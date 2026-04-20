// =============================================================================
// RoundTile — 結算頁列出每回合的小卡
// =============================================================================

import 'package:flutter/material.dart';

import '../models/guess_result.dart';

class RoundTile extends StatelessWidget {
  final int roundIndex;
  final GuessResult result;

  const RoundTile({
    super.key,
    required this.roundIndex,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final String subtitle;
    if (!result.answered) {
      subtitle = '未作答';
    } else {
      final double dist = result.distanceKm ?? 0;
      subtitle = '距離 ${dist.toStringAsFixed(1)} km';
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo,
          child: Text(
            '${roundIndex + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          '第 ${roundIndex + 1} 回合',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Text(
          '${result.score}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
      ),
    );
  }
}
