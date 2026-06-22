// ============================================================
// alien_controller.dart — Space Alien Boss System
// Level 31 → Alien #2 (Standing), Level 32 → Alien #3 (Smiling)
// Level 33 → Alien #1 (Waving, ships explode first)
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_manager.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum AlienPhase {
  idle,
  warningEntry,   // L31 only: full-screen danger briefing (5 s)
  shipEntry,      // 4 ships fly in from edges, merge → alien materialises
  active,         // Alien active: throws meteors, takes laser damage
  laserHit,       // Laser is hitting alien (brief flash state)
  winBlast,       // Player defeated alien → spectacular explosion
  loss,           // Alien wins
}

enum AlienType {
  waving,   // Alien #1 — bottom-left waving alien (L33)
  standing, // Alien #2 — center standing alien     (L31)
  smiling,  // Alien #3 — bottom-right smiling alien (L32)
}

// ─── Meteor Throw ─────────────────────────────────────────────────────────────

class AlienMeteorThrow {
  final int col;
  final int row;
  final double id; // unique id per throw for animation key
  const AlienMeteorThrow(this.col, this.row, this.id);
}

// ─── Laser Hit Data ───────────────────────────────────────────────────────────

class AlienLaserHit {
  final int damage;
  final int mergeCount;
  final double id;
  const AlienLaserHit(this.damage, this.mergeCount, this.id);
}

// ─── Level Config ─────────────────────────────────────────────────────────────

/// Maps level number → AlienType
const Map<int, AlienType> kAlienLevels = {
  31: AlienType.standing,
  32: AlienType.smiling,
  33: AlienType.waving,
};

/// BGM asset per level
const Map<int, String> kAlienBgm = {
  31: 'assets/audio/bgm_alien2.mp3',
  32: 'assets/audio/bgm_alien3.mp3',
  33: 'assets/audio/bgm_alien1.mp3',
};

/// Merge thresholds and per-hit damage (cumulative = 100 HP total)
/// threshold → damage this laser does
const List<(int threshold, int damage)> kMergeThresholds = [
  (2,  5),
  (4,  10),
  (6,  10),
  (8,  10),
  (10, 5),
  (12, 10),
  (15, 10),
  (18, 20),
  (20, 10),
  (22, 10),
];

// ─── Controller ───────────────────────────────────────────────────────────────

class AlienController extends ChangeNotifier with WidgetsBindingObserver {

  // ── Public readable state ─────────────────────────────────────────────────
  AlienPhase phase             = AlienPhase.idle;
  AlienType  alienType         = AlienType.standing;
  int        currentLevel      = 0;
  int        alienHealth       = 100; // 0–100
  int        mergesDone        = 0;
  int        nextThresholdIdx  = 0;   // index into kMergeThresholds
  bool       permanentlyDefeated = false;

  /// Active meteor throws on the grid right now
  List<AlienMeteorThrow> activeMeteors = [];

  /// Most recent laser hit (null if none)
  AlienLaserHit? lastLaserHit;

  /// Ships animation entry: false = still flying, true = merged/done
  bool shipsEntryComplete = false;

  // ── Private ───────────────────────────────────────────────────────────────
  bool     _appFg   = true;
  bool     _disposed = false;
  final Random _rng = Random();

  Timer? _postAnim;
  Timer? _meteorTimer;
  Timer? _vibTimer;
  Timer? _laserCooldown;

  int    _gridCols = 6;
  int    _gridRows = 5;
  double _throwIdCounter = 0;

  /// Called each meteor cycle — gives (col, row) targets for cells to hit
  void Function(List<AlienMeteorThrow>)? onMeteorThrow;

  /// Called when a meteor lands on a cell — game logic destroys the item
  void Function(int col, int row)? onCellDestroyed;

  /// Called when laser fires — game subtracts from player health if alien attacks
  void Function(int damage)? onPlayerDamage;

  AlienController() {
    WidgetsBinding.instance.addObserver(this);
  }

  // ── Computed ──────────────────────────────────────────────────────────────
  bool get isIdle    => phase == AlienPhase.idle;
  bool get isActive  => phase != AlienPhase.idle;
  bool get isFinal   => currentLevel == 33;
  double get healthFraction => alienHealth / 100.0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appFg = state == AppLifecycleState.resumed;
    if (!_appFg) {
      _meteorTimer?.cancel();
      _vibTimer?.cancel();
      try { Vibration.cancel(); } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  void triggerForLevel(
    int level, {
    required int gridCols,
    required int gridRows,
    required void Function(List<AlienMeteorThrow>) onThrow,
    required void Function(int col, int row) onCellDestroy,
    required void Function(int damage) onDamage,
  }) {
    if (permanentlyDefeated) return;
    if (!kAlienLevels.containsKey(level)) { _goIdle(); return; }

    _cancelTimers();
    currentLevel      = level;
    alienType         = kAlienLevels[level]!;
    alienHealth       = 100;
    mergesDone        = 0;
    nextThresholdIdx  = 0;
    activeMeteors     = [];
    lastLaserHit      = null;
    shipsEntryComplete = false;
    _gridCols         = gridCols;
    _gridRows         = gridRows;
    onMeteorThrow     = onThrow;
    onCellDestroyed   = onCellDestroy;
    onPlayerDamage    = onDamage;

    _hapticBurst();

    // Switch to alien BGM
    final bgm = kAlienBgm[level] ?? 'assets/audio/bgm_alien2.mp3';
    AudioManager.instance.playAlienBgm(bgm).catchError((_) {});

    if (level == 31) {
      // Level 31: show warning first
      phase = AlienPhase.warningEntry;
      notifyListeners();
      _postAnim = Timer(const Duration(seconds: 5), _beginShipEntry);
    } else {
      _beginShipEntry();
    }
  }

  /// Player taps "FACE THE ALIEN" on warning screen → skip wait
  void dismissWarning() {
    if (phase != AlienPhase.warningEntry) return;
    _postAnim?.cancel();
    _beginShipEntry();
  }

  /// Called by GameNotifier after every successful merge
  void onItemMerged() {
    if (phase != AlienPhase.active) return;
    mergesDone++;
    notifyListeners();

    // Check laser threshold
    if (nextThresholdIdx < kMergeThresholds.length) {
      final (threshold, damage) = kMergeThresholds[nextThresholdIdx];
      if (mergesDone >= threshold) {
        nextThresholdIdx++;
        _fireLaser(damage);
      }
    }
  }

  /// Called when player completes level quota
  void onLevelComplete() {
    if (phase == AlienPhase.idle || phase == AlienPhase.winBlast) return;
    _cancelTimers();
    AudioManager.instance.resumePreAlienBgm();
    _safeVibrate(pattern: [0, 200, 60, 300, 60, 500, 60, 800]);
    if (isFinal) permanentlyDefeated = true;
    phase = AlienPhase.winBlast;
    activeMeteors = [];
    notifyListeners();
    _postAnim = Timer(const Duration(milliseconds: 3500), _goIdle);
  }

  void reset() {
    _cancelTimers();
    AudioManager.instance.resumePreAlienBgm();
    _goIdle();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private
  // ─────────────────────────────────────────────────────────────────────────

  void _beginShipEntry() {
    if (_disposed) return;
    phase = AlienPhase.shipEntry;
    notifyListeners();

    // Total animation: 3.8s fly-in + 0.8s hover + 1.2s merge + 0.8s alien materialise
    // Total animation: ships(3800) + hover(500) + shock+blast(2300) + reveal(2000) = ~8600ms
    // L33: ships(3800) + explode(1200) + reveal(2000) = ~7100ms
    final entryMs = currentLevel == 33 ? 7100 : 8600;
    _postAnim = Timer(Duration(milliseconds: entryMs), () {
      if (_disposed) return;
      shipsEntryComplete = true;
      phase = AlienPhase.active;
      _startMeteorCycle();
      _startVibPulse();
      notifyListeners();
    });
  }

  void _startMeteorCycle() {
    // Alien throws meteors every 2 seconds, 4-5 cells per throw
    _meteorTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (phase != AlienPhase.active || _disposed) return;
      _throwMeteors();
    });
  }

  void _throwMeteors() {
    final throwCount = 4 + _rng.nextInt(2); // 4 or 5
    final candidates = <(int, int)>[];

    for (int c = 0; c < _gridCols; c++) {
      for (int r = 0; r < _gridRows; r++) {
        candidates.add((c, r));
      }
    }
    candidates.shuffle(_rng);

    final targets = candidates.take(throwCount).map((pos) {
      _throwIdCounter += 1;
      return AlienMeteorThrow(pos.$1, pos.$2, _throwIdCounter);
    }).toList();

    activeMeteors = [...activeMeteors, ...targets];
    onMeteorThrow?.call(targets);
    _safeVibrate(pattern: [0, 40, 20, 60]);
    notifyListeners();

    // Meteor lands after 1.2 seconds → destroy cell
    for (final meteor in targets) {
      Timer(const Duration(milliseconds: 1200), () {
        if (_disposed || phase != AlienPhase.active) return;
        activeMeteors = activeMeteors
            .where((m) => m.id != meteor.id)
            .toList();
        onCellDestroyed?.call(meteor.col, meteor.row);
        notifyListeners();
      });
    }
  }

  void _fireLaser(int damage) {
    if (_disposed) return;
    _throwIdCounter += 0.5;
    lastLaserHit = AlienLaserHit(damage, mergesDone, _throwIdCounter);

    // Apply damage to alien
    alienHealth = (alienHealth - damage).clamp(0, 100);

    // Brief laser-hit flash state
    phase = AlienPhase.laserHit;
    notifyListeners();

    _safeVibrate(pattern: [0, 100, 30, 150]);

    // Return to active after flash
    _laserCooldown?.cancel();
    _laserCooldown = Timer(const Duration(milliseconds: 800), () {
      if (_disposed) return;
      if (alienHealth <= 0) {
        _handleWin();
      } else {
        phase = AlienPhase.active;
        notifyListeners();
      }
    });
  }

  void _handleWin() {
    _cancelTimers();
    AudioManager.instance.resumePreAlienBgm();
    _safeVibrate(pattern: [0, 300, 80, 300, 80, 600, 80, 1000]);
    if (isFinal) permanentlyDefeated = true;
    phase = AlienPhase.winBlast;
    activeMeteors = [];
    notifyListeners();
    _postAnim = Timer(const Duration(milliseconds: 3500), _goIdle);
  }

  void _startVibPulse() {
    _vibTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (phase != AlienPhase.active) { _vibTimer?.cancel(); return; }
      _safeVibrate(pattern: [0, 30, 20, 30]);
    });
  }

  void _hapticBurst() {
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    Future.delayed(const Duration(milliseconds: 120), () {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    });
    Future.delayed(const Duration(milliseconds: 280), () {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    });
    _safeVibrate(pattern: [0, 200, 60, 200, 60, 500]);
  }

  void _goIdle() {
    if (_disposed) return;
    phase             = AlienPhase.idle;
    currentLevel      = 0;
    alienHealth       = 100;
    mergesDone        = 0;
    nextThresholdIdx  = 0;
    activeMeteors     = [];
    lastLaserHit      = null;
    shipsEntryComplete = false;
    onMeteorThrow     = null;
    onCellDestroyed   = null;
    onPlayerDamage    = null;
    notifyListeners();
  }

  void _cancelTimers() {
    _postAnim?.cancel();
    _meteorTimer?.cancel();
    _vibTimer?.cancel();
    _laserCooldown?.cancel();
    _postAnim = _meteorTimer = _vibTimer = _laserCooldown = null;
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
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    super.dispose();
  }
}
