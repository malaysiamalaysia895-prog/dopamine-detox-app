// ============================================================
// ad_manager.dart
// Tech Tycoon Merge — Production AdMob Service
//
// pubspec.yaml dependency:
//   google_mobile_ads: ^5.1.0
//
// AndroidManifest.xml — inside <application> tag:
//   <meta-data
//     android:name="com.google.android.gms.ads.APPLICATION_ID"
//     android:value="ca-app-pub-8566652140087308~1114269136"/>
//
// iOS Info.plist — inside <dict>:
//   <key>GADApplicationIdentifier</key>
//   <string>ca-app-pub-8566652140087308~1114269136</string>
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'level_config.dart';

// ─── Ad Unit IDs ─────────────────────────────────────────────────────────────

class _AdUnitIds {
  // Use test IDs in debug mode; real IDs in release.
  static String get rewarded => kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917'   // Google test rewarded ID
      : TechTycoonLevels.rewardedAdUnitId;          // ca-app-pub-8566652140087308/7306930941

  static String get interstitial => kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712'   // Google test interstitial ID
      : TechTycoonLevels.interstitialAdUnitId;      // ca-app-pub-8566652140087308/3659026052
}

// ─── AdManagerService (Singleton) ────────────────────────────────────────────

class AdManagerService {
  AdManagerService._();
  static final AdManagerService instance = AdManagerService._();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  bool _rewardedLoading = false;
  bool _interstitialLoading = false;

  // Callbacks stored while ad is being watched
  VoidCallback? _pendingRewardCallback;
  VoidCallback? _pendingInterstitialDismiss;

  // ── Initialise MobileAds SDK ───────────────────────────────────────────────
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Pre-load both ad types so they are ready when needed
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REWARDED AD (Rules 1, 2, 3)
  // ══════════════════════════════════════════════════════════════════════════

  void _loadRewardedAd() {
    if (_rewardedLoading || _rewardedAd != null) return;
    _rewardedLoading = true;

    RewardedAd.load(
      adUnitId: _AdUnitIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoading = false;
          _configureRewardedCallbacks();
          debugPrint('[AdManager] Rewarded ad loaded ✓');
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          debugPrint('[AdManager] Rewarded ad failed to load: $error');
          // Retry after 30 s
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  void _configureRewardedCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) =>
          debugPrint('[AdManager] Rewarded ad showing'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdManager] Rewarded ad dismissed (no reward earned)');
        ad.dispose();
        _rewardedAd = null;
        _pendingRewardCallback = null;
        _loadRewardedAd(); // Pre-load next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdManager] Rewarded ad failed to show: $error');
        ad.dispose();
        _rewardedAd = null;
        _pendingRewardCallback = null;
        _loadRewardedAd();
      },
    );
  }

  /// Show a Rewarded Ad.
  ///
  /// [onReward] is called ONLY when the user earns the reward (full view).
  /// This maps to:
  ///   • Rule 1 — onReward: addEnergy(50)
  ///   • Rule 2 — onReward: addEnergy(50)
  ///   • Rule 3 — onReward: multiplyCoins(3)
  Future<bool> showRewardedAd({required VoidCallback onReward}) async {
    if (_rewardedAd == null) {
      debugPrint('[AdManager] Rewarded ad not ready. Loading now…');
      _loadRewardedAd();
      return false;
    }

    _pendingRewardCallback = onReward;

    _rewardedAd!.show(
      onUserEarnedReward: (_, reward) {
        debugPrint('[AdManager] Reward earned: ${reward.type} x${reward.amount}');
        // ✅ Only fires when the user completes the ad — strict as required
        _pendingRewardCallback?.call();
        _pendingRewardCallback = null;
      },
    );

    _rewardedAd = null; // Mark as consumed; pre-load next
    _loadRewardedAd();
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERSTITIAL AD (Rule 4)
  // ══════════════════════════════════════════════════════════════════════════

  void _loadInterstitialAd() {
    if (_interstitialLoading || _interstitialAd != null) return;
    _interstitialLoading = true;

    InterstitialAd.load(
      adUnitId: _AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoading = false;
          _configureInterstitialCallbacks();
          debugPrint('[AdManager] Interstitial ad loaded ✓');
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          debugPrint('[AdManager] Interstitial failed to load: $error');
          Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
        },
      ),
    );
  }

  void _configureInterstitialCallbacks() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdManager] Interstitial dismissed — loading next level');
        ad.dispose();
        _interstitialAd = null;
        // ✅ Rule 4: next level grid loads ONLY here, inside onDismiss
        _pendingInterstitialDismiss?.call();
        _pendingInterstitialDismiss = null;
        _loadInterstitialAd(); // Pre-load for next even level
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdManager] Interstitial failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        // Still load the next level so the player isn't stuck
        _pendingInterstitialDismiss?.call();
        _pendingInterstitialDismiss = null;
        _loadInterstitialAd();
      },
    );
  }

  /// Show an Interstitial Ad (Rule 4 — every even level).
  ///
  /// [onDismiss] is called after the ad is dismissed.
  /// The caller MUST wait for this callback before loading the next level.
  ///
  /// Returns true if the ad was shown, false if not ready.
  Future<bool> showInterstitialAd({required VoidCallback onDismiss}) async {
    if (_interstitialAd == null) {
      debugPrint('[AdManager] Interstitial not ready — loading next level directly');
      onDismiss(); // Fallback: don't block the player
      _loadInterstitialAd();
      return false;
    }

    _pendingInterstitialDismiss = onDismiss;
    _interstitialAd!.show();
    _interstitialAd = null; // Mark as consumed
    _loadInterstitialAd();
    return true;
  }

  // ── Dispose ───────────────────────────────────────────────────────────────
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd = null;
    _interstitialAd = null;
  }
}
