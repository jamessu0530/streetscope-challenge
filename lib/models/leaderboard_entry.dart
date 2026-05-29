import 'dart:convert';

import 'game_mode.dart';
import 'game_region.dart';

class LeaderboardEntry {
  final String id;
  final String userId;
  final String name;
  final int totalScore;
  final int rounds;
  final int secondsPerRound;
  final GameMode mode;
  final GameRegion region;
  final DateTime playedAt;
  final bool isMe;

  const LeaderboardEntry({
    required this.id,
    required this.userId,
    required this.name,
    required this.totalScore,
    required this.rounds,
    required this.secondsPerRound,
    required this.mode,
    required this.region,
    required this.playedAt,
    this.isMe = false,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'displayName': name,
      'totalScore': totalScore,
      'rounds': rounds,
      'secondsPerRound': secondsPerRound,
      'mode': mode.name,
      'region': region.name,
      'playedAt': playedAt.toIso8601String(),
      'isMe': isMe,
    };
  }

  factory LeaderboardEntry.fromApiJson(Map<String, dynamic> json) {
    final String modeName = json['mode'] as String? ?? GameMode.move.name;
    final String regionName =
        json['region'] as String? ?? GameRegion.world.name;
    return LeaderboardEntry(
      id: (json['id'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
      name: (json['displayName'] as String?)?.trim().isNotEmpty == true
          ? (json['displayName'] as String).trim()
          : 'Player',
      totalScore: (json['totalScore'] as num?)?.toInt() ?? 0,
      rounds: (json['rounds'] as num?)?.toInt() ?? 0,
      secondsPerRound: (json['secondsPerRound'] as num?)?.toInt() ?? 0,
      mode: GameMode.values.firstWhere(
        (GameMode m) => m.name == modeName,
        orElse: () => GameMode.move,
      ),
      region: GameRegion.values.firstWhere(
        (GameRegion r) => r.name == regionName,
        orElse: () => GameRegion.world,
      ),
      playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isMe: json['isMe'] as bool? ?? false,
    );
  }

  String encode() => jsonEncode(toJson());

  static LeaderboardEntry? decode(String raw) {
    try {
      final dynamic data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      return LeaderboardEntry.fromApiJson(data);
    } catch (_) {
      return null;
    }
  }
}
