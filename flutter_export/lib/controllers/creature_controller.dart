// ============================================================
// creature_controller.dart  —  Data Kraken Silicon Valley Boss
// Levels 23 · 25 · 27 · 29
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_manager.dart';

// ── Boss phases ───────────────────────────────────────────────────────────────

enum CreaturePhase {
  idle,
  warningEntry,   // L23 only — full-screen danger briefing (5 s)
  assemblyEntry,  // dramatic entrance — body + tentacles materialise (2.4 s)
  active,         // throws corrupted packets every 4–5 s
  winBlast,       // player finishes quota → spectacular explosion (3.2 s)
}

// Levels where Data Kraken appears
const Set<int> kCreatureLevelSet = {23, 25, 27, 29};

// ── Controller ────────────────────────────────────────────────────────────────

class CreatureController extends ChangeNotifier with WidgetsBindingObserver {

  // ── Public state (read by overlay + provider) ─────────────────────────────
  CreaturePhase phase        = CreaturePhase.idle;
  int           currentLevel = 0;
  int           throwCount   = 0;   // increments every throw (used by overlay)
  int           throwArmIdx  = 0;   // which tentacle throws (0-7, cycles)
  bool          permanentlyDefeated = false;

  // ── Private ───────────────────────────────────────────────────────────────
  bool          _appFg = true;
  VoidCallback? _onThrow;

  Timer?       _postAnim;
  Timer?       _throwTimer;
  Timer?       _vibTimer;
  final Random _rng = Random();

  CreatureController() {
    WidgetsBinding.instance.addObserver(this);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appFg = state == AppLifecycleState.resumed;
    if (!_appFg) {
      _throwTimer?.cancel();
      _vibTimer?.cancel();
      try { Vibration.cancel(); } catch (_) {}
    }
  }

  // ── Convenience getters ───────────────────────────────────────────────────

  bool get isIdle   => phase == CreaturePhase.idle;
  bool get isFinal  => currentLevel == 29;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Call from GameNotifier.dismissStory().  [onThrow] fires every 4–5 s.
  void triggerForLevel(int level, {required VoidCallback onThrow}) {
    if (permanentlyDefeated) return;
    if (!kCreatureLevelSet.contains(level)) { _goIdle(); return; }

    _cancelTimers();
    currentLevel = level;
    throwCount   = 0;
    throwArmIdx  = 0;
    _onThrow     = onThrow;

    _hapticBurst();
    AudioManager.instance.playCreatureBgm().catchError((_) {});

    if (level == 23) {
      // Level 23: show full-screen warning for 5 seconds
      phase = CreaturePhase.warningEntry;
      notifyListeners();
      _postAnim = Timer(const Duration(seconds: 5), _beginAssembly);
    } else {
      _beginAssembly();
    }
  }

  /// Player taps "FACE THE KRAKEN" on warning screen → skip wait.
  void dismissWarning() {
    if (phase != CreaturePhase.warningEntry) return;
    _postAnim?.cancel();
    _beginAssembly();
  }

  /// Called when a creature-thrown item is successfully merged.
  void onThrowMerged() => notifyListeners();

  /// Called when the player completes the level delivery quota.
  void onLevelComplete() {
    if (phase == CreaturePhase.idle || phase == CreaturePhase.winBlast) return;
    _cancelTimers();
    AudioManager.instance.resumePreCreatureBgm();
    _safeVibrate(pattern: [0, 200, 60, 300, 60, 450, 60, 800]);
    phase = CreaturePhase.winBlast;
    if (isFinal) permanentlyDefeated = true;
    notifyListeners();
    _postAnim = Timer(const Duration(milliseconds: 3200), _goIdle);
  }

  void reset() {
    _cancelTimers();
    AudioManager.instance.resumePreCreatureBgm();
    _goIdle();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _beginAssembly() {
    phase = CreaturePhase.assemblyEntry;
    notifyListeners();
    _postAnim = Timer(const Duration(milliseconds: 4200), () {
      phase = CreaturePhase.active;
      _startThrowCycle();
      _startVibPulse();
      notifyListeners();
    });
  }

  void _startThrowCycle() {
    final delayMs = 4000 + _rng.nextInt(1001); // 4 000 – 5 000 ms
    _throwTimer = Timer(Duration(milliseconds: delayMs), () {
      if (phase != CreaturePhase.active) return;
      throwCount++;
      throwArmIdx = _rng.nextInt(8); // random tentacle throws each time
      _onThrow?.call();
      _safeVibrate(pattern: [0, 55, 25, 90]);
      notifyListeners();
      _startThrowCycle();
    });
  }

  void _startVibPulse() {
    _vibTimer = Timer.periodic(const Duration(milliseconds: 4000), (_) {
      if (phase != CreaturePhase.active) { _vibTimer?.cancel(); return; }
      _safeVibrate(pattern: [0, 20, 10, 20]);
    });
  }

  void _hapticBurst() {
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    Future.delayed(const Duration(milliseconds: 130), () {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    });
    Future.delayed(const Duration(milliseconds: 310), () {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    });
    _safeVibrate(pattern: [0, 180, 60, 220, 60, 450]);
  }

  void _goIdle() {
    phase        = CreaturePhase.idle;
    currentLevel = 0;
    throwCount   = 0;
    throwArmIdx  = 0;
    _onThrow     = null;
    notifyListeners();
  }

  void _cancelTimers() {
    _postAnim?.cancel();
    _throwTimer?.cancel();
    _vibTimer?.cancel();
    _postAnim = _throwTimer = _vibTimer = null;
  }

  Future<void> _safeVibrate({List<int>? pattern, int duration = 300}) async {
    if (!_appFg) return;
    try {
      final has = await Vibration.hasVibrator() ?? false;
      if (!has) return;
      if (pattern != null) { await Vibration.vibrate(pattern: pattern); }
      else { await Vibration.vibrate(duration: duration); }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    super.dispose();
  }
}
