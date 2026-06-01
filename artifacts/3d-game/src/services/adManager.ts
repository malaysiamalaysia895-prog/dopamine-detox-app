// AdManagerService — simulates AdMob rewarded & interstitial ads in browser
// In production Flutter this maps to google_mobile_ads package calls

export type AdCallback = () => void;

let adOverlayContainer: HTMLElement | null = null;

function getContainer(): HTMLElement {
  if (!adOverlayContainer) {
    adOverlayContainer = document.createElement("div");
    adOverlayContainer.id = "ad-overlay-root";
    document.body.appendChild(adOverlayContainer);
  }
  return adOverlayContainer;
}

export const AdManagerService = {
  /**
   * Rule 1 & 2 & 3: Rewarded Ad — calls onSuccess only when ad "completes"
   * Simulates a 3s countdown ad experience.
   */
  showRewardedAd(onSuccess: AdCallback): Promise<void> {
    return new Promise((resolve) => {
      const container = getContainer();
      // Fire custom event so React can show its own modal
      const ev = new CustomEvent("ad:rewarded", {
        detail: { onSuccess: () => { onSuccess(); resolve(); } }
      });
      window.dispatchEvent(ev);
    });
  },

  /**
   * Rule 4: Interstitial Ad — calls onDismiss after dismiss; next level loads only then.
   * Simulates a 2s interstitial.
   */
  showInterstitialAd(onDismiss: AdCallback): Promise<void> {
    return new Promise((resolve) => {
      const ev = new CustomEvent("ad:interstitial", {
        detail: { onDismiss: () => { onDismiss(); resolve(); } }
      });
      window.dispatchEvent(ev);
    });
  },
};
