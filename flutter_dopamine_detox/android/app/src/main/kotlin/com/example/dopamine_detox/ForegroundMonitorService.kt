package com.example.dopamine_detox

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * ForegroundMonitorService
 *
 * Runs as a sticky foreground service. Every POLL_MS it:
 *   1. Reads UsageStatsManager → current foreground package.
 *   2. Writes the package name to SharedPreferences (for Flutter polling).
 *   3. If the package is in the blocked list AND not in emergency bypass:
 *      → Invokes the Dart 'showOverlay' method via the cached FlutterEngine.
 *   4. If the package is NOT blocked:
 *      → Invokes 'closeOverlay' if overlay was showing.
 *
 * WHY FlutterEngineCache instead of EventChannel:
 *   EventChannel.onCancel() fires when the Activity goes to background,
 *   setting eventSink = null and silently dropping events. The pre-warmed
 *   engine in App.kt survives Activity destruction, so MethodChannel calls
 *   always reach live Dart code.
 *
 * stopWithTask = false keeps the service alive when the user clears the app
 * from recents. Combined with the persistent engine this means overlay
 * detection works even when the app appears killed.
 */
class ForegroundMonitorService : Service() {

    companion object {
        const val CHANNEL_ID    = "focus_monitor_v3"
        const val NOTIF_ID      = 2003
        const val ACTION_STOP   = "com.example.dopamine_detox.STOP_MONITOR"
        const val EXTRA_BLOCKED = "blockedPackages"
        private const val POLL_MS = 500L
        private const val TAG = "FocusMonitor"

        // Overlay control MethodChannel name — must match main.dart
        private const val OVERLAY_CHANNEL =
            "com.example.dopamine_detox/overlay_control"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var overlayShowing = false

    private val pollRunnable = object : Runnable {
        override fun run() {
            detect()
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
            if (overlayShowing) invokeOverlayControl("closeOverlay", null)
            stopSelf()
            return START_NOT_STICKY
        }

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
            .edit().putBoolean(MainActivity.KEY_ACTIVE, false).apply()
        Log.d(TAG, "Destroyed.")
        super.onDestroy()
    }

    // ── Detection loop ────────────────────────────────────────────────────────

    private fun detect() {
        val prefs = getSharedPreferences(MainActivity.PREFS_NAME, Context.MODE_PRIVATE)
        val isActive   = prefs.getBoolean(MainActivity.KEY_ACTIVE, false)
        val emergency  = prefs.getBoolean(MainActivity.KEY_EMERGENCY, false)
        val blocked    = prefs.getStringSet(MainActivity.KEY_BLOCKED, emptySet()) ?: emptySet()

        val pkg = getForegroundPackage() ?: return
        prefs.edit().putString(MainActivity.KEY_FOREGROUND, pkg).apply()

        if (!isActive || blocked.isEmpty()) return

        val shouldBlock = pkg in blocked && !emergency

        if (shouldBlock && !overlayShowing) {
            Log.d(TAG, "Blocked app detected: $pkg — showing overlay")
            overlayShowing = true
            val appName = pkg.split(".").last().replaceFirstChar { it.uppercase() }
            invokeOverlayControl("showOverlay", mapOf("appName" to appName))

        } else if (!shouldBlock && overlayShowing) {
            Log.d(TAG, "Non-blocked app: $pkg — closing overlay")
            overlayShowing = false
            invokeOverlayControl("closeOverlay", null)
        }
    }

    /**
     * Calls a Dart method on the pre-warmed FlutterEngine.
     * This works even when MainActivity has been destroyed.
     *
     * Must be called on the main thread (Handler posts guarantee this).
     */
    private fun invokeOverlayControl(method: String, args: Any?) {
        val engine = FlutterEngineCache.getInstance().get(App.ENGINE_ID)
        if (engine == null) {
            Log.w(TAG, "FlutterEngine not cached — overlay call dropped: $method")
            return
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
            .invokeMethod(method, args)
    }

    // ── UsageStats ────────────────────────────────────────────────────────────

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
            .setContentText("Monitoring blocked apps in background")
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
                        CHANNEL_ID,
                        "Focus Monitor",
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
