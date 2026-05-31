import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_mode.dart';
import '../models/game_region.dart';
import '../models/play_history_entry.dart';
import '../widgets/matchday_ui.dart';

class PlayHistoryDetailPage extends StatelessWidget {
  const PlayHistoryDetailPage({
    super.key,
    required this.entry,
    required this.whenLabel,
  });

  final PlayHistoryEntry entry;
  final String whenLabel;

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
            '紀錄詳情',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            _DetailCard(
              title: entry.playType.label,
              children: <Widget>[
                _DetailRow(label: '時間', value: whenLabel),
                _DetailRow(label: '總分', value: '${entry.totalScore} 分'),
                if (entry.outcomeLabel != null)
                  _DetailRow(label: '結果', value: entry.outcomeLabel!),
              ],
            ),
            const SizedBox(height: 12),
            _DetailCard(
              title: '對局設定',
              children: <Widget>[
                _DetailRow(label: '模式', value: entry.mode.label),
                _DetailRow(label: '區域', value: entry.region.label),
                _DetailRow(label: '回合數', value: '${entry.rounds} 回合'),
                _DetailRow(
                  label: '每回合秒數',
                  value: '${entry.secondsPerRound} 秒',
                ),
              ],
            ),
            if (entry.playType != PlayHistoryType.solo) ...<Widget>[
              const SizedBox(height: 12),
              _DetailCard(
                title: '對手資訊',
                children: <Widget>[
                  _DetailRow(label: '對手', value: entry.opponentLabel),
                  if (entry.opponentScore != null)
                    _DetailRow(
                      label: '對手分數',
                      value: '${entry.opponentScore} 分',
                    ),
                  if (entry.aiStrength != null)
                    _DetailRow(
                      label: 'AI 強度',
                      value: entry.aiStrength!,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MatchdayPalette.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MatchdayPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MatchdayPalette.ink.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
