// =============================================================================
// Google Map 相關的小工具
// =============================================================================

import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 把兩個座標包成可以丟給 `CameraUpdate.newLatLngBounds(...)` 的 bounds。
///
/// 注意：不處理跨換日線的特殊情形（學生作業範圍不會遇到）。
LatLngBounds boundsForTwoPoints(LatLng a, LatLng b) {
  final double south = math.min(a.latitude, b.latitude);
  final double north = math.max(a.latitude, b.latitude);
  final double west = math.min(a.longitude, b.longitude);
  final double east = math.max(a.longitude, b.longitude);
  return LatLngBounds(
    southwest: LatLng(south, west),
    northeast: LatLng(north, east),
  );
}
