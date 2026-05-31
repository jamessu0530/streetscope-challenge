# 遊玩紀錄（MongoDB）

每一局結束都會新增一筆（與排行榜「只留最佳」不同）。

## Collection：`play_history_entries`

| 欄位 | 說明 |
|------|------|
| `userId` | 玩家 |
| `totalScore` | 該局總分 |
| `rounds` / `secondsPerRound` / `mode` / `region` | 局設定 |
| `playType` | `solo` 單人 · `ai` AI 對戰 · `friend` 好友對戰 |
| `opponentDisplayName` / `opponentScore` | 對手（AI 或好友） |
| `opponentUserId` | 好友對戰時的對方帳號 id |
| `won` | 好友對戰：贏 `true`、輸 `false`、平手 `null` |
| `aiStrength` | AI 對戰：`weak` / `medium` / `strong` |
| `playedAt` | 結算時間 |

## API

| 方法 | 路徑 | 說明 |
|------|------|------|
| POST | `/play-history` | 寫入一局（需 JWT） |
| GET | `/play-history?limit=50&skip=0` | 自己的紀錄，新到舊 |

## App

- 單人 / AI：`ResultPage` 結算時寫入
- 好友對戰：`DuelResultPage` 結算時寫入
- 首頁右上角頭像選單 → **遊玩紀錄**
