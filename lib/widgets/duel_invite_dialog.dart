import 'package:flutter/material.dart';

import '../models/duel_messages.dart';
import '../models/game_mode.dart';
import '../services/realtime_service.dart';

/// 全域對戰邀請對話框（首頁、大廳、遊戲中皆可彈出）。
Future<void> showDuelInviteDialog(
  BuildContext context,
  DuelInviteIncoming invite,
) async {
  final GameMode mode = invite.settings.mode;
  final String moveHint = mode == GameMode.move &&
          invite.settings.maxMoveSteps > 0
      ? '\n最多 ${invite.settings.maxMoveSteps} 步'
      : '';

  final String title = invite.isRematch ? '再戰邀請' : '對戰邀請';
  final String body = invite.isRematch
      ? '${invite.from.displayName} 要求再戰一次'
      : '${invite.from.displayName} 邀請你對戰';
  final String funLine = invite.settings.entertainmentMode
      ? '\n娛樂模式 · AI 建議（使用折半）· 不計排行榜'
      : '';

  final bool? accept = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(
          '$body\n'
          '模式：${mode.label} · ${invite.settings.roundsPerGame} 回合 · '
          '${invite.settings.secondsPerRound} 秒$moveHint$funLine',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('拒絕'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('接受'),
          ),
        ],
      );
    },
  );

  RealtimeService.instance.incomingDuelInvite.value = null;
  if (accept == true) {
    RealtimeService.instance.replyDuelInvite(
      inviteId: invite.inviteId,
      accept: true,
    );
  } else if (accept == false) {
    RealtimeService.instance.replyDuelInvite(
      inviteId: invite.inviteId,
      accept: false,
    );
  }
}
