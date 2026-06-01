import { useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useGameStore } from "../store/useGameStore";
import { LEVELS, PHASE_THEMES, getItemById } from "../data/gameData";
import { AdManagerService } from "../services/adManager";

export function GameHUD() {
  const {
    currentLevel, energy, maxEnergy, totalCoins,
    timerSeconds, timerActive, tickTimer,
    showEnergyWarning, dismissEnergyWarning, addEnergy,
  } = useGameStore();

  const cfg = LEVELS[currentLevel];
  if (!cfg) return null;

  const theme = PHASE_THEMES[cfg.theme];
  const target = getItemById(cfg.targetItemId);

  // ── Timer tick ─────────────────────────────────────────────────────────────
  useEffect(() => {
    if (!timerActive) return;
    const t = setInterval(tickTimer, 1000);
    return () => clearInterval(t);
  }, [timerActive, tickTimer]);

  const energyPct = (energy / maxEnergy) * 100;

  // Rule 1 condition: energy ≤ 20 AND > 0 AND this level allows the boost
  const showLowEnergyButton = cfg.allowLowEnergyBoost && energy <= 20 && energy > 0;

  // Rule 2 condition: energy == 0 AND this level allows the lockout wall
  const showZeroEnergyWall = cfg.allowZeroEnergyLockout && showEnergyWarning;

  async function watchAdForEnergy() {
    // Both Rule 1 and Rule 2 use the same rewarded ad unit
    await AdManagerService.showRewardedAd(() => {
      addEnergy(50);
    });
  }

  const mins = Math.floor(timerSeconds / 60);
  const secs = timerSeconds % 60;

  return (
    <div className="px-3 pt-3 pb-1 flex flex-col gap-2">
      {/* ── Top row ── */}
      <div className="flex items-center justify-between">
        <div className="flex flex-col">
          <span className="text-white/50 text-[10px] uppercase tracking-widest">Level</span>
          <span className="text-white font-black text-xl leading-none">{cfg.level}</span>
          <span className="text-white/60 text-[10px]">{cfg.title}</span>
        </div>

        {/* Timed order countdown */}
        {timerActive && (
          <motion.div
            animate={{ scale: timerSeconds <= 10 ? [1, 1.06, 1] : 1 }}
            transition={{ repeat: timerSeconds <= 10 ? Infinity : 0, duration: 0.5 }}
            className={`flex flex-col items-center px-3 py-1 rounded-xl border ${
              timerSeconds <= 10 ? "border-red-500 bg-red-900/40" : "border-white/20 bg-white/10"
            }`}
          >
            <span className="text-white/50 text-[10px] uppercase">Time</span>
            <span className={`font-mono font-black text-lg ${timerSeconds <= 10 ? "text-red-400" : "text-white"}`}>
              {mins}:{secs.toString().padStart(2, "0")}
            </span>
          </motion.div>
        )}

        {/* Coins */}
        <div className="flex flex-col items-end">
          <span className="text-white/50 text-[10px] uppercase tracking-widest">Coins</span>
          <span className="text-yellow-400 font-black text-xl leading-none">💰 {totalCoins.toLocaleString()}</span>
          <span className="text-white/40 text-[10px]">Phase {cfg.phase}</span>
        </div>
      </div>

      {/* ── Target row ── */}
      <div className="flex items-center gap-2 px-3 py-2 rounded-xl border border-white/10 bg-white/5">
        <span className="text-white/50 text-xs">Target:</span>
        <span className="text-xl">{target?.emoji}</span>
        <span className="text-white font-semibold text-sm">{target?.name}</span>
        <div className="ml-auto text-yellow-400 text-xs font-bold">+{cfg.baseCoins} 💰</div>
      </div>

      {/* ── Energy bar ── */}
      <div className="flex items-center gap-2">
        <span className="text-[10px] text-white/50 w-10">⚡{energy}</span>
        <div className="flex-1 h-3 bg-white/10 rounded-full overflow-hidden">
          <motion.div
            className="h-full rounded-full"
            style={{
              width: `${energyPct}%`,
              background: energyPct > 50 ? "#22c55e" : energyPct > 20 ? "#eab308" : "#ef4444",
              transition: "width 0.3s ease, background 0.3s ease",
            }}
            layout
          />
        </div>
        <span className="text-[10px] text-white/40">{maxEnergy}</span>
      </div>

      {/* ── Rule 1: Low Energy floating button (allowLowEnergyBoost gate) ── */}
      <AnimatePresence>
        {showLowEnergyButton && (
          <motion.button
            key="low-energy-btn"
            initial={{ opacity: 0, y: 10 }}
            animate={{
              opacity: 1, y: 0,
              boxShadow: ["0 0 10px #facc15", "0 0 28px #facc15cc", "0 0 10px #facc15"],
            }}
            exit={{ opacity: 0, y: 10 }}
            transition={{ boxShadow: { repeat: Infinity, duration: 1.2 } }}
            onClick={watchAdForEnergy}
            className="w-full py-2.5 rounded-xl font-black text-sm text-black bg-yellow-400 border-2 border-yellow-300"
          >
            ⚡ Low Energy! Watch Ad for +50 ⚡
          </motion.button>
        )}
      </AnimatePresence>

      {/* ── Rule 2: Zero Energy hard-lockout popup (allowZeroEnergyLockout gate) ── */}
      <AnimatePresence>
        {showZeroEnergyWall && (
          <motion.div
            key="zero-energy-wall"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/85 p-4"
          >
            <motion.div
              initial={{ scale: 0.85, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.85, opacity: 0 }}
              className="bg-gradient-to-br from-red-950 to-gray-950 rounded-2xl p-6 max-w-sm w-full border border-red-700 text-center"
            >
              {/* AdUnit badge */}
              <div className="inline-block mb-3 px-2 py-0.5 rounded text-[10px] font-bold bg-yellow-400/20 text-yellow-400 border border-yellow-400/30">
                REWARDED AD · {cfg.rewardedAdUnitId}
              </div>

              <div className="text-5xl mb-3">⚡</div>
              <h2 className="text-white font-black text-xl mb-2">Energy Depleted!</h2>
              <p className="text-white/60 text-sm mb-6">
                You cannot spawn items.<br />
                Watch a Video to recharge.
              </p>

              {/* Triggers rewarded ad → onSuccess adds 50 energy */}
              <button
                onClick={async () => {
                  dismissEnergyWarning();
                  await AdManagerService.showRewardedAd(() => {
                    addEnergy(50);
                  });
                }}
                className="w-full py-3 rounded-xl bg-gradient-to-r from-yellow-400 to-orange-400 text-black font-black text-base mb-3"
              >
                📺 Watch Video to Recharge +50 ⚡
              </button>

              <button
                onClick={dismissEnergyWarning}
                className="text-white/40 text-sm underline"
              >
                Dismiss
              </button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
