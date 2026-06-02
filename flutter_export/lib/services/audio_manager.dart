// ============================================================
// audio_manager.dart — BGM + SFX + Android Lifecycle Management
// Tech Tycoon Merge
// audioplayers: ^6.0.0
//
// Volume design:
//   BGM  → _kBgmVolume  = 0.20  (calm 20 % background presence)
//   SFX  → _kSfxVolume  = 1.00  (100 % — crisp interaction feedback)
//
// BGM loops infinitely via ReleaseMode.loop — it never stops.
// ============================================================

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ── Volume constants ──────────────────────────────────────────────────────────
const double _kBgmVolume = 0.20; // 20 % — calm background, never distracting
const double _kSfxVolume = 1.00; // 100 % — satisfying, clearly audible SFX

// ── Default BGM (plays on app open / Level Map screen) ────────────────────────
// "Floating Cities" by Kevin MacLeod (incompetech.com)
// Licensed under Creative Commons: By Attribution 4.0 License
// http://creativecommons.org/licenses/by/4.0/
// Stored as bgm_ambient.mp3 — used for all phases.
const String _kDefaultBgm = 'audio/bgm_ambient.mp3';

class AudioManager with WidgetsBindingObserver {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _bgm = AudioPlayer();

  String? _currentBgmAsset;
  bool _bgmPaused   = false;
  bool _muted       = false;
  bool _initialized = false;

  // ── Initialise (called from main() AFTER runApp — never blocks the UI) ───────

  Future<void> initialize() async {
    try {
      WidgetsBinding.instance.addObserver(this);
      // CRITICAL: Set _initialized = true FIRST, before any platform calls.
      // In audioplayers ^6.0.0 on Android, setReleaseMode/setVolume can throw
      // if the native channel has a timing issue on cold start. Setting it first
      // means every play() call still attempts to run (each has its own try-catch).
      _initialized = true;
      // INFINITE LOOP: ReleaseMode.loop ensures BGM restarts automatically
      // when it reaches the end — it never stops playing.
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(_kBgmVolume);
    } catch (e) {
      debugPrint('[Audio] initialize() failed: $e');
    }

    // Auto-start the ambient BGM as soon as the SDK is ready.
    // Runs after runApp() — never stalls cold-start UI.
    await playBgm(_kDefaultBgm);
  }

  // ── Public BGM controls ───────────────────────────────────────────────────

  Future<void> playBgm(String assetPath) async {
    if (!_initialized) return;
    try {
      // Strip leading 'assets/' if the caller includes it.
      final String asset = assetPath.replaceFirst('assets/', '');

      if (_currentBgmAsset == asset && !_bgmPaused) {
        // Same track already playing — nothing to do
        return;
      }
      _currentBgmAsset = asset;
      await _bgm.stop();
      if (!_muted) {
        await _bgm.setReleaseMode(ReleaseMode.loop); // Re-affirm loop on every track change
        await _bgm.setVolume(_kBgmVolume);
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

  // ── Public SFX controls ───────────────────────────────────────────────────
  // Each SFX creates its own AudioPlayer so sounds never cut each other off.
  // Every player is set to _kSfxVolume (1.0) before playback.

  Future<void> playSpawnPop()    => _playSfx('audio/spawn_pop.mp3');
  Future<void> playMergeSnap()   => _playSfx('audio/merge_snap.mp3');
  Future<void> playErrorBuzz()   => _playSfx('audio/error_buzz.mp3');
  Future<void> playVictory()     => _playSfx('audio/level_victory_fanfare.mp3');
  Future<void> playTimeWarning() => _playSfx('audio/time_warning.mp3');
  Future<void> playUnlock()      => _playSfx('audio/spawn_pop.mp3');

  Future<void> _playSfx(String asset) async {
    if (!_initialized || _muted) return;
    try {
      // Fresh player per SFX so rapid spawns/merges never cancel each other.
      final player = AudioPlayer();
      await player.setVolume(_kSfxVolume); // Full volume — must stand out over BGM
      await player.play(AssetSource(asset));
      // Dispose automatically once the sound finishes.
      player.onPlayerComplete.first
          .then((_) => player.dispose())
          .catchError((_) => player.dispose());
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
      } else {
        _bgm.setVolume(_kBgmVolume); // Restore to 20 % — never back to a louder value
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
