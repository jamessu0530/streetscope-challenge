# Facebook 登入設定（iOS + FastAPI + MongoDB）

本專案使用 `flutter_facebook_auth` 7.x + FastAPI 後端。iOS 在開發階段**多半走 Limited Login（JWT）**，不是舊教學裡的 classic Graph API access token。

---

## 成功登入靠什麼（必備清單）

### Meta 開發者後台

| 項目 | 必填 | 說明 |
|------|------|------|
| 應用程式編號 App ID | ✅ | 例：`2441016729700783` → `.env` + `Secrets.xcconfig` |
| 用戶端權杖 Client Token | ✅ | Meta **設定 → 基本/進階** → 與 `FACEBOOK_CLIENT_TOKEN` 完全一致 |
| iOS 平台 + Bundle ID | ✅ | `com.example.geoGuesser`，須與 Xcode **完全一致** |
| iPhone Store 編號 | ✅* | 新版後台常必填；可從 App Store Connect 建草稿 App 拿 Apple ID 數字（不必上架） |
| 測試人員 | ✅ | App **開發中** 時，你的 FB 帳號必須在 **應用程式角色 → 測試人員** |
| 隱私政策 HTTPS | ✅ | 例：`https://geoguesser.jamessu2016.com/privacy.html` |
| 資料刪除指示 HTTPS | ✅ | 例：`https://geoguesser.jamessu2016.com/delete-data.html` |
| Facebook 登入 → 用戶端 OAuth | ✅ | 開啟 |
| Facebook 登入 → 嵌入的瀏覽器 OAuth | ✅ | **是**（內嵌瀏覽器登入需要） |
| OAuth 重新導向 URI（`fb://`） | ❌ 不要填 | 那欄只收 `https://`，給**網站**用；iOS 靠 Bundle ID + URL Scheme |

### iOS / Flutter 專案

| 項目 | 位置 |
|------|------|
| `FACEBOOK_APP_ID` | `ios/Flutter/Secrets.xcconfig` |
| `FACEBOOK_CLIENT_TOKEN` | `ios/Flutter/Secrets.xcconfig` |
| `FACEBOOK_DISPLAY_NAME` | `ios/Flutter/Secrets.xcconfig` |
| URL Scheme `fb{APP_ID}` | `ios/Runner/Info.plist`（`fb$(FACEBOOK_APP_ID)`） |
| `FacebookAppID` / `FacebookClientToken` | `ios/Runner/Info.plist` |
| `flutter_facebook_auth` | `pubspec.yaml` |
| 登入權限 | 先只用 `public_profile`（**不要**先要 `email`） |
| Bundle Identifier | Xcode / `project.pbxproj` → `com.example.geoGuesser` |

### 後端（FastAPI）

| 項目 | 說明 |
|------|------|
| `FACEBOOK_APP_ID` | 根目錄 `.env`，Limited Login JWT 驗 `aud` 用 |
| `POST /auth/facebook` | 支援 **Limited**（JWT）與 **Classic**（Graph API token）兩種 |
| `PyJWT` | `pip install -r requirements.txt`（含 `PyJWT[crypto]`） |
| `FACEBOOK_LIMITED_LOGIN_RELAXED` | 課堂預設 `true`；簽章驗證失敗時改檢查 aud/exp/sub |
| 靜態頁 | `public/privacy.html`、`public/delete-data.html` 由同一 port 提供 |
| 啟動目錄 | 必須在 **`server/`** 跑 `uvicorn app.main:app` |

### 執行環境

```bash
# 終端 1 — 後端（一定要在 server/ 目錄）
cd server && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 3000

# 終端 2 — 對外 HTTPS（Meta 隱私網址用，例：Cloudflare Tunnel）
cloudflared tunnel --url http://localhost:3000
# 或固定網域：geoguesser.jamessu2016.com

# 終端 3 — Flutter
flutter pub get
cd ios && pod install && cd ..
flutter run
```

真機測試時 `.env` 的 `API_BASE_URL` 不能是 `localhost`，要改成 Mac 區網 IP 或 tunnel 網域。

---

## 登入流程（實際跑的是這條）

```text
App 按 Facebook 登入
  → Meta 授權（Limited 或 Classic）
  → Flutter 拿到 token
  → POST /auth/facebook
  → 後端驗證 + 寫入 MongoDB users
  → 回 JWT
```

### iOS 常見：Limited Login（JWT）

`flutter_facebook_auth` 7.x 在 iOS 上，若未允許追蹤或 SDK 判定為 limited，回傳的是 **`LimitedToken`（JWT）**，不是 Graph API 的 access token。

- **錯誤做法**：把 JWT 當 `accessToken` 丟 Graph API → `bad signature` / 401
- **正確做法**：App 送 `authenticationToken` + `userId` + `userName` + `nonce`；後端用 Meta JWKS（`https://limited.facebook.com/.well-known/oauth/openid/jwks/`）驗證

參考：[Meta Limited Login — Validating the Token](https://developers.facebook.com/documentation/facebook-login/ios/limited-login/token/validating)

### Classic Login（較少見於 iOS 開發機）

若拿到的是 `ClassicToken`，後端用 Graph API `GET /me?access_token=...` 驗證。

---

## 1. Meta 後台逐步設定

1. [developers.facebook.com](https://developers.facebook.com/) 建立 App（**其他** / **消費者**）
2. 加入產品 **Facebook 登入**
3. **設定 → 基本**
   - 複製 **應用程式編號**、**用戶端權杖**
   - 填 **隱私政策**、**資料刪除指示**（公開 HTTPS）
4. **設定 → 基本 → 新增平台 → iOS**
   - **套件組合編號**：`com.example.geoGuesser`
   - **Store 編號**：App Store Connect 的 Apple ID（草稿即可）
5. **Facebook 登入 → 設定**
   - 用戶端 OAuth：**開**
   - 嵌入的瀏覽器 OAuth：**是**
   - OAuth 重新導向 URI：**留空**（除非做網站登入）
6. **應用程式角色 → 測試人員**：加入你的 Facebook 帳號

---

## 2. 專案設定檔

**`ios/Flutter/Secrets.xcconfig`**

```
FACEBOOK_APP_ID=你的應用程式編號
FACEBOOK_CLIENT_TOKEN=你的用戶端權杖
FACEBOOK_DISPLAY_NAME=Geo Guesser
```

**`.env`（根目錄）**

```env
FACEBOOK_APP_ID=你的應用程式編號
API_BASE_URL=http://localhost:3000
# 課堂用；正式環境 Limited Login 請設 false 並確保 JWT 簽章驗證通過
FACEBOOK_LIMITED_LOGIN_RELAXED=true
```

**`Info.plist` 已有（勿刪）**

- `CFBundleURLSchemes` → `fb$(FACEBOOK_APP_ID)`
- `FacebookAppID`、`FacebookClientToken`
- `LSApplicationQueriesSchemes` → `fbapi`、`fbauth2` 等

---

## 3. Cloudflare Tunnel（隱私 / 刪除資料網址）

頁面在 `public/`，與 API 同 port：

- `/privacy.html`
- `/delete-data.html`

1. 啟動 uvicorn（port 3000）
2. `cloudflared tunnel --url http://localhost:3000` 或綁定 `geoguesser.jamessu2016.com`
3. 瀏覽器確認兩個 HTTPS 頁面能開
4. 網址貼進 Meta **設定 → 基本**

---

## 4. 我們踩過的坑（對照表）

| 現象 | 原因 | 解法 |
|------|------|------|
| 應用程式設定不接受這個網址 | iOS 平台 / Bundle ID / 測試人員 | 設 iOS 平台 + 加測試人員；勿在 redirect 填 `fb://` |
| OAuth redirect 只收 https | 正常，那欄給網頁用 | iOS 改填 Bundle ID |
| Store 編號填 `0` 被拒 | 新版 Meta 要真實 Apple ID | App Store Connect 建草稿 App |
| email permission 被擋 | 開發中 App 未開 email 進階權限 | 先只要 `public_profile` |
| `bad signature` | JWT 被當 access token 用 | 後端走 Limited Login + PyJWT |
| `POST /auth/facebook 401` | 後端驗 token 失敗 | `pip install -r requirements.txt`、確認 `FACEBOOK_APP_ID`、重啟 uvicorn |
| `No module named 'app'` | 在錯目錄跑 uvicorn | `cd server` 再跑 |
| 隱私網址打不開 | DNS / tunnel 未指到本機 | Cloudflare Tunnel + DNS CNAME |

---

## 5. 之後若要 email

1. Meta **應用程式審查 → 權限和功能**：`email` 改 **進階存取**
2. Flutter 改回 `permissions: ['email', 'public_profile']`
3. 後端 Graph / JWT 欄位可再取 email

---

## 6. 安全提醒

- `Secrets.xcconfig`、`.env` 勿 commit
- 課堂可開 `FACEBOOK_LIMITED_LOGIN_RELAXED=true`；**正式上線應設 `false`** 並確保完整 JWT 簽章驗證
- Client Token、MongoDB 密碼若曾外洩，正式環境請輪替
