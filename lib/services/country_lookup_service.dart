// =============================================================================
// country_lookup_service
//
// 把街景的 (lat, lng) 反查成國家名稱（英文）。
// 用 Google Geocoding reverse geocode，因為本專案已經有 API Key，
// 不必額外多一條授權 / 額外的第三方服務。
//
// 回傳英文國家名；取不到就回 null（呼叫端要能處理 null → 走 fallback meme）。
// =============================================================================

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/config.dart';

Future<String?> lookupCountryName(double lat, double lng) async {
  if (kGoogleApiKey == 'YOUR_GOOGLE_API_KEY' || kGoogleApiKey.isEmpty) {
    return null;
  }
  final Uri uri = Uri.parse(
    'https://maps.googleapis.com/maps/api/geocode/json'
    '?latlng=$lat,$lng'
    '&language=en'
    '&result_type=country'
    '&key=$kGoogleApiKey',
  );
  try {
    final http.Response resp =
        await http.get(uri).timeout(const Duration(seconds: 6));
    if (resp.statusCode != 200) return null;
    final Map<String, dynamic> data =
        jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;
    final List<dynamic>? results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    // result_type=country 會把 formatted_address 直接當成國家英文名
    // 例：Japan / France / Taiwan / United States
    final Map<String, dynamic> first = results.first as Map<String, dynamic>;
    final Object? formatted = first['formatted_address'];
    if (formatted is String && formatted.isNotEmpty) {
      return formatted;
    }
    // fallback：掃 address_components 抓 country
    final List<dynamic>? comps = first['address_components'] as List<dynamic>?;
    if (comps != null) {
      for (final dynamic c in comps) {
        if (c is! Map<String, dynamic>) continue;
        final List<dynamic>? types = c['types'] as List<dynamic>?;
        if (types != null && types.contains('country')) {
          final Object? longName = c['long_name'];
          if (longName is String && longName.isNotEmpty) return longName;
        }
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}
