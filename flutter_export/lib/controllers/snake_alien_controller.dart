// snake_alien_controller.dart — Snake-Alien Hybrid Boss
// Level 38: 40 merges (Level 37 now uses its own AntiGravityController)
// Polish: Dialogue bubbles, Snake Jr. blocker, L38 final dialogue, death slow-mo

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/audio_manager.dart';

enum SnakeAlienPhase {
  idle,
  entry,
  active,
  slowMo,
  winBlast,
}

class MiniAlienDrop {
  final int col;
  final int row;
  final int secondsLeft;
  final double id;
  const MiniAlienDrop(this.col, this.row, this.secondsLeft, this.id);
  MiniAlienDrop withSeconds(int s) => MiniAlienDrop(col, row, s, id);
}

class SnakeJrCell {
  final int col;
  final int row;
  final double id;
  const SnakeJrCell(this.col, this.row, this.id);
}

const Map<int, int> kSnakeAlienLevels = { 38: 40 };

const _kSnakeDialogues = [
  'SSSLITHERING DOOM! 🐍',
  'MY CHILDREN WILL DEVOUR YOU! 👽',
  'HISSSS... YOU ARE FINISHED! 💀',
  'FEEL THE VENOM! ☠️',
  'YOUR GRID IS MY NEST! 🐍',
  'FOOLISH MAMMAL! 😈',
  'YOU CANNOT MERGE FAST ENOUGH! ⚡',
  'I WILL CONSUME EVERYTHING! 🌀',
];

const _kL38FinalWords = [
  'I... WILL... RETURN! 😤',
  'THIS IS NOT THE END! 🔥',
  'MY REVENGE WILL BE SWIFT! 💀',
  'MARK MY WORDS, HUMAN! 👾',
];

class SnakeAlienController extends ChangeNotifier {

  SnakeAlienPhase phase  = SnakeAlienPhase.idle;
  int  currentLevel      = 0;
  int  mergesDone        = 0;
  int  mergesNeeded      = 35;
  bool entryComplete     = false;

  String? dialogueText;
  String? deathDialogue;
  bool    isSlowMo   = false;
  bool    isLowHp    = false;
  List<MiniAlienDrop> activeDrops  = [];
  List<SnakeJrCell>   snakeJrCells = [];

  void Function(List<MiniAlienDrop>)? onDropWave;
  void Function(int col, int row)?    onCellDestroyed;
  void Function(int damage)?          onPlayerDamage;
  void Function(int col, int row)?    onCellBlocked;
  void Function(int col, int row)?    onCellUnblocked;
  int? Function(int col, int row)?   _itemIdAt; // FIX: know which cells have items

  bool _disposed = false;
  final Random _rng       = Random();
  double       _idCounter = 0;

  Timer? _entryTimer;
  Timer? _dropWaveTimer;
  Timer? _dropCountdownTimer;
  Timer? _vibTimer;
  Timer? _dialogueTimer;
  Timer? _snakeJrTimer;
  Timer? _slowMoTimer;

  int _gridCols = 6;
  int _gridRows = 5;

  bool   get isIdle    => phase == SnakeAlienPhase.idle;
  bool   get isActive  => phase == SnakeAlienPhase.active;
  double get progressFraction =>
      mergesNeeded > 0 ? (mergesDone / mergesNeeded).clamp(0.0, 1.0) : 0;

  void triggerForLevel(
    int level, {
    required int gridCols,
    required int gridRows,
    required void Function(List<MiniAlienDrop>) onWave,
    required void Function(int col, int row) onCellDestroy,
    required void Function(int damage) onDamage,
    void Function(int col, int row)? onBlock,
    void Function(int col, int row)? onUnblock,
    int? Function(int col, int row)? itemIdAt,
  }) {
    if (!kSnakeAlienLevels.containsKey(level)) { _goIdle(); return; }

    _cancelTimers();
    currentLevel    = level;
    mergesNeeded    = kSnakeAlienLevels[level]!;
    mergesDone      = 0;
    activeDrops     = [];
    snakeJrCells    = [];
    entryComplete   = false;
    isSlowMo        = false;
    isLowHp         = false;
    dialogueText    = null;
    deathDialogue   = null;
    _gridCols       = gridCols;
    _gridRows       = gridRows;
    onDropWave      = onWave;
    onCellDestroyed = onCellDestroy;
    onPlayerDamage  = onDamage;
    onCellBlocked   = onBlock;
    onCellUnblocked = onUnblock;
    _itemIdAt       = itemIdAt;

    _hapticBurst();
    AudioManager.instance.playAlienBgm('assets/audio/bgm_alien_boss.mp3').catchError((_) {});

    phase = SnakeAlienPhase.entry;
    notifyListeners();

    _entryTimer = Timer(const Duration(milliseconds: 5200), () {
      if (_disposed) return;
      entryComplete = true;
      phase = SnakeAlienPhase.active;
      _startDropCycle();
      _startSnakeJrCycle();
      _startVibPulse();
      _startDialogueCycle();
      notifyListeners();
    });
  }

  void onItemMerged(int col, int row) {
    if (phase != SnakeAlienPhase.active) return;
    mergesDone++;
    _updateLowHp();
    notifyListeners();
    if (mergesDone >= mergesNeeded) _handleWin();
  }

  void onMergeAtCell(int col, int row) {
    if (phase != SnakeAlienPhase.active) return;
    final before = activeDrops.length;
    activeDrops = activeDrops
        .where((d) => !(d.col == col && d.row == row))
        .toList();
    if (activeDrops.length < before) notifyListeners();
  }

  MiniAlienDrop? getDropAt(int col, int row) {
    try { return activeDrops.firstWhere((d) => d.col == col && d.row == row); }
    catch (_) { return null; }
  }

  bool hasSnakeJrAt(int col, int row) =>
      snakeJrCells.any((s) => s.col == col && s.row == row);

  void onLevelComplete() {
    if (phase == SnakeAlienPhase.idle || phase == SnakeAlienPhase.winBlast) return;
    _handleWin();
  }

  void reset() {
    _cancelTimers();
    for (final s in snakeJrCells) { onCellUnblocked?.call(s.col, s.row); }
    snakeJrCells = [];
    AudioManager.instance.resumePreAlienBgm();
    _goIdle();
  }

  void _startDropCycle() {
    _dropWaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (phase != SnakeAlienPhase.active || _disposed) return;
      _dropWave();
    });
    _dropCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      _tickDropCountdowns();
    });
  }

  void _startSnakeJrCycle() {
    Timer(const Duration(seconds: 20), () {
      if (phase == SnakeAlienPhase.active && !_disposed) _spawnSnakeJr();
    });
    _snakeJrTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (phase != SnakeAlienPhase.active || _disposed) return;
      _spawnSnakeJr();
    });
  }

  void _spawnSnakeJr() {
    final existing = { for (final s in snakeJrCells) (s.col, s.row) };
    final dropped  = { for (final d in activeDrops) (d.col, d.row) };
    final candidates = <(int, int)>[];
    for (int c = 0; c < _gridCols; c++) {
      for (int r = 1; r < _gridRows; r++) {
        if (!existing.contains((c, r)) && !dropped.contains((c, r)))
          candidates.add((c, r));
      }
    }
    if (candidates.isEmpty) return;
    candidates.shuffle(_rng);
    _idCounter += 1;
    final jr = SnakeJrCell(candidates.first.$1, candidates.first.$2, _idCounter);
    snakeJrCells = [...snakeJrCells, jr];
    onCellBlocked?.call(jr.col, jr.row);
    dialogueText = 'SNAKE JR. DEPLOYED! 🐍';
    notifyListeners();
    Timer(const Duration(seconds: 2), () {
      if (!_disposed) { dialogueText = null; notifyListeners(); }
    });
    _safeVibrate(pattern: [0, 120, 40, 120]);
  }

  void _dropWave() {
    final occupied = {
      for (final d in activeDrops) (d.col, d.row),
      for (final s in snakeJrCells) (s.col, s.row),
    };
    final candidates = <(int, int)>[];
    for (int c = 0; c < _gridCols; c++) {
      for (int r = 1; r < _gridRows; r++) {
        if (!occupied.contains((c, r))) {
          // FIX bug1: only attack cells that HAVE items on the grid
          final hasItem = _itemIdAt == null || _itemIdAt!(c, r) != null;
          if (hasItem) candidates.add((c, r));
        }
      }
    }
    // FIX: if no items on grid, skip this wave entirely
    if (candidates.isEmpty) return;
    candidates.shuffle(_rng);
    // FIX bug3: max 5, but never more than available item-cells
    final count = min(5, candidates.length);
    final newDrops = <MiniAlienDrop>[];
    for (int i = 0; i < count; i++) {
      _idCounter += 1;
      newDrops.add(MiniAlienDrop(candidates[i].$1, candidates[i].$2, 5, _idCounter));
    }
    activeDrops = [...activeDrops, ...newDrops];
    onDropWave?.call(newDrops);
    _safeVibrate(pattern: [0, 60, 20, 60, 20, 100]);
    notifyListeners();
  }

  void _tickDropCountdowns() {
    if (activeDrops.isEmpty) return;
    final expired = <MiniAlienDrop>[];
    final updated = <MiniAlienDrop>[];
    for (final d in activeDrops) {
      if (d.secondsLeft <= 1) expired.add(d);
      else updated.add(d.withSeconds(d.secondsLeft - 1));
    }
    activeDrops = updated;
    for (final d in expired) { onCellDestroyed?.call(d.col, d.row); }
    if (expired.isNotEmpty) { _safeVibrate(pattern: [0, 200, 60, 300]); }
    notifyListeners();
  }

  void _updateLowHp() {
    final newLow = progressFraction >= 0.75;
    if (newLow != isLowHp) { isLowHp = newLow; notifyListeners(); }
  }

  void _startDialogueCycle() {
    _dialogueTimer = Timer(const Duration(seconds: 4), () {
      if (_disposed || phase != SnakeAlienPhase.active) return;
      dialogueText = _kSnakeDialogues[_rng.nextInt(_kSnakeDialogues.length)];
      notifyListeners();
      _dialogueTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (_disposed || phase != SnakeAlienPhase.active) return;
        dialogueText = _kSnakeDialogues[_rng.nextInt(_kSnakeDialogues.length)];
        notifyListeners();
        Timer(const Duration(milliseconds: 3500), () {
          if (!_disposed) { dialogueText = null; notifyListeners(); }
        });
      });
    });
  }

  void _handleWin() {
    _cancelTimers();
    isSlowMo = true;
    if (currentLevel == 38) {
      deathDialogue = _kL38FinalWords[_rng.nextInt(_kL38FinalWords.length)];
    }
    dialogueText = null;
    notifyListeners();

    _slowMoTimer = Timer(const Duration(milliseconds: 600), () {
      if (_disposed) return;
      isSlowMo = false;
      for (final s in snakeJrCells) { onCellUnblocked?.call(s.col, s.row); }
      snakeJrCells = [];
      activeDrops  = [];
      phase = SnakeAlienPhase.winBlast;
      AudioManager.instance.resumePreAlienBgm();
      _safeVibrate(pattern: [0, 300, 80, 300, 80, 600, 80, 1200]);
      notifyListeners();
      _entryTimer = Timer(const Duration(milliseconds: 4200), _goIdle);
    });
  }

  void _startVibPulse() {
    _vibTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (phase != SnakeAlienPhase.active) { _vibTimer?.cancel(); return; }
      _safeVibrate(pattern: [0, 20, 10, 20]);
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
    phase         = SnakeAlienPhase.idle;
    currentLevel  = 0;
    mergesDone    = 0;
    mergesNeeded  = 35;
    activeDrops   = [];
    snakeJrCells  = [];
    entryComplete = false;
    isSlowMo      = false;
    isLowHp       = false;
    dialogueText  = null;
    deathDialogue = null;
    notifyListeners();
  }

  void _cancelTimers() {
    _entryTimer?.cancel();
    _dropWaveTimer?.cancel();
    _dropCountdownTimer?.cancel();
    _vibTimer?.cancel();
    _dialogueTimer?.cancel();
    _snakeJrTimer?.cancel();
    _slowMoTimer?.cancel();
    _entryTimer = _dropWaveTimer = _dropCountdownTimer = _vibTimer =
        _dialogueTimer = _snakeJrTimer = _slowMoTimer = null;
  }

  Future<void> _safeVibrate({List<int>? pattern, int duration = 200}) async {
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
