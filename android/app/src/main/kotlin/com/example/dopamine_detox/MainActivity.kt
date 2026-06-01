package com.example.dopamine_detox

import android.app.AppOpsManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val MONITOR_CHANNEL = "com.example.dopamine_detox/app_monitor"
        private const val ENGINE_CACHE_ID = "main_engine"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache the engine so AppMonitorService can invoke Dart methods even
        // when this Activity is not in the foreground. The foreground service
        // keeps the process alive, so the cached engine stays hot.
        FlutterEngineCache.getInstance().put(ENGINE_CACHE_ID, flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MONITOR_CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {

                "startMonitoring" -> {
                    @Suppress("UNCHECKED_CAST")
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    startMonitorService(packages)
                    result.success(null)
                }

                "stopMonitoring" -> {
                    stopMonitorService()
                    result.success(null)
                }

                "hasUsageStatsPermission" -> {
                    result.success(checkUsageStatsPermission())
                }

                // ── Native app list — guaranteed to return ALL launchable apps ──
                //
                // Uses queryIntentActivities(MAIN+LAUNCHER, MATCH_ALL) with the
                // QUERY_ALL_PACKAGES permission. This is the only correct way to
                // enumerate apps on Android 11+ without missing user-installed
                // apps like Instagram, Facebook, WhatsApp, etc.
                //
                // The installed_apps Flutter package uses queryIntentActivities
                // with flag 0 on some ROM/API combinations, which causes package
                // visibility filtering to silently drop third-party apps.
                // This native implementation avoids that entirely.
                "getInstalledApps" -> {
                    Thread {
                        try {
                            val apps = queryAllLaunchableApps()
                            Handler(Looper.getMainLooper()).post { result.success(apps) }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("LOAD_FAILED", e.message, null)
                            }
                        }
                    }.start()
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Queries every app that has a launcher (home-screen) icon.
     * Runs on a background thread — called from the "getInstalledApps" handler.
     *
     * Returns a list of maps with "name" and "packageName" keys only (no icons).
     * Icons are loaded separately in Dart via the installed_apps package.
     */
    private fun queryAllLaunchableApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)

        @Suppress("DEPRECATION")
        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong())
            )
        } else {
            pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        }

        return resolveInfos
            .mapNotNull { ri ->
                try {
                    val ai = ri.activityInfo.applicationInfo
                    if (ai.packageName == packageName) return@mapNotNull null // skip our own app
                    val label = pm.getApplicationLabel(ai).toString()
                    mapOf("name" to label, "packageName" to ai.packageName)
                } catch (_: Exception) {
                    null
                }
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["name"]?.lowercase() }
    }

    // ── Monitor service helpers ────────────────────────────────────────────────

    private fun startMonitorService(packages: List<String>) {
        val intent = Intent(this, AppMonitorService::class.java).apply {
            action = AppMonitorService.ACTION_START
            putStringArrayListExtra(AppMonitorService.EXTRA_PACKAGES, ArrayList(packages))
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopMonitorService() {
        startService(Intent(this, AppMonitorService::class.java).apply {
            action = AppMonitorService.ACTION_STOP
        })
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
