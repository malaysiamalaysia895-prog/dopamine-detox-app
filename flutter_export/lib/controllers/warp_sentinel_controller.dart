// warp_sentinel_controller.dart — WARP SENTINEL Boss (Level 41)
// Warp Siphon: black hole sucks nearby items — merge to escape.
// Time Lock: laser freezes a 2×2 grid area.
// Stun: deliver Warp Engine (id 42) → 20s freeze.
// Portal Hopping: boss teleports between 2 black holes.

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_manager.dart';

enum WarpSentinelPhase { idle, glitch, entry, active, stunned, winBlast }
enum WarpAttackType   { warpSiphon, timeLock }

const int kWarpSentinelLevel      = 41;
const int _kWarpEngineId          = 42;   // Warp Engine → triggers stun
const int _kSiphonWarningSec      = 3;    // seconds player has to merge before siphon hits
const int _kTimeLockWarningSec    = 3;    // warning glow before Time Lock activates
const int _kTimeLockDurationSec   = 12;   // locked tiles duration
const int _kStunDurationSec       = 20;
const int _kTeleportIntervalSec   = 15;   // boss jumps between black holes
const int _kAttackIntervalMin     = 15;
const int _kAttackIntervalMax     = 20;
const int _kFirstAttackDelaySec   = 6;
const int _kGlitchDurationMs      = 2000;
const int _kEntryDurationMs       = 3200;

const List<String> kWarpHints = [
  'Merge siphoned items before they vanish into the void! 🌀',
  'Block the siphon with cheap items near the black holes!',
  'Deliver Warp Engines to stun the Sentinel for 20s! 🚀',
  'Time Lock zones glow purple before locking — move fast! ⏱️',
];

const List<String> _kDialogues = [
  'WARP SIPHON CHARGING... YOUR ITEMS ARE MINE! 🌀',
  'TIME LOCK DEPLOYED. ESCAPE IS FUTILE. ⏱️',
  'REALITY BENDS TO MY WILL! ⚡',
  'YOU CANNOT OUTRUN A WARP SENTINEL! 🚀',
  'TELEPORTING... YOUR DEFENSES ARE MEANINGLESS. 🔮',
  'PORTAL DESTABILISED. PHASE TWO INITIATED. 💀',
];

class WarpSentinelController extends ChangeNotifier {
  WarpSentinelPhase phase = WarpSentinelPhase.idle;
  bool  entryComplete    = false;
  bool  glitchActive     = false;
  bool  isTeleporting    = false;

  // Black hole grid positions (set during entry)
  List<(int, int)> blackHoles   = [];
  int              bossHoleIndex = 0;   // which hole the boss is currently "at"

  // Current attack
  WarpAttackType?  currentAttack;
  bool get isAttacking => currentAttack != null;

  // Siphon state
  Set<(int, int)> siphonedCells  = {};
  int             siphonSecsLeft = _kSiphonWarningSec;

  // Time Lock state
  Set<(int, int)> timeLockCells  = {};

  // Pre-attack warning glow (shared by both attacks)
  Set<(int, int)> warningCells   = {};

  // Stun
  bool isStunned      = false;
  int  stunSecsLeft   = 0;

  // HUD
  int     hintIndex         = 0;
  String? dialogueText;
  int     attackSecsLeft    = _kAttackIntervalMin;
  bool    winFlashReady     = false;

  // Callbacks
  void Function(int col, int row)? onCellLocked;
  void Function(int col, int row)? onCellUnlocked;
  void Function(int col, int row)? onCellSiphoned;   // item consumed
  void Function(int energy)?       onPlayerPenalty;
  bool Function(int col, int row)? isCellOccupied;
  bool Function(int col, int row)? isCellBlocked;

  bool         _disposed = false;
  final Random _rng      = Random();
  int          _gridCols = 6;
  int          _gridRows = 5;

  Timer? _glitchTimer;
  Timer? _entryTimer;
  Timer? _attackLoopTimer;
  Timer? _attackCountdownTimer;
  Timer? _warningTimer;
  Timer? _siphonCountdownTimer;
  Timer? _timeLockUnlockTimer;
  Timer? _stunCountdownTimer;
  Timer? _hintTimer;
  Timer? _dialogueTimer;
  Timer? _teleportTimer;

  // ── Public API ──────────────────────────────────────────────────────────────

  void triggerForLevel(
    int level, {
    required void Function(int col, int row) onLocked,
    required void Function(int col, int row) onUnlocked,
    required void Function(int col, int row) onSiphoned,
    required void Function(int energy)       onPenalty,
    required bool Function(int col, int row) isOccupied,
    required bool Function(int col, int row) isBlocked,
    required int  gridCols,
    required int  gridRows,
  }) {
    if (level != kWarpSentinelLevel) { _goIdle(); return; }
    _cancelTimers();

    phase           = WarpSentinelPhase.glitch;
    entryComplete   = false;
    glitchActive    = true;
    isTeleporting   = false;
    blackHoles      = [];
    bossHoleIndex   = 0;
    siphonedCells.clear();
    timeLockCells.clear();
    warningCells.clear();
    currentAttack   = null;
    isStunned       = false;
    stunSecsLeft    = 0;
    dialogueText    = null;
    hintIndex       = 0;
    winFlashReady   = false;
    attackSecsLeft  = _kFirstAttackDelaySec;
    _gridCols       = gridCols;
    _gridRows       = gridRows;
    onCellLocked    = onLocked;
    onCellUnlocked  = onUnlocked;
    onCellSiphoned  = onSiphoned;
    onPlayerPenalty = onPenalty;
    isCellOccupied  = isOccupied;
    isCellBlocked   = isBlocked;

    notifyListeners();

    // Phase 1: 2s screen glitch
    _glitchTimer = Timer(const Duration(milliseconds: _kGlitchDurationMs), () {
      if (_disposed) return;
      glitchActive  = false;
      phase         = WarpSentinelPhase.entry;
      blackHoles    = _pickBlackHolePositions();
      notifyListeners();

      // Phase 2: black holes expand, boss emerges (3.2s)
      _entryTimer = Timer(const Duration(milliseconds: _kEntryDurationMs), () {
        if (_disposed) return;
        entryComplete = true;
        phase         = WarpSentinelPhase.active;
        notifyListeners();
        _setDialogue('WARP SENTINEL ONLINE. REALITY DISTORTION ACTIVE. ⚡');
        _startHints();
        _scheduleAttack(delay: const Duration(seconds: _kFirstAttackDelaySec));
        _scheduleTeleport();
      });
    });
  }

  /// Merge event: cancels siphon if merged cell is one of the siphoned cells.
  void onItemMerged(int fc, int fr, int tc, int tr) {
    if (siphonedCells.contains((fc, fr)) || siphonedCells.contains((tc, tr))) {
      _siphonCountdownTimer?.cancel();
      siphonedCells.clear();
      warningCells.clear();
      currentAttack = null;
      _setDialogue('SIPHON ESCAPED! RECALIBRATING WARP FIELD... 😤');
      try { HapticFeedback.lightImpact(); } catch (_) {}
      notifyListeners();
      _scheduleAttack();
    }
    siphonedCells.remove((fc, fr));
    siphonedCells.remove((tc, tr));
    notifyListeners();
  }

  void onCellCleared(int col, int row) {
    bool changed = false;
    if (siphonedCells.remove((col, row))) changed = true;
    if (warningCells.remove((col, row)))  changed = true;
    if (changed) notifyListeners();
  }

  void onCellMoved(int fc, int fr, int tc, int tr) {
    bool changed = false;
    if (siphonedCells.contains((fc, fr))) {
      siphonedCells.remove((fc, fr)); siphonedCells.add((tc, tr)); changed = true;
    }
    if (warningCells.contains((fc, fr))) {
      warningCells.remove((fc, fr)); warningCells.add((tc, tr)); changed = true;
    }
    if (changed) notifyListeners();
  }

  void onCellsSwapped(int fc, int fr, int tc, int tr) {
    final fs = siphonedCells.contains((fc, fr));
    final ts = siphonedCells.contains((tc, tr));
    if (fs) { siphonedCells.remove((fc, fr)); siphonedCells.add((tc, tr)); }
    if (ts) { siphonedCells.remove((tc, tr)); siphonedCells.add((fc, fr)); }
    if (fs || ts) notifyListeners();
  }

  /// Warp Engine (id 42) delivered → stun boss.
  void onWarpEngineDelivered() {
    if (phase != WarpSentinelPhase.active && phase != WarpSentinelPhase.stunned) return;
    _stun();
  }

  void onLevelComplete() {
    _cancelTimers();
    siphonedCells.clear();
    timeLockCells.clear();
    warningCells.clear();
    currentAttack = null;
    isStunned     = false;
    winFlashReady = true;
    phase         = WarpSentinelPhase.winBlast;
    notifyListeners();
  }

  void reset() => _goIdle();

  // ── Attack Logic ────────────────────────────────────────────────────────────

  void _scheduleAttack({Duration? delay}) {
    _attackLoopTimer?.cancel();
    _attackCountdownTimer?.cancel();
    final sec = delay?.inSeconds ??
        (_kAttackIntervalMin + _rng.nextInt(_kAttackIntervalMax - _kAttackIntervalMin + 1));
    attackSecsLeft = sec;

    _attackCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || isStunned) return;
      attackSecsLeft = (attackSecsLeft - 1).clamp(0, 999);
      notifyListeners();
    });

    _attackLoopTimer = Timer(Duration(seconds: sec), () {
      if (_disposed || isStunned || phase != WarpSentinelPhase.active) return;
      _attackCountdownTimer?.cancel();
      _fireAttack();
    });
  }

  void _fireAttack() {
    if (_disposed || phase != WarpSentinelPhase.active) return;
    // Alternate: prefer siphon slightly more (60/40)
    if (_rng.nextInt(10) < 6) {
      _fireWarpSiphon();
    } else {
      _fireTimeLock();
    }
  }

  void _fireWarpSiphon() {
    final hole = blackHoles.isNotEmpty ? blackHoles[bossHoleIndex] : null;
    if (hole == null) { _scheduleAttack(); return; }

    // Collect occupied cells near the boss's black hole (radius 2 manhattan)
    final candidates = <(int, int)>[];
    for (int c = 0; c < _gridCols; c++) {
      for (int r = 0; r < _gridRows; r++) {
        if (isCellOccupied?.call(c, r) ?? false) {
          final dist = (c - hole.$1).abs() + (r - hole.$2).abs();
          if (dist <= 2) candidates.add((c, r));
        }
      }
    }
    // Fallback: whole grid
    if (candidates.isEmpty) {
      for (int c = 0; c < _gridCols; c++) {
        for (int r = 0; r < _gridRows; r++) {
          if (isCellOccupied?.call(c, r) ?? false) candidates.add((c, r));
        }
      }
    }
    if (candidates.isEmpty) { _scheduleAttack(); return; }

    candidates.shuffle(_rng);
    final count = candidates.length >= 2 ? 1 + _rng.nextInt(2) : 1;
    siphonedCells  = candidates.take(count).toSet();
    warningCells   = Set.from(siphonedCells);
    siphonSecsLeft = _kSiphonWarningSec;
    currentAttack  = WarpAttackType.warpSiphon;

    _setDialogue('WARP SIPHON ACTIVATED! MERGE NOW TO ESCAPE! 🌀');
    try { HapticFeedback.mediumImpact(); } catch (_) {}
    notifyListeners();

    _siphonCountdownTimer?.cancel();
    _siphonCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) return;
      siphonSecsLeft = (siphonSecsLeft - 1).clamp(0, _kSiphonWarningSec);
      notifyListeners();
      if (siphonSecsLeft <= 0) {
        t.cancel();
        _siphonLand();
      }
    });
  }

  void _siphonLand() {
    final toRemove = List<(int, int)>.from(siphonedCells);
    siphonedCells.clear();
    warningCells.clear();
    currentAttack = null;
    notifyListeners();

    for (final cell in toRemove) {
      if (isCellOccupied?.call(cell.$1, cell.$2) ?? false) {
        onCellSiphoned?.call(cell.$1, cell.$2);
        try { HapticFeedback.heavyImpact(); } catch (_) {}
      }
    }
    _scheduleAttack();
  }

  void _fireTimeLock() {
    // 3-second warning, then lock a 2×2 area
    final origins = <(int, int)>[];
    for (int c = 0; c <= _gridCols - 2; c++) {
      for (int r = 0; r <= _gridRows - 2; r++) {
        origins.add((c, r));
      }
    }
    if (origins.isEmpty) { _scheduleAttack(); return; }

    final origin = origins[_rng.nextInt(origins.length)];
    final lockSet = <(int, int)>{
      origin,
      (origin.$1 + 1, origin.$2),
      (origin.$1,     origin.$2 + 1),
      (origin.$1 + 1, origin.$2 + 1),
    };

    warningCells  = Set.from(lockSet);
    currentAttack = WarpAttackType.timeLock;
    _setDialogue('TIME LOCK INCOMING! CLEAR THE ZONE! ⏱️');
    try { HapticFeedback.mediumImpact(); } catch (_) {}
    notifyListeners();

    _warningTimer?.cancel();
    _warningTimer = Timer(const Duration(seconds: _kTimeLockWarningSec), () {
      if (_disposed || phase != WarpSentinelPhase.active) return;
      warningCells.clear();
      timeLockCells = lockSet;
      notifyListeners();

      for (final cell in lockSet) {
        onCellLocked?.call(cell.$1, cell.$2);
      }
      try { HapticFeedback.heavyImpact(); } catch (_) {}

      _timeLockUnlockTimer?.cancel();
      _timeLockUnlockTimer = Timer(
          const Duration(seconds: _kTimeLockDurationSec), () {
        if (_disposed) return;
        for (final cell in timeLockCells) {
          onCellUnlocked?.call(cell.$1, cell.$2);
        }
        timeLockCells.clear();
        currentAttack = null;
        notifyListeners();
        _scheduleAttack();
      });
    });
  }

  // ── Teleport ────────────────────────────────────────────────────────────────

  void _scheduleTeleport() {
    _teleportTimer?.cancel();
    _teleportTimer = Timer(const Duration(seconds: _kTeleportIntervalSec), () {
      if (_disposed || phase != WarpSentinelPhase.active || isStunned) return;
      _doTeleport();
    });
  }

  void _doTeleport() {
    if (blackHoles.length < 2) return;
    isTeleporting = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 700), () {
      if (_disposed) return;
      bossHoleIndex = 1 - bossHoleIndex;
      isTeleporting = false;
      notifyListeners();
      _scheduleTeleport();
    });
  }

  // ── Stun ────────────────────────────────────────────────────────────────────

  void _stun() {
    _attackLoopTimer?.cancel();
    _attackCountdownTimer?.cancel();
    _siphonCountdownTimer?.cancel();
    _warningTimer?.cancel();
    _teleportTimer?.cancel();
    siphonedCells.clear();
    warningCells.clear();
    currentAttack = null;

    isStunned    = true;
    stunSecsLeft = _kStunDurationSec;
    phase        = WarpSentinelPhase.stunned;
    _setDialogue('WARP FIELD COLLAPSED... EMERGENCY REBOOT... 💀');
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    _safeVibrate(pattern: [0, 100, 80, 200, 80, 400]);
    notifyListeners();

    _stunCountdownTimer?.cancel();
    _stunCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) return;
      stunSecsLeft = (stunSecsLeft - 1).clamp(0, _kStunDurationSec);
      notifyListeners();
      if (stunSecsLeft <= 0) {
        t.cancel();
        _recover();
      }
    });
  }

  void _recover() {
    if (_disposed) return;
    isStunned = false;
    phase     = WarpSentinelPhase.active;
    _setDialogue('WARP FIELD RESTORED. ANNIHILATION SEQUENCE RESUMED! ⚡');
    notifyListeners();
    _scheduleAttack();
    _scheduleTeleport();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  List<(int, int)> _pickBlackHolePositions() {
    // Place 2 holes spread apart (left half + right half)
    final halfCol = _gridCols ~/ 2;
    final col0 = _rng.nextInt(halfCol.clamp(1, _gridCols));
    final row0 = 1 + _rng.nextInt((_gridRows - 2).clamp(1, _gridRows - 1));
    final col1 = halfCol + _rng.nextInt((_gridCols - halfCol).clamp(1, _gridCols - halfCol));
    final row1 = 1 + _rng.nextInt((_gridRows - 2).clamp(1, _gridRows - 1));
    return [(col0, row0), (col1.clamp(0, _gridCols - 1), row1)];
  }

  void _startHints() {
    _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_disposed) return;
      hintIndex = (hintIndex + 1) % kWarpHints.length;
      notifyListeners();
    });
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
    phase         = WarpSentinelPhase.idle;
    entryComplete = false;
    glitchActive  = false;
    isTeleporting = false;
    blackHoles    = [];
    siphonedCells.clear();
    timeLockCells.clear();
    warningCells.clear();
    currentAttack = null;
    isStunned     = false;
    dialogueText  = null;
    winFlashReady = false;
    notifyListeners();
  }

  void _cancelTimers() {
    _glitchTimer?.cancel();
    _entryTimer?.cancel();
    _attackLoopTimer?.cancel();
    _attackCountdownTimer?.cancel();
    _warningTimer?.cancel();
    _siphonCountdownTimer?.cancel();
    _timeLockUnlockTimer?.cancel();
    _stunCountdownTimer?.cancel();
    _hintTimer?.cancel();
    _dialogueTimer?.cancel();
    _teleportTimer?.cancel();
    _glitchTimer = _entryTimer = _attackLoopTimer = _attackCountdownTimer =
        _warningTimer = _siphonCountdownTimer = _timeLockUnlockTimer =
        _stunCountdownTimer = _hintTimer = _dialogueTimer = _teleportTimer = null;
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
