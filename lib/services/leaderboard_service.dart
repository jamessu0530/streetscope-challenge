import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';
import '../models/game_mode.dart';
import '../models/game_region.dart';
import '../models/game_settings.dart';
import '../models/guess_result.dart';
import '../models/leaderboard_entry.dart';
import 'auth_service.dart';

class LeaderboardException implements Exception {
  LeaderboardException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LeaderboardService {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  static const String _kEntriesKey = 'leaderboard_entries_v3';
  static const String _kLegacyKeyV1 = 'leaderboard_entries_v1';
  static const String _kLegacyKeyV2 = 'leaderboard_entries_v2';

  /// 清除本機舊排行榜（已改雲端 MongoDB）。
  Future<void> purgeLocalStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEntriesKey);
    await prefs.remove(_kLegacyKeyV1);
    await prefs.remove(_kLegacyKeyV2);
  }

  /// 登入後提交一局；回傳雲端紀錄 id（供排行榜高亮）。
  Future<String?> saveRun({
    required List<GuessResult> results,
    required GameSettings settings,
  }) async {
    final int totalScore = results.fold<int>(
      0,
      (int sum, GuessResult r) => sum + r.score,
    );
    return saveRunTotals(
      totalScore: totalScore,
      rounds: results.length,
      settings: settings,
    );
  }

  /// 以總分提交（對戰結算等沒有逐回合 [GuessResult] 時使用）。
  Future<String?> saveRunTotals({
    required int totalScore,
    required int rounds,
    required GameSettings settings,
  }) async {
    if (!AuthService.instance.isLoggedIn) {
      return null;
    }
    final String? token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty || !hasApiBaseUrl) {
      throw LeaderboardException('請先登入並設定 API_BASE_URL');
    }

    final http.Response response = await http
        .post(
          _uri(''),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(<String, dynamic>{
            'totalScore': totalScore,
            'rounds': rounds,
            'secondsPerRound': settings.secondsPerRound,
            'mode': settings.mode.name,
            'region': settings.region.name,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = _decodeJson(response.body);
      return data['id'] as String?;
    }
    throw LeaderboardException(_errorMessage(response));
  }

  Future<List<LeaderboardEntry>> loadAll({
    String sort = 'top',
    GameMode? mode,
    GameRegion? region,
    int limit = 50,
  }) async {
    if (!AuthService.instance.isLoggedIn) {
      throw LeaderboardException('請先登入才能查看雲端排行榜');
    }
    final String? token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty || !hasApiBaseUrl) {
      throw LeaderboardException('請設定 API_BASE_URL');
    }

    final Map<String, String> query = <String, String>{
      'sort': sort,
      'limit': limit.toString(),
    };
    if (mode != null) query['mode'] = mode.name;
    if (region != null) query['region'] = region.name;

    final http.Response response = await http.get(
      _uri('', query: query),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw LeaderboardException('伺服器回應格式錯誤');
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(LeaderboardEntry.fromApiJson)
          .toList();
    }
    throw LeaderboardException(_errorMessage(response));
  }

  Future<List<LeaderboardEntry>> loadTop10({
    GameMode? mode,
    GameRegion? region,
  }) async {
    final List<LeaderboardEntry> rows = await loadAll(
      sort: 'top',
      mode: mode,
      region: region,
      limit: 10,
    );
    return rows;
  }

  Future<List<LeaderboardEntry>> loadRecent10({
    GameMode? mode,
    GameRegion? region,
  }) async {
    return loadAll(
      sort: 'recent',
      mode: mode,
      region: region,
      limit: 10,
    );
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final String base = kApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final String suffix = path.isEmpty
        ? ''
        : (path.startsWith('/') ? path : '/$path');
    return Uri.parse('$base/leaderboard$suffix')
        .replace(queryParameters: query);
  }

  Map<String, dynamic> _decodeJson(String body) {
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw LeaderboardException('伺服器回應格式錯誤');
    }
    return decoded;
  }

  String _errorMessage(http.Response response) {
    try {
      final Map<String, dynamic> data = _decodeJson(response.body);
      final dynamic detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {
      // ignore
    }
    return '排行榜請求失敗（${response.statusCode}）';
  }
}
