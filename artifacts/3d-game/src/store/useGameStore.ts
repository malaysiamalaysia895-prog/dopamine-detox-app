import { create } from "zustand";
import { LEVELS, LevelConfig, getItemById, getNextItem, getBaseItemForPhase, ITEM_CHAINS } from "../data/gameData";

export type CellObstacle = "dusty_web" | "locked_crate" | "black_hole" | null;

export interface GridCell {
  id: string;           // unique cell key "col-row"
  col: number;
  row: number;
  itemId: string | null;
  obstacle: CellObstacle;
  locked: boolean;      // true = obstacle is active, item cannot be placed
}

export interface GameState {
  // Progress
  currentLevel: number;
  coins: number;
  totalCoins: number;

  // Energy
  energy: number;
  maxEnergy: number;

  // Grid
  grid: GridCell[][];

  // UI States
  phase: "playing" | "level_complete" | "game_over" | "menu";
  levelCompleteCoins: number;
  adState: "none" | "rewarded_pending" | "interstitial_pending";
  showEnergyWarning: boolean;

  // Timed order
  timerSeconds: number;
  timerActive: boolean;
}

interface GameActions {
  startLevel: (levelIndex: number) => void;
  spawnItem: (col: number, row: number) => void;
  moveItem: (fromCol: number, fromRow: number, toCol: number, toRow: number) => void;
  addEnergy: (amount: number) => void;
  completeLevel: () => void;
  multiplyCoins: (factor: number) => void;
  setPhase: (phase: GameState["phase"]) => void;
  tickTimer: () => void;
  resetTimer: () => void;
  dismissEnergyWarning: () => void;
  getCurrentLevelConfig: () => LevelConfig;
}

const MAX_ENERGY = 100;

function buildGrid(cfg: LevelConfig): GridCell[][] {
  const grid: GridCell[][] = [];
  for (let c = 0; c < cfg.gridCols; c++) {
    grid[c] = [];
    for (let r = 0; r < cfg.gridRows; r++) {
      grid[c][r] = {
        id: `${c}-${r}`,
        col: c, row: r,
        itemId: null,
        obstacle: null,
        locked: false,
      };
    }
  }

  // Place obstacles randomly
  const totalCells = cfg.gridCols * cfg.gridRows;
  const allPositions: [number, number][] = [];
  for (let c = 0; c < cfg.gridCols; c++)
    for (let r = 0; r < cfg.gridRows; r++)
      allPositions.push([c, r]);

  const shuffled = [...allPositions].sort(() => Math.random() - 0.5);
  let obsIdx = 0;

  // Place 1-2 of each obstacle type
  for (const obs of cfg.obstacles) {
    const count = obs === "black_hole" ? Math.min(2, Math.floor(totalCells * 0.08)) : 1;
    for (let i = 0; i < count && obsIdx < shuffled.length; i++, obsIdx++) {
      const [c, r] = shuffled[obsIdx];
      if (obs === "black_hole") {
        grid[c][r].obstacle = "black_hole";
        grid[c][r].locked = true;
      } else if (obs === "dusty_web") {
        grid[c][r].obstacle = "dusty_web";
        grid[c][r].locked = true;
      } else if (obs === "locked_crate") {
        grid[c][r].obstacle = "locked_crate";
        grid[c][r].locked = true;
      }
    }
  }

  // Pre-place starter items on non-obstacle cells
  const baseItem = getBaseItemForPhase(cfg.theme);
  const freeCells = allPositions.filter(([c, r]) => !grid[c][r].obstacle);
  const starterCount = Math.min(Math.max(1, Math.floor(totalCells * 0.15)), freeCells.length);
  for (let i = 0; i < starterCount; i++) {
    const [c, r] = freeCells[i];
    grid[c][r].itemId = baseItem.id;
  }

  return grid;
}

function isAdjacentToFreeCell(grid: GridCell[][], col: number, row: number): boolean {
  const dirs = [[-1,0],[1,0],[0,-1],[0,1]];
  for (const [dc, dr] of dirs) {
    const nc = col + dc, nr = row + dr;
    if (nc >= 0 && nr >= 0 && nc < grid.length && nr < grid[0].length) {
      if (!grid[nc][nr].obstacle || grid[nc][nr].obstacle === "dusty_web" || grid[nc][nr].obstacle === "locked_crate") {
        // adjacent cell exists
        return true;
      }
    }
  }
  return false;
}

function tryUnlockAdjacentObstacles(grid: GridCell[][], col: number, row: number) {
  const dirs = [[-1,0],[1,0],[0,-1],[0,1]];
  for (const [dc, dr] of dirs) {
    const nc = col + dc, nr = row + dr;
    if (nc >= 0 && nr >= 0 && nc < grid.length && nr < grid[0].length) {
      const cell = grid[nc][nr];
      if (cell.obstacle === "dusty_web" || cell.obstacle === "locked_crate") {
        cell.obstacle = null;
        cell.locked = false;
      }
    }
  }
}

function checkLevelComplete(grid: GridCell[][], targetItemId: string): boolean {
  for (const col of grid) {
    for (const cell of col) {
      if (cell.itemId === targetItemId) return true;
    }
  }
  return false;
}

export const useGameStore = create<GameState & GameActions>((set, get) => ({
  currentLevel: 0,
  coins: 0,
  totalCoins: 0,
  energy: 100,
  maxEnergy: MAX_ENERGY,
  grid: [],
  phase: "menu",
  levelCompleteCoins: 0,
  adState: "none",
  showEnergyWarning: false,
  timerSeconds: 0,
  timerActive: false,

  getCurrentLevelConfig: () => LEVELS[get().currentLevel],

  startLevel: (levelIndex: number) => {
    const cfg = LEVELS[levelIndex];
    if (!cfg) return;
    const grid = buildGrid(cfg);
    set({
      currentLevel: levelIndex,
      grid,
      phase: "playing",
      adState: "none",
      levelCompleteCoins: 0,
      showEnergyWarning: false,
      timerActive: cfg.obstacles.includes("timed_order"),
      timerSeconds: cfg.timedOrderSeconds ?? 0,
    });
  },

  spawnItem: (col: number, row: number) => {
    const state = get();
    const cfg = LEVELS[state.currentLevel];
    const cell = state.grid[col]?.[row];

    if (!cell || cell.locked || cell.obstacle === "black_hole") return;
    if (cell.itemId !== null) return; // occupied

    // Energy check
    if (state.energy === 0) {
      set({ showEnergyWarning: true });
      return;
    }

    const energyCost = cfg.energyCostPerSpawn * (cfg.fasterEnergyDrain ? 1.5 : 1);
    const baseItem = getBaseItemForPhase(cfg.theme);

    const newGrid = state.grid.map(col => col.map(c => ({ ...c })));
    newGrid[col][row] = { ...newGrid[col][row], itemId: baseItem.id };

    const newEnergy = Math.max(0, state.energy - energyCost);
    set({
      grid: newGrid,
      energy: newEnergy,
      showEnergyWarning: newEnergy === 0,
    });
  },

  moveItem: (fromCol: number, fromRow: number, toCol: number, toRow: number) => {
    const state = get();
    const fromCell = state.grid[fromCol]?.[fromRow];
    const toCell = state.grid[toCol]?.[toRow];

    if (!fromCell || !toCell) return;
    if (fromCell.itemId === null) return;
    if (toCell.locked || toCell.obstacle === "black_hole") {
      // Moving into black hole destroys the item
      if (toCell.obstacle === "black_hole") {
        const newGrid = state.grid.map(col => col.map(c => ({ ...c })));
        newGrid[fromCol][fromRow] = { ...newGrid[fromCol][fromRow], itemId: null };
        set({ grid: newGrid });
      }
      return;
    }

    const cfg = LEVELS[state.currentLevel];
    const newGrid = state.grid.map(col => col.map(c => ({ ...c })));

    if (toCell.itemId === null) {
      // Simple move
      newGrid[toCol][toRow] = { ...newGrid[toCol][toRow], itemId: fromCell.itemId };
      newGrid[fromCol][fromRow] = { ...newGrid[fromCol][fromRow], itemId: null };
      tryUnlockAdjacentObstacles(newGrid, toCol, toRow);
    } else if (toCell.itemId === fromCell.itemId) {
      // Merge!
      const merged = getNextItem(fromCell.itemId);
      if (merged) {
        newGrid[toCol][toRow] = { ...newGrid[toCol][toRow], itemId: merged.id };
        newGrid[fromCol][fromRow] = { ...newGrid[fromCol][fromRow], itemId: null };
        tryUnlockAdjacentObstacles(newGrid, toCol, toRow);

        // Check win condition
        if (checkLevelComplete(newGrid, cfg.targetItemId)) {
          set({ grid: newGrid });
          get().completeLevel();
          return;
        }
      }
    } else {
      // Swap
      newGrid[toCol][toRow] = { ...newGrid[toCol][toRow], itemId: fromCell.itemId };
      newGrid[fromCol][fromRow] = { ...newGrid[fromCol][fromRow], itemId: toCell.itemId };
    }

    set({ grid: newGrid });
  },

  addEnergy: (amount: number) => {
    const state = get();
    const newEnergy = Math.min(MAX_ENERGY, state.energy + amount);
    set({ energy: newEnergy, showEnergyWarning: newEnergy === 0 });
  },

  completeLevel: () => {
    const state = get();
    const cfg = LEVELS[state.currentLevel];
    set({
      phase: "level_complete",
      levelCompleteCoins: cfg.baseCoins,
      timerActive: false,
    });
  },

  multiplyCoins: (factor: number) => {
    set(s => ({
      levelCompleteCoins: s.levelCompleteCoins * factor,
    }));
  },

  setPhase: (phase) => set({ phase }),

  tickTimer: () => {
    const state = get();
    if (!state.timerActive || state.timerSeconds <= 0) return;
    const newTime = state.timerSeconds - 1;
    if (newTime <= 0) {
      set({ timerSeconds: 0, timerActive: false, phase: "game_over" });
    } else {
      set({ timerSeconds: newTime });
    }
  },

  resetTimer: () => {
    const cfg = LEVELS[get().currentLevel];
    set({
      timerSeconds: cfg.timedOrderSeconds ?? 0,
      timerActive: cfg.obstacles.includes("timed_order"),
    });
  },

  dismissEnergyWarning: () => set({ showEnergyWarning: false }),
}));
