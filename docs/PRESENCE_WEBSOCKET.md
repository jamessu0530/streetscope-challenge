# WebSocket 線上大廳（在線玩家 + 聊天）

## 架構

- 端點：`WS /ws?token=<JWT>`
- 連上即視為**在線**；斷線（關 App、登出、網路斷）即**離線**
- 伺服器記憶體內維護連線表，並廣播 `presence` 給所有客戶端
- 聊天訊息 `chat` 廣播給大廳內所有人（之後可擴充私聊、房間）

## 後端

```bash
cd server && source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 3000
```

## Flutter

- `.env` 的 `API_BASE_URL` 會自動轉成 `ws://` 或 `wss://`
- 登入後自動 `RealtimeService.connect()`
- 首頁「線上大廳」進入 `LobbyPage`

## 真機 + 模擬器測試

1. 兩邊都登入**不同帳號**
2. `API_BASE_URL`：真機用 Mac 區網 IP；模擬器可用 `http://127.0.0.1:3000`（會變 `ws://127.0.0.1:3000/ws`）
3. 兩邊都開大廳 → 玩家列表應看到對方；聊天可互傳

## 訊息格式（JSON）

| type | 方向 | 說明 |
|------|------|------|
| `presence` | Server → Client | `{ players: [{ id, displayName }] }` |
| `chat` | 雙向 | Client 送 `{ text }`；Server 廣播 `{ from, text, at }` |
| `ping` / `pong` | Client ↔ Server | 保持連線 |

## 真人對戰（第一階段）

1. 首頁設定回合／時間／區域 → **線上大廳**
2. 點另一位在線玩家 → **發起挑戰**
3. 對方 **接受** → 房主產生題目 → 雙方進入 `GamePage`（可選 Picture / No Move / Move；可勾 **娛樂模式**）
4. 每回合送出後 WebSocket 同步分數；全部回合結束顯示勝負
5. 對手斷線 → 保留房間、等待重連（`duel_opponent_disconnected`）；重連後 `duel_state_sync` 恢復進度
6. 在線方可按 **退出對戰**（`duel_leave`）；對手收到 `duel_cancelled`
7. 對戰結束後結果頁可 **再戰一次**（沿用邀請流程）

### 娛樂模式（好友對戰）

- 發起挑戰時可勾選；**不寫入排行榜**（仍會記遊玩紀錄）。
- 每回合至少 **60 秒**；可使用一次 **AI 道具** → 地圖上顯示橘色 AI 建議點與理由（與 AI 對戰同色，自行決定是否參考）。
- 使用 AI 道具後該回合送出 **分數折半**；對戰仍計分，但 **不寫入排行榜**。

登入後 WebSocket 會保持連線，**首頁也能收到對戰邀請**（不必先進大廳）。

WS 訊息：`duel_invite`、`duel_invite_reply`、`duel_places`、`duel_start`、`duel_round_submit`、`duel_round_complete`、`duel_advance_round`（Client→Server）、`duel_sync_next_round`（Server→對手，同步下一回合）

## 限制（課堂版）

- 重啟後端會清空在線列表與對戰房（記憶體 hub）
- 單機 uvicorn 適合開發；正式環境多實例需 Redis 等共享 presence
