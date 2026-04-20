// =============================================================================
// 計分：1 公里 = 扣 1 分，5000 公里以上 0 分
// =============================================================================
//
// 規則：
//   - 距離 < 1 km   → 5000（滿分）
//   - 距離 = 1 km   → 4999
//   - 距離 = 2 km   → 4998
//   - ...
//   - 距離 = 5000 km → 0
//   - 距離 > 5000 km → 0
//
// 公式：score = max(0, 5000 - round(distanceKm))
// =============================================================================

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'geo_utils.dart';

/// 滿分。
const int kMaxScore = 5000;

/// 超過此距離直接 0 分（也是扣完所有分的臨界點）。
const double kZeroScoreDistanceKm = 5000.0;

int scoreFromDistanceKm(double distanceKm) {
  if (distanceKm < 1.0) return kMaxScore;
  if (distanceKm >= kZeroScoreDistanceKm) return 0;
  final int score = kMaxScore - distanceKm.round();
  if (score < 0) return 0;
  if (score > kMaxScore) return kMaxScore;
  return score;
}

int scoreForGuess({
  required LatLng guess,
  required LatLng correct,
}) {
  return scoreFromDistanceKm(haversineKm(guess, correct));
}
