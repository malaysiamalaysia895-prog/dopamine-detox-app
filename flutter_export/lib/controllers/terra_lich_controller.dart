// ============================================================
// terra_lich_controller.dart  —  Terra-Lich Mech Boss
// Level 42  ·  "Terraforming"
// Dark Metal body + Red / Orange energy
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

// ── Boss phases ───────────────────────────────────────────────────────────────

enum TerraLichPhase {
  idle,
  entry,       // mechanical descent from top (2.5 s)
  active,      // hovering above grid — idle anims + attack cycle
  chargingUp,  // attack charge phase (1.5 s) — arms raise, chest opens
  striking,    // EMP beam fires (0.8 s) — game logic callback called
  winBlast,    // player meets win condition → spectacular explosion (3.2 s)
}

// ── Idle animation variants (shown every 5–10 s while active) ─────────────────

enum TerraLichIdleAnim {
  none,
  energyPulse,    // green light flows through body pipes from head to hands
  mechanicalFlex, // shoulders jerk up, body leans forward, extra exhaust burst
  scannerSweep,   // neck rotates, eye laser sweeps grid left→right
}

// Level where Terra-Lich appears
const Set<int> kTerraLichLevelSet = {42};

// ── Controller ────────────────────────────────────────────────────────────────

class TerraLichController extends ChangeNotifier with WidgetsBindingObserver {

  // ── Public state (read by overlay + provider) ──────────────────────────────
  TerraLichPhase     phase       = TerraLichPhase.idle;
  TerraLichIdleAnim  idleAnim    = TerraLichIdleAnim.none;
  int                currentLevel = 0;
  int                attackCount  = 0;
  bool               permanentlyDefeated = false;

  // ── Private ────────────────────────────────────────────────────────────────
  bool          _appFg = true;
  VoidCallback? _onAttack;

  Timer?        _entryTimer;
  Timer?        _idleAnimTimer;
  Timer?        _attackTimer;
  Timer?        _idleResetTimer;
  final Random  _rng = Random();

  TerraLichController() {
    WidgetsBinding.instance.addObserver(this);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appFg = state == AppLifecycleState.resumed;
    if (!_appFg) {
      _idleAnimTimer?.cancel();
      _attackTimer?.cancel();
    }
  }

  // ── Convenience getters ───────────────────────────────────────────────────

  bool get isIdle     => phase == TerraLichPhase.idle;
  bool get isAttacking =>
      phase == TerraLichPhase.chargingUp || phase == TerraLichPhase.striking;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Call from GameNotifier.dismissStory().
  /// [onAttack] fires when the boss executes its EMP strike.
  void triggerForLevel(int level, {required VoidCallback onAttack}) {
    if (permanentlyDefeated) return;
    if (!kTerraLichLevelSet.contains(level)) { _goIdle(); return; }

    _cancelTimers();
    currentLevel = level;
    attackCount  = 0;
    idleAnim     = TerraLichIdleAnim.none;
    _onAttack    = onAttack;

    _hapticBurst();

    phase = TerraLichPhase.entry;
    notifyListeners();

    // Mechanical descent: 2.5 s
    _entryTimer = Timer(const Duration(milliseconds: 3800), _beginActive);
  }

  /// Called when the player meets the level win condition.
  void onLevelComplete() {
    if (phase == TerraLichPhase.idle || phase == TerraLichPhase.winBlast) return;
    _cancelTimers();
    phase = TerraLichPhase.winBlast;
    permanentlyDefeated = true;
    notifyListeners();

    _safeVibrate(pattern: [0, 200, 60, 300, 60, 450, 60, 800]);

    // Auto-idle after win blast
    _entryTimer = Timer(const Duration(milliseconds: 3200), _goIdle);
  }

  /// Reset to idle without the win blast (level restart / nav away).
  void reset() {
    _cancelTimers();
    _goIdle();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _beginActive() {
    if (phase == TerraLichPhase.entry) {
      phase = TerraLichPhase.active;
      notifyListeners();
      _scheduleNextIdleAnim();
      _scheduleNextAttack();
    }
  }

  void _scheduleNextIdleAnim() {
    final delayMs = 5000 + _rng.nextInt(5000); // 5–10 s
    _idleAnimTimer = Timer(Duration(milliseconds: delayMs), () {
      if (phase != TerraLichPhase.active) return;

      final variants = [
        TerraLichIdleAnim.energyPulse,
        TerraLichIdleAnim.mechanicalFlex,
        TerraLichIdleAnim.scannerSweep,
      ];
      idleAnim = variants[_rng.nextInt(variants.length)];
      notifyListeners();

      // Auto-reset after animation duration (1.8 s)
      _idleResetTimer = Timer(const Duration(milliseconds: 1800), () {
        if (phase == TerraLichPhase.active) {
          idleAnim = TerraLichIdleAnim.none;
          notifyListeners();
          _scheduleNextIdleAnim();
        }
      });
    });
  }

  void _scheduleNextAttack() {
    final delayMs = 10000 + _rng.nextInt(6000); // 10–16 s between attacks
    _attackTimer = Timer(Duration(milliseconds: delayMs), _doAttack);
  }

  void _doAttack() {
    if (phase != TerraLichPhase.active) return;

    // Cancel any running idle anim
    _idleAnimTimer?.cancel();
    _idleResetTimer?.cancel();
    idleAnim = TerraLichIdleAnim.none;

    // Phase 1 — Charge Up (1.5 s)
    phase = TerraLichPhase.chargingUp;
    notifyListeners();
    _safeVibrate(pattern: [0, 80, 40, 80, 40, 80]);

    _entryTimer = Timer(const Duration(milliseconds: 1500), () {
      if (phase != TerraLichPhase.chargingUp) return;

      // Phase 2 — Strike (0.8 s)
      phase = TerraLichPhase.striking;
      attackCount++;
      notifyListeners();
      _safeVibrate(pattern: [0, 300, 60, 500]);

      // Fire the game-logic callback
      _onAttack?.call();

      // Return to active after strike
      _entryTimer = Timer(const Duration(milliseconds: 800), () {
        if (phase == TerraLichPhase.striking) {
          phase = TerraLichPhase.active;
          notifyListeners();
          _scheduleNextIdleAnim();
          _scheduleNextAttack();
        }
      });
    });
  }

  void _cancelTimers() {
    _entryTimer?.cancel();
    _idleAnimTimer?.cancel();
    _attackTimer?.cancel();
    _idleResetTimer?.cancel();
    _entryTimer = _idleAnimTimer = _attackTimer = _idleResetTimer = null;
  }

  void _goIdle() {
    phase        = TerraLichPhase.idle;
    idleAnim     = TerraLichIdleAnim.none;
    currentLevel = 0;
    attackCount  = 0;
    _onAttack    = null;
    notifyListeners();
  }

  void _hapticBurst() {
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    Future.delayed(const Duration(milliseconds: 130), () {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    });
    Future.delayed(const Duration(milliseconds: 310), () {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    });
  }

  Future<void> _safeVibrate({List<int>? pattern, int duration = 250}) async {
    if (!_appFg) return;
    try {
      if (pattern != null) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    super.dispose();
  }
}
