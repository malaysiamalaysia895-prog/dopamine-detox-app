import { motion } from "framer-motion";
import { useGameStore } from "../store/useGameStore";
import { LEVELS, PHASE_THEMES } from "../data/gameData";

const PHASES = [
  { phase: 1, theme: "garage" as const, levels: "1-10", name: "The Garage Startup" },
  { phase: 2, theme: "office" as const, levels: "11-20", name: "The Office Upgrade" },
  { phase: 3, theme: "silicon" as const, levels: "21-30", name: "Silicon Valley Tycoon" },
  { phase: 4, theme: "megacorp" as const, levels: "31-40", name: "Global Mega-Corp" },
  { phase: 5, theme: "universe" as const, levels: "41-50", name: "Masters of the Universe" },
];

export function MenuPage() {
  const { totalCoins, startLevel } = useGameStore();

  return (
    <div className="min-h-screen bg-black flex flex-col overflow-y-auto">
      {/* Hero */}
      <div className="relative overflow-hidden flex flex-col items-center py-12 px-4">
        <div
          className="absolute inset-0 opacity-30"
          style={{
            background: "radial-gradient(ellipse at 50% 30%, #6600cc, #003366, #000)",
          }}
        />
        <motion.div
          initial={{ scale: 0, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ type: "spring", stiffness: 200 }}
          className="relative text-7xl mb-3"
        >
          🖥️
        </motion.div>
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="relative text-center font-black text-4xl text-white leading-tight"
        >
          Tech Tycoon
          <br />
          <span className="text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-purple-400">
            Merge
          </span>
        </motion.h1>
        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.35 }}
          className="relative text-white/50 text-sm mt-2 text-center"
        >
          50 Levels · 5 Phases · From Garage to Galaxy
        </motion.p>
        {totalCoins > 0 && (
          <div className="relative mt-3 px-4 py-1.5 bg-yellow-900/40 border border-yellow-500/30 rounded-full">
            <span className="text-yellow-400 font-bold text-sm">💰 {totalCoins.toLocaleString()} coins</span>
          </div>
        )}
      </div>

      {/* Start buttons */}
      <div className="px-4 pb-2">
        <motion.button
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.45 }}
          whileTap={{ scale: 0.97 }}
          onClick={() => startLevel(0)}
          className="w-full py-4 rounded-2xl font-black text-xl text-black"
          style={{ background: "linear-gradient(135deg, #00E5FF, #0080FF)" }}
        >
          ▶ Start Game
        </motion.button>
      </div>

      {/* Phase preview */}
      <div className="px-4 pb-8 mt-4 flex flex-col gap-3">
        <h2 className="text-white/40 text-xs uppercase tracking-widest text-center">5 Epic Phases</h2>
        {PHASES.map((p, i) => {
          const colors = PHASE_THEMES[p.theme];
          const firstLevel = LEVELS.find(l => l.phase === p.phase)!;
          return (
            <motion.button
              key={p.phase}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.5 + i * 0.07 }}
              whileTap={{ scale: 0.98 }}
              onClick={() => startLevel((p.phase - 1) * 10)}
              className="flex items-center gap-3 px-4 py-3 rounded-xl border text-left"
              style={{ borderColor: colors.primary + "44", background: colors.primary + "11" }}
            >
              <div
                className="w-10 h-10 rounded-lg flex items-center justify-center text-xl flex-shrink-0"
                style={{ background: colors.primary + "33" }}
              >
                {p.phase === 1 ? "🔌" : p.phase === 2 ? "💻" : p.phase === 3 ? "🥽" : p.phase === 4 ? "🧠" : "☀️"}
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-bold text-white text-sm truncate">{p.name}</div>
                <div className="text-white/40 text-xs">Levels {p.levels}</div>
              </div>
              <div className="text-white/30 text-xs">{p.theme === "silicon" || p.theme === "universe" ? "⚡Fast drain" : ""}</div>
              <span style={{ color: colors.primary }} className="font-bold text-sm">→</span>
            </motion.button>
          );
        })}
      </div>
    </div>
  );
}
