// nexus_core_controller.dart — NEXUS CORE Rogue AI Boss (Level 40)
// Hacking laser: targets grid items 1-by-1, player must merge to escape.
// Stun: deliver Space Station (id 41) → 20s freeze (EMP blast).
// Win: quota 100% → golden laser, boss destruction sequence.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_manager.dart';

enum NexusCorePhase { idle, entry, active, stunned, winBlast }

const int kNexusCoreLevel        = 40;
const int _kSpaceSatelliteId     = 41;  // Space Station → triggers EMP stun
const int _kTargetWindowSec      = 5;   // seconds player has to merge targeted item
const int _kAttackIntervalSec    = 10;  // seconds between attacks
const int _kFirstAttackDelaySec  = 5;   // seconds after entry before first attack
const int _kStunDurationSec      = 10;  // seconds boss is frozen after satellite delivery
const int _kEntryDurationMs      = 3500; // entry animation length (ms)

const List<String> _kDialogues = [
  'INITIATING HACK SEQUENCE 🤖',
  'YOUR GRID IS MY PLAYGROUND 💀',
  'RESISTANCE IS FUTILE 🔴',
  'SCANNING FOR VULNERABILITIES ⚡',
  'CORRUPTING YOUR DATA NOW 🔥',
  'YOU CANNOT ESCAPE MY LASER 😈',
  'HACKING IN PROGRESS... ☠️',
  'SYSTEMS NOMINAL. YOU ARE NOT. 🤖',
];

const List<String> kNexusHints = [
  'Merge a targeted item quickly to dodge the hack!',
  'Danger: Merging hacked items drains 15 Energy!',
  'Deliver Space Stations to Stun the Boss for 20s!',
];

class NexusCoreController extends ChangeNotifier {
  NexusCorePhase phase = NexusCorePhase.idle;
  bool entryComplete   = false;

  // Currently targeted cell (crosshair, 2-second warning window)
  (int, int)? targetedCell;
  int targetSecondsLeft = _kTargetWindowSec;
  bool get isTargeting  => targetedCell != null && phase == NexusCorePhase.active;

  // Permanently hacked cell positions
  final Set<(int, int)> hackedCells = {};
  bool isHackedAt(int col, int row) => hackedCells.contains((col, row));

  // Stun
  bool isStunned       = false;
  int  stunSecondsLeft = 0;

  // HUD: hint rotation
  int hintIndex = 0;

  // Boss dialogue bubble
  String? dialogueText;

  // Next attack countdown (displayed in overlay)
  int attackSecondsLeft = _kAttackIntervalSec;

  // Pre-attack laser charging state (overlay shows eye charge-up when true)
  bool isLaserCharging = false;

  // Win flash flag (overlay reads this once)
  bool winFlashReady = false;

  // Callbacks wired by game_provider
  void Function(int col, int row)?   onCellHacked;    // item at pos becomes hacked
  void Function(int energy)?         onPlayerPenalty;  // hacked-merge penalty
  bool Function(int col, int row)?   isCellOccupied;  // does cell have an item?

  // Internal
  bool         _disposed  = false;
  final Random _rng       = Random();
  int          _gridCols  = 6;
  int          _gridRows  = 5;

  Timer? _entryTimer;
  Timer? _attackLoopTimer;
  Timer? _targetCountdownTimer;
  Timer? _stunCountdownTimer;
  Timer? _hintTimer;
  Timer? _dialogueTimer;
  Timer? _attackCountdownTickTimer;
  Timer? _preChargeTimer;

  // ── Public API ──────────────────────────────────────────────────────────────

  void triggerForLevel(
    int level, {
    required void Function(int col, int row) onHacked,
    required void Function(int energy)       onPenalty,
    required bool Function(int col, int row) isOccupied,
    required int gridCols,
    required int gridRows,
  }) {
    if (level != kNexusCoreLevel) { _goIdle(); return; }
    _cancelTimers();

    phase             = NexusCorePhase.entry;
    entryComplete     = false;
    hackedCells.clear();
    targetedCell      = null;
    isStunned         = false;
    stunSecondsLeft   = 0;
    attackSecondsLeft = _kAttackIntervalSec;
    dialogueText      = null;
    hintIndex         = 0;
    winFlashReady     = false;
    _gridCols         = gridCols;
    _gridRows         = gridRows;
    onCellHacked      = onHacked;
    onPlayerPenalty   = onPenalty;
    isCellOccupied    = isOccupied;

    notifyListeners();

    // Hint rotation every 4 s
    _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_disposed) return;
      hintIndex = (hintIndex + 1) % kNexusHints.length;
      notifyListeners();
    });

    // Entry animation → switch to active → schedule first attack
    _entryTimer = Timer(const Duration(milliseconds: _kEntryDurationMs), () {
      if (_disposed) return;
      entryComplete = true;
      phase         = NexusCorePhase.active;
      notifyListeners();
      _setDialogue('NEXUS CORE ONLINE. INITIATING ATTACK PROTOCOL. 🔴');
      _scheduleAttack(delay: const Duration(seconds: _kFirstAttackDelaySec));
    });
  }

  /// Called by game_provider._mergeItems — cancels targeting if merged from/to
  /// the targeted cell, and clears hacked state from both cells.
  void onItemMerged(int fc, int fr, int tc, int tr) {
    if (targetedCell != null) {
      final t = targetedCell!;
      if ((fc == t.$1 && fr == t.$2) || (tc == t.$1 && tr == t.$2)) {
        // Player escaped the hack!
        _targetCountdownTimer?.cancel();
        _attackLoopTimer?.cancel();
        _attackCountdownTickTimer?.cancel();
        targetedCell = null;
        _setDialogue('HACK ESCAPED! RECALIBRATING... 😤');
        notifyListeners();
        _scheduleAttack(); // next attack in 10s
      }
    }
    // Item consumed by merge → remove hacked state
    hackedCells.remove((fc, fr));
    hackedCells.remove((tc, tr));
    notifyListeners();
  }

  /// Called when a cell is cleared of items by any means.
  void onCellCleared(int col, int row) {
    if (hackedCells.remove((col, row))) notifyListeners();
  }

  /// Called by _moveCell — hacked state + targeting follow the item.
  void onCellMoved(int fc, int fr, int tc, int tr) {
    bool changed = false;
    if (hackedCells.contains((fc, fr))) {
      hackedCells.remove((fc, fr));
      hackedCells.add((tc, tr));
      changed = true;
    }
    if (targetedCell == (fc, fr)) {
      targetedCell = (tc, tr);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Called by _swapCells — hacked state swaps with items.
  void onCellsSwapped(int fc, int fr, int tc, int tr) {
    final fromHacked = hackedCells.contains((fc, fr));
    final toHacked   = hackedCells.contains((tc, tr));
    if (fromHacked) { hackedCells.remove((fc, fr)); hackedCells.add((tc, tr)); }
    if (toHacked)   { hackedCells.remove((tc, tr)); hackedCells.add((fc, fr)); }
    final targeted = targetedCell;
    if (targeted == (fc, fr))      targetedCell = (tc, tr);
    else if (targeted == (tc, tr)) targetedCell = (fc, fr);
    if (fromHacked || toHacked || targeted != null) notifyListeners();
  }

  /// Space Station delivered → Blue EMP stun for 20 s.
  void onSatelliteDelivered() {
    if (phase != NexusCorePhase.active && phase != NexusCorePhase.stunned) return;
    _stun();
  }

  /// Quota 100% → boss destruction sequence.
  void onLevelComplete() {
    _cancelTimers();
    targetedCell  = null;
    isStunned     = false;
    winFlashReady = true;
    phase         = NexusCorePhase.winBlast;
    notifyListeners();
  }

  void reset() => _goIdle();

  // ── Private Attack Logic ────────────────────────────────────────────────────

  void _scheduleAttack({Duration delay = const Duration(seconds: _kAttackIntervalSec)}) {
    _attackLoopTimer?.cancel();
    _attackCountdownTickTimer?.cancel();
    _preChargeTimer?.cancel();
    isLaserCharging = false;
    attackSecondsLeft = delay.inSeconds;

    _attackCountdownTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || isStunned) return;
      attackSecondsLeft = (attackSecondsLeft - 1).clamp(0, 999);
      notifyListeners();
    });

    // Pre-charge: show eye charge-up animation 2s before attack fires
    final preChargeDelay = delay - const Duration(seconds: 2);
    if (!preChargeDelay.isNegative) {
      _preChargeTimer = Timer(preChargeDelay, () {
        if (_disposed || isStunned || phase != NexusCorePhase.active) return;
        isLaserCharging = true;
        notifyListeners();
      });
    }

    _attackLoopTimer = Timer(delay, () {
      if (_disposed || isStunned || phase != NexusCorePhase.active) return;
      _attackCountdownTickTimer?.cancel();
      isLaserCharging = false;
      _fireAttack();
    });
  }

  void _fireAttack() {
    if (_disposed || phase != NexusCorePhase.active) return;

    final candidates = <(int, int)>[];
    for (int c = 0; c < _gridCols; c++) {
      for (int r = 0; r < _gridRows; r++) {
        if (!isHackedAt(c, r) && (isCellOccupied?.call(c, r) ?? false)) {
          candidates.add((c, r));
        }
      }
    }

    if (candidates.isEmpty) {
      _scheduleAttack(delay: const Duration(seconds: 5));
      return;
    }

    final target      = candidates[_rng.nextInt(candidates.length)];
    targetedCell      = target;
    targetSecondsLeft = _kTargetWindowSec;

    _setDialogue(_kDialogues[_rng.nextInt(_kDialogues.length)]);
    try { HapticFeedback.mediumImpact(); } catch (_) {}
    notifyListeners();

    _targetCountdownTimer?.cancel();
    _targetCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) return;
      targetSecondsLeft = (targetSecondsLeft - 1).clamp(0, _kTargetWindowSec);
      notifyListeners();
      if (targetSecondsLeft <= 0) {
        t.cancel();
        _hackLand();
      }
    });
  }

  void _hackLand() {
    final cell = targetedCell;
    if (cell == null) return;
    targetedCell = null;

    if (isCellOccupied?.call(cell.$1, cell.$2) ?? false) {
      hackedCells.add(cell);
      onCellHacked?.call(cell.$1, cell.$2);
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    }
    notifyListeners();
    _scheduleAttack();
  }

  void _stun() {
    _attackLoopTimer?.cancel();
    _attackCountdownTickTimer?.cancel();
    _targetCountdownTimer?.cancel();
    _preChargeTimer?.cancel();
    isLaserCharging = false;
    targetedCell = null;

    isStunned       = true;
    stunSecondsLeft = _kStunDurationSec;
    phase           = NexusCorePhase.stunned;
    _setDialogue('SYSTEMS OFFLINE... REBOOTING 💀');
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    _safeVibrate(pattern: [0, 100, 80, 200, 80, 400]);
    notifyListeners();

    _stunCountdownTimer?.cancel();
    _stunCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) return;
      stunSecondsLeft = (stunSecondsLeft - 1).clamp(0, _kStunDurationSec);
      notifyListeners();
      if (stunSecondsLeft <= 0) {
        t.cancel();
        _recover();
      }
    });
  }

  void _recover() {
    if (_disposed) return;
    isStunned = false;
    phase     = NexusCorePhase.active;
    _setDialogue('REBOOTED. MAXIMUM DISRUPTION MODE ACTIVATED! 🔴');
    notifyListeners();
    _scheduleAttack();
  }

  void _setDialogue(String text) {
    dialogueText = text;
    notifyListeners();
    _dialogueTimer?.cancel();
    _dialogueTimer = Timer(const Duration(milliseconds: 2800), () {
      if (_disposed) return;
      dialogueText = null;
      notifyListeners();
    });
  }

  void _goIdle() {
    _cancelTimers();
    phase           = NexusCorePhase.idle;
    entryComplete   = false;
    hackedCells.clear();
    targetedCell    = null;
    isStunned       = false;
    isLaserCharging = false;
    dialogueText    = null;
    winFlashReady   = false;
    notifyListeners();
  }

  void _cancelTimers() {
    _entryTimer?.cancel();
    _attackLoopTimer?.cancel();
    _targetCountdownTimer?.cancel();
    _stunCountdownTimer?.cancel();
    _hintTimer?.cancel();
    _dialogueTimer?.cancel();
    _attackCountdownTickTimer?.cancel();
    _preChargeTimer?.cancel();
    _entryTimer = _attackLoopTimer = _targetCountdownTimer =
        _stunCountdownTimer = _hintTimer = _dialogueTimer =
        _attackCountdownTickTimer = _preChargeTimer = null;
  }

  Future<void> _safeVibrate({List<int>? pattern, int duration = 300}) async {
    try {
      final has = await Vibration.hasVibrator() ?? false;
      if (!has) return;
      if (pattern != null) await Vibration.vibrate(pattern: pattern);
      else await Vibration.vibrate(duration: duration);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    super.dispose();
  }
}
