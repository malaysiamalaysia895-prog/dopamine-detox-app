import { useState } from "react";
import { motion } from "framer-motion";
import { useGameStore } from "../store/useGameStore";
import { LEVELS, PHASE_THEMES } from "../data/gameData";
import { AdManagerService } from "../services/adManager";

export function LevelCompleteModal() {
  const { phase, currentLevel, levelCompleteCoins, multiplyCoins, setPhase, startLevel } = useGameStore();
  const [adWatched, setAdWatched] = useState(false);
  const [collectCoins, setCollectCoins] = useState(0);
  const [awaitingInterstitial, setAwaitingInterstitial] = useState(false);

  if (phase !== "level_complete") return null;

  const cfg = LEVELS[currentLevel];
  const theme = PHASE_THEMES[cfg.theme];
  const isLastLevel = currentLevel === LEVELS.length - 1;

  // Calculate displayed coins
  const displayCoins = adWatched ? levelCompleteCoins * 3 : levelCompleteCoins;

  async function handleWatchAd() {
    // Rule 3: Rewarded ad for 3x coins
    await AdManagerService.showRewardedAd(() => {
      multiplyCoins(3);
      setAdWatched(true);
    });
  }

  async function handleNextLevel() {
    // Collect coins into total
    useGameStore.setState(s => ({
      totalCoins: s.totalCoins + s.levelCompleteCoins,
    }));

    if (isLastLevel) {
      setPhase("menu");
      return;
    }

    // Rule 4: Strict interstitial before loading next level
    setAwaitingInterstitial(true);
    await AdManagerService.showInterstitialAd(() => {
      setAwaitingInterstitial(false);
      startLevel(currentLevel + 1);
    });
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="fixed inset-0 z-40 flex items-center justify-center bg-black/80 p-4"
    >
      <motion.div
        initial={{ scale: 0.8, y: 40 }}
        animate={{ scale: 1, y: 0 }}
        transition={{ type: "spring", stiffness: 300, damping: 20 }}
        className="w-full max-w-sm rounded-2xl overflow-hidden border border-white/10"
        style={{
          background: `linear-gradient(135deg, ${theme.primary}22, #000)`,
          borderColor: theme.primary + "44",
        }}
      >
        {/* Header */}
        <div className="p-6 text-center relative overflow-hidden">
          {/* Star burst */}
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1, rotate: [0, 15, -10, 5, 0] }}
            transition={{ delay: 0.2, type: "spring" }}
            className="text-7xl mb-2"
          >
            🏆
          </motion.div>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
            className="text-white font-black text-2xl"
          >
            Level {cfg.level} Complete!
          </motion.h2>
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.4 }}
            className="text-white/60 text-sm mt-1"
          >
            {cfg.story}
          </motion.p>
        </div>

        {/* Coin reward */}
        <div className="mx-4 mb-4 p-4 rounded-xl bg-black/40 border border-white/10 text-center">
          <p className="text-white/50 text-xs mb-1">Coins Earned</p>
          <motion.div
            key={displayCoins}
            initial={{ scale: 1.4 }}
            animate={{ scale: 1 }}
            className="text-yellow-400 font-black text-4xl"
          >
            💰 {displayCoins.toLocaleString()}
          </motion.div>
          {adWatched && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="text-green-400 text-xs font-bold mt-1"
            >
              ✓ 3X MULTIPLIER APPLIED!
            </motion.div>
          )}
        </div>

        {/* Actions */}
        <div className="px-4 pb-6 flex flex-col gap-3">
          {/* Rule 3: 3x ad button */}
          {!adWatched && (
            <motion.button
              whileTap={{ scale: 0.97 }}
              onClick={handleWatchAd}
              className="w-full py-4 rounded-xl font-black text-lg text-black border-2 border-yellow-300"
              style={{ background: `linear-gradient(135deg, #FFD700, #FFA500)` }}
              animate={{
                boxShadow: ["0 0 10px #FFD70088", "0 0 25px #FFD700bb", "0 0 10px #FFD70088"],
              }}
              transition={{ boxShadow: { repeat: Infinity, duration: 1.5 } }}
            >
              📺 Watch Ad to get 3X Coins!
            </motion.button>
          )}

          {/* Next level button — triggers interstitial (Rule 4) */}
          <button
            onClick={handleNextLevel}
            disabled={awaitingInterstitial}
            className="w-full py-3 rounded-xl font-bold text-white border border-white/20 bg-white/10 disabled:opacity-50"
          >
            {awaitingInterstitial
              ? "Loading..."
              : isLastLevel
              ? "🎉 Back to Menu"
              : "Next Level →"}
          </button>
        </div>
      </motion.div>
    </motion.div>
  );
}
