import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useGameStore } from "../store/useGameStore";
import { LEVELS, PHASE_THEMES } from "../data/gameData";
import { AdManagerService } from "../services/adManager";

export function LevelCompleteModal() {
  const {
    phase, currentLevel, levelCompleteCoins,
    multiplyCoins, setPhase, startLevel,
  } = useGameStore();

  const [adWatched, setAdWatched] = useState(false);
  const [awaitingInterstitial, setAwaitingInterstitial] = useState(false);

  if (phase !== "level_complete") return null;

  const cfg = LEVELS[currentLevel];
  const theme = PHASE_THEMES[cfg.theme];
  const isLastLevel = currentLevel === LEVELS.length - 1;

  // The coins shown already reflect any multiplier applied to levelCompleteCoins in the store
  const displayCoins = adWatched ? levelCompleteCoins : levelCompleteCoins;

  // ── Rule 3: Watch rewarded ad for 3× coins (allowScoreMultiplier gate) ─────
  async function handleWatchAd() {
    if (!cfg.allowScoreMultiplier) return;
    await AdManagerService.showRewardedAd(() => {
      // onSuccess fires only on full ad completion — multiply coins now
      multiplyCoins(3);
      setAdWatched(true);
    });
  }

  // ── Rule 4: Interstitial fires on every "Next Level" tap (triggerInterstitialNext gate) ──
  async function handleNextLevel() {
    // Collect coins into running total first
    useGameStore.setState(s => ({
      totalCoins: s.totalCoins + s.levelCompleteCoins,
    }));

    if (isLastLevel) {
      setPhase("menu");
      return;
    }

    if (cfg.triggerInterstitialNext) {
      // Strictly block next level load until interstitial onDismiss fires
      setAwaitingInterstitial(true);
      await AdManagerService.showInterstitialAd(() => {
        setAwaitingInterstitial(false);
        startLevel(currentLevel + 1);
      });
    } else {
      startLevel(currentLevel + 1);
    }
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
        className="w-full max-w-sm rounded-2xl overflow-hidden border"
        style={{
          background: `linear-gradient(135deg, ${theme.primary}22, #000)`,
          borderColor: theme.primary + "44",
        }}
      >
        {/* ── Header ── */}
        <div className="p-6 text-center">
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

        {/* ── Coin reward ── */}
        <div className="mx-4 mb-4 p-4 rounded-xl bg-black/40 border border-white/10 text-center">
          <p className="text-white/50 text-xs mb-1">Coins Earned</p>
          <motion.div
            key={levelCompleteCoins}
            initial={{ scale: 1.3 }}
            animate={{ scale: 1 }}
            className="text-yellow-400 font-black text-4xl"
          >
            💰 {levelCompleteCoins.toLocaleString()}
          </motion.div>
          <AnimatePresence>
            {adWatched && (
              <motion.div
                initial={{ opacity: 0, y: -6 }}
                animate={{ opacity: 1, y: 0 }}
                className="text-green-400 text-xs font-bold mt-1"
              >
                ✓ 3× MULTIPLIER APPLIED!
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        {/* ── Actions ── */}
        <div className="px-4 pb-6 flex flex-col gap-3">
          {/* Rule 3 — 3× ad button, only rendered when allowScoreMultiplier is true */}
          {cfg.allowScoreMultiplier && !adWatched && (
            <motion.button
              whileTap={{ scale: 0.97 }}
              onClick={handleWatchAd}
              className="w-full py-4 rounded-xl font-black text-lg text-black border-2 border-yellow-300"
              style={{ background: "linear-gradient(135deg, #FFD700, #FFA500)" }}
              animate={{
                boxShadow: [
                  "0 0 10px #FFD70088",
                  "0 0 28px #FFD700cc",
                  "0 0 10px #FFD70088",
                ],
              }}
              transition={{ boxShadow: { repeat: Infinity, duration: 1.5 } }}
            >
              📺 Watch Ad to get 3× Coins!
            </motion.button>
          )}

          {/* Rule 4 — Next Level, fires interstitial when triggerInterstitialNext is true.
              The next level's grid ONLY loads inside the onDismiss callback. */}
          <button
            onClick={handleNextLevel}
            disabled={awaitingInterstitial}
            className="w-full py-3 rounded-xl font-bold text-white border border-white/20 bg-white/10 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {awaitingInterstitial
              ? "⏳ Loading ad…"
              : isLastLevel
              ? "🎉 Back to Menu"
              : cfg.triggerInterstitialNext
              ? "Next Level →"   // interstitial fires first
              : "Next Level →"}
          </button>

          {/* Interstitial unit ID badge (shown while awaiting) */}
          {awaitingInterstitial && (
            <p className="text-center text-[10px] text-white/30">
              Interstitial · {cfg.interstitialAdUnitId}
            </p>
          )}
        </div>
      </motion.div>
    </motion.div>
  );
}
