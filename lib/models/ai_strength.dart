// =============================================================================
// AiStrength — AI 對手智能強度（弱 / 中 / 強）
//
// 影響 AI 能看到多少街景資訊：
//   move    弱=只看終點、中=沿路 8 點、強=沿路 16 點
//   noMove  弱=1 張、中=2 張、強=4 張
//   picture 不受強弱影響（一律 1 張）
// =============================================================================

enum AiStrength {
  weak,
  medium,
  strong,
}

extension AiStrengthX on AiStrength {
  /// 後端 API 用的字串（與 enum 名稱一致）。
  String get apiValue => name;

  String get label {
    switch (this) {
      case AiStrength.weak:
        return '弱';
      case AiStrength.medium:
        return '中';
      case AiStrength.strong:
        return '強';
    }
  }

  /// 該強度的整體說明（給設定頁顯示）。
  String get description {
    switch (this) {
      case AiStrength.weak:
        return 'Move 只看終點 ・ No Move 1 張';
      case AiStrength.medium:
        return 'Move 沿路 8 點 ・ No Move 2 張';
      case AiStrength.strong:
        return 'Move 沿路 16 點 ・ No Move 4 張';
    }
  }

  static AiStrength fromIndex(int index) {
    if (index <= 0) return AiStrength.weak;
    if (index >= 2) return AiStrength.strong;
    return AiStrength.medium;
  }
}
