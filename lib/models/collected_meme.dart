// =============================================================================
// CollectedMeme — 玩家蒐集到的迷因資料模型
//
// 每當遊戲中低分懲罰抓到一個 meme，就會把它存進本地蒐集庫。之後可以在
// 「MEME 收集庫」頁面檢視、依國家分類、或再次瀏覽。
// =============================================================================

import 'dart:convert';

import '../models/meme_result.dart';

class CollectedMeme {
  final String title;
  final String imageUrl;
  final String postUrl;
  final String subreddit;
  final int ups;

  /// 觸發此 meme 的國家（無法反查時為 null / unknown）。
  final String? country;

  /// 觸發時玩家本回合的分數。
  final int score;

  /// 蒐集時間。用來排序 / 去重。
  final DateTime collectedAt;

  const CollectedMeme({
    required this.title,
    required this.imageUrl,
    required this.postUrl,
    required this.subreddit,
    required this.ups,
    required this.country,
    required this.score,
    required this.collectedAt,
  });

  factory CollectedMeme.fromResult({
    required MemeResult meme,
    required String? country,
    required int score,
    DateTime? collectedAt,
  }) {
    return CollectedMeme(
      title: meme.title,
      imageUrl: meme.imageUrl,
      postUrl: meme.postUrl,
      subreddit: meme.subreddit,
      ups: meme.ups,
      country: country,
      score: score,
      collectedAt: collectedAt ?? DateTime.now(),
    );
  }

  String get countryLabel =>
      (country == null || country!.trim().isEmpty) ? 'Unknown' : country!;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'image_url': imageUrl,
        'post_url': postUrl,
        'subreddit': subreddit,
        'ups': ups,
        'country': country,
        'score': score,
        'collected_at': collectedAt.toIso8601String(),
      };

  factory CollectedMeme.fromJson(Map<String, dynamic> j) {
    return CollectedMeme(
      title: (j['title'] as String?) ?? '',
      imageUrl: (j['image_url'] as String?) ?? '',
      postUrl: (j['post_url'] as String?) ?? '',
      subreddit: (j['subreddit'] as String?) ?? '',
      ups: (j['ups'] as num?)?.toInt() ?? 0,
      country: j['country'] as String?,
      score: (j['score'] as num?)?.toInt() ?? 0,
      collectedAt:
          DateTime.tryParse(j['collected_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  String encode() => jsonEncode(toJson());
  factory CollectedMeme.decode(String s) =>
      CollectedMeme.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
