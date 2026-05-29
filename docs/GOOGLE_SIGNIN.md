# Google 登入設定（Flutter + FastAPI + MongoDB）

## 1. Google Cloud Console（與地圖同一個專案即可）

1. 打開 [Google Cloud Console](https://console.cloud.google.com/) → 選你的專案  
2. **APIs & Services** → **OAuth consent screen**  
   - User type：External（測試用）  
   - 填 App 名稱、支援 email  
   - **Test users**：加入你要測的 Gmail  
3. **Credentials** → **Create Credentials** → **OAuth client ID**

建立 **兩個** Client：

| 類型 | 用途 | 設定 |
|------|------|------|
| **iOS** | App 跳出 Google 登入 | Bundle ID：`com.example.geoGuesser` |
| **Web application** | 後端驗證 idToken、Flutter `serverClientId` | 不用填 redirect 也可（僅驗 token） |

記下：

- **Web Client ID** → `xxxx.apps.googleusercontent.com`  
- **iOS Client ID** → `yyyy.apps.googleusercontent.com`  
- iOS 詳情裡的 **iOS URL scheme**（Reversed client ID）→ 例如 `com.googleusercontent.apps.1234567890-abcdef`

## 2. 專案根目錄 `.env`

```env
GOOGLE_WEB_CLIENT_ID=你的Web_Client_ID.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=你的iOS_Client_ID.apps.googleusercontent.com
```

後端 `server` 讀 `GOOGLE_WEB_CLIENT_ID` 驗證 token。

## 3. iOS：`ios/Flutter/Secrets.xcconfig`

複製 `Secrets.xcconfig.example` 為 `Secrets.xcconfig`，加入：

```
GOOGLE_IOS_REVERSED_CLIENT_ID=com.googleusercontent.apps.xxxxx
```

（填 Console 上 iOS OAuth 的 URL scheme）

## 4. 啟動

```bash
# 後端
cd server && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 3000

# Flutter（完整重啟，不要只 hot reload）
flutter pub get
flutter run
```

## 5. 流程

App 按「使用 Google 登入」→ Google 帳號選擇 → 取得 `idToken` →  
`POST /auth/google` → MongoDB `users` 寫入/更新 → 回 JWT → 與 Email 登入相同。

## 常見錯誤

| 狀況 | 處理 |
|------|------|
| 無法取得 idToken | 確認 `.env` 有 `GOOGLE_WEB_CLIENT_ID`（Web 那組） |
| 後端 Google 登入驗證失敗 | Web Client ID 要與 Flutter `serverClientId` 一致 |
| iOS 閃退 / 無法回 App | 檢查 `GOOGLE_IOS_REVERSED_CLIENT_ID` 與 Info.plist URL scheme |
| 測試帳號無法登入 | OAuth 同意畫面要把 Gmail 加進 Test users |
