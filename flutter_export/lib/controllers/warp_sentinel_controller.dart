// warp_sentinel_controller.dart — WARP SENTINEL Boss (Level 41) v2
// Full attack cycle: cooldown → warning(3s,3x3 glow) → pull(5s,proximity)
// Teleport: arm→wireframe→suck→exit→solidify
// Sacrifice: drag high-level item onto black hole to overload it
// Gravitational drag: energy cost to move heavy items out of pull zone

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_manager.dart';

enum WarpSentinelPhase  { idle, glitch, entry, active, stunned, winBlast }
enum WarpSiphonPhase    { inactive, warning, pull }
enum WarpTeleportPhase  { idle, arming, dissolving, materializing }

const int kWarpSentinelLevel     = 41;
const int _kWarpEngineId         = 42;   // Warp Engine → stun
const int _kCooldownMin          = 15;
const int _kCooldownMax          = 20;
const int _kWarningSec           = 3;    // warning glow before pull
const int _kPullSec              = 5;    // active pull phase
const int _kPullTickMs           = 1500; // proximity pull every 1.5s
const int _kStunDurationSec      = 20;
const int _kTeleportIntervalSec  = 15;
const int _kFirstAttackDelaySec  = 6;
const int _kGlitchDurationMs     = 2000;
const int _kEntryDurationMs      = 3200;
// Sacrifice: item must be this many tiers above spawner to satisfy the hole
const int _kSacrificeMinOffset   = 2;
// Gravitational drag: item this many tiers above spawner costs extra energy
const int _kDragMinOffset        = 2;
const int _kDragEnergyCost       = 4;   // energy deducted per heavy item move

const List<String> kWarpHints = [
  'Drag a high-tier item onto the black hole to overload it! 🌀',
  'Only Level 3+ items satisfy the black hole — cheap items feed it! ⚡',
  'Deliver Warp Engines to stun the Sentinel for 20s! 🚀',
  'Heavy items cost energy to drag from the pull zone — plan ahead! 🏋️',
];

const List<String> _kDialogues = [
  'WARP SIPHON INITIATED. YOUR ITEMS ARE MINE! 🌀',
  'GRAVITATIONAL PULL ENGAGED! ⚡',
  'REALITY BENDS TO MY WILL! ⚡',
  'YOU CANNOT OUTRUN A WARP SENTINEL! 🚀',
  'MASS ACQUIRED. CHARGING FOR NEXT BREACH. 💀',
  'PORTAL DESTABILISED. PHASE TWO INITIATED. 🔮',
];

class WarpSentinelController extends ChangeNotifier {
  // ── Top-level phase ────────────────────────────────────────────────────────
  WarpSentinelPhase  phase         = WarpSentinelPhase.idle;
  bool               entryComplete = false;
  bool               glitchActive  = false;

  // ── Siphon sub-phase ───────────────────────────────────────────────────────
  WarpSiphonPhase siphonPhase    = WarpSiphonPhase.inactive;
  Set<(int, int)> pullZoneCells  = {};   // 3×3 around boss hole during attack
  int             warningSecsLeft = _kWarningSec;
  int             pullSecsLeft    = _kPullSec;
  bool get isWarning => siphonPhase == WarpSiphonPhase.warning;
  bool get isPulling => siphonPhase == WarpSiphonPhase.pull;

  // ── Teleport phase ─────────────────────────────────────────────────────────
  WarpTeleportPhase teleportPhase = WarpTeleportPhase.idle;
  int               fromHoleIndex = 0;
  int               toHoleIndex   = 1;
  bool get isTeleporting => teleportPhase != WarpTeleportPhase.idle;

  // ── Black holes ────────────────────────────────────────────────────────────
  List<(int, int)> blackHoles   = [];
  int              bossHoleIndex = 0;

  // ── Attack pose (boss raises arms before attack) ───────────────────────────
  bool isAttackPoseActive = false;

  // ── Stun ───────────────────────────────────────────────────────────────────
  bool isStunned    = false;
  int  stunSecsLeft = 0;

  // ── HUD ────────────────────────────────────────────────────────────────────
  int     hintIndex      = 0;
  String? dialogueText;
  int     cooldownSecsLeft = _kCooldownMin;
  bool    winFlashReady    = false;

  // ── Overload flash (black hole was fed) ───────────────────────────────────
  bool overloadFlash = false;

  // ── Callbacks ──────────────────────────────────────────────────────────────
  void Function(int col, int row)? onCellSiphoned;
  void Function(int energy)?       onPlayerPenalty;
  bool Function(int col, int row)? isCellOccupied;

  bool         _disposed    = false;
  final Random _rng         = Random();
  int          _gridCols    = 6;
  int          _gridRows    = 5;
  int          _spawnerItemId = 39; // updated at triggerForLevel

  Timer? _glitchTimer;
  Timer? _entryTimer;
  Timer? _cooldownLoopTimer;
  Timer? _cooldownTickTimer;
  Timer? _warningCountdownTimer;
  Timer? _pullCountdownTimer;
  Timer? _pullTickTimer;
  Timer? _stunCountdownTimer;
  Timer? _hintTimer;
  Timer? _dialogueTimer;
  Timer? _teleportTimer;
  Timer? _attackPoseTimer;

  // ── Public API ──────────────────────────────────────────────────────────────

  void triggerForLevel(
    int level, {
    required void Function(int col, int row) onSiphoned,
    required void Function(int energy)       onPenalty,
    required bool Function(int col, int row) isOccupied,
    required int  gridCols,
    required int  gridRows,
    required int  spawnerItemId,
    required List<(int, int)> blackHolePositions, // actual cells from level config
  }) {
    if (level != kWarpSentinelLevel) { _goIdle(); return; }
    _cancelTimers();

    phase            = WarpSentinelPhase.glitch;
    entryComplete    = false;
    glitchActive     = true;
    siphonPhase      = WarpSiphonPhase.inactive;
    teleportPhase    = WarpTeleportPhase.idle;
    isAttackPoseActive = false;
    blackHoles       = [];
    bossHoleIndex    = 0;
    pullZoneCells.clear();
    isStunned        = false;
    stunSecsLeft     = 0;
    dialogueText     = null;
    hintIndex        = 0;
    winFlashReady    = false;
    overloadFlash    = false;
    cooldownSecsLeft = _kFirstAttackDelaySec;
    _gridCols        = gridCols;
    _gridRows        = gridRows;
    _spawnerItemId   = spawnerItemId;
    onCellSiphoned   = onSiphoned;
    onPlayerPenalty  = onPenalty;
    isCellOccupied   = isOccupied;

    notifyListeners();

    // Phase 1: 2s screen glitch
    _glitchTimer = Timer(const Duration(milliseconds: _kGlitchDurationMs), () {
      if (_disposed) return;
      glitchActive  = false;
      phase         = WarpSentinelPhase.entry;
      // Use actual grid black hole positions (no random picking)
      blackHoles    = List.of(blackHolePositions);
      if (blackHoles.isEmpty) blackHoles = [(gridCols ~/ 2, 1)]; // fallback
      bossHoleIndex = blackHoles.length > 1 ? _rng.nextInt(2) : 0;
      notifyListeners();

      // Phase 2: entry animation 3.2s
      _entryTimer = Timer(const Duration(milliseconds: _kEntryDurationMs), () {
        if (_disposed) return;
        entryComplete = true;
        phase         = WarpSentinelPhase.active;
        notifyListeners();
        _setDialogue('WARP SENTINEL ONLINE. REALITY DISTORTION ACTIVE. ⚡');
        _startHints();
        _scheduleCooldown(delay: const Duration(seconds: _kFirstAttackDelaySec));
        _scheduleTeleport();
      });
    });
  }

  // ── Merge: cancel siphon if merged item was in pull zone ──────────────────

  void onItemMerged(int fc, int fr, int tc, int tr) {
    if (siphonPhase == WarpSiphonPhase.warning || siphonPhase == WarpSiphonPhase.pull) {
      if (pullZoneCells.contains((fc, fr)) || pullZoneCells.contains((tc, tr))) {
        _setDialogue('MASS ESCAPED THE FIELD! RECALIBRATING... 😤');
        try { HapticFeedback.lightImpact(); } catch (_) {}
      }
    }
    notifyListeners();
  }

  void onCellCleared(int col, int row) {
    pullZoneCells.remove((col, row));
    notifyListeners();
  }

  void onCellMoved(int fc, int fr, int tc, int tr) {
    // Pull zone follows items only during warning — during pull the zone is fixed
    if (siphonPhase == WarpSiphonPhase.warning) {
      if (pullZoneCells.contains((fc, fr))) {
        pullZoneCells.remove((fc, fr));
        pullZoneCells.add((tc, tr));
        notifyListeners();
      }
    }
  }

  void onCellsSwapped(int fc, int fr, int tc, int tr) {
    if (siphonPhase == WarpSiphonPhase.warning) {
      final fa = pullZoneCells.contains((fc, fr));
      final ta = pullZoneCells.contains((tc, tr));
      if (fa) { pullZoneCells.remove((fc, fr)); pullZoneCells.add((tc, tr)); }
      if (ta) { pullZoneCells.remove((tc, tr)); pullZoneCells.add((fc, fr)); }
      if (fa || ta) notifyListeners();
    }
  }

  /// Player drags item onto a black hole cell — sacrifice / feed mechanic.
  /// Returns true if the item was accepted (regardless of overload).
  bool onItemSacrificed(int itemId) {
    // Cheap items just get consumed — black hole is not satisfied
    if (itemId < _spawnerItemId + _kSacrificeMinOffset) {
      _setDialogue('BLACK HOLE HUNGERS FOR MORE... CHEAP ITEMS INSUFFICIENT! 🌀');
      AudioManager.instance.playErrorBuzz();
      notifyListeners();
      return true; // item is consumed but no overload
    }
    // High-level item → overload!
    _cancelAttackPhase();
    overloadFlash    = true;
    siphonPhase      = WarpSiphonPhase.inactive;
    pullZoneCells.clear();
    isAttackPoseActive = false;
    _setDialogue('BLACK HOLE OVERLOADED! VORTEX COLLAPSING! 💥');
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    _safeVibrate(pattern: [0, 80, 60, 150, 60, 300]);
    notifyListeners();

    // Clear overload flash after 800ms, then schedule next cooldown
    Timer(const Duration(milliseconds: 800), () {
      if (_disposed) return;
      overloadFlash = false;
      notifyListeners();
      _scheduleCooldown();
    });
    return true;
  }

  /// Returns energy cost for moving an item from (col,row).
  /// Heavy items (≥ spawnerItemId + _kDragMinOffset) in the pull zone cost energy.
  int getDragEnergyCost(int col, int row, int itemId) {
    if (siphonPhase != WarpSiphonPhase.pull) return 0;
    if (!pullZoneCells.contains((col, row))) return 0;
    if (itemId < _spawnerItemId + _kDragMinOffset) return 0;
    return _kDragEnergyCost;
  }

  /// Warp Engine (id 42) delivered → stun.
  void onWarpEngineDelivered() {
    if (phase != WarpSentinelPhase.active && phase != WarpSentinelPhase.stunned) return;
    _stun();
  }

  void onLevelComplete() {
    _cancelTimers();
    pullZoneCells.clear();
    siphonPhase      = WarpSiphonPhase.inactive;
    isAttackPoseActive = false;
    isStunned        = false;
    winFlashReady    = true;
    phase            = WarpSentinelPhase.winBlast;
    notifyListeners();
  }

  void reset() => _goIdle();

  // ── Attack cycle ────────────────────────────────────────────────────────────

  void _scheduleCooldown({Duration? delay}) {
    _cancelAttackPhase();
    final sec = delay?.inSeconds ??
        (_kCooldownMin + _rng.nextInt(_kCooldownMax - _kCooldownMin + 1));
    cooldownSecsLeft = sec;

    _cooldownTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || isStunned) return;
      cooldownSecsLeft = (cooldownSecsLeft - 1).clamp(0, 999);
      notifyListeners();
    });

    _cooldownLoopTimer = Timer(Duration(seconds: sec), () {
      if (_disposed || isStunned || phase != WarpSentinelPhase.active) return;
      _cooldownTickTimer?.cancel();
      _startAttackPose();
    });
  }

  // Step 1: Boss raises arms (0.5s), then transitions to warning
  void _startAttackPose() {
    if (_disposed || phase != WarpSentinelPhase.active) return;
    isAttackPoseActive = true;
    notifyListeners();

    _attackPoseTimer = Timer(const Duration(milliseconds: 600), () {
      if (_disposed) return;
      _startWarningPhase();
    });
  }

  // Step 2: 3×3 warning glow for 3 seconds
  void _startWarningPhase() {
    if (_disposed || phase != WarpSentinelPhase.active) return;
    final hole = blackHoles.isNotEmpty ? blackHoles[bossHoleIndex] : null;
    if (hole == null) { _scheduleCooldown(); return; }

    siphonPhase      = WarpSiphonPhase.warning;
    pullZoneCells    = _compute3x3(hole.$1, hole.$2);
    warningSecsLeft  = _kWarningSec;

    _setDialogue('WARP SIPHON CHARGING... EVACUATE THE ZONE! 🌀');
    try { HapticFeedback.mediumImpact(); } catch (_) {}
    notifyListeners();

    _warningCountdownTimer?.cancel();
    _warningCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) return;
      warningSecsLeft = (warningSecsLeft - 1).clamp(0, _kWarningSec);
      notifyListeners();
      if (warningSecsLeft <= 0) {
        t.cancel();
        _startPullPhase();
      }
    });
  }

  // Step 3: 5-second pull phase — proximity siphon every 1.5s
  void _startPullPhase() {
    if (_disposed || phase != WarpSentinelPhase.active) return;
    siphonPhase  = WarpSiphonPhase.pull;
    pullSecsLeft = _kPullSec;
    notifyListeners();

    // Screen shake + whirring sound cue
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    AudioManager.instance.playTimeWarning(); // closest available 'whirring' SFX

    _pullTickTimer = Timer.periodic(
        const Duration(milliseconds: _kPullTickMs), (_) {
      if (_disposed) return;
      _pullNearestItem();
    });

    _pullCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) return;
      pullSecsLeft = (pullSecsLeft - 1).clamp(0, _kPullSec);
      notifyListeners();
      if (pullSecsLeft <= 0) {
        t.cancel();
        _endPullPhase();
      }
    });
  }

  // Siphon the item closest to the black hole center in the pull zone
  void _pullNearestItem() {
    if (blackHoles.isEmpty) return;
    final hole = blackHoles[bossHoleIndex];
    final hx = hole.$1.toDouble();
    final hy = hole.$2.toDouble();

    // Collect occupied pull zone cells, sort by distance to hole
    final candidates = pullZoneCells
        .where((cell) => isCellOccupied?.call(cell.$1, cell.$2) ?? false)
        .toList()
      ..sort((a, b) {
        final da = pow(a.$1 - hx, 2) + pow(a.$2 - hy, 2);
        final db = pow(b.$1 - hx, 2) + pow(b.$2 - hy, 2);
        return da.compareTo(db);
      });

    if (candidates.isEmpty) return;
    final target = candidates.first;
    onCellSiphoned?.call(target.$1, target.$2);
    pullZoneCells.remove(target);
    try { HapticFeedback.mediumImpact(); } catch (_) {}
    notifyListeners();
  }

  void _endPullPhase() {
    siphonPhase      = WarpSiphonPhase.inactive;
    isAttackPoseActive = false;
    pullZoneCells.clear();
    notifyListeners();
    _scheduleCooldown();
  }

  void _cancelAttackPhase() {
    _cooldownLoopTimer?.cancel();
    _cooldownTickTimer?.cancel();
    _warningCountdownTimer?.cancel();
    _pullCountdownTimer?.cancel();
    _pullTickTimer?.cancel();
    _attackPoseTimer?.cancel();
    _cooldownLoopTimer = _cooldownTickTimer = _warningCountdownTimer =
        _pullCountdownTimer = _pullTickTimer = _attackPoseTimer = null;
  }

  // ── Teleport ────────────────────────────────────────────────────────────────

  void _scheduleTeleport() {
    _teleportTimer?.cancel();
    _teleportTimer = Timer(const Duration(seconds: _kTeleportIntervalSec), () {
      if (_disposed || phase != WarpSentinelPhase.active || isStunned) return;
      // Only teleport if not mid-attack
      if (siphonPhase != WarpSiphonPhase.inactive) {
        _scheduleTeleport(); // retry after next interval
        return;
      }
      _doTeleport();
    });
  }

  void _doTeleport() {
    if (blackHoles.length < 2) return;
    fromHoleIndex = bossHoleIndex;
    toHoleIndex   = 1 - bossHoleIndex;

    // Phase: arm extend
    teleportPhase = WarpTeleportPhase.arming;
    notifyListeners();

    Timer(const Duration(milliseconds: 450), () {
      if (_disposed) return;
      // Phase: dissolve → suck into hole
      teleportPhase = WarpTeleportPhase.dissolving;
      notifyListeners();

      Timer(const Duration(milliseconds: 550), () {
        if (_disposed) return;
        // Switch hole
        bossHoleIndex = toHoleIndex;
        // Phase: materialise from other hole
        teleportPhase = WarpTeleportPhase.materializing;
        notifyListeners();

        Timer(const Duration(milliseconds: 500), () {
          if (_disposed) return;
          teleportPhase = WarpTeleportPhase.idle;
          notifyListeners();
          _scheduleTeleport();
        });
      });
    });
  }

  // ── Stun ────────────────────────────────────────────────────────────────────

  void _stun() {
    _cancelAttackPhase();
    _teleportTimer?.cancel();
    pullZoneCells.clear();
    siphonPhase      = WarpSiphonPhase.inactive;
    isAttackPoseActive = false;

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
    _scheduleCooldown();
    _scheduleTeleport();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Set<(int, int)> _compute3x3(int cx, int cy) {
    final cells = <(int, int)>{};
    for (int dc = -1; dc <= 1; dc++) {
      for (int dr = -1; dr <= 1; dr++) {
        final c = (cx + dc).clamp(0, _gridCols - 1);
        final r = (cy + dr).clamp(0, _gridRows - 1);
        cells.add((c, r));
      }
    }
    return cells;
  }

  List<(int, int)> _pickBlackHolePositions() {
    final half = _gridCols ~/ 2;
    final col0 = _rng.nextInt(half.clamp(1, _gridCols));
    final row0 = 1 + _rng.nextInt((_gridRows - 2).clamp(1, _gridRows - 1));
    final col1 = half + _rng.nextInt((_gridCols - half).clamp(1, _gridCols - half));
    final row1 = 1 + _rng.nextInt((_gridRows - 2).clamp(1, _gridRows - 1));
    bossHoleIndex = _rng.nextInt(2);
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
    phase            = WarpSentinelPhase.idle;
    entryComplete    = false;
    glitchActive     = false;
    siphonPhase      = WarpSiphonPhase.inactive;
    teleportPhase    = WarpTeleportPhase.idle;
    isAttackPoseActive = false;
    blackHoles       = [];
    pullZoneCells.clear();
    isStunned        = false;
    dialogueText     = null;
    winFlashReady    = false;
    overloadFlash    = false;
    notifyListeners();
  }

  void _cancelTimers() {
    _cancelAttackPhase();
    _glitchTimer?.cancel();
    _entryTimer?.cancel();
    _stunCountdownTimer?.cancel();
    _hintTimer?.cancel();
    _dialogueTimer?.cancel();
    _teleportTimer?.cancel();
    _glitchTimer = _entryTimer = _stunCountdownTimer =
        _hintTimer = _dialogueTimer = _teleportTimer = null;
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

