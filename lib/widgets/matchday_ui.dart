// =============================================================================
// matchday_ui.dart — 首頁 / 選模式頁共用的編輯風元件
//
// 把原本藏在 HomePage 裡面的 `_TopTicker`、`_FooterStripe`、`_SectionHeader`、
// `_AngleCornerClipper`、`_ModeFixtureCard` 抽出來做成 public 版，方便：
//   - HomePage：拿 TopTicker / FooterStripe / SectionHeader / AngleClip 來拼設定頁
//   - ModeSelectionPage：拿 ModeCard 排列三張 matchday 卡
//
// 命名：以 `Matchday` 作前綴，避免和一般通用元件混淆。
// =============================================================================

import 'package:flutter/material.dart';

// ---- 設計 token（跟 HomePage 共用的色票） ------------------------------------
class MatchdayPalette {
  MatchdayPalette._();
  static const Color ink = Color(0xFF101014);
  static const Color bg = Color(0xFFF1EDE6);
  static const Color cream = Color(0xFFFAF6EF);
  static const Color yellow = Color(0xFFFFD84D);
  static const Color pink = Color(0xFFFFB5BC);
  static const Color blue = Color(0xFFA7C5EC);
  static const Color green = Color(0xFFB4DFA8);
  static const Color accent = Color(0xFFFF3D57);
}

// =============================================================================
// 頂部黑條 ticker：LIVE 點 + 左側文字 + 右側 trailing 文字
// =============================================================================
class MatchdayTopTicker extends StatelessWidget {
  final String label;
  final String trailing;
  final Color ink;
  final Color accent;

  const MatchdayTopTicker({
    super.key,
    this.label = 'LIVE · MATCHDAY READY',
    this.trailing = 'ROUND 01',
    this.ink = MatchdayPalette.ink,
    this.accent = MatchdayPalette.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ink,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const Spacer(),
          Text(
            trailing,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 黑色 footer：品牌 + 版次標
// =============================================================================
class MatchdayFooterStripe extends StatelessWidget {
  final String brand;
  final String edition;
  final Color ink;
  const MatchdayFooterStripe({
    super.key,
    this.brand = 'LOLCATION',
    this.edition = '© MATCHDAY EDITION',
    this.ink = MatchdayPalette.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ink,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: <Widget>[
          Text(
            brand,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          Text(
            edition,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 編輯式小 section 標題：左邊一條黑槓 + 大字 + 選配 trailing 小字
// =============================================================================
class MatchdaySectionHeader extends StatelessWidget {
  final String label;
  final String? trailing;
  final Color ink;
  const MatchdaySectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.ink = MatchdayPalette.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: <Widget>[
          Container(width: 4, height: 16, color: ink),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: ink,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// 角切 ClipPath：把卡片的一角斜切掉，做出 editorial / poster 感
// =============================================================================
enum MatchdayCorner { topLeft, topRight, bottomLeft, bottomRight }

class MatchdayAngleCornerClipper extends CustomClipper<Path> {
  final double cut;
  final MatchdayCorner corner;
  const MatchdayAngleCornerClipper({
    required this.cut,
    required this.corner,
  });

  @override
  Path getClip(Size size) {
    final Path p = Path();
    switch (corner) {
      case MatchdayCorner.topRight:
        p
          ..moveTo(0, 0)
          ..lineTo(size.width - cut, 0)
          ..lineTo(size.width, cut)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        break;
      case MatchdayCorner.topLeft:
        p
          ..moveTo(cut, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..lineTo(0, cut)
          ..close();
        break;
      case MatchdayCorner.bottomRight:
        p
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height - cut)
          ..lineTo(size.width - cut, size.height)
          ..lineTo(0, size.height)
          ..close();
        break;
      case MatchdayCorner.bottomLeft:
        p
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(cut, size.height)
          ..lineTo(0, size.height - cut)
          ..close();
        break;
    }
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// =============================================================================
// Matchday 模式卡：彩色賽程卡（右上角斜切 + 粗框 + 大字）
// =============================================================================
class MatchdayModeCard extends StatelessWidget {
  final Color bg;
  final String index;
  final String kickoff;
  final String title;
  final String subtitle;
  final String tagline;
  final IconData icon;
  final VoidCallback onTap;
  final Color ink;

  const MatchdayModeCard({
    super.key,
    required this.bg,
    required this.index,
    required this.kickoff,
    required this.title,
    required this.subtitle,
    required this.tagline,
    required this.icon,
    required this.onTap,
    this.ink = MatchdayPalette.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipPath(
        clipper: const MatchdayAngleCornerClipper(
          cut: 36,
          corner: MatchdayCorner.topRight,
        ),
        child: Material(
          color: bg,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: ink, width: 2),
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    right: -10,
                    bottom: -24,
                    child: Icon(
                      icon,
                      size: 160,
                      color: ink.withValues(alpha: 0.08),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                index,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: ink.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                kickoff,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: -1,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Container(width: 2, height: 48, color: ink),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.5,
                                    color: ink.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 34,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.2,
                                    color: ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Container(width: 12, height: 2, color: ink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tagline,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                                color: ink,
                              ),
                            ),
                          ),
                          _KickoffPill(ink: ink),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KickoffPill extends StatelessWidget {
  final Color ink;
  const _KickoffPill({required this.ink});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: ink),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'KICKOFF',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward, color: Colors.white, size: 14),
        ],
      ),
    );
  }
}
