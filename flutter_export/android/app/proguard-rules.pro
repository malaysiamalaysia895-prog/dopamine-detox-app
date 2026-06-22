# ─── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ─── Google Mobile Ads (AdMob) ────────────────────────────────────────────────
# Core SDK classes must survive shrinking or ads will silently fail
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Ad formats (interstitial, rewarded, banner, native)
-keep class com.google.android.gms.ads.interstitial.** { *; }
-keep class com.google.android.gms.ads.rewarded.** { *; }
-keep class com.google.android.gms.ads.rewardedinterstitial.** { *; }
-keep class com.google.android.gms.ads.nativead.** { *; }
-keep class com.google.android.gms.ads.AdLoader { *; }
-keep class com.google.android.gms.ads.AdLoader$Builder { *; }
-keep class com.google.android.gms.ads.AdRequest { *; }
-keep class com.google.android.gms.ads.AdRequest$Builder { *; }
-keep class com.google.android.gms.ads.MobileAds { *; }
-keep class com.google.android.gms.ads.RequestConfiguration { *; }
-keep class com.google.android.gms.ads.RequestConfiguration$Builder { *; }

# Ad listeners and callbacks (if minified these break silently)
-keep interface com.google.android.gms.ads.FullScreenContentCallback { *; }
-keep interface com.google.android.gms.ads.LoadAdError { *; }
-keep interface com.google.android.gms.ads.OnUserEarnedRewardListener { *; }
-keep class com.google.android.gms.ads.rewarded.RewardItem { *; }

# UMP (User Messaging Platform — consent for EEA/GDPR)
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.ump.**

# Suppress warnings from optional GMS features AdMob references at runtime
-dontwarn com.google.android.gms.**

# ─── Google Play Core (pulled in by google_mobile_ads) ────────────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ─── Flutter plugin: google_mobile_ads ────────────────────────────────────────
-keep class io.flutter.plugins.googlemobileads.** { *; }
-dontwarn io.flutter.plugins.googlemobileads.**

# ─── Flutter plugin: audioplayers ─────────────────────────────────────────────
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ─── Flutter plugin: shared_preferences ──────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ─── Flutter plugin: connectivity_plus ───────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ─── Kotlin ───────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# ─── AndroidX ─────────────────────────────────────────────────────────────────
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.**
