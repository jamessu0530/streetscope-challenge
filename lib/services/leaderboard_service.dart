import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_settings.dart';
import '../models/guess_result.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  // v2：加入玩家名稱欄位（並順便清掉 v1 的自動生成假名）
  static const String _kEntriesKey = 'leaderboard_entries_v2';
  static const String _kLegacyKeyV1 = 'leaderboard_entries_v1';
  static const int _kStorageCap = 200;

  /// 存一筆新紀錄，回傳該筆的 playedAt（供事後 updateEntryName 定位）。
  Future<DateTime> saveRun({
    required List<GuessResult> results,
    required GameSettings settings,
    required String name,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // 把 v1 舊資料丟掉，避免顯示自動生成、使用者不認得的名字
    await prefs.remove(_kLegacyKeyV1);

    final List<LeaderboardEntry> entries = await loadAll();
    final int totalScore = results.fold<int>(
      0,
      (int sum, GuessResult r) => sum + r.score,
    );
    final DateTime playedAt = DateTime.now();
    final String cleanName = _sanitizeName(name);
    entries.add(
      LeaderboardEntry(
        name: cleanName,
        totalScore: totalScore,
        rounds: results.length,
        secondsPerRound: settings.secondsPerRound,
        mode: settings.mode,
        region: settings.region,
        playedAt: playedAt,
      ),
    );

    entries.sort((LeaderboardEntry a, LeaderboardEntry b) {
      final int scoreCmp = b.totalScore.compareTo(a.totalScore);
      if (scoreCmp != 0) return scoreCmp;
      return b.playedAt.compareTo(a.playedAt);
    });
    final List<LeaderboardEntry> trimmed = entries.length > _kStorageCap
        ? entries.take(_kStorageCap).toList()
        : entries;
    await prefs.setStringList(
      _kEntriesKey,
      trimmed.map((LeaderboardEntry e) => e.encode()).toList(),
    );
    return playedAt;
  }

  /// 更新指定 playedAt 的那筆的名字（結算頁可即時跟著打字改）。
  Future<void> updateEntryName({
    required DateTime playedAt,
    required String name,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<LeaderboardEntry> all = await loadAll();
    final String cleanName = _sanitizeName(name);
    final List<LeaderboardEntry> updated = all
        .map(
          (LeaderboardEntry e) => e.playedAt.millisecondsSinceEpoch ==
                  playedAt.millisecondsSinceEpoch
              ? e.copyWith(name: cleanName)
              : e,
        )
        .toList();
    await prefs.setStringList(
      _kEntriesKey,
      updated.map((LeaderboardEntry e) => e.encode()).toList(),
    );
  }

  Future<List<LeaderboardEntry>> loadAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_kEntriesKey) ?? <String>[];
    final List<LeaderboardEntry> out = <LeaderboardEntry>[];
    for (final String row in raw) {
      final LeaderboardEntry? e = LeaderboardEntry.decode(row);
      if (e != null) out.add(e);
    }
    return out;
  }

  Future<List<LeaderboardEntry>> loadTop10() async {
    final List<LeaderboardEntry> entries = await loadAll();
    entries.sort((LeaderboardEntry a, LeaderboardEntry b) {
      final int scoreCmp = b.totalScore.compareTo(a.totalScore);
      if (scoreCmp != 0) return scoreCmp;
      return b.playedAt.compareTo(a.playedAt);
    });
    return entries.take(10).toList();
  }

  Future<List<LeaderboardEntry>> loadRecent10() async {
    final List<LeaderboardEntry> entries = await loadAll();
    entries.sort(
      (LeaderboardEntry a, LeaderboardEntry b) =>
          b.playedAt.compareTo(a.playedAt),
    );
    return entries.take(10).toList();
  }

  String _sanitizeName(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return 'JAMES';
    // 顯示是 arcade 等寬字，限制 8 字元避免欄位爆版
    return trimmed.length > 8 ? trimmed.substring(0, 8) : trimmed;
  }
}
