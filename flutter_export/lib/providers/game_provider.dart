// ============================================================
// game_provider.dart — Full Riverpod Game State
// Tech Tycoon Merge
// ============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/audio_manager.dart';
import '../services/ad_manager.dart';
import '../themes/phase_themes.dart';
import '../controllers/malware_controller.dart';
import '../controllers/robot_controller.dart';
import '../controllers/creature_controller.dart';
import '../controllers/alien_controller.dart';
import '../controllers/spaceship_boss_controller.dart';
import '../controllers/octopus_alien_controller.dart';
import '../controllers/snake_alien_controller.dart';
import '../controllers/antigravity_controller.dart';
import '../controllers/nexus_core_controller.dart';
import '../controllers/warp_sentinel_controller.dart';
import '../controllers/terra_lich_controller.dart';

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

enum AnimType { spawn, merge, error, unlock, hazardHit, upwardSpawn, decoyHit, decoyHit20 }

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

  // Supply Drop / Mystery Drop Box state (Levels 11–50)
  final int supplyDropCol;      // -1 = none active
  final int supplyDropRow;
  final int supplyDropCountdown; // seconds remaining (0–10)

  // Glitched Decoy mechanic (Levels 5–20)
  final int decoyGlitchTick; // increments each glitch cycle → _GlitchedDecoyTile reacts

  // Data Kraken creature throw mechanic (Levels 23, 25, 27, 29)
  final List<CreatureThrow> creatureThrows;

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
    this.supplyDropCol = -1,
    this.supplyDropRow = -1,
    this.supplyDropCountdown = 0,
    this.decoyGlitchTick = 0,
    this.creatureThrows = const [],
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
    int? supplyDropCol,
    int? supplyDropRow,
    int? supplyDropCountdown,
    int? decoyGlitchTick,
    List<CreatureThrow>? creatureThrows,
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
      supplyDropCol:        supplyDropCol        ?? this.supplyDropCol,
      supplyDropRow:        supplyDropRow        ?? this.supplyDropRow,
      supplyDropCountdown:  supplyDropCountdown  ?? this.supplyDropCountdown,
      decoyGlitchTick:      decoyGlitchTick      ?? this.decoyGlitchTick,
      creatureThrows:       creatureThrows       ?? this.creatureThrows,
    );
  }
}

// ─── Game Notifier ────────────────────────────────────────────────────────────

class GameNotifier extends StateNotifier<GameState> {
  GameNotifier() : super(const GameState()) {
    _loadPrefs();
  }

  Timer? _timer;
  Timer? _supplyDropSpawnTimer;
  Timer? _supplyDropCountdownTimer;
  Timer? _glitchTimer;
  Timer? _decoyTeleportTimer;
  bool   _disposed = false;
  final Random _rng = Random();
  final malwareController       = MalwareController();
  final robotController         = RobotController();
  final creatureController      = CreatureController();
  final alienController         = AlienController();
  final spaceshipBossController = SpaceshipBossController();
  final octopusAlienController  = OctopusAlienController();
  final snakeAlienController    = SnakeAlienController();
  final antiGravityController   = AntiGravityController();
  final nexusCoreController     = NexusCoreController();
  final warpSentinelController  = WarpSentinelController();
  final terraLichController     = TerraLichController();
  Timer? _creatureThrowCdTimer;

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
        highestUnlockedLevel: kLevels.length,
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
    _supplyDropSpawnTimer?.cancel();
    _supplyDropCountdownTimer?.cancel();
    _glitchTimer?.cancel();
    _decoyTeleportTimer?.cancel();
    _creatureThrowCdTimer?.cancel();
    _creatureThrowCdTimer = null;
    creatureController.reset();
    alienController.reset();
    spaceshipBossController.reset();
    octopusAlienController.reset();
    snakeAlienController.reset();
    antiGravityController.reset();
    terraLichController.reset();
    final level = state.currentLevel;
    state = state.copyWith(
      screen: AppScreen.map,
      timerActive: false,
      supplyDropCol: -1,
      supplyDropRow: -1,
      supplyDropCountdown: 0,
      decoyGlitchTick: 0,
      creatureThrows: const [],
    );
    AudioManager.instance.playBgm(themeOf(level.phase).bgmAsset);
  }

  // ── Start Level ───────────────────────────────────────────────────────────

  void startLevel(int levelIndex) {
    // Guard: clamp to valid range
    final safeIndex = levelIndex.clamp(0, kLevels.length - 1);
    _timer?.cancel();
    _supplyDropSpawnTimer?.cancel();
    _supplyDropCountdownTimer?.cancel();
    _glitchTimer?.cancel();
    _decoyTeleportTimer?.cancel();
    _creatureThrowCdTimer?.cancel();
    _creatureThrowCdTimer = null;

    final cfg  = kLevels[safeIndex];
    final grid = _buildInitialGrid(cfg);
    final base = cfg.baseCoins;

    // Reset robot state immediately so stale robot never bleeds into a new level
    robotController.reset();
    creatureController.reset();
    alienController.reset();
    spaceshipBossController.reset();
    octopusAlienController.reset();
    snakeAlienController.reset();
    antiGravityController.reset();
    terraLichController.reset();

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
      supplyDropCol:      -1,
      supplyDropRow:      -1,
      supplyDropCountdown: 0,
      decoyGlitchTick:    0,
      creatureThrows:     const [],
    );
    // FIX BUG 1: Start phase BGM immediately when level is selected (during
    // story dialog) so there is no jarring sound change when "Let's Go" is
    // tapped. dismissStory() still calls playBgm() but it becomes a no-op
    // since the same asset is already playing (_currentBgmAsset guard).
    AudioManager.instance.playBgm(themeOf(cfg.phase).bgmAsset);

  }

  // ── Clear All Grid Items (malware loss callback) ────────────────────────
  void _clearAllItems() {
    final cfg     = state.currentLevel;
    final newGrid = _cloneGrid();
    for (int c = 0; c < cfg.gridCols; c++) {
      for (int r = 0; r < cfg.gridRows; r++) {
        newGrid[c][r] = newGrid[c][r].clearItem();
      }
    }
    state = state.copyWith(grid: newGrid);
  }

  // ── Data Kraken Creature Throw Mechanics ──────────────────────────────────
  // Levels 23, 25, 27, 29 — called by CreatureController every 4-5 s.

  void _placeCreatureThrow() {
    if (_disposed) return;
    // Do not pick new targets while existing targets are still active on the grid.
    // Player must merge/save all current targets before creature selects new ones.
    if (state.creatureThrows.isNotEmpty) return;
    final cfg = state.currentLevel;

    // Empty cells not already targeted by an active creature throw
    final occupied = {for (final t in state.creatureThrows) (t.col, t.row)};
    final empties  = <(int, int)>[];
    for (int c = 0; c < cfg.gridCols; c++) {
      for (int r = 0; r < cfg.gridRows; r++) {
        final cell = state.grid[c][r];
        if (cell.isEmpty && !occupied.contains((c, r))) empties.add((c, r));
      }
    }
    if (empties.isEmpty) return; // grid too full to place

    empties.shuffle(_rng);
    final (tc, tr) = empties.first;
    final itemId   = cfg.spawnerItemId;

    final newGrid   = _cloneGrid();
    newGrid[tc][tr] = GridCell(itemId: itemId);

    final newThrow = CreatureThrow(tc, tr, itemId, 5);
    final throws   = [...state.creatureThrows, newThrow];
    final anims    = [
      ...state.pendingAnimations,
      PendingAnimation(tc, tr, AnimType.upwardSpawn),
    ];

    state = state.copyWith(grid: newGrid, creatureThrows: throws, pendingAnimations: anims);
    AudioManager.instance.playSpawnPop();
    _startCreatureThrowCountdown();
  }

  void _cancelCreatureThrowAt(int col, int row) {
    final throws = state.creatureThrows;
    if (throws.isEmpty) return;
    final updated = throws.where((t) => !(t.col == col && t.row == row)).toList();
    if (updated.length == throws.length) return; // nothing to cancel
    state = state.copyWith(creatureThrows: updated);
    creatureController.onThrowMerged();
    if (updated.isEmpty) {
      _creatureThrowCdTimer?.cancel();
      _creatureThrowCdTimer = null;
    }
  }

  void _startCreatureThrowCountdown() {
    if (_creatureThrowCdTimer != null) return; // already running
    _creatureThrowCdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) {
        _creatureThrowCdTimer?.cancel();
        _creatureThrowCdTimer = null;
        return;
      }
      final throws = state.creatureThrows;
      if (throws.isEmpty) {
        _creatureThrowCdTimer?.cancel();
        _creatureThrowCdTimer = null;
        return;
      }

      final newGrid = _cloneGrid();
      var   energy  = state.energy;
      final updated = <CreatureThrow>[];

      for (final t in throws) {
        if (t.secondsLeft <= 1) {
          // Countdown expired — clear item, deduct 10 energy
          if (state.grid[t.col][t.row].itemId != null) {
            newGrid[t.col][t.row] = newGrid[t.col][t.row].clearItem();
            energy = (energy - 10).clamp(0, state.maxEnergy);
          }
        } else {
          updated.add(t.withSeconds(t.secondsLeft - 1));
        }
      }

      state = state.copyWith(grid: newGrid, energy: energy, creatureThrows: updated);

      if (updated.isEmpty) {
        _creatureThrowCdTimer?.cancel();
        _creatureThrowCdTimer = null;
      }
    });
  }

  // ── Initial Grid Construction ─────────────────────────────────────────────

  List<List<GridCell>> _buildInitialGrid(LevelDefinition cfg) {
    final cells = List.generate(
      cfg.gridCols,
      (c) => List.generate(cfg.gridRows, (r) => const GridCell()),
    );

    // ── Hazard Traps — fixed positions, placed FIRST (multiples of 5 only) ───
    // Indexes are flat row-major: col = idx % gridCols, row = idx ~/ gridCols
    for (final idx in hazardIndexesForLevel(cfg.number)) {
      final col = idx % cfg.gridCols;
      final row = idx ~/ cfg.gridCols;
      if (col < cfg.gridCols && row < cfg.gridRows) {
        cells[col][row] = const GridCell(obstacle: ObstacleType.hazardTrap);
      }
    }

    // ── Remaining random obstacles (shuffled positions, skip hazard slots) ───
    final positions = <(int, int)>[];
    for (int c = 0; c < cfg.gridCols; c++) {
      for (int r = 0; r < cfg.gridRows; r++) {
        if (cells[c][r].isEmpty) positions.add((c, r));
      }
    }
    positions.shuffle(_rng);

    int posIdx = 0;

    // Black Holes (Phase 5)
    // Level 41 (Warp Sentinel) uses FIXED positions so coverage is always optimal
    // and consistent across every restart.
    //   Hole A = (col=1, row=2): 3×3 zone covers cols 0-2, rows 1-3 (left-center cluster)
    //   Hole B = (col=4, row=3): 3×3 zone covers cols 3-5, rows 2-4 (right-center cluster)
    // Both zones avoid row 0 (boss anchor) and row 5 (locked corners), together
    // covering 18 of 36 cells in the two highest-density item areas.
    if (cfg.number == 41) {
      const fixedHoles = [(1, 2), (4, 3)];
      for (final hole in fixedHoles) {
        final hc = hole.$1;
        final hr = hole.$2;
        if (hc < cfg.gridCols && hr < cfg.gridRows && cells[hc][hr].isEmpty) {
          cells[hc][hr] = const GridCell(obstacle: ObstacleType.blackHole);
        }
      }
    } else {
      for (int i = 0; i < cfg.blackHoleCount && posIdx < positions.length; i++) {
        final (c, r) = positions[posIdx++];
        cells[c][r] = const GridCell(obstacle: ObstacleType.blackHole);
      }
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

    // Seed some starting items (skip all obstacle slots)
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

    // ── Locked / Rusted Tiles (Levels 1–50) ─────────────────────────────────
    // Place 2–3 pre-locked base items that can only be freed by merging the
    // same item type onto them. Applied to every level 1–50.
    final lockedCount = 2 + _rng.nextInt(2); // 2 or 3
    final availForLocked = <(int, int)>[];
    for (int c = 0; c < cfg.gridCols; c++) {
      for (int r = 0; r < cfg.gridRows; r++) {
        if (cells[c][r].isEmpty) availForLocked.add((c, r));
      }
    }
    availForLocked.shuffle(_rng);
    for (int i = 0; i < lockedCount && i < availForLocked.length; i++) {
      final (c, r) = availForLocked[i];
      cells[c][r] = GridCell(
        obstacle: ObstacleType.lockedItem,
        lockedItemId: cfg.spawnerItemId,
      );
    }

    // ── Glitched Decoys (Levels 5–20) ────────────────────────────────────────
    // Place 2 decoys (L5-10, static) or 3 decoys (L11-20, teleporting).
    // Decoys visually mimic a real merge item to fool the player.
    // Tapping one costs -30 Energy. Grid minimum: ≥13 usable non-decoy cells.
    final decoyCount = cfg.decoyCount;
    if (decoyCount > 0) {
      final availForDecoy = <(int, int)>[];
      for (int c = 0; c < cfg.gridCols; c++) {
        for (int r = 0; r < cfg.gridRows; r++) {
          if (cells[c][r].isEmpty) availForDecoy.add((c, r));
        }
      }
      availForDecoy.shuffle(_rng);
      // Decoy mimics spawnerItemId + 1 to blend with the lowest board items
      final decoyMimicId = (cfg.spawnerItemId + 1).clamp(1, 51);
      for (int i = 0; i < decoyCount && i < availForDecoy.length; i++) {
        final (c, r) = availForDecoy[i];
        cells[c][r] = GridCell(
          obstacle: ObstacleType.glitchedDecoy,
          decoyItemId: decoyMimicId,
        );
      }
    }

    // ── L41 Glitchy Decoys (4 items, opposite side of active black hole) ─────
    // On start bossHoleIndex=0 (Hole A/LEFT at col=1 active) → decoys on RIGHT.
    // Positions are mathematically fixed outside both holes' 3×3 pull zones:
    //   RIGHT positions (bossHoleIndex=0): (3,0),(5,0),(3,5),(5,5)
    //   LEFT  positions (bossHoleIndex=1): (0,0),(2,0),(0,5),(2,5)
    if (cfg.hasL41Decoys) {
      _placeL41DecoysCells(cells, 0, cfg.gridCols, cfg.gridRows, cfg.spawnerItemId);
    }

    return cells;
  }

  // ── Hazard Trap Tap ───────────────────────────────────────────────────────
  // Penalty: tapping a Hazard Trap costs 20 Energy and plays error SFX.
  // If energy drops to 0 or below, the zeroEnergy dialog fires immediately.

  void tapHazard(int col, int row) {
    if (state.activeDialog != ActiveDialog.none) return;
    final cell = state.grid[col][row];
    if (cell.obstacle != ObstacleType.hazardTrap) return;

    HapticFeedback.heavyImpact();
    AudioManager.instance.playErrorBuzz();

    final newEnergy = (state.energy - 20).clamp(0, state.maxEnergy);
    final anims = [
      ...state.pendingAnimations,
      PendingAnimation(col, row, AnimType.error),    // cell shake
      const PendingAnimation(-1, -1, AnimType.hazardHit), // full-screen flash
    ];

    if (newEnergy <= 0) {
      state = state.copyWith(
        energy:           0,
        activeDialog:     ActiveDialog.zeroEnergy,
        pendingAnimations: anims,
      );
    } else {
      state = state.copyWith(
        energy:           newEnergy,
        pendingAnimations: anims,
      );
    }
  }

  // ── Glitched Decoy Tap ────────────────────────────────────────────────────
  // Penalty: tapping a Glitched Decoy costs:
  //   -30 Energy on L5-20 (standard decoys)
  //   -20 Energy on L41  (warp glitchy decoys)
  // If energy drops to 0, the zeroEnergy dialog fires.

  void tapDecoy(int col, int row) {
    if (state.activeDialog != ActiveDialog.none) return;
    final cell = state.grid[col][row];
    if (!cell.isDecoy) return;

    HapticFeedback.heavyImpact();
    AudioManager.instance.playErrorBuzz();

    final isL41Decoy = state.currentLevel.hasL41Decoys;
    final penalty    = isL41Decoy ? 20 : 30;
    final hitAnim    = isL41Decoy ? AnimType.decoyHit20 : AnimType.decoyHit;

    final newEnergy = (state.energy - penalty).clamp(0, state.maxEnergy);
    final anims = [
      ...state.pendingAnimations,
      PendingAnimation(col, row, hitAnim),               // floating -20/-30⚡ text
      const PendingAnimation(-1, -1, AnimType.hazardHit), // screen flash
    ];

    if (newEnergy <= 0) {
      state = state.copyWith(
        energy:            0,
        activeDialog:      ActiveDialog.zeroEnergy,
        pendingAnimations: anims,
      );
    } else {
      state = state.copyWith(
        energy:            newEnergy,
        pendingAnimations: anims,
      );
    }
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
    // Phase BGM — only starts when player taps Let's Go
    AudioManager.instance.playBgm(themeOf(cfg.phase).bgmAsset);
    // Start Mystery Drop Box timer for levels 11–50
    if (cfg.number >= 11 && cfg.number <= 50) {
      _scheduleNextSupplyDrop();
    }
    // Start Glitched Decoy timers for levels 5–20 and L41
    if (cfg.hasDecoys || cfg.hasL41Decoys) {
      _startGlitchTimer();
      if (cfg.decoysAreTeleporting) _startDecoyTeleportTimer();
    }

    // ── Malware Boss Event: trigger AFTER story dismissed so player sees board ──
    {
      final grid = state.grid;
      (int, int)? _tutFrom;
      (int, int)? _tutTo;
      if (cfg.number == 5) {
        outer:
        for (int cc = 0; cc < cfg.gridCols; cc++) {
          for (int rr = 0; rr < cfg.gridRows; rr++) {
            final id = grid[cc][rr].itemId;
            if (id == null || grid[cc][rr].isBlocked) continue;
            for (int cc2 = cc; cc2 < cfg.gridCols; cc2++) {
              for (int rr2 = (cc2 == cc ? rr + 1 : 0); rr2 < cfg.gridRows; rr2++) {
                if (grid[cc2][rr2].itemId == id && !grid[cc2][rr2].isBlocked) {
                  _tutFrom = (cc, rr);
                  _tutTo   = (cc2, rr2);
                  break outer;
                }
              }
            }
          }
        }
      }
      malwareController.triggerForLevel(
        cfg.number,
        onClearGrid:  _clearAllItems,
        tutorialFrom: _tutFrom,
        tutorialTo:   _tutTo,
      );
    }
    // ── Robot Villain trigger (L13, L15, L17, L20) ──────────────────────────
    // Always call — triggerForLevel(_goIdle) for non-robot levels, trigger for robot levels
    robotController.triggerForLevel(cfg.number, onClearGrid: _clearAllItems);
    // ── Data Kraken creature trigger (L23, L25, L27, L29) ────────────────────
    creatureController.triggerForLevel(cfg.number, onThrow: _placeCreatureThrow);
    // ── Alien Boss trigger (L31, L32, L33) ───────────────────────────────────
    if (kAlienLevels.containsKey(cfg.number)) {
      alienController.triggerForLevel(
        cfg.number,
        gridCols: cfg.gridCols,
        gridRows: cfg.gridRows,
        onThrow: (_) {}, // overlay handles animation; game logic via onCellDestroy
        onCellDestroy: _onAlienMeteorLand,
        onDamage: (_) {},
      );
    } else {
      alienController.reset();
    }

    // ── Spaceship Boss trigger (L34, L35) ─────────────────────────────────────
    if (kSpaceshipBossLevels.containsKey(cfg.number)) {
      spaceshipBossController.triggerForLevel(
        cfg.number,
        gridCols: cfg.gridCols,
        gridRows: cfg.gridRows,
        onThrow: (_) {}, // overlay renders timers
        onCellDestroy: _onBossThrowExpire,
        onDamage: _onBossDamage,
        onCoins: _onCoinReward,
        onBlock: _onCellBlocked,
        onUnblock: _onCellUnblocked,
        isCellOccupied: (c, r) =>
            state.grid[c][r].itemId != null && !state.grid[c][r].isBlocked,
      );
    } else {
      spaceshipBossController.reset();
    }

    // ── Octopus Alien trigger (L36) ───────────────────────────────────────────
    if (cfg.number == 36) {
      octopusAlienController.triggerForLevel(
        cfg.number,
        gridCols: cfg.gridCols,
        gridRows: cfg.gridRows,
        onCellDestroy: _onBossThrowExpire,
        onDamage: _onBossDamage,
        onCoins: _onCoinReward,
        isCellOccupied: (c, r) =>
            state.grid[c][r].itemId != null && !state.grid[c][r].isBlocked,
      );
    } else {
      octopusAlienController.reset();
    }

    // ── Snake Alien trigger (L38) ─────────────────────────────────────────────
    if (kSnakeAlienLevels.containsKey(cfg.number)) {
      snakeAlienController.triggerForLevel(
        cfg.number,
        gridCols: cfg.gridCols,
        gridRows: cfg.gridRows,
        onWave: (_) {}, // overlay renders drop timers
        onCellDestroy: _onBossThrowExpire,
        onDamage: _onBossDamage,
        onBlock: _onCellBlocked,
        onUnblock: _onCellUnblocked,
        // FIX bug1: so boss only targets cells that have items
        itemIdAt: (col, row) => state.grid[col][row].itemId,
      );
    } else {
      snakeAlienController.reset();
    }

    // ── NEXUS CORE trigger (L40) ──────────────────────────────────────────────
    if (cfg.number == kNexusCoreLevel) {
      nexusCoreController.triggerForLevel(
        cfg.number,
        gridCols: cfg.gridCols,
        gridRows: cfg.gridRows,
        onHacked: (col, row) {
          // Visual feedback only — hacked state is tracked by the controller.
          // The merge penalty is handled inside _mergeItems.
          HapticFeedback.mediumImpact();
        },
        onPenalty: (e) {
          final newE = (state.energy - e).clamp(0, state.maxEnergy);
          state = state.copyWith(energy: newE);
          AudioManager.instance.playErrorBuzz();
          HapticFeedback.heavyImpact();
        },
        isOccupied: (c, r) => state.grid[c][r].itemId != null && !state.grid[c][r].isBlocked,
      );
    } else {
      nexusCoreController.reset();
    }

    // ── WARP SENTINEL trigger (L41) ───────────────────────────────────────────
    if (cfg.number == kWarpSentinelLevel) {
      // Collect actual black hole positions from the already-built grid
      final bhPositions = <(int, int)>[];
      for (int c = 0; c < cfg.gridCols; c++) {
        for (int r = 0; r < cfg.gridRows; r++) {
          if (state.grid[c][r].obstacle == ObstacleType.blackHole) {
            bhPositions.add((c, r));
          }
        }
      }
      warpSentinelController.onBossHoleSwitched = (newBossHoleIndex) {
        // L41: when the boss teleports to the other black hole, reposition
        // the 4 glitchy decoys to the opposite side of the new active hole.
        if (!_disposed) _repositionL41Decoys(newBossHoleIndex);
      };
      warpSentinelController.triggerForLevel(
        cfg.number,
        gridCols:           cfg.gridCols,
        gridRows:           cfg.gridRows,
        spawnerItemId:      cfg.spawnerItemId,
        blackHolePositions: bhPositions,
        onSiphoned: (col, row) {
          // Item proximity-pulled into black hole — remove it
          final cfg2 = state.currentLevel;
          if (col < 0 || col >= cfg2.gridCols || row < 0 || row >= cfg2.gridRows) return;
          final newGrid = _cloneGrid();
          newGrid[col][row] = newGrid[col][row].clearItem();
          state = state.copyWith(
            grid: newGrid,
            pendingAnimations: [
              ...state.pendingAnimations,
              PendingAnimation(col, row, AnimType.hazardHit),
            ],
          );
          AudioManager.instance.playErrorBuzz();
          HapticFeedback.heavyImpact();
        },
        onPenalty: (e) {
          final newE = (state.energy - e).clamp(0, state.maxEnergy);
          state = state.copyWith(energy: newE);
          AudioManager.instance.playErrorBuzz();
          HapticFeedback.heavyImpact();
        },
        isOccupied: (c, r) => state.grid[c][r].itemId != null && !state.grid[c][r].isBlocked,
        isDecoy:    (c, r) => state.grid[c][r].isDecoy,
      );
    } else {
      warpSentinelController.reset();
    }

    // ── Anti-Gravity trigger (L37) ────────────────────────────────────────────
    if (cfg.number == 37) {
      antiGravityController.triggerForLevel(
        cfg.number,
        gridCols: cfg.gridCols,
        gridRows: cfg.gridRows,
        onDestroy: _onBossThrowExpire,
        onPenalty: (e) { // 15 energy per item destroyed
          final newE = (state.energy - e).clamp(0, state.maxEnergy);
          state = state.copyWith(energy: newE);
          AudioManager.instance.playErrorBuzz();
          HapticFeedback.heavyImpact();
        },
        isVulnerable: (c, r) {
          final cell = state.grid[c][r];
          if (cell.itemId == null || cell.isBlocked) return false;
          // "Never merged" == still at the raw spawner tier for this level.
          return cell.itemId! <= cfg.spawnerItemId;
        },
        itemIdAt: (c, r) => state.grid[c][r].itemId,
      );
    } else {
      antiGravityController.reset();
    }

    // ── Terra-Lich trigger (L42) ──────────────────────────────────────────────
    if (cfg.number == 42) {
      terraLichController.triggerForLevel(
        cfg.number,
        onAttack: () {
          // TODO: attack mechanic to be defined by user
          // Placeholder: haptic feedback on EMP strike
          HapticFeedback.heavyImpact();
        },
      );
    } else {
      terraLichController.reset();
    }
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

    final anims = [...state.pendingAnimations, PendingAnimation(col, row, AnimType.upwardSpawn)];

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

    // Dragging from a Glitched Decoy: cancel + pay Energy penalty
    if (from.isDecoy) {
      tapDecoy(fromCol, fromRow);
      return;
    }

    if (isDelivery) {
      _deliverItem(fromCol, fromRow);
      return;
    }

    if (toCol == null || toRow == null) return;
    final to = state.grid[toCol][toRow];

    // ── Locked tile: only matching item can unlock it ────────────────────────
    if (to.obstacle == ObstacleType.lockedItem) {
      if (from.itemId == to.lockedItemId) {
        _unlockLockedItem(fromCol, fromRow, toCol, toRow);
      } else {
        AudioManager.instance.playErrorBuzz();
        state = state.copyWith(
          pendingAnimations: [...state.pendingAnimations,
            PendingAnimation(toCol, toRow, AnimType.error)],
        );
      }
      return;
    }

    // ── WARP SENTINEL: sacrifice item into black hole (L41) ─────────────────
    if (to.obstacle == ObstacleType.blackHole &&
        warpSentinelController.phase != WarpSentinelPhase.idle) {
      final itemId = from.itemId!;
      warpSentinelController.onItemSacrificed(itemId);
      // Remove the sacrificed item from the board
      final newGrid = _cloneGrid();
      newGrid[fromCol][fromRow] = newGrid[fromCol][fromRow].clearItem();
      state = state.copyWith(
        grid: newGrid,
        pendingAnimations: [
          ...state.pendingAnimations,
          PendingAnimation(fromCol, fromRow, AnimType.hazardHit),
        ],
      );
      return;
    }

    if (to.isBlocked) {
      // BUG FIX: drag onto hazardTrap fires -20⚡, glitchedDecoy fires -30⚡.
      if (to.isHazard)       tapHazard(toCol, toRow);
      else if (to.isDecoy)   tapDecoy(toCol, toRow);
      return;          // all other blocked cells → silent reject
    }

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
    // Cancel creature throw on source cell — item moved, no penalty
    _cancelCreatureThrowAt(fc, fr);
    // NEXUS CORE: hacked state + targeting follow the moved item
    nexusCoreController.onCellMoved(fc, fr, tc, tr);
    // WARP SENTINEL: siphon state follows the moved item
    warpSentinelController.onCellMoved(fc, fr, tc, tr);
    // WARP SENTINEL: gravitational drag — moving heavy items from pull zone costs energy
    final dragCost = warpSentinelController.getDragEnergyCost(fc, fr, id);
    if (dragCost > 0) {
      final newE = (state.energy - dragCost).clamp(0, state.maxEnergy);
      state = state.copyWith(energy: newE);
      AudioManager.instance.playErrorBuzz();
    }
  }

  void _swapCells(int fc, int fr, int tc, int tr) {
    final newGrid = _cloneGrid();
    final idA = newGrid[fc][fr].itemId;
    final idB = newGrid[tc][tr].itemId;
    newGrid[fc][fr] = idB != null ? newGrid[fc][fr].withItem(idB) : newGrid[fc][fr].clearItem();
    newGrid[tc][tr] = idA != null ? newGrid[tc][tr].withItem(idA) : newGrid[tc][tr].clearItem();
    state = state.copyWith(grid: newGrid);
    // Cancel creature throws on both swapped cells — items moved, no penalty
    _cancelCreatureThrowAt(fc, fr);
    _cancelCreatureThrowAt(tc, tr);
    // NEXUS CORE: swap hacked states with items
    nexusCoreController.onCellsSwapped(fc, fr, tc, tr);
    // WARP SENTINEL: swap siphon states with items
    warpSentinelController.onCellsSwapped(fc, fr, tc, tr);
  }

  void _mergeItems(int fc, int fr, int tc, int tr) {
    // ── NEXUS CORE: hacked-merge trap (L40) ──────────────────────────────────
    if (nexusCoreController.phase != NexusCorePhase.idle) {
      final fromHacked = nexusCoreController.isHackedAt(fc, fr);
      final toHacked   = nexusCoreController.isHackedAt(tc, tr);
      if (fromHacked || toHacked) {
        // Delete BOTH items, deduct 15 energy, play error — merge fails.
        final newGrid = _cloneGrid();
        newGrid[fc][fr] = newGrid[fc][fr].clearItem();
        newGrid[tc][tr] = newGrid[tc][tr].clearItem();
        final newE = (state.energy - 15).clamp(0, state.maxEnergy);
        final anims = [
          ...state.pendingAnimations,
          PendingAnimation(fc, fr, AnimType.hazardHit),
          PendingAnimation(tc, tr, AnimType.hazardHit),
        ];
        state = state.copyWith(grid: newGrid, energy: newE, pendingAnimations: anims);
        nexusCoreController.onCellCleared(fc, fr);
        nexusCoreController.onCellCleared(tc, tr);
        AudioManager.instance.playErrorBuzz();
        HapticFeedback.heavyImpact();
        return;
      }
      // Normal merge on un-hacked cells → notify controller (may cancel targeting)
      nexusCoreController.onItemMerged(fc, fr, tc, tr);
    }

    // ── WARP SENTINEL: siphon escape on merge (L41) ───────────────────────────
    if (warpSentinelController.phase != WarpSentinelPhase.idle) {
      warpSentinelController.onItemMerged(fc, fr, tc, tr);
    }

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
    HapticFeedback.lightImpact();
    malwareController.onItemMerged(); // ← Malware boss: count this merge
    alienController.onItemMerged();   // ← Alien boss: fire laser on milestones
    spaceshipBossController.onItemMerged(); // ← Spaceship boss (L34-35)
    spaceshipBossController.neutralizeThrowAt(tc, tr); // ← cancel any throw at merge target
    spaceshipBossController.neutralizeThrowAt(fc, fr);
    octopusAlienController.onItemMerged(); // ← Octopus alien (L36)
    snakeAlienController.onItemMerged(tc, tr); // ← Snake alien (L37-38)
    snakeAlienController.onMergeAtCell(fc, fr); // ← save adjacent cells too
    snakeAlienController.onMergeAtCell(tc, tr);
    // Data Kraken: cancel countdown if merged from/to a creature-thrown cell
    _cancelCreatureThrowAt(fc, fr);
    _cancelCreatureThrowAt(tc, tr);
    // Robot boss defeat is counted via deliverToRobot() — player must
    // physically drag the merged item onto the Defeat chip (like normal quota).
  }

  /// Called when the player drags a board item onto the Robot Defeat chip.
  /// Removes the item from the grid and registers one robot defeat point.
  void deliverToRobot(int col, int row) {
    if (!robotController.isActive) return;
    final cell = state.grid[col][row];
    if (cell.itemId == null || cell.isBlocked) return;
    // Guard: only accept items that have been merged at least once.
    // spawnerItemId is the raw base item dropped by the board —
    // anything <= that has never been merged, so reject it.
    if (cell.itemId! < state.currentLevel.spawnerItemId + 3) return;

    final newGrid = _cloneGrid();
    newGrid[col][row] = newGrid[col][row].clearItem();
    final anims = [...state.pendingAnimations, PendingAnimation(col, row, AnimType.merge)];
    state = state.copyWith(grid: newGrid, pendingAnimations: anims);

    AudioManager.instance.playMergeSnap();
    HapticFeedback.mediumImpact();
    robotController.onItemMerged();
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

  // ── Locked Item Unlock ────────────────────────────────────────────────────
  void _unlockLockedItem(int fromCol, int fromRow, int toCol, int toRow) {
    final id   = state.grid[fromCol][fromRow].itemId!;
    final next = ItemDictionary.nextItem(id);
    final newGrid = _cloneGrid();
    newGrid[fromCol][fromRow] = newGrid[fromCol][fromRow].clearItem();
    if (next != null) {
      newGrid[toCol][toRow] = GridCell(itemId: next.id);
    } else {
      newGrid[toCol][toRow] = const GridCell();
    }
    final anims = [
      ...state.pendingAnimations,
      PendingAnimation(toCol, toRow, AnimType.merge),
    ];
    state = state.copyWith(grid: newGrid, pendingAnimations: anims);
    AudioManager.instance.playMergeSnap();
    HapticFeedback.lightImpact();
  }

  // ── Mystery Drop Box ─────────────────────────────────────────────────────
  // RNG Loot Table:  60% Trap → instant Energy = 0
  //                  30% Wealth → +100 coins
  //                  10% Ultra Rare → high-tier item placed on board
  void tapSupplyDrop(int col, int row) {
    if (state.supplyDropCol != col || state.supplyDropRow != row) return;
    if (state.activeDialog != ActiveDialog.none) return;

    _supplyDropCountdownTimer?.cancel();
    HapticFeedback.mediumImpact();

    final roll = _rng.nextInt(100);

    if (roll < 60) {
      // 60 %: Lethal Trap — drain Energy to 0
      AudioManager.instance.playErrorBuzz();
      state = state.copyWith(
        energy:              0,
        supplyDropCol:       -1,
        supplyDropRow:       -1,
        supplyDropCountdown: 0,
        activeDialog:        ActiveDialog.zeroEnergy,
        pendingAnimations: [...state.pendingAnimations,
          const PendingAnimation(-1, -1, AnimType.hazardHit)],
      );
      // Don't schedule next drop — level is effectively over (dialog showing)
    } else if (roll < 90) {
      // 30 %: Wealth — +100 coins
      AudioManager.instance.playMergeSnap();
      state = state.copyWith(
        totalCoins:          state.totalCoins + 100,
        supplyDropCol:       -1,
        supplyDropRow:       -1,
        supplyDropCountdown: 0,
      );
      _savePrefs();
      _scheduleNextSupplyDrop();
    } else {
      // 10 %: Ultra Rare — place a high-tier item on the board
      final cfg      = state.currentLevel;
      final rewardId = (cfg.spawnerItemId + 5 + _rng.nextInt(6)).clamp(1, 51);
      final newGrid  = _cloneGrid();

      int rCol = -1, rRow = -1;
      outer:
      for (int c = 0; c < cfg.gridCols; c++) {
        for (int r = 0; r < cfg.gridRows; r++) {
          if (newGrid[c][r].isEmpty) { rCol = c; rRow = r; break outer; }
        }
      }

      if (rCol != -1) newGrid[rCol][rRow] = GridCell(itemId: rewardId);

      AudioManager.instance.playMergeSnap();
      state = state.copyWith(
        grid:               rCol != -1 ? newGrid : state.grid,
        supplyDropCol:      -1,
        supplyDropRow:      -1,
        supplyDropCountdown: 0,
        pendingAnimations: rCol != -1
            ? [...state.pendingAnimations, PendingAnimation(rCol, rRow, AnimType.spawn)]
            : state.pendingAnimations,
      );
      _scheduleNextSupplyDrop();
    }
  }

  void _scheduleNextSupplyDrop() {
    _supplyDropSpawnTimer?.cancel();
    // Random delay 30–45 seconds
    final delay = 30 + _rng.nextInt(16);
    _supplyDropSpawnTimer = Timer(Duration(seconds: delay), _spawnSupplyDrop);
  }

  void _spawnSupplyDrop() {
    if (_disposed) return;
    final cfg = state.currentLevel;
    if (cfg.number < 11 || cfg.number > 50) return;
    if (state.activeDialog != ActiveDialog.none) {
      _scheduleNextSupplyDrop();
      return;
    }

    // Pick a random empty cell
    final empties = <(int, int)>[];
    for (int c = 0; c < cfg.gridCols; c++) {
      for (int r = 0; r < cfg.gridRows; r++) {
        if (state.grid[c][r].isEmpty) empties.add((c, r));
      }
    }
    if (empties.isEmpty) {
      _scheduleNextSupplyDrop();
      return;
    }
    final pick = empties[_rng.nextInt(empties.length)];

    state = state.copyWith(
      supplyDropCol:      pick.$1,
      supplyDropRow:      pick.$2,
      supplyDropCountdown: 10,
    );
    _startSupplyDropCountdown();
  }

  void _startSupplyDropCountdown() {
    _supplyDropCountdownTimer?.cancel();
    _supplyDropCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) { t.cancel(); return; }
      final remaining = state.supplyDropCountdown - 1;
      if (remaining <= 0) {
        t.cancel();
        state = state.copyWith(
          supplyDropCol:      -1,
          supplyDropRow:      -1,
          supplyDropCountdown: 0,
        );
        _scheduleNextSupplyDrop();
      } else {
        state = state.copyWith(supplyDropCountdown: remaining);
      }
    });
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

    // ── NEXUS CORE: Space Station delivery → EMP stun (L40) ──────────────────
    if (nexusCoreController.phase != NexusCorePhase.idle && itemId == 41) {
      nexusCoreController.onSatelliteDelivered();
    }

    // ── WARP SENTINEL: Warp Engine delivery → stun (L41) ─────────────────────
    if (warpSentinelController.phase != WarpSentinelPhase.idle && itemId == 42) {
      warpSentinelController.onWarpEngineDelivered();
    }

    if (state.isLevelComplete) {
      _onLevelComplete();
    }
  }

  // ── Level Complete ────────────────────────────────────────────────────────

  // ── Alien Meteor Landing ──────────────────────────────────────────────────
  void _onAlienMeteorLand(int col, int row) {
    final cfg = state.currentLevel;
    if (col < 0 || col >= cfg.gridCols || row < 0 || row >= cfg.gridRows) return;
    final cell = state.grid[col][row];
    // Only destroy cells that have an item (not empty or blocked)
    if (cell.itemId == null || cell.isBlocked) return;
    final newGrid = _cloneGrid();
    newGrid[col][row] = newGrid[col][row].clearItem();
    // Deduct 3 energy (player HP) — minimum 0
    final newEnergy = (state.energy - 3).clamp(0, state.maxEnergy);
    final anims = [
      ...state.pendingAnimations,
      PendingAnimation(col, row, AnimType.hazardHit),
    ];
    state = state.copyWith(
      grid: newGrid,
      energy: newEnergy,
      pendingAnimations: anims,
    );
    HapticFeedback.mediumImpact();
  }

  // ── Boss cell-destroy callback (L34-38) ──────────────────────────────────

  void _onBossThrowExpire(int col, int row) {
    // Destroy item on that cell
    final cfg  = state.currentLevel;
    if (col < 0 || col >= cfg.gridCols || row < 0 || row >= cfg.gridRows) return;
    final cell = state.grid[col][row];
    if (cell.itemId == null || cell.isBlocked) return;
    final newGrid = _cloneGrid();
    newGrid[col][row] = newGrid[col][row].clearItem();
    // Fire a hazardHit flash so the destruction is visually distinct
    final anims = [
      ...state.pendingAnimations,
      PendingAnimation(col, row, AnimType.hazardHit),
    ];
    // FIX bug2: apply 15 energy penalty when snake alien (L38) destroys an item
    int newEnergy = state.energy;
    if (snakeAlienController.phase == SnakeAlienPhase.active) {
      newEnergy = (state.energy - 15).clamp(0, state.maxEnergy);
      AudioManager.instance.playErrorBuzz();
    }
    state = state.copyWith(grid: newGrid, pendingAnimations: anims, energy: newEnergy);
    HapticFeedback.heavyImpact();
  }

  void _onBossDamage(int damage) {
    final newEnergy = (state.energy - damage).clamp(0, state.maxEnergy);
    state = state.copyWith(energy: newEnergy);
    if (newEnergy <= 0) {
      // Treat as energy-out loss
      _timer?.cancel();
      state = state.copyWith(activeDialog: ActiveDialog.timeFail);
    }
  }

  void _onCoinReward(int coins) {
    state = state.copyWith(levelEarnedCoins: state.levelEarnedCoins + coins);
  }

  void _onAntiGravityPenalty(int coins) {
    final newEarned = (state.levelEarnedCoins - coins).clamp(0, 1 << 30);
    state = state.copyWith(levelEarnedCoins: newEarned);
    AudioManager.instance.playErrorBuzz();
    HapticFeedback.heavyImpact();
  }

  void _onCellBlocked(int col, int row) {
    final cfg = state.currentLevel;
    if (col < 0 || col >= cfg.gridCols || row < 0 || row >= cfg.gridRows) return;
    final newGrid = _cloneGrid();
    newGrid[col][row] = newGrid[col][row].copyWith(obstacle: ObstacleType.lockedCrate);
    state = state.copyWith(grid: newGrid);
  }

  void _onCellUnblocked(int col, int row) {
    final cfg = state.currentLevel;
    if (col < 0 || col >= cfg.gridCols || row < 0 || row >= cfg.gridRows) return;
    final newGrid = _cloneGrid();
    newGrid[col][row] = newGrid[col][row].copyWith(obstacle: ObstacleType.none);
    state = state.copyWith(grid: newGrid);
  }

  void _onLevelComplete() {
    creatureController.onLevelComplete(); // ← Data Kraken win blast
    alienController.onLevelComplete();    // ← Alien boss win blast
    spaceshipBossController.onLevelComplete(); // ← Spaceship boss (L34-35)
    octopusAlienController.onLevelComplete();  // ← Octopus alien (L36)
    snakeAlienController.onLevelComplete();    // ← Snake alien (L38)
    antiGravityController.onLevelComplete();   // ← Anti-Gravity boss (L37)
    nexusCoreController.onLevelComplete();     // ← NEXUS CORE (L40)
    warpSentinelController.onLevelComplete();  // ← WARP SENTINEL (L41)
    terraLichController.onLevelComplete();        // ← TERRA-LICH (L42)
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

  // ── Ad: Zero Energy — Option A (Watch Ad) ────────────────────────────────

  Future<void> watchAdForEnergy() async {
    AudioManager.instance.pauseBgm();
    final shown = await AdManager.instance.showRewarded(onReward: () {
      // Rule 5: reward granted ONLY in onUserEarnedReward.
      // Reset energy to the full cap (100) — not just +50.
      state = state.copyWith(
        energy:       state.maxEnergy,
        activeDialog: ActiveDialog.none,
      );
      AudioManager.instance.resumeBgm();
    });
    if (!shown) {
      // Ad not ready — keep dialog open so the player can retry or spend coins.
      AudioManager.instance.resumeBgm();
    }
  }

  // ── Spend Coins for Energy — Option B (200 Coins → full refill) ───────────

  void spendCoinsForEnergy() {
    const int kEnergyCost = 200;
    if (state.totalCoins < kEnergyCost) return; // safety guard — UI should prevent this
    state = state.copyWith(
      totalCoins:   state.totalCoins - kEnergyCost,
      energy:       state.maxEnergy,
      activeDialog: ActiveDialog.none,
    );
    _savePrefs();
    AudioManager.instance.resumeBgm();
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

  // ── Ad: Victory 3× Reward — fixed 300 coins ──────────────────────────────

  Future<void> watchAdForMultiplier() async {
    if (state.coinsMultiplied) return;
    AudioManager.instance.pauseBgm();
    final shown = await AdManager.instance.showRewarded(onReward: () {
      // Rule 5: coins granted ONLY inside onUserEarnedReward (this closure).
      // Fixed reward: always 300 coins regardless of level base value.
      state = state.copyWith(
        levelEarnedCoins: 300,
        coinsMultiplied:  true,
      );
      // Rule 3 (mutual exclusion): player watched opt-in Rewarded Ad.
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
              itemId:       cell.itemId,
              obstacle:     cell.obstacle,
              isUnlocking:  false,
              lockedItemId: cell.lockedItemId,
              decoyItemId:  cell.decoyItemId,
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

  // ── L41 Glitchy Decoy Helpers ─────────────────────────────────────────────
  //
  // Positions are computed from the 6×6 grid geometry so that the 4 decoys:
  //   • Are always on the OPPOSITE half from the active black hole.
  //   • Sit in corner slots that lie OUTSIDE both holes' 3×3 pull zones:
  //       Hole A (LEFT)  (1,2) → zone cols 0-2, rows 1-3
  //       Hole B (RIGHT) (4,3) → zone cols 3-5, rows 2-4
  //   • Rows 0 and 5 are safe for both holes (outside every pull zone).
  //   • When LEFT hole (bossHoleIndex=0) is active:
  //       5 decoys on RIGHT (opposite) + 3 decoys on LEFT (same side)
  //   • When RIGHT hole (bossHoleIndex=1) is active:
  //       5 decoys on LEFT (opposite) + 3 decoys on RIGHT (same side)
  //   Total: 8 decoys at any time — maximum merge disruption for the player.

  // bossHoleIndex=0 (LEFT active) — 5 on RIGHT side (opposite)
  // RIGHT cols 3-5: zone B covers rows 2-4 → rows 0,1,5 are safe
  static const _kL41OppRight  = [(3,0),(4,1),(5,0),(3,1),(5,5)];
  // bossHoleIndex=0 (LEFT active) — 3 on LEFT side (same)
  // LEFT cols 0-2: zone A covers rows 1-3 → rows 0,4,5 are safe
  static const _kL41SameLeft  = [(0,4),(1,0),(2,4)];

  // bossHoleIndex=1 (RIGHT active) — 5 on LEFT side (opposite)
  // LEFT cols 0-2: zone A covers rows 1-3 → rows 0,4,5 are safe
  static const _kL41OppLeft   = [(0,0),(1,4),(2,0),(0,4),(2,5)];
  // bossHoleIndex=1 (RIGHT active) — 3 on RIGHT side (same)
  // RIGHT cols 3-5: zone B covers rows 2-4 → rows 0,1,5 are safe
  static const _kL41SameRight = [(3,1),(4,0),(5,1)];

  /// Place all 8 L41 glitchy decoys into [cells] (initial grid build).
  void _placeL41DecoysCells(
    List<List<GridCell>> cells,
    int activeBossHoleIndex,
    int gridCols,
    int gridRows,
    int spawnerItemId,
  ) {
    final decoyMimicId = (spawnerItemId + 1).clamp(1, 51);
    final allPositions = activeBossHoleIndex == 0
        ? [..._kL41OppRight, ..._kL41SameLeft]
        : [..._kL41OppLeft,  ..._kL41SameRight];
    for (final pos in allPositions) {
      final c = pos.$1;
      final r = pos.$2;
      if (c < gridCols && r < gridRows) {
        cells[c][r] = GridCell(
          obstacle: ObstacleType.glitchedDecoy,
          decoyItemId: decoyMimicId,
        );
      }
    }
  }

  /// Called when Warp Sentinel teleports — repositions all 8 L41 glitchy
  /// decoys: 5 on the opposite side + 3 on the same side as the new active
  /// black hole. Never displaces existing items; finds the nearest empty cell
  /// on the correct half for any decoy whose preferred spot is occupied.
  void _repositionL41Decoys(int newBossHoleIndex) {
    if (state.activeDialog != ActiveDialog.none) return;
    final cfg = state.currentLevel;
    if (!cfg.hasL41Decoys) return;

    final newGrid      = _cloneGrid();
    final decoyMimicId = (cfg.spawnerItemId + 1).clamp(1, 51);

    // 1. Clear all existing glitchy decoys
    for (int c = 0; c < cfg.gridCols; c++) {
      for (int r = 0; r < cfg.gridRows; r++) {
        if (newGrid[c][r].isDecoy) newGrid[c][r] = const GridCell();
      }
    }

    // 2. Build the two groups for the new active hole
    //    Each group: (preferred positions list, colMin, colMax for fallback)
    final groups = newBossHoleIndex == 0
        ? [(_kL41OppRight,  3, cfg.gridCols - 1),
           (_kL41SameLeft,  0, 2)]
        : [(_kL41OppLeft,   0, 2),
           (_kL41SameRight, 3, cfg.gridCols - 1)];

    final claimed = <(int, int)>{};

    for (final group in groups) {
      final preferred = group.$1 as List<(int, int)>;
      final colMin    = group.$2 as int;
      final colMax    = group.$3 as int;

      for (final pos in preferred) {
        final tc = pos.$1;
        final tr = pos.$2;

        // Preferred cell is free — place directly
        if (tc < cfg.gridCols && tr < cfg.gridRows &&
            newGrid[tc][tr].isEmpty && !claimed.contains((tc, tr))) {
          newGrid[tc][tr] = GridCell(
            obstacle: ObstacleType.glitchedDecoy, decoyItemId: decoyMimicId);
          claimed.add((tc, tr));
          continue;
        }

        // Occupied → find nearest empty cell on the same half (no item moved)
        (int, int)? slot;
        outer:
        for (int c = colMin; c <= colMax; c++) {
          for (int r = 0; r < cfg.gridRows; r++) {
            if (!claimed.contains((c, r)) && newGrid[c][r].isEmpty) {
              slot = (c, r);
              break outer;
            }
          }
        }
        if (slot == null) continue; // grid half full — skip this decoy
        newGrid[slot.$1][slot.$2] = GridCell(
          obstacle: ObstacleType.glitchedDecoy, decoyItemId: decoyMimicId);
        claimed.add(slot);
      }
    }

    state = state.copyWith(grid: newGrid);
  }

  // ── Glitch Timer Helpers ──────────────────────────────────────────────────

  void _startGlitchTimer() {
    _glitchTimer?.cancel();
    final cfg = state.currentLevel;
    if (!cfg.hasDecoys && !cfg.hasL41Decoys) return;
    _glitchTimer = Timer.periodic(
      Duration(seconds: cfg.glitchIntervalSeconds), (_) {
        if (_disposed) return;
        state = state.copyWith(decoyGlitchTick: state.decoyGlitchTick + 1);
      });
  }

  void _startDecoyTeleportTimer() {
    _decoyTeleportTimer?.cancel();
    _decoyTeleportTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_disposed) return;
      _teleportDecoys();
    });
  }

  void _teleportDecoys() {
    if (state.activeDialog != ActiveDialog.none) return;
    final cfg  = state.currentLevel;
    final grid = _cloneGrid();

    // Collect decoy positions and candidate (non-blocked) swap targets
    final decoyPositions = <(int, int)>[];
    final candidates     = <(int, int)>[];
    for (int c = 0; c < cfg.gridCols; c++) {
      for (int r = 0; r < cfg.gridRows; r++) {
        if (grid[c][r].isDecoy)                               decoyPositions.add((c, r));
        else if (!grid[c][r].isBlocked) candidates.add((c, r));
      }
    }
    if (decoyPositions.isEmpty || candidates.isEmpty) return;

    candidates.shuffle(_rng);
    final used = <(int, int)>{};

    for (final decoyPos in decoyPositions) {
      (int, int)? target;
      for (final c in candidates) {
        if (!used.contains(c)) { target = c; used.add(c); break; }
      }
      if (target == null) break;

      final (dc, dr) = decoyPos;
      final (tc, tr) = target;
      final decoyCell  = grid[dc][dr];
      final targetCell = grid[tc][tr];
      grid[dc][dr] = targetCell;
      grid[tc][tr] = decoyCell;
    }

    state = state.copyWith(grid: grid);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _supplyDropSpawnTimer?.cancel();
    _supplyDropCountdownTimer?.cancel();
    _glitchTimer?.cancel();
    _decoyTeleportTimer?.cancel();
    malwareController.dispose();
    robotController.dispose();
    _creatureThrowCdTimer?.cancel();
    creatureController.dispose();
    alienController.dispose();
    spaceshipBossController.dispose();
    octopusAlienController.dispose();
    snakeAlienController.dispose();
    antiGravityController.dispose();
    nexusCoreController.dispose();
    warpSentinelController.dispose();
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
final deletionModeProvider    = Provider<bool>((ref) => ref.watch(gameProvider).deletionModeActive);
final supplyDropProvider      = Provider<(int, int)>((ref) {
  final s = ref.watch(gameProvider);
  return (s.supplyDropCol, s.supplyDropRow);
});
final supplyDropCountdownProvider = Provider<int>((ref) => ref.watch(gameProvider).supplyDropCountdown);
final decoyGlitchTickProvider     = Provider<int>((ref) => ref.watch(gameProvider).decoyGlitchTick);
final creatureThrowsProvider      = Provider<List<CreatureThrow>>((ref) => ref.watch(gameProvider).creatureThrows);
