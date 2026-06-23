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
//      Android OS never sends AUDIOFOCUS_LOSS to the BGM player.
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
const double _kBgmVolume = 0.15; // 15 % — softer background during gameplay
const double _kSfxVolume = 1.00; // 100 % — full clarity on every interaction

// ── Default BGM track ─────────────────────────────────────────────────────────
const String _kDefaultBgm = 'audio/bgm_ambient.mp3';

// ── Audio context: BGM — holds full focus, loops indefinitely ─────────────────
final AudioContext _kBgmContext = AudioContext(
  android: AudioContextAndroid(
    audioFocus: AndroidAudioFocus.gain,
    usageType:   AndroidUsageType.game,
    contentType: AndroidContentType.music,
    stayAwake:   true,
    isSpeakerphoneOn: false,
  ),
  iOS: AudioContextIOS(
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
    audioFocus: AndroidAudioFocus.none,
    usageType:   AndroidUsageType.game,
    contentType: AndroidContentType.sonification,
    stayAwake:   false,
    isSpeakerphoneOn: false,
  ),
  iOS: AudioContextIOS(
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

  double _bgmVol = _kBgmVolume;
  double _sfxVol = _kSfxVolume;

  String? _currentBgmAsset;
  bool _bgmPaused   = false;
  bool _muted       = false;
  bool _initialized = false;

  /// Saved BGM asset path before malware takes over. Restored on malware end.
  String? _preMalwareBgm;

  /// Saved BGM asset path before robot takes over. Restored on robot end.
  String? _preRobotBgm;

  /// Saved BGM asset path before creature (Data Kraken) takes over.
  String? _preCreatureBgm;

  /// Saved BGM asset path before alien invasion takes over.
  String? _preAlienBgm;

  double get bgmVolume => _bgmVol;
  double get sfxVolume => _sfxVol;
  bool   get isMuted   => _muted;

  // ── Initialise ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
      await _bgm.setAudioContext(_kBgmContext);
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(_bgmVol);
    } catch (e) {
      debugPrint('[Audio] initialize() failed: $e');
    }
    await playBgm(_kDefaultBgm);
  }

  // ── Volume setters ────────────────────────────────────────────────────────

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

  // ── Malware BGM switchover (Levels 5, 7, 9, 10) ──────────────────────────

  /// Switch to villain/scary BGM the moment malware appears.
  /// Saves the current track so [resumePreMalwareBgm] can restore it.
  Future<void> playMalwareBgm() async {
    _preMalwareBgm = _currentBgmAsset;
    await playBgm('audio/bgm_malware.mp3');
  }

  /// Restore the BGM that was playing before malware took over.
  Future<void> resumePreMalwareBgm() async {
    final prev = _preMalwareBgm;
    _preMalwareBgm = null;
    if (prev != null) await playBgm(prev);
  }

  // ── Robot BGM switchover ──────────────────────────────────────────────────

  /// Switch to robot villain BGM when robot appears.
  Future<void> playRobotBgm() async {
    _preRobotBgm = _currentBgmAsset;
    await playBgm('audio/bgm_robot.mp3');
  }

  /// Restore the BGM that was playing before robot took over.
  Future<void> resumePreRobotBgm() async {
    final prev = _preRobotBgm;
    _preRobotBgm = null;
    if (prev != null) await playBgm(prev);
  }

  // ── Creature BGM switchover (Data Kraken, Levels 23, 25, 27, 29) ─────────

  /// Villain entry BGM — played while creature assembles on screen.
  /// Saves the current track so [resumePreCreatureBgm] can restore it later.
  Future<void> playCreatureBgm() async {
    _preCreatureBgm = _currentBgmAsset;
    await playBgm('audio/bgm_creature.mp3');
  }

  /// Switch to energetic gameplay BGM once Data Kraken is fully active.
  /// Uses bgm_megacorp.mp3 — epic/energetic feel for the battle phase.
  Future<void> playCreatureActiveBgm() async {
    await playBgm('audio/bgm_creature.mp3');
  }

  /// Restore the BGM that was playing before the creature took over.
  Future<void> resumePreCreatureBgm() async {
    final prev = _preCreatureBgm;
    _preCreatureBgm = null;
    if (prev != null) await playBgm(prev);
  }

  // ── Alien BGM switchover (Levels 31, 32, 33) ─────────────────────────────

  /// Switch to villain/scary BGM while alien ships enter.
  /// Saves the current track so [resumePreAlienBgm] can restore it later.
  /// AlienController will switch to the level-specific alien BGM once
  /// the ship entry animation is complete and the alien goes active.
  Future<void> playAlienBgm(String assetPath) async {
    _preAlienBgm = _currentBgmAsset;
    await playBgm(assetPath);
  }

  /// Restore the BGM that was playing before alien invasion.
  Future<void> resumePreAlienBgm() async {
    final prev = _preAlienBgm;
    _preAlienBgm = null;
    if (prev != null) await playBgm(prev);
  }

  // ── BGM controls ──────────────────────────────────────────────────────────

  Future<void> playBgm(String assetPath) async {
    if (!_initialized) return;
    try {
      final String asset = assetPath.replaceFirst('assets/', '');
      if (_currentBgmAsset == asset && !_bgmPaused) return;
      _currentBgmAsset = asset;
      await _bgm.stop();
      if (!_muted) {
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

  Future<void> playSpawnPop()    => _playSfx('audio/spawn_pop.mp3');
  Future<void> playMergeSnap()   => _playSfx('audio/merge_snap.mp3');
  Future<void> playErrorBuzz()   => _playSfx('audio/error_buzz.mp3');
  Future<void> playVictory()     => _playSfx('audio/level_victory_fanfare.mp3');
  Future<void> playTimeWarning() => _playSfx('audio/time_warning.mp3');
  Future<void> playMalwareBlast()  => _playSfx('audio/level_victory_fanfare.mp3');
  Future<void> playUnlock()      => _playSfx('audio/spawn_pop.mp3');

  Future<void> _playSfx(String asset) async {
    if (!_initialized || _muted) return;
    try {
      final player = AudioPlayer();
      await player.setAudioContext(_kSfxContext);
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
