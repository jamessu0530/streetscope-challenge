# GeoGuesser API（FastAPI + MongoDB Atlas）

## 啟動

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 3000
```

連線設定讀專案根目錄的 `.env`（`MONGODB_URI`、`JWT_SECRET`）。

- 文件：http://127.0.0.1:3000/docs
- 健康檢查：`GET /health`

## API

| 方法 | 路徑 | 說明 |
|------|------|------|
| POST | `/auth/register` | 註冊 `{ "email", "password", "displayName" }` |
| POST | `/auth/login` | 登入 `{ "email", "password" }` |
| GET | `/auth/me` | Header: `Authorization: Bearer <token>` |
| POST | `/auth/change-password` | Header: Bearer；Body: `{ "currentPassword", "newPassword" }` |
| POST | `/auth/forgot-password` | Body: `{ "email" }` → 教育版回 `resetToken` |
| POST | `/auth/reset-password` | Body: `{ "email", "resetToken", "newPassword" }` |
| POST | `/auth/google` | Body: `{ "idToken" }` → JWT + MongoDB user |

| POST | `/auth/facebook` | Body: `{ "accessToken" }` → JWT + MongoDB |

Google 登入：`docs/GOOGLE_SIGNIN.md`  
Facebook 登入：`docs/FACEBOOK_SIGNIN.md`

## 在 Atlas 建立 `users` collection

### 方法 A：不用手動建（建議）

後端第一次 **註冊** 或啟動時 `ensure_indexes()` 會自動建立 `users` collection。

1. 先啟動 API（見上方）
2. 打開 http://127.0.0.1:3000/docs
3. 試 `POST /auth/register`
4. 到 Atlas → **Browse Collections** → database `loginstorage` → 會看到 `users`

### 方法 B：在 Atlas 網頁先手動建

1. 登入 [MongoDB Atlas](https://cloud.mongodb.com)
2. 左側 **Database** → **Browse Collections**
3. 若還沒有 database：
   - **Create Database**
   - Database name：`loginstorage`（與 `.env` 裡 URI 路徑一致）
   - Collection name：`users`
4. 若已有 `loginstorage`，點 **Create Collection**，名稱填 `users`
5. 可維持空白，不必先 Insert Document

### 建議 Index（可選，後端啟動也會自動建）

在 `users` → **Indexes** → **Create Index**：

- `{ "email": 1 }`，勾選 **Unique**，Partial filter：`{ "provider": "email" }`

### Network Access

**Security → Network Access** 要包含你電腦 IP，或暫時 `0.0.0.0/0`，否則 `/health` 會連不上。
