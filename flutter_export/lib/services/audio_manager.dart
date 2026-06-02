// ============================================================
// audio_manager.dart — BGM + SFX + Android Lifecycle Management
// Tech Tycoon Merge
// audioplayers: ^6.0.0
//
// Volume design (settable at runtime via SettingsProvider):
//   BGM  → default 0.20  (20 % calm background presence)
//   SFX  → default 1.00  (100 % — crisp interaction feedback)
//
// BGM loops infinitely via ReleaseMode.loop — it never stops.
// ============================================================

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ── Default volume constants (used on first launch / before prefs load) ───────
const double _kBgmVolume = 0.20;
const double _kSfxVolume = 1.00;

// ── Default BGM track ─────────────────────────────────────────────────────────
// "Floating Cities" by Kevin MacLeod (incompetech.com)
// Licensed under Creative Commons: By Attribution 4.0 License
// http://creativecommons.org/licenses/by/4.0/
const String _kDefaultBgm = 'audio/bgm_ambient.mp3';

class AudioManager with WidgetsBindingObserver {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _bgm = AudioPlayer();

  // ── Runtime volume state (updated by SettingsProvider) ────────────────────
  double _bgmVol = _kBgmVolume;
  double _sfxVol = _kSfxVolume;

  String? _currentBgmAsset;
  bool _bgmPaused   = false;
  bool _muted       = false;
  bool _initialized = false;

  // ── Getters for SettingsProvider / UI ─────────────────────────────────────
  double get bgmVolume => _bgmVol;
  double get sfxVolume => _sfxVol;
  bool   get isMuted   => _muted;

  // ── Initialise ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(_bgmVol);
    } catch (e) {
      debugPrint('[Audio] initialize() failed: $e');
    }
    await playBgm(_kDefaultBgm);
  }

  // ── Volume setters (called by SettingsProvider) ───────────────────────────

  void setBgmVolume(double v) {
    _bgmVol = v.clamp(0.0, 1.0);
    if (!_muted) {
      try { _bgm.setVolume(_bgmVol); } catch (e) {
        debugPrint('[Audio] setBgmVolume() failed: $e');
      }
    }
  }

  void setSfxVolume(double v) {
    _sfxVol = v.clamp(0.0, 1.0);
    // Applied per-play in _playSfx — no active player to update.
  }

  /// Set mute state explicitly (used by SettingsProvider on load + toggle).
  /// Idempotent — calling setMuted(true) twice has the same effect as once.
  void setMuted(bool muted) {
    if (_muted == muted) return; // already in desired state
    _muted = muted;
    try {
      if (_muted) {
        _bgm.setVolume(0);
      } else {
        _bgm.setVolume(_bgmVol);
        if (!_bgmPaused && _currentBgmAsset != null) _bgm.resume();
      }
    } catch (e) {
      debugPrint('[Audio] setMuted() failed: $e');
    }
  }

  /// Legacy toggle — kept for the mute button in the game HUD.
  void toggleMute() => setMuted(!_muted);

  // ── Public BGM controls ───────────────────────────────────────────────────

  Future<void> playBgm(String assetPath) async {
    if (!_initialized) return;
    try {
      final String asset = assetPath.replaceFirst('assets/', '');
      if (_currentBgmAsset == asset && !_bgmPaused) return;
      _currentBgmAsset = asset;
      await _bgm.stop();
      if (!_muted) {
        await _bgm.setReleaseMode(ReleaseMode.loop);
        await _bgm.setVolume(_bgmVol);
        await _bgm.play(AssetSource(asset));
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

  // ── SFX controls ─────────────────────────────────────────────────────────

  Future<void> playSpawnPop()    => _playSfx('audio/spawn_pop.mp3');
  Future<void> playMergeSnap()   => _playSfx('audio/merge_snap.mp3');
  Future<void> playErrorBuzz()   => _playSfx('audio/error_buzz.mp3');
  Future<void> playVictory()     => _playSfx('audio/level_victory_fanfare.mp3');
  Future<void> playTimeWarning() => _playSfx('audio/time_warning.mp3');
  Future<void> playUnlock()      => _playSfx('audio/spawn_pop.mp3');

  Future<void> _playSfx(String asset) async {
    if (!_initialized || _muted) return;
    try {
      final player = AudioPlayer();
      await player.setVolume(_sfxVol);
      await player.play(AssetSource(asset));
      player.onPlayerComplete.first
          .then((_) => player.dispose())
          .catchError((_) => player.dispose());
    } catch (e) {
      debugPrint('[Audio] _playSfx($asset) failed: $e');
    }
  }

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
    } catch (e) {
      debugPrint('[Audio] dispose() failed: $e');
    }
  }
}
