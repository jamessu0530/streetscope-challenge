// =============================================================================
// RuleRow — 首頁規則卡的單一列
// =============================================================================

import 'package:flutter/material.dart';

class RuleRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const RuleRow({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ],
    );
  }
}
