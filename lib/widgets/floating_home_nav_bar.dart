// =============================================================================
// FloatingHomeNavBar — 4-tab 浮動主導覽列
//
// 設計規格：
//   - 一個藥丸（capsule）形狀的浮動條，置中於畫面底部
//   - 四個 tab：排行榜、主頁、大廳、迷因搜集庫
//   - 目前頁面的 tab 用黑底白字高亮；其他 tab 淡色 / 透明
//   - 切 tab 會做「真的 page navigation」，不是 in-page tab
// =============================================================================

import 'package:flutter/material.dart';

import '../screens/leaderboard_page.dart';
import '../screens/lobby_page.dart';
import '../screens/meme_collection_page.dart';
import '../services/audio_service.dart';
import 'matchday_ui.dart';

enum HomeTab { leaderboard, home, lobby, memeLibrary }

class FloatingHomeNavBar extends StatelessWidget {
  final HomeTab current;

  const FloatingHomeNavBar({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    // 鍵盤開啟時隱藏，避免 bar 被往上擠到鍵盤上方。
    if (mq.viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }

    final double bottomSafe = mq.padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomSafe + 14,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
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
              icon: Icons.groups_outlined,
              label: '大廳',
              active: current == HomeTab.lobby,
              onTap: () => _navigate(context, HomeTab.lobby),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.collections_bookmark_outlined,
              label: '迷因庫',
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
      case HomeTab.lobby:
        _pushOrReplace(context, const LobbyPage());
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
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
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
