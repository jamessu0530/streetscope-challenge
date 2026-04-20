// =============================================================================
// HomePage — 編輯風 / 英超 Matchday 視覺（Step 1：Game Setup）
//
// 流程：
//   HomePage（做好 Region / Rounds / Time / Moves 設定）
//     → 按「CONTINUE」CTA
//     → ModeSelectionPage（再選 MOVE / NO MOVE / PICTURE）
//     → GamePage
//
// 音訊：
//   - 進頁面 → startHomeBgm（lobby 用的 Dreamy Flashback，跟遊戲主音樂不同）
//   - 推 ModeSelectionPage 時：保持 home BGM 續播
//   - 回到本頁：確保 home BGM 恢復
//   - 離開應用或被背景：pause，回前景 resume
// =============================================================================

import 'package:flutter/material.dart';

import '../data/game_constants.dart';
import '../models/game_region.dart';
import '../models/game_settings.dart';
import '../services/audio_service.dart';
import '../widgets/matchday_ui.dart';
import 'leaderboard_page.dart';
import 'mode_selection_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  GameRegion _region = GameRegion.world;
  int _secondsPerRound = kSecondsPerRound;
  int _roundsPerGame = kRoundsPerGame;
  int _maxMoveSteps = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioService.instance.startHomeBgm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MatchdayPalette.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const MatchdayTopTicker(
                label: 'LIVE · MATCHDAY READY',
                trailing: 'STEP · 01 / 02',
              ),
              const SizedBox(height: 20),
              const _Masthead(ink: MatchdayPalette.ink),
              const SizedBox(height: 22),
              _SetupSection(
                ink: MatchdayPalette.ink,
                yellow: MatchdayPalette.yellow,
                cream: MatchdayPalette.cream,
                region: _region,
                onRegionChanged: (GameRegion r) => setState(() => _region = r),
                rounds: _roundsPerGame,
                onRoundsChanged: (int n) => setState(() => _roundsPerGame = n),
                seconds: _secondsPerRound,
                onSecondsChanged: (int s) =>
                    setState(() => _secondsPerRound = s),
                maxMoveSteps: _maxMoveSteps,
                onMoveStepsChanged: (int v) =>
                    setState(() => _maxMoveSteps = v),
              ),
              const SizedBox(height: 24),
              _ContinueCta(onTap: _goToModeSelection),
              const SizedBox(height: 10),
              _LeaderboardCta(onTap: _goToLeaderboard),
              const SizedBox(height: 40),
              const MatchdayFooterStripe(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goToModeSelection() async {
    AudioService.instance.playClick();
    final GameSettings base = GameSettings(
      region: _region,
      secondsPerRound: _secondsPerRound,
      roundsPerGame: _roundsPerGame,
      maxMoveSteps: _maxMoveSteps,
    );
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ModeSelectionPage(baseSettings: base),
      ),
    );
    if (!mounted) return;
    // 從選模式頁返回時確保 home BGM 還在；GamePage 進去會自己停，
    // ModeSelectionPage 會在返回時 restart。這裡當雙重保險。
    AudioService.instance.startHomeBgm();
  }

  Future<void> _goToLeaderboard() async {
    AudioService.instance.playClick();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const LeaderboardPage(),
      ),
    );
    if (!mounted) return;
    AudioService.instance.startHomeBgm();
  }
}

// =============================================================================
// Masthead：巨大編輯標題
// =============================================================================
class _Masthead extends StatelessWidget {
  final Color ink;
  const _Masthead({required this.ink});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'MATCHDAY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 18, height: 2, color: ink),
              const SizedBox(width: 8),
              const Text(
                'N°07 · WORLDWIDE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Brand mark：LOL / CATION.
          // 用 FittedBox 保險；小螢幕自動縮，不會爆畫面。
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'LOL',
              style: TextStyle(
                fontSize: 96,
                height: 0.92,
                letterSpacing: -4,
                fontWeight: FontWeight.w900,
                color: ink,
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
                Text(
                  'CATION',
                  style: TextStyle(
                    fontSize: 96,
                    height: 0.92,
                    letterSpacing: -4,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const Text(
                  '.',
                  style: TextStyle(
                    fontSize: 96,
                    height: 0.92,
                    fontWeight: FontWeight.w900,
                    color: MatchdayPalette.accent,
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
                width: 28,
                height: 2,
                margin: const EdgeInsets.only(top: 8, right: 10),
                color: ink,
              ),
              const Expanded(
                child: Text(
                  'GUESS THE WORLD.\nLAUGH AT YOUR L.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 設定區：黃色卡 + 區域 / 回合 / 時間 / 步數
// =============================================================================
class _SetupSection extends StatelessWidget {
  final Color ink;
  final Color yellow;
  final Color cream;
  final GameRegion region;
  final ValueChanged<GameRegion> onRegionChanged;
  final int rounds;
  final ValueChanged<int> onRoundsChanged;
  final int seconds;
  final ValueChanged<int> onSecondsChanged;
  final int maxMoveSteps;
  final ValueChanged<int> onMoveStepsChanged;

  const _SetupSection({
    required this.ink,
    required this.yellow,
    required this.cream,
    required this.region,
    required this.onRegionChanged,
    required this.rounds,
    required this.onRoundsChanged,
    required this.seconds,
    required this.onSecondsChanged,
    required this.maxMoveSteps,
    required this.onMoveStepsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MatchdaySectionHeader(
            label: 'GAME SETUP',
            trailing: 'PRE-MATCH',
          ),
          const SizedBox(height: 10),
          ClipPath(
            clipper: const MatchdayAngleCornerClipper(
              cut: 28,
              corner: MatchdayCorner.topRight,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: yellow,
                border: Border.all(color: ink, width: 2),
              ),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SetupField(
                    ink: ink,
                    label: 'REGION',
                    child: _RegionDropdown(
                      ink: ink,
                      cream: cream,
                      region: region,
                      onChanged: onRegionChanged,
                    ),
                  ),
                  _Divider(ink: ink),
                  _SetupField(
                    ink: ink,
                    label: 'ROUNDS',
                    child: _BoldChipsRow<int>(
                      ink: ink,
                      values: kRoundsPerGameOptions,
                      selected: rounds,
                      toLabel: (int v) => '$v',
                      onTap: onRoundsChanged,
                    ),
                  ),
                  _Divider(ink: ink),
                  _SetupField(
                    ink: ink,
                    label: 'TIME',
                    child: _TimeSlider(
                      ink: ink,
                      seconds: seconds,
                      onChanged: onSecondsChanged,
                    ),
                  ),
                  _Divider(ink: ink),
                  _SetupField(
                    ink: ink,
                    label: 'MOVES',
                    trailing: 'MOVE ONLY',
                    child: _BoldChipsRow<int>(
                      ink: ink,
                      values: kMoveStepLimitOptions,
                      selected: maxMoveSteps,
                      toLabel: (int v) => v == 0 ? '∞' : '$v',
                      onTap: onMoveStepsChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupField extends StatelessWidget {
  final Color ink;
  final String label;
  final String? trailing;
  final Widget child;
  const _SetupField({
    required this.ink,
    required this.label,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
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
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color ink;
  const _Divider({required this.ink});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: ink.withValues(alpha: 0.15),
    );
  }
}

class _RegionDropdown extends StatelessWidget {
  final Color ink;
  final Color cream;
  final GameRegion region;
  final ValueChanged<GameRegion> onChanged;
  const _RegionDropdown({
    required this.ink,
    required this.cream,
    required this.region,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cream,
        border: Border.all(color: ink, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<GameRegion>(
          value: region,
          isExpanded: true,
          dropdownColor: cream,
          iconEnabledColor: ink,
          style: TextStyle(
            color: ink,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
          items: GameRegion.values
              .map(
                (GameRegion r) => DropdownMenuItem<GameRegion>(
                  value: r,
                  child: Text('${r.label} · ${r.description}'),
                ),
              )
              .toList(),
          onChanged: (GameRegion? v) {
            if (v == null) return;
            AudioService.instance.playClick();
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _BoldChipsRow<T> extends StatelessWidget {
  final Color ink;
  final List<T> values;
  final T selected;
  final String Function(T) toLabel;
  final ValueChanged<T> onTap;

  const _BoldChipsRow({
    required this.ink,
    required this.values,
    required this.selected,
    required this.toLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((T v) {
        final bool isSel = v == selected;
        return InkWell(
          onTap: () {
            AudioService.instance.playClick();
            onTap(v);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? ink : Colors.white,
              border: Border.all(color: ink, width: 1.5),
            ),
            child: Text(
              toLabel(v),
              style: TextStyle(
                color: isSel ? Colors.white : ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TimeSlider extends StatelessWidget {
  final Color ink;
  final int seconds;
  final ValueChanged<int> onChanged;
  const _TimeSlider({
    required this.ink,
    required this.seconds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              '$seconds',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -1,
                color: ink,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'SEC / ROUND',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: ink,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: ink,
            inactiveTrackColor: ink.withValues(alpha: 0.2),
            thumbColor: ink,
            overlayColor: ink.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: seconds.toDouble(),
            min: kMinSecondsPerRound.toDouble(),
            max: kMaxSecondsPerRound.toDouble(),
            divisions: kMaxSecondsPerRound - kMinSecondsPerRound,
            label: '$seconds',
            onChanged: (double v) => onChanged(v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '${kMinSecondsPerRound}s',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: ink.withValues(alpha: 0.6),
              ),
            ),
            Text(
              '${kMaxSecondsPerRound}s',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: ink.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Continue CTA：黑底粗框大字 + 右上角切角，視覺呼應 Matchday Card
// =============================================================================
class _ContinueCta extends StatelessWidget {
  final VoidCallback onTap;
  const _ContinueCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipPath(
        clipper: const MatchdayAngleCornerClipper(
          cut: 32,
          corner: MatchdayCorner.topRight,
        ),
        child: Material(
          color: MatchdayPalette.ink,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'STEP · 02 / 02',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w800,
                            color: Colors.white60,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'PICK YOUR',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1,
                            letterSpacing: -0.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'MATCHDAY →',
                          style: TextStyle(
                            fontSize: 28,
                            height: 1,
                            letterSpacing: -1,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: MatchdayPalette.accent,
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 24,
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

class _LeaderboardCta extends StatelessWidget {
  final VoidCallback onTap;
  const _LeaderboardCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 46,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.leaderboard),
          label: const Text('排行榜（最近 10 場 / 前 10 名）'),
        ),
      ),
    );
  }
}
