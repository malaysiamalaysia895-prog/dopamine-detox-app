// ============================================================
// ad_manager.dart — Production AdMob (Rewarded + Interstitial)
// Tech Tycoon Merge
// google_mobile_ads: ^5.1.0
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

// ─── Real Ad Unit IDs ─────────────────────────────────────────────────────────

class AdIds {
  static const String appId             = 'ca-app-pub-8566652140087308~1114269136';
  static const String _rewardedReal     = 'ca-app-pub-8566652140087308/7306930941';
  static const String _interstitialReal = 'ca-app-pub-8566652140087308/3659026052';

  // Google Test IDs
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

  // ══════════════════════════════════════════════════════════════════════════
  // REWARDED AD
  // Used for: Zero Energy (+50⚡), Grid Full Rescue (delete 1 item),
  //           Victory Multiplier (3× Coins), Time Extension (+60s).
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
            Future.delayed(const Duration(seconds: 30), _loadRewarded);
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
        debugPrint('[Ad] Rewarded dismissed (no reward earned)');
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
  /// [onReward] fires ONLY when the user completes the full ad view.
  /// Returns true if the ad was shown, false if not ready (fallback fires automatically).
  Future<bool> showRewarded({required VoidCallback onReward}) async {
    if (_rewardedAd == null) {
      debugPrint('[Ad] Rewarded not ready — skipping');
      _loadRewarded();
      return false;
    }
    final ad = _rewardedAd!;
    _rewardedAd = null;
    try {
      ad.show(onUserEarnedReward: (_, reward) {
        debugPrint('[Ad] Reward earned ✓');
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
  // INTERSTITIAL AD — Rule 4: fires on even-numbered level completions
  // CRITICAL: next level loads ONLY inside onAdDismissedFullScreenContent
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
            // Still fire the pending callback so the player is never permanently blocked
            _firePendingDismiss();
            Future.delayed(const Duration(seconds: 30), _loadInterstitial);
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
        debugPrint('[Ad] Interstitial dismissed — loading next level');
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

  /// Show Interstitial for Rule 4. [onDismiss] fires after the ad is closed.
  /// CRITICAL: caller must NOT load the next level before onDismiss fires.
  Future<bool> showInterstitial({required VoidCallback onDismiss}) async {
    if (_interstitialAd == null) {
      debugPrint('[Ad] Interstitial not ready — passing through');
      try { onDismiss(); } catch (e) {
        debugPrint('[Ad] showInterstitial fallback onDismiss threw: $e');
      }
      _loadInterstitial();
      return false;
    }
    _pendingInterstitialDismiss = onDismiss;
    final ad = _interstitialAd!;
    _interstitialAd = null;
    // NOTE: Do NOT call _loadInterstitial() here.
    // The dismiss/failedToShow callbacks already call it after the ad closes.
    try {
      ad.show();
    } catch (e) {
      debugPrint('[Ad] showInterstitial() show() threw: $e');
      try { ad.dispose(); } catch (_) {}
      _firePendingDismiss();
      _loadInterstitial();
      return false;
    }
    return true;
  }

  void dispose() {
    try { _rewardedAd?.dispose(); } catch (_) {}
    try { _interstitialAd?.dispose(); } catch (_) {}
  }
}
