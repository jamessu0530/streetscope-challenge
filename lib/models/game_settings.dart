// =============================================================================
// GameSettings — 從首頁帶去 GamePage 的整包設定
// =============================================================================

import '../data/game_constants.dart';
import 'game_mode.dart';
import 'game_region.dart';

class GameSettings {
  final GameMode mode;
  final GameRegion region;
  final int secondsPerRound;
  final int roundsPerGame;

  /// 0 = 不限制；其他值 = Move 模式下最多可以走幾步。
  /// noMove / picture 模式此值被忽略。
  final int maxMoveSteps;

  const GameSettings({
    this.mode = GameMode.move,
    this.region = GameRegion.world,
    this.secondsPerRound = kSecondsPerRound,
    this.roundsPerGame = kRoundsPerGame,
    this.maxMoveSteps = 0,
  });

  GameSettings copyWith({
    GameMode? mode,
    GameRegion? region,
    int? secondsPerRound,
    int? roundsPerGame,
    int? maxMoveSteps,
  }) {
    return GameSettings(
      mode: mode ?? this.mode,
      region: region ?? this.region,
      secondsPerRound: secondsPerRound ?? this.secondsPerRound,
      roundsPerGame: roundsPerGame ?? this.roundsPerGame,
      maxMoveSteps: maxMoveSteps ?? this.maxMoveSteps,
    );
  }
}
