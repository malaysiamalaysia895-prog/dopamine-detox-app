// ============================================================
// robot_controller.dart  —  Robot Villain Boss (L13, L15, L17, L20)
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_manager.dart';

enum RobotPhase {
  idle,
  assemblyEntry,  // Parts fly in from screen edges and snap together
  active,         // Merge countdown challenge
  winDissolve,    // L13/15/17: smooth shrink-vanish
  winExplosion,   // L20: parts fly apart dramatically
  loss,
}

const Map<int, int> kRobotLevels = {13: 7, 15: 8, 17: 10, 20: 12};
const int kRobotTimerSeconds = 20;
const int kRobotAssemblyMs  = 1800; // ms for parts to fly in

class RobotController extends ChangeNotifier with WidgetsBindingObserver {

  // ── State ────────────────────────────────────────────────────────────────
  RobotPhase phase          = RobotPhase.idle;
  int        secondsLeft    = kRobotTimerSeconds;
  int        mergesDone     = 0;
  int        mergesRequired = 0;
  int        currentLevel   = 0;
  bool       permanentlyDestroyed = false;
  bool       _appInForeground = true;

  // ── Timers ───────────────────────────────────────────────────────────────
  Timer?        _countdown;
  Timer?        _postAnim;
  Timer?        _vibrationTimer;
  VoidCallback? _clearGridCallback;

  RobotController() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (!_appInForeground) {
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      try { Vibration.cancel(); } catch (_) {}
    }
  }

  // ── Computed ─────────────────────────────────────────────────────────────
  bool   get isIdle      => phase == RobotPhase.idle;
  bool   get isActive    => phase != RobotPhase.idle;
  bool   get isFinalBoss => currentLevel == 20;
  double get mergeProgress =>
      mergesRequired == 0 ? 0.0 : (mergesDone / mergesRequired).clamp(0.0, 1.0);

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  void triggerForLevel(int level, {required VoidCallback onClearGrid}) {
    if (permanentlyDestroyed) return;
    final required = kRobotLevels[level];
    if (required == null) { _goIdle(); return; }

    _cancelTimers();
    currentLevel       = level;
    mergesRequired     = required;
    mergesDone         = 0;
    secondsLeft        = kRobotTimerSeconds;
    _clearGridCallback = onClearGrid;

    // Mechanical entry impact
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    _safeVibrate(pattern: [0, 180, 60, 180, 60, 400]);
    AudioManager.instance.playRobotBgm().catchError((_) {});

    phase = RobotPhase.assemblyEntry;
    notifyListeners();

    // Parts assemble → then start countdown
    _postAnim = Timer(const Duration(milliseconds: kRobotAssemblyMs + 400), () {
      phase = RobotPhase.active;
      _startCountdown();
      notifyListeners();
    });
  }

  void onItemMerged() {
    if (phase != RobotPhase.active) return;
    mergesDone++;
    if (mergesDone >= mergesRequired) { _handleWin(); return; }
    notifyListeners();
  }

  void reset() { _cancelTimers(); _goIdle(); }

  // ─────────────────────────────────────────────────────────────────────────
  // Private
  // ─────────────────────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (phase != RobotPhase.active) { _countdown?.cancel(); return; }
      secondsLeft--;
      notifyListeners();
      if (secondsLeft <= 0) { _countdown?.cancel(); _handleLoss(); }
    });
    // Mechanical pulse every 2s during active phase
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (phase != RobotPhase.active) { _vibrationTimer?.cancel(); return; }
      _safeVibrate(pattern: [0, 50, 30, 50]);
    });
  }

  void _handleWin() {
    _cancelTimers();
    AudioManager.instance.resumePreRobotBgm();
    if (isFinalBoss) {
      _safeVibrate(pattern: [0, 250, 80, 250, 80, 500, 80, 700]);
      phase = RobotPhase.winExplosion;
    } else {
      _safeVibrate(pattern: [0, 120, 60, 280]);
      phase = RobotPhase.winDissolve;
    }
    notifyListeners();
    _postAnim = Timer(
      isFinalBoss ? const Duration(milliseconds: 2400) : const Duration(milliseconds: 1400),
      () { if (isFinalBoss) permanentlyDestroyed = true; _goIdle(); },
    );
  }

  void _handleLoss() {
    _cancelTimers();
    AudioManager.instance.resumePreRobotBgm();
    phase = RobotPhase.loss;
    notifyListeners();
    _clearGridCallback?.call();
    _postAnim = Timer(const Duration(milliseconds: 2400), _goIdle);
  }

  void _goIdle() {
    phase             = RobotPhase.idle;
    mergesDone        = 0;
    mergesRequired    = 0;
    secondsLeft       = kRobotTimerSeconds;
    currentLevel      = 0;
    _clearGridCallback = null;
    notifyListeners();
  }

  void _cancelTimers() {
    _countdown?.cancel();
    _postAnim?.cancel();
    _vibrationTimer?.cancel();
    _countdown = _postAnim = _vibrationTimer = null;
  }

  void _safeVibrate({List<int>? pattern, int duration = 400}) {
    if (!_appInForeground) return;
    try {
      if (pattern != null) { Vibration.vibrate(pattern: pattern); }
      else                  { Vibration.vibrate(duration: duration); }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    super.dispose();
  }
}
