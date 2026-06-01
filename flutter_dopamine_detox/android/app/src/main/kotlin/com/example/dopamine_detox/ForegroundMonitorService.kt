package com.example.dopamine_detox

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * ForegroundMonitorService
 *
 * Runs as a persistent Android foreground service (sticky).
 * Polls UsageStatsManager every POLL_MS to detect which app is in the foreground.
 * When the foreground app changes, it notifies Flutter via MainActivity.eventSink.
 *
 * Flutter decides whether to show/hide the overlay based on its own blocked-package list.
 * The service is purely a sensor — it does NOT touch the overlay directly.
 *
 * Requires: PACKAGE_USAGE_STATS permission (user must grant in Settings).
 */
class ForegroundMonitorService : Service() {

    companion object {
        const val CHANNEL_ID   = "focus_monitor_v1"
        const val NOTIF_ID     = 2001
        const val ACTION_STOP  = "com.example.dopamine_detox.STOP_MONITOR"
        const val EXTRA_BLOCKED = "blockedPackages"
        private const val POLL_MS = 500L
        private const val TAG = "FocusMonitor"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lastForeground = ""

    // Live list of blocked packages — updated if service is re-started with new list
    @Volatile
    private var blockedPackages: Set<String> = emptySet()

    private val pollRunnable = object : Runnable {
        override fun run() {
            detectForeground()
            handler.postDelayed(this, POLL_MS)
        }
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.d(TAG, "Stop command received — stopping service.")
            stopSelf()
            return START_NOT_STICKY
        }

        // Update the blocked list if caller provided one
        intent?.getStringArrayListExtra(EXTRA_BLOCKED)?.let { list ->
            blockedPackages = list.toSet()
            Log.d(TAG, "Blocking ${blockedPackages.size} packages: $blockedPackages")
        }

        startForeground(NOTIF_ID, buildNotification())

        // Start polling (remove previous callbacks first to avoid double-posting)
        handler.removeCallbacks(pollRunnable)
        handler.post(pollRunnable)

        return START_STICKY  // Restart automatically if killed by OS
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        Log.d(TAG, "Service destroyed.")
        super.onDestroy()
    }

    // ── Core detection logic ──────────────────────────────────────────────────

    private fun detectForeground() {
        val pkg = getCurrentForegroundPackage() ?: return
        if (pkg == lastForeground) return   // No change — skip

        lastForeground = pkg
        Log.d(TAG, "Foreground → $pkg  (blocked=${blockedPackages.contains(pkg)})")

        // Push to Flutter via the static EventSink registered in MainActivity.
        // This call is on the main looper so it is safe to call EventSink.success() here.
        MainActivity.eventSink?.success(pkg)
    }

    /**
     * Uses UsageStatsManager to find the most recently used app.
     * Queries a 5-second window so we catch fast switches.
     * Returns null if permission has not been granted.
     */
    private fun getCurrentForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return null

        val now = System.currentTimeMillis()
        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            now - 5_000L,
            now
        ) ?: return null

        // The app with the most recent lastTimeUsed is in the foreground
        return stats
            .filter { it.lastTimeUsed > 0 && it.packageName.isNotBlank() }
            .maxByOrNull { it.lastTimeUsed }
            ?.packageName
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun buildNotification(): Notification {
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentIntent = PendingIntent.getActivity(this, 0, openAppIntent, pendingFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("📚 Study Focus Active")
            .setContentText("Blocking selected apps — tap to view timer.")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(contentIntent)
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID,
                        "Focus Monitor",
                        NotificationManager.IMPORTANCE_LOW
                    ).apply {
                        description = "Monitors foreground app during study sessions"
                        setShowBadge(false)
                    }
                )
            }
        }
    }
}
