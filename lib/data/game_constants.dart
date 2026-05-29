// =============================================================================
// 遊戲常數（不依賴題庫）
// =============================================================================

const int kRoundsPerGame = 5;
const int kSecondsPerRound = 30;
const int kMinSecondsPerRound = 30;
const int kMaxSecondsPerRound = 120;

/// 首頁可選回合數清單（短局到長局都能玩）。
const List<int> kRoundsPerGameOptions = <int>[3, 5, 10];

/// 倒數剩餘秒數 ≤ 此值時，每秒播放 tick 音效。
const int kCountdownTickThresholdSeconds = 5;

/// 探索階段 BGM：剩餘秒數 **大於** 此值時播輕柔曲；≤ 此值改播 lofi（見 game_page）。
const int kCalmBgmEndRemainingSeconds = 30;

/// 「可移動步數上限」選項。0 = 無限制。
const List<int> kMoveStepLimitOptions = <int>[0, 5, 10, 20, 50];
