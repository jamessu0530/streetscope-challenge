// =============================================================================
// 隨機產生題目：隨機點 + Metadata 找「可行走」街景（links 足夠、非明顯俯視）
// =============================================================================

import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place.dart';
import '../models/game_region.dart';
import '../utils/geo_utils.dart';
import 'street_view_service.dart';

final math.Random _rnd = math.Random();

/// 各區域抽點方框。格式：(south, north, west, east)
const Map<GameRegion, List<(double, double, double, double)>> _regionBoxes =
    <GameRegion, List<(double, double, double, double)>>{
  GameRegion.world: <(double, double, double, double)>[
    (33.0, 47.0, -103.0, -82.0),
    (43.0, 49.0, -95.0, -75.0),
    (46.0, 53.0, 1.0, 21.0),
    (38.0, 43.0, -7.0, -1.0),
    (44.0, 46.0, 8.0, 13.0),
    (52.0, 55.0, -3.0, 0.0),
    (35.0, 37.0, 137.0, 140.0),
    (36.0, 38.0, 127.0, 129.0),
    (28.0, 36.0, 106.0, 117.0),
    (19.0, 28.0, 76.0, 84.0),
    (-22.0, -16.0, -50.0, -44.0),
    (-35.0, -31.0, -64.0, -59.0),
    (-29.0, -25.0, 26.0, 30.0),
    (-36.0, -32.0, 145.0, 149.0),
  ],
  GameRegion.asia: <(double, double, double, double)>[
    (34.0, 37.0, 136.0, 140.0),
    (35.5, 38.0, 127.0, 129.0),
    (24.0, 32.0, 104.0, 116.0),
    (18.0, 28.0, 76.0, 84.0),
    (13.0, 17.0, 100.0, 104.0),
  ],
  GameRegion.europe: <(double, double, double, double)>[
    (46.0, 53.0, 2.0, 21.0),
    (40.0, 43.0, -6.0, -1.0),
    (44.0, 46.0, 8.0, 13.0),
    (52.0, 55.0, -3.0, 0.5),
  ],
  GameRegion.africa: <(double, double, double, double)>[
    (-29.0, -25.0, 26.0, 30.0),
    (30.0, 36.0, -8.0, 2.0),
    (5.0, 10.0, -1.0, 8.0),
  ],
  GameRegion.northAmerica: <(double, double, double, double)>[
    (33.0, 47.0, -103.0, -82.0),
    (43.0, 49.0, -95.0, -75.0),
    (19.0, 23.0, -102.0, -98.0),
  ],
  GameRegion.southAmerica: <(double, double, double, double)>[
    (-22.0, -16.0, -50.0, -44.0),
    (-35.0, -31.0, -64.0, -59.0),
    (-15.0, -11.0, -49.0, -45.0),
  ],
  GameRegion.oceania: <(double, double, double, double)>[
    (-36.0, -32.0, 145.0, 149.0),
    (-29.0, -24.0, 145.0, 151.0),
    (-44.0, -39.0, 170.0, 176.0),
  ],
  GameRegion.taiwan: <(double, double, double, double)>[
    (24.7, 25.2, 121.0, 121.9), // 北部
    (24.0, 24.8, 120.3, 121.0), // 中部
    (22.5, 23.2, 120.1, 120.9), // 南部
    (23.4, 24.2, 121.1, 121.8), // 東部
  ],
};

/// 100% 都從內陸框抽，不要再開全球隨機（會掉到海上）。
const double _landBiasFraction = 1.0;

/// 抽到的隨機點與最近全景的距離上限。
/// Google snap 太遠基本上代表周遭沒有街景（很可能是海邊 / 荒地），直接丟掉。
const double _maxSnapDistanceKm = 25;

void _randomLatLng(math.Random rnd, List<double> out, GameRegion region) {
  final List<(double, double, double, double)> boxes =
      _regionBoxes[region] ?? _regionBoxes[GameRegion.world]!;
  if (rnd.nextDouble() < _landBiasFraction) {
    final (double s, double n, double w, double e) =
        boxes[rnd.nextInt(boxes.length)];
    out[0] = s + rnd.nextDouble() * (n - s);
    out[1] = w + rnd.nextDouble() * (e - w);
  } else {
    out[0] = -58 + rnd.nextDouble() * 128;
    out[1] = -180 + rnd.nextDouble() * 360;
  }
}

/// 產生 [count] 個回合；每個點必須通過 [findNearestWalkablePanorama]（有足夠 links）。
Future<List<Place>> generateRandomPlaces({
  required int count,
  GameRegion region = GameRegion.world,
  int maxAttemptsPerRound = 150,
}) async {
  final List<Place> out = <Place>[];
  final List<double> ll = <double>[0, 0];

  for (int round = 0; round < count; round++) {
    Place? found;
    for (int attempt = 0; attempt < maxAttemptsPerRound; attempt++) {
      _randomLatLng(_rnd, ll, region);
      final double lat = ll[0];
      final double lng = ll[1];
      final PanoramaMetadata? meta =
          await findNearestPanoramaMetadata(lat, lng);
      if (meta == null) continue;

      final double snapKm = haversineKm(
        LatLng(lat, lng),
        LatLng(meta.latitude, meta.longitude),
      );
      if (snapKm > _maxSnapDistanceKm) continue;

      found = meta.toPlace();
      break;
    }
    if (found == null) {
      throw StateError(
        '連續 $maxAttemptsPerRound 次隨機點都找不到合適街景，'
        '請檢查 API Key、帳單、Street View Static / Street View API。',
      );
    }
    out.add(found);
  }

  return out;
}
