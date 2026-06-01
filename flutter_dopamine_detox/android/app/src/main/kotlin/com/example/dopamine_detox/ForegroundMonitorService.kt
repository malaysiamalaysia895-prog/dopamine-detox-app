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
 * Runs as a sticky foreground service. Every POLL_MS it:
 *   1. Reads UsageStatsManager to find the current foreground package.
 *   2. Writes the package name into SharedPreferences (KEY_FOREGROUND).
 *
 * Flutter's HomeScreen polls SharedPreferences via MethodChannel.getForeground()
 * every 500 ms. This polling approach is reliable even when the Flutter
 * Activity is backgrounded — unlike EventChannel whose sink becomes null
 * the moment the activity goes to background (onCancel fires).
 *
 * The service does NOT touch the overlay directly. Flutter decides when
 * to call FlutterOverlayWindow.showOverlay() / closeOverlay().
 */
class ForegroundMonitorService : Service() {

    companion object {
        const val CHANNEL_ID    = "focus_monitor_v2"
        const val NOTIF_ID      = 2002
        const val ACTION_STOP   = "com.example.dopamine_detox.STOP"
        const val EXTRA_BLOCKED = "blockedPackages"
        private const val POLL_MS = 500L
        private const val TAG = "FocusMonitor"
    }

    private val handler = Handler(Looper.getMainLooper())

    private val pollRunnable = object : Runnable {
        override fun run() {
            writeForegroundToPrefs()
            handler.postDelayed(this, POLL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.d(TAG, "Stop requested.")
            stopSelf()
            return START_NOT_STICKY
        }

        // Update blocked list in SharedPreferences whenever service is (re)started
        intent?.getStringArrayListExtra(EXTRA_BLOCKED)?.let { list ->
            getSharedPreferences(MainActivity.PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putStringSet(MainActivity.KEY_BLOCKED, list.toSet())
                .putBoolean(MainActivity.KEY_ACTIVE, true)
                .apply()
            Log.d(TAG, "Blocking: $list")
        }

        startForeground(NOTIF_ID, buildNotification())

        handler.removeCallbacks(pollRunnable)
        handler.post(pollRunnable)

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        getSharedPreferences(MainActivity.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(MainActivity.KEY_ACTIVE, false)
            .apply()
        Log.d(TAG, "Service destroyed.")
        super.onDestroy()
    }

    /**
     * Reads the current foreground app from UsageStatsManager and
     * writes it to SharedPreferences so Flutter can poll it.
     */
    private fun writeForegroundToPrefs() {
        val pkg = getForegroundPackage() ?: return
        getSharedPreferences(MainActivity.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(MainActivity.KEY_FOREGROUND, pkg)
            .apply()
    }

    /**
     * Queries the last used app within a 5-second window.
     * The entry with the most recent lastTimeUsed is in the foreground.
     * Returns null if PACKAGE_USAGE_STATS permission has not been granted.
     */
    private fun getForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return null
        val now = System.currentTimeMillis()
        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            now - 5_000L, now
        ) ?: return null
        return stats
            .filter { it.lastTimeUsed > 0 && it.packageName.isNotBlank() }
            .maxByOrNull { it.lastTimeUsed }
            ?.packageName
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun buildNotification(): Notification {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_IMMUTABLE else 0
        val tap = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName), flags
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("📚 Study Focus Active")
            .setContentText("Monitoring blocked apps...")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(tap)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        CHANNEL_ID, "Focus Monitor",
                        NotificationManager.IMPORTANCE_LOW
                    ).apply {
                        description = "Runs during study focus sessions"
                        setShowBadge(false)
                    }
                )
            }
        }
    }
}
