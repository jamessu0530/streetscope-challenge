// =============================================================================
// GameSettings — 從首頁帶去 GamePage 的整包設定
// =============================================================================

import '../data/game_constants.dart';
import 'ai_strength.dart';
import 'game_mode.dart';
import 'game_region.dart';
import 'place.dart';

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

  /// 真人對戰（WebSocket 房間）。
  final bool vsPlayer;
  final String? duelRoomId;
  final String? opponentUserId;
  final String? opponentDisplayName;

  /// 房主產生的共用題目；有值時 GamePage 不再自行抽題。
  final List<Place>? presetPlaces;

  /// 好友對戰娛樂模式：可用 AI 建議（使用後該回合折半）、不寫入排行榜。
  final bool entertainmentMode;

  const GameSettings({
    this.mode = GameMode.move,
    this.region = GameRegion.world,
    this.secondsPerRound = kSecondsPerRound,
    this.roundsPerGame = kRoundsPerGame,
    this.maxMoveSteps = 0,
    this.vsAi = false,
    this.aiStrength = AiStrength.medium,
    this.vsPlayer = false,
    this.duelRoomId,
    this.opponentUserId,
    this.opponentDisplayName,
    this.presetPlaces,
    this.entertainmentMode = false,
  });

  GameSettings copyWith({
    GameMode? mode,
    GameRegion? region,
    int? secondsPerRound,
    int? roundsPerGame,
    int? maxMoveSteps,
    bool? vsAi,
    AiStrength? aiStrength,
    bool? vsPlayer,
    String? duelRoomId,
    String? opponentUserId,
    String? opponentDisplayName,
    List<Place>? presetPlaces,
    bool? entertainmentMode,
  }) {
    return GameSettings(
      mode: mode ?? this.mode,
      region: region ?? this.region,
      secondsPerRound: secondsPerRound ?? this.secondsPerRound,
      roundsPerGame: roundsPerGame ?? this.roundsPerGame,
      maxMoveSteps: maxMoveSteps ?? this.maxMoveSteps,
      vsAi: vsAi ?? this.vsAi,
      aiStrength: aiStrength ?? this.aiStrength,
      vsPlayer: vsPlayer ?? this.vsPlayer,
      duelRoomId: duelRoomId ?? this.duelRoomId,
      opponentUserId: opponentUserId ?? this.opponentUserId,
      opponentDisplayName:
          opponentDisplayName ?? this.opponentDisplayName,
      presetPlaces: presetPlaces ?? this.presetPlaces,
      entertainmentMode: entertainmentMode ?? this.entertainmentMode,
    );
  }

  Map<String, dynamic> toDuelJson() => <String, dynamic>{
        'mode': mode.name,
        'region': region.name,
        'secondsPerRound': secondsPerRound,
        'roundsPerGame': roundsPerGame,
        'maxMoveSteps': maxMoveSteps,
        'entertainmentMode': entertainmentMode,
      };
}

GameSettings duelSettingsFromJson(Map<String, dynamic> json) {
  GameMode mode = GameMode.picture;
  for (final GameMode m in GameMode.values) {
    if (m.name == json['mode']) {
      mode = m;
      break;
    }
  }
  GameRegion region = GameRegion.world;
  for (final GameRegion r in GameRegion.values) {
    if (r.name == json['region']) {
      region = r;
      break;
    }
  }
  return GameSettings(
    mode: mode,
    region: region,
    secondsPerRound: (json['secondsPerRound'] as num?)?.toInt() ?? kSecondsPerRound,
    roundsPerGame: (json['roundsPerGame'] as num?)?.toInt() ?? kRoundsPerGame,
    maxMoveSteps: (json['maxMoveSteps'] as num?)?.toInt() ?? 0,
    entertainmentMode: json['entertainmentMode'] == true,
  );
}
