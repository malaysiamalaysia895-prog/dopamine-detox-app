import { useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useGameStore } from "../store/useGameStore";
import { LEVELS, PHASE_THEMES } from "../data/gameData";
import { GameHUD } from "../components/GameHUD";
import { GameGrid } from "../components/GameGrid";
import { Spawner } from "../components/Spawner";
import { LevelCompleteModal } from "../components/LevelCompleteModal";
import { GameOverModal } from "../components/GameOverModal";

export function GamePage() {
  const { currentLevel, phase, setPhase } = useGameStore();

  if (phase === "menu") return null;

  const cfg = LEVELS[currentLevel];
  if (!cfg) return null;

  const theme = PHASE_THEMES[cfg.theme];

  return (
    <motion.div
      key={`level-${currentLevel}`}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className={`min-h-screen flex flex-col bg-gradient-to-br ${theme.bg} relative overflow-hidden`}
    >
      {/* Ambient glow background */}
      <div
        className="absolute inset-0 opacity-20 pointer-events-none"
        style={{
          background: `radial-gradient(ellipse at 50% 0%, ${theme.primary}44, transparent 60%)`,
        }}
      />

      {/* Phase banner */}
      <div
        className="relative px-3 pt-1 pb-0.5 text-center text-[9px] font-bold tracking-widest uppercase border-b border-white/5"
        style={{ color: theme.accent }}
      >
        Phase {cfg.phase}: {theme.name}
      </div>

      {/* Back button */}
      <button
        onClick={() => setPhase("menu")}
        className="absolute top-5 left-3 z-10 text-white/30 hover:text-white/70 text-sm transition-colors"
      >
        ← Menu
      </button>

      {/* HUD */}
      <GameHUD />

      {/* Grid */}
      <GameGrid />

      {/* Spawner */}
      <Spawner />

      {/* Modals */}
      <LevelCompleteModal />
      <GameOverModal />
    </motion.div>
  );
}
