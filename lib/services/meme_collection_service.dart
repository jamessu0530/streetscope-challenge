// =============================================================================
// MemeCollectionService — 雲端迷因庫（MongoDB，依使用者 + 國家）
// =============================================================================

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import '../models/collected_meme.dart';
import '../models/meme_result.dart';
import 'auth_service.dart';

class MemeCollectionException implements Exception {
  MemeCollectionException(this.message);
  final String message;

  @override
  String toString() => message;
}

class MemeCollectionService {
  MemeCollectionService._();
  static final MemeCollectionService instance = MemeCollectionService._();

  static const String _kLegacyStorageKey = 'meme_collection_v1';

  /// 清除本機舊迷因庫（已改雲端）。
  Future<void> purgeLocalStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLegacyStorageKey);
  }

  /// 登入後才會寫入；同一使用者同一 imageUrl 不重複。
  Future<bool> add({
    required MemeResult meme,
    required String? country,
    required int score,
  }) async {
    if (!AuthService.instance.isLoggedIn) return false;

    final String? token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty || !hasApiBaseUrl) return false;

    final http.Response response = await http
        .post(
          _uri(''),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(<String, dynamic>{
            'title': meme.title,
            'imageUrl': meme.imageUrl,
            'postUrl': meme.postUrl,
            'subreddit': meme.subreddit,
            'ups': meme.ups,
            'country': country,
            'score': score,
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    }
    return false;
  }

  Future<List<CollectedMeme>> loadAll() async {
    if (!AuthService.instance.isLoggedIn) {
      throw MemeCollectionException('請先登入才能查看迷因庫');
    }
    final String? token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty || !hasApiBaseUrl) {
      throw MemeCollectionException('請設定 API_BASE_URL');
    }

    final http.Response response = await http.get(
      _uri(''),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw MemeCollectionException('伺服器回應格式錯誤');
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CollectedMeme.fromApiJson)
          .toList();
    }
    throw MemeCollectionException(_errorMessage(response));
  }

  Future<Map<String, List<CollectedMeme>>> loadGroupedByCountry() async {
    final List<CollectedMeme> all = await loadAll();
    final Map<String, List<CollectedMeme>> map =
        <String, List<CollectedMeme>>{};
    for (final CollectedMeme m in all) {
      map.putIfAbsent(m.countryLabel, () => <CollectedMeme>[]).add(m);
    }
    for (final List<CollectedMeme> list in map.values) {
      list.sort(
        (CollectedMeme a, CollectedMeme b) =>
            b.collectedAt.compareTo(a.collectedAt),
      );
    }
    return map;
  }

  Future<void> clearAll() async {
    if (!AuthService.instance.isLoggedIn) {
      throw MemeCollectionException('請先登入');
    }
    final String? token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty || !hasApiBaseUrl) {
      throw MemeCollectionException('請設定 API_BASE_URL');
    }

    final http.Response response = await http.delete(
      _uri(''),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw MemeCollectionException(_errorMessage(response));
    }
  }

  Uri _uri(String path) {
    final String base = kApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final String suffix =
        path.isEmpty ? '' : (path.startsWith('/') ? path : '/$path');
    return Uri.parse('$base/memes$suffix');
  }

  String _errorMessage(http.Response response) {
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
      }
    } catch (_) {
      // ignore
    }
    return '迷因庫請求失敗（${response.statusCode}）';
  }
}
