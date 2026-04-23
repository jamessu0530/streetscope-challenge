// =============================================================================
// MemeCollectionPage — 迷因收集庫
//
// 顯示玩家蒐集到的所有 meme，並依國家分類（類似寶可夢 / 集郵冊）。
//
// 視覺風格：
//   - 沿用 Matchday 設計 token（黑底 / 米白 / 品牌字體）
//   - 頂部 ticker + 收藏統計（COLLECTED X / COUNTRIES Y）
//   - 依國家分段，每段用 horizontal list 展示 meme 縮圖
//   - 點擊縮圖 → 全圖 viewer + meta
// =============================================================================

import 'package:flutter/material.dart';

import '../models/collected_meme.dart';
import '../services/audio_service.dart';
import '../services/meme_collection_service.dart';
import '../widgets/floating_home_nav_bar.dart';
import '../widgets/matchday_ui.dart';

class MemeCollectionPage extends StatefulWidget {
  const MemeCollectionPage({super.key});

  @override
  State<MemeCollectionPage> createState() => _MemeCollectionPageState();
}

class _MemeCollectionPageState extends State<MemeCollectionPage> {
  bool _loading = true;
  Map<String, List<CollectedMeme>> _grouped =
      const <String, List<CollectedMeme>>{};
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final Map<String, List<CollectedMeme>> grouped =
        await MemeCollectionService.instance.loadGroupedByCountry();
    if (!mounted) return;
    final int total = grouped.values.fold<int>(
      0,
      (int acc, List<CollectedMeme> v) => acc + v.length,
    );
    setState(() {
      _grouped = grouped;
      _totalCount = total;
      _loading = false;
    });
  }

  Future<void> _confirmClear() async {
    AudioService.instance.playClick();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('清空收集庫？'),
          content: const Text('此操作會刪除所有已收集的 meme，無法復原。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('全部清除'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await MemeCollectionService.instance.clearAll();
      if (!mounted) return;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 依「收集數量」遞減排序國家
    final List<MapEntry<String, List<CollectedMeme>>> sorted = _grouped.entries
        .toList()
      ..sort((MapEntry<String, List<CollectedMeme>> a,
              MapEntry<String, List<CollectedMeme>> b) =>
          b.value.length.compareTo(a.value.length));

    return Scaffold(
      backgroundColor: MatchdayPalette.bg,
      body: Stack(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const MatchdayTopTicker(
                  label: 'ARCHIVE · MEME VAULT',
                  trailing: 'WORLD TOUR',
                ),
                _Header(
                  onBack: () {
                    AudioService.instance.playClick();
                    Navigator.of(context).pop();
                  },
                  onClear: _totalCount > 0 ? _confirmClear : null,
                  totalCount: _totalCount,
                  countryCount: _grouped.length,
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (sorted.isEmpty
                          ? const _EmptyState()
                          : ListView.builder(
                              // 底部多 110 給浮動 nav bar
                              padding: const EdgeInsets.fromLTRB(0, 4, 0, 110),
                              itemCount: sorted.length,
                              itemBuilder: (BuildContext context, int i) {
                                final MapEntry<String, List<CollectedMeme>> e =
                                    sorted[i];
                                return _CountrySection(
                                  country: e.key,
                                  memes: e.value,
                                );
                              },
                            )),
                ),
              ],
            ),
          ),
          const FloatingHomeNavBar(current: HomeTab.memeLibrary),
        ],
      ),
    );
  }
}

// =============================================================================
// Header：返回鍵 + 大標 + 統計 + 清除鈕
// =============================================================================
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onClear;
  final int totalCount;
  final int countryCount;

  const _Header({
    required this.onBack,
    required this.onClear,
    required this.totalCount,
    required this.countryCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          IconButton(
            tooltip: '返回',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: MatchdayPalette.ink),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'MEME VAULT',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: MatchdayPalette.ink,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'COLLECTED $totalCount · '
                  'COUNTRIES $countryCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: '全部清除',
              onPressed: onClear,
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.black54,
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// 國家分段：大標 + 數量 + 橫向縮圖列
// =============================================================================
class _CountrySection extends StatelessWidget {
  final String country;
  final List<CollectedMeme> memes;

  const _CountrySection({required this.country, required this.memes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Container(width: 4, height: 22, color: MatchdayPalette.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    country.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: MatchdayPalette.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  color: MatchdayPalette.ink,
                  child: Text(
                    'x${memes.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: memes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int i) {
                final CollectedMeme m = memes[i];
                return _MemeThumb(meme: m);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemeThumb extends StatelessWidget {
  final CollectedMeme meme;
  const _MemeThumb({required this.meme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.playClick();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _MemeViewerPage(meme: meme),
            fullscreenDialog: true,
          ),
        );
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: MatchdayPalette.ink, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.network(
              meme.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (BuildContext context, Widget child,
                  ImageChunkEvent? p) {
                if (p == null) return child;
                return const ColoredBox(
                  color: Colors.black12,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder:
                  (BuildContext context, Object err, StackTrace? _) {
                return const ColoredBox(
                  color: Colors.black26,
                  child: Icon(Icons.broken_image, color: Colors.white54),
                );
              },
            ),
            // 底部漸層遮罩 + 分數
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black87,
                    ],
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.sports_score,
                      size: 12,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${meme.score} pts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'r/${meme.subreddit}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 空狀態
// =============================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.image_search,
              size: 72,
              color: MatchdayPalette.ink.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            const Text(
              '收集庫空空如也',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: MatchdayPalette.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '遊戲中本回合分數低於 1000 時會觸發懲罰，\n同時把 meme 收進這裡。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 全圖檢視頁
// =============================================================================
class _MemeViewerPage extends StatelessWidget {
  final CollectedMeme meme;
  const _MemeViewerPage({required this.meme});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          meme.countryLabel.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 13,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: SizedBox(
                width: double.infinity,
                child: Image.network(
                  meme.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (BuildContext context, Widget child,
                      ImageChunkEvent? p) {
                    if (p == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (BuildContext context, Object err,
                      StackTrace? _) {
                    return const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white54, size: 80),
                    );
                  },
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  meme.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Icon(Icons.forum,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'r/${meme.subreddit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_upward,
                        size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 2),
                    Text(
                      '${meme.ups}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '本回合 ${meme.score} 分',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: MatchdayPalette.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
