// ============================================================
// audio_manager.dart — BGM + SFX + Android Lifecycle Management
// Tech Tycoon Merge
// audioplayers: ^6.0.0
// ============================================================

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AudioManager with WidgetsBindingObserver {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _bgm = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();

  String? _currentBgmAsset;
  bool _bgmPaused = false;
  bool _muted     = false;
  bool _initialized = false;

  // ── Public BGM controls ───────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      WidgetsBinding.instance.addObserver(this);
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(0.6);
      await _sfx.setVolume(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('[Audio] initialize() failed: $e');
    }
  }

  Future<void> playBgm(String assetPath) async {
    if (!_initialized) return;
    try {
      if (_currentBgmAsset == assetPath && !_bgmPaused) {
        // Same track already playing — nothing to do
        return;
      }
      _currentBgmAsset = assetPath;
      await _bgm.stop();
      if (!_muted) {
        await _bgm.play(AssetSource(assetPath.replaceFirst('assets/', '')));
      }
    } catch (e) {
      debugPrint('[Audio] playBgm($assetPath) failed: $e');
    }
  }

  Future<void> pauseBgm() async {
    if (!_initialized) return;
    try {
      _bgmPaused = true;
      await _bgm.pause();
    } catch (e) {
      debugPrint('[Audio] pauseBgm() failed: $e');
    }
  }

  Future<void> resumeBgm() async {
    if (!_initialized || !_bgmPaused) return;
    try {
      _bgmPaused = false;
      if (!_muted) await _bgm.resume();
    } catch (e) {
      debugPrint('[Audio] resumeBgm() failed: $e');
    }
  }

  Future<void> stopBgm() async {
    if (!_initialized) return;
    try {
      _currentBgmAsset = null;
      await _bgm.stop();
    } catch (e) {
      debugPrint('[Audio] stopBgm() failed: $e');
    }
  }

  // ── Public SFX controls ───────────────────────────────────────────────────

  Future<void> playSpawnPop()    => _playSfx('audio/spawn_pop.mp3');
  Future<void> playMergeSnap()   => _playSfx('audio/merge_snap.mp3');
  Future<void> playErrorBuzz()   => _playSfx('audio/error_buzz.mp3');
  Future<void> playVictory()     => _playSfx('audio/level_victory_fanfare.mp3');
  Future<void> playTimeWarning() => _playSfx('audio/time_warning.mp3');
  Future<void> playUnlock()      => _playSfx('audio/spawn_pop.mp3');

  Future<void> _playSfx(String asset) async {
    if (!_initialized || _muted) return;
    try {
      await _sfx.play(AssetSource(asset));
    } catch (e) {
      debugPrint('[Audio] _playSfx($asset) failed: $e');
    }
  }

  // ── Mute toggle ───────────────────────────────────────────────────────────

  void toggleMute() {
    if (!_initialized) return;
    _muted = !_muted;
    try {
      if (_muted) {
        _bgm.setVolume(0);
        _sfx.setVolume(0);
      } else {
        _bgm.setVolume(0.6);
        _sfx.setVolume(1.0);
        if (!_bgmPaused && _currentBgmAsset != null) _bgm.resume();
      }
    } catch (e) {
      debugPrint('[Audio] toggleMute() failed: $e');
    }
  }

  bool get isMuted => _muted;

  // ── Android Lifecycle ─────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) return;
    try {
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
    } catch (e) {
      debugPrint('[Audio] lifecycle handler failed: $e');
    }
  }

  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
      _bgm.dispose();
      _sfx.dispose();
    } catch (e) {
      debugPrint('[Audio] dispose() failed: $e');
    }
  }
}
