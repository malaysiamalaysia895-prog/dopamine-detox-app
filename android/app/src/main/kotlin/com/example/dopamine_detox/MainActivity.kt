package com.example.dopamine_detox

import android.app.AppOpsManager
import android.content.Intent
import android.os.Build
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val MONITOR_CHANNEL = "com.example.dopamine_detox/app_monitor"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MONITOR_CHANNEL
        )

        // Give AppMonitorService a handle so it can call back into Flutter
        // even when the Activity is in the background.
        AppMonitorService.flutterChannel = channel

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
                else -> result.notImplemented()
            }
        }
    }

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
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
