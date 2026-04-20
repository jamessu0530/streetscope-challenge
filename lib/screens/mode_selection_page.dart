// =============================================================================
// ModeSelectionPage — GAME SETUP 確認後才會來的「選模式」頁
//
// 流程：
//   HomePage（做好設定）→ CONTINUE → ModeSelectionPage（挑三種模式）→ GamePage
//
// 設計：
//   - 沿用 matchday 風格（MatchdayTopTicker / FooterStripe / ModeCard）
//   - 標頭顯示從 HomePage 帶來的設定 recap（Region / Rounds / Time / Moves）
//   - 三張模式卡：MOVE / NO MOVE / PICTURE，點下去才真正進遊戲
//
// BGM：
//   - 跟 HomePage 共用 home BGM（lobby 氛圍）
//   - 進 GamePage 前停掉，回到這頁再自動續播
// =============================================================================

import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../models/game_region.dart';
import '../models/game_settings.dart';
import '../services/audio_service.dart';
import '../widgets/matchday_ui.dart';
import 'game_page.dart';

class ModeSelectionPage extends StatefulWidget {
  final GameSettings baseSettings;
  const ModeSelectionPage({super.key, required this.baseSettings});

  @override
  State<ModeSelectionPage> createState() => _ModeSelectionPageState();
}

class _ModeSelectionPageState extends State<ModeSelectionPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // home BGM 是冪等的；若 HomePage 已經在播就 no-op，不會疊音。
    AudioService.instance.startHomeBgm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 注意：不在這邊 stopHomeBgm，因為返回 HomePage 後那邊還在用。
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
    AudioService.instance.playClick();
    final GameSettings settings = widget.baseSettings.copyWith(
      mode: mode,
      // picture / noMove 模式下強制移動步數為 0（忽略 Home 的輸入值）
      maxMoveSteps:
          mode == GameMode.move ? widget.baseSettings.maxMoveSteps : 0,
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
  }

  @override
  Widget build(BuildContext context) {
    final GameSettings s = widget.baseSettings;
    return Scaffold(
      backgroundColor: MatchdayPalette.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const MatchdayTopTicker(
                label: 'LIVE · PICK YOUR MATCHDAY',
                trailing: '3 MODES',
              ),
              const SizedBox(height: 20),
              const _Headline(ink: MatchdayPalette.ink),
              const SizedBox(height: 22),
              _SettingsRecap(
                ink: MatchdayPalette.ink,
                cream: MatchdayPalette.cream,
                settings: s,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const MatchdaySectionHeader(
                      label: 'SELECT FIXTURE',
                      trailing: 'TAP TO KICKOFF',
                    ),
                    const SizedBox(height: 6),
                    Container(height: 2, color: MatchdayPalette.ink),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              MatchdayModeCard(
                bg: MatchdayPalette.pink,
                index: '01',
                kickoff: '16:00',
                title: 'MOVE',
                subtitle: '完整模式',
                tagline: 'WALK THE STREETS',
                icon: Icons.directions_walk,
                onTap: () => _launch(GameMode.move),
              ),
              const SizedBox(height: 14),
              MatchdayModeCard(
                bg: MatchdayPalette.blue,
                index: '02',
                kickoff: '18:30',
                title: 'NO MOVE',
                subtitle: '鏡頭旋轉',
                tagline: 'STAND & OBSERVE',
                icon: Icons.threesixty,
                onTap: () => _launch(GameMode.noMove),
              ),
              const SizedBox(height: 14),
              MatchdayModeCard(
                bg: MatchdayPalette.green,
                index: '03',
                kickoff: '20:45',
                title: 'PICTURE',
                subtitle: '完全靜態',
                tagline: 'ONE SHOT · NO MOVES',
                icon: Icons.image,
                onTap: () => _launch(GameMode.picture),
              ),
              const SizedBox(height: 36),
              const MatchdayFooterStripe(),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Headline：返回鍵 + 大 PICK YOUR MATCHDAY 標題
// =============================================================================
class _Headline extends StatelessWidget {
  final Color ink;
  const _Headline({required this.ink});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: () {
                  AudioService.instance.playClick();
                  Navigator.maybePop(context);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: ink, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.arrow_back, size: 14, color: ink),
                      const SizedBox(width: 6),
                      Text(
                        'BACK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'STEP · 02 / 02',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'PICK YOUR',
              style: TextStyle(
                fontSize: 72,
                height: 0.92,
                letterSpacing: -3,
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
                  'MATCHDAY',
                  style: TextStyle(
                    fontSize: 72,
                    height: 0.92,
                    letterSpacing: -3,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                const Text(
                  '.',
                  style: TextStyle(
                    fontSize: 72,
                    height: 0.92,
                    fontWeight: FontWeight.w900,
                    color: MatchdayPalette.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                  'SETUP LOCKED IN.\nNOW CHOOSE HOW YOU PLAY.',
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
// SettingsRecap：把 HomePage 的設定做一個可一眼看完的 cream 卡
// =============================================================================
class _SettingsRecap extends StatelessWidget {
  final Color ink;
  final Color cream;
  final GameSettings settings;
  const _SettingsRecap({
    required this.ink,
    required this.cream,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MatchdaySectionHeader(
            label: 'TEAM SHEET',
            trailing: 'FROM SETUP',
          ),
          const SizedBox(height: 10),
          ClipPath(
            clipper: const MatchdayAngleCornerClipper(
              cut: 24,
              corner: MatchdayCorner.topRight,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: cream,
                border: Border.all(color: ink, width: 2),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: <Widget>[
                  _RecapRow(
                    ink: ink,
                    label: 'REGION',
                    value: settings.region.label,
                  ),
                  _RecapDivider(ink: ink),
                  _RecapRow(
                    ink: ink,
                    label: 'ROUNDS',
                    value: '${settings.roundsPerGame}',
                  ),
                  _RecapDivider(ink: ink),
                  _RecapRow(
                    ink: ink,
                    label: 'TIME',
                    value: '${settings.secondsPerRound}s / round',
                  ),
                  _RecapDivider(ink: ink),
                  _RecapRow(
                    ink: ink,
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
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  final Color ink;
  final String label;
  final String value;
  const _RecapRow({
    required this.ink,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapDivider extends StatelessWidget {
  final Color ink;
  const _RecapDivider({required this.ink});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: ink.withValues(alpha: 0.15),
    );
  }
}
