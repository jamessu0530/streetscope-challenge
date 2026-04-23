# StreetScope Challenge

簡化版說明：只保留「怎麼執行」和「檔案架構」。

## 如何執行

1. 安裝 Flutter SDK（[官方安裝文件](https://docs.flutter.dev/get-started/install)）
2. 在專案根目錄執行：

```bash
flutter pub get
flutter run
```

### API Key（必要）

- 建立 `.env`：

```bash
cp .env.example .env
```

- 在 `.env` 填入：

```env
GOOGLE_API_KEY=YOUR_REAL_KEY
```

- iOS 另外需要：

```bash
cp ios/Flutter/Secrets.xcconfig.example ios/Flutter/Secrets.xcconfig
```

並在 `ios/Flutter/Secrets.xcconfig` 填入：

```txt
GOOGLE_MAPS_API_KEY=YOUR_REAL_KEY
```

## 檔案架構

```text
flutterproject4/
├── lib/
│   ├── main.dart                     # App 入口
│   ├── data/                         # 題目/常數資料
│   ├── models/                       # 資料模型（分數、模式、排行榜等）
│   ├── screens/                      # 頁面（首頁、遊戲、結算、排行榜、迷因收藏）
│   ├── services/                     # 邏輯服務（排行榜、meme、查國家、音效等）
│   ├── widgets/                      # 共用 UI 元件
│   └── utils/                        # 工具函式
├── assets/                           # 圖片與資源
├── ios/Flutter/                      # iOS 設定（含 Secrets.xcconfig）
└── pubspec.yaml                      # 套件與資源宣告
```
