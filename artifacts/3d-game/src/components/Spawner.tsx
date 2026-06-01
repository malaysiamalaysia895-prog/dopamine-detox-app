import { motion } from "framer-motion";
import { useGameStore } from "../store/useGameStore";
import { LEVELS, PHASE_THEMES, getBaseItemForPhase } from "../data/gameData";

export function Spawner() {
  const { currentLevel, energy, grid, spawnItem } = useGameStore();
  const cfg = LEVELS[currentLevel];
  if (!cfg) return null;

  const theme = PHASE_THEMES[cfg.theme];
  const baseItem = getBaseItemForPhase(cfg.theme);

  // Find first empty non-locked cell
  function findEmptyCell(): [number, number] | null {
    for (let c = 0; c < cfg.gridCols; c++) {
      for (let r = 0; r < cfg.gridRows; r++) {
        const cell = grid[c]?.[r];
        if (cell && !cell.itemId && !cell.locked) return [c, r];
      }
    }
    return null;
  }

  function handleSpawn() {
    const target = findEmptyCell();
    if (target) spawnItem(target[0], target[1]);
  }

  const empty = findEmptyCell();
  const canSpawn = energy > 0 && empty !== null;

  return (
    <div className="px-3 pb-3 flex flex-col items-center gap-2">
      <p className="text-white/40 text-[10px] uppercase tracking-widest">Spawner</p>
      <motion.button
        onClick={handleSpawn}
        disabled={energy === 0}
        whileTap={{ scale: 0.92 }}
        animate={canSpawn ? {
          boxShadow: [
            `0 0 10px ${theme.primary}55`,
            `0 0 22px ${theme.primary}99`,
            `0 0 10px ${theme.primary}55`,
          ]
        } : {}}
        transition={{ boxShadow: { repeat: Infinity, duration: 1.8 } }}
        className="flex items-center gap-3 px-6 py-3 rounded-2xl border-2 font-bold text-white text-base disabled:opacity-40"
        style={{
          borderColor: canSpawn ? theme.primary : "#ffffff22",
          background: canSpawn
            ? `linear-gradient(135deg, ${theme.primary}33, ${theme.secondary}11)`
            : "rgba(255,255,255,0.05)",
        }}
      >
        <span className="text-2xl">{baseItem.emoji}</span>
        <span className="flex flex-col items-start">
          <span className="text-sm font-black">Spawn {baseItem.name}</span>
          <span className="text-[10px] text-white/50">-{cfg.energyCostPerSpawn * (cfg.fasterEnergyDrain ? 1.5 : 1)} ⚡</span>
        </span>
        <span className="ml-1 text-lg">⚡{energy}</span>
      </motion.button>
    </div>
  );
}
