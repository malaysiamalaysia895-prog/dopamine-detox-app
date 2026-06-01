package com.example.dopamine_detox

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity
 *
 * Uses the pre-warmed FlutterEngine from App (Application class) so the engine
 * — and its MethodChannel registrations — survive MainActivity being killed.
 *
 * shouldDestroyEngineWithHost() = false is the critical line that keeps the
 * engine alive after the user clears the app from recents.
 *
 * MethodChannel: "com.example.dopamine_detox/monitor"
 *   start(blocked)          — start ForegroundMonitorService
 *   stop()                  — stop the service
 *   getForeground()         — read current foreground package from SharedPrefs
 *   setEmergencyBypass(bool)— toggle emergency bypass flag in SharedPrefs
 *   saveBlocked(list)       — persist blocked list
 *   requestBatteryOptExempt — request system to ignore battery optimisation
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val PREFS_NAME   = "focus_prefs"
        const val KEY_FOREGROUND = "current_foreground_pkg"
        const val KEY_BLOCKED    = "blocked_packages"
        const val KEY_ACTIVE     = "challenge_active"
        const val KEY_EMERGENCY  = "emergency_bypass"
    }

    // ── Use the pre-warmed engine — do NOT destroy it with the Activity ───────

    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(App.ENGINE_ID)

    override fun shouldDestroyEngineWithHost(): Boolean = false

    // ── Register MethodChannels (called even for cached engines) ──────────────

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.dopamine_detox/monitor"
        ).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            when (call.method) {

                "start" -> {
                    @Suppress("UNCHECKED_CAST")
                    val blocked =
                        (call.argument<List<String>>("blocked") ?: emptyList())
                    prefs.edit()
                        .putStringSet(KEY_BLOCKED, blocked.toSet())
                        .putBoolean(KEY_ACTIVE, true)
                        .putBoolean(KEY_EMERGENCY, false)
                        .apply()

                    val intent =
                        Intent(this, ForegroundMonitorService::class.java).apply {
                            putStringArrayListExtra(
                                ForegroundMonitorService.EXTRA_BLOCKED,
                                ArrayList(blocked)
                            )
                        }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        startForegroundService(intent)
                    else startService(intent)
                    result.success(null)
                }

                "stop" -> {
                    prefs.edit()
                        .putBoolean(KEY_ACTIVE, false)
                        .putBoolean(KEY_EMERGENCY, false)
                        .apply()
                    startService(
                        Intent(this, ForegroundMonitorService::class.java).apply {
                            action = ForegroundMonitorService.ACTION_STOP
                        }
                    )
                    result.success(null)
                }

                "getForeground" -> {
                    result.success(
                        prefs.getString(KEY_FOREGROUND, "") ?: ""
                    )
                }

                "setEmergencyBypass" -> {
                    val active = call.argument<Boolean>("active") ?: false
                    prefs.edit().putBoolean(KEY_EMERGENCY, active).apply()
                    result.success(null)
                }

                "saveBlocked" -> {
                    @Suppress("UNCHECKED_CAST")
                    val blocked =
                        (call.argument<List<String>>("blocked") ?: emptyList())
                    prefs.edit()
                        .putStringSet(KEY_BLOCKED, blocked.toSet())
                        .apply()
                    result.success(null)
                }

                "requestBatteryOptExempt" -> {
                    // Ask the system to exclude us from battery optimisation.
                    // Without this, MIUI / Samsung kill our foreground service
                    // despite stopWithTask=false.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            startActivity(
                                Intent(
                                    android.provider.Settings
                                        .ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                ).apply {
                                    data = android.net.Uri.parse("package:$packageName")
                                }
                            )
                        } catch (_: Exception) {}
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
