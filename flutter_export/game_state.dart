// ============================================================
// game_state.dart
// Tech Tycoon Merge — Riverpod State Management
//
// pubspec.yaml:
//   flutter_riverpod: ^2.5.1
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'level_config.dart';
import 'ad_manager.dart';

// ─── Grid Cell ───────────────────────────────────────────────────────────────

class GridCell {
  final String? itemId;       // null = empty
  final ObstacleType obstacle;
  final bool isLocked;        // true = obstacle is blocking, cannot place items

  const GridCell({
    this.itemId,
    this.obstacle = ObstacleType.none,
    this.isLocked = false,
  });

  bool get isEmpty => itemId == null && !isLocked;
  bool get hasItem  => itemId != null;
  bool get isBlackHole => obstacle == ObstacleType.blackHole;

  GridCell copyWith({
    Object? itemId = _sentinel,
    ObstacleType? obstacle,
    bool? isLocked,
  }) {
    return GridCell(
      itemId:   itemId == _sentinel ? this.itemId : itemId as String?,
      obstacle: obstacle  ?? this.obstacle,
      isLocked: isLocked  ?? this.isLocked,
    );
  }

  static const Object _sentinel = Object();
}

// ─── App Phase ───────────────────────────────────────────────────────────────

enum AppPhase { menu, playing, levelComplete, gameOver }

// ─── Game State ──────────────────────────────────────────────────────────────

@immutable
class GameState {
  final int currentLevelIndex;   // 0-based index into LEVELS list
  final List<List<GridCell>> grid; // grid[col][row]
  final int energy;
  final int maxEnergy;
  final int totalCoins;
  final int levelCompleteCoins;  // base coins for this level (may be ×3 after ad)
  final AppPhase appPhase;
  final bool showEnergyWarning;  // Rule 2 hard popup
  final int timerSeconds;
  final bool timerActive;

  const GameState({
    this.currentLevelIndex = 0,
    this.grid = const [],
    this.energy = 100,
    this.maxEnergy = 100,
    this.totalCoins = 0,
    this.levelCompleteCoins = 0,
    this.appPhase = AppPhase.menu,
    this.showEnergyWarning = false,
    this.timerSeconds = 0,
    this.timerActive = false,
  });

  LevelModel get currentLevel => TechTycoonLevels.get50Levels()[currentLevelIndex];

  /// Rule 1 condition — expose to UI
  bool get shouldShowLowEnergyButton =>
      currentLevel.allowLowEnergyBoost && energy <= 20 && energy > 0;

  /// Rule 2 condition — expose to UI
  bool get isSpawnerBlocked => energy == 0;

  GameState copyWith({
    int? currentLevelIndex,
    List<List<GridCell>>? grid,
    int? energy,
    int? maxEnergy,
    int? totalCoins,
    int? levelCompleteCoins,
    AppPhase? appPhase,
    bool? showEnergyWarning,
    int? timerSeconds,
    bool? timerActive,
  }) {
    return GameState(
      currentLevelIndex:  currentLevelIndex  ?? this.currentLevelIndex,
      grid:               grid               ?? this.grid,
      energy:             energy             ?? this.energy,
      maxEnergy:          maxEnergy          ?? this.maxEnergy,
      totalCoins:         totalCoins         ?? this.totalCoins,
      levelCompleteCoins: levelCompleteCoins ?? this.levelCompleteCoins,
      appPhase:           appPhase           ?? this.appPhase,
      showEnergyWarning:  showEnergyWarning  ?? this.showEnergyWarning,
      timerSeconds:       timerSeconds       ?? this.timerSeconds,
      timerActive:        timerActive        ?? this.timerActive,
    );
  }
}

// ─── Game Notifier ───────────────────────────────────────────────────────────

class GameNotifier extends StateNotifier<GameState> {
  GameNotifier() : super(const GameState());

  Timer? _timer;
  final List<LevelModel> _levels = TechTycoonLevels.get50Levels();

  // ── Start Level ───────────────────────────────────────────────────────────

  void startLevel(int levelIndex) {
    _timer?.cancel();
    final cfg = _levels[levelIndex];
    final grid = _buildGrid(cfg);

    state = state.copyWith(
      currentLevelIndex: levelIndex,
      grid: grid,
      appPhase: AppPhase.playing,
      showEnergyWarning: false,
      levelCompleteCoins: 0,
      timerActive: cfg.obstacle == ObstacleType.timedOrder,
      timerSeconds: cfg.timedOrderSeconds ?? 0,
    );

    if (cfg.obstacle == ObstacleType.timedOrder) {
      _startTimer();
    }
  }

  // ── Grid Construction ─────────────────────────────────────────────────────

  List<List<GridCell>> _buildGrid(LevelModel cfg) {
    final rng = DateTime.now().millisecondsSinceEpoch;
    final grid = List.generate(
      cfg.gridCols,
      (c) => List.generate(cfg.gridRows, (r) => const GridCell()),
    );

    // Place obstacles
    int obsCount = 0;
    final maxObs = cfg.obstacle == ObstacleType.blackHole ? 3 : 1;
    outer:
    for (int c = 0; c < cfg.gridCols && obsCount < maxObs; c++) {
      for (int r = 0; r < cfg.gridRows && obsCount < maxObs; r++) {
        // Stagger positions using pseudo-random offset
        if ((c + r + rng) % (cfg.gridCols + 2) == 0) {
          grid[c][r] = GridCell(
            obstacle: cfg.obstacle,
            isLocked: cfg.obstacle != ObstacleType.timedOrder,
          );
          obsCount++;
        }
      }
    }

    // Seed starter items (base tier of current phase)
    final baseItem = ItemChains.chainForPhase(cfg.phase).first;
    int seeded = 0;
    final targetSeeds = ((cfg.gridCols * cfg.gridRows) * 0.18).round().clamp(2, 8);
    for (int c = 0; c < cfg.gridCols && seeded < targetSeeds; c++) {
      for (int r = 0; r < cfg.gridRows && seeded < targetSeeds; r++) {
        if (grid[c][r].isEmpty) {
          grid[c][r] = GridCell(itemId: baseItem.id);
          seeded++;
        }
      }
    }

    return grid;
  }

  // ── Spawn Item ────────────────────────────────────────────────────────────

  /// Called when the player taps an empty cell (spawner interaction).
  void spawnItem(int col, int row) {
    final cfg = state.currentLevel;
    final cell = state.grid[col][row];

    if (cell.isLocked || cell.isBlackHole || cell.hasItem) return;

    // ── Rule 2: energy == 0 — block and optionally show wall ────────────────
    if (state.energy == 0) {
      if (cfg.allowZeroEnergyLockout) {
        state = state.copyWith(showEnergyWarning: true);
      }
      return;
    }

    final energyCost = (cfg.energyCostPerSpawn * (cfg.fasterEnergyDrain ? 1.5 : 1.0)).round();
    final baseItem = ItemChains.chainForPhase(cfg.phase).first;

    final newGrid = _cloneGrid();
    newGrid[col][row] = GridCell(itemId: baseItem.id);

    state = state.copyWith(
      grid: newGrid,
      energy: (state.energy - energyCost).clamp(0, state.maxEnergy),
      showEnergyWarning: false,
    );
  }

  // ── Move / Merge ──────────────────────────────────────────────────────────
  // Called by the UI drag-and-drop gesture.
  // Level(X) + Level(X) = Level(X+1)

  void moveItem(int fromCol, int fromRow, int toCol, int toRow) {
    final fromCell = state.grid[fromCol][fromRow];
    final toCell   = state.grid[toCol][toRow];
    final cfg = state.currentLevel;

    if (fromCell.itemId == null) return;

    final newGrid = _cloneGrid();

    // Dragging into a black hole destroys the item
    if (toCell.isBlackHole) {
      newGrid[fromCol][fromRow] = newGrid[fromCol][fromRow].copyWith(itemId: null);
      state = state.copyWith(grid: newGrid);
      return;
    }

    if (toCell.isLocked) return;

    if (toCell.itemId == null) {
      // ── Simple move ──────────────────────────────────────────────────────
      newGrid[toCol][toRow]     = newGrid[toCol][toRow].copyWith(itemId: fromCell.itemId);
      newGrid[fromCol][fromRow] = newGrid[fromCol][fromRow].copyWith(itemId: null);
      _tryUnlockAdjacent(newGrid, toCol, toRow, cfg);
    } else if (toCell.itemId == fromCell.itemId) {
      // ── Merge: Level(X) + Level(X) → Level(X+1) ─────────────────────────
      final merged = ItemChains.nextTier(fromCell.itemId!);
      if (merged != null) {
        newGrid[toCol][toRow]     = newGrid[toCol][toRow].copyWith(itemId: merged.id);
        newGrid[fromCol][fromRow] = newGrid[fromCol][fromRow].copyWith(itemId: null);
        _tryUnlockAdjacent(newGrid, toCol, toRow, cfg);

        state = state.copyWith(grid: newGrid);
        _checkWinCondition(newGrid, cfg);
        return;
      }
    } else {
      // ── Swap ─────────────────────────────────────────────────────────────
      newGrid[toCol][toRow]     = newGrid[toCol][toRow].copyWith(itemId: fromCell.itemId);
      newGrid[fromCol][fromRow] = newGrid[fromCol][fromRow].copyWith(itemId: toCell.itemId);
    }

    state = state.copyWith(grid: newGrid);
  }

  void _tryUnlockAdjacent(List<List<GridCell>> grid, int col, int row, LevelModel cfg) {
    const dirs = [[-1,0],[1,0],[0,-1],[0,1]];
    for (final d in dirs) {
      final nc = col + d[0], nr = row + d[1];
      if (nc < 0 || nc >= cfg.gridCols || nr < 0 || nr >= cfg.gridRows) continue;
      final cell = grid[nc][nr];
      if (cell.obstacle == ObstacleType.dustyWeb ||
          cell.obstacle == ObstacleType.lockedCrate) {
        grid[nc][nr] = cell.copyWith(obstacle: ObstacleType.none, isLocked: false);
      }
    }
  }

  void _checkWinCondition(List<List<GridCell>> grid, LevelModel cfg) {
    for (final col in grid) {
      for (final cell in col) {
        if (cell.itemId == cfg.targetItemId) {
          _completeLevel(cfg);
          return;
        }
      }
    }
  }

  void _completeLevel(LevelModel cfg) {
    _timer?.cancel();
    state = state.copyWith(
      appPhase: AppPhase.levelComplete,
      levelCompleteCoins: cfg.baseCoins,
      timerActive: false,
    );
  }

  // ── Energy Management ─────────────────────────────────────────────────────

  /// Called inside the rewarded ad onReward callback (Rules 1 & 2).
  void addEnergy(int amount) {
    state = state.copyWith(
      energy: (state.energy + amount).clamp(0, state.maxEnergy),
      showEnergyWarning: false,
    );
  }

  void dismissEnergyWarning() {
    state = state.copyWith(showEnergyWarning: false);
  }

  // ── Coin Multiplier ───────────────────────────────────────────────────────

  /// Called inside the rewarded ad onReward callback (Rule 3).
  void multiplyCoins(int factor) {
    state = state.copyWith(levelCompleteCoins: state.levelCompleteCoins * factor);
  }

  // ── Next Level ────────────────────────────────────────────────────────────

  /// Handles Rule 4: interstitial fires on even levels, then loads next level
  /// ONLY inside the onDismiss callback.
  Future<void> goToNextLevel() async {
    // Collect coins
    state = state.copyWith(
      totalCoins: state.totalCoins + state.levelCompleteCoins,
    );

    final nextIndex = state.currentLevelIndex + 1;
    if (nextIndex >= _levels.length) {
      state = state.copyWith(appPhase: AppPhase.menu);
      return;
    }

    final currentLevel = state.currentLevel;

    // ── Rule 4: fire interstitial on even levels if flag is set ─────────────
    if (currentLevel.triggerInterstitialNext &&
        currentLevel.levelNumber % 2 == 0) {
      // Grid does NOT load until onDismiss fires
      await AdManagerService.instance.showInterstitialAd(
        onDismiss: () => startLevel(nextIndex),
      );
    } else {
      // Odd levels: load immediately
      startLevel(nextIndex);
    }
  }

  // ── Timed Order ───────────────────────────────────────────────────────────

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.timerSeconds <= 1) {
        _timer?.cancel();
        state = state.copyWith(timerSeconds: 0, timerActive: false, appPhase: AppPhase.gameOver);
      } else {
        state = state.copyWith(timerSeconds: state.timerSeconds - 1);
      }
    });
  }

  // ── Restart Level ─────────────────────────────────────────────────────────

  void restartLevel() => startLevel(state.currentLevelIndex);

  void goToMenu() {
    _timer?.cancel();
    state = state.copyWith(appPhase: AppPhase.menu);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<List<GridCell>> _cloneGrid() {
    return state.grid
        .map((col) => col.map((cell) => cell.copyWith()).toList())
        .toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ─── Riverpod Providers ──────────────────────────────────────────────────────

final gameProvider = StateNotifierProvider<GameNotifier, GameState>(
  (ref) => GameNotifier(),
);

// Convenient derived providers — only rebuild widgets that depend on them.

final appPhaseProvider = Provider<AppPhase>(
  (ref) => ref.watch(gameProvider).appPhase,
);

final energyProvider = Provider<int>(
  (ref) => ref.watch(gameProvider).energy,
);

final gridProvider = Provider<List<List<GridCell>>>(
  (ref) => ref.watch(gameProvider).grid,
);

final currentLevelProvider = Provider<LevelModel>(
  (ref) => ref.watch(gameProvider).currentLevel,
);

final showEnergyWarningProvider = Provider<bool>(
  (ref) => ref.watch(gameProvider).showEnergyWarning,
);
