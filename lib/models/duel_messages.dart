import 'game_settings.dart';
import 'online_player.dart';
import 'place.dart';
import 'place_json.dart';

class DuelInviteIncoming {
  const DuelInviteIncoming({
    required this.inviteId,
    required this.from,
    required this.settings,
    this.isRematch = false,
  });

  final String inviteId;
  final OnlinePlayer from;
  final GameSettings settings;
  final bool isRematch;

  factory DuelInviteIncoming.fromJson(Map<String, dynamic> json) {
    return DuelInviteIncoming(
      inviteId: (json['inviteId'] as String?) ?? '',
      isRematch: json['rematch'] == true,
      from: OnlinePlayer.fromJson(
        (json['from'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      settings: duelSettingsFromJson(
        (json['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }
}

class DuelRoundPlayerResult {
  const DuelRoundPlayerResult({
    required this.id,
    required this.displayName,
    required this.score,
    this.distanceKm,
  });

  final String id;
  final String displayName;
  final int score;
  final double? distanceKm;

  factory DuelRoundPlayerResult.fromJson(Map<String, dynamic> json) {
    final dynamic d = json['distanceKm'];
    return DuelRoundPlayerResult(
      id: (json['id'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ?? 'Player',
      score: (json['score'] as num?)?.toInt() ??
          (json['totalScore'] as num?)?.toInt() ??
          0,
      distanceKm: d == null ? null : (d as num).toDouble(),
    );
  }
}

class DuelRoundComplete {
  const DuelRoundComplete({
    required this.roomId,
    required this.round,
    required this.players,
    required this.totals,
    required this.matchEnd,
    this.winnerId,
  });

  final String roomId;
  final int round;
  final List<DuelRoundPlayerResult> players;
  final List<DuelRoundPlayerResult> totals;
  final bool matchEnd;
  final String? winnerId;

  factory DuelRoundComplete.fromJson(Map<String, dynamic> json) {
    return DuelRoundComplete(
      roomId: (json['roomId'] as String?) ?? '',
      round: (json['round'] as num?)?.toInt() ?? 0,
      players: (json['players'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DuelRoundPlayerResult.fromJson)
          .toList(),
      totals: (json['totals'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(DuelRoundPlayerResult.fromJson)
          .toList(),
      matchEnd: json['matchEnd'] == true,
      winnerId: json['winnerId'] as String?,
    );
  }
}

class DuelStartEvent {
  const DuelStartEvent({
    required this.roomId,
    required this.settings,
    required this.places,
    required this.opponent,
  });

  final String roomId;
  final GameSettings settings;
  final List<Place> places;
  final OnlinePlayer opponent;

  factory DuelStartEvent.fromJson(Map<String, dynamic> json) {
    final OnlinePlayer opponent = OnlinePlayer.fromJson(
      (json['opponent'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
    final GameSettings base = duelSettingsFromJson(
      (json['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
    return DuelStartEvent(
      roomId: (json['roomId'] as String?) ?? '',
      settings: base.copyWith(
        vsAi: false,
        vsPlayer: true,
        duelRoomId: (json['roomId'] as String?) ?? '',
        opponentUserId: opponent.id,
        opponentDisplayName: opponent.displayName,
        presetPlaces: PlaceJson.listFromJson(
          json['places'] as List<dynamic>? ?? <dynamic>[],
        ),
      ),
      places: PlaceJson.listFromJson(
        json['places'] as List<dynamic>? ?? <dynamic>[],
      ),
      opponent: opponent,
    );
  }
}

/// 重連後恢復對戰進度（由 `duel_state_sync` 轉換）。
class DuelStateSync {
  const DuelStateSync({
    required this.roomId,
    required this.settings,
    required this.places,
    required this.round,
    required this.inSettlement,
    required this.canAdvance,
    required this.opponent,
    required this.opponentDisconnected,
    required this.mySubmitted,
    required this.opponentSubmitted,
    this.myScore,
    this.myDistanceKm,
    this.opponentScore,
    this.opponentDistanceKm,
  });

  final String roomId;
  final GameSettings settings;
  final List<Place> places;
  final int round;
  final bool inSettlement;
  final bool canAdvance;
  final OnlinePlayer opponent;
  final bool opponentDisconnected;
  final bool mySubmitted;
  final bool opponentSubmitted;
  final int? myScore;
  final double? myDistanceKm;
  final int? opponentScore;
  final double? opponentDistanceKm;

  factory DuelStateSync.fromJson(Map<String, dynamic> json) {
    final OnlinePlayer opponent = OnlinePlayer.fromJson(
      (json['opponent'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
    final GameSettings base = duelSettingsFromJson(
      (json['settings'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
    final dynamic myD = json['myDistanceKm'];
    final dynamic oppD = json['opponentDistanceKm'];
    return DuelStateSync(
      roomId: (json['roomId'] as String?) ?? '',
      settings: base.copyWith(
        vsAi: false,
        vsPlayer: true,
        duelRoomId: (json['roomId'] as String?) ?? '',
        opponentUserId: opponent.id,
        opponentDisplayName: opponent.displayName,
        presetPlaces: PlaceJson.listFromJson(
          json['places'] as List<dynamic>? ?? <dynamic>[],
        ),
      ),
      places: PlaceJson.listFromJson(
        json['places'] as List<dynamic>? ?? <dynamic>[],
      ),
      round: (json['round'] as num?)?.toInt() ?? 0,
      inSettlement: json['inSettlement'] == true,
      canAdvance: json['canAdvance'] == true,
      opponent: opponent,
      opponentDisconnected: json['opponentDisconnected'] == true,
      mySubmitted: json['mySubmitted'] == true,
      opponentSubmitted: json['opponentSubmitted'] == true,
      myScore: (json['myScore'] as num?)?.toInt(),
      myDistanceKm: myD == null ? null : (myD as num).toDouble(),
      opponentScore: (json['opponentScore'] as num?)?.toInt(),
      opponentDistanceKm: oppD == null ? null : (oppD as num).toDouble(),
    );
  }

  DuelResumeState toResumeState() {
    return DuelResumeState(
      round: round,
      submitted: mySubmitted,
      duelCanAdvance: canAdvance && opponentSubmitted,
      duelOpponentSubmitted: opponentSubmitted,
      duelOpponentScore: opponentScore,
      duelOpponentDistanceKm: opponentDistanceKm,
      waitingForOpponentReconnect: opponentDisconnected,
      myScore: myScore,
      myDistanceKm: myDistanceKm,
    );
  }
}

class DuelResumeState {
  const DuelResumeState({
    required this.round,
    required this.submitted,
    required this.duelCanAdvance,
    required this.duelOpponentSubmitted,
    required this.waitingForOpponentReconnect,
    this.duelOpponentScore,
    this.duelOpponentDistanceKm,
    this.myScore,
    this.myDistanceKm,
  });

  final int round;
  final bool submitted;
  final bool duelCanAdvance;
  final bool duelOpponentSubmitted;
  final bool waitingForOpponentReconnect;
  final int? duelOpponentScore;
  final double? duelOpponentDistanceKm;
  final int? myScore;
  final double? myDistanceKm;
}

