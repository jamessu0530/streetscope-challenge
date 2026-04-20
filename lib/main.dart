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
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/theme_service.dart';
import 'screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  await ThemeService.instance.load();
  runApp(const GeoGuesserApp());
}

class GeoGuesserApp extends StatelessWidget {
  const GeoGuesserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.mode,
      builder: (BuildContext context, ThemeMode mode, _) {
        return MaterialApp(
          title: 'GeoGuesser 地理猜謎',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0C0F14),
          ),
          builder: (BuildContext context, Widget? child) {
            if (child == null) return const SizedBox.shrink();
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            if (!isDark) return child;
            return Stack(
              children: <Widget>[
                child,
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                ),
              ],
            );
          },
          home: const HomePage(),
        );
      },
    );
  }
}
