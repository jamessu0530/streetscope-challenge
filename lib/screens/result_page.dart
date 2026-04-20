// =============================================================================
// ResultPage — 結算頁  ←  ✅ [Multiple Pages #3]
//
// 風格：Apple Health / 分析儀表板；
//   - 巨大 Total Score 主數字
//   - 細長 bar chart（可點 bar 切換高亮）
//   - 極簡 round rows（index / distance / score，不再用卡片）
//   - 單一橘色 accent，凸顯最佳回合
// =============================================================================

import 'package:flutter/material.dart';

import '../models/game_settings.dart';
import '../models/guess_result.dart';
import '../services/audio_service.dart';
import '../services/leaderboard_service.dart';
import '../utils/score_utils.dart';
import 'home_page.dart';
import 'leaderboard_page.dart';

class ResultPage extends StatefulWidget {
  final List<GuessResult> results;
  final GameSettings settings;

  const ResultPage({
    super.key,
    required this.results,
    required this.settings,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage>
    with SingleTickerProviderStateMixin {
  bool _saving = true;
  int? _highlightIndex;
  late final AnimationController _chartCtrl;

  // 玩家名字：預設 JAMES，使用者可自行改。排行榜會跟著更新。
  static const String _defaultName = 'JAMES';
  late final TextEditingController _nameCtrl =
      TextEditingController(text: _defaultName);
  DateTime? _savedAt;

  int get _totalScore =>
      widget.results.fold<int>(0, (int sum, GuessResult r) => sum + r.score);

  int get _maxPossibleScore => widget.results.length * kMaxScore;

  double get _averageScore {
    if (widget.results.isEmpty) return 0;
    return _totalScore / widget.results.length;
  }

  int? get _bestRoundIndex {
    if (widget.results.isEmpty) return null;
    int bestIdx = 0;
    for (int i = 1; i < widget.results.length; i++) {
      if (widget.results[i].score > widget.results[bestIdx].score) {
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  double? get _bestDistanceKm {
    double? best;
    for (final GuessResult r in widget.results) {
      final double? d = r.distanceKm;
      if (d == null) continue;
      if (best == null || d < best) best = d;
    }
    return best;
  }

  @override
  void initState() {
    super.initState();
    _chartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _saveRun();
  }

  @override
  void dispose() {
    _chartCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveRun() async {
    final DateTime savedAt = await LeaderboardService.instance.saveRun(
      results: widget.results,
      settings: widget.settings,
      name: _nameCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _savedAt = savedAt;
      _saving = false;
    });
  }

  void _onNameChanged(String value) {
    final DateTime? at = _savedAt;
    if (at == null) return;
    LeaderboardService.instance.updateEntryName(
      playedAt: at,
      name: value,
    );
  }

  // ---- 設計 token（Apple Health 風） --------------------------------------
  static const Color _ink = Color(0xFF111216);
  static const Color _ink2 = Color(0xFF6B6F76);
  static const Color _ink3 = Color(0xFFAEB2B8);
  static const Color _bg = Color(0xFFF6F6F7);
  static const Color _divider = Color(0xFFE6E6E8);
  static const Color _accent = Color(0xFFFF7A1A);

  @override
  Widget build(BuildContext context) {
    final int? bestIdx = _bestRoundIndex;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: <Widget>[
                  const SizedBox(height: 12),
                  _buildNameField(),
                  const SizedBox(height: 16),
                  _buildHeroNumber(),
                  const SizedBox(height: 20),
                  _buildChart(bestIdx: bestIdx),
                  const SizedBox(height: 10),
                  _buildMetaRow(bestIdx: bestIdx),
                  const SizedBox(height: 28),
                  _buildSectionLabel('ROUNDS'),
                  const SizedBox(height: 6),
                  _buildRoundList(bestIdx: bestIdx),
                  const SizedBox(height: 24),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Center(
                        child: Text(
                          'Saving run…',
                          style: TextStyle(
                            fontSize: 12,
                            color: _ink3,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  // ---- Top bar（只有一個極淡的 SUMMARY 標） ---------------------------------
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: <Widget>[
          const Text(
            'SUMMARY',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
              color: _ink2,
            ),
          ),
          const Spacer(),
          Text(
            _fmtMode(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: _ink3,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtMode() {
    final String region = widget.settings.region.name.toUpperCase();
    final String mode = widget.settings.mode.name.toUpperCase();
    return '$mode · $region';
  }

  // ---- 玩家名字（極簡下底線輸入） -----------------------------------------
  Widget _buildNameField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'NAME',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w800,
              color: _ink3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _nameCtrl,
            onChanged: _onNameChanged,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: 2,
            ),
            decoration: const InputDecoration(
              isDense: true,
              counterText: '',
              hintText: _defaultName,
              hintStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ink3,
                letterSpacing: 2,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 6),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: _divider),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _divider),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _ink, width: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Icon(Icons.edit_outlined, size: 14, color: _ink3),
        ),
      ],
    );
  }

  // ---- 巨大主數字 ---------------------------------------------------------
  Widget _buildHeroNumber() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Total Score',
          style: TextStyle(
            fontSize: 13,
            color: _ink2,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '$_totalScore',
              style: const TextStyle(
                fontSize: 72,
                height: 1,
                letterSpacing: -2,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '/ $_maxPossibleScore',
                style: const TextStyle(
                  fontSize: 16,
                  color: _ink3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- 細長 bar chart ----------------------------------------------------
  Widget _buildChart({required int? bestIdx}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails details) =>
              _handleChartTap(details.localPosition, c.maxWidth),
          child: SizedBox(
            height: 140,
            child: AnimatedBuilder(
              animation: _chartCtrl,
              builder: (BuildContext context, _) {
                return CustomPaint(
                  painter: _BarChartPainter(
                    results: widget.results,
                    maxScore: kMaxScore,
                    highlightIndex: _highlightIndex ?? bestIdx,
                    progress: Curves.easeOutCubic.transform(_chartCtrl.value),
                    ink: _ink,
                    ink2: _ink2,
                    ink3: _ink3,
                    divider: _divider,
                    accent: _accent,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _handleChartTap(Offset localPos, double maxWidth) {
    if (widget.results.isEmpty) return;
    final double slot = maxWidth / widget.results.length;
    int idx = (localPos.dx / slot).floor();
    if (idx < 0) idx = 0;
    if (idx >= widget.results.length) idx = widget.results.length - 1;
    setState(() {
      _highlightIndex = _highlightIndex == idx ? null : idx;
    });
  }

  // ---- Meta row：Rounds · Avg · Best -------------------------------------
  Widget _buildMetaRow({required int? bestIdx}) {
    final String avg = _averageScore.toStringAsFixed(0);
    final double? bestKm = _bestDistanceKm;
    final String bestStr = bestKm == null
        ? '—'
        : (bestKm < 1 ? '<1 km' : '${bestKm.toStringAsFixed(1)} km');
    return Row(
      children: <Widget>[
        Expanded(child: _metaItem('Rounds', '${widget.results.length}')),
        Expanded(child: _metaItem('Avg', avg)),
        Expanded(
          child: _metaItem(
            'Best dist',
            bestStr,
            valueColor: bestIdx == null ? null : _accent,
          ),
        ),
      ],
    );
  }

  Widget _metaItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
            color: _ink3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: valueColor ?? _ink,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 2.4,
        fontWeight: FontWeight.w800,
        color: _ink2,
      ),
    );
  }

  // ---- Round 列表（極簡 rows） -------------------------------------------
  Widget _buildRoundList({required int? bestIdx}) {
    return Column(
      children: List<Widget>.generate(widget.results.length, (int i) {
        final GuessResult r = widget.results[i];
        final bool isBest = bestIdx == i;
        final bool isHighlighted = _highlightIndex == i;
        final bool dim = _highlightIndex != null && !isHighlighted;
        final String distText = r.answered
            ? (r.distanceKm! < 1
                ? '<1 km'
                : '${r.distanceKm!.toStringAsFixed(1)} km')
            : 'No answer';
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: dim ? 0.35 : 1,
          child: _RoundRow(
            index: i,
            distText: distText,
            score: r.score,
            isBest: isBest,
            ink: _ink,
            ink2: _ink2,
            ink3: _ink3,
            divider: _divider,
            accent: _accent,
          ),
        );
      }),
    );
  }

  // ---- 底部按鈕 ----------------------------------------------------------
  Widget _buildBottomActions() {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const LeaderboardPage(),
                  ),
                );
              },
              icon: const Icon(Icons.leaderboard_outlined, size: 16),
              label: const Text('VIEW LEADERBOARD'),
              style: TextButton.styleFrom(
                foregroundColor: _ink2,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () async {
                await AudioService.instance.startHomeBgm();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const HomePage(),
                  ),
                  (Route<dynamic> route) => false,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 1.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('DONE'),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 單一回合的 row：左 index 圓徽、中距離、右分數
// =============================================================================
class _RoundRow extends StatelessWidget {
  final int index;
  final String distText;
  final int score;
  final bool isBest;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color divider;
  final Color accent;

  const _RoundRow({
    required this.index,
    required this.distText,
    required this.score,
    required this.isBest,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.divider,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isBest ? accent : ink3,
                width: isBest ? 1.6 : 1,
              ),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isBest ? accent : ink2,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              distText,
              style: TextStyle(
                fontSize: 14,
                color: ink2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isBest ? accent : ink,
              letterSpacing: -0.5,
            ),
          ),
          if (isBest) ...<Widget>[
            const SizedBox(width: 6),
            Icon(Icons.star_rounded, size: 16, color: accent),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Bar chart painter：細長直條、極低視覺雜訊，best round 用 accent 突出
// =============================================================================
class _BarChartPainter extends CustomPainter {
  final List<GuessResult> results;
  final int maxScore;
  final int? highlightIndex;
  final double progress;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color divider;
  final Color accent;

  _BarChartPainter({
    required this.results,
    required this.maxScore,
    required this.highlightIndex,
    required this.progress,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.divider,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (results.isEmpty) return;

    const double topPad = 8;
    const double bottomPad = 22; // 留空間給底部標籤
    final double chartH = size.height - topPad - bottomPad;

    // 基線
    final Paint baseLine = Paint()
      ..color = divider
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - bottomPad),
      Offset(size.width, size.height - bottomPad),
      baseLine,
    );

    final int n = results.length;
    final double slot = size.width / n;
    final double barW = (slot * 0.22).clamp(3.0, 10.0);

    for (int i = 0; i < n; i++) {
      final int score = results[i].score;
      final double ratio = (score / maxScore).clamp(0.0, 1.0);
      final double h = chartH * ratio * progress;
      final double cx = slot * (i + 0.5);
      final double top = size.height - bottomPad - h;

      final bool isHL = highlightIndex == i;
      final Paint barPaint = Paint()
        ..color = isHL ? accent : ink
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barW;

      canvas.drawLine(
        Offset(cx, size.height - bottomPad),
        Offset(cx, top),
        barPaint,
      );

      // 高亮的 bar 上方畫一個小圓點 + 分數
      if (isHL) {
        final Paint dot = Paint()..color = accent;
        canvas.drawCircle(Offset(cx, top - 6), 3, dot);

        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: '$score',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final double textX =
            (cx - tp.width / 2).clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(textX, top - 22));
      }

      // 底部 index 標籤（只顯示選中或首末，避免擁擠）
      final bool showIdx =
          isHL || i == 0 || i == n - 1 || (n <= 5) || (i % 2 == 0 && n <= 10);
      if (showIdx) {
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              color: isHL ? accent : ink3,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final double textX =
            (cx - tp.width / 2).clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(textX, size.height - bottomPad + 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) {
    return old.highlightIndex != highlightIndex ||
        old.progress != progress ||
        old.results != results;
  }
}
