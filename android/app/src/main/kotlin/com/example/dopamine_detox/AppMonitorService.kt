package com.example.dopamine_detox

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service that polls UsageStatsManager every second.
 *
 * When a package from [lockedPackages] comes to the foreground, the service
 * calls [flutterChannel].invokeMethod("onBlockedAppDetected") on the main
 * thread so Flutter can immediately show the lock overlay.
 *
 * Lifecycle:
 *   start: send Intent with action ACTION_START + EXTRA_PACKAGES
 *   stop:  send Intent with action ACTION_STOP
 *
 * The service survives Activity destruction — it persists until the
 * challenge ends (Flutter sends ACTION_STOP).
 */
class AppMonitorService : Service() {

    companion object {
        const val CHANNEL_ID   = "dopamine_monitor_ch"
        const val NOTIFICATION_ID = 8821
        const val ACTION_START = "ACTION_START_MONITOR"
        const val ACTION_STOP  = "ACTION_STOP_MONITOR"
        const val EXTRA_PACKAGES = "locked_packages"

        /**
         * Written by MainActivity once FlutterEngine is ready.
         * Allows the service to push events to Dart on the main thread.
         */
        @Volatile var flutterChannel: MethodChannel? = null

        @Volatile var isRunning: Boolean = false
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lockedPackages: Set<String> = emptySet()

    // Debounce: only fire once per "enter blocked app" event, not every second.
    private var lastBlockedPkg: String? = null

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            checkForegroundApp()
            handler.postDelayed(this, 1_000L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val pkgs = intent.getStringArrayListExtra(EXTRA_PACKAGES) ?: arrayListOf()
                lockedPackages = pkgs.toSet()
                isRunning = true
                lastBlockedPkg = null
                startForeground(NOTIFICATION_ID, buildNotification())
                handler.removeCallbacks(pollRunnable)
                handler.post(pollRunnable)
            }
            ACTION_STOP -> {
                isRunning = false
                lastBlockedPkg = null
                handler.removeCallbacks(pollRunnable)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    // ── Core polling logic ─────────────────────────────────────────────────

    private fun checkForegroundApp() {
        val fg = getForegroundPackage() ?: return

        // Never block our own app or the overlay service package
        if (fg == packageName) return

        if (fg in lockedPackages) {
            if (fg != lastBlockedPkg) {
                lastBlockedPkg = fg
                // invokeMethod is thread-safe on the main looper thread
                flutterChannel?.invokeMethod(
                    "onBlockedAppDetected",
                    mapOf("package" to fg)
                )
            }
        } else {
            // User left the blocked app — reset debounce
            if (lastBlockedPkg != null) {
                lastBlockedPkg = null
                flutterChannel?.invokeMethod("onBlockedAppLeft", null)
            }
        }
    }

    /**
     * Returns the package name of the most recently used app using
     * UsageStatsManager (requires PACKAGE_USAGE_STATS permission).
     */
    private fun getForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null
        val now = System.currentTimeMillis()
        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            now - 10_000L,
            now
        )
        return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
    }

    // ── Notification ───────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Focus Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps focus mode running in the background"
                setShowBadge(false)
                setSound(null, null)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Dopamine Detox — Focus Active")
            .setContentText("Monitoring locked apps. Stay focused! \uD83D\uDCAA")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}
