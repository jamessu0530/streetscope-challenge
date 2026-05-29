# 雲端迷因庫（MongoDB）

## 資料存在哪？

與登入帳號同一個 MongoDB 資料庫（`.env` 的 `MONGODB_URI`）。

| Collection | 用途 |
|------------|------|
| `user_memes` | 每位使用者自己的迷因，依**國家**分類 |

### `user_memes` 欄位

| 欄位 | 說明 |
|------|------|
| `userId` | 對應 `users._id`（必填） |
| `country` | 該局正確答案所在國家（反查地名，例如 `Japan`、`Taiwan`；無則 `Unknown`） |
| `title` / `imageUrl` / `postUrl` / `subreddit` / `ups` | Reddit meme 內容 |
| `score` | 觸發時本回合分數（0 分懲罰） |
| `collectedAt` | 蒐集時間 |

同一使用者、同一 `imageUrl` 只會存一筆（不重複）。

## API（皆需 JWT 登入）

| 方法 | 路徑 | 說明 |
|------|------|------|
| POST | `/memes` | 新增一張迷因 |
| GET | `/memes` | 讀取我的全部迷因（App 再依 `country` 分組） |
| GET | `/memes?country=Japan` | 可選：只讀某國 |
| DELETE | `/memes` | 清空**我**的迷因庫 |

## App 行為

- **未登入**：迷因庫頁提示登入；遊戲中 0 分懲罰仍會顯示 meme，但**不會存入**雲端。
- **已登入**：依國家顯示你的收集冊；每個帳號資料互相獨立。

## 在 MongoDB Atlas 查看

1. **Browse Collections** → 你的資料庫（例如 `loginstorage`）
2. 開 **`user_memes`**
3. 用 `userId` 篩選某位玩家；用 `country` 篩選國家

## 清空資料

- **本機舊資料**：App 啟動會刪除 `meme_collection_v1`（SharedPreferences）
- **雲端**：`.env` 設 `MEME_CLEAR_ON_START=true` 後重啟後端，或於 Atlas 刪除 `user_memes` collection
