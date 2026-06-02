// ============================================================
// game_provider.dart — Full Riverpod Game State
// Tech Tycoon Merge
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/audio_manager.dart';
import '../services/ad_manager.dart';
import '../themes/phase_themes.dart';

// ─── Persistence Keys ─────────────────────────────────────────────────────────

const _kHighestLevel = 'highest_unlocked_level';
const _kTotalCoins   = 'total_coins';

// ─── Popup / Dialog Type ──────────────────────────────────────────────────────

enum ActiveDialog {
  none,
  story,
  zeroEnergy,
  gridFull,
  victory,
  timeFail,
  gameBeaten,
}

// ─── Pending Animation ────────────────────────────────────────────────────────

class PendingAnimation {
  final int col, row;
  final AnimType type;
  const PendingAnimation(this.col, this.row, this.type);
}

enum AnimType { spawn, merge, error, unlock }

// ─── Game State (Immutable) ───────────────────────────────────────────────────

@immutable
class GameState {
  // Navigation
  final AppScreen screen;
  final int currentLevelIndex;     // 0-based
  final int highestUnlockedLevel;  // 1-based

  // Grid
  final List<List<GridCell>> grid; // grid[col][row]

  // Economy
  final int energy;
  final int maxEnergy;
  final int totalCoins;
  final int levelBaseCoins;    // = level.number * 100
  final int levelEarnedCoins;  // may be ×3 after ad
  final bool coinsMultiplied;

  // Quota
  final Map<int, int> quotaRequired;   // itemId → count needed
  final Map<int, int> quotaDelivered;  // itemId → count delivered

  // Timer
  final int timerSeconds;
  final bool timerActive;
  final bool timerExpiredOnce; // true once 00:00 hit (used for time-extension ad)

  // Dialogs
  final ActiveDialog activeDialog;

  // Grid-rescue mode: player can tap one item to delete it
  final bool deletionModeActive;

  // Pending animations (consumed by widget layer)
  final List<PendingAnimation> pendingAnimations;

  const GameState({
    this.screen = AppScreen.map,
    this.currentLevelIndex = 0,
    this.highestUnlockedLevel = 1,
    this.grid = const [],
    this.energy = 100,
    this.maxEnergy = 100,
    this.totalCoins = 0,
    this.levelBaseCoins = 0,
    this.levelEarnedCoins = 0,
    this.coinsMultiplied = false,
    this.quotaRequired = const {},
    this.quotaDelivered = const {},
    this.timerSeconds = 0,
    this.timerActive = false,
    this.timerExpiredOnce = false,
    this.activeDialog = ActiveDialog.none,
    this.deletionModeActive = false,
    this.pendingAnimations = const [],
  });

  LevelDefinition get currentLevel => kLevels[currentLevelIndex];

  double get quotaPercent {
    if (quotaRequired.isEmpty) return 0;
    int needed = 0, done = 0;
    quotaRequired.forEach((id, cnt) {
      needed += cnt;
      done   += min(quotaDelivered[id] ?? 0, cnt);
    });
    return needed == 0 ? 1.0 : done / needed;
  }

  bool get isLevelComplete => quotaPercent >= 1.0;

  bool get isGridFull {
    for (final col in grid) {
      for (final cell in col) {
        if (cell.isEmpty) return false;
      }
    }
    return true;
  }

  /// True when grid is full AND no two adjacent cells share the same item.
  bool get isGridLocked {
    if (!isGridFull) return false;
    final cfg = currentLevel;
    for (int c = 0; c < cfg.gridCols; c++) {
      for (int r = 0; r < cfg.gridRows; r++) {
        final id = grid[c][r].itemId;
        if (id == null) continue;
        for (final d in const [[-1,0],[1,0],[0,-1],[0,1]]) {
          final nc = c + d[0], nr = r + d[1];
          if (nc < 0 || nc >= cfg.gridCols || nr < 0 || nr >= cfg.gridRows) continue;
          if (grid[nc][nr].itemId == id) return false; // merge possible
        }
      }
    }
    return true;
  }

  GameState copyWith({
    AppScreen? screen,
    int? currentLevelIndex,
    int? highestUnlockedLevel,
    List<List<GridCell>>? grid,
    int? energy,
    int? maxEnergy,
    int? totalCoins,
    int? levelBaseCoins,
    int? levelEarnedCoins,
    bool? coinsMultiplied,
    Map<int, int>? quotaRequired,
    Map<int, int>? quotaDelivered,
    int? timerSeconds,
    bool? timerActive,
    bool? timerExpiredOnce,
    ActiveDialog? activeDialog,
    bool? deletionModeActive,
    List<PendingAnimation>? pendingAnimations,
  }) {
    return GameState(
      screen:               screen               ?? this.screen,
      currentLevelIndex:    currentLevelIndex    ?? this.currentLevelIndex,
      highestUnlockedLevel: highestUnlockedLevel ?? this.highestUnlockedLevel,
      grid:                 grid                 ?? this.grid,
      energy:               energy               ?? this.energy,
      maxEnergy:            maxEnergy            ?? this.maxEnergy,
      totalCoins:           totalCoins           ?? this.totalCoins,
      levelBaseCoins:       levelBaseCoins       ?? this.levelBaseCoins,
      levelEarnedCoins:     levelEarnedCoins     ?? this.levelEarnedCoins,
      coinsMultiplied:      coinsMultiplied      ?? this.coinsMultiplied,
      quotaRequired:        quotaRequired        ?? this.quotaRequired,
      quotaDelivered:       quotaDelivered       ?? this.quotaDelivered,
      timerSeconds:         timerSeconds         ?? this.timerSeconds,
      timerActive:          timerActive          ?? this.timerActive,
      timerExpiredOnce:     timerExpiredOnce     ?? this.timerExpiredOnce,
      activeDialog:         activeDialog         ?? this.activeDialog,
      deletionModeActive:   deletionModeActive   ?? this.deletionModeActive,
      pendingAnimations:    pendingAnimations     ?? this.pendingAnimations,
    );
  }
}

// ─── Game Notifier ────────────────────────────────────────────────────────────

class GameNotifier extends StateNotifier<GameState> {
  GameNotifier() : super(const GameState()) {
    _loadPrefs();
  }

  Timer? _timer;
  final Random _rng = Random();

  /// True if the player voluntarily watched the Rewarded Ad (3× coins) on the
  /// current Victory screen. Reset to false at the start of every new level
  /// completion. Used to enforce the Rewarded ↔ Interstitial mutual exclusion
  /// rule: never stack a forced Interstitial right after an opt-in Rewarded Ad.
  bool _rewardedWatchedThisVictory = false;

  // ── Preferences ───────────────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state.copyWith(
        highestUnlockedLevel: prefs.getInt(_kHighestLevel) ?? 1,
        totalCoins:           prefs.getInt(_kTotalCoins)   ?? 0,
      );
    } catch (e) {
      debugPrint('[Prefs] _loadPrefs() failed: $e');
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kHighestLevel, state.highestUnlockedLevel);
      await prefs.setInt(_kTotalCoins,   state.totalCoins);
    } catch (e) {
      debugPrint('[Prefs] _savePrefs() failed: $e');
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void goToMap() {
    _timer?.cancel();
    final level = state.currentLevel;
    state = state.copyWith(screen: AppScreen.map, timerActive: false);
    AudioManager.instance.playBgm(themeOf(level.phase).bgmAsset);
  }

  // ── Start Level ───────────────────────────────────────────────────────────

  void startLevel(int levelIndex) {
    // Guard: clamp to valid range
    final safeIndex = levelIndex.clamp(0, kLevels.length - 1);
    _timer?.cancel();

    final cfg  = kLevels[safeIndex];
    final grid = _buildInitialGrid(cfg);
    final base = cfg.baseCoins;

    // CRITICAL FIX: Do NOT start the timer here. The story dialog is about to
    // be shown, and the player cannot interact with the board while it is open.
    // Starting the timer now would mean precious seconds tick away while the
    // player reads the level brief, AND could fire ActiveDialog.timeFail while
    // ActiveDialog.story is still open → bad state → crash / frozen UI.
    // The timer is started inside dismissStory() once the player taps "Let's Go".
    state = state.copyWith(
      screen:             AppScreen.game,
      currentLevelIndex:  safeIndex,
      grid:               grid,
      energy:             100,
      maxEnergy:          100,
      levelBaseCoins:     base,
      levelEarnedCoins:   base,
      coinsMultiplied:    false,
      quotaRequired:      cfg.quotaMap,
      quotaDelivered:     {},
      timerSeconds:       cfg.timeLimitSeconds,
      timerActive:        false,   // timer NOT active yet — starts after story is dismissed
      timerExpiredOnce:   false,
      activeDialog:       ActiveDialog.story,
      deletionModeActive: false,
      pendingAnimations:  const [],
    );

    // Audio is guarded by try-catch inside AudioManager
    AudioManager.instance.playBgm(themeOf(cfg.phase).bgmAsset);
  }

  // ── Initial Grid Construction ─────────────────────────────────────────────

  List<List<GridCell>> _buildInitialGrid(LevelDefinition cfg) {
    final cells = List.generate(
      cfg.gridCols,
      (c) => List.generate(cfg.gridRows, (r) => const GridCell()),
    );

    final positions = <(int, int)>[];
    for (int c = 0; c < cfg.gridCols; c++) {
      for (int r = 0; r < cfg.gridRows; r++) {
        positions.add((c, r));
      }
    }
    positions.shuffle(_rng);

    int posIdx = 0;

    // Black Holes (Phase 5)
    for (int i = 0; i < cfg.blackHoleCount && posIdx < positions.length; i++) {
      final (c, r) = positions[posIdx++];
      cells[c][r] = const GridCell(obstacle: ObstacleType.blackHole);
    }

    // Dusty Webs (Phase 1 L6+)
    for (int i = 0; i < cfg.dustyWebCount && posIdx < positions.length; i++) {
      final (c, r) = positions[posIdx++];
      cells[c][r] = const GridCell(obstacle: ObstacleType.dustyWeb);
    }

    // Locked Crates (Phase 2 L15+)
    for (int i = 0; i < cfg.lockedCrateCount && posIdx < positions.length; i++) {
      final (c, r) = positions[posIdx++];
      cells[c][r] = const GridCell(obstacle: ObstacleType.lockedCrate);
    }

    // Seed some starting items
    final seedId = cfg.spawnerItemId;
    final nonObstacle = <(int, int)>[];
    for (int c = 0; c < cfg.gridCols; c++) {
      for (int r = 0; r < cfg.gridRows; r++) {
        if (cells[c][r].isEmpty) nonObstacle.add((c, r));
      }
    }
    nonObstacle.shuffle(_rng);
    final seedCount = max(2, (nonObstacle.length * 0.15).round());
    for (int i = 0; i < seedCount && i < nonObstacle.length; i++) {
      final (c, r) = nonObstacle[i];
      cells[c][r] = GridCell(itemId: seedId);
    }

    return cells;
  }

  // ── Story Dialog ──────────────────────────────────────────────────────────

  void dismissStory() {
    final cfg = state.currentLevel;
    // CRITICAL FIX: Start the countdown timer HERE, not in startLevel().
    // The timer must only run while the player can actually interact with
    // the board. Starting it from startLevel() (while the story dialog is
    // blocking all input) counted down time the player couldn't use, and
    // also allowed timeFail to fire while the story dialog was still open,
    // causing a bad-state crash on the "Let's Go" button tap.
    state = state.copyWith(
      activeDialog: ActiveDialog.none,
      timerActive:  cfg.hasTimer,
    );
    if (cfg.hasTimer) _startTimer();
  }

  // ── Spawn Item ────────────────────────────────────────────────────────────

  void spawnItem({int? targetCol, int? targetRow}) {
    if (state.activeDialog != ActiveDialog.none) return;
    if (state.deletionModeActive) return;
    final cfg = state.currentLevel;

    if (state.energy <= 0) {
      AudioManager.instance.playErrorBuzz();
      state = state.copyWith(activeDialog: ActiveDialog.zeroEnergy);
      return;
    }

    int col = targetCol ?? -1;
    int row = targetRow ?? -1;
    if (col == -1 || row == -1) {
      outer:
      for (int c = 0; c < cfg.gridCols; c++) {
        for (int r = 0; r < cfg.gridRows; r++) {
          if (state.grid[c][r].isEmpty) { col = c; row = r; break outer; }
        }
      }
    }

    if (col == -1) {
      if (state.isGridLocked && cfg.allowGridRescue) {
        state = state.copyWith(activeDialog: ActiveDialog.gridFull);
      }
      return;
    }

    final newGrid = _cloneGrid();
    newGrid[col][row] = GridCell(itemId: cfg.spawnerItemId);

    final anims = [...state.pendingAnimations, PendingAnimation(col, row, AnimType.spawn)];

    state = state.copyWith(
      grid:  newGrid,
      energy: state.energy - 1,
      pendingAnimations: anims,
    );

    AudioManager.instance.playSpawnPop();
    _checkGridLocked();
  }

  // ── Move / Merge / Deliver ────────────────────────────────────────────────

  void handleDrag(int fromCol, int fromRow, {int? toCol, int? toRow, bool isDelivery = false}) {
    if (state.activeDialog != ActiveDialog.none) return;
    if (state.deletionModeActive) return;

    final from = state.grid[fromCol][fromRow];
    if (from.itemId == null) return;

    if (isDelivery) {
      _deliverItem(fromCol, fromRow);
      return;
    }

    if (toCol == null || toRow == null) return;
    final to = state.grid[toCol][toRow];

    if (to.isBlocked) return;

    if (to.itemId == null) {
      _moveCell(fromCol, fromRow, toCol, toRow);
    } else if (to.itemId == from.itemId) {
      _mergeItems(fromCol, fromRow, toCol, toRow);
    } else {
      _swapCells(fromCol, fromRow, toCol, toRow);
    }
  }

  void _moveCell(int fc, int fr, int tc, int tr) {
    final newGrid = _cloneGrid();
    final id = newGrid[fc][fr].itemId!;
    newGrid[fc][fr] = newGrid[fc][fr].clearItem();
    newGrid[tc][tr] = newGrid[tc][tr].withItem(id);
    state = state.copyWith(grid: newGrid);
  }

  void _swapCells(int fc, int fr, int tc, int tr) {
    final newGrid = _cloneGrid();
    final idA = newGrid[fc][fr].itemId;
    final idB = newGrid[tc][tr].itemId;
    newGrid[fc][fr] = idB != null ? newGrid[fc][fr].withItem(idB) : newGrid[fc][fr].clearItem();
    newGrid[tc][tr] = idA != null ? newGrid[tc][tr].withItem(idA) : newGrid[tc][tr].clearItem();
    state = state.copyWith(grid: newGrid);
  }

  void _mergeItems(int fc, int fr, int tc, int tr) {
    final id   = state.grid[fc][fr].itemId!;
    final next = ItemDictionary.nextItem(id);
    if (next == null) {
      AudioManager.instance.playErrorBuzz();
      state = state.copyWith(
        pendingAnimations: [...state.pendingAnimations, PendingAnimation(tc, tr, AnimType.error)],
      );
      return;
    }

    final newGrid = _cloneGrid();
    newGrid[fc][fr] = newGrid[fc][fr].clearItem();
    newGrid[tc][tr] = newGrid[tc][tr].withItem(next.id);

    _unlockAdjacent(newGrid, tc, tr);

    final anims = [...state.pendingAnimations, PendingAnimation(tc, tr, AnimType.merge)];
    state = state.copyWith(grid: newGrid, pendingAnimations: anims);

    AudioManager.instance.playMergeSnap();
  }

  void _unlockAdjacent(List<List<GridCell>> grid, int col, int row) {
    final cfg = state.currentLevel;
    for (final d in const [[-1,0],[1,0],[0,-1],[0,1]]) {
      final nc = col + d[0], nr = row + d[1];
      if (nc < 0 || nc >= cfg.gridCols || nr < 0 || nr >= cfg.gridRows) continue;
      final cell = grid[nc][nr];
      if (cell.obstacle == ObstacleType.dustyWeb ||
          cell.obstacle == ObstacleType.lockedCrate) {
        grid[nc][nr] = GridCell(isUnlocking: true);
        AudioManager.instance.playUnlock();
      }
    }
  }

  void _deliverItem(int col, int row) {
    final itemId  = state.grid[col][row].itemId!;
    final needed  = state.quotaRequired[itemId] ?? 0;
    final done    = state.quotaDelivered[itemId] ?? 0;

    if (needed == 0 || done >= needed) {
      AudioManager.instance.playErrorBuzz();
      state = state.copyWith(
        pendingAnimations: [...state.pendingAnimations, PendingAnimation(col, row, AnimType.error)],
      );
      return;
    }

    final newGrid     = _cloneGrid();
    newGrid[col][row] = newGrid[col][row].clearItem();
    final newDelivered = Map<int, int>.from(state.quotaDelivered);
    newDelivered[itemId] = done + 1;

    state = state.copyWith(
      grid:          newGrid,
      quotaDelivered: newDelivered,
    );

    AudioManager.instance.playMergeSnap();

    if (state.isLevelComplete) {
      _onLevelComplete();
    }
  }

  // ── Level Complete ────────────────────────────────────────────────────────

  void _onLevelComplete() {
    _timer?.cancel();
    AudioManager.instance.pauseBgm();
    AudioManager.instance.playVictory();

    final lvlNum     = state.currentLevel.number;
    final newHighest = max(state.highestUnlockedLevel, lvlNum + 1);

    // Reset the mutual-exclusion flag for the incoming Victory screen.
    // If the player watches the Rewarded Ad here, it will be set to true,
    // and the Interstitial will be suppressed when they tap "Next Level".
    _rewardedWatchedThisVictory = false;

    state = state.copyWith(
      timerActive:          false,
      activeDialog:         ActiveDialog.victory,
      highestUnlockedLevel: min(newHighest, kLevels.length),
    );
    _savePrefs();

    // Pre-warm the interstitial while the player is on the Victory dialog
    // (reading story text, optionally watching the 3× coin ad, etc.).
    // This gives the download time to finish so the ad fires instantly when
    // they tap "Next Level" instead of sitting through a 3-second loading poll.
    // Only bother from level 4 onwards — the grace period blocks levels 1-3.
    // prewarmInterstitial() is a no-op if already loaded or loading.
    if (lvlNum >= 4) {
      AdManager.instance.prewarmInterstitial();
    }
  }

  // ── Ad: Zero Energy — Rule 1 ──────────────────────────────────────────────

  Future<void> watchAdForEnergy() async {
    AudioManager.instance.pauseBgm();
    final shown = await AdManager.instance.showRewarded(onReward: () {
      state = state.copyWith(
        energy:       (state.energy + 50).clamp(0, state.maxEnergy),
        activeDialog: ActiveDialog.none,
      );
      AudioManager.instance.resumeBgm();
    });
    if (!shown) {
      // Ad not ready — do NOT give free energy.
      // Keep the dialog open so the player can retry once the ad loads.
      AudioManager.instance.resumeBgm();
    }
  }

  // ── Ad: Grid Full Rescue — Phase 3+ ───────────────────────────────────────

  Future<void> watchAdForGridRescue() async {
    AudioManager.instance.pauseBgm();
    final shown = await AdManager.instance.showRewarded(onReward: () {
      state = state.copyWith(
        activeDialog:       ActiveDialog.none,
        deletionModeActive: true,
      );
      AudioManager.instance.resumeBgm();
    });
    if (!shown) {
      state = state.copyWith(activeDialog: ActiveDialog.none);
      AudioManager.instance.resumeBgm();
    }
  }

  void deleteItemInRescueMode(int col, int row) {
    if (!state.deletionModeActive) return;
    final cell = state.grid[col][row];
    if (cell.itemId == null || cell.isBlocked) return;

    final newGrid = _cloneGrid();
    newGrid[col][row] = newGrid[col][row].clearItem();
    state = state.copyWith(
      grid:               newGrid,
      deletionModeActive: false,
    );
    AudioManager.instance.playSpawnPop();
  }

  void cancelDeletionMode() {
    state = state.copyWith(deletionModeActive: false);
  }

  // ── Ad: Victory Multiplier — Rule 3 ──────────────────────────────────────

  Future<void> watchAdForMultiplier() async {
    if (state.coinsMultiplied) return;
    AudioManager.instance.pauseBgm();
    final shown = await AdManager.instance.showRewarded(onReward: () {
      // Rule 5: coins are added ONLY inside onUserEarnedReward (this closure).
      state = state.copyWith(
        levelEarnedCoins: state.levelEarnedCoins * 3,
        coinsMultiplied:  true,
      );
      // Rule 3 (mutual exclusion): player just watched an opt-in Rewarded Ad.
      // Flag this so goToNextLevel() will suppress the Interstitial.
      _rewardedWatchedThisVictory = true;
      AudioManager.instance.resumeBgm();
    });
    if (!shown) AudioManager.instance.resumeBgm();
  }

  // ── Proceed to Next Level ─────────────────────────────────────────────────

  Future<void> goToNextLevel() async {
    final lvlNum = state.currentLevel.number;

    state = state.copyWith(
      totalCoins: state.totalCoins + state.levelEarnedCoins,
    );
    _savePrefs();

    final nextIndex = state.currentLevelIndex + 1;
    if (nextIndex >= kLevels.length) {
      state = state.copyWith(activeDialog: ActiveDialog.gameBeaten);
      return;
    }

    // ── Anti-Fatigue Gate ──────────────────────────────────────────────────
    // All four rules are checked here in canShowInterstitial():
    //   Rule 1 — Grace period: only levels ≥ 4 are eligible.
    //   Rule 2 — 3-minute cooldown: skip if < 180 s since last interstitial.
    //   Rule 3 — Mutual exclusion: skip if player just watched a Rewarded Ad.
    //   Rule 4 — Triggered ONLY on this button tap, never during gameplay.
    if (AdManager.instance.canShowInterstitial(
      lvlNum,
      rewardedJustWatched: _rewardedWatchedThisVictory,
    )) {
      AudioManager.instance.pauseBgm();
      await AdManager.instance.showInterstitial(onDismiss: () {
        AudioManager.instance.resumeBgm();
        startLevel(nextIndex);
      });
    } else {
      startLevel(nextIndex);
    }
  }

  void dismissVictory() {
    state = state.copyWith(activeDialog: ActiveDialog.none);
    AudioManager.instance.resumeBgm();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.timerSeconds <= 1) {
        _timer?.cancel();
        _onTimerExpired();
      } else {
        final secs = state.timerSeconds - 1;
        state = state.copyWith(timerSeconds: secs);
        if (secs == 10) AudioManager.instance.playTimeWarning();
      }
    });
  }

  void _onTimerExpired() {
    AudioManager.instance.pauseBgm();
    state = state.copyWith(
      timerSeconds:     0,
      timerActive:      false,
      timerExpiredOnce: true,
      activeDialog:     ActiveDialog.timeFail,
    );
  }

  // ── Ad: Time Extension (Phase 4+) ─────────────────────────────────────────

  Future<void> watchAdForTimeExtension() async {
    await AdManager.instance.showRewarded(onReward: () {
      final newSecs = state.timerSeconds + 60;
      state = state.copyWith(
        timerSeconds:     newSecs,
        timerActive:      true,
        timerExpiredOnce: false,
        activeDialog:     ActiveDialog.none,
      );
      _startTimer();
      AudioManager.instance.resumeBgm();
    });
  }

  // ── Restart Level ─────────────────────────────────────────────────────────

  Future<void> retryLevel() async {
    final lvlNum = state.currentLevel.number;

    // Same anti-fatigue gate as goToNextLevel(), except mutual exclusion is
    // irrelevant here (no Rewarded Ad on a restart flow), so pass false.
    // Grace period and 3-minute cooldown still apply.
    if (AdManager.instance.canShowInterstitial(
      lvlNum,
      rewardedJustWatched: false,
    )) {
      AudioManager.instance.pauseBgm();
      await AdManager.instance.showInterstitial(onDismiss: () {
        startLevel(state.currentLevelIndex);
      });
    } else {
      startLevel(state.currentLevelIndex);
    }
  }

  // ── Consume Animations ────────────────────────────────────────────────────

  void consumeAnimation(PendingAnimation anim) {
    state = state.copyWith(
      pendingAnimations: state.pendingAnimations
          .where((a) => a != anim)
          .toList(),
    );
  }

  // ── Grid Helpers ──────────────────────────────────────────────────────────

  List<List<GridCell>> _cloneGrid() {
    return state.grid
        .map((col) => col.map((cell) => GridCell(
              itemId:      cell.itemId,
              obstacle:    cell.obstacle,
              isUnlocking: false,
            )).toList())
        .toList();
  }

  void _checkGridLocked() {
    final cfg = state.currentLevel;
    if (state.isGridLocked && cfg.allowGridRescue) {
      if (state.activeDialog == ActiveDialog.none) {
        state = state.copyWith(activeDialog: ActiveDialog.gridFull);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final gameProvider = StateNotifierProvider<GameNotifier, GameState>(
  (_) => GameNotifier(),
);

// Derived providers — minimise widget rebuilds
final screenProvider       = Provider<AppScreen>((ref) => ref.watch(gameProvider).screen);
final gridProvider         = Provider<List<List<GridCell>>>((ref) => ref.watch(gameProvider).grid);
final dialogProvider       = Provider<ActiveDialog>((ref) => ref.watch(gameProvider).activeDialog);
final energyProvider       = Provider<int>((ref) => ref.watch(gameProvider).energy);
final timerProvider        = Provider<int>((ref) => ref.watch(gameProvider).timerSeconds);
final quotaPctProvider     = Provider<double>((ref) => ref.watch(gameProvider).quotaPercent);
final animProvider         = Provider<List<PendingAnimation>>((ref) => ref.watch(gameProvider).pendingAnimations);
final highestLvlProvider   = Provider<int>((ref) => ref.watch(gameProvider).highestUnlockedLevel);
final deletionModeProvider = Provider<bool>((ref) => ref.watch(gameProvider).deletionModeActive);
