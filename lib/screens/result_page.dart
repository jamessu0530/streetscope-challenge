// =============================================================================
// ResultPage — 結算頁  ←  ✅ [Multiple Pages #3]
// =============================================================================

import 'package:flutter/material.dart';

import '../models/guess_result.dart';
import '../utils/score_utils.dart';
import '../widgets/round_tile.dart';
import 'home_page.dart';

class ResultPage extends StatelessWidget {
  final List<GuessResult> results;

  const ResultPage({super.key, required this.results});

  int get _totalScore =>
      results.fold<int>(0, (int sum, GuessResult r) => sum + r.score);

  int get _maxPossibleScore => results.length * kMaxScore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('遊戲結算'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                color: Colors.indigo,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        '總分',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_totalScore',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '滿分 $_maxPossibleScore',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final GuessResult r = results[index];
                    return RoundTile(roundIndex: index, result: r);
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext context) => const HomePage(),
                      ),
                      (Route<dynamic> route) => false,
                    );
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('回到首頁'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
