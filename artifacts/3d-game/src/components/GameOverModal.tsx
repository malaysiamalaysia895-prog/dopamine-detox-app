import { motion } from "framer-motion";
import { useGameStore } from "../store/useGameStore";
import { LEVELS } from "../data/gameData";
import { AdManagerService } from "../services/adManager";

export function GameOverModal() {
  const { phase, currentLevel, startLevel, setPhase, addEnergy } = useGameStore();

  if (phase !== "game_over") return null;

  const cfg = LEVELS[currentLevel];

  async function watchAdRetry() {
    await AdManagerService.showRewardedAd(() => {
      addEnergy(50);
      startLevel(currentLevel);
    });
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="fixed inset-0 z-40 flex items-center justify-center bg-black/85 p-4"
    >
      <motion.div
        initial={{ scale: 0.8 }}
        animate={{ scale: 1 }}
        transition={{ type: "spring", stiffness: 300, damping: 22 }}
        className="w-full max-w-sm bg-gradient-to-br from-red-950 to-gray-950 rounded-2xl p-6 text-center border border-red-800"
      >
        <div className="text-6xl mb-3">⏰</div>
        <h2 className="text-white font-black text-2xl mb-2">Time's Up!</h2>
        <p className="text-white/60 text-sm mb-6">
          Level {cfg.level}: {cfg.title} — Order expired. Try again!
        </p>

        <button
          onClick={watchAdRetry}
          className="w-full py-4 rounded-xl bg-gradient-to-r from-yellow-400 to-orange-400 text-black font-black text-lg mb-3"
        >
          📺 Watch Ad to Retry
        </button>

        <button
          onClick={() => startLevel(currentLevel)}
          className="w-full py-3 rounded-xl border border-white/20 text-white font-bold"
        >
          Restart Level
        </button>

        <button
          onClick={() => setPhase("menu")}
          className="mt-3 text-white/40 text-sm underline"
        >
          Main Menu
        </button>
      </motion.div>
    </motion.div>
  );
}
