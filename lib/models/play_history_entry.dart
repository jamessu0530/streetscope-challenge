import 'game_mode.dart';
import 'game_region.dart';

enum PlayHistoryType {
  solo,
  ai,
  friend;

  static PlayHistoryType fromApi(String raw) {
    switch (raw) {
      case 'ai':
        return PlayHistoryType.ai;
      case 'friend':
        return PlayHistoryType.friend;
      default:
        return PlayHistoryType.solo;
    }
  }

  String get apiValue => name;
}

extension PlayHistoryTypeX on PlayHistoryType {
  String get label {
    switch (this) {
      case PlayHistoryType.solo:
        return '單人';
      case PlayHistoryType.ai:
        return 'AI 對戰';
      case PlayHistoryType.friend:
        return '好友對戰';
    }
  }
}

class PlayHistoryEntry {
  const PlayHistoryEntry({
    required this.id,
    required this.totalScore,
    required this.rounds,
    required this.secondsPerRound,
    required this.mode,
    required this.region,
    required this.playType,
    required this.playedAt,
    this.opponentUserId,
    this.opponentDisplayName,
    this.opponentScore,
    this.won,
    this.aiStrength,
  });

  final String id;
  final int totalScore;
  final int rounds;
  final int secondsPerRound;
  final GameMode mode;
  final GameRegion region;
  final PlayHistoryType playType;
  final DateTime playedAt;
  final String? opponentUserId;
  final String? opponentDisplayName;
  final int? opponentScore;
  final bool? won;
  final String? aiStrength;

  factory PlayHistoryEntry.fromApiJson(Map<String, dynamic> json) {
    final String modeName = json['mode'] as String? ?? GameMode.move.name;
    final String regionName =
        json['region'] as String? ?? GameRegion.world.name;
    return PlayHistoryEntry(
      id: (json['id'] as String?) ?? '',
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
      playType: PlayHistoryType.fromApi(
        (json['playType'] as String?) ?? 'solo',
      ),
      playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      opponentUserId: json['opponentUserId'] as String?,
      opponentDisplayName: json['opponentDisplayName'] as String?,
      opponentScore: (json['opponentScore'] as num?)?.toInt(),
      won: json['won'] as bool?,
      aiStrength: json['aiStrength'] as String?,
    );
  }

  String get opponentLabel {
    switch (playType) {
      case PlayHistoryType.solo:
        return '—';
      case PlayHistoryType.ai:
        final String strength = aiStrength ?? 'medium';
        final String label = switch (strength) {
          'weak' => '弱',
          'strong' => '強',
          _ => '中',
        };
        return 'AI（$label）';
      case PlayHistoryType.friend:
        final String? name = opponentDisplayName?.trim();
        if (name != null && name.isNotEmpty) return name;
        return '好友';
    }
  }

  String? get outcomeLabel {
    if (playType != PlayHistoryType.friend || won == null) return null;
    return won! ? '勝' : '負';
  }
}
