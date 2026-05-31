import 'game_settings.dart';
import 'online_player.dart';
import 'place.dart';
import 'place_json.dart';

class DuelInviteIncoming {
  const DuelInviteIncoming({
    required this.inviteId,
    required this.from,
    required this.settings,
  });

  final String inviteId;
  final OnlinePlayer from;
  final GameSettings settings;

  factory DuelInviteIncoming.fromJson(Map<String, dynamic> json) {
    return DuelInviteIncoming(
      inviteId: (json['inviteId'] as String?) ?? '',
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

