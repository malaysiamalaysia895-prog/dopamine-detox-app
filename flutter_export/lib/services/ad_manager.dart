// ============================================================
// ad_manager.dart — Production AdMob (Rewarded + Interstitial)
// Tech Tycoon Merge
// google_mobile_ads: ^5.1.0
//
// ════════════════════════════════════════════════════════════
// AD MONETISATION STRATEGY — Anti-Fatigue Rules
// ════════════════════════════════════════════════════════════
//
// Rule 1 — Grace Period
//   No Interstitials for levels 1-3. First eligible level: 4.
//   Let the player get hooked before showing any forced ads.
//
// Rule 2 — 3-Minute Frequency Cap
//   Even when eligible (level ≥ 4), skip if < 180 s have elapsed
//   since the last successfully-shown Interstitial.
//   Tracked via _lastInterstitialShownAt (in-memory per session).
//
// Rule 3 — Rewarded ↔ Interstitial Mutual Exclusion
//   If the player already watched a Rewarded Ad on the Victory
//   screen (3× coins), the Interstitial is suppressed for that
//   transition.  Never stack two ads back-to-back.
//
// Rule 4 — Gameplay Is Sacrosanct
//   canShowInterstitial() is ONLY called when the player taps
//   "Next Level" or "Restart Level". The timer never fires an ad
//   proactively during active play.
//
// Rule 5 — Reward Validation
//   Coins / Energy are granted ONLY inside onUserEarnedReward.
//   No reward on skip, early close, or failed load.
//
// AndroidManifest.xml — inside <application>:
//   <meta-data
//     android:name="com.google.android.gms.ads.APPLICATION_ID"
//     android:value="ca-app-pub-8566652140087308~1114269136"/>
//
// iOS Info.plist — inside <dict>:
//   <key>GADApplicationIdentifier</key>
//   <string>ca-app-pub-8566652140087308~1114269136</string>
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ─── Ad Policy Constants ──────────────────────────────────────────────────────

/// Minimum level number at which Interstitials are permitted.
/// Levels 1–3 are a grace period — no forced ads.
const int _kInterstitialGraceLevel = 4;

/// Minimum seconds between two Interstitial shows (frequency cap).
const Duration _kInterstitialCooldown = Duration(seconds: 180);

// ─── Ad Unit IDs ─────────────────────────────────────────────────────────────

class AdIds {
  static const String appId             = 'ca-app-pub-8566652140087308~1114269136';
  static const String _rewardedReal     = 'ca-app-pub-8566652140087308/7306930941';
  static const String _interstitialReal = 'ca-app-pub-8566652140087308/3659026052';

  // Google Test IDs (used automatically in debug builds)
  static const String _rewardedTest     = 'ca-app-pub-3940256099942544/5224354917';
  static const String _interstitialTest = 'ca-app-pub-3940256099942544/1033173712';

  static String get rewarded     => kDebugMode ? _rewardedTest     : _rewardedReal;
  static String get interstitial => kDebugMode ? _interstitialTest : _interstitialReal;
}

// ─── Ad Manager (Singleton) ───────────────────────────────────────────────────

class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  RewardedAd?     _rewardedAd;
  InterstitialAd? _interstitialAd;

  bool _rewardedLoading     = false;
  bool _interstitialLoading = false;
  bool _initialized         = false;

  VoidCallback? _pendingInterstitialDismiss;

  /// Timestamp of the most-recently-shown Interstitial Ad.
  /// null means no Interstitial has been shown this session.
  DateTime? _lastInterstitialShownAt;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadRewarded();
      _loadInterstitial();
    } catch (e) {
      debugPrint('[Ad] initialize() failed: $e');
      // App continues without ads — player is never blocked
    }
  }

  // ── Interstitial Policy Gate ──────────────────────────────────────────────

  /// Returns true ONLY when all anti-fatigue rules are satisfied.
  ///
  /// Call this ONCE per "Next Level" / "Restart Level" tap — never
  /// proactively during gameplay.
  ///
  /// [levelNumber]       — the level the player just completed / is restarting.
  /// [rewardedJustWatched] — true if the player voluntarily watched a Rewarded
  ///                        Ad on the Victory screen for this transition.
  bool canShowInterstitial(
    int levelNumber, {
    required bool rewardedJustWatched,
  }) {
    // Rule 1: Grace period — protect the first 3 levels
    if (levelNumber < _kInterstitialGraceLevel) {
      debugPrint(
        '[Ad] Interstitial SKIPPED — grace period '
        '(level $levelNumber < $_kInterstitialGraceLevel)',
      );
      return false;
    }

    // Rule 3: Mutual exclusion — never stack forced ad after opt-in rewarded
    if (rewardedJustWatched) {
      debugPrint(
        '[Ad] Interstitial SKIPPED — rewarded ad already watched this victory',
      );
      return false;
    }

    // Rule 2: 3-minute frequency cap
    if (_lastInterstitialShownAt != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialShownAt!);
      if (elapsed < _kInterstitialCooldown) {
        final remaining = _kInterstitialCooldown - elapsed;
        debugPrint(
          '[Ad] Interstitial SKIPPED — cooldown active '
          '(${elapsed.inSeconds}s elapsed, ${remaining.inSeconds}s remaining)',
        );
        return false;
      }
    }

    debugPrint('[Ad] Interstitial ALLOWED (level $levelNumber)');
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REWARDED AD
  // Rule 5: Reward granted ONLY inside onUserEarnedReward callback.
  // ══════════════════════════════════════════════════════════════════════════

  void _loadRewarded() {
    if (!_initialized) return;
    if (_rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;
    try {
      RewardedAd.load(
        adUnitId: AdIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd      = ad;
            _rewardedLoading = false;
            _setupRewardedCallbacks();
            debugPrint('[Ad] Rewarded loaded ✓');
          },
          onAdFailedToLoad: (err) {
            _rewardedLoading = false;
            debugPrint('[Ad] Rewarded failed to load: $err');
            Future.delayed(const Duration(seconds: 10), _loadRewarded);
          },
        ),
      );
    } catch (e) {
      _rewardedLoading = false;
      debugPrint('[Ad] _loadRewarded() exception: $e');
    }
  }

  void _setupRewardedCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        try { ad.dispose(); } catch (_) {}
        _rewardedAd = null;
        _loadRewarded();
        debugPrint('[Ad] Rewarded dismissed (no reward — user closed early)');
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        try { ad.dispose(); } catch (_) {}
        _rewardedAd = null;
        _loadRewarded();
        debugPrint('[Ad] Rewarded failed to show: $err');
      },
    );
  }

  /// Show a Rewarded Ad.
  ///
  /// [onReward] fires ONLY when the user completes the full ad view
  /// (AdMob onUserEarnedReward callback). Never fires on skip or failure.
  ///
  /// Waits up to 5 s for SDK init, then up to 3 s for the ad to load.
  /// Returns true if the ad was shown, false otherwise.
  Future<bool> showRewarded({required VoidCallback onReward}) async {
    // Wait up to 5 s for the SDK to finish initialising on cold start.
    if (!_initialized) {
      debugPrint('[Ad] SDK not yet initialized — waiting up to 5s…');
      for (int i = 0; i < 25; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_initialized) break;
      }
    }
    if (!_initialized) {
      debugPrint('[Ad] SDK failed to initialize — skipping rewarded ad');
      return false;
    }
    if (_rewardedAd == null && !_rewardedLoading) _loadRewarded();

    if (_rewardedAd == null && _rewardedLoading) {
      debugPrint('[Ad] Rewarded loading — waiting up to 3s…');
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_rewardedAd != null) break;
      }
    }

    if (_rewardedAd == null) {
      debugPrint('[Ad] Rewarded not ready — skipping (no reward given)');
      if (!_rewardedLoading) _loadRewarded();
      return false;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;
    try {
      ad.show(onUserEarnedReward: (_, reward) {
        // Rule 5 enforcement: reward is granted here and ONLY here.
        debugPrint('[Ad] Reward earned ✓ (onUserEarnedReward)');
        try { onReward(); } catch (e) {
          debugPrint('[Ad] onReward callback threw: $e');
        }
      });
    } catch (e) {
      debugPrint('[Ad] showRewarded() show() threw: $e');
      try { ad.dispose(); } catch (_) {}
      _loadRewarded();
      return false;
    }
    _loadRewarded();
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERSTITIAL AD
  // CRITICAL: next level loads ONLY inside onAdDismissedFullScreenContent.
  // Timestamp recorded the moment ad.show() succeeds to start the cooldown.
  // ══════════════════════════════════════════════════════════════════════════

  void _loadInterstitial() {
    if (!_initialized) return;
    if (_interstitialLoading || _interstitialAd != null) return;
    _interstitialLoading = true;
    try {
      InterstitialAd.load(
        adUnitId: AdIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd      = ad;
            _interstitialLoading = false;
            _setupInterstitialCallbacks();
            debugPrint('[Ad] Interstitial loaded ✓');
          },
          onAdFailedToLoad: (err) {
            _interstitialLoading = false;
            debugPrint('[Ad] Interstitial failed to load: $err');
            // Fire pending callback so player is never permanently blocked
            _firePendingDismiss();
            Future.delayed(const Duration(seconds: 10), _loadInterstitial);
          },
        ),
      );
    } catch (e) {
      _interstitialLoading = false;
      debugPrint('[Ad] _loadInterstitial() exception: $e');
      _firePendingDismiss();
    }
  }

  void _setupInterstitialCallbacks() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[Ad] Interstitial dismissed — proceeding to next screen');
        try { ad.dispose(); } catch (_) {}
        _interstitialAd = null;
        _firePendingDismiss();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('[Ad] Interstitial failed to show: $err');
        try { ad.dispose(); } catch (_) {}
        _interstitialAd = null;
        _firePendingDismiss();
        _loadInterstitial();
      },
    );
  }

  void _firePendingDismiss() {
    final cb = _pendingInterstitialDismiss;
    _pendingInterstitialDismiss = null;
    if (cb != null) {
      try { cb(); } catch (e) {
        debugPrint('[Ad] pendingInterstitialDismiss callback threw: $e');
      }
    }
  }

  /// Show Interstitial Ad. [onDismiss] fires after the ad is closed.
  ///
  /// IMPORTANT: Callers MUST check [canShowInterstitial] before calling this.
  /// This method does NOT enforce policy — it just shows the loaded ad.
  ///
  /// Waits up to 5 s for SDK init, then up to 3 s for the ad to load.
  /// Returns true if the ad was shown. Always eventually fires [onDismiss].
  Future<bool> showInterstitial({required VoidCallback onDismiss}) async {
    if (!_initialized) {
      debugPrint('[Ad] SDK not yet initialized — waiting up to 5s…');
      for (int i = 0; i < 25; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_initialized) break;
      }
    }
    if (!_initialized) {
      debugPrint('[Ad] SDK failed to initialize — skipping interstitial');
      try { onDismiss(); } catch (_) {}
      return false;
    }
    if (_interstitialAd == null && !_interstitialLoading) _loadInterstitial();

    if (_interstitialAd == null && _interstitialLoading) {
      debugPrint('[Ad] Interstitial loading — waiting up to 3s…');
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_interstitialAd != null) break;
      }
    }

    if (_interstitialAd == null) {
      debugPrint('[Ad] Interstitial not ready — passing through');
      try { onDismiss(); } catch (e) {
        debugPrint('[Ad] showInterstitial fallback onDismiss threw: $e');
      }
      if (!_interstitialLoading) _loadInterstitial();
      return false;
    }

    _pendingInterstitialDismiss = onDismiss;
    final ad = _interstitialAd!;
    _interstitialAd = null;

    try {
      // Record the timestamp the INSTANT the ad fires — this starts the
      // 3-minute cooldown clock regardless of how long the user watches it.
      _lastInterstitialShownAt = DateTime.now();
      ad.show();
    } catch (e) {
      debugPrint('[Ad] showInterstitial() show() threw: $e');
      // Roll back timestamp — the ad never actually showed
      _lastInterstitialShownAt = null;
      try { ad.dispose(); } catch (_) {}
      _firePendingDismiss();
      _loadInterstitial();
      return false;
    }
    return true;
  }

  /// Pre-warm the interstitial while the player is on the Victory dialog.
  ///
  /// Call this when a level completes and the level number >= 4.
  /// By the time the player taps "Next Level", the download is already done.
  /// Safe to call at any time: no-op if already loaded or loading.
  void prewarmInterstitial() => _loadInterstitial();

  void dispose() {
    try { _rewardedAd?.dispose(); } catch (_) {}
    try { _interstitialAd?.dispose(); } catch (_) {}
  }
}
