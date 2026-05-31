import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../widgets/matchday_ui.dart';
import 'home_page.dart';

class DuelResultPage extends StatelessWidget {
  const DuelResultPage({
    super.key,
    required this.myName,
    required this.opponentName,
    required this.myTotal,
    required this.opponentTotal,
    this.winnerId,
    required this.myUserId,
  });

  final String myName;
  final String opponentName;
  final int myTotal;
  final int opponentTotal;
  final String? winnerId;
  final String myUserId;

  @override
  Widget build(BuildContext context) {
    final bool draw = winnerId == null;
    final bool iWon = !draw && winnerId == myUserId;
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
              const MatchdayTopTicker(
                label: 'DUEL · FINISHED',
                trailing: 'VS PLAYER',
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
              _ScoreCard(name: myName, score: myTotal, highlight: iWon || draw),
              const SizedBox(height: 12),
              _ScoreCard(
                name: opponentName,
                score: opponentTotal,
                highlight: !draw && !iWon,
              ),
              const Spacer(),
              FilledButton(
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
                style: FilledButton.styleFrom(
                  backgroundColor: MatchdayPalette.ink,
                  foregroundColor: MatchdayPalette.yellow,
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
