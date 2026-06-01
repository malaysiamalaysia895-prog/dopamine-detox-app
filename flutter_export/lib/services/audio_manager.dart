// ============================================================
// audio_manager.dart — BGM + SFX + Android Lifecycle Management
// Tech Tycoon Merge
// audioplayers: ^6.0.0
// ============================================================

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class AudioManager with WidgetsBindingObserver {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  String? _currentBgmAsset;
  bool _bgmPaused = false;
  bool _muted     = false;

  // ── Public BGM controls ───────────────────────────────────────────────────

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await _bgm.setReleaseMode(ReleaseMode.loop);
    await _bgm.setVolume(0.6);
    await _sfx.setVolume(1.0);
  }

  Future<void> playBgm(String assetPath) async {
    if (_currentBgmAsset == assetPath) return;
    _currentBgmAsset = assetPath;
    await _bgm.stop();
    if (!_muted) {
      await _bgm.play(AssetSource(assetPath.replaceFirst('assets/', '')));
    }
  }

  Future<void> pauseBgm() async {
    _bgmPaused = true;
    await _bgm.pause();
  }

  Future<void> resumeBgm() async {
    if (!_bgmPaused) return;
    _bgmPaused = false;
    if (!_muted) await _bgm.resume();
  }

  Future<void> stopBgm() async {
    _currentBgmAsset = null;
    await _bgm.stop();
  }

  // ── Public SFX controls ───────────────────────────────────────────────────

  Future<void> playSpawnPop()    => _playSfx('audio/spawn_pop.mp3');
  Future<void> playMergeSnap()   => _playSfx('audio/merge_snap.mp3');
  Future<void> playErrorBuzz()   => _playSfx('audio/error_buzz.mp3');
  Future<void> playVictory()     => _playSfx('audio/level_victory_fanfare.mp3');
  Future<void> playTimeWarning() => _playSfx('audio/time_warning.mp3');
  Future<void> playUnlock()      => _playSfx('audio/spawn_pop.mp3'); // reuse

  Future<void> _playSfx(String asset) async {
    if (_muted) return;
    await _sfx.play(AssetSource(asset));
  }

  // ── Mute toggle ───────────────────────────────────────────────────────────

  void toggleMute() {
    _muted = !_muted;
    if (_muted) {
      _bgm.setVolume(0);
      _sfx.setVolume(0);
    } else {
      _bgm.setVolume(0.6);
      _sfx.setVolume(1.0);
      if (!_bgmPaused && _currentBgmAsset != null) _bgm.resume();
    }
  }

  bool get isMuted => _muted;

  // ── Android Lifecycle ─────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _bgm.pause();
        _sfx.pause();
        break;
      case AppLifecycleState.resumed:
        if (!_bgmPaused && !_muted && _currentBgmAsset != null) {
          _bgm.resume();
        }
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgm.dispose();
    _sfx.dispose();
  }
}
