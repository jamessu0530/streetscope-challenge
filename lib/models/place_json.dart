import 'place.dart';

extension PlaceJson on Place {
  Map<String, dynamic> toJson() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        if (panoId != null && panoId!.isNotEmpty) 'panoId': panoId,
      };

  static Place fromJson(Map<String, dynamic> json) {
    return Place(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      panoId: json['panoId'] as String?,
    );
  }

  static List<Place> listFromJson(List<dynamic> raw) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PlaceJson.fromJson)
        .toList();
  }
}
