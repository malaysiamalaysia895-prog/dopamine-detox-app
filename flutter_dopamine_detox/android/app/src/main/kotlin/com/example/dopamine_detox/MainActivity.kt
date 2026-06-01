package com.example.dopamine_detox

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity
 *
 * Registers ONE MethodChannel used by Flutter for:
 *   • start(blocked)           — starts ForegroundMonitorService with blocked list
 *   • stop()                   — stops the service
 *   • getForeground()          — returns the last detected foreground package name
 *   • setEmergencyBypass(bool) — tells the service to suppress overlay temporarily
 *   • saveBlocked(list)        — persists the blocked list to SharedPreferences
 *
 * The EventChannel approach was removed because onCancel() fires when the
 * activity goes to background, setting eventSink = null and silently
 * dropping every detection event. The new approach uses SharedPreferences
 * as the IPC layer — the service writes, Flutter polls every 500 ms.
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val PREFS_NAME = "focus_prefs"
        const val KEY_FOREGROUND = "current_foreground_pkg"
        const val KEY_BLOCKED    = "blocked_packages"
        const val KEY_ACTIVE     = "challenge_active"
        const val KEY_EMERGENCY  = "emergency_bypass"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.dopamine_detox/monitor"
        ).setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            when (call.method) {

                // ── Start monitoring ────────────────────────────────────────
                "start" -> {
                    @Suppress("UNCHECKED_CAST")
                    val blocked = (call.argument<List<String>>("blocked") ?: emptyList())
                    prefs.edit()
                        .putStringSet(KEY_BLOCKED, blocked.toSet())
                        .putBoolean(KEY_ACTIVE, true)
                        .putBoolean(KEY_EMERGENCY, false)
                        .apply()

                    val intent = Intent(this, ForegroundMonitorService::class.java).apply {
                        putStringArrayListExtra(
                            ForegroundMonitorService.EXTRA_BLOCKED,
                            ArrayList(blocked)
                        )
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }

                // ── Stop monitoring ─────────────────────────────────────────
                "stop" -> {
                    prefs.edit()
                        .putBoolean(KEY_ACTIVE, false)
                        .putBoolean(KEY_EMERGENCY, false)
                        .apply()
                    val stopIntent = Intent(this, ForegroundMonitorService::class.java).apply {
                        action = ForegroundMonitorService.ACTION_STOP
                    }
                    startService(stopIntent)
                    result.success(null)
                }

                // ── Poll current foreground package ─────────────────────────
                // Called by Flutter Timer.periodic(500ms) to detect blocked apps.
                "getForeground" -> {
                    val pkg = prefs.getString(KEY_FOREGROUND, "") ?: ""
                    result.success(pkg)
                }

                // ── Emergency bypass toggle ─────────────────────────────────
                "setEmergencyBypass" -> {
                    val active = call.argument<Boolean>("active") ?: false
                    prefs.edit().putBoolean(KEY_EMERGENCY, active).apply()
                    result.success(null)
                }

                // ── Save blocked packages (used on session restore) ─────────
                "saveBlocked" -> {
                    @Suppress("UNCHECKED_CAST")
                    val blocked = (call.argument<List<String>>("blocked") ?: emptyList())
                    prefs.edit()
                        .putStringSet(KEY_BLOCKED, blocked.toSet())
                        .apply()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
