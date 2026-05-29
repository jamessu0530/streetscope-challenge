// =============================================================================
// AudioService — 集中管理 BGM + 音效
//
// Singleton；四路 Player：
//   1. home BGM（loop）：首頁 / matchday 選單頁專用，偏 ambient / dreamy
//   2. calm game BGM（loop）：遊戲中倒數剩 > 30 秒，輕柔探索氛圍
//   3. game BGM（loop）：遊戲中倒數剩 ≤ 30 秒，lofi 壓迫感
//   4. SFX（release）：tick（倒數最後 5 秒）+ click（按鈕回饋）
//
// BGM 切換一律 crossfade / fade，避免硬切斷音。
//
// 音檔來源：
//   - assets/audio/home_bgm.mp3   （Kevin MacLeod - Dreamy Flashback，incompetech）
//   - assets/audio/calm_bgm.mp3   （Keys of Moon - White Petals，chosic / CC BY）
//   - assets/audio/lofi_bgm.mp3   （Purrple Cat - Equinox，chosic）
//   - assets/audio/tick.ogg       （Google Actions Sound Library CC-BY）
//   - assets/audio/click.ogg      （Google Actions Sound Library CC-BY，cartoon pop）
// =============================================================================

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum _InGameBgmPhase { none, calm, game }

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const String _homeBgmAsset = 'audio/home_bgm.mp3';
  static const String _calmBgmAsset = 'audio/calm_bgm.mp3';
  static const String _gameBgmAsset = 'audio/lofi_bgm.mp3';
  static const String _tickAsset = 'audio/tick.ogg';
  static const String _clickAsset = 'audio/click.ogg';

  static const double _homePeakVolume = 0.35;
  static const double _calmPeakVolume = 0.25;
  static const double _gamePeakVolume = 0.45;

  /// 探索 ↔ lofi 等「切換曲目」用較長 crossfade。
  static const Duration _bgmCrossfadeDuration = Duration(milliseconds: 1500);
  /// 離開遊戲、送答案等「收尾」用稍短 fade out。
  static const Duration _bgmFadeOutDuration = Duration(milliseconds: 800);
  static const int _bgmFadeSteps = 15;

  final AudioPlayer _homeBgmPlayer = AudioPlayer(playerId: 'home-bgm')
    ..setReleaseMode(ReleaseMode.loop);
  final AudioPlayer _calmBgmPlayer = AudioPlayer(playerId: 'calm-bgm')
    ..setReleaseMode(ReleaseMode.loop);
  final AudioPlayer _gameBgmPlayer = AudioPlayer(playerId: 'game-bgm')
    ..setReleaseMode(ReleaseMode.loop);
  final AudioPlayer _sfxPlayer = AudioPlayer(playerId: 'sfx')
    ..setReleaseMode(ReleaseMode.release);
  final AudioPlayer _clickPlayer = AudioPlayer(playerId: 'click')
    ..setReleaseMode(ReleaseMode.release);

  bool _homePlaying = false;
  bool _calmPlaying = false;
  bool _gamePlaying = false;
  int _bgmOpGen = 0;

  /// 遊戲內目標曲目；避免倒數每 250ms 觸發 onTick 重複啟動 crossfade 而中斷切換。
  _InGameBgmPhase _inGamePhase = _InGameBgmPhase.none;
  bool _inGameCrossfading = false;

  bool get isHomeBgmPlaying => _homePlaying;
  bool get isCalmBgmPlaying => _calmPlaying;
  bool get isGameBgmPlaying => _gamePlaying;
  bool get isInGameBgmPlaying => _calmPlaying || _gamePlaying;

  int _nextBgmOpGen() => ++_bgmOpGen;

  bool _isBgmOpCurrent(int gen) => gen == _bgmOpGen;

  Duration _stepDelay(Duration total) => Duration(
        microseconds: total.inMicroseconds ~/ _bgmFadeSteps,
      );

  Future<void> _fadePlayerVolume(
    int gen,
    AudioPlayer player,
    double from,
    double to,
    Duration duration,
  ) async {
    final Duration step = _stepDelay(duration);
    for (int i = 1; i <= _bgmFadeSteps; i++) {
      if (!_isBgmOpCurrent(gen)) return;
      final double t = i / _bgmFadeSteps;
      await player.setVolume(from + (to - from) * t);
      await Future<void>.delayed(step);
    }
  }

  Future<void> _fadeInBgm(
    int gen,
    AudioPlayer player,
    String asset,
    double peakVolume,
  ) async {
    if (!_isBgmOpCurrent(gen)) return;
    try {
      await player.setVolume(0);
      await player.play(AssetSource(asset));
      await _fadePlayerVolume(gen, player, 0, peakVolume, _bgmCrossfadeDuration);
      if (!_isBgmOpCurrent(gen)) return;
      await player.setVolume(peakVolume);
    } catch (e) {
      if (kDebugMode) debugPrint('BGM fade-in error: $e');
    }
  }

  Future<void> _fadeOutAndStopBgm(
    int gen,
    AudioPlayer player,
    double peakVolume,
    void Function() markStopped,
  ) async {
    if (!_isBgmOpCurrent(gen)) return;
    try {
      await _fadePlayerVolume(gen, player, peakVolume, 0, _bgmFadeOutDuration);
      if (!_isBgmOpCurrent(gen)) return;
      await player.stop();
      await player.setVolume(peakVolume);
      markStopped();
    } catch (e) {
      if (kDebugMode) debugPrint('BGM fade-out error: $e');
      markStopped();
    }
  }

  Future<void> _crossfadeBgm({
    required int gen,
    required AudioPlayer outPlayer,
    required double outPeakVolume,
    required void Function() markOutStopped,
    required AudioPlayer inPlayer,
    required String inAsset,
    required double inPeakVolume,
    required void Function() markInStarted,
  }) async {
    if (!_isBgmOpCurrent(gen)) return;
    try {
      await inPlayer.setVolume(0);
      await inPlayer.play(AssetSource(inAsset));
      markInStarted();

      final Duration step = _stepDelay(_bgmCrossfadeDuration);
      for (int i = 1; i <= _bgmFadeSteps; i++) {
        if (!_isBgmOpCurrent(gen)) return;
        final double t = i / _bgmFadeSteps;
        await outPlayer.setVolume(outPeakVolume * (1 - t));
        await inPlayer.setVolume(inPeakVolume * t);
        await Future<void>.delayed(step);
      }
      if (!_isBgmOpCurrent(gen)) return;

      await outPlayer.stop();
      await outPlayer.setVolume(outPeakVolume);
      markOutStopped();
      await inPlayer.setVolume(inPeakVolume);
    } catch (e) {
      if (kDebugMode) debugPrint('BGM crossfade error: $e');
    }
  }

  Future<void> _hardStopCalmBgm() async {
    try {
      await _calmBgmPlayer.stop();
    } catch (_) {}
    await _calmBgmPlayer.setVolume(_calmPeakVolume);
    _calmPlaying = false;
  }

  Future<void> _hardStopGameBgm() async {
    try {
      await _gameBgmPlayer.stop();
    } catch (_) {}
    await _gameBgmPlayer.setVolume(_gamePeakVolume);
    _gamePlaying = false;
  }

  // ---- Home BGM（首頁 / 選模式頁） -----------------------------------------
  Future<void> startHomeBgm() async {
    if (_homePlaying) return;
    final int gen = _nextBgmOpGen();

    if (_calmPlaying || _gamePlaying) {
      await _crossfadeInGameToHome(gen);
      return;
    }

    _homePlaying = true;
    await _fadeInBgm(gen, _homeBgmPlayer, _homeBgmAsset, _homePeakVolume);
    if (_isBgmOpCurrent(gen)) _homePlaying = true;
  }

  Future<void> _crossfadeInGameToHome(int gen) async {
    final bool hadCalm = _calmPlaying;
    final bool hadGame = _gamePlaying;
    if (!hadCalm && !hadGame) {
      _homePlaying = true;
      await _fadeInBgm(gen, _homeBgmPlayer, _homeBgmAsset, _homePeakVolume);
      return;
    }

    _homePlaying = true;
    if (hadCalm && hadGame) {
      await Future.wait<void>(<Future<void>>[
        _fadeOutAndStopBgm(gen, _calmBgmPlayer, _calmPeakVolume, () {
          _calmPlaying = false;
        }),
        _fadeOutAndStopBgm(gen, _gameBgmPlayer, _gamePeakVolume, () {
          _gamePlaying = false;
        }),
      ]);
      if (!_isBgmOpCurrent(gen)) return;
      await _fadeInBgm(gen, _homeBgmPlayer, _homeBgmAsset, _homePeakVolume);
      return;
    }

    final AudioPlayer outPlayer = hadCalm ? _calmBgmPlayer : _gameBgmPlayer;
    final double outPeak = hadCalm ? _calmPeakVolume : _gamePeakVolume;
    await _crossfadeBgm(
      gen: gen,
      outPlayer: outPlayer,
      outPeakVolume: outPeak,
      markOutStopped: () {
        if (hadCalm) {
          _calmPlaying = false;
        } else {
          _gamePlaying = false;
        }
      },
      inPlayer: _homeBgmPlayer,
      inAsset: _homeBgmAsset,
      inPeakVolume: _homePeakVolume,
      markInStarted: () => _homePlaying = true,
    );
  }

  Future<void> stopHomeBgm() async {
    if (!_homePlaying) return;
    final int gen = _nextBgmOpGen();
    await _fadeOutAndStopBgm(
      gen,
      _homeBgmPlayer,
      _homePeakVolume,
      () => _homePlaying = false,
    );
  }

  Future<void> pauseHomeBgm() async {
    if (!_homePlaying) return;
    _nextBgmOpGen();
    try {
      await _homeBgmPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeHomeBgm() async {
    try {
      await _homeBgmPlayer.resume();
      _homePlaying = true;
    } catch (_) {}
  }

  // ---- 遊戲 BGM（探索 ↔ lofi，含 crossfade） --------------------------------
  /// 應播探索曲：已在探索階段則略過；若 lofi 在播則 crossfade。
  Future<void> ensureCalmGameBgm() async {
    if (_inGamePhase == _InGameBgmPhase.calm) return;
    if (_inGameCrossfading) return;

    _inGamePhase = _InGameBgmPhase.calm;
    final int gen = _nextBgmOpGen();
    if (_homePlaying) {
      await _fadeOutAndStopBgm(
        gen,
        _homeBgmPlayer,
        _homePeakVolume,
        () => _homePlaying = false,
      );
    }
    if (!_isBgmOpCurrent(gen)) return;

    if (_gamePlaying) {
      _calmPlaying = true;
      _inGameCrossfading = true;
      try {
        await _crossfadeBgm(
          gen: gen,
          outPlayer: _gameBgmPlayer,
          outPeakVolume: _gamePeakVolume,
          markOutStopped: () => _gamePlaying = false,
          inPlayer: _calmBgmPlayer,
          inAsset: _calmBgmAsset,
          inPeakVolume: _calmPeakVolume,
          markInStarted: () => _calmPlaying = true,
        );
      } finally {
        _inGameCrossfading = false;
        if (_isBgmOpCurrent(gen) && _inGamePhase == _InGameBgmPhase.calm) {
          await _hardStopGameBgm();
          _calmPlaying = true;
        }
      }
      return;
    }

    _calmPlaying = true;
    await _fadeInBgm(gen, _calmBgmPlayer, _calmBgmAsset, _calmPeakVolume);
    if (!_isBgmOpCurrent(gen)) return;
    _calmPlaying = true;
  }

  /// 應播 lofi：已在衝刺階段則略過；若探索曲在播則 crossfade 並確實停掉探索曲。
  Future<void> ensureGameBgm() async {
    if (_inGamePhase == _InGameBgmPhase.game) {
      if (!_inGameCrossfading && _calmPlaying) {
        await _hardStopCalmBgm();
      }
      return;
    }
    if (_inGameCrossfading) return;

    _inGamePhase = _InGameBgmPhase.game;
    _gamePlaying = true;
    final int gen = _nextBgmOpGen();
    if (_homePlaying) {
      await _fadeOutAndStopBgm(
        gen,
        _homeBgmPlayer,
        _homePeakVolume,
        () => _homePlaying = false,
      );
    }
    if (!_isBgmOpCurrent(gen)) return;

    if (_calmPlaying) {
      _inGameCrossfading = true;
      try {
        await _crossfadeBgm(
          gen: gen,
          outPlayer: _calmBgmPlayer,
          outPeakVolume: _calmPeakVolume,
          markOutStopped: () => _calmPlaying = false,
          inPlayer: _gameBgmPlayer,
          inAsset: _gameBgmAsset,
          inPeakVolume: _gamePeakVolume,
          markInStarted: () => _gamePlaying = true,
        );
      } finally {
        _inGameCrossfading = false;
        if (_isBgmOpCurrent(gen) && _inGamePhase == _InGameBgmPhase.game) {
          await _hardStopCalmBgm();
          _gamePlaying = true;
        }
      }
      return;
    }

    await _fadeInBgm(gen, _gameBgmPlayer, _gameBgmAsset, _gamePeakVolume);
    if (!_isBgmOpCurrent(gen)) return;
    _gamePlaying = true;
  }

  /// 遊戲頁內兩段 BGM 淡出收尾（換回合、離開頁、送出答案、倒數歸零）。
  Future<void> stopAllInGameBgm() async {
    if (_inGamePhase == _InGameBgmPhase.none &&
        !_calmPlaying &&
        !_gamePlaying) {
      return;
    }
    _inGamePhase = _InGameBgmPhase.none;
    _inGameCrossfading = false;
    final int gen = _nextBgmOpGen();
    final List<Future<void>> fades = <Future<void>>[];
    if (_calmPlaying) {
      fades.add(_fadeOutAndStopBgm(
        gen,
        _calmBgmPlayer,
        _calmPeakVolume,
        () => _calmPlaying = false,
      ));
    }
    if (_gamePlaying) {
      fades.add(_fadeOutAndStopBgm(
        gen,
        _gameBgmPlayer,
        _gamePeakVolume,
        () => _gamePlaying = false,
      ));
    }
    await Future.wait<void>(fades);
  }

  /// App 進背景：取消進行中的 fade，兩段都暫停。
  Future<void> pauseInGameBgm() async {
    _nextBgmOpGen();
    await pauseCalmGameBgm();
    await pauseGameBgm();
  }

  /// 回前景：只恢復進背景前正在播的那一段。
  Future<void> resumeInGameBgm() async {
    if (_calmPlaying) await resumeCalmGameBgm();
    if (_gamePlaying) await resumeGameBgm();
  }

  Future<void> pauseCalmGameBgm() async {
    if (!_calmPlaying) return;
    try {
      await _calmBgmPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeCalmGameBgm() async {
    if (!_calmPlaying) return;
    try {
      await _calmBgmPlayer.resume();
    } catch (_) {}
  }

  Future<void> pauseGameBgm() async {
    if (!_gamePlaying) return;
    try {
      await _gameBgmPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeGameBgm() async {
    if (!_gamePlaying) return;
    try {
      await _gameBgmPlayer.resume();
    } catch (_) {}
  }

  // ---- SFX ------------------------------------------------------------------
  Future<void> playTick() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(1.0);
      await _sfxPlayer.play(AssetSource(_tickAsset));
    } catch (e) {
      if (kDebugMode) debugPrint('Tick play error: $e');
    }
  }

  Future<void> playClick() async {
    try {
      await _clickPlayer.stop();
      await _clickPlayer.setVolume(0.8);
      await _clickPlayer.play(AssetSource(_clickAsset));
    } catch (e) {
      if (kDebugMode) debugPrint('Click play error: $e');
    }
  }
}
