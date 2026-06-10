import 'package:flutter/material.dart';

import '../app_navigator.dart';
import '../models/auth_user.dart';
import '../screens/nickname_page.dart';
import '../services/auth_service.dart';

/// 關閉目前頁與疊加路由，回到 [HomePage]（MaterialApp home）。
void returnToAppHome(BuildContext context, {String? snackMessage}) {
  if (!context.mounted) return;
  Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);

  if (snackMessage == null || snackMessage.isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final BuildContext? root = appNavigatorKey.currentContext;
    if (root == null || !root.mounted) return;
    ScaffoldMessenger.of(root).showSnackBar(
      SnackBar(
        content: Text(snackMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  });
}

/// 登入成功：關閉登入頁與其上疊加的路由，回到 [HomePage]（MaterialApp home）。
Future<void> completeLoginAndReturnHome(
  BuildContext loginContext, {
  String? welcomeMessage,
}) async {
  if (!loginContext.mounted) return;

  ScaffoldMessenger.of(loginContext).clearSnackBars();
  Navigator.of(loginContext).popUntil((Route<dynamic> route) => route.isFirst);

  final BuildContext? root = appNavigatorKey.currentContext;
  if (root == null || !root.mounted) return;
  ScaffoldMessenger.of(root).clearSnackBars();

  final AuthUser? user = AuthService.instance.currentUser.value;
  if (user == null) return;

  if (user.needsNicknameSetup) {
    final bool ready = await ensureNicknameSetup(root);
    if (!ready) {
      await AuthService.instance.signOut();
      if (root.mounted) {
        ScaffoldMessenger.of(root).showSnackBar(
          const SnackBar(content: Text('請完成遊戲暱稱設定後再登入')),
        );
      }
      return;
    }
  }

  if (welcomeMessage != null && welcomeMessage.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      returnToAppHome(root, snackMessage: welcomeMessage);
    });
  }
}
