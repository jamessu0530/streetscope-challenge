# 雲端排行榜（MongoDB）

## 資料存在哪？

與登入帳號同一個 MongoDB 資料庫（`.env` 的 `MONGODB_URI` 裡的 database 名稱，例如 `loginstorage`）。

| Collection | 用途 |
|------------|------|
| `users` | 登入帳號（已有） |
| `leaderboard_entries` | **新** — 每一局成績 |

### `leaderboard_entries` 欄位

| 欄位 | 說明 |
|------|------|
| `userId` | 對應 `users._id`（ObjectId），**必填** |
| `displayName` | 當下帳號顯示名稱（快照，不讓玩家自填假名） |
| `totalScore` | 總分 |
| `rounds` | 回合數 |
| `secondsPerRound` | 每回合秒數 |
| `mode` | `move` / `noMove` / `picture` |
| `region` | `world` / `asia` 等 |
| `playedAt` | 遊戲結束時間 |

## API

| 方法 | 路徑 | 說明 |
|------|------|------|
| POST | `/leaderboard` | 提交一局（**需 JWT 登入**） |
| GET | `/leaderboard?sort=top\|recent&limit=50` | 讀排行榜（**需登入**） |

## 本機舊資料

- App 啟動會刪除 SharedPreferences 裡的舊本機排行榜（v1～v3）。
- 雲端 `leaderboard_entries` 已透過 `LEADERBOARD_CLEAR_ON_START` 清空過一次。

## 在 MongoDB Atlas 手動查看 / 清空

1. 登入 [MongoDB Atlas](https://cloud.mongodb.com/)
2. **Database** → 你的 Cluster → **Browse Collections**
3. 選資料庫（與 `MONGODB_URI` 相同，例如 `loginstorage`）
4. 開 **`leaderboard_entries`** 即可看到每筆紀錄的 `userId`
5. 若要全部刪除：該 collection → **Delete Collection** 或 Filter `{}` → Delete

## `.env`（後端）

```env
# 僅開發用：下次啟動後端時清空 leaderboard_entries
LEADERBOARD_CLEAR_ON_START=false
```

設為 `true` 並重啟 `uvicorn` 會執行 `delete_many({})`，用完請改回 `false`。

## App 行為

- **未登入**：結算頁不寫入排行榜；排行榜頁提示登入。
- **已登入**：單人／AI 結算頁、**雙人對戰結算頁**結束後自動 POST，名字來自帳號 `displayName`，不能自填。
- **雙人對戰**：每位玩家各自提交**自己的總分**（`mode`／`region` 與該場對戰設定相同），與單人局共用同一排行榜。
