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

/// 後端 API 根網址（登入、排行榜等）。未設定時為空。
String get kApiBaseUrl =>
    dotenv.maybeGet('API_BASE_URL')?.trim() ??
    const String.fromEnvironment('API_BASE_URL', defaultValue: '').trim();

bool get hasApiBaseUrl => kApiBaseUrl.isNotEmpty;

/// Google OAuth Web Client ID（後端驗 idToken、Flutter serverClientId）。
String get kGoogleWebClientId {
  final String fromDotEnv =
      dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID')?.trim() ?? '';
  if (fromDotEnv.isNotEmpty) return fromDotEnv;
  return const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '')
      .trim();
}

/// Google OAuth iOS Client ID（僅 iOS 原生登入流程）。
String get kGoogleIosClientId {
  final String fromDotEnv =
      dotenv.maybeGet('GOOGLE_IOS_CLIENT_ID')?.trim() ?? '';
  if (fromDotEnv.isNotEmpty) return fromDotEnv;
  return const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID', defaultValue: '')
      .trim();
}

bool get hasGoogleOAuth => kGoogleIosClientId.isNotEmpty;

String get kFacebookAppId {
  final String fromDotEnv =
      dotenv.maybeGet('FACEBOOK_APP_ID')?.trim() ?? '';
  if (fromDotEnv.isNotEmpty) return fromDotEnv;
  return const String.fromEnvironment('FACEBOOK_APP_ID', defaultValue: '')
      .trim();
}

bool get hasFacebookAppId => kFacebookAppId.isNotEmpty;

/// GitHub OAuth App Client ID（Flutter 開授權頁用）。
String get kGithubClientId {
  final String fromDotEnv =
      dotenv.maybeGet('GITHUB_CLIENT_ID')?.trim() ?? '';
  if (fromDotEnv.isNotEmpty) return fromDotEnv;
  return const String.fromEnvironment('GITHUB_CLIENT_ID', defaultValue: '')
      .trim();
}

/// 須與 GitHub OAuth App 的 Authorization callback URL 一致。
String get kGithubOAuthRedirectUri {
  final String fromDotEnv =
      dotenv.maybeGet('GITHUB_OAUTH_REDIRECT_URI')?.trim() ?? '';
  if (fromDotEnv.isNotEmpty) return fromDotEnv;
  return const String.fromEnvironment(
    'GITHUB_OAUTH_REDIRECT_URI',
    defaultValue: 'com.example.geoGuesser://github-callback',
  ).trim();
}

bool get hasGithubOAuth => kGithubClientId.isNotEmpty;

/// MongoDB 連線字串 — 僅供未來後端或本機腳本參考；Flutter UI 不應直連資料庫。
String get kMongoDbUri =>
    dotenv.maybeGet('MONGODB_URI')?.trim() ??
    const String.fromEnvironment('MONGODB_URI', defaultValue: '').trim();
