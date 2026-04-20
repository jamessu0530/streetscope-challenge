// =============================================================================
// meme_service
//
// 懲罰用 meme 抓取：當玩家本回合分數 < 1000，去 Reddit 抓一個跟
// 目標國家相關的 meme 回來嘲諷玩家。
//
// 設計原則：
//   1. 優先用 Reddit 公開 JSON 端點（.json），不需要 OAuth，只要帶有禮貌的
//      User-Agent 就好。只讀不寫，完全不碰 login。
//   2. 擋掉 NSFW、擋掉 spoiler、擋掉沒有可顯示圖片的 post（只留實際 image post）。
//   3. 優先搜國家名相關 meme subreddits；不夠就 fallback 到通用嘲諷 query。
//   4. 再 fallback：若連 Reddit 都抓不到（被 429 / 403 / 斷線），改打
//      https://meme-api.com/gimme/memes 當作最後保底（只能拿通用 meme）。
//   5. 嚴格 timeout + 失敗直接 return 空，避免拖住遊戲流程。
//
// 輸出 spec：PunishmentMemeOutcome（見 models/meme_result.dart）。
// =============================================================================

import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/meme_result.dart';

/// 分數門檻：低於此分數才觸發。
const int kMemePunishmentScoreThreshold = 1000;

/// 一律帶上禮貌的 User-Agent；Reddit 對無 UA 的請求會 429 / 403。
const String _kRedditUserAgent =
    'geo_guesser/1.0 (by /u/geoguesser_flutter_demo)';

/// 通用 meme subreddits（無論國家一定會用）。
const List<String> _kCoreMemeSubs = <String>[
  'memes',
  'dankmemes',
  'me_irl',
];

/// 依國家名（英文）挑額外的社群 meme subreddits。
/// 這裡只列相對安全、更新頻繁的；找不到對應就只用 _kCoreMemeSubs。
const Map<String, List<String>> _kCountryExtraSubs = <String, List<String>>{
  'Japan': <String>['2asia4u', 'AnimeFunny'],
  'South Korea': <String>['2asia4u'],
  'Korea': <String>['2asia4u'],
  'China': <String>['2asia4u'],
  'Taiwan': <String>['2asia4u'],
  'Hong Kong': <String>['2asia4u'],
  'Thailand': <String>['2asia4u'],
  'Vietnam': <String>['2asia4u'],
  'India': <String>['2asia4u', 'IndianDankMemes'],
  'France': <String>['2westerneurope4u'],
  'Germany': <String>['2westerneurope4u'],
  'Italy': <String>['2westerneurope4u'],
  'Spain': <String>['2westerneurope4u'],
  'Netherlands': <String>['2westerneurope4u'],
  'United Kingdom': <String>['2westerneurope4u', 'CasualUK'],
  'Ireland': <String>['2westerneurope4u', 'ireland'],
  'Portugal': <String>['2westerneurope4u'],
  'Sweden': <String>['2westerneurope4u'],
  'United States': <String>['ShitAmericansSay'],
  'Canada': <String>['ShitAmericansSay', 'canada'],
  'Brazil': <String>['brasil'],
  'Mexico': <String>['mexico'],
  'Australia': <String>['straya'],
};

/// 完全沒國家 / 或國家 meme 抓不到時，用這些通用嘲諷 query。
const List<String> _kMockeryFallbackQueries = <String>[
  'wrong country meme',
  'clown meme',
  'you tried meme',
  'mission failed meme',
];

/// 單次 HTTP timeout。
const Duration _kHttpTimeout = Duration(seconds: 8);

/// 單次 search 結果最多取多少筆。
const int _kSearchLimit = 25;

/// 圖片副檔名，用來判斷「這是不是可預覽圖片」。
const List<String> _kImageExts = <String>[
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
];

/// 外部入口：給一個國家名 + 本回合分數，回傳 meme 結果。
/// 不會 throw；任何失敗 → triggered 依分數、但 selectedMeme=null。
Future<PunishmentMemeOutcome> fetchPunishmentMeme({
  required String? country,
  required int score,
}) async {
  if (score >= kMemePunishmentScoreThreshold) {
    return PunishmentMemeOutcome.notTriggered(score);
  }

  // Step 1: 依國家組第一個 query。country 可能是 null（反查失敗）。
  if (country != null && country.trim().isNotEmpty) {
    final String q1 = '$country meme';
    final List<String> subs = <String>[
      ..._kCoreMemeSubs,
      ...(_kCountryExtraSubs[country] ?? const <String>[]),
    ];
    final MemeResult? m1 =
        await _searchAndPick(subs: subs, query: q1, country: country);
    if (m1 != null) {
      return PunishmentMemeOutcome(
        triggered: true,
        country: country,
        score: score,
        queryUsed: q1,
        selectedMeme: m1,
        fallbackUsed: false,
      );
    }
    // Step 2: "country funny meme"，稍微不同的 query
    final String q2 = '$country funny meme';
    final MemeResult? m2 =
        await _searchAndPick(subs: subs, query: q2, country: country);
    if (m2 != null) {
      return PunishmentMemeOutcome(
        triggered: true,
        country: country,
        score: score,
        queryUsed: q2,
        selectedMeme: m2,
        fallbackUsed: false,
      );
    }
  }

  // Step 3: fallback 嘲諷 query，隨機挑一個
  final math.Random rnd = math.Random();
  final List<String> shuffled = List<String>.from(_kMockeryFallbackQueries)
    ..shuffle(rnd);
  for (final String q in shuffled) {
    final MemeResult? m = await _searchAndPick(
      subs: _kCoreMemeSubs,
      query: q,
      country: country,
    );
    if (m != null) {
      return PunishmentMemeOutcome(
        triggered: true,
        country: country,
        score: score,
        queryUsed: q,
        selectedMeme: m,
        fallbackUsed: true,
      );
    }
  }

  // Step 4: 最後保底 — 打通用 meme-api，抓一張通用 meme
  final MemeResult? emergency = await _emergencyMemeApi();
  return PunishmentMemeOutcome(
    triggered: true,
    country: country,
    score: score,
    queryUsed: emergency != null ? 'meme-api.com/gimme/memes' : null,
    selectedMeme: emergency,
    fallbackUsed: true,
  );
}

// ------ 以下為內部實作 --------------------------------------------------------

/// 打 Reddit 搜尋 → 過濾 → 排序 → 回單一 meme。
Future<MemeResult?> _searchAndPick({
  required List<String> subs,
  required String query,
  required String? country,
}) async {
  final List<_RedditPost> posts = await _searchReddit(
    subreddits: subs,
    query: query,
  );
  if (posts.isEmpty) return null;

  // 過濾 + 去重
  final Set<String> seen = <String>{};
  final List<_RedditPost> cleaned =
      posts.where(_isUsablePost).where((p) => seen.add(p.url)).toList();
  if (cleaned.isEmpty) return null;

  // 排序：依國家字串是否出現在 title、ups、是否明顯是 meme post
  cleaned.sort((a, b) => _score(b, country).compareTo(_score(a, country)));
  final _RedditPost best = cleaned.first;
  return MemeResult(
    title: best.title,
    imageUrl: best.imageUrl!,
    postUrl: best.permalink,
    subreddit: best.subreddit,
    ups: best.ups,
  );
}

/// 用 `r/a+b+c/search.json` 一次搜多個 subreddit，減少 round-trip。
Future<List<_RedditPost>> _searchReddit({
  required List<String> subreddits,
  required String query,
}) async {
  final String subsJoined = subreddits.join('+');
  final Uri uri = Uri.parse(
    'https://www.reddit.com/r/$subsJoined/search.json'
    '?q=${Uri.encodeQueryComponent(query)}'
    '&restrict_sr=on'
    '&sort=top'
    '&t=all'
    '&limit=$_kSearchLimit'
    '&include_over_18=false',
  );
  try {
    final http.Response resp = await http.get(uri, headers: <String, String>{
      'User-Agent': _kRedditUserAgent,
      'Accept': 'application/json',
    }).timeout(_kHttpTimeout);
    // Reddit 有時會回 403 / 429；直接放棄，不 throw。
    if (resp.statusCode != 200) return const <_RedditPost>[];
    return _parseRedditListing(resp.body);
  } catch (_) {
    return const <_RedditPost>[];
  }
}

/// 最後保底：meme-api.com 的 gimme endpoint（無認證、無 NSFW 搜尋參數，
/// 但官方預設就會過濾 NSFW）。
Future<MemeResult?> _emergencyMemeApi() async {
  final Uri uri = Uri.parse('https://meme-api.com/gimme/memes');
  try {
    final http.Response resp = await http.get(uri, headers: <String, String>{
      'User-Agent': _kRedditUserAgent,
      'Accept': 'application/json',
    }).timeout(_kHttpTimeout);
    if (resp.statusCode != 200) return null;
    final Map<String, dynamic> data =
        jsonDecode(resp.body) as Map<String, dynamic>;
    final bool nsfw = data['nsfw'] == true;
    final bool spoiler = data['spoiler'] == true;
    if (nsfw || spoiler) return null;
    final String? imageUrl = data['url'] as String?;
    if (imageUrl == null || !_looksLikeImageUrl(imageUrl)) return null;
    return MemeResult(
      title: (data['title'] as String?) ?? 'Mission failed',
      imageUrl: imageUrl,
      postUrl: (data['postLink'] as String?) ?? imageUrl,
      subreddit: (data['subreddit'] as String?) ?? 'memes',
      ups: (data['ups'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return null;
  }
}

/// 判斷 post 能不能用：非 NSFW、非 spoiler、有圖片。
bool _isUsablePost(_RedditPost p) {
  if (p.nsfw) return false;
  if (p.spoiler) return false;
  if (p.imageUrl == null) return false;
  if (p.title.isEmpty) return false;
  return true;
}

/// 排序分數：越高越優先。
int _score(_RedditPost p, String? country) {
  int s = 0;
  // ups：log 級別，避免爆炸大 post 把其他 filter 權重蓋過
  s += _logish(p.ups) * 8;
  // 標題有國家字串
  if (country != null) {
    final String lower = p.title.toLowerCase();
    if (lower.contains(country.toLowerCase())) s += 120;
  }
  // 看起來像 meme：標題短、post_hint = image
  if (p.postHint == 'image') s += 40;
  if (p.title.length < 80) s += 15;
  // 明顯是 meme 社群
  if (p.subreddit.contains('meme')) s += 20;
  return s;
}

int _logish(int n) {
  if (n <= 0) return 0;
  int i = 0;
  int x = n;
  while (x > 0) {
    x ~/= 2;
    i++;
  }
  return i; // 約等於 log2
}

/// 解析 Reddit listing JSON。
List<_RedditPost> _parseRedditListing(String body) {
  try {
    final Map<String, dynamic> root = jsonDecode(body) as Map<String, dynamic>;
    final Map<String, dynamic>? data = root['data'] as Map<String, dynamic>?;
    if (data == null) return const <_RedditPost>[];
    final List<dynamic>? children = data['children'] as List<dynamic>?;
    if (children == null) return const <_RedditPost>[];

    final List<_RedditPost> out = <_RedditPost>[];
    for (final dynamic c in children) {
      if (c is! Map<String, dynamic>) continue;
      final Map<String, dynamic>? d = c['data'] as Map<String, dynamic>?;
      if (d == null) continue;
      out.add(_RedditPost.fromJson(d));
    }
    return out;
  } catch (_) {
    return const <_RedditPost>[];
  }
}

bool _looksLikeImageUrl(String url) {
  final String lower = url.toLowerCase().split('?').first;
  for (final String ext in _kImageExts) {
    if (lower.endsWith(ext)) return true;
  }
  // i.redd.it / i.imgur.com 常常沒副檔名但一定是圖
  final Uri? uri = Uri.tryParse(url);
  if (uri != null) {
    final String h = uri.host.toLowerCase();
    if (h == 'i.redd.it' || h == 'i.imgur.com') return true;
  }
  return false;
}

/// Reddit post 的精簡版本，只留我們會用到的欄位。
class _RedditPost {
  final String title;
  final String subreddit;
  final String url;
  final String permalink;
  final int ups;
  final bool nsfw;
  final bool spoiler;
  final String? postHint;
  final String? imageUrl;

  const _RedditPost({
    required this.title,
    required this.subreddit,
    required this.url,
    required this.permalink,
    required this.ups,
    required this.nsfw,
    required this.spoiler,
    required this.postHint,
    required this.imageUrl,
  });

  factory _RedditPost.fromJson(Map<String, dynamic> d) {
    final String title = (d['title'] as String?) ?? '';
    final String subreddit = (d['subreddit'] as String?) ??
        (d['subreddit_name_prefixed'] as String?)?.replaceFirst('r/', '') ??
        '';
    final String url =
        (d['url_overridden_by_dest'] as String?) ?? (d['url'] as String?) ?? '';
    final String permalinkRaw = (d['permalink'] as String?) ?? '';
    final String permalink = permalinkRaw.startsWith('http')
        ? permalinkRaw
        : 'https://www.reddit.com$permalinkRaw';
    final int ups = (d['ups'] as num?)?.toInt() ?? 0;
    final bool nsfw = d['over_18'] == true;
    final bool spoiler = d['spoiler'] == true;
    final String? postHint = d['post_hint'] as String?;

    // 嘗試從多個地方抽出可預覽的圖片 URL：
    // 1) url 本身是 .jpg / .png / ...
    // 2) preview.images[0].source.url（要把 HTML entity 還原）
    String? imageUrl;
    if (_looksLikeImageUrl(url)) {
      imageUrl = url;
    } else {
      final Map<String, dynamic>? preview =
          d['preview'] as Map<String, dynamic>?;
      final List<dynamic>? images = preview?['images'] as List<dynamic>?;
      if (images != null && images.isNotEmpty) {
        final Map<String, dynamic>? first =
            images.first as Map<String, dynamic>?;
        final Map<String, dynamic>? source =
            first?['source'] as Map<String, dynamic>?;
        final String? src = source?['url'] as String?;
        if (src != null && src.isNotEmpty) {
          imageUrl = src.replaceAll('&amp;', '&');
        }
      }
    }

    return _RedditPost(
      title: title,
      subreddit: subreddit,
      url: url,
      permalink: permalink,
      ups: ups,
      nsfw: nsfw,
      spoiler: spoiler,
      postHint: postHint,
      imageUrl: imageUrl,
    );
  }
}
