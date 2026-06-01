# ─────────────────────────────────────────────────────────────────────────────
# proguard-rules.pro  —  Dopamine Detox
# Obfuscates and shrinks the release APK/AAB so your logic cannot be
# reverse-engineered or stolen.
# ─────────────────────────────────────────────────────────────────────────────


# ── Flutter engine ────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**


# ── flutter_overlay_window ────────────────────────────────────────────────────
-keep class flutter.overlay.window.flutter_overlay_window.** { *; }
-dontwarn flutter.overlay.window.**


# ── Google Play Billing (in_app_purchase) ─────────────────────────────────────
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**
-keep class com.android.vending.billing.** { *; }


# ── Pedometer ─────────────────────────────────────────────────────────────────
-keep class com.example.pedometer.** { *; }
-keep class be.tramckrijte.stepCounter.** { *; }
-dontwarn be.tramckrijte.**


# ── device_apps ───────────────────────────────────────────────────────────────
-keep class fr.g123k.deviceapps.** { *; }
-dontwarn fr.g123k.**


# ── permission_handler ────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.**


# ── shared_preferences ────────────────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }


# ── Lottie ───────────────────────────────────────────────────────────────────
-keep class com.airbnb.lottie.** { *; }
-dontwarn com.airbnb.lottie.**


# ── Kotlin ────────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}


# ── AndroidX / Google libraries ───────────────────────────────────────────────
-keep class androidx.lifecycle.** { *; }
-keep class com.google.android.** { *; }
-dontwarn com.google.android.**
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**


# ── General Android ───────────────────────────────────────────────────────────
# Keep all Activities, Services, BroadcastReceivers, ContentProviders
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep Parcelable implementations intact
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep R class fields for resource access
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Remove all logging in release (security + size)
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}


# ── Obfuscation settings ──────────────────────────────────────────────────────
# Rename packages during obfuscation to make decompilation harder
-repackageclasses 'com.dopaminedetox.obf'
-allowaccessmodification

# ─────────────────────────────────────────────────────────────────────────────
# END OF proguard-rules.pro
# ─────────────────────────────────────────────────────────────────────────────
