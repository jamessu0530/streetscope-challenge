// =============================================================================
// API Key 設定範本（會被 commit 進 Git，因此「絕對不可以」放真的 key）
// =============================================================================
//
// 第一次拿到專案：
//   1. 複製這份範本：
//        cp lib/config/config.example.dart lib/config/config.dart
//   2. 打開 lib/config/config.dart，把 YOUR_GOOGLE_API_KEY 換成你自己的 Google
//      API Key。
//   3. 同步把 ios/Runner/AppDelegate.swift 裡的
//        GMSServices.provideAPIKey("YOUR_GOOGLE_API_KEY")
//      也換成同一把 key。
//
// 進階：可改用 --dart-define 從環境變數注入：
//   flutter run --dart-define=GOOGLE_API_KEY=AIzaXXXX
//   const String kGoogleApiKey =
//       String.fromEnvironment('GOOGLE_API_KEY', defaultValue: '');
// =============================================================================

const String kGoogleApiKey = 'YOUR_GOOGLE_API_KEY';
