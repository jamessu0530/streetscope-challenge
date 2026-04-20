// =============================================================================
// GeoGuesser — App entry
// =============================================================================
//
// 這個檔案故意保持非常薄：只負責啟動 App 與設定主題。
// 所有實際邏輯都拆到：
//   - config/   API key 管理
//   - models/   資料模型
//   - data/     世界地點題庫
//   - services/ Google API 呼叫
//   - widgets/  可重用 UI 元件
//   - screens/  各個頁面
//   - utils/    純函式工具
//
// 設定 API Key：
//   1. cp lib/config/config.example.dart lib/config/config.dart
//   2. 填入你的 key
//   3. ios/Runner/AppDelegate.swift 內 GMSServices.provideAPIKey(...) 也要改
// =============================================================================

import 'package:flutter/material.dart';

import 'screens/home_page.dart';

void main() {
  runApp(const GeoGuesserApp());
}

class GeoGuesserApp extends StatelessWidget {
  const GeoGuesserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoGuesser 地理猜謎',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
