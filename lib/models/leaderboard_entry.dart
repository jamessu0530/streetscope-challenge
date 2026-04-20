import 'dart:convert';

import 'game_mode.dart';
import 'game_region.dart';

class LeaderboardEntry {
  final String name;
  final int totalScore;
  final int rounds;
  final int secondsPerRound;
  final GameMode mode;
  final GameRegion region;
  final DateTime playedAt;

  const LeaderboardEntry({
    required this.name,
    required this.totalScore,
    required this.rounds,
    required this.secondsPerRound,
    required this.mode,
    required this.region,
    required this.playedAt,
  });

  LeaderboardEntry copyWith({String? name}) {
    return LeaderboardEntry(
      name: name ?? this.name,
      totalScore: totalScore,
      rounds: rounds,
      secondsPerRound: secondsPerRound,
      mode: mode,
      region: region,
      playedAt: playedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'totalScore': totalScore,
      'rounds': rounds,
      'secondsPerRound': secondsPerRound,
      'mode': mode.name,
      'region': region.name,
      'playedAt': playedAt.toIso8601String(),
    };
  }

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final String modeName = json['mode'] as String? ?? GameMode.move.name;
    final String regionName =
        json['region'] as String? ?? GameRegion.world.name;
    return LeaderboardEntry(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'JAMES',
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
    );
  }

  String encode() => jsonEncode(toJson());

  static LeaderboardEntry? decode(String raw) {
    try {
      final dynamic data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      return LeaderboardEntry.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
