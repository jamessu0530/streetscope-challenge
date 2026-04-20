# GeoGuesser – Flutter 地理猜謎遊戲（大學作業範本）

一個 GeoGuessr 風格的小遊戲：看提示 → 在地圖上猜地點 → 根據距離得分。
本專案特別寫給剛學 Flutter 的同學當作業用，**刻意保持簡潔**，不引入複雜套件。

---

## 0. Google API Key（ENV）

專案現在改成從環境讀取：

1. 複製 `.env.example`：
   ```bash
   cp .env.example .env
   ```
2. 編輯 `.env`：
   ```env
   GOOGLE_API_KEY=YOUR_REAL_KEY
   ```
3. 或使用 CI / CLI 注入：
   ```bash
   flutter run --dart-define=GOOGLE_API_KEY=YOUR_REAL_KEY
   ```

> `.env` 已加入 `.gitignore`，不會被上傳；只會上傳 `.env.example`。

### iOS 原生（Google Maps SDK）金鑰設定

iOS 端不能直接讀 Flutter 的 `.env`，請另外設定：

1. 複製範本
   ```bash
   cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
   ```
2. 編輯 `ios/Flutter/Secrets.xcconfig`
   ```txt
   GOOGLE_MAPS_API_KEY=YOUR_REAL_KEY
   ```

`Secrets.xcconfig` 已在 `.gitignore`，不會被上傳。

---

## 一、專案結構

```
flutterproject4/
├── pubspec.yaml
├── assets/
│   └── images/                    ← 放題目圖片（空的也沒關係，會顯示占位圖）
└── lib/
    ├── main.dart                  ← App 入口點、MaterialApp
    ├── data/
    │   └── places_data.dart       ← 5 題的題目資料（寫死）
    ├── models/
    │   ├── place.dart             ← 自訂資料模型 Place
    │   └── guess_result.dart      ← 自訂資料模型 GuessResult（含距離 + 分數計算）
    ├── screens/
    │   ├── home_page.dart         ← 首頁
    │   ├── game_page.dart         ← 遊戲主畫面（父元件，管所有狀態）
    │   └── result_page.dart       ← 結算畫面
    └── widgets/
        ├── countdown_timer_widget.dart  ← 倒數計時（Timer + callback 示範）
        └── map_guess_widget.dart        ← 模擬地圖（callback 上傳狀態示範）
```

> 整個程式不到 700 行，適合作為作業繳交與口頭報告的示範。

---

## 二、三個畫面說明

### 1. `HomePage` （`lib/screens/home_page.dart`）
- App 啟動後第一個看到的畫面。
- 顯示遊戲標題、規則說明、以及「開始遊戲」按鈕。
- 點擊按鈕後使用 `Navigator.push()` 切到 `GamePage`。
- 由於沒有會變動的狀態，使用 **`StatelessWidget`**（首頁不一定要 Stateful）。

### 2. `GamePage` （`lib/screens/game_page.dart`）
- **整份作業最重要的檔案**，扮演父元件角色：
  - 管理「目前第幾回合」、「玩家猜的座標」、「是否已送出」、「每回合結果」等狀態。
  - 接收子元件（計時器 / 地圖）透過 callback 回傳的資料。
  - 5 回合結束後使用 `Navigator.pushReplacement()` 切到 `ResultPage`。
- UI 結構：
  1. `AppBar`：顯示「第 X / 5 回合」與倒數計時元件。
  2. 提示卡片（圖片 + 文字）。
  3. 模擬地圖（玩家點擊選位置）。
  4. 送出按鈕 + 結算小彈窗。

### 3. `ResultPage` （`lib/screens/result_page.dart`）
- 顯示總分、每回合地點 / 距離 / 分數。
- 「回到首頁」按鈕使用 `Navigator.pushAndRemoveUntil()` 清空歷史棧。

---

## 三、資料模型

### `Place`（題目）
```dart
class Place {
  final String name;       // 正確地點名稱
  final String hint;       // 給玩家看的文字提示
  final String imagePath;  // asset 圖片路徑
  final double latitude;   // 正確緯度
  final double longitude;  // 正確經度
}
```

### `GuessResult`（每回合結果）
```dart
class GuessResult {
  final Place correctPlace;
  final double guessedLat;
  final double guessedLng;
  final double distanceKm; // 使用 Haversine 公式計算
  final int score;         // 距離越近分數越高（最高 5000）
}
```
- 額外提供 `GuessResult.fromGuess(...)` 工廠方法，自動計算距離與分數。
- 計分規則：`score = 5000 × (1 − distance / 20000)`，超過 20000 km 算 0 分。

---

## 四、作業需求對照表

| 作業要求 | 檔案 | 關鍵位置 |
|---|---|---|
| **1. StatefulWidget** | `screens/game_page.dart` | `class GamePage extends StatefulWidget` |
|  | `widgets/countdown_timer_widget.dart` | `class CountdownTimerWidget extends StatefulWidget` |
|  | `widgets/map_guess_widget.dart` | `class MapGuessWidget extends StatefulWidget` |
| **2. setState** | `screens/game_page.dart` | `_handleGuessChanged`、`_submitGuess`、`_goToNextRoundOrFinish` 裡 |
|  | `widgets/countdown_timer_widget.dart` | `_startTimer` 每秒呼叫 `setState` 更新剩餘秒數 |
|  | `widgets/map_guess_widget.dart` | `_handleTap` 內用 `setState` 更新 marker 位置 |
| **3. Callback（lifting state up）** | `widgets/countdown_timer_widget.dart` | `onTimeUp`、`onTick` 由父元件傳入 |
|  | `widgets/map_guess_widget.dart` | `onGuessChanged` 由父元件傳入 |
|  | `screens/game_page.dart` | `_handleGuessChanged`、`_handleTimeUp` 接收子元件資料 |
| **4. Timer** | `widgets/countdown_timer_widget.dart` | `Timer.periodic(const Duration(seconds: 1), ...)` |
| **5. 多頁面導航** | `screens/home_page.dart` | `Navigator.push` 到 `GamePage` |
|  | `screens/game_page.dart` | `Navigator.pushReplacement` 到 `ResultPage` |
|  | `screens/result_page.dart` | `Navigator.pushAndRemoveUntil` 回到 `HomePage` |
| **6. 自訂資料模型** | `models/place.dart` | `class Place` |
|  | `models/guess_result.dart` | `class GuessResult`（含 Haversine 距離 + 計分邏輯）|

---

## 五、導航流程

```
HomePage
   │  按「開始遊戲」 → Navigator.push
   ▼
GamePage（5 回合，每回合 20 秒）
   │  第 5 回合送出後 → Navigator.pushReplacement
   ▼
ResultPage（顯示總分 + 各回合細節）
   │  按「回到首頁」 → Navigator.pushAndRemoveUntil
   ▼
HomePage（全新開始）
```

---

## 六、Lifting State Up（子傳父）流程示意

```
 ┌────────────────────────── GamePage (父) ──────────────────────────┐
 │                                                                   │
 │   狀態： _currentRound、_guessedLat、_guessedLng、_results ...    │
 │                                                                   │
 │   ┌── CountdownTimerWidget ──┐     ┌── MapGuessWidget ──────┐     │
 │   │  Timer.periodic 每秒跑   │     │  GestureDetector 偵測  │     │
 │   │  時間歸零 → onTimeUp()   │     │  點擊 → onGuessChanged()│     │
 │   └──────────┬───────────────┘     └────────────┬───────────┘     │
 │              │                                  │                 │
 │   ①  callback 通知父元件時間到        ②  callback 回傳玩家座標    │
 │              │                                  │                 │
 │              ▼                                  ▼                 │
 │     父元件在 _handleTimeUp()       父元件在 _handleGuessChanged()  │
 │     呼叫 setState + 自動送出       呼叫 setState 更新猜測         │
 │                                                                   │
 └───────────────────────────────────────────────────────────────────┘
```

這就是作業要求的 **「callback 函式，子 widget 把資料送回父 widget」**。

---

## 七、如何執行

1. 安裝 Flutter（官方文件：<https://docs.flutter.dev/get-started/install>）。
2. 在專案根目錄執行：
   ```bash
   flutter create .          # 產生各平台資料夾 (android / ios / web ...)
   flutter pub get
   flutter run
   ```
   > `flutter create .` 只需要執行一次，會把目前資料夾補成完整 Flutter 專案，不會覆蓋你已經寫好的 `lib/`、`pubspec.yaml`。
3. 如果想要加入題目圖片：
   - 把圖片（eiffel.jpg、liberty.jpg…）放進 `assets/images/`。
   - 或者直接修改 `lib/data/places_data.dart` 裡的 `imagePath`。
   - **沒有圖片也沒關係**，程式用 `Image.asset` 的 `errorBuilder` 顯示占位圖，不會閃退。

---

## 八、可能的加分延伸（選做）

- 加入隨機出題：每次玩時用 `shuffle()` 打亂 `kGamePlaces`。
- 把計分規則改成指數衰減：`score = 5000 * exp(-distance / 2000)`。
- 使用 `SharedPreferences` 儲存歷史最佳分數。
- 顯示「正確答案的位置」在地圖上，讓玩家直接看到距離。
- 導入真正的地圖套件（如 `flutter_map`）取代模擬地圖。

---

## 九、報告時可以強調的重點

1. **為什麼用 StatefulWidget？**
   因為回合數、倒數秒數、玩家猜測都是會「隨使用者動作變化」的資料，
   必須搭配 `setState()` 通知 Flutter 重建 UI。
2. **為什麼要把 Timer 抽到 `CountdownTimerWidget`？**
   - 封裝：父元件不用知道倒數細節。
   - 重用：未來可以放到其他遊戲模式。
   - **示範 callback (lifting state up)**：子元件負責計時，但把「時間到」這個事件透過 callback 告訴父元件決定怎麼處理。
3. **為什麼地圖要自己模擬？**
   作業規格允許模擬，這樣可避免引入 Google Maps API key 之類的複雜設定，
   也更容易解釋每一行程式在做什麼。
