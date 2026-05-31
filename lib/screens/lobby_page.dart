// =============================================================================
// LobbyPage — WebSocket 線上大廳：在線玩家 + 邀請對戰 + 聊天
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/game_constants.dart';
import '../models/auth_user.dart';
import '../models/game_mode.dart';
import '../models/game_region.dart';
import '../models/game_settings.dart';
import '../models/online_player.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../widgets/floating_home_nav_bar.dart';
import '../widgets/matchday_ui.dart';
import 'login_page.dart';
import 'nickname_page.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  static const Color _entertainmentOrange = Color(0xFFFF7A1A);

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  GameRegion _region = GameRegion.world;
  int _secondsPerRound = kSecondsPerRound;
  int _roundsPerGame = kRoundsPerGame;
  int _maxMoveSteps = 0;
  bool _entertainmentMode = false;

  GameSettings get _lobbySettings => GameSettings(
        region: _region,
        secondsPerRound: _secondsPerRound,
        roundsPerGame: _roundsPerGame,
        maxMoveSteps: _maxMoveSteps,
      );

  @override
  void initState() {
    super.initState();
    if (RealtimeService.instance.canUseRealtime) {
      unawaited(RealtimeService.instance.connect());
    }
    RealtimeService.instance.chatMessages.addListener(_scrollChatToEnd);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ensureNicknameSetup(context);
    });
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
    int seconds = _lobbySettings.secondsPerRound;
    if (entertainment && seconds < kMinSecondsPerRoundEntertainment) {
      seconds = kMinSecondsPerRoundEntertainment;
    }
    return _lobbySettings.copyWith(
      mode: mode,
      vsAi: false,
      vsPlayer: true,
      entertainmentMode: entertainment,
      secondsPerRound: seconds,
      maxMoveSteps: mode == GameMode.move ? _lobbySettings.maxMoveSteps : 0,
    );
  }

  Future<void> _challengePlayer(OnlinePlayer target) async {
    AudioService.instance.playClick();
    GameMode selectedMode = GameMode.picture;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('發起挑戰'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final GameMode mode in GameMode.values)
                    RadioListTile<GameMode>(
                      value: mode,
                      groupValue: selectedMode,
                      onChanged: (GameMode? value) {
                        if (value == null) return;
                        setDialogState(() => selectedMode = value);
                      },
                      title: Text(_challengeModeLabel(mode)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
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
    unawaited(AudioService.instance.playChallengeFanfare());
    RealtimeService.instance.sendDuelInvite(
      toUserId: target.id,
      settings: _duelSettingsForMode(
        selectedMode,
        entertainment: _entertainmentMode,
      ),
    );
  }

  String _challengeModeLabel(GameMode mode) {
    switch (mode) {
      case GameMode.move:
        return 'Move';
      case GameMode.noMove:
        return 'No Move';
      case GameMode.picture:
        return 'Picture';
    }
  }

  void _applyLobbySettings({
    required GameRegion region,
    required int rounds,
    required int seconds,
    required int moves,
  }) {
    setState(() {
      _region = region;
      _roundsPerGame = rounds;
      _secondsPerRound = seconds;
      _maxMoveSteps = moves;
      if (_entertainmentMode &&
          _secondsPerRound < kMinSecondsPerRoundEntertainment) {
        _secondsPerRound = kMinSecondsPerRoundEntertainment;
      }
    });
  }

  Future<void> _editDuelSetup() async {
    AudioService.instance.playClick();
    GameRegion region = _region;
    int rounds = _roundsPerGame;
    int seconds = _secondsPerRound;
    int moves = _maxMoveSteps;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MatchdayPalette.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            void syncSettings() {
              _applyLobbySettings(
                region: region,
                rounds: rounds,
                seconds: seconds,
                moves: moves,
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    '對戰設定',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<GameRegion>(
                    value: region,
                    decoration: const InputDecoration(
                      labelText: '區域',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: GameRegion.values
                        .map(
                          (GameRegion r) => DropdownMenuItem<GameRegion>(
                            value: r,
                            child: Text(r.label),
                          ),
                        )
                        .toList(),
                    onChanged: (GameRegion? value) {
                      if (value == null) return;
                      setSheetState(() => region = value);
                      syncSettings();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: rounds,
                    decoration: const InputDecoration(
                      labelText: '回合數',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: kRoundsPerGameOptions
                        .map(
                          (int n) => DropdownMenuItem<int>(
                            value: n,
                            child: Text('$n 回合'),
                          ),
                        )
                        .toList(),
                    onChanged: (int? value) {
                      if (value == null) return;
                      setSheetState(() => rounds = value);
                      syncSettings();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: seconds,
                    decoration: const InputDecoration(
                      labelText: '每回合秒數',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List<int>.generate(
                      (kMaxSecondsPerRound - kMinSecondsPerRound) ~/ 15 + 1,
                      (int i) => kMinSecondsPerRound + i * 15,
                    )
                        .map(
                          (int s) => DropdownMenuItem<int>(
                            value: s,
                            child: Text('$s 秒'),
                          ),
                        )
                        .toList(),
                    onChanged: (int? value) {
                      if (value == null) return;
                      setSheetState(() => seconds = value);
                      syncSettings();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: moves,
                    decoration: const InputDecoration(
                      labelText: 'Move 模式步數上限',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: kMoveStepLimitOptions
                        .map(
                          (int n) => DropdownMenuItem<int>(
                            value: n,
                            child: Text(n == 0 ? '無限制' : '$n 步'),
                          ),
                        )
                        .toList(),
                    onChanged: (int? value) {
                      if (value == null) return;
                      setSheetState(() => moves = value);
                      syncSettings();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _setEntertainmentMode(bool value) {
    setState(() {
      _entertainmentMode = value;
      if (value && _secondsPerRound < kMinSecondsPerRoundEntertainment) {
        _secondsPerRound = kMinSecondsPerRoundEntertainment;
      }
    });
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
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Text('請先登入才能使用線上大廳'),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext _) =>
                                        const LoginPage(),
                                  ),
                                );
                              },
                              child: const Text('前往登入'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...<Widget>[
                  if (!keyboardVisible)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Column(
                        children: <Widget>[
                          _LobbyOptionCard(
                            icon: Icons.tune,
                            iconColor: MatchdayPalette.ink,
                            borderColor: MatchdayPalette.ink,
                            backgroundColor: MatchdayPalette.cream,
                            title: '對戰設定',
                            subtitle:
                                '${_lobbySettings.region.label} · '
                                '${_lobbySettings.roundsPerGame} 回合 · '
                                '${_lobbySettings.secondsPerRound} 秒'
                                '${_lobbySettings.maxMoveSteps > 0 ? ' · Move ${_lobbySettings.maxMoveSteps} 步' : ''}',
                            trailing: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Colors.black54,
                            ),
                            onTap: _editDuelSetup,
                          ),
                          const SizedBox(height: 8),
                          _LobbyOptionCard(
                            icon: Icons.auto_awesome,
                            iconColor: _entertainmentMode
                                ? _entertainmentOrange
                                : MatchdayPalette.ink,
                            borderColor: _entertainmentMode
                                ? _entertainmentOrange
                                : MatchdayPalette.ink,
                            backgroundColor: _entertainmentMode
                                ? _entertainmentOrange.withValues(alpha: 0.12)
                                : MatchdayPalette.cream,
                            title: '娛樂模式',
                            titleColor: _entertainmentMode
                                ? _entertainmentOrange
                                : MatchdayPalette.ink,
                            subtitle:
                                'AI 道具 · 使用折半 · 不計排行榜 · 每回合 ≥60 秒',
                            trailing: Switch.adaptive(
                              value: _entertainmentMode,
                              onChanged: _setEntertainmentMode,
                              activeTrackColor:
                                  _entertainmentOrange.withValues(alpha: 0.55),
                              activeThumbColor: _entertainmentOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: MatchdayPalette.cream,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: MatchdayPalette.ink,
                                width: 1.5,
                              ),
                            ),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _chatController,
                              onSubmitted: (_) => _sendChat(),
                              textInputAction: TextInputAction.send,
                              decoration: const InputDecoration(
                                hintText: '輸入訊息…',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 12),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: MatchdayPalette.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: MatchdayPalette.ink,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _sendChat,
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!keyboardVisible)
            const FloatingHomeNavBar(current: HomeTab.lobby),
        ],
      ),
    );
  }
}

class _LobbyOptionCard extends StatelessWidget {
  const _LobbyOptionCard({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  static const double _minHeight = 56;

  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final Color backgroundColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: titleColor ?? MatchdayPalette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: MatchdayPalette.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
