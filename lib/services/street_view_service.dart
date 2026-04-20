// =============================================================================
// Street View — Metadata（pano + links + tilt）+ Static 圖
// =============================================================================
//
// 與 Google 地圖網頁街景相同：用 Metadata 的 [links] 在鄰接全景間移動，
// 不再用「往某座標找最近全景」模擬走路（避免船上／無路網）。
//
// 參考：
//   https://developers.google.com/maps/documentation/streetview/metadata
//   https://developers.google.com/maps/documentation/streetview/image
// =============================================================================

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/place.dart';

/// Metadata 裡單一「可走方向」：與官方 maps 街景地上箭頭同源。
class StreetViewLink {
  final double headingDeg;
  final String panoId;

  const StreetViewLink({
    required this.headingDeg,
    required this.panoId,
  });
}

/// 一次 Metadata 回傳的完整資訊（成功時）。
class PanoramaMetadata {
  final String panoId;
  final double latitude;
  final double longitude;
  final List<StreetViewLink> links;

  /// 相機俯仰；接近 90° 表示幾乎垂直向下（空拍／俯視），體驗不適合本遊戲。
  final double? tiltDeg;

  const PanoramaMetadata({
    required this.panoId,
    required this.latitude,
    required this.longitude,
    required this.links,
    this.tiltDeg,
  });

  Place toPlace() => Place(
        latitude: latitude,
        longitude: longitude,
        panoId: panoId,
      );
}

// 注意：Google 的 HTTP Metadata 端點目前**不會**回傳 links / tilt
// （那是 Maps JavaScript StreetViewService 才有）。所以我們只能在能拿到的時候做過濾。

PanoramaMetadata? _parseMetadataJson(Map<String, dynamic> data) {
  if (data['status'] != 'OK') return null;

  final Object? panoRaw = data['pano_id'];
  if (panoRaw is! String || panoRaw.isEmpty) return null;

  final Map<String, dynamic>? loc = data['location'] as Map<String, dynamic>?;
  if (loc == null) return null;
  final Object? la = loc['lat'];
  final Object? ln = loc['lng'];
  if (la is! num || ln is! num) return null;

  double? tiltDeg;
  final Object? t = data['tilt'];
  if (t is num) tiltDeg = t.toDouble();

  final List<StreetViewLink> links = <StreetViewLink>[];
  final List<dynamic>? linksRaw = data['links'] as List<dynamic>?;
  if (linksRaw != null) {
    for (final dynamic item in linksRaw) {
      if (item is! Map<String, dynamic>) continue;
      final Object? h = item['heading'];
      final Object? p = item['pano'];
      if (h is num && p is String && p.isNotEmpty) {
        links.add(
          StreetViewLink(headingDeg: h.toDouble(), panoId: p),
        );
      }
    }
  }

  return PanoramaMetadata(
    panoId: panoRaw,
    latitude: la.toDouble(),
    longitude: ln.toDouble(),
    links: links,
    tiltDeg: tiltDeg,
  );
}

Future<PanoramaMetadata?> fetchPanoramaMetadata({
  String? panoId,
  double? lat,
  double? lng,
  int? radiusMeters,
}) async {
  if (!hasGoogleApiKey) {
    return null;
  }
  if (panoId != null && panoId.isNotEmpty) {
    final Uri uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/streetview/metadata'
      '?pano=$panoId'
      '&key=$kGoogleApiKey',
    );
    return _getMetadata(uri);
  }
  if (lat != null && lng != null) {
    final String r = radiusMeters != null ? '&radius=$radiusMeters' : '';
    // source=outdoor: 只回戶外街景，過濾掉室內 / 部分商家內部全景
    final Uri uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/streetview/metadata'
      '?location=$lat,$lng'
      '$r'
      '&source=outdoor'
      '&key=$kGoogleApiKey',
    );
    return _getMetadata(uri);
  }
  return null;
}

Future<PanoramaMetadata?> _getMetadata(Uri uri) async {
  try {
    final http.Response resp =
        await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return null;
    final Map<String, dynamic> data =
        jsonDecode(resp.body) as Map<String, dynamic>;
    return _parseMetadataJson(data);
  } catch (_) {
    return null;
  }
}

/// 以 (lat,lng) 為中心遞增半徑搜尋最近的可顯示全景。
///
/// 半徑刻意壓在 25km 內：避免 Google 一路 snap 到幾百公里外的海岸／離島，
/// 抽不到的點直接讓 picker 換下一個隨機坐標重抽。
Future<PanoramaMetadata?> findNearestPanoramaMetadata(
  double lat,
  double lng,
) async {
  if (!hasGoogleApiKey) {
    return null;
  }

  const List<int> radiiMeters = <int>[5000, 15000, 25000];

  for (final int radius in radiiMeters) {
    final PanoramaMetadata? m =
        await fetchPanoramaMetadata(lat: lat, lng: lng, radiusMeters: radius);
    if (m != null) return m;
  }
  return null;
}

/// 「往前走一步」用：以小半徑找鄰近全景；用於沒有 links 時的 fallback。
Future<PanoramaMetadata?> findNearbyPanoramaMetadata(
  double lat,
  double lng,
) async {
  if (!hasGoogleApiKey) {
    return null;
  }
  const List<int> radiiMeters = <int>[60, 200, 600, 2000];
  for (final int radius in radiiMeters) {
    final PanoramaMetadata? m =
        await fetchPanoramaMetadata(lat: lat, lng: lng, radiusMeters: radius);
    if (m != null) return m;
  }
  return null;
}

/// Street View Static API — 優先使用 [panoId]（與官方一致）。
String streetViewStaticImageUrl(
  Place place, {
  int heading = 0,
  int pitch = 0,
  int fov = 90,
  int width = 640,
  int height = 400,
}) {
  final String base = 'https://maps.googleapis.com/maps/api/streetview'
      '?size=${width}x$height'
      '&heading=$heading'
      '&pitch=$pitch'
      '&fov=$fov'
      '&key=$kGoogleApiKey';
  final String? pid = place.panoId;
  if (pid != null && pid.isNotEmpty) {
    return '$base&pano=$pid';
  }
  return '$base&location=${place.latitude},${place.longitude}';
}
