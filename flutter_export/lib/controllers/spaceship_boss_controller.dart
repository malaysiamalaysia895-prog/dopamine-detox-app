// spaceship_boss_controller.dart — Spaceship Alien Boss
// Level 34: 20 merges | Level 35: 25 merges + L35 obstacle cells
// Polish: Dialogue bubbles, +15 coin rewards, death slow-mo, HP pulse

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_manager.dart';

enum SpaceshipBossPhase {
  idle,
  entry,
  slowMo,
  active,
  winBlast,
}

class SpaceshipThrow {
  final int col;
  final int row;
  final int secondsLeft;
  final double id;
  const SpaceshipThrow(this.col, this.row, this.secondsLeft, this.id);
  SpaceshipThrow withSeconds(int s) => SpaceshipThrow(col, row, s, id);
}

class BlockedCell {
  final int col;
  final int row;
  final double id;
  const BlockedCell(this.col, this.row, this.id);
}

const Map<int, int> kSpaceshipBossLevels = { 34: 20, 35: 25 };

const _kSpaceshipDialogues = [
  'FOOLISH HUMAN! 👾',
  'RESISTANCE IS FUTILE! 🛸',
  'YOUR GRID IS MINE! ⚡',
  'SURRENDER NOW! 💀',
  'I WILL DESTROY YOU! 🔥',
  'PATHETIC EARTHLING! 😈',
  'YOU CANNOT STOP ME! 🚀',
  'FEEL MY POWER! ☄️',
];

const _kL35ExtraDialogues = [
  'LEVEL 35 — TRY HARDER! 😤',
  'MY SHIPS ARE UNSTOPPABLE! 🛸',
  'I BLOCK YOUR PATH! 🚫',
  'CRUMBLE BEFORE ME! 💥',
];

class SpaceshipBossController extends ChangeNotifier {

  SpaceshipBossPhase phase      = SpaceshipBossPhase.idle;
  int   currentLevel            = 0;
  int   mergesDone              = 0;
  int   mergesNeeded            = 20;
  bool  entryComplete           = false;

  String? dialogueText;
  bool    isLowHp       = false;
  bool    isSlowMo      = false;
  List<SpaceshipThrow>  activeThrows  = [];
  List<BlockedCell>     blockedCells  = [];

  void Function(List<SpaceshipThrow>)? onWaveThrow;
  void Function(int col, int row)?     onCellDestroyed;
  void Function(int damage)?           onPlayerDamage;
  void Function(int coins)?            onCoinReward;
  void Function(int col, int row)?     onCellBlocked;
  void Function(int col, int row)?     onCellUnblocked;

  bool _disposed = false;
  final Random _rng       = Random();
  double       _idCounter = 0;

  Timer? _entryTimer;
  Timer? _waveTimer;
  Timer? _countdownTimer;
  Timer? _vibTimer;
  Timer? _dialogueTimer;
  Timer? _l35ObstacleTimer;
  Timer? _slowMoTimer;

  int _gridCols = 6;
  int _gridRows = 5;

  bool   get isIdle    => phase == SpaceshipBossPhase.idle;
  bool   get isActive  => phase == SpaceshipBossPhase.active;
  double get progressFraction => mergesNeeded > 0
      ? (mergesDone / mergesNeeded).clamp(0.0, 1.0) : 0;

  void triggerForLevel(
    int level, {
    required int gridCols,
    required int gridRows,
    required void Function(List<SpaceshipThrow>) onThrow,
    required void Function(int col, int row) onCellDestroy,
    required void Function(int damage) onDamage,
    void Function(int coins)? onCoins,
    void Function(int col, int row)? onBlock,
    void Function(int col, int row)? onUnblock,
  }) {
    if (!kSpaceshipBossLevels.containsKey(level)) { _goIdle(); return; }

    _cancelTimers();
    currentLevel    = level;
    mergesNeeded    = kSpaceshipBossLevels[level]!;
    mergesDone      = 0;
    activeThrows    = [];
    blockedCells    = [];
    entryComplete   = false;
    isLowHp         = false;
    isSlowMo        = false;
    dialogueText    = null;
    _gridCols       = gridCols;
    _gridRows       = gridRows;
    onWaveThrow     = onThrow;
    onCellDestroyed = onCellDestroy;
    onPlayerDamage  = onDamage;
    onCoinReward    = onCoins;
    onCellBlocked   = onBlock;
    onCellUnblocked = onUnblock;

    _hapticBurst();
    AudioManager.instance.playAlienBgm('assets/audio/bgm_alien_boss.mp3').catchError((_) {});

    phase = SpaceshipBossPhase.entry;
    notifyListeners();

    _entryTimer = Timer(const Duration(milliseconds: 5500), () {
      if (_disposed) return;
      entryComplete = true;
      phase = SpaceshipBossPhase.active;
      _startWaveCycle();
      _startVibPulse();
      _startDialogueCycle();
      notifyListeners();
    });
  }

  void onItemMerged() {
    if (phase != SpaceshipBossPhase.active) return;
    mergesDone++;
    _updateLowHp();
    notifyListeners();
    if (mergesDone >= mergesNeeded) _handleWin();
  }

  bool neutralizeThrowAt(int col, int row) {
    final idx = activeThrows.indexWhere((t) => t.col == col && t.row == row);
    if (idx == -1) return false;
    activeThrows = List.from(activeThrows)..removeAt(idx);
    onCoinReward?.call(15);
    _safeVibrate(pattern: [0, 60, 20, 60]);
    notifyListeners();
    return true;
  }

  SpaceshipThrow? getThrowAt(int col, int row) {
    try { return activeThrows.firstWhere((t) => t.col == col && t.row == row); }
    catch (_) { return null; }
  }

  bool isCellBlocked(int col, int row) =>
      blockedCells.any((b) => b.col == col && b.row == row);

  void onLevelComplete() {
    if (phase == SpaceshipBossPhase.idle || phase == SpaceshipBossPhase.winBlast) return;
    _handleWin();
  }

  void reset() {
    _cancelTimers();
    for (final b in blockedCells) { onCellUnblocked?.call(b.col, b.row); }
    blockedCells = [];
    AudioManager.instance.resumePreAlienBgm();
    _goIdle();
  }

  void _startWaveCycle() {
    _waveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (phase != SpaceshipBossPhase.active || _disposed) return;
      _throwWave();
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      _tickCountdowns();
    });
    if (currentLevel == 35) {
      _l35ObstacleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (phase != SpaceshipBossPhase.active || _disposed) return;
        _placeL35Obstacles();
      });
    }
  }

  void _throwWave() {
    final occupied = { for (final t in activeThrows) (t.col, t.row) };
    final blocked  = { for (final b in blockedCells) (b.col, b.row) };
    final candidates = <(int, int)>[];
    for (int c = 0; c < _gridCols; c++) {
      for (int r = 1; r < _gridRows; r++) {
        if (!occupied.contains((c, r)) && !blocked.contains((c, r)))
          candidates.add((c, r));
      }
    }
    candidates.shuffle(_rng);
    final count = min(5, candidates.length);
    final newThrows = <SpaceshipThrow>[];
    for (int i = 0; i < count; i++) {
      _idCounter += 1;
      newThrows.add(SpaceshipThrow(candidates[i].$1, candidates[i].$2, 10, _idCounter));
    }
    activeThrows = [...activeThrows, ...newThrows];
    onWaveThrow?.call(newThrows);
    _safeVibrate(pattern: [0, 80, 30, 80, 30, 120]);
    notifyListeners();
  }

  void _placeL35Obstacles() {
    final existing = { for (final b in blockedCells) (b.col, b.row) };
    final thrown   = { for (final t in activeThrows) (t.col, t.row) };
    final candidates = <(int, int)>[];
    for (int c = 0; c < _gridCols; c++) {
      for (int r = 1; r < _gridRows; r++) {
        if (!existing.contains((c, r)) && !thrown.contains((c, r)))
          candidates.add((c, r));
      }
    }
    candidates.shuffle(_rng);
    final count = min(2, candidates.length);
    final placed = <(int,int)>[];
    for (int i = 0; i < count; i++) {
      _idCounter += 1;
      final cell = BlockedCell(candidates[i].$1, candidates[i].$2, _idCounter);
      blockedCells = [...blockedCells, cell];
      onCellBlocked?.call(cell.col, cell.row);
      placed.add((cell.col, cell.row));
    }
    notifyListeners();
    Timer(const Duration(seconds: 15), () {
      if (_disposed) return;
      for (final p in placed) { onCellUnblocked?.call(p.$1, p.$2); }
      blockedCells = blockedCells.where((b) =>
          !placed.any((p) => p.$1 == b.col && p.$2 == b.row)).toList();
      notifyListeners();
    });
  }

  void _tickCountdowns() {
    if (activeThrows.isEmpty) return;
    final expired = <SpaceshipThrow>[];
    final updated = <SpaceshipThrow>[];
    for (final t in activeThrows) {
      if (t.secondsLeft <= 1) expired.add(t);
      else updated.add(t.withSeconds(t.secondsLeft - 1));
    }
    activeThrows = updated;
    if (expired.isNotEmpty) {
      for (final t in expired) { onCellDestroyed?.call(t.col, t.row); }
      onPlayerDamage?.call(25);
      _updateLowHp();
      _safeVibrate(pattern: [0, 300, 80, 400, 80, 600]);
    }
    notifyListeners();
  }

  void _updateLowHp() {
    final newLow = progressFraction >= 0.75;
    if (newLow != isLowHp) { isLowHp = newLow; notifyListeners(); }
  }

  void _startDialogueCycle() {
    final lines = currentLevel == 35
        ? [..._kSpaceshipDialogues, ..._kL35ExtraDialogues]
        : _kSpaceshipDialogues;
    _dialogueTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed || phase != SpaceshipBossPhase.active) return;
      dialogueText = lines[_rng.nextInt(lines.length)];
      notifyListeners();
      _dialogueTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (_disposed || phase != SpaceshipBossPhase.active) return;
        dialogueText = lines[_rng.nextInt(lines.length)];
        notifyListeners();
        Timer(const Duration(milliseconds: 3500), () {
          if (_disposed) return;
          dialogueText = null;
          notifyListeners();
        });
      });
    });
  }

  void _handleWin() {
    _cancelTimers();
    isSlowMo = true;
    dialogueText = null;
    notifyListeners();
    _slowMoTimer = Timer(const Duration(milliseconds: 500), () {
      if (_disposed) return;
      isSlowMo = false;
      for (final b in blockedCells) { onCellUnblocked?.call(b.col, b.row); }
      blockedCells  = [];
      activeThrows  = [];
      phase = SpaceshipBossPhase.winBlast;
      AudioManager.instance.resumePreAlienBgm();
      _safeVibrate(pattern: [0, 300, 80, 300, 80, 600, 80, 1000]);
      notifyListeners();
      _entryTimer = Timer(const Duration(milliseconds: 3800), _goIdle);
    });
  }

  void _startVibPulse() {
    _vibTimer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
      if (phase != SpaceshipBossPhase.active) { _vibTimer?.cancel(); return; }
      _safeVibrate(pattern: [0, 25, 15, 25]);
    });
  }

  void _hapticBurst() {
    try { HapticFeedback.heavyImpact(); } catch (_) {}
    Future.delayed(const Duration(milliseconds: 150), () {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    });
    _safeVibrate(pattern: [0, 200, 60, 200, 60, 400]);
  }

  void _goIdle() {
    if (_disposed) return;
    phase         = SpaceshipBossPhase.idle;
    currentLevel  = 0;
    mergesDone    = 0;
    mergesNeeded  = 20;
    activeThrows  = [];
    blockedCells  = [];
    entryComplete = false;
    isLowHp       = false;
    isSlowMo      = false;
    dialogueText  = null;
    notifyListeners();
  }

  void _cancelTimers() {
    _entryTimer?.cancel();
    _waveTimer?.cancel();
    _countdownTimer?.cancel();
    _vibTimer?.cancel();
    _dialogueTimer?.cancel();
    _l35ObstacleTimer?.cancel();
    _slowMoTimer?.cancel();
    _entryTimer = _waveTimer = _countdownTimer = _vibTimer =
        _dialogueTimer = _l35ObstacleTimer = _slowMoTimer = null;
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
