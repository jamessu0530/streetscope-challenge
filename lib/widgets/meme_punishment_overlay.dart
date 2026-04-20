// =============================================================================
// MemePunishmentOverlay
//
// 低分懲罰 UI。在 game_page 的 Map overlay 上面再疊一層半透明全螢幕層，
// 用幾乎整個螢幕的大小顯示 meme 圖（以全圖原比例呈現，不裁切）。
//
// 三個狀態：
//   1. loading：抓 meme 中 → 顯示 CircularProgressIndicator
//   2. loaded ＋ 有 meme：顯示全圖 + 標題 + sub / ups
//   3. loaded ＋ 沒抓到 meme：顯示嘲諷文字卡，避免空白
// =============================================================================

import 'package:flutter/material.dart';

import '../models/meme_result.dart';

class MemePunishmentOverlay extends StatelessWidget {
  final bool loading;
  final PunishmentMemeOutcome? outcome;
  final VoidCallback onDismiss;

  const MemePunishmentOverlay({
    super.key,
    required this.loading,
    required this.outcome,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.88),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                Expanded(child: _buildCard(context)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: loading ? null : onDismiss,
                    icon: const Icon(Icons.sentiment_very_dissatisfied),
                    label: const Text('我知道錯了 QQ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final int? score = outcome?.score;
    final String? country = outcome?.country;
    final String subtitle =
        country != null ? '目標國家：$country · 分數 $score' : '分數 $score';
    return Column(
      children: [
        const Text(
          '低分懲罰！',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    if (loading) {
      return const _MemeCardShell(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '正在從 Reddit 撿一張嘲諷你的 meme…',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final MemeResult? meme = outcome?.selectedMeme;
    if (meme == null) {
      return const _MemeCardShell(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sentiment_very_dissatisfied,
                    size: 88, color: Colors.deepOrange),
                SizedBox(height: 16),
                Text(
                  'Mission Failed.\n我們會再試一次，也許下次你會更像個地理學家。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _MemeCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: SizedBox(
                  width: double.infinity,
                  child: Image.network(
                    meme.imageUrl,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    loadingBuilder: (BuildContext context, Widget child,
                        ImageChunkEvent? progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (BuildContext context, Object error,
                        StackTrace? stack) {
                      return const Center(
                        child: Icon(Icons.broken_image,
                            size: 80, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meme.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.forum, size: 14, color: Colors.grey.shade600),
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
                    if (outcome?.fallbackUsed == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'fallback',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                          ),
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

class _MemeCardShell extends StatelessWidget {
  final Widget child;
  const _MemeCardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
