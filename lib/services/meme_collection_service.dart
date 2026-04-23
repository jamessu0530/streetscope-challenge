// =============================================================================
// MemeCollectionService
//
// 用 shared_preferences 在本機儲存玩家蒐集到的 meme。
// 操作都是 singleton：MemeCollectionService.instance.xxx
//
// 流程：
//   1. 低分懲罰抓到 meme 後 → GamePage 呼叫 .add(...)
//   2. 首頁「MEME 收集庫」進去 → MemeCollectionPage 呼叫 .loadAll()
//   3. 用 imageUrl 做唯一鍵，避免同一張圖被重複存
// =============================================================================

import 'package:shared_preferences/shared_preferences.dart';

import '../models/collected_meme.dart';
import '../models/meme_result.dart';

class MemeCollectionService {
  MemeCollectionService._();
  static final MemeCollectionService instance = MemeCollectionService._();

  static const String _kStorageKey = 'meme_collection_v1';
  static const int _kStorageCap = 300;

  /// 儲存一個新 meme（若 imageUrl 已存在則略過，保持蒐集庫不重複）。
  /// 回傳：是不是「真的新增成功」（沒重複時為 true）。
  Future<bool> add({
    required MemeResult meme,
    required String? country,
    required int score,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<CollectedMeme> all = await loadAll();
    final bool exists =
        all.any((CollectedMeme m) => m.imageUrl == meme.imageUrl);
    if (exists) return false;

    final CollectedMeme fresh = CollectedMeme.fromResult(
      meme: meme,
      country: country,
      score: score,
    );

    final List<CollectedMeme> next = <CollectedMeme>[fresh, ...all];
    // 新的排前面；如果超過上限就裁掉最舊的。
    final List<CollectedMeme> trimmed =
        next.length > _kStorageCap ? next.take(_kStorageCap).toList() : next;

    await prefs.setStringList(
      _kStorageKey,
      trimmed.map((CollectedMeme m) => m.encode()).toList(),
    );
    return true;
  }

  /// 讀出所有蒐集 meme（按 collectedAt 由新到舊）。
  Future<List<CollectedMeme>> loadAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? raw = prefs.getStringList(_kStorageKey);
    if (raw == null || raw.isEmpty) return <CollectedMeme>[];
    final List<CollectedMeme> out = <CollectedMeme>[];
    for (final String s in raw) {
      try {
        out.add(CollectedMeme.decode(s));
      } catch (_) {
        // 單筆壞掉就略過，不影響其他資料。
      }
    }
    out.sort((CollectedMeme a, CollectedMeme b) =>
        b.collectedAt.compareTo(a.collectedAt));
    return out;
  }

  /// 以國家分組（key = countryLabel），value 已按時間由新到舊。
  Future<Map<String, List<CollectedMeme>>> loadGroupedByCountry() async {
    final List<CollectedMeme> all = await loadAll();
    final Map<String, List<CollectedMeme>> map =
        <String, List<CollectedMeme>>{};
    for (final CollectedMeme m in all) {
      map.putIfAbsent(m.countryLabel, () => <CollectedMeme>[]).add(m);
    }
    return map;
  }

  /// 清空整個蒐集庫（測試 / 給玩家「清除」用）。
  Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStorageKey);
  }
}
