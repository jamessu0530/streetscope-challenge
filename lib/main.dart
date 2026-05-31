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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/game_page.dart';
import 'screens/home_page.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/leaderboard_service.dart';
import 'services/meme_collection_service.dart';
import 'models/duel_messages.dart';
import 'services/realtime_service.dart';
import 'widgets/duel_invite_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  await AuthService.instance.init();
  await LeaderboardService.instance.purgeLocalStorage();
  await MemeCollectionService.instance.purgeLocalStorage();
  runApp(const GeoGuesserApp());
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class GeoGuesserApp extends StatefulWidget {
  const GeoGuesserApp({super.key});

  @override
  State<GeoGuesserApp> createState() => _GeoGuesserAppState();
}

class _GeoGuesserAppState extends State<GeoGuesserApp> {
  @override
  void initState() {
    super.initState();
    RealtimeService.instance.pendingDuelStart.addListener(_onPendingDuelStart);
    RealtimeService.instance.incomingDuelInvite.addListener(_onIncomingInvite);
  }

  @override
  void dispose() {
    RealtimeService.instance.pendingDuelStart.removeListener(_onPendingDuelStart);
    RealtimeService.instance.incomingDuelInvite.removeListener(_onIncomingInvite);
    super.dispose();
  }

  void _onIncomingInvite() {
    final DuelInviteIncoming? invite =
        RealtimeService.instance.incomingDuelInvite.value;
    if (invite == null) return;

    final BuildContext? ctx = appNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    unawaited(showDuelInviteDialog(ctx, invite));
  }

  void _onPendingDuelStart() {
    final DuelStartEvent? event = RealtimeService.instance.pendingDuelStart.value;
    if (event == null) return;
    RealtimeService.instance.pendingDuelStart.value = null;

    AudioService.instance.stopHomeBgm();
    appNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => GamePage(settings: event.settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
