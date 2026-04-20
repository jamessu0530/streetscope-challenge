// =============================================================================
// AudioService — 集中管理 BGM + 音效
//
// Singleton；三路 Player：
//   1. home BGM（loop）：首頁 / matchday 選單頁專用，偏 ambient / dreamy
//      → 讓 pre-game 氛圍跟遊戲主音樂做區分
//   2. game BGM（loop）：遊戲中倒數剩 30 秒才啟動，真・lofi 壓迫感
//   3. SFX（release）：tick（倒數最後 5 秒）+ click（按鈕回饋）
//
// 音檔來源：
//   - assets/audio/home_bgm.mp3   （Kevin MacLeod - Dreamy Flashback，incompetech）
//   - assets/audio/lofi_bgm.mp3   （Purrple Cat - Equinox，chosic）
//   - assets/audio/tick.ogg       （Google Actions Sound Library CC-BY）
//   - assets/audio/click.ogg      （Google Actions Sound Library CC-BY，cartoon pop）
// =============================================================================

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const String _homeBgmAsset = 'audio/home_bgm.mp3';
  static const String _gameBgmAsset = 'audio/lofi_bgm.mp3';
  static const String _tickAsset = 'audio/tick.ogg';
  static const String _clickAsset = 'audio/click.ogg';

  final AudioPlayer _homeBgmPlayer = AudioPlayer(playerId: 'home-bgm')
    ..setReleaseMode(ReleaseMode.loop);
  final AudioPlayer _gameBgmPlayer = AudioPlayer(playerId: 'game-bgm')
    ..setReleaseMode(ReleaseMode.loop);
  final AudioPlayer _sfxPlayer = AudioPlayer(playerId: 'sfx')
    ..setReleaseMode(ReleaseMode.release);
  final AudioPlayer _clickPlayer = AudioPlayer(playerId: 'click')
    ..setReleaseMode(ReleaseMode.release);

  bool _homePlaying = false;
  bool _gamePlaying = false;
  bool get isHomeBgmPlaying => _homePlaying;
  bool get isGameBgmPlaying => _gamePlaying;

  // ---- Home BGM（首頁 / 選模式頁） -----------------------------------------
  Future<void> startHomeBgm() async {
    if (_homePlaying) return;
    // 防呆：若 game BGM 還在（從遊戲回來但尚未觸發 stop），先關掉
    if (_gamePlaying) await stopGameBgm();
    try {
      await _homeBgmPlayer.setVolume(0.35);
      await _homeBgmPlayer.play(AssetSource(_homeBgmAsset));
      _homePlaying = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Home BGM play error: $e');
    }
  }

  Future<void> stopHomeBgm() async {
    if (!_homePlaying) return;
    try {
      await _homeBgmPlayer.stop();
    } catch (_) {}
    _homePlaying = false;
  }

  Future<void> pauseHomeBgm() async {
    if (!_homePlaying) return;
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

  // ---- Game BGM（遊戲中倒數壓迫感） -----------------------------------------
  Future<void> startGameBgm() async {
    if (_gamePlaying) return;
    if (_homePlaying) await stopHomeBgm();
    try {
      await _gameBgmPlayer.setVolume(0.45);
      await _gameBgmPlayer.play(AssetSource(_gameBgmAsset));
      _gamePlaying = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Game BGM play error: $e');
    }
  }

  Future<void> stopGameBgm() async {
    if (!_gamePlaying) return;
    try {
      await _gameBgmPlayer.stop();
    } catch (_) {}
    _gamePlaying = false;
  }

  Future<void> pauseGameBgm() async {
    if (!_gamePlaying) return;
    try {
      await _gameBgmPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeGameBgm() async {
    try {
      await _gameBgmPlayer.resume();
      _gamePlaying = true;
    } catch (_) {}
  }

  // ---- SFX ------------------------------------------------------------------
  /// 倒數最後 N 秒的 tick 音；短促、可中斷。
  Future<void> playTick() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setVolume(1.0);
      await _sfxPlayer.play(AssetSource(_tickAsset));
    } catch (e) {
      if (kDebugMode) debugPrint('Tick play error: $e');
    }
  }

  /// UI 按鈕點擊音；使用獨立 player 才不會把 tick 打斷。
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
