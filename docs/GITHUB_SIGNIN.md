# GitHub 登入

## 1. 建立 GitHub OAuth App

1. 開啟 [GitHub Developer Settings → OAuth Apps](https://github.com/settings/developers)
2. **New OAuth App**
3. 填寫：
   - **Application name**：例如 `Geo Guesser`
   - **Homepage URL**：`http://localhost:3000`（課堂用可填本機）
   - **Authorization callback URL**（必須完全一致）：
     ```
     com.example.geoGuesser://github-callback
     ```
4. 建立後記下 **Client ID**，並產生 **Client Secret**

## 2. 設定 `.env`（專案根目錄）

```env
GITHUB_CLIENT_ID=你的_Client_ID
GITHUB_CLIENT_SECRET=你的_Client_Secret
GITHUB_OAUTH_REDIRECT_URI=com.example.geoGuesser://github-callback
API_BASE_URL=http://127.0.0.1:3000
```

- **Client Secret 只放後端**，不要提交到 Git。
- Flutter 只需讀 `GITHUB_CLIENT_ID` 與 `GITHUB_OAUTH_REDIRECT_URI`（與 callback URL 相同）。

## 3. 啟動後端

```bash
cd server
uvicorn app.main:app --reload --host 0.0.0.0 --port 3000
```

## 4. 跑 App 測試

```bash
flutter run
```

登入頁 → **使用 GitHub 登入** → 瀏覽器授權 → 自動回到 App。

真機請把 `API_BASE_URL` 改成 Mac 區網 IP。

## 流程說明

1. App 開 GitHub 授權頁（`flutter_web_auth_2`）
2. 使用者同意後導回 `com.example.geoGuesser://github-callback?code=...`
3. App 把 `code` 送到 `POST /auth/github`
4. 後端用 **Client Secret** 向 GitHub 換 token，再查使用者資料，寫入 MongoDB

## 常見錯誤

| 現象 | 處理 |
|------|------|
| `redirect_uri` 不符 | GitHub OAuth App 的 callback 與 `.env` 的 `GITHUB_OAUTH_REDIRECT_URI` 一字不差 |
| 授權後 App 沒回來 | 確認 `ios/Runner/Info.plist` 有 URL Scheme `com.example.geoGuesser` |
| `GITHUB_CLIENT_ID` 未設定 | 根目錄 `.env` 補上後重新 `flutter run` |
| 後端 401 | 檢查 `GITHUB_CLIENT_SECRET`、code 是否過期（重新登入） |
