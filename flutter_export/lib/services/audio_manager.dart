// ============================================================
// audio_manager.dart — BGM + SFX + Android Lifecycle Management
// Tech Tycoon Merge
// audioplayers: ^6.0.0
//
// ════════════════════════════════════════════════════════════
// ROOT CAUSE OF BGM INTERRUPTION — and the fix
// ════════════════════════════════════════════════════════════
//
// BUG: Every new AudioPlayer() created for SFX requested
// AUDIOFOCUS_GAIN from the Android OS by default.
// Android then sent AUDIOFOCUS_LOSS to the BGM player,
// which the audioplayers library handled by stopping it.
//
// FIX — two-part:
//   1. BGM player: AudioContextAndroid(audioFocus: gain,
//      usageType: game, stayAwake: true).
//      Holds full audio focus for background music.
//
//   2. Each SFX player: AudioContextAndroid(audioFocus: none).
//      Does NOT participate in the focus protocol at all.
//      Android OS never sends AUDIOFOCUS_LOSS to the BGM.
//      iOS: AVAudioSessionOptions.mixWithOthers on every player.
//
// Result: BGM and SFX play fully simultaneously, at all times.
// ════════════════════════════════════════════════════════════
//
// Volume:
//   BGM  → default 0.30  (30 % calm background)
//   SFX  → default 1.00  (100 % clear, satisfying interaction)
//
// BGM loops infinitely via ReleaseMode.loop.
// ============================================================

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// ── Volume defaults ───────────────────────────────────────────────────────────
const double _kBgmVolume = 0.30; // 30 % — calm background, raised from 0.2
const double _kSfxVolume = 1.00; // 100 % — full clarity on every interaction

// ── Default BGM track ─────────────────────────────────────────────────────────
// "Floating Cities" by Kevin MacLeod (incompetech.com)
// Licensed under Creative Commons: By Attribution 4.0 License
const String _kDefaultBgm = 'audio/bgm_ambient.mp3';

// ── Audio context: BGM — holds full focus, loops indefinitely ─────────────────
final AudioContext _kBgmContext = AudioContext(
  android: AudioContextAndroid(
    // Full, persistent focus — the BGM owns audio for the session.
    audioFocus: AndroidAudioFocus.gain,
    // game usageType = optimised for low-latency game audio mixing
    usageType:   AndroidUsageType.game,
    contentType: AndroidContentType.music,
    stayAwake:   true,
    isSpeakerphoneOn: false,
  ),
  iOS: AudioContextIOS(
    // mixWithOthers lets BGM coexist with SFX on the same AVAudioSession.
    category: AVAudioSessionCategory.playback,
    options: {
      AVAudioSessionOptions.mixWithOthers,
      AVAudioSessionOptions.allowBluetooth,
    },
  ),
);

// ── Audio context: SFX — no focus request, always mixes with BGM ──────────────
final AudioContext _kSfxContext = AudioContext(
  android: AudioContextAndroid(
    // THE CRITICAL FIX: AudioFocus.none means this player NEVER sends
    // AUDIOFOCUS_GAIN to Android, so the OS never evicts the BGM player.
    audioFocus: AndroidAudioFocus.none,
    usageType:   AndroidUsageType.game,
    contentType: AndroidContentType.sonification,
    stayAwake:   false,
    isSpeakerphoneOn: false,
  ),
  iOS: AudioContextIOS(
    // ambient category + mixWithOthers = SFX mixes on top of BGM on iOS.
    category: AVAudioSessionCategory.ambient,
    options: {
      AVAudioSessionOptions.mixWithOthers,
    },
  ),
);

class AudioManager with WidgetsBindingObserver {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _bgm = AudioPlayer();

  // Runtime-settable volumes (updated by SettingsProvider)
  double _bgmVol = _kBgmVolume;
  double _sfxVol = _kSfxVolume;

  String? _currentBgmAsset;
  bool _bgmPaused   = false;
  bool _muted       = false;
  bool _initialized = false;

  /// Saved BGM asset path before malware takes over. Restored on malware end.
  String? _preMalwareBgm;

  // Getters for SettingsProvider / UI
  double get bgmVolume => _bgmVol;
  double get sfxVolume => _sfxVol;
  bool   get isMuted   => _muted;

  // ── Initialise ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;

      // Apply the BGM-specific audio context BEFORE any playback call.
      // This tells Android: "this player holds full, persistent focus".
      await _bgm.setAudioContext(_kBgmContext);
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(_bgmVol);
    } catch (e) {
      debugPrint('[Audio] initialize() failed: $e');
    }

    // Auto-start ambient BGM — runs after runApp(), never stalls cold-start UI.
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
  }

  // ── Mute control ──────────────────────────────────────────────────────────

  void setMuted(bool muted) {
    if (_muted == muted) return;
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

  void toggleMute() => setMuted(!_muted);

  // ── Malware BGM switchover ─────────────────────────────────────────────────

  /// Switch to villain/scary BGM the moment malware appears.
  /// Saves the current track so [resumePreMalwareBgm] can restore it.
  Future<void> playMalwareBgm() async {
    _preMalwareBgm = _currentBgmAsset;
    // Fade out current BGM quickly, then fade villain track in
    try { await _bgm.setVolume(0); } catch (_) {}
    await playBgm('audio/bgm_malware.mp3');
    // Smooth fade-in: ramp volume 0→target over 800 ms (16 steps × 50 ms)
    const steps = 16;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      try {
        final v = (_bgmVol * i / steps).clamp(0.0, 1.0);
        if (!_muted) await _bgm.setVolume(v);
      } catch (_) {}
    }
  }

  /// Restore the BGM that was playing before malware took over.
  Future<void> resumePreMalwareBgm() async {
    final prev = _preMalwareBgm;
    _preMalwareBgm = null;
    if (prev != null) {
      await playBgm(prev);
    }
  }

  // ── BGM controls ──────────────────────────────────────────────────────────

  Future<void> playBgm(String assetPath) async {
    if (!_initialized) return;
    try {
      final String asset = assetPath.replaceFirst('assets/', '');
      // Same track already playing — do nothing (avoids needless stop/restart)
      if (_currentBgmAsset == asset && !_bgmPaused) return;
      _currentBgmAsset = asset;
      await _bgm.stop();
      if (!_muted) {
        // Re-apply context and loop mode after every stop, as some Android
        // versions reset these on stop().
        await _bgm.setAudioContext(_kBgmContext);
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

  // ── SFX controls ──────────────────────────────────────────────────────────
  //
  // KEY DESIGN: every SFX gets a fresh AudioPlayer configured with
  // _kSfxContext (audioFocus: none). It plays, then disposes itself.
  // The BGM player's audio focus is NEVER affected.

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

      // ▶ CRITICAL FIX: Apply SFX context BEFORE play().
      // audioFocus: none → Android never sends AUDIOFOCUS_LOSS to BGM.
      // mixWithOthers   → iOS lets this SFX layer over the BGM session.
      await player.setAudioContext(_kSfxContext);
      await player.setVolume(_sfxVol);
      await player.play(AssetSource(asset));

      // Self-dispose after playback completes — no memory leak.
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
