// =============================================================================
// GamePage — 遊戲主頁
//
// ✅ [Multiple Pages #2] ✅ [StatefulWidget] ✅ [setState]
// ✅ [Callback / Lift]   GuessMap、CountdownTimerWidget
// ✅ [Timer]            CountdownTimerWidget
//
// 版型：
//   - 街景全螢幕 → 玩家拖曳上下左右環視 + 指南針
//   - 地圖預設隱藏 → 底部按鈕「打開地圖選位置」按下才出現（疊加層）
//   - 送出答案 → 結算疊加層 → 「查看地圖」開啟答案地圖
// =============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/game_constants.dart';
import '../models/game_mode.dart';
import '../models/game_settings.dart';
import '../models/guess_result.dart';
import '../models/meme_result.dart';
import '../models/place.dart';
import '../services/audio_service.dart';
import '../services/country_lookup_service.dart';
import '../services/meme_collection_service.dart';
import '../services/meme_service.dart';
import '../services/place_picker_service.dart';
import '../utils/map_utils.dart';
import '../widgets/countdown_timer_widget.dart';
import '../widgets/guess_map.dart';
import '../widgets/meme_punishment_overlay.dart';
import '../widgets/street_view_panel.dart';
import 'result_page.dart';

/// 倒數剩餘秒數 ≤ 此值 → 開始播 lofi BGM（一開始太吵，最後衝刺再出來比較有感）
const int kBgmStartRemainingSeconds = 30;

class GamePage extends StatefulWidget {
  final GameSettings settings;

  const GamePage({
    super.key,
    this.settings = const GameSettings(),
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  List<Place>? _places;
  String? _loadError;

  int _currentRound = 0;
  LatLng? _guessedLocation;
  bool _submitted = false;
  final List<GuessResult> _results = <GuessResult>[];
  Key _timerKey = UniqueKey();

  /// 控制各疊加層。地圖僅在使用者按按鈕時建立，避免常駐 PlatformView。
  bool _mapOverlayOpen = false;
  bool _roundSummaryWasTimeUp = false;

  /// Meme 懲罰相關狀態：低分時抓 meme 並顯示。
  bool _memeOverlayOpen = false;
  bool _memeLoading = false;
  PunishmentMemeOutcome? _memeOutcome;
  int _memeRequestSeq = 0;

  GoogleMapController? _mapController;

  /// 倒數 widget 的最新回呼值，用來決定什麼時候該播 tick。
  int _lastTickSecond = -1;

  Place get _currentPlace => _places![_currentRound];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlaces();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AudioService.instance.pauseGameBgm();
    } else if (state == AppLifecycleState.resumed) {
      if (AudioService.instance.isGameBgmPlaying) {
        AudioService.instance.resumeGameBgm();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioService.instance.stopGameBgm();
    super.dispose();
  }

  Future<void> _initPlaces() async {
    try {
      final List<Place> picked = await generateRandomPlaces(
        count: widget.settings.roundsPerGame,
        region: widget.settings.region,
      );
      if (!mounted) return;
      setState(() => _places = picked);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '$e');
    }
  }

  void _handleGuessChanged(LatLng position) {
    if (_submitted) return;
    setState(() => _guessedLocation = position);
  }

  /// 街景依 Metadata [links] 移動後，同步更新本回合「正確答案」座標與 panoId。
  void _handleStreetViewPlaceChanged(Place newPlace) {
    if (_submitted) return;
    final List<Place>? places = _places;
    if (places == null) return;
    setState(() {
      places[_currentRound] = newPlace;
    });
  }

  bool _repicking = false;

  /// 街景告訴我們：這個 panorama 沒有任何可走的 links（俯視 / 空拍 / 孤島）。
  /// 自動重抽一個本回合的地點。
  Future<void> _handleStreetViewNeedsRepick() async {
    if (_submitted || _repicking) return;
    final List<Place>? places = _places;
    if (places == null) return;
    _repicking = true;
    try {
      final List<Place> fresh = await generateRandomPlaces(
        count: 1,
        region: widget.settings.region,
      );
      if (!mounted) return;
      if (_submitted) return;
      setState(() {
        places[_currentRound] = fresh.first;
        // 換新地點 = 重新計時。
        _timerKey = UniqueKey();
        _guessedLocation = null;
      });
    } catch (_) {
      // 抽不到就放棄重抽，讓玩家用原本那張。
    } finally {
      _repicking = false;
    }
  }

  void _handleTimeUp() {
    if (_submitted) return;
    _submitGuess(timeUp: true);
  }

  void _submitGuess({bool timeUp = false}) {
    if (_submitted) return;

    final GuessResult result = _guessedLocation == null
        ? GuessResult.noAnswer(_currentPlace)
        : GuessResult.fromGuess(
            correctPlace: _currentPlace,
            guessed: _guessedLocation!,
          );

    setState(() {
      _submitted = true;
      _results.add(result);
      _roundSummaryWasTimeUp = timeUp;
      // 送出 → 直接打開答案地圖（含距離 / 分數），按鈕就是下一回合。
      _mapOverlayOpen = true;
    });

    // 送出就停 BGM；等下一題再視倒數重新啟動
    AudioService.instance.stopGameBgm();

    // 低分懲罰：本回合 <1000 分 → 背景抓 meme 後疊加顯示。
    // 不 await，不阻塞主流程；抓到再更新狀態。
    if (result.score < kMemePunishmentScoreThreshold) {
      _triggerMemePunishment(result);
    }
  }

  /// 倒數每秒回呼：
  /// - 剩餘 ≤ 30 秒 → 啟動 lofi BGM（若尚未啟動）
  /// - 剩餘 ≤ 5 秒  → 每秒播一次 tick
  void _handleCountdownTick(int remaining) {
    // 低於 30 秒才開始鋪 lofi
    if (remaining > 0 &&
        remaining <= kBgmStartRemainingSeconds &&
        !AudioService.instance.isGameBgmPlaying) {
      AudioService.instance.startGameBgm();
    }

    if (remaining <= 0) {
      _lastTickSecond = -1;
      return;
    }
    if (remaining > kCountdownTickThresholdSeconds ||
        remaining == _lastTickSecond) {
      return;
    }
    _lastTickSecond = remaining;
    AudioService.instance.playTick();
  }

  /// 背景流程：反查國家 → 抓 meme → 更新 UI。任何錯誤都吞掉，
  /// 因為這只是嘲諷彩蛋，不能拖慢或中斷遊戲本身。
  Future<void> _triggerMemePunishment(GuessResult result) async {
    final int seq = ++_memeRequestSeq;
    setState(() {
      _memeLoading = true;
      _memeOutcome = null;
      _memeOverlayOpen = true;
    });

    try {
      final String? country = await lookupCountryName(
        result.correctPlace.latitude,
        result.correctPlace.longitude,
      );
      final PunishmentMemeOutcome outcome = await fetchPunishmentMeme(
        country: country,
        score: result.score,
      );
      if (!mounted) return;
      // 玩家已經走到下一回合 → 丟掉舊結果
      if (seq != _memeRequestSeq) return;
      setState(() {
        _memeOutcome = outcome;
        _memeLoading = false;
      });
      // 有抓到 meme 就順手存進「迷因收集庫」。失敗就算了，不影響主流程。
      if (outcome.selectedMeme != null) {
        unawaited(MemeCollectionService.instance.add(
          meme: outcome.selectedMeme!,
          country: outcome.country,
          score: outcome.score,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      if (seq != _memeRequestSeq) return;
      setState(() {
        _memeOutcome = PunishmentMemeOutcome(
          triggered: true,
          country: null,
          score: result.score,
          queryUsed: null,
          selectedMeme: null,
          fallbackUsed: true,
        );
        _memeLoading = false;
      });
    }
  }

  void _dismissMeme() {
    setState(() {
      _memeOverlayOpen = false;
    });
  }

  void _openMap() {
    setState(() => _mapOverlayOpen = true);
  }

  void _closeMap() {
    setState(() {
      _mapOverlayOpen = false;
      _mapController = null;
    });
  }

  Future<void> _fitMapToBoth() async {
    final GoogleMapController? c = _mapController;
    if (c == null) return;
    final LatLng correct = _currentPlace.latLng;
    final LatLng? guessed = _guessedLocation;

    try {
      if (guessed == null) {
        await c.animateCamera(CameraUpdate.newLatLngZoom(correct, 5));
        return;
      }
      final LatLngBounds bounds = boundsForTwoPoints(guessed, correct);
      final double latSpan =
          (bounds.northeast.latitude - bounds.southwest.latitude).abs();
      final double lngSpan =
          (bounds.northeast.longitude - bounds.southwest.longitude).abs();
      if (latSpan < 1e-5 && lngSpan < 1e-5) {
        await c.animateCamera(CameraUpdate.newLatLngZoom(correct, 12));
        return;
      }
      await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {
      // 忽略 PlatformView 邊界例外。
    }
  }

  void _goToNextRoundOrFinish() {
    if (_currentRound >= _places!.length - 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => ResultPage(
            results: _results,
            settings: widget.settings,
          ),
        ),
      );
      return;
    }

    setState(() {
      _currentRound += 1;
      _guessedLocation = null;
      _submitted = false;
      _mapOverlayOpen = false;
      _mapController = null;
      _timerKey = UniqueKey();
      _lastTickSecond = -1;
      // 清掉上一回合的 meme 彩蛋
      _memeOverlayOpen = false;
      _memeOutcome = null;
      _memeLoading = false;
      _memeRequestSeq++;
    });
    // 下一題一開始先靜音；要等倒數再度 ≤ 30 秒才播。
    AudioService.instance.stopGameBgm();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) return _buildErrorScaffold();
    if (_places == null) return _buildLoadingScaffold();

    final Place place = _currentPlace;
    final bool hasGuess = _guessedLocation != null;
    final bool isLastRound = _currentRound >= _places!.length - 1;
    final GuessResult? summaryResult =
        _results.isNotEmpty ? _results.last : null;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await _handleBackTap();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _MatchdayGameAppBar(
          currentRound: _currentRound + 1,
          totalRounds: _places!.length,
          submitted: _submitted,
          timer: _submitted
              ? null
              : CountdownTimerWidget(
                  key: _timerKey,
                  totalSeconds: widget.settings.secondsPerRound,
                  onTimeUp: _handleTimeUp,
                  onTick: _handleCountdownTick,
                ),
          onBack: _handleBackTap,
        ),
        body: Stack(
          children: [
            _buildMainContent(
              place: place,
              hasGuess: hasGuess,
              isLastRound: isLastRound,
            ),
            if (_mapOverlayOpen)
              _MapOverlay(
                place: place,
                guessed: _guessedLocation,
                submitted: _submitted,
                isLastRound: isLastRound,
                wasTimeUp: _roundSummaryWasTimeUp,
                result: _submitted ? summaryResult : null,
                onMapCreated: (GoogleMapController c) {
                  _mapController = c;
                  if (_submitted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _fitMapToBoth();
                    });
                  }
                },
                onGuessChanged: _handleGuessChanged,
                onClose: _closeMap,
                onNextRound: _goToNextRoundOrFinish,
              ),
            if (_memeOverlayOpen)
              MemePunishmentOverlay(
                loading: _memeLoading,
                outcome: _memeOutcome,
                onDismiss: _dismissMeme,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBackTap() async {
    final bool leave = await _confirmExit();
    if (!leave) return;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool> _confirmExit() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('離開遊戲？'),
          content: const Text('目前進度尚未完成，離開後本場成績不會記錄。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('繼續遊戲'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('離開'),
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }

  Widget _buildMainContent({
    required Place place,
    required bool hasGuess,
    required bool isLastRound,
  }) {
    // 浮動送出按鈕高度 (52) + 底部安全區 bottom padding (~34 on notched iPhones)
    //   + 額外 16 留白 + google 版權字高度 ~20
    // 抓個簡單保守值：72px 作為「街景控制項要往上躲多少」
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    final double streetViewBottomInset = 52 + 16 + bottomSafe + 4;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: StreetViewPanel(
            // 只用 round 當 key：
            //   - 走路 → State 內 _ignoreNextExternalChange=true，不 reload
            //   - 自動重抽 / 換回合 → didUpdateWidget 看到 place 變且旗標未設 → reload
            key: ValueKey<int>(_currentRound),
            place: place,
            mode: widget.settings.mode,
            // No Move / Picture 模式不會在街景中走動，所以不需要 onPlaceChanged。
            onPlaceChanged: widget.settings.mode == GameMode.move
                ? _handleStreetViewPlaceChanged
                : null,
            onNeedsRepick: _handleStreetViewNeedsRepick,
            // 把「打開地圖選位置」整合進街景右上角的 icon
            onOpenMap: _submitted ? null : _openMap,
            hasGuess: hasGuess,
            maxMoveSteps: widget.settings.maxMoveSteps,
            bottomInset: streetViewBottomInset,
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: _FloatingSubmitButton(
              enabled: hasGuess && !_submitted,
              label: hasGuess ? '送出答案' : '請先在地圖上選位置',
              onTap: hasGuess && !_submitted ? () => _submitGuess() : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('GeoGuesser')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在隨機產生地點並對齊街景…'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('GeoGuesser')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() => _loadError = null);
                  _initPlaces();
                },
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 編輯風 AppBar：黑底 + LIVE 點 + 回合指示 + 右側計時膠囊
// =============================================================================
class _MatchdayGameAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final int currentRound;
  final int totalRounds;
  final bool submitted;
  final Widget? timer;
  final VoidCallback onBack;

  const _MatchdayGameAppBar({
    required this.currentRound,
    required this.totalRounds,
    required this.submitted,
    required this.timer,
    required this.onBack,
  });

  static const Color _ink = Color(0xFF101014);
  static const Color _accent = Color(0xFFFF3D57);

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ink,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              // 左側：自訂返回鈕
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: IconButton(
                  tooltip: '退出遊戲',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBack,
                ),
              ),
              // 中央：LIVE 點 + ROUND n/N
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ROUND $currentRound / $totalRounds',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
              // 右側：計時膠囊 / 已提交標記
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: submitted
                    ? _SubmittedBadge()
                    : _TimerPill(child: timer!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  final Widget child;
  const _TimerPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          color: _MatchdayGameAppBar._ink,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
        child: IconTheme.merge(
          data: const IconThemeData(
            color: _MatchdayGameAppBar._ink,
            size: 16,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SubmittedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: const Text(
        'SUBMITTED',
        style: TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

// =============================================================================
// 浮動送出按鈕：街景全螢幕時疊在底部，毛玻璃感 + 陰影，保持可讀性
// =============================================================================
class _FloatingSubmitButton extends StatelessWidget {
  final bool enabled;
  final String label;
  final VoidCallback? onTap;

  const _FloatingSubmitButton({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = enabled
        ? Theme.of(context).colorScheme.primary
        : Colors.black.withValues(alpha: 0.55);
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  enabled ? Icons.check : Icons.place_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 全螢幕地圖疊加層
// =============================================================================

class _MapOverlay extends StatelessWidget {
  final Place place;
  final LatLng? guessed;
  final bool submitted;
  final bool isLastRound;
  final bool wasTimeUp;
  final GuessResult? result;
  final ValueChanged<GoogleMapController> onMapCreated;
  final ValueChanged<LatLng> onGuessChanged;
  final VoidCallback onClose;
  final VoidCallback onNextRound;

  const _MapOverlay({
    required this.place,
    required this.guessed,
    required this.submitted,
    required this.isLastRound,
    required this.wasTimeUp,
    required this.result,
    required this.onMapCreated,
    required this.onGuessChanged,
    required this.onClose,
    required this.onNextRound,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool hasGuess = guessed != null;
    final double topSafe = MediaQuery.of(context).padding.top;
    final double bottomSafe = MediaQuery.of(context).padding.bottom;

    // 底部操作條高度估計（給地圖的縮放按鈕 bottomInset 用）
    final double bottomBarHeight = submitted ? 120 : 110;

    return Positioned.fill(
      child: Material(
        color: Colors.black,
        child: Stack(
          children: <Widget>[
            // ---- 全螢幕地圖（邊到邊）
            Positioned.fill(
              child: GuessMap(
                onGuessChanged: onGuessChanged,
                onMapCreated: onMapCreated,
                locked: submitted,
                guessedLocation: guessed,
                correctLocation: submitted ? place.latLng : null,
                cornerRadius: 0,
                bottomInset: bottomBarHeight + bottomSafe + 8,
              ),
            ),

            // ---- 頂部狀態條（浮動在地圖上）
            Positioned(
              left: 12,
              right: 12,
              top: topSafe + 10,
              child: _MapOverlayHeader(
                submitted: submitted,
                wasTimeUp: wasTimeUp,
                hasGuess: hasGuess,
                onClose: submitted ? null : onClose,
              ),
            ),

            // ---- 底部：結算 strip / 提示 + 主按鈕
            Positioned(
              left: 12,
              right: 12,
              bottom: bottomSafe + 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (submitted && result != null)
                    _ResultStrip(result: result!)
                  else
                    _GuessCoordPill(guessed: guessed),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: submitted
                          ? onNextRound
                          : (hasGuess ? onClose : null),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      icon: Icon(
                        submitted
                            ? (isLastRound
                                ? Icons.emoji_events
                                : Icons.arrow_forward)
                            : Icons.check,
                      ),
                      label: Text(
                        submitted
                            ? (isLastRound ? '查看總成績' : '下一回合')
                            : (hasGuess ? '完成猜測' : '尚未選擇位置'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 浮動頂部 header：半透明黑底 + 關閉鈕 + 標題。
class _MapOverlayHeader extends StatelessWidget {
  final bool submitted;
  final bool wasTimeUp;
  final bool hasGuess;
  final VoidCallback? onClose;

  const _MapOverlayHeader({
    required this.submitted,
    required this.wasTimeUp,
    required this.hasGuess,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final String title = submitted
        ? (wasTimeUp ? '時間到！' : '本回合結算')
        : '請點地圖選擇你的猜測';
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
        child: Row(
          children: <Widget>[
            if (onClose != null)
              IconButton(
                tooltip: '返回街景',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              )
            else
              const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuessCoordPill extends StatelessWidget {
  final LatLng? guessed;
  const _GuessCoordPill({required this.guessed});

  @override
  Widget build(BuildContext context) {
    final bool hasGuess = guessed != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            hasGuess ? Icons.place : Icons.touch_app,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            hasGuess
                ? '${guessed!.latitude.toStringAsFixed(2)}°, '
                    '${guessed!.longitude.toStringAsFixed(2)}°'
                : '點地圖任一位置下注',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 送出後在地圖底部顯示距離 + 分數的小條。
class _ResultStrip extends StatelessWidget {
  final GuessResult result;
  const _ResultStrip({required this.result});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String distanceText = result.distanceKm == null
        ? '本回合未作答'
        : '距離：${result.distanceKm!.toStringAsFixed(1)} 公里';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            distanceText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onPrimaryContainer,
            ),
          ),
          Text(
            '本回合 ${result.score} 分',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
