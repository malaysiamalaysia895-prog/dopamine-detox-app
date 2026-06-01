import { create } from "zustand";
import { LEVELS, LevelConfig, getNextItem, getBaseItemForPhase } from "../data/gameData";

export type CellObstacle = "dusty_web" | "locked_crate" | "black_hole" | null;

export interface GridCell {
  id: string;
  col: number;
  row: number;
  itemId: string | null;
  obstacle: CellObstacle;
  locked: boolean;
}

export interface GameState {
  currentLevel: number;
  coins: number;
  totalCoins: number;
  energy: number;
  maxEnergy: number;
  grid: GridCell[][];
  phase: "playing" | "level_complete" | "game_over" | "menu";
  levelCompleteCoins: number;
  showEnergyWarning: boolean;
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
  dismissEnergyWarning: () => void;
  getCurrentLevelConfig: () => LevelConfig;
}

const MAX_ENERGY = 100;

function buildGrid(cfg: LevelConfig): GridCell[][] {
  const grid: GridCell[][] = [];
  for (let c = 0; c < cfg.gridCols; c++) {
    grid[c] = [];
    for (let r = 0; r < cfg.gridRows; r++) {
      grid[c][r] = { id: `${c}-${r}`, col: c, row: r, itemId: null, obstacle: null, locked: false };
    }
  }

  const allPositions: [number, number][] = [];
  for (let c = 0; c < cfg.gridCols; c++)
    for (let r = 0; r < cfg.gridRows; r++)
      allPositions.push([c, r]);

  const shuffled = [...allPositions].sort(() => Math.random() - 0.5);
  let obsIdx = 0;

  for (const obs of cfg.obstacles) {
    const count = obs === "black_hole"
      ? Math.min(3, Math.floor(cfg.gridCols * cfg.gridRows * 0.08))
      : 1;
    for (let i = 0; i < count && obsIdx < shuffled.length; i++, obsIdx++) {
      const [c, r] = shuffled[obsIdx];
      grid[c][r].obstacle = obs as CellObstacle;
      grid[c][r].locked = true;
    }
  }

  // Seed a few base items on free cells
  const baseItem = getBaseItemForPhase(cfg.theme);
  const freeCells = allPositions.filter(([c, r]) => !grid[c][r].obstacle);
  const starterCount = Math.min(Math.max(2, Math.floor(freeCells.length * 0.18)), freeCells.length);
  for (let i = 0; i < starterCount; i++) {
    const [c, r] = freeCells[i];
    grid[c][r].itemId = baseItem.id;
  }

  return grid;
}

function tryUnlockAdjacent(grid: GridCell[][], col: number, row: number) {
  const dirs = [[-1,0],[1,0],[0,-1],[0,1]];
  for (const [dc, dr] of dirs) {
    const nc = col + dc, nr = row + dr;
    if (nc >= 0 && nr >= 0 && nc < grid.length && nr < (grid[0]?.length ?? 0)) {
      const cell = grid[nc][nr];
      if (cell.obstacle === "dusty_web" || cell.obstacle === "locked_crate") {
        cell.obstacle = null;
        cell.locked = false;
      }
    }
  }
}

function checkWin(grid: GridCell[][], targetItemId: string): boolean {
  return grid.some(col => col.some(cell => cell.itemId === targetItemId));
}

export const useGameStore = create<GameState & GameActions>((set, get) => ({
  currentLevel: 0,
  coins: 0,
  totalCoins: 0,
  energy: MAX_ENERGY,
  maxEnergy: MAX_ENERGY,
  grid: [],
  phase: "menu",
  levelCompleteCoins: 0,
  showEnergyWarning: false,
  timerSeconds: 0,
  timerActive: false,

  getCurrentLevelConfig: () => LEVELS[get().currentLevel],

  startLevel: (levelIndex: number) => {
    const cfg = LEVELS[levelIndex];
    if (!cfg) return;
    set({
      currentLevel: levelIndex,
      grid: buildGrid(cfg),
      phase: "playing",
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
    if (cell.itemId !== null) return;

    // ── Rule 2 gate: only show lockout wall if level allows it ──────────────
    if (state.energy === 0) {
      if (cfg.allowZeroEnergyLockout) set({ showEnergyWarning: true });
      return;
    }

    const rawCost = cfg.energyCostPerSpawn * (cfg.fasterEnergyDrain ? 1.5 : 1);
    const energyCost = Math.round(rawCost);
    const baseItem = getBaseItemForPhase(cfg.theme);

    const newGrid = state.grid.map(col => col.map(c => ({ ...c })));
    newGrid[col][row] = { ...newGrid[col][row], itemId: baseItem.id };
    const newEnergy = Math.max(0, state.energy - energyCost);

    set({ grid: newGrid, energy: newEnergy, showEnergyWarning: false });
  },

  moveItem: (fromCol, fromRow, toCol, toRow) => {
    const state = get();
    const fromCell = state.grid[fromCol]?.[fromRow];
    const toCell   = state.grid[toCol]?.[toRow];
    if (!fromCell || !toCell || fromCell.itemId === null) return;

    // Black hole destroys the dragged item
    if (toCell.obstacle === "black_hole") {
      const newGrid = state.grid.map(c => c.map(cell => ({ ...cell })));
      newGrid[fromCol][fromRow] = { ...newGrid[fromCol][fromRow], itemId: null };
      set({ grid: newGrid });
      return;
    }

    if (toCell.locked) return;

    const cfg = LEVELS[state.currentLevel];
    const newGrid = state.grid.map(c => c.map(cell => ({ ...cell })));

    if (toCell.itemId === null) {
      // Simple move
      newGrid[toCol][toRow]   = { ...newGrid[toCol][toRow],   itemId: fromCell.itemId };
      newGrid[fromCol][fromRow] = { ...newGrid[fromCol][fromRow], itemId: null };
      tryUnlockAdjacent(newGrid, toCol, toRow);
    } else if (toCell.itemId === fromCell.itemId) {
      // Merge → next tier
      const merged = getNextItem(fromCell.itemId);
      if (merged) {
        newGrid[toCol][toRow]   = { ...newGrid[toCol][toRow],   itemId: merged.id };
        newGrid[fromCol][fromRow] = { ...newGrid[fromCol][fromRow], itemId: null };
        tryUnlockAdjacent(newGrid, toCol, toRow);
        set({ grid: newGrid });
        if (checkWin(newGrid, cfg.targetItemId)) { get().completeLevel(); }
        return;
      }
    } else {
      // Swap
      newGrid[toCol][toRow]   = { ...newGrid[toCol][toRow],   itemId: fromCell.itemId };
      newGrid[fromCol][fromRow] = { ...newGrid[fromCol][fromRow], itemId: toCell.itemId };
    }

    set({ grid: newGrid });
  },

  addEnergy: (amount) => {
    set(s => ({
      energy: Math.min(MAX_ENERGY, s.energy + amount),
      showEnergyWarning: false,
    }));
  },

  completeLevel: () => {
    const cfg = LEVELS[get().currentLevel];
    set({ phase: "level_complete", levelCompleteCoins: cfg.baseCoins, timerActive: false });
  },

  // ── Rule 3: called inside rewarded ad onSuccess callback ──────────────────
  multiplyCoins: (factor) => {
    set(s => ({ levelCompleteCoins: s.levelCompleteCoins * factor }));
  },

  setPhase: (phase) => set({ phase }),

  tickTimer: () => {
    const { timerActive, timerSeconds } = get();
    if (!timerActive || timerSeconds <= 0) return;
    const next = timerSeconds - 1;
    if (next <= 0) set({ timerSeconds: 0, timerActive: false, phase: "game_over" });
    else set({ timerSeconds: next });
  },

  dismissEnergyWarning: () => set({ showEnergyWarning: false }),
}));
