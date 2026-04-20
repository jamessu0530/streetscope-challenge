// =============================================================================
// CountdownTimerWidget — 倒數計時 chip
//
// ✅ [StatefulWidget] ✅ [setState] ✅ [Timer] ✅ [Callback / Lift]
//
// 以「截止時間」對照 DateTime.now() 計算剩餘秒數，不要用「每秒 -1」。
// 觸控 google_maps_flutter（PlatformView）時，iOS 主執行緒可能忙碌，
// Timer.periodic 的回呼會延遲，若只靠 _remaining-- 容易卡在「1 秒」不歸零。
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

class CountdownTimerWidget extends StatefulWidget {
  final int totalSeconds;

  /// 倒數歸零通知父 widget（典型 lifting state up）。
  final VoidCallback onTimeUp;

  /// 每秒回報剩餘秒數（選用）。
  final void Function(int remainingSeconds)? onTick;

  const CountdownTimerWidget({
    super.key,
    required this.totalSeconds,
    required this.onTimeUp,
    this.onTick,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  /// 時間到的瞬間（牆上時鐘）。
  late DateTime _deadline;

  /// 顯示用剩餘「整秒」數。
  late int _remaining;

  Timer? _timer;
  bool _timeUpFired = false;

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(Duration(seconds: widget.totalSeconds));
    _remaining = widget.totalSeconds;
    _timeUpFired = false;
    _timer = Timer.periodic(const Duration(milliseconds: 250), _onPulse);
  }

  @override
  void didUpdateWidget(covariant CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalSeconds != widget.totalSeconds) {
      _deadline = DateTime.now().add(Duration(seconds: widget.totalSeconds));
      _remaining = widget.totalSeconds;
      _timeUpFired = false;
    }
  }

  /// 將剩餘毫秒換成顯示用整秒（與常見倒數一致：不足 1 秒仍顯示 1）。
  static int _displaySecondsFromMsLeft(int msLeft) {
    if (msLeft <= 0) return 0;
    return (msLeft + 999) ~/ 1000;
  }

  void _onPulse(Timer timer) {
    if (!mounted) return;

    final int msLeft = _deadline.difference(DateTime.now()).inMilliseconds;

    if (msLeft <= 0) {
      if (_remaining != 0) {
        setState(() => _remaining = 0);
      }
      widget.onTick?.call(0);
      if (!_timeUpFired) {
        _timeUpFired = true;
        timer.cancel();
        widget.onTimeUp();
      }
      return;
    }

    final int rem = _displaySecondsFromMsLeft(msLeft);
    if (rem != _remaining) {
      setState(() => _remaining = rem);
    }
    widget.onTick?.call(rem);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCritical = _remaining <= 5;
    final Color color = isCritical ? Colors.red : Colors.indigo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: color, size: 18),
          const SizedBox(width: 4),
          Text(
            '$_remaining 秒',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
