// =============================================================================
// LeaderboardPage — 8-bit 街機風高分榜
//
// 風格：復古街機高分看板；黑底、白色等寬字、掃描線 CRT、當下玩家黃色閃爍
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_mode.dart';
import '../models/game_region.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';
import '../widgets/floating_home_nav_bar.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

enum _Tab { top, recent }

class _LeaderboardPageState extends State<LeaderboardPage>
    with TickerProviderStateMixin {
  bool _loading = true;
  List<LeaderboardEntry> _all = <LeaderboardEntry>[];
  DateTime? _currentPlayedAt;
  _Tab _tab = _Tab.top;
  GameMode? _modeFilter;
  GameRegion? _regionFilter;

  late final AnimationController _countCtrl;
  late final AnimationController _blinkCtrl;

  // ---- 設計 token -----------------------------------------------------------
  static const Color _bg = Color(0xFF000000);
  static const Color _ink = Color(0xFFE8E8E8);
  static const Color _dim = Color(0xFF6A6A6A);
  static const Color _accent = Color(0xFFFFD400); // arcade yellow
  static const Color _green = Color(0xFF39FF14);
  static const Color _pink = Color(0xFFFF3EC9);
  static const List<String> _monoFallback = <String>[
    'Menlo',
    'Courier New',
    'Courier',
    'monospace',
  ];

  @override
  void initState() {
    super.initState();
    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final List<LeaderboardEntry> all = await LeaderboardService.instance.loadAll();
    DateTime? currentPlayedAt;
    for (final LeaderboardEntry e in all) {
      if (currentPlayedAt == null || e.playedAt.isAfter(currentPlayedAt)) {
        currentPlayedAt = e.playedAt;
      }
    }
    if (!mounted) return;
    setState(() {
      _all = all;
      _currentPlayedAt = currentPlayedAt;
      _loading = false;
    });
    _countCtrl.forward(from: 0);
  }

  List<LeaderboardEntry> get _rows {
    final Iterable<LeaderboardEntry> filtered = _all.where((LeaderboardEntry e) {
      final bool modeOk = _modeFilter == null || e.mode == _modeFilter;
      final bool regionOk = _regionFilter == null || e.region == _regionFilter;
      return modeOk && regionOk;
    });
    final List<LeaderboardEntry> rows = filtered.toList();
    if (_tab == _Tab.top) {
      rows.sort((LeaderboardEntry a, LeaderboardEntry b) {
        final int scoreCmp = b.totalScore.compareTo(a.totalScore);
        if (scoreCmp != 0) return scoreCmp;
        return b.playedAt.compareTo(a.playedAt);
      });
    } else {
      rows.sort(
        (LeaderboardEntry a, LeaderboardEntry b) =>
            b.playedAt.compareTo(a.playedAt),
      );
    }
    return rows.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: <Widget>[
            SafeArea(
              child: _loading
                  ? const Center(
                      child: Text(
                        'LOADING...',
                        style: TextStyle(
                          color: _dim,
                          fontSize: 14,
                          letterSpacing: 4,
                          fontFamily: 'Menlo',
                          fontFamilyFallback: _monoFallback,
                        ),
                      ),
                    )
                  : _buildBody(),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: _ScanlineOverlay(),
              ),
            ),
            const FloatingHomeNavBar(current: HomeTab.leaderboard),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: <Widget>[
        _buildTopBar(),
        const SizedBox(height: 8),
        _buildTitle(),
        const SizedBox(height: 8),
        _buildTabs(),
        const SizedBox(height: 8),
        _buildFilters(),
        const SizedBox(height: 10),
        _buildColumnHeaders(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            height: 1,
            color: _dim.withValues(alpha: 0.4),
          ),
        ),
        Expanded(child: _buildList()),
        _buildFooter(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: _ink, size: 20),
            tooltip: 'Back',
          ),
          const Spacer(),
          const Text(
            'ARCADE · v1',
            style: TextStyle(
              color: _dim,
              fontSize: 10,
              letterSpacing: 3,
              fontFamily: 'Menlo',
              fontFamilyFallback: _monoFallback,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: <Widget>[
          AnimatedBuilder(
            animation: _blinkCtrl,
            builder: (BuildContext context, _) {
              final double o = 0.55 + 0.45 * _blinkCtrl.value;
              return Text(
                '>>  INSERT COIN  <<',
                style: TextStyle(
                  color: _pink.withValues(alpha: o),
                  fontSize: 10,
                  letterSpacing: 4,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: _monoFallback,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          const _PixelGlowText(
            text: 'HIGH SCORES',
            color: _accent,
            glow: _accent,
            fontSize: 30,
            letterSpacing: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: <Widget>[
          Expanded(child: _tabButton('TOP 10', _Tab.top)),
          const SizedBox(width: 10),
          Expanded(child: _tabButton('RECENT', _Tab.recent)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _Tab value) {
    final bool active = _tab == value;
    return GestureDetector(
      onTap: () {
        if (_tab == value) return;
        setState(() => _tab = value);
        _countCtrl.forward(from: 0);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: active ? _green : _dim, width: 1),
          color: active ? _green.withValues(alpha: 0.08) : Colors.transparent,
        ),
        child: Text(
          active ? '[ $label ]' : '  $label  ',
          style: TextStyle(
            color: active ? _green : _dim,
            fontSize: 11,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w800,
            fontFamily: 'Menlo',
            fontFamilyFallback: _monoFallback,
          ),
        ),
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, 6),
      child: DefaultTextStyle(
        style: TextStyle(
          color: _dim,
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w800,
          fontFamily: 'Menlo',
          fontFamilyFallback: _monoFallback,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(width: 58, child: Text('RANK')),
            SizedBox(width: 110, child: Text('NAME')),
            Expanded(
              child: Text('SCORE', textAlign: TextAlign.right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _filterChip(
                  label: 'ALL MODES',
                  selected: _modeFilter == null,
                  onTap: () => _setModeFilter(null),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'MOVE',
                  selected: _modeFilter == GameMode.move,
                  onTap: () => _setModeFilter(GameMode.move),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'NO MOVE',
                  selected: _modeFilter == GameMode.noMove,
                  onTap: () => _setModeFilter(GameMode.noMove),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  label: 'PICTURE',
                  selected: _modeFilter == GameMode.picture,
                  onTap: () => _setModeFilter(GameMode.picture),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _filterChip(
                  label: 'ALL REGIONS',
                  selected: _regionFilter == null,
                  onTap: () => _setRegionFilter(null),
                ),
                ...GameRegion.values.map((GameRegion region) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _filterChip(
                      label: region.label.toUpperCase(),
                      selected: _regionFilter == region,
                      onTap: () => _setRegionFilter(region),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? _accent : _dim, width: 1),
          color: selected ? _accent.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Text(
          selected ? '[ $label ]' : '  $label  ',
          style: TextStyle(
            color: selected ? _accent : _dim,
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
            fontFamily: 'Menlo',
            fontFamilyFallback: _monoFallback,
          ),
        ),
      ),
    );
  }

  void _setModeFilter(GameMode? mode) {
    if (_modeFilter == mode) return;
    setState(() => _modeFilter = mode);
    _countCtrl.forward(from: 0);
  }

  void _setRegionFilter(GameRegion? region) {
    if (_regionFilter == region) return;
    setState(() => _regionFilter = region);
    _countCtrl.forward(from: 0);
  }

  Widget _buildList() {
    if (_rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'NO RECORDS.\nPLAY A ROUND.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _dim,
              fontSize: 12,
              height: 1.8,
              letterSpacing: 2,
              fontFamily: 'Menlo',
              fontFamilyFallback: _monoFallback,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _rows.length,
      itemBuilder: (BuildContext context, int index) {
        final LeaderboardEntry e = _rows[index];
        final bool isCurrent = _currentPlayedAt != null &&
            e.playedAt.millisecondsSinceEpoch ==
                _currentPlayedAt!.millisecondsSinceEpoch;
        return _ScoreRow(
          index: index,
          entry: e,
          isCurrent: isCurrent,
          countCtrl: _countCtrl,
          blinkCtrl: _blinkCtrl,
          monoFallback: _monoFallback,
          ink: _ink,
          dim: _dim,
          accent: _accent,
          green: _green,
        );
      },
    );
  }

  Widget _buildFooter() {
    final int total = _rows.length;
    // 多留 96 給底部浮動 nav bar，避免文字被蓋到
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + 96 + MediaQuery.of(context).padding.bottom,
      ),
      child: AnimatedBuilder(
        animation: _blinkCtrl,
        builder: (BuildContext context, _) {
          final bool on = _blinkCtrl.value > 0.5;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'PLAYS $total',
                style: const TextStyle(
                  color: _dim,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: _monoFallback,
                ),
              ),
              Text(
                on ? 'PRESS  START' : '            ',
                style: const TextStyle(
                  color: _green,
                  fontSize: 10,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: _monoFallback,
                ),
              ),
              const Text(
                '(C) 2026',
                style: TextStyle(
                  color: _dim,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: _monoFallback,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// 單列分數 row，支援 count-up + 當前玩家黃色閃爍
// =============================================================================
class _ScoreRow extends StatelessWidget {
  final int index;
  final LeaderboardEntry entry;
  final bool isCurrent;
  final Animation<double> countCtrl;
  final Animation<double> blinkCtrl;
  final List<String> monoFallback;
  final Color ink;
  final Color dim;
  final Color accent;
  final Color green;

  const _ScoreRow({
    required this.index,
    required this.entry,
    required this.isCurrent,
    required this.countCtrl,
    required this.blinkCtrl,
    required this.monoFallback,
    required this.ink,
    required this.dim,
    required this.accent,
    required this.green,
  });

  @override
  Widget build(BuildContext context) {
    final String rank = _ordinal(index + 1);
    final String name = entry.name.toUpperCase();
    // 每 row 按順序加入 count-up 階段
    final double rowStart = (index * 0.06).clamp(0.0, 0.9);
    final double rowEnd = (rowStart + 0.35).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[countCtrl, blinkCtrl]),
      builder: (BuildContext context, _) {
        final double raw =
            ((countCtrl.value - rowStart) / (rowEnd - rowStart)).clamp(0.0, 1.0);
        final double t = Curves.easeOutCubic.transform(raw);
        final int animatedScore = (entry.totalScore * t).round();

        final Color textColor;
        final double opacity;
        if (isCurrent) {
          final double pulse = 0.6 + 0.4 * blinkCtrl.value;
          textColor = accent;
          opacity = pulse;
        } else {
          textColor = ink;
          opacity = 1;
        }

        final Widget content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 58,
                child: Text(
                  rank,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Menlo',
                    fontFamilyFallback: monoFallback,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: _MarqueeName(
                  text: name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Menlo',
                    fontFamilyFallback: monoFallback,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _padScore(animatedScore),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Menlo',
                    fontFamilyFallback: monoFallback,
                  ),
                ),
              ),
              if (isCurrent) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  blinkCtrl.value > 0.5 ? '◄' : ' ',
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Menlo',
                    fontFamilyFallback: monoFallback,
                  ),
                ),
              ],
            ],
          ),
        );

        return Opacity(
          opacity: opacity,
          child: content,
        );
      },
    );
  }

  String _ordinal(int n) {
    final int mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${n}TH';
    switch (n % 10) {
      case 1:
        return '${n}ST';
      case 2:
        return '${n}ND';
      case 3:
        return '${n}RD';
      default:
        return '${n}TH';
    }
  }

  String _padScore(int score) {
    // 6 位填 0，街機味
    final String s = score.toString();
    if (s.length >= 6) return s;
    return s.padLeft(6, '0');
  }

}

class _MarqueeName extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeName({
    required this.text,
    required this.style,
  });

  @override
  State<_MarqueeName> createState() => _MarqueeNameState();
}

class _MarqueeNameState extends State<_MarqueeName>
    with SingleTickerProviderStateMixin {
  static const double _gap = 24;
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final double textWidth = painter.width;
        final double boxWidth = constraints.maxWidth;
        final double overflow = textWidth - boxWidth;

        if (overflow <= 0) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (BuildContext context, _) {
              final double loopWidth = textWidth + _gap;
              final double dx = -loopWidth * _ctrl.value;
              return SizedBox(
                height: painter.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(
                      left: dx,
                      top: 0,
                      child: SizedBox(
                        width: textWidth,
                        child: Text(
                          widget.text,
                          maxLines: 1,
                          softWrap: false,
                          style: widget.style,
                        ),
                      ),
                    ),
                    Positioned(
                      left: dx + loopWidth,
                      top: 0,
                      child: SizedBox(
                        width: textWidth,
                        child: Text(
                          widget.text,
                          maxLines: 1,
                          softWrap: false,
                          style: widget.style,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// =============================================================================
// 像素字標題 + 發光
// =============================================================================
class _PixelGlowText extends StatelessWidget {
  final String text;
  final Color color;
  final Color glow;
  final double fontSize;
  final double letterSpacing;

  const _PixelGlowText({
    required this.text,
    required this.color,
    required this.glow,
    required this.fontSize,
    required this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w900,
        fontFamily: 'Menlo',
        fontFamilyFallback: const <String>[
          'Menlo',
          'Courier New',
          'Courier',
          'monospace',
        ],
        shadows: <Shadow>[
          Shadow(color: glow.withValues(alpha: 0.9), blurRadius: 0, offset: Offset.zero),
          Shadow(color: glow.withValues(alpha: 0.45), blurRadius: 12),
          Shadow(color: glow.withValues(alpha: 0.22), blurRadius: 24),
        ],
      ),
    );
  }
}

// =============================================================================
// CRT 掃描線覆層
// =============================================================================
class _ScanlineOverlay extends StatelessWidget {
  const _ScanlineOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScanlinePainter(),
      size: Size.infinite,
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()..color = Colors.white.withValues(alpha: 0.04);
    const double gap = 3;
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
    // vignette 四角略暗
    final Paint vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: <Color>[
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35),
        ],
        stops: const <double>[0.7, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) => false;
}
