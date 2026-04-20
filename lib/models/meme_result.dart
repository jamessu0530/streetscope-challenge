// =============================================================================
// MemeResult / PunishmentMemeOutcome
//
// 回合分數 < 1000 分時 meme 服務的輸出資料結構。
// JSON 形狀與 spec 對齊：
// {
//   "triggered": true,
//   "country": "Japan",
//   "score": 742,
//   "query_used": "Japan meme",
//   "selected_meme": {
//     "title": "...",
//     "image_url": "...",
//     "post_url": "...",
//     "subreddit": "...",
//     "ups": 1234
//   },
//   "fallback_used": false
// }
// =============================================================================

class MemeResult {
  final String title;
  final String imageUrl;
  final String postUrl;
  final String subreddit;
  final int ups;

  const MemeResult({
    required this.title,
    required this.imageUrl,
    required this.postUrl,
    required this.subreddit,
    required this.ups,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'image_url': imageUrl,
        'post_url': postUrl,
        'subreddit': subreddit,
        'ups': ups,
      };
}

class PunishmentMemeOutcome {
  /// 本回合是否真的有觸發懲罰（分數 < 1000 才會 true）。
  final bool triggered;

  /// 懲罰對應的國家名稱（沒辦法解析就是 null）。
  final String? country;

  /// 本回合玩家分數，方便 debug / 之後寫 log。
  final int score;

  /// 最後實際送出的 Reddit 搜尋 query，例如 "Japan meme"。
  /// 沒觸發時是 null。
  final String? queryUsed;

  /// 實際挑出的 meme。觸發但都抓不到時是 null。
  final MemeResult? selectedMeme;

  /// 是不是用 fallback（找不到國家 meme → 改用 "mission failed" 等）。
  final bool fallbackUsed;

  const PunishmentMemeOutcome({
    required this.triggered,
    required this.country,
    required this.score,
    required this.queryUsed,
    required this.selectedMeme,
    required this.fallbackUsed,
  });

  /// 沒觸發時的空輸出（score >= 1000 或呼叫端還沒有國家資訊）。
  factory PunishmentMemeOutcome.notTriggered(int score) {
    return PunishmentMemeOutcome(
      triggered: false,
      country: null,
      score: score,
      queryUsed: null,
      selectedMeme: null,
      fallbackUsed: false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'triggered': triggered,
        'country': country,
        'score': score,
        'query_used': queryUsed,
        'selected_meme': selectedMeme?.toJson(),
        'fallback_used': fallbackUsed,
      };
}
