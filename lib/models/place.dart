// =============================================================================
// Place — 一回合的正確答案座標
// =============================================================================
//
// 題目來源：隨機點 + Street View Metadata 對齊到「可行走」的全景（含 [panoId]）。
// [panoId] 用於 Static 圖與與鄰接全景（links）導航，與 Google 網頁街景一致。
// =============================================================================

import 'package:google_maps_flutter/google_maps_flutter.dart';

class Place {
  /// 街景全景實際所在位置（Google Metadata 的 location）。
  final double latitude;
  final double longitude;

  /// Street View panorama id；有則 Static API 用 `pano=`，並可走 links 導航。
  final String? panoId;

  const Place({
    required this.latitude,
    required this.longitude,
    this.panoId,
  });

  LatLng get latLng => LatLng(latitude, longitude);
}
