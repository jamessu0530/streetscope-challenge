// 保留舊版範例：目前專案已改為 `lib/config/env.dart` 讀取 `.env` / dart-define。
// 新做法：
//   1) 複製 `.env.example` 成 `.env`
//   2) 在 `.env` 放 `GOOGLE_API_KEY=...`
//   3) 或用 `--dart-define=GOOGLE_API_KEY=...`
const String kGoogleApiKey = 'YOUR_GOOGLE_API_KEY';
