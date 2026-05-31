// =============================================================================
// RealtimeService — WebSocket 大廳 + 真人對戰
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';
import '../models/duel_messages.dart';
import '../models/game_settings.dart';
import '../models/online_player.dart';
import '../models/place.dart';
import '../models/place_json.dart';
import '../services/auth_service.dart';
import '../services/place_picker_service.dart';

enum RealtimeConnectionState { disconnected, connecting, connected }

class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  static const int _maxChatMessages = 100;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  final ValueNotifier<List<OnlinePlayer>> onlinePlayers =
      ValueNotifier<List<OnlinePlayer>>(<OnlinePlayer>[]);
  final ValueNotifier<List<LobbyChatMessage>> chatMessages =
      ValueNotifier<List<LobbyChatMessage>>(<LobbyChatMessage>[]);
  final ValueNotifier<RealtimeConnectionState> connectionState =
      ValueNotifier<RealtimeConnectionState>(RealtimeConnectionState.disconnected);

  final ValueNotifier<DuelInviteIncoming?> incomingDuelInvite =
      ValueNotifier<DuelInviteIncoming?>(null);
  final ValueNotifier<String?> duelStatusMessage = ValueNotifier<String?>(null);
  final ValueNotifier<DuelStartEvent?> pendingDuelStart =
      ValueNotifier<DuelStartEvent?>(null);
  final ValueNotifier<DuelStateSync?> pendingDuelResync =
      ValueNotifier<DuelStateSync?>(null);

  /// 遊戲頁註冊：接收對手送出、回合結算。
  void Function(Map<String, dynamic>)? onDuelGameEvent;

  final List<Map<String, dynamic>> _pendingDuelGameEvents =
      <Map<String, dynamic>>[];

  /// 綁定遊戲頁 handler，並重播進入遊戲前暫存的對戰事件。
  void bindDuelGameHandler(void Function(Map<String, dynamic>) handler) {
    onDuelGameEvent = handler;
    if (_pendingDuelGameEvents.isEmpty) return;
    final List<Map<String, dynamic>> queued =
        List<Map<String, dynamic>>.from(_pendingDuelGameEvents);
    _pendingDuelGameEvents.clear();
    for (final Map<String, dynamic> event in queued) {
      handler(event);
    }
  }

  void unbindDuelGameHandler() {
    onDuelGameEvent = null;
  }

  void _emitDuelGameEvent(Map<String, dynamic> payload) {
    final void Function(Map<String, dynamic>)? handler = onDuelGameEvent;
    if (handler != null) {
      handler(payload);
      return;
    }
    _pendingDuelGameEvents.add(payload);
    if (_pendingDuelGameEvents.length > 32) {
      _pendingDuelGameEvents.removeAt(0);
    }
  }

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _intentionalDisconnect = false;
  int _connectGeneration = 0;

  bool get canUseRealtime =>
      hasWsBaseUrl && AuthService.instance.hasApi && AuthService.instance.isLoggedIn;

  Future<void> connect() async {
    if (!canUseRealtime) return;

    final String? token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty) return;

    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();
    final int gen = ++_connectGeneration;

    await _tearDownChannel();
    connectionState.value = RealtimeConnectionState.connecting;

    try {
      final Uri uri = Uri.parse(kWsBaseUrl).replace(
        path: '/ws',
        queryParameters: <String, String>{'token': token},
      );
      final WebSocketChannel channel = WebSocketChannel.connect(uri);
      if (gen != _connectGeneration) {
        await channel.sink.close();
        return;
      }

      _channel = channel;
      _subscription = channel.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      connectionState.value = RealtimeConnectionState.connected;
      _startPing();
    } catch (e) {
      if (kDebugMode) debugPrint('Realtime connect error: $e');
      connectionState.value = RealtimeConnectionState.disconnected;
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _connectGeneration++;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    onlinePlayers.value = <OnlinePlayer>[];
    chatMessages.value = <LobbyChatMessage>[];
    incomingDuelInvite.value = null;
    duelStatusMessage.value = null;
    pendingDuelStart.value = null;
    connectionState.value = RealtimeConnectionState.disconnected;
    await _tearDownChannel();
  }

  void sendChat(String text) {
    _send(<String, dynamic>{'type': 'chat', 'text': text.trim()});
  }

  void sendDuelInvite({
    required String toUserId,
    required GameSettings settings,
    bool rematch = false,
  }) {
    duelStatusMessage.value = rematch ? '已送出再戰邀請…' : '已送出挑戰邀請…';
    _send(<String, dynamic>{
      'type': 'duel_invite',
      'toUserId': toUserId,
      'settings': settings.toDuelJson(),
      'rematch': rematch,
    });
  }

  void replyDuelInvite({required String inviteId, required bool accept}) {
    _send(<String, dynamic>{
      'type': 'duel_invite_reply',
      'inviteId': inviteId,
      'accept': accept,
    });
  }

  void submitDuelRound({
    required String roomId,
    required int round,
    required int score,
    double? distanceKm,
    LatLng? guessed,
  }) {
    _send(<String, dynamic>{
      'type': 'duel_round_submit',
      'roomId': roomId,
      'round': round,
      'score': score,
      'distanceKm': distanceKm,
      if (guessed != null) 'guessedLat': guessed.latitude,
      if (guessed != null) 'guessedLng': guessed.longitude,
    });
  }

  /// 結算後按「下一回合」：通知對手同步進入同一回合。
  void requestDuelAdvanceRound({
    required String roomId,
    required int finishedRound,
  }) {
    _send(<String, dynamic>{
      'type': 'duel_advance_round',
      'roomId': roomId,
      'round': finishedRound,
    });
  }

  /// 主動退出進行中的對戰（對手會收到 duel_cancelled）。
  void leaveDuel({required String roomId}) {
    _send(<String, dynamic>{
      'type': 'duel_leave',
      'roomId': roomId,
    });
  }

  void _send(Map<String, dynamic> payload) {
    final WebSocketChannel? channel = _channel;
    if (channel == null) return;
    if (connectionState.value != RealtimeConnectionState.connected) return;
    try {
      channel.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      _handlePayload(decoded);
    } catch (e) {
      if (kDebugMode) debugPrint('Realtime parse error: $e');
    }
  }

  void _handlePayload(Map<String, dynamic> payload) {
    final String type = (payload['type'] as String?) ?? '';
    switch (type) {
      case 'presence':
        final dynamic players = payload['players'];
        if (players is List) {
          onlinePlayers.value = players
              .whereType<Map<String, dynamic>>()
              .map(OnlinePlayer.fromJson)
              .where((OnlinePlayer p) => p.id.isNotEmpty)
              .toList();
        }
        return;
      case 'chat':
        final LobbyChatMessage msg = LobbyChatMessage.fromJson(payload);
        if (msg.text.isEmpty) return;
        final List<LobbyChatMessage> next =
            List<LobbyChatMessage>.from(chatMessages.value)..add(msg);
        if (next.length > _maxChatMessages) {
          next.removeRange(0, next.length - _maxChatMessages);
        }
        chatMessages.value = next;
        return;
      case 'pong':
        return;
      case 'duel_invite_incoming':
        incomingDuelInvite.value = DuelInviteIncoming.fromJson(payload);
        return;
      case 'duel_invite_sent':
        duelStatusMessage.value = '等待對方回應…';
        return;
      case 'duel_invite_declined':
        duelStatusMessage.value = '對方拒絕了挑戰';
        return;
      case 'duel_error':
        duelStatusMessage.value = '對戰錯誤：${payload['message']}';
        return;
      case 'duel_room_ready':
        unawaited(_onDuelRoomReady(payload));
        return;
      case 'duel_start':
        pendingDuelStart.value = DuelStartEvent.fromJson(payload);
        duelStatusMessage.value = null;
        incomingDuelInvite.value = null;
        return;
      case 'duel_cancelled':
        duelStatusMessage.value = '對戰已取消';
        _emitDuelGameEvent(payload);
        return;
      case 'duel_opponent_disconnected':
      case 'duel_opponent_reconnected':
      case 'duel_state_sync':
      case 'duel_round_ack':
      case 'duel_opponent_submitted':
      case 'duel_round_complete':
      case 'duel_sync_next_round':
        if ((payload['type'] as String?) == 'duel_state_sync' &&
            onDuelGameEvent == null) {
          pendingDuelResync.value = DuelStateSync.fromJson(payload);
          return;
        }
        _emitDuelGameEvent(payload);
        return;
      default:
        return;
    }
  }

  Future<void> _onDuelRoomReady(Map<String, dynamic> payload) async {
    final String role = (payload['role'] as String?) ?? '';
    final String roomId = (payload['roomId'] as String?) ?? '';
    if (roomId.isEmpty) return;

    if (role != 'host') {
      duelStatusMessage.value = '等待房主準備題目…';
      return;
    }

    duelStatusMessage.value = '正在產生題目…';
    final GameSettings settings = duelSettingsFromJson(
      (payload['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
    try {
      final List<Place> places = await generateRandomPlaces(
        count: settings.roundsPerGame,
        region: settings.region,
      );
      _send(<String, dynamic>{
        'type': 'duel_places',
        'roomId': roomId,
        'places': places.map((Place p) => p.toJson()).toList(),
      });
      duelStatusMessage.value = '題目已送出，等待雙方進入遊戲…';
    } catch (e) {
      duelStatusMessage.value = '題目產生失敗：$e';
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _send(<String, String>{'type': 'ping'});
    });
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    if (!canUseRealtime) return;

    _pingTimer?.cancel();
    connectionState.value = RealtimeConnectionState.disconnected;
    unawaited(_tearDownChannel());

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      if (_intentionalDisconnect) return;
      if (!canUseRealtime) return;
      try {
        await AuthService.instance.ensureSessionStillValid();
      } on AuthException catch (e) {
        if (AuthService.isSessionSupersededMessage(e.message)) {
          return;
        }
      } catch (_) {
        // 網路錯誤時仍嘗試重連 WebSocket。
      }
      if (_intentionalDisconnect || !canUseRealtime) return;
      await connect();
    });
  }

  Future<void> _tearDownChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
