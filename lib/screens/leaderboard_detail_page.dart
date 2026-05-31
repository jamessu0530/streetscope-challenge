import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_mode.dart';
import '../models/game_region.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardDetailPage extends StatelessWidget {
  const LeaderboardDetailPage({
    super.key,
    required this.entry,
    required this.rank,
  });

  final LeaderboardEntry entry;
  final int rank;

  static const Color _bg = Color(0xFF000000);
  static const Color _ink = Color(0xFFE8E8E8);
  static const Color _dim = Color(0xFF6A6A6A);
  static const Color _accent = Color(0xFFFFD400);
  static const List<String> _monoFallback = <String>[
    'Menlo',
    'Courier New',
    'Courier',
    'monospace',
  ];

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

  String _formatWhen(DateTime dt) {
    final DateTime local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          foregroundColor: _ink,
          title: const Text(
            'SCORE DETAIL',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontFamily: 'Menlo',
              fontFamilyFallback: _monoFallback,
              fontSize: 14,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            Text(
              _ordinal(rank),
              style: const TextStyle(
                color: _accent,
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                fontFamily: 'Menlo',
                fontFamilyFallback: _monoFallback,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.name.toUpperCase(),
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontFamily: 'Menlo',
                fontFamilyFallback: _monoFallback,
              ),
            ),
            if (entry.isMe) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '◄ YOUR SCORE',
                style: TextStyle(
                  color: _accent.withValues(alpha: 0.85),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Menlo',
                  fontFamilyFallback: _monoFallback,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _DetailBlock(
              rows: <_DetailLine>[
                _DetailLine('SCORE', entry.totalScore.toString().padLeft(6, '0')),
                _DetailLine('MODE', entry.mode.label.toUpperCase()),
                _DetailLine('REGION', entry.region.label.toUpperCase()),
                _DetailLine('ROUNDS', '${entry.rounds}'),
                _DetailLine('SEC / ROUND', '${entry.secondsPerRound}'),
                _DetailLine('PLAYED AT', _formatWhen(entry.playedAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.rows});

  final List<_DetailLine> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: LeaderboardDetailPage._dim, width: 1),
      ),
      child: Column(
        children: rows
            .map(
              (_DetailLine row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 110,
                      child: Text(
                        row.label,
                        style: const TextStyle(
                          color: LeaderboardDetailPage._dim,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Menlo',
                          fontFamilyFallback: LeaderboardDetailPage._monoFallback,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: const TextStyle(
                          color: LeaderboardDetailPage._ink,
                          fontSize: 14,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Menlo',
                          fontFamilyFallback: LeaderboardDetailPage._monoFallback,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DetailLine {
  const _DetailLine(this.label, this.value);
  final String label;
  final String value;
}
