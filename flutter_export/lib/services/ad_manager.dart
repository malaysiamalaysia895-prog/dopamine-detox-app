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
  static const String appId          = 'ca-app-pub-8566652140087308~1114269136';
  static const String _rewardedReal  = 'ca-app-pub-8566652140087308/7306930941';
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

  VoidCallback? _pendingInterstitialDismiss;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadRewarded();
    _loadInterstitial();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REWARDED AD
  // Used for: Zero Energy (+50⚡), Grid Full Rescue (delete 1 item),
  //           Victory Multiplier (3× Coins), Time Extension (+60s).
  // ══════════════════════════════════════════════════════════════════════════

  void _loadRewarded() {
    if (_rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd    = ad;
          _rewardedLoading = false;
          _setupRewardedCallbacks();
          debugPrint('[Ad] Rewarded loaded ✓');
        },
        onAdFailedToLoad: (err) {
          _rewardedLoading = false;
          debugPrint('[Ad] Rewarded failed: $err');
          Future.delayed(const Duration(seconds: 30), _loadRewarded);
        },
      ),
    );
  }

  void _setupRewardedCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        debugPrint('[Ad] Rewarded dismissed (no reward)');
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        debugPrint('[Ad] Rewarded failed to show: $err');
      },
    );
  }

  /// Show a Rewarded Ad.
  ///
  /// [onReward] fires ONLY when user completes the full ad view.
  /// Returns true if ad was shown, false if not ready.
  Future<bool> showRewarded({required VoidCallback onReward}) async {
    if (_rewardedAd == null) {
      debugPrint('[Ad] Rewarded not ready');
      _loadRewarded();
      return false;
    }
    final ad = _rewardedAd!;
    _rewardedAd = null;
    ad.show(onUserEarnedReward: (_, reward) {
      debugPrint('[Ad] Reward earned ✓');
      onReward();
    });
    _loadRewarded();
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERSTITIAL AD — Rule 4: fires on even-numbered level completions
  // CRITICAL: next level loads ONLY inside onAdDismissedFullScreenContent
  // ══════════════════════════════════════════════════════════════════════════

  void _loadInterstitial() {
    if (_interstitialLoading || _interstitialAd != null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd    = ad;
          _interstitialLoading = false;
          _setupInterstitialCallbacks();
          debugPrint('[Ad] Interstitial loaded ✓');
        },
        onAdFailedToLoad: (err) {
          _interstitialLoading = false;
          debugPrint('[Ad] Interstitial failed: $err');
          // Still fire the callback so player isn't permanently blocked
          _pendingInterstitialDismiss?.call();
          _pendingInterstitialDismiss = null;
          Future.delayed(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  void _setupInterstitialCallbacks() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[Ad] Interstitial dismissed — loading next level');
        ad.dispose();
        _interstitialAd = null;
        _pendingInterstitialDismiss?.call();
        _pendingInterstitialDismiss = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('[Ad] Interstitial show failed: $err');
        ad.dispose();
        _interstitialAd = null;
        _pendingInterstitialDismiss?.call();
        _pendingInterstitialDismiss = null;
        _loadInterstitial();
      },
    );
  }

  /// Show Interstitial for Rule 4. [onDismiss] fires after ad closed.
  /// CRITICAL: caller must NOT load the next level before onDismiss fires.
  Future<bool> showInterstitial({required VoidCallback onDismiss}) async {
    if (_interstitialAd == null) {
      debugPrint('[Ad] Interstitial not ready — passing through');
      onDismiss(); // Fallback: never block player permanently
      _loadInterstitial();
      return false;
    }
    _pendingInterstitialDismiss = onDismiss;
    _interstitialAd!.show();
    _interstitialAd = null;
    _loadInterstitial();
    return true;
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}
