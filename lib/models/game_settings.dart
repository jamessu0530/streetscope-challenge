// =============================================================================
// GameSettings — 從首頁帶去 GamePage 的整包設定
// =============================================================================

import '../data/game_constants.dart';
import 'ai_strength.dart';
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

  /// 是否與 AI（Gemini 看街景圖猜經緯度）對戰。
  final bool vsAi;

  /// AI 對手強度（弱 / 中 / 強）。picture 模式不受影響。
  final AiStrength aiStrength;

  const GameSettings({
    this.mode = GameMode.move,
    this.region = GameRegion.world,
    this.secondsPerRound = kSecondsPerRound,
    this.roundsPerGame = kRoundsPerGame,
    this.maxMoveSteps = 0,
    this.vsAi = false,
    this.aiStrength = AiStrength.medium,
  });

  GameSettings copyWith({
    GameMode? mode,
    GameRegion? region,
    int? secondsPerRound,
    int? roundsPerGame,
    int? maxMoveSteps,
    bool? vsAi,
    AiStrength? aiStrength,
  }) {
    return GameSettings(
      mode: mode ?? this.mode,
      region: region ?? this.region,
      secondsPerRound: secondsPerRound ?? this.secondsPerRound,
      roundsPerGame: roundsPerGame ?? this.roundsPerGame,
      maxMoveSteps: maxMoveSteps ?? this.maxMoveSteps,
      vsAi: vsAi ?? this.vsAi,
      aiStrength: aiStrength ?? this.aiStrength,
    );
  }
}
