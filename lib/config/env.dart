import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 讀取 Google API Key：
/// 1) `.env` 的 GOOGLE_API_KEY（本機開發）
/// 2) `--dart-define=GOOGLE_API_KEY=...`（CI/CD）
/// 3) 都沒有就回空字串
String get kGoogleApiKey {
  final String fromDotEnv = dotenv.maybeGet('GOOGLE_API_KEY')?.trim() ?? '';
  if (fromDotEnv.isNotEmpty) return fromDotEnv;
  return const String.fromEnvironment('GOOGLE_API_KEY', defaultValue: '')
      .trim();
}

bool get hasGoogleApiKey => kGoogleApiKey.isNotEmpty;
