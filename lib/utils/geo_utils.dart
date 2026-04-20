// =============================================================================
// 地理座標相關的純數學函式（無 Flutter / 無 Google API 依賴 → 易於測試）
// =============================================================================

import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 角度 → 弧度
double degToRad(double deg) => deg * (math.pi / 180.0);

/// 兩個經緯度之間的球面距離（公里）。
/// 使用 Haversine 公式，地球半徑取 6371 km。
double haversineKm(LatLng a, LatLng b) {
  const double earthRadiusKm = 6371.0;
  final double dLat = degToRad(b.latitude - a.latitude);
  final double dLng = degToRad(b.longitude - a.longitude);

  final double sinDLat = math.sin(dLat / 2);
  final double sinDLng = math.sin(dLng / 2);

  final double h = sinDLat * sinDLat +
      math.cos(degToRad(a.latitude)) *
          math.cos(degToRad(b.latitude)) *
          sinDLng *
          sinDLng;

  return 2 * earthRadiusKm * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
