import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../models/game_settings.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_service.dart';
import '../services/play_history_service.dart';
import '../services/realtime_service.dart';
import '../widgets/matchday_ui.dart';
import 'home_page.dart';
import 'leaderboard_page.dart';

class DuelResultPage extends StatefulWidget {
  const DuelResultPage({
    super.key,
    required this.myName,
    required this.opponentName,
    required this.myTotal,
    required this.opponentTotal,
    this.winnerId,
    required this.myUserId,
    required this.opponentUserId,
    required this.rematchSettings,
  });

  final String myName;
  final String opponentName;
  final int myTotal;
  final int opponentTotal;
  final String? winnerId;
  final String myUserId;
  final String opponentUserId;
  final GameSettings rematchSettings;

  @override
  State<DuelResultPage> createState() => _DuelResultPageState();
}

class _DuelResultPageState extends State<DuelResultPage> {
  bool _saving = true;
  bool _savedToCloud = false;
  String? _saveMessage;
  String? _savedEntryId;

  bool get _canRematch =>
      widget.opponentUserId.trim().isNotEmpty &&
      RealtimeService.instance.canUseRealtime;

  GameSettings get _rematchPayload => widget.rematchSettings.copyWith(
        vsAi: false,
        vsPlayer: true,
        duelRoomId: null,
        opponentUserId: widget.opponentUserId,
        opponentDisplayName: widget.opponentName,
        presetPlaces: null,
      );

  @override
  void initState() {
    super.initState();
    _saveRunToLeaderboard();
  }

  Future<void> _saveRunToLeaderboard() async {
    final bool funMode = widget.rematchSettings.entertainmentMode;

    if (!AuthService.instance.isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedToCloud = false;
        _saveMessage = funMode
            ? '娛樂模式不計排行榜'
            : '未登入：本局不會寫入雲端排行榜';
      });
      return;
    }

    try {
      String? entryId;
      if (!funMode) {
        entryId = await LeaderboardService.instance.saveRunTotals(
          totalScore: widget.myTotal,
          rounds: widget.rematchSettings.roundsPerGame,
          settings: widget.rematchSettings,
        );
      }
      await PlayHistoryService.instance.recordFriendDuel(
        myTotal: widget.myTotal,
        opponentTotal: widget.opponentTotal,
        settings: widget.rematchSettings,
        opponentUserId: widget.opponentUserId,
        opponentDisplayName: widget.opponentName,
        winnerId: widget.winnerId,
        myUserId: widget.myUserId,
      );
      if (!mounted) return;
      setState(() {
        _savedEntryId = entryId;
        _savedToCloud = !funMode && entryId != null;
        _saveMessage = funMode
            ? '娛樂模式：不計入排行榜（已寫入遊玩紀錄）'
            : '已存入雲端排行榜';
        _saving = false;
      });
    } on LeaderboardException catch (e) {
      if (!mounted) return;
      setState(() {
        _savedToCloud = false;
        _saveMessage = e.message;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savedToCloud = false;
        _saveMessage = '排行榜儲存失敗：$e';
        _saving = false;
      });
    }
  }

  void _requestRematch(BuildContext context) {
    AudioService.instance.playClick();
    RealtimeService.instance.sendDuelInvite(
      toUserId: widget.opponentUserId,
      settings: _rematchPayload,
      rematch: true,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已向 ${widget.opponentName} 送出再戰邀請'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool funMode = widget.rematchSettings.entertainmentMode;
    final bool draw = widget.winnerId == null;
    final bool iWon = !draw && widget.winnerId == widget.myUserId;
    final String headline = draw
        ? '平手！'
        : iWon
            ? '你贏了！'
            : '對手獲勝';

    return Scaffold(
      backgroundColor: MatchdayPalette.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              MatchdayTopTicker(
                label: 'DUEL · FINISHED',
                trailing: widget.rematchSettings.entertainmentMode
                    ? 'FUN MODE'
                    : 'VS PLAYER',
              ),
              const SizedBox(height: 32),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 24),
              if (funMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '娛樂模式 · 不計入排行榜',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MatchdayPalette.ink.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              _ScoreCard(
                name: widget.myName,
                score: widget.myTotal,
                highlight: iWon || draw,
              ),
              const SizedBox(height: 12),
              _ScoreCard(
                name: widget.opponentName,
                score: widget.opponentTotal,
                highlight: !draw && !iWon,
              ),
              const SizedBox(height: 12),
              _buildLeaderboardStatus(),
              const SizedBox(height: 8),
              ValueListenableBuilder<String?>(
                valueListenable: RealtimeService.instance.duelStatusMessage,
                builder: (BuildContext context, String? status, _) {
                  if (status == null || status.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MatchdayPalette.ink.withValues(alpha: 0.65),
                    ),
                  );
                },
              ),
              const Spacer(),
              if (_savedToCloud && !_saving && !widget.rematchSettings.entertainmentMode) ...<Widget>[
                OutlinedButton.icon(
                  onPressed: () {
                    AudioService.instance.playClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => LeaderboardPage(
                          highlightEntryId: _savedEntryId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.leaderboard_outlined),
                  label: const Text(
                    '查看排行榜',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MatchdayPalette.ink,
                    side: const BorderSide(color: MatchdayPalette.ink, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_canRematch) ...<Widget>[
                FilledButton.icon(
                  onPressed: () => _requestRematch(context),
                  icon: const Icon(Icons.replay),
                  label: const Text(
                    '再戰一次',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: MatchdayPalette.yellow,
                    foregroundColor: MatchdayPalette.ink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '模式：${widget.rematchSettings.mode.label} · '
                  '${widget.rematchSettings.roundsPerGame} 回合',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: MatchdayPalette.ink.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              OutlinedButton(
                onPressed: () {
                  AudioService.instance.playClick();
                  Navigator.pushAndRemoveUntil<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const HomePage(),
                    ),
                    (Route<dynamic> r) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: MatchdayPalette.ink,
                  side: const BorderSide(color: MatchdayPalette.ink, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '回主頁',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardStatus() {
    if (_saving) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: MatchdayPalette.ink.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '正在寫入排行榜…',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MatchdayPalette.ink.withValues(alpha: 0.55),
            ),
          ),
        ],
      );
    }
    final String? msg = _saveMessage;
    if (msg == null || msg.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      msg,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _savedToCloud
            ? const Color(0xFF2E7D32)
            : MatchdayPalette.ink.withValues(alpha: 0.55),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.name,
    required this.score,
    required this.highlight,
  });

  final String name;
  final int score;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlight ? MatchdayPalette.yellow : MatchdayPalette.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MatchdayPalette.ink, width: 2),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
