// =============================================================================
// AiOpponentService — 呼叫後端 /ai/guess，讓 Gemini 看街景圖猜經緯度
//
// 與玩家共用同一把計分尺：拿到 AI 的 LatLng 後，由 GamePage 用
// GuessResult.fromGuess(correctPlace, guessed) 計分（與玩家完全一致）。
//
// 設計原則：嚴格 timeout + 失敗回 null，永遠不阻塞 / 中斷遊戲主流程。
// =============================================================================

import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/ai_strength.dart';
import '../models/game_mode.dart';
import '../models/place.dart';

class AiOpponentGuess {
  final LatLng location;
  final double? confidence;
  final String? reasoning;

  const AiOpponentGuess({
    required this.location,
    this.confidence,
    this.reasoning,
  });
}

class AiOpponentService {
  AiOpponentService._();
  static final AiOpponentService instance = AiOpponentService._();

  bool get hasApi => kApiBaseUrl.isNotEmpty;

  /// 失敗（無 API / 逾時 / 後端 502 / 解析失敗）一律回 null，由呼叫端 fallback。
  ///
  /// [trail]：move 模式玩家沿路經過的地點（依序）。提供時 AI 會看整段路線，
  /// 而非只看終點。
  /// [strength]：AI 強度，影響後端取幾張圖（弱的 move 只看終點 → 不送 trail）。
  Future<AiOpponentGuess?> guess({
    required Place place,
    required GameMode mode,
    AiStrength strength = AiStrength.medium,
    double? playerHeading,
    List<Place>? trail,
  }) async {
    if (!hasApi) return null;

    final String base = kApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final Uri uri = Uri.parse('$base/ai/guess');

    final List<String> panoTrail = <String>[
      for (final Place p in trail ?? const <Place>[])
        if (p.panoId != null && p.panoId!.isNotEmpty) p.panoId!,
    ];

    // move 弱 = 只看終點，不送沿路足跡。
    final bool sendTrail = mode == GameMode.move &&
        strength != AiStrength.weak &&
        panoTrail.isNotEmpty;

    final Map<String, dynamic> body = <String, dynamic>{
      if (place.panoId != null && place.panoId!.isNotEmpty)
        'panoId': place.panoId,
      'lat': place.latitude,
      'lng': place.longitude,
      'mode': mode.name, // move / noMove / picture
      'strength': strength.apiValue, // weak / medium / strong
      if (mode == GameMode.picture) 'heading': (playerHeading ?? 0).round(),
      if (sendTrail) 'panoTrail': panoTrail,
    };

    try {
      final http.Response resp = await http
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return null;

      final num? lat = decoded['lat'] as num?;
      final num? lng = decoded['lng'] as num?;
      if (lat == null || lng == null) return null;

      return AiOpponentGuess(
        location: LatLng(lat.toDouble(), lng.toDouble()),
        confidence: (decoded['confidence'] as num?)?.toDouble(),
        reasoning: decoded['reasoning'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
