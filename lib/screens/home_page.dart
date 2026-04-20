// =============================================================================
// HomePage — 首頁  ←  ✅ [Multiple Pages #1]
// =============================================================================

import 'package:flutter/material.dart';

import '../data/game_constants.dart';
import '../models/game_mode.dart';
import '../models/game_region.dart';
import '../widgets/rule_row.dart';
import 'game_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GameRegion _selectedRegion = GameRegion.world;
  int _selectedSeconds = kSecondsPerRound;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3F51B5), Color(0xFF9FA8DA)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.public, size: 120, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'GeoGuesser',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '隨機丟到世界某處，用街景找線索、在地圖上猜位置！',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: <Widget>[
                      const RuleRow(
                          icon: Icons.shuffle, text: '每回合：隨機座標 → 自動對齊最近街景'),
                      const SizedBox(height: 8),
                      RuleRow(
                          icon: Icons.timer,
                          text:
                              '每場 $kRoundsPerGame 回合 · 每回合 $_selectedSeconds 秒'),
                      const SizedBox(height: 8),
                      const RuleRow(icon: Icons.map, text: '地圖可縮放、平移後點選你的猜測'),
                      const SizedBox(height: 8),
                      const RuleRow(
                          icon: Icons.emoji_events, text: '越接近街景實際拍攝點分數越高'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '選擇地區',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 320,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<GameRegion>(
                      value: _selectedRegion,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(Icons.public),
                      items: GameRegion.values
                          .map(
                            (GameRegion region) => DropdownMenuItem<GameRegion>(
                              value: region,
                              child:
                                  Text('${region.label}・${region.description}'),
                            ),
                          )
                          .toList(),
                      onChanged: (GameRegion? value) {
                        if (value == null) return;
                        setState(() => _selectedRegion = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '每回合時間',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 320,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$_selectedSeconds 秒',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3F51B5),
                          ),
                        ),
                        Slider(
                          value: _selectedSeconds.toDouble(),
                          min: kMinSecondsPerRound.toDouble(),
                          max: kMaxSecondsPerRound.toDouble(),
                          divisions: kMaxSecondsPerRound - kMinSecondsPerRound,
                          label: '$_selectedSeconds 秒',
                          onChanged: (double value) {
                            setState(() => _selectedSeconds = value.round());
                          },
                        ),
                        Text(
                          '$kMinSecondsPerRound 秒 ～ $kMaxSecondsPerRound 秒（最多兩分鐘）',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '選擇難度',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                _ModeButton(
                  mode: GameMode.move,
                  region: _selectedRegion,
                  secondsPerRound: _selectedSeconds,
                  icon: Icons.directions_walk,
                ),
                const SizedBox(height: 10),
                _ModeButton(
                  mode: GameMode.noMove,
                  region: _selectedRegion,
                  secondsPerRound: _selectedSeconds,
                  icon: Icons.threesixty,
                ),
                const SizedBox(height: 10),
                _ModeButton(
                  mode: GameMode.picture,
                  region: _selectedRegion,
                  secondsPerRound: _selectedSeconds,
                  icon: Icons.image,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final GameMode mode;
  final GameRegion region;
  final int secondsPerRound;
  final IconData icon;

  const _ModeButton({
    required this.mode,
    required this.region,
    required this.secondsPerRound,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (BuildContext context) => GamePage(
                mode: mode,
                region: region,
                secondsPerRound: secondsPerRound,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF3F51B5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
