// =============================================================================
// FloatingHomeNavBar — 3-tab 浮動主導覽列
//
// 設計規格：
//   - 一個藥丸（capsule）形狀的浮動條，置中於畫面底部
//   - 三個 tab：左=排行榜、中=主頁、右=迷因搜集庫
//   - 目前頁面的 tab 用黑底白字高亮；其他 tab 淡色 / 透明
//   - 切 tab 會做「真的 page navigation」，不是 in-page tab
//
// 用法：
//   在任何頁面的 Scaffold body (Stack) 裡，放入：
//     const FloatingHomeNavBar(current: HomeTab.home)
//   並確保頁面內容的底部有足夠 padding（約 110）讓內容不會被遮住。
//
// 導覽行為（避免 push 無限堆疊）：
//   - 點「主頁」：popUntil 回到第一個 route（HomePage 永遠是 root）
//   - 從主頁 push 到 Leaderboard / MemeLibrary：用 push（保留返回鍵）
//   - 從 Leaderboard <-> MemeLibrary：用 pushReplacement（不堆疊）
// =============================================================================

import 'package:flutter/material.dart';

import '../screens/leaderboard_page.dart';
import '../screens/meme_collection_page.dart';
import '../services/audio_service.dart';
import 'matchday_ui.dart';

enum HomeTab { leaderboard, home, memeLibrary }

class FloatingHomeNavBar extends StatelessWidget {
  final HomeTab current;

  const FloatingHomeNavBar({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final double bottomSafe = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomSafe + 14,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _NavPill(current: current),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 主膠囊容器：米白底 / 黑邊 / 陰影 / 3 等分 tab
// =============================================================================
class _NavPill extends StatelessWidget {
  final HomeTab current;
  const _NavPill({required this.current});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: MatchdayPalette.cream,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: MatchdayPalette.ink, width: 1.5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _NavItem(
              icon: Icons.leaderboard_outlined,
              label: '排行榜',
              active: current == HomeTab.leaderboard,
              onTap: () => _navigate(context, HomeTab.leaderboard),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              label: '主頁',
              active: current == HomeTab.home,
              onTap: () => _navigate(context, HomeTab.home),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.collections_bookmark_outlined,
              label: '迷因搜集庫',
              active: current == HomeTab.memeLibrary,
              onTap: () => _navigate(context, HomeTab.memeLibrary),
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, HomeTab target) {
    if (target == current) return;
    AudioService.instance.playClick();

    switch (target) {
      case HomeTab.home:
        // 主頁永遠是 root，直接 popUntil 回去即可。
        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        break;
      case HomeTab.leaderboard:
        _pushOrReplace(context, const LeaderboardPage());
        break;
      case HomeTab.memeLibrary:
        _pushOrReplace(context, const MemeCollectionPage());
        break;
    }
  }

  /// 從主頁出發：用 push（保留返回鍵可回主頁）。
  /// 從其他次要頁（Leaderboard / MemeLibrary）互切：用 pushReplacement，
  /// 避免堆疊出 Home → Leaderboard → MemeLibrary → Leaderboard…。
  void _pushOrReplace(BuildContext context, Widget page) {
    final Route<void> route = PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, Animation<double> a, __, Widget child) {
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );

    if (current == HomeTab.home) {
      Navigator.of(context).push(route);
    } else {
      Navigator.of(context).pushReplacement(route);
    }
  }
}

// =============================================================================
// 單一 tab：AnimatedContainer 做高亮滑移 + 顏色漸變
// =============================================================================
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: active ? MatchdayPalette.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: active ? Colors.white : Colors.black54,
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 240),
                  style: TextStyle(
                    color: active ? Colors.white : Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                  child: Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
