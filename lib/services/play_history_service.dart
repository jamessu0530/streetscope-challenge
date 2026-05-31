import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/ai_strength.dart';
import '../models/game_settings.dart';
import '../models/play_history_entry.dart';
import 'auth_service.dart';

class PlayHistoryException implements Exception {
  PlayHistoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PlayHistoryService {
  PlayHistoryService._();
  static final PlayHistoryService instance = PlayHistoryService._();

  Future<String?> recordSoloOrAi({
    required int totalScore,
    required GameSettings settings,
    required bool vsAi,
    int? opponentScore,
  }) async {
    return _submit(
      totalScore: totalScore,
      settings: settings,
      playType: vsAi ? PlayHistoryType.ai : PlayHistoryType.solo,
      opponentDisplayName: vsAi ? 'AI' : null,
      opponentScore: vsAi ? opponentScore : null,
      aiStrength: vsAi ? settings.aiStrength.apiValue : null,
    );
  }

  Future<String?> recordFriendDuel({
    required int myTotal,
    required int opponentTotal,
    required GameSettings settings,
    required String opponentUserId,
    required String opponentDisplayName,
    required String? winnerId,
    required String myUserId,
  }) async {
    final bool? won = winnerId == null
        ? null
        : winnerId.trim() == myUserId.trim();
    return _submit(
      totalScore: myTotal,
      settings: settings,
      playType: PlayHistoryType.friend,
      opponentUserId: opponentUserId.trim().isEmpty ? null : opponentUserId,
      opponentDisplayName: opponentDisplayName,
      opponentScore: opponentTotal,
      won: won,
    );
  }

  Future<List<PlayHistoryEntry>> loadMine({
    int limit = 50,
    int skip = 0,
  }) async {
    if (!AuthService.instance.isLoggedIn) {
      throw PlayHistoryException('請先登入才能查看遊玩紀錄');
    }
    final String? token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty || !hasApiBaseUrl) {
      throw PlayHistoryException('請設定 API_BASE_URL');
    }

    final http.Response response = await http.get(
      _uri('', query: <String, String>{
        'limit': limit.toString(),
        'skip': skip.toString(),
      }),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw PlayHistoryException('伺服器回應格式錯誤');
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PlayHistoryEntry.fromApiJson)
          .toList();
    }
    throw PlayHistoryException(_errorMessage(response));
  }

  Future<String?> _submit({
    required int totalScore,
    required GameSettings settings,
    required PlayHistoryType playType,
    String? opponentUserId,
    String? opponentDisplayName,
    int? opponentScore,
    bool? won,
    String? aiStrength,
  }) async {
    if (!AuthService.instance.isLoggedIn) return null;
    final String? token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty || !hasApiBaseUrl) {
      return null;
    }

    final http.Response response = await http
        .post(
          _uri(''),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(<String, dynamic>{
            'totalScore': totalScore,
            'rounds': settings.roundsPerGame,
            'secondsPerRound': settings.secondsPerRound,
            'mode': settings.mode.name,
            'region': settings.region.name,
            'playType': playType.apiValue,
            if (opponentUserId != null) 'opponentUserId': opponentUserId,
            if (opponentDisplayName != null)
              'opponentDisplayName': opponentDisplayName,
            if (opponentScore != null) 'opponentScore': opponentScore,
            if (won != null) 'won': won,
            if (aiStrength != null) 'aiStrength': aiStrength,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = _decodeJson(response.body);
      return data['id'] as String?;
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print('Play history save failed: ${_errorMessage(response)}');
    }
    return null;
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final String base = kApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final String suffix = path.isEmpty
        ? ''
        : (path.startsWith('/') ? path : '/$path');
    return Uri.parse('$base/play-history$suffix')
        .replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeJson(String body) {
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw PlayHistoryException('伺服器回應格式錯誤');
    }
    return decoded;
  }

  String _errorMessage(http.Response response) {
    try {
      final Map<String, dynamic> data = _decodeJson(response.body);
      final dynamic detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {
      // ignore
    }
    return '遊玩紀錄請求失敗（${response.statusCode}）';
  }
}
