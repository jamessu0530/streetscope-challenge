// =============================================================================
// Google Map 相關的小工具
// =============================================================================

import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 把兩個座標包成可以丟給 `CameraUpdate.newLatLngBounds(...)` 的 bounds。
///
/// 注意：不處理跨換日線的特殊情形（學生作業範圍不會遇到）。
LatLngBounds boundsForTwoPoints(LatLng a, LatLng b) {
  return boundsForPoints(<LatLng>[a, b]);
}

/// 把多個座標包成 bounds（至少一個點）。
LatLngBounds boundsForPoints(Iterable<LatLng> points) {
  final List<LatLng> list = points.toList();
  if (list.isEmpty) {
    return LatLngBounds(
      southwest: const LatLng(-1, -1),
      northeast: const LatLng(1, 1),
    );
  }
  double south = list.first.latitude;
  double north = list.first.latitude;
  double west = list.first.longitude;
  double east = list.first.longitude;
  for (final LatLng p in list.skip(1)) {
    south = math.min(south, p.latitude);
    north = math.max(north, p.latitude);
    west = math.min(west, p.longitude);
    east = math.max(east, p.longitude);
  }
  return LatLngBounds(
    southwest: LatLng(south, west),
    northeast: LatLng(north, east),
  );
}
