// =============================================================================
// LobbyPage — WebSocket 線上大廳：在線玩家 + 邀請對戰 + 聊天
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/game_constants.dart';
import '../models/auth_user.dart';
import '../models/game_mode.dart';
import '../models/game_settings.dart';
import '../models/online_player.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../widgets/floating_home_nav_bar.dart';
import '../widgets/matchday_ui.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key, required this.lobbySettings});

  /// 首頁設定的回合／時間／區域；發起挑戰時可再選模式。
  final GameSettings lobbySettings;

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (RealtimeService.instance.canUseRealtime) {
      unawaited(RealtimeService.instance.connect());
    }
    RealtimeService.instance.chatMessages.addListener(_scrollChatToEnd);
  }

  @override
  void dispose() {
    RealtimeService.instance.chatMessages.removeListener(_scrollChatToEnd);
    _chatController.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScroll.hasClients) return;
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendChat() {
    AudioService.instance.playClick();
    final String text = _chatController.text;
    if (text.trim().isEmpty) return;
    RealtimeService.instance.sendChat(text);
    _chatController.clear();
  }

  GameSettings _duelSettingsForMode(GameMode mode, {required bool entertainment}) {
    int seconds = widget.lobbySettings.secondsPerRound;
    if (entertainment && seconds < kMinSecondsPerRoundEntertainment) {
      seconds = kMinSecondsPerRoundEntertainment;
    }
    return widget.lobbySettings.copyWith(
      mode: mode,
      vsAi: false,
      vsPlayer: true,
      entertainmentMode: entertainment,
      secondsPerRound: seconds,
      maxMoveSteps: mode == GameMode.move ? widget.lobbySettings.maxMoveSteps : 0,
    );
  }

  Future<void> _challengePlayer(OnlinePlayer target) async {
    AudioService.instance.playClick();
    GameMode selectedMode = GameMode.picture;
    bool entertainmentMode = false;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final GameSettings preview = _duelSettingsForMode(
              selectedMode,
              entertainment: entertainmentMode,
            );
            final String moveHint = selectedMode == GameMode.move &&
                    preview.maxMoveSteps > 0
                ? '\n最多 ${preview.maxMoveSteps} 步'
                : '';

            return AlertDialog(
              title: const Text('發起挑戰'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('向 ${target.displayName} 發送對戰邀請？'),
                    const SizedBox(height: 12),
                    const Text(
                      '遊戲模式',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final GameMode mode in GameMode.values)
                      RadioListTile<GameMode>(
                        value: mode,
                        groupValue: selectedMode,
                        onChanged: (GameMode? value) {
                          if (value == null) return;
                          setDialogState(() => selectedMode = value);
                        },
                        title: Text(mode.label),
                        subtitle: Text(
                          mode.description,
                          style: const TextStyle(fontSize: 11),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '娛樂模式',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        '每回合 AI 建議（使用後該回合分數折半）\n'
                        '至少 ${kMinSecondsPerRoundEntertainment} 秒 · 不計排行榜',
                        style: TextStyle(fontSize: 11, height: 1.35),
                      ),
                      value: entertainmentMode,
                      onChanged: (bool value) {
                        setDialogState(() => entertainmentMode = value);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${preview.roundsPerGame} 回合 · '
                      '${preview.secondsPerRound} 秒$moveHint',
                      style: TextStyle(
                        fontSize: 12,
                        color: MatchdayPalette.ink.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('邀請'),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    RealtimeService.instance.sendDuelInvite(
      toUserId: target.id,
      settings: _duelSettingsForMode(
        selectedMode,
        entertainment: entertainmentMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthUser? me = AuthService.instance.currentUser.value;
    final bool loggedIn = me != null;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bool keyboardVisible = keyboardInset > 0;
    final double bottomSafe = MediaQuery.paddingOf(context).bottom;
    final double chatBottomPadding = keyboardVisible ? 8 : 120 + bottomSafe;

    return Scaffold(
      backgroundColor: MatchdayPalette.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const MatchdayTopTicker(
                  label: 'LIVE · LOBBY',
                  trailing: 'DUEL · WS',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          AudioService.instance.playClick();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back),
                        color: MatchdayPalette.ink,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          '線上大廳',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<RealtimeConnectionState>(
                        valueListenable:
                            RealtimeService.instance.connectionState,
                        builder: (
                          BuildContext context,
                          RealtimeConnectionState s,
                          _,
                        ) {
                          final String label;
                          final Color dot;
                          switch (s) {
                            case RealtimeConnectionState.connected:
                              label = '已連線';
                              dot = Colors.green;
                            case RealtimeConnectionState.connecting:
                              label = '連線中';
                              dot = Colors.orange;
                            case RealtimeConnectionState.disconnected:
                              label = '離線';
                              dot = Colors.red;
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: dot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<String?>(
                  valueListenable: RealtimeService.instance.duelStatusMessage,
                  builder: (BuildContext context, String? msg, _) {
                    if (msg == null || msg.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        msg,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MatchdayPalette.ink.withValues(alpha: 0.7),
                        ),
                      ),
                    );
                  },
                ),
                if (!loggedIn)
                  const Expanded(
                    child: Center(
                      child: Text('請先登入'),
                    ),
                  )
                else ...<Widget>[
                  if (!keyboardVisible) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '點擊玩家卡片發起挑戰',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: MatchdayPalette.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 150,
                      child: ValueListenableBuilder<List<OnlinePlayer>>(
                        valueListenable:
                            RealtimeService.instance.onlinePlayers,
                        builder: (
                          BuildContext context,
                          List<OnlinePlayer> players,
                          _,
                        ) {
                          final List<OnlinePlayer> others = players
                              .where((OnlinePlayer p) => p.id != me.id)
                              .toList();
                          if (others.isEmpty) {
                            return const Center(
                              child: Text('目前沒有其他玩家在線'),
                            );
                          }
                          return ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: others.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (BuildContext context, int index) {
                              final OnlinePlayer p = others[index];
                              return Material(
                                color: MatchdayPalette.cream,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _challengePlayer(p),
                                  child: Container(
                                    width: 130,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: MatchdayPalette.ink,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        const Icon(
                                          Icons.sports_esports,
                                          size: 18,
                                          color: MatchdayPalette.ink,
                                        ),
                                        const Spacer(),
                                        Text(
                                          p.displayName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const Text(
                                          '點擊挑戰',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '大廳聊天',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: MatchdayPalette.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ValueListenableBuilder<List<LobbyChatMessage>>(
                      valueListenable: RealtimeService.instance.chatMessages,
                      builder: (
                        BuildContext context,
                        List<LobbyChatMessage> messages,
                        _,
                      ) {
                        if (messages.isEmpty) {
                          return const Center(
                            child: Text('還沒有訊息'),
                          );
                        }
                        return ListView.builder(
                          controller: _chatScroll,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: messages.length,
                          itemBuilder: (BuildContext context, int index) {
                            final LobbyChatMessage m = messages[index];
                            final bool isMe = m.fromId == me.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${isMe ? '你' : m.fromDisplayName}: ${m.text}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      chatBottomPadding,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            onSubmitted: (_) => _sendChat(),
                            textInputAction: TextInputAction.send,
                            decoration: const InputDecoration(
                              hintText: '輸入訊息…',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _sendChat,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!keyboardVisible)
            const FloatingHomeNavBar(current: HomeTab.home),
        ],
      ),
    );
  }
}
