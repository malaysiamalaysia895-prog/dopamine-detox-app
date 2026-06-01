import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

type AdMode = "rewarded" | "interstitial" | null;

interface PendingAd {
  mode: AdMode;
  onComplete: () => void;
}

export function AdOverlay() {
  const [pending, setPending] = useState<PendingAd | null>(null);
  const [countdown, setCountdown] = useState(0);
  const [canSkip, setCanSkip] = useState(false);

  useEffect(() => {
    const handleRewarded = (e: Event) => {
      const detail = (e as CustomEvent).detail;
      setPending({ mode: "rewarded", onComplete: detail.onSuccess });
      setCountdown(4);
      setCanSkip(false);
    };
    const handleInterstitial = (e: Event) => {
      const detail = (e as CustomEvent).detail;
      setPending({ mode: "interstitial", onComplete: detail.onDismiss });
      setCountdown(3);
      setCanSkip(false);
    };
    window.addEventListener("ad:rewarded", handleRewarded);
    window.addEventListener("ad:interstitial", handleInterstitial);
    return () => {
      window.removeEventListener("ad:rewarded", handleRewarded);
      window.removeEventListener("ad:interstitial", handleInterstitial);
    };
  }, []);

  useEffect(() => {
    if (!pending) return;
    if (countdown <= 0) {
      setCanSkip(pending.mode === "interstitial");
      return;
    }
    const t = setTimeout(() => {
      setCountdown(c => {
        if (c <= 1) {
          if (pending.mode === "rewarded") {
            pending.onComplete();
            setPending(null);
            return 0;
          }
          setCanSkip(true);
          return 0;
        }
        return c - 1;
      });
    }, 1000);
    return () => clearTimeout(t);
  }, [countdown, pending]);

  function dismiss() {
    if (!pending) return;
    pending.onComplete();
    setPending(null);
    setCanSkip(false);
  }

  const fakeAdContent = [
    { title: "🎮 PLAY NOW", sub: "Top Rated Mobile Game of 2025" },
    { title: "💎 DIAMONDS SALE", sub: "Get 99% off premium gems!" },
    { title: "🚗 NEW GAME", sub: "Race Legends — Download Free" },
    { title: "🍕 ORDER NOW", sub: "Pizza delivered in 30 minutes" },
  ];
  const ad = fakeAdContent[Math.floor(Date.now() / 10000) % fakeAdContent.length];

  return (
    <AnimatePresence>
      {pending && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/90"
        >
          <div className="relative w-full max-w-sm mx-4">
            {/* Ad badge */}
            <div className="absolute -top-3 left-4 bg-yellow-400 text-black text-xs font-bold px-2 py-0.5 rounded">
              {pending.mode === "rewarded" ? "REWARDED AD" : "AD"}
            </div>

            {/* Fake ad content */}
            <div className="bg-gradient-to-br from-blue-900 to-purple-900 rounded-2xl overflow-hidden border border-white/20">
              <div className="h-48 bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 flex items-center justify-center">
                <div className="text-center">
                  <div className="text-6xl mb-2">{ad.title.split(" ")[0]}</div>
                  <div className="text-white font-black text-2xl">{ad.title.split(" ").slice(1).join(" ")}</div>
                </div>
              </div>
              <div className="p-4 text-center">
                <p className="text-white/80 text-sm">{ad.sub}</p>
              </div>
            </div>

            {/* Countdown / skip */}
            <div className="mt-4 flex items-center justify-between">
              <div className="text-white/60 text-sm">
                {countdown > 0 ? (
                  <span>
                    {pending.mode === "rewarded" ? "⚡ Earning reward in " : "Ad closes in "}
                    <span className="text-yellow-400 font-bold">{countdown}s</span>
                  </span>
                ) : pending.mode === "rewarded" ? (
                  <span className="text-green-400">✓ Reward earned!</span>
                ) : null}
              </div>
              {canSkip && (
                <motion.button
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  onClick={dismiss}
                  className="bg-white/10 hover:bg-white/20 text-white px-4 py-2 rounded-lg text-sm font-bold border border-white/20"
                >
                  Skip Ad ✕
                </motion.button>
              )}
            </div>

            {pending.mode === "rewarded" && countdown > 0 && (
              <div className="mt-2">
                <div className="bg-white/10 rounded-full h-2">
                  <motion.div
                    className="bg-yellow-400 h-2 rounded-full"
                    initial={{ width: "0%" }}
                    animate={{ width: "100%" }}
                    transition={{ duration: 4, ease: "linear" }}
                  />
                </div>
                <p className="text-center text-yellow-400 text-xs mt-1 font-bold">Watch to earn your reward!</p>
              </div>
            )}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
