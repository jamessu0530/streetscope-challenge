// =============================================================================
// GameMode — 遊戲難度／互動模式
// =============================================================================

enum GameMode {
  /// 完整模式：可在街景中沿路走動 + 旋轉鏡頭 + 縮放。
  move,

  /// No Move：鏡頭可拖曳環視 / 縮放，但不能沿路走動（沒有地上箭頭）。
  noMove,

  /// Picture：完全靜態圖，連鏡頭都不能轉。
  picture,
}

extension GameModeX on GameMode {
  String get label {
    switch (this) {
      case GameMode.move:
        return '完整 Move';
      case GameMode.noMove:
        return 'No Move';
      case GameMode.picture:
        return 'Picture';
    }
  }

  String get description {
    switch (this) {
      case GameMode.move:
        return '可沿街景走動 + 旋轉鏡頭';
      case GameMode.noMove:
        return '只能旋轉鏡頭、不能走動';
      case GameMode.picture:
        return '完全靜態圖，連鏡頭都不能動';
    }
  }
}
