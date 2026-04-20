// =============================================================================
// GuessResult — 一回合的結算結果
//
// ✅ [Custom Model] 作業要求的自訂資料模型 #2
// =============================================================================

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/geo_utils.dart';
import '../utils/score_utils.dart';
import 'place.dart';

class GuessResult {
  final Place correctPlace;
  final LatLng? guessed;
  final double? distanceKm;
  final int score;

  const GuessResult({
    required this.correctPlace,
    required this.guessed,
    required this.distanceKm,
    required this.score,
  });

  bool get answered => guessed != null;

  factory GuessResult.fromGuess({
    required Place correctPlace,
    required LatLng guessed,
  }) {
    final double d = haversineKm(guessed, correctPlace.latLng);
    return GuessResult(
      correctPlace: correctPlace,
      guessed: guessed,
      distanceKm: d,
      score: scoreFromDistanceKm(d),
    );
  }

  factory GuessResult.noAnswer(Place correctPlace) {
    return GuessResult(
      correctPlace: correctPlace,
      guessed: null,
      distanceKm: null,
      score: 0,
    );
  }
}
