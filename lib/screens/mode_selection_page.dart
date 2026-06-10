// =============================================================================
// ModeSelectionPage — 「選模式」頁（Premium Experimental Redesign）
//
// 流程不變：HomePage → ModeSelectionPage（挑模式 + VS AI + 強度）→ GamePage
//
// 設計方向：
//   Liquid gradient + organic geometry + editorial typography + generative art。
//   暖白紙質背景 + 顆粒噪點、有機框、液態拉桿、可收藏感模式卡。
//   不使用 glassmorphism / neumorphism / 標準圓角卡。
//
// 功能完整保留：返回、TEAM SHEET（Region/Rounds/Time/Moves）、VS AI 開關、
//   AI 強度（弱/中/強）、三模式啟動、BGM 生命週期。
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ai_strength.dart';
import '../models/game_mode.dart';
import '../models/game_region.dart';
import '../models/game_settings.dart';
import '../services/audio_service.dart';
import 'game_page.dart';

// ---- 新色票（warm paper + 多彩 accent） -------------------------------------
class _Palette {
  _Palette._();
  static const Color bg = Color(0xFFF5F2ED);
  static const Color paper = Color(0xFFFBF8F2);
  static const Color ink = Color(0xFF211C17); // 暖近黑
  static const Color inkSoft = Color(0xFF8A8178); // 描述用淺灰

  static const Color red = Color(0xFFFF5A5F);
  static const Color blue = Color(0xFF4D8CFF);
  static const Color yellow = Color(0xFFFFD84D);
  static const Color green = Color(0xFF7CCB7A);
  static const Color pink = Color(0xFFFF9BD5);
}

// 有機（不對稱圓角）形狀。
BorderRadius _organic(double a, double b) => BorderRadius.only(
      topLeft: Radius.circular(a),
      topRight: Radius.circular(b),
      bottomRight: Radius.circular(a),
      bottomLeft: Radius.circular(b),
    );

class ModeSelectionPage extends StatefulWidget {
  final GameSettings baseSettings;
  const ModeSelectionPage({super.key, required this.baseSettings});

  @override
  State<ModeSelectionPage> createState() => _ModeSelectionPageState();
}

class _ModeSelectionPageState extends State<ModeSelectionPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _vsAi = false;
  AiStrength _aiStrength = AiStrength.medium;
  bool _launching = false;

  // 環境動畫：驅動背景漸層飄動、邊框流動、卡片浮動。
  late final AnimationController _ambient;

  // 紙質噪點（一次性產生，正規化座標）。
  final List<Offset> _grain = <Offset>[];
  final List<double> _grainAlpha = <double>[];

  // 背景液態色塊（正規化中心）。
  late final List<_Blob> _blobs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioService.instance.startHomeBgm();

    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    final math.Random r = math.Random(42);
    for (int i = 0; i < 900; i++) {
      _grain.add(Offset(r.nextDouble(), r.nextDouble()));
      _grainAlpha.add(0.012 + r.nextDouble() * 0.045);
    }

    _blobs = const <_Blob>[
      _Blob(nx: 0.12, ny: 0.08, radius: 0.55, color: _Palette.red, phase: 0.0),
      _Blob(nx: 0.92, ny: 0.20, radius: 0.5, color: _Palette.blue, phase: 1.4),
      _Blob(nx: 0.85, ny: 0.92, radius: 0.55, color: _Palette.green, phase: 2.6),
      _Blob(nx: 0.1, ny: 0.86, radius: 0.5, color: _Palette.yellow, phase: 3.9),
      _Blob(nx: 0.5, ny: 0.5, radius: 0.6, color: _Palette.pink, phase: 5.1),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ambient.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AudioService.instance.pauseHomeBgm();
    } else if (state == AppLifecycleState.resumed && mounted) {
      AudioService.instance.resumeHomeBgm();
    }
  }

  Future<void> _launch(GameMode mode) async {
    if (_launching) return;
    setState(() => _launching = true);
    AudioService.instance.playClick();
    try {
      final GameSettings settings = widget.baseSettings.copyWith(
        mode: mode,
        maxMoveSteps:
            mode == GameMode.move ? widget.baseSettings.maxMoveSteps : 0,
        vsAi: _vsAi,
        aiStrength: _aiStrength,
      );
      await AudioService.instance.stopHomeBgm();
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (BuildContext context) => GamePage(settings: settings),
        ),
      );
      if (!mounted) return;
      AudioService.instance.startHomeBgm();
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GameSettings s = widget.baseSettings;
    final double bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _Palette.bg,
      body: Stack(
        children: <Widget>[
          // ---- 背景：液態色塊（動）+ 紙質噪點（靜）
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (BuildContext context, _) {
                  return CustomPaint(
                    painter: _BlobsPainter(_ambient.value, _blobs),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GrainPainter(_grain, _grainAlpha),
              ),
            ),
          ),

          // ---- 內容
          SafeArea(
            bottom: false,
            child: AbsorbPointer(
              absorbing: _launching,
              child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TopBar(
                      onBack: () {
                        AudioService.instance.playClick();
                        Navigator.maybePop(context);
                      },
                    ),
                    const SizedBox(height: 22),
                    const _Hero(),
                    const SizedBox(height: 26),
                    _TeamSheetPanel(settings: s),
                    const SizedBox(height: 18),
                    _VsAiPanel(
                      ambient: _ambient,
                      value: _vsAi,
                      onChanged: (bool v) {
                        AudioService.instance.playClick();
                        setState(() => _vsAi = v);
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: _vsAi
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: _LiquidStrengthSlider(
                                strength: _aiStrength,
                                onChanged: (AiStrength v) {
                                  AudioService.instance.playClick();
                                  setState(() => _aiStrength = v);
                                },
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: 28),
                    const _SectionRule(label: 'SELECT FIXTURE'),
                    const SizedBox(height: 16),
                    _ModeCard(
                      ambient: _ambient,
                      phase: 0.0,
                      index: '01',
                      title: 'MOVE',
                      subtitle: '完整模式',
                      tagline: 'WALK THE STREETS',
                      icon: Icons.directions_walk_rounded,
                      c1: _Palette.red,
                      c2: _Palette.pink,
                      onTap: () => _launch(GameMode.move),
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      ambient: _ambient,
                      phase: 2.1,
                      index: '02',
                      title: 'NO MOVE',
                      subtitle: '鏡頭旋轉',
                      tagline: 'STAND & OBSERVE',
                      icon: Icons.threesixty_rounded,
                      c1: _Palette.blue,
                      c2: const Color(0xFF8FB8FF),
                      onTap: () => _launch(GameMode.noMove),
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      ambient: _ambient,
                      phase: 4.2,
                      index: '03',
                      title: 'PICTURE',
                      subtitle: '完全靜態',
                      tagline: 'ONE SHOT · NO MOVES',
                      icon: Icons.image_rounded,
                      c1: _Palette.green,
                      c2: const Color(0xFFAEE3A6),
                      onTap: () => _launch(GameMode.picture),
                    ),
                    SizedBox(height: 28 + bottomSafe),
                    const _Footer(),
                    SizedBox(height: 16 + bottomSafe),
                  ],
                ),
              ),
            ),
            ),
          ),
          if (_launching)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// 頂部：漸變外框 BACK pill + STEP 標
// =============================================================================
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _GradientOutlinePill(
          onTap: onBack,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.arrow_back_rounded, size: 15, color: _Palette.ink),
              SizedBox(width: 6),
              Text(
                'BACK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: _Palette.ink,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'STEP · 02 / 02',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
            color: _Palette.inkSoft.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Hero：超大編輯式標題 PICK YOUR MATCHDAY.
// =============================================================================
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[_Palette.red, _Palette.pink],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'LIVE · PICK YOUR MATCHDAY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'PICK YOUR',
            style: TextStyle(
              fontSize: 74,
              height: 0.9,
              letterSpacing: -3.5,
              fontWeight: FontWeight.w900,
              color: _Palette.ink,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              ShaderMask(
                shaderCallback: (Rect b) => const LinearGradient(
                  colors: <Color>[_Palette.ink, _Palette.ink],
                ).createShader(b),
                child: const Text(
                  'MATCHDAY',
                  style: TextStyle(
                    fontSize: 74,
                    height: 0.9,
                    letterSpacing: -3.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              ShaderMask(
                shaderCallback: (Rect b) => const LinearGradient(
                  colors: <Color>[_Palette.red, _Palette.pink],
                ).createShader(b),
                child: const Text(
                  '.',
                  style: TextStyle(
                    fontSize: 74,
                    height: 0.9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 26,
              height: 3,
              margin: const EdgeInsets.only(top: 7, right: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[_Palette.red, _Palette.yellow],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Expanded(
              child: Text(
                'SETUP LOCKED IN.\nNOW CHOOSE HOW YOU PLAY.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: _Palette.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// TEAM SHEET：有機框 + 漸層邊緣，內含 Region / Rounds / Time / Moves
// =============================================================================
class _TeamSheetPanel extends StatelessWidget {
  final GameSettings settings;
  const _TeamSheetPanel({required this.settings});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = _organic(30, 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _MiniLabel(label: 'TEAM SHEET', trailing: 'FROM SETUP'),
        const SizedBox(height: 10),
        CustomPaint(
          painter: _PanelPainter(
            radius: radius,
            fill: _Palette.paper,
            strokeGradient: const LinearGradient(
              colors: <Color>[_Palette.red, _Palette.pink, _Palette.blue],
            ),
            strokeWidth: 2.4,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              children: <Widget>[
                _RecapRow(label: 'REGION', value: settings.region.label),
                const _RecapDivider(),
                _RecapRow(label: 'ROUNDS', value: '${settings.roundsPerGame}'),
                const _RecapDivider(),
                _RecapRow(
                  label: 'TIME',
                  value: '${settings.secondsPerRound}s / round',
                ),
                const _RecapDivider(),
                _RecapRow(
                  label: 'MOVES',
                  value: settings.maxMoveSteps == 0
                      ? '∞ (MOVE mode)'
                      : '${settings.maxMoveSteps} steps (MOVE mode)',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecapRow extends StatelessWidget {
  final String label;
  final String value;
  const _RecapRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: _Palette.inkSoft,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: _Palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapDivider extends StatelessWidget {
  const _RecapDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: _Palette.ink.withValues(alpha: 0.08),
    );
  }
}

// =============================================================================
// VS AI：premium 面板。開啟時動態漸層邊框 + 柔光。
// =============================================================================
class _VsAiPanel extends StatelessWidget {
  final AnimationController ambient;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _VsAiPanel({
    required this.ambient,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = _organic(26, 14);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedBuilder(
        animation: ambient,
        builder: (BuildContext context, Widget? child) {
          final Gradient stroke = value
              ? SweepGradient(
                  colors: const <Color>[
                    _Palette.red,
                    _Palette.pink,
                    _Palette.blue,
                    _Palette.green,
                    _Palette.red,
                  ],
                  transform: GradientRotation(ambient.value * 2 * math.pi),
                )
              : LinearGradient(
                  colors: <Color>[
                    _Palette.ink.withValues(alpha: 0.18),
                    _Palette.ink.withValues(alpha: 0.18),
                  ],
                );
          return CustomPaint(
            painter: _PanelPainter(
              radius: radius,
              fill: value ? const Color(0xFF221C28) : _Palette.paper,
              strokeGradient: stroke,
              strokeWidth: value ? 2.8 : 1.6,
              glow: value,
            ),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          child: Row(
            children: <Widget>[
              _AiGlyph(active: value),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'VS AI',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: value ? Colors.white : _Palette.ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (value)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[_Palette.pink, _Palette.blue],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'GEMINI',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value ? 'GEMINI 會看街景圖跟你同場較量' : '開啟後與 Gemini AI 對戰',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: value
                            ? Colors.white.withValues(alpha: 0.7)
                            : _Palette.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              _LiquidToggle(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

// AI 圖示：開啟時彩色漸層圓底。
class _AiGlyph extends StatelessWidget {
  final bool active;
  const _AiGlyph({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[_Palette.pink, _Palette.blue],
              )
            : null,
        color: active ? null : _Palette.ink.withValues(alpha: 0.06),
        borderRadius: _organic(16, 8),
      ),
      child: Icon(
        Icons.smart_toy_rounded,
        size: 22,
        color: active ? Colors.white : _Palette.inkSoft,
      ),
    );
  }
}

// 自訂液態開關（取代 Material Switch）。
class _LiquidToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _LiquidToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: value
              ? const LinearGradient(
                  colors: <Color>[_Palette.pink, _Palette.blue],
                )
              : null,
          color: value ? null : _Palette.ink.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 液態 AI 強度拉桿（弱→黃、中→粉、強→藍）
// =============================================================================
class _LiquidStrengthSlider extends StatefulWidget {
  final AiStrength strength;
  final ValueChanged<AiStrength> onChanged;

  const _LiquidStrengthSlider({
    required this.strength,
    required this.onChanged,
  });

  @override
  State<_LiquidStrengthSlider> createState() => _LiquidStrengthSliderState();
}

class _LiquidStrengthSliderState extends State<_LiquidStrengthSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _dragging = false;

  static const double _thumbR = 17;
  static const double _trackH = 22;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1,
      value: widget.strength.index / 2,
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant _LiquidStrengthSlider old) {
    super.didUpdateWidget(old);
    if (!_dragging && widget.strength != old.strength) {
      _c.animateTo(
        widget.strength.index / 2,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static Color colorAt(double t) {
    if (t <= 0.5) {
      return Color.lerp(_Palette.yellow, _Palette.pink, t / 0.5)!;
    }
    return Color.lerp(_Palette.pink, _Palette.blue, (t - 0.5) / 0.5)!;
  }

  double _toFraction(double dx, double width) {
    final double usable = width - _thumbR * 2;
    return ((dx - _thumbR) / usable).clamp(0.0, 1.0);
  }

  void _snapAndReport() {
    final int idx = (_c.value * 2).round().clamp(0, 2);
    _c.animateTo(
      idx / 2,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    final AiStrength next = AiStrengthX.fromIndex(idx);
    if (next != widget.strength) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = _organic(24, 16);
    return CustomPaint(
      painter: _PanelPainter(
        radius: radius,
        fill: _Palette.paper,
        strokeGradient: const LinearGradient(
          colors: <Color>[_Palette.yellow, _Palette.pink, _Palette.blue],
        ),
        strokeWidth: 2.2,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.tune_rounded, size: 18, color: _Palette.ink),
                const SizedBox(width: 8),
                const Text(
                  'AI 智能強度',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: _Palette.ink,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorAt(_c.value),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.strength.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double w = c.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _dragging = true,
                  onTapDown: (TapDownDetails d) {
                    _c.value = _toFraction(d.localPosition.dx, w);
                  },
                  onTapUp: (_) => _snapAndReport(),
                  onHorizontalDragUpdate: (DragUpdateDetails d) {
                    _c.stop();
                    _c.value = _toFraction(d.localPosition.dx, w);
                  },
                  onHorizontalDragEnd: (_) {
                    _dragging = false;
                    _snapAndReport();
                  },
                  child: SizedBox(
                    height: _trackH + 18,
                    width: w,
                    child: CustomPaint(
                      painter: _SliderPainter(
                        t: _c.value,
                        thumbR: _thumbR,
                        trackH: _trackH,
                      ),
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _tick('弱', AiStrength.weak, _Palette.yellow),
                  _tick('中', AiStrength.medium, _Palette.pink),
                  _tick('強', AiStrength.strong, _Palette.blue),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.strength.description,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: _Palette.inkSoft,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Picture 模式不受強弱影響',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _Palette.inkSoft.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tick(String label, AiStrength s, Color color) {
    final bool active = widget.strength == s;
    return GestureDetector(
      onTap: () {
        if (s != widget.strength) widget.onChanged(s);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            color: active ? color : _Palette.inkSoft.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 模式卡：大型有機容器 + 各自漸層識別 + 生成式背景圖形
// =============================================================================
class _ModeCard extends StatelessWidget {
  final AnimationController ambient;
  final double phase;
  final String index;
  final String title;
  final String subtitle;
  final String tagline;
  final IconData icon;
  final Color c1;
  final Color c2;
  final VoidCallback onTap;

  const _ModeCard({
    required this.ambient,
    required this.phase,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.tagline,
    required this.icon,
    required this.c1,
    required this.c2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = _organic(34, 16);
    return AnimatedBuilder(
      animation: ambient,
      builder: (BuildContext context, Widget? child) {
        final double dy =
            math.sin(ambient.value * 2 * math.pi + phase) * 3.0;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: _Pressable(
        onTap: onTap,
        child: CustomPaint(
          painter: _ModeCardPainter(radius: radius, c1: c1, c2: c2),
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              height: 138,
              child: Stack(
                children: <Widget>[
                  // 生成式大圖示（淡）
                  Positioned(
                    right: -16,
                    bottom: -28,
                    child: Icon(
                      icon,
                      size: 168,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              index,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.5,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 40,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.6,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                tagline,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                              ),
                            ),
                            const _PlayPill(),
                          ],
                        ),
                      ],
                    ),
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

// 卡片內的「PLAY」膠囊（白底 + 箭頭）。
class _PlayPill extends StatelessWidget {
  const _PlayPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'PLAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: _Palette.ink,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 15, color: _Palette.ink),
        ],
      ),
    );
  }
}

// 按下縮放：tactile 觸感。
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// 通用：漸層外框 pill 按鈕
// =============================================================================
class _GradientOutlinePill extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _GradientOutlinePill({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[_Palette.red, _Palette.blue],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _Palette.bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// 小 section 標籤（左漸層槓 + 字）。
class _MiniLabel extends StatelessWidget {
  final String label;
  final String? trailing;
  const _MiniLabel({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 4,
          height: 15,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[_Palette.red, _Palette.pink],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: _Palette.ink,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
              color: _Palette.inkSoft,
            ),
          ),
      ],
    );
  }
}

// SELECT FIXTURE：標題 + 漸層細線。
class _SectionRule extends StatelessWidget {
  final String label;
  const _SectionRule({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: _Palette.ink,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'TAP TO START',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: _Palette.inkSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 3,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[
                _Palette.red,
                _Palette.pink,
                _Palette.yellow,
                _Palette.green,
                _Palette.blue,
              ],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Text(
          'LOLCATION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: _Palette.ink,
          ),
        ),
        Spacer(),
        Text(
          '© MATCHDAY EDITION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: _Palette.inkSoft,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Painters
// =============================================================================
class _Blob {
  final double nx;
  final double ny;
  final double radius;
  final Color color;
  final double phase;
  const _Blob({
    required this.nx,
    required this.ny,
    required this.radius,
    required this.color,
    required this.phase,
  });
}

class _BlobsPainter extends CustomPainter {
  final double t;
  final List<_Blob> blobs;
  _BlobsPainter(this.t, this.blobs);

  @override
  void paint(Canvas canvas, Size size) {
    const double drift = 22;
    for (final _Blob b in blobs) {
      final double cx =
          b.nx * size.width + math.sin(t * 2 * math.pi + b.phase) * drift;
      final double cy =
          b.ny * size.height + math.cos(t * 2 * math.pi + b.phase) * drift;
      final double radius = b.radius * size.width;
      final Rect rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
      final Paint p = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            b.color.withValues(alpha: 0.18),
            b.color.withValues(alpha: 0.0),
          ],
        ).createShader(rect);
      canvas.drawCircle(Offset(cx, cy), radius, p);
    }
  }

  @override
  bool shouldRepaint(covariant _BlobsPainter old) => old.t != t;
}

class _GrainPainter extends CustomPainter {
  final List<Offset> pts;
  final List<double> alphas;
  _GrainPainter(this.pts, this.alphas);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint();
    for (int i = 0; i < pts.length; i++) {
      p.color = _Palette.ink.withValues(alpha: alphas[i]);
      canvas.drawRect(
        Rect.fromLTWH(pts[i].dx * size.width, pts[i].dy * size.height, 1.2, 1.2),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => false;
}

// 有機面板：填色 + 漸層描邊（+ 可選柔光）。
class _PanelPainter extends CustomPainter {
  final BorderRadius radius;
  final Color fill;
  final Gradient strokeGradient;
  final double strokeWidth;
  final bool glow;

  _PanelPainter({
    required this.radius,
    required this.fill,
    required this.strokeGradient,
    required this.strokeWidth,
    this.glow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rr = radius.toRRect(rect);

    if (glow) {
      final Paint g = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..shader = strokeGradient.createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRRect(rr, g);
    }

    canvas.drawRRect(rr, Paint()..color = fill);

    final Paint sp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = strokeGradient.createShader(rect);
    canvas.drawRRect(rr.deflate(strokeWidth / 2), sp);
  }

  @override
  bool shouldRepaint(covariant _PanelPainter old) =>
      old.fill != fill ||
      old.strokeWidth != strokeWidth ||
      old.glow != glow ||
      old.strokeGradient != strokeGradient;
}

// 模式卡：漸層填底 + 生成式形狀 + 底部可讀性 scrim + 漸層描邊。
class _ModeCardPainter extends CustomPainter {
  final BorderRadius radius;
  final Color c1;
  final Color c2;
  _ModeCardPainter({required this.radius, required this.c1, required this.c2});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rr = radius.toRRect(rect);
    canvas.save();
    canvas.clipRRect(rr);

    // 主漸層
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[c1, c2],
        ).createShader(rect),
    );

    // 生成式柔形（白色低 alpha）
    final Paint soft = Paint()..color = Colors.white.withValues(alpha: 0.1);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.1), 60, soft);
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.85),
      90,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = Colors.white.withValues(alpha: 0.1);
    canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.2), 70, arc);

    // 底部可讀性 scrim（不是重陰影，只是柔暗化文字區）
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.22),
          ],
        ).createShader(rect),
    );
    canvas.restore();

    // 漸層描邊（提亮邊緣）
    final Paint sp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.15),
        ],
      ).createShader(rect);
    canvas.drawRRect(rr.deflate(1), sp);
  }

  @override
  bool shouldRepaint(covariant _ModeCardPainter old) =>
      old.c1 != c1 || old.c2 != c2;
}

// 液態拉桿：粗圓軌 + 漸層進度 + 發光液泡 thumb。
class _SliderPainter extends CustomPainter {
  final double t;
  final double thumbR;
  final double trackH;
  _SliderPainter({
    required this.t,
    required this.thumbR,
    required this.trackH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cy = size.height / 2;
    final double left = thumbR;
    final double right = size.width - thumbR;
    final double usable = right - left;
    final double thumbX = left + usable * t;
    final Color cur = _LiquidStrengthSliderState.colorAt(t);

    // 軌道底
    final RRect track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, cy - trackH / 2, size.width, trackH),
      Radius.circular(trackH),
    );
    canvas.drawRRect(
      track,
      Paint()..color = _Palette.ink.withValues(alpha: 0.08),
    );

    // 進度漸層填色
    final Rect fillRect = Rect.fromLTWH(
      0,
      cy - trackH / 2,
      thumbX + thumbR * 0.4,
      trackH,
    );
    if (fillRect.width > 0) {
      final RRect fill = RRect.fromRectAndRadius(
        fillRect,
        Radius.circular(trackH),
      );
      canvas.drawRRect(
        fill,
        Paint()
          ..shader = LinearGradient(
            colors: <Color>[_Palette.yellow, cur],
          ).createShader(fillRect),
      );
    }

    // 三個停靠刻度點
    for (int i = 0; i < 3; i++) {
      final double x = left + usable * (i / 2);
      canvas.drawCircle(
        Offset(x, cy),
        2.4,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }

    // thumb 外發光（柔光，非重陰影）
    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbR + 7,
      Paint()
        ..color = cur.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // thumb 液泡本體
    final Rect bubble = Rect.fromCircle(center: Offset(thumbX, cy), radius: thumbR);
    canvas.drawCircle(
      Offset(thumbX, cy),
      thumbR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: <Color>[
            Color.lerp(cur, Colors.white, 0.5)!,
            cur,
          ],
        ).createShader(bubble),
    );
    // 高光點
    canvas.drawCircle(
      Offset(thumbX - thumbR * 0.32, cy - thumbR * 0.34),
      thumbR * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _SliderPainter old) => old.t != t;
}
