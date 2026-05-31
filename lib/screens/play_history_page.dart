import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_mode.dart';
import '../models/game_region.dart';
import '../models/play_history_entry.dart';
import '../services/auth_service.dart';
import '../services/play_history_service.dart';
import '../widgets/matchday_ui.dart';
import 'login_page.dart';
import 'play_history_detail_page.dart';

class PlayHistoryPage extends StatefulWidget {
  const PlayHistoryPage({super.key});

  @override
  State<PlayHistoryPage> createState() => _PlayHistoryPageState();
}

class _PlayHistoryPageState extends State<PlayHistoryPage> {
  bool _loading = true;
  String? _error;
  List<PlayHistoryEntry> _entries = <PlayHistoryEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthService.instance.isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '請先登入才能查看遊玩紀錄';
        _entries = <PlayHistoryEntry>[];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<PlayHistoryEntry> rows =
          await PlayHistoryService.instance.loadMine(limit: 100);
      if (!mounted) return;
      setState(() {
        _entries = rows;
        _loading = false;
      });
    } on PlayHistoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _entries = <PlayHistoryEntry>[];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '載入失敗：$e';
        _entries = <PlayHistoryEntry>[];
        _loading = false;
      });
    }
  }

  static String _formatWhen(DateTime dt) {
    final DateTime local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: MatchdayPalette.bg,
        appBar: AppBar(
          backgroundColor: MatchdayPalette.bg,
          elevation: 0,
          foregroundColor: MatchdayPalette.ink,
          title: const Text(
            '遊玩紀錄',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          actions: <Widget>[
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: '重新整理',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _entries.isEmpty) {
      return const Center(
        child: ApiLoadingBar(label: '載入遊玩紀錄…'),
      );
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MatchdayPalette.ink.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!AuthService.instance.isLoggedIn)
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const LoginPage(),
                          ),
                        );
                      },
                      child: const Text('前往登入'),
                    )
                  else
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('重試'),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
            Center(
              child: Text(
                '尚無紀錄\n完成一局後會自動記錄',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MatchdayPalette.ink.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        if (_loading)
          const LinearProgressIndicator(
            color: MatchdayPalette.ink,
            backgroundColor: Color(0xFFE8E4DC),
            minHeight: 3,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final PlayHistoryEntry entry = _entries[index];
                return _HistoryCard(
                  entry: entry,
                  whenLabel: _formatWhen(entry.playedAt),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            PlayHistoryDetailPage(
                          entry: entry,
                          whenLabel: _formatWhen(entry.playedAt),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.whenLabel,
    required this.onTap,
  });

  final PlayHistoryEntry entry;
  final String whenLabel;
  final VoidCallback onTap;

  Color get _typeColor {
    switch (entry.playType) {
      case PlayHistoryType.solo:
        return const Color(0xFF5C6BC0);
      case PlayHistoryType.ai:
        return const Color(0xFFEF6C00);
      case PlayHistoryType.friend:
        return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? outcome = entry.outcomeLabel;
    return Material(
      color: MatchdayPalette.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: MatchdayPalette.ink, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _typeColor, width: 1.5),
                ),
                child: Text(
                  entry.playType.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _typeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (outcome != null) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  outcome,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: entry.won == true
                        ? const Color(0xFF2E7D32)
                        : MatchdayPalette.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                whenLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MatchdayPalette.ink.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${entry.totalScore}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '分',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MatchdayPalette.ink.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const Spacer(),
              if (entry.playType != PlayHistoryType.solo)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '對手',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MatchdayPalette.ink.withValues(alpha: 0.45),
                      ),
                    ),
                    Text(
                      entry.opponentLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (entry.opponentScore != null)
                      Text(
                        '${entry.opponentScore} 分',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MatchdayPalette.ink.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${entry.mode.label} · ${entry.region.label} · '
            '${entry.rounds} 回合 · 每回合 ${entry.secondsPerRound} 秒',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MatchdayPalette.ink.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Text(
                '查看詳情',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: MatchdayPalette.ink.withValues(alpha: 0.45),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: MatchdayPalette.ink.withValues(alpha: 0.45),
              ),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }
}
