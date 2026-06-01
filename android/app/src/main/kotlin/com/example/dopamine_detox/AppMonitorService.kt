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
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service — polls UsageStatsManager every second to detect when a
 * locked app enters the foreground. Notifies the main Flutter engine to show
 * the lock overlay.
 *
 * ## Android background-execution compliance
 *
 * ✅ This is a FOREGROUND service (foregroundServiceType="dataSync").
 *    Android's background-execution limits only affect BACKGROUND services.
 *    Foreground services continue running until explicitly stopped.
 *
 * ✅ lockedPackages is persisted to native SharedPreferences (NATIVE_PREFS).
 *    On a START_STICKY restart (null intent), we restore them from disk.
 *
 * ✅ Emergency-unlock window is read from Flutter's SharedPreferences
 *    (FlutterSharedPreferences / flutter.emergencyEndEpochMs) so no Dart
 *    timer needs to be alive. The native service is the source of truth.
 *
 * ✅ FlutterEngineCache is used instead of a static MethodChannel. This
 *    means we always communicate with the live engine even after an
 *    Activity restart.
 */
class AppMonitorService : Service() {

    companion object {
        const val CHANNEL_ID      = "dopamine_monitor_ch"
        const val NOTIFICATION_ID = 8821
        const val ACTION_START    = "ACTION_START_MONITOR"
        const val ACTION_STOP     = "ACTION_STOP_MONITOR"
        const val EXTRA_PACKAGES  = "locked_packages"

        // Must match MainActivity and main.dart
        const val MONITOR_CHANNEL = "com.example.dopamine_detox/app_monitor"
        const val ENGINE_CACHE_ID = "main_engine"

        // Native-only SharedPreferences (separate from Flutter's prefs)
        private const val NATIVE_PREFS   = "dopamine_monitor_native"
        private const val KEY_LOCKED_SET = "locked_pkgs"

        // Flutter's SharedPreferences file name (written by shared_preferences plugin)
        private const val FLUTTER_PREFS       = "FlutterSharedPreferences"
        private const val KEY_EMERGENCY_END   = "flutter.emergencyEndEpochMs"

        @Volatile var isRunning: Boolean = false
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lockedPackages: Set<String> = emptySet()

    // Debounce: only fire onBlockedAppDetected once per "enter blocked app" event
    private var lastBlockedPkg: String? = null

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            checkForegroundApp()
            handler.postDelayed(this, 1_000L)
        }
    }

    // ── Service lifecycle ──────────────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        // Restore locked packages for START_STICKY restarts (null intent).
        // On a normal start, onStartCommand() overwrites this.
        val saved = getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE)
            .getStringSet(KEY_LOCKED_SET, emptySet()) ?: emptySet()
        if (saved.isNotEmpty()) {
            lockedPackages = saved
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val pkgs = intent.getStringArrayListExtra(EXTRA_PACKAGES) ?: arrayListOf()
                lockedPackages = pkgs.toSet()
                isRunning = true
                lastBlockedPkg = null

                // Persist so START_STICKY restart still knows what to monitor
                getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE).edit()
                    .putStringSet(KEY_LOCKED_SET, lockedPackages).apply()

                startForeground(NOTIFICATION_ID, buildNotification())
                handler.removeCallbacks(pollRunnable)
                handler.post(pollRunnable)
            }

            ACTION_STOP -> {
                isRunning = false
                lastBlockedPkg = null
                handler.removeCallbacks(pollRunnable)

                // Clear persisted packages
                getSharedPreferences(NATIVE_PREFS, MODE_PRIVATE).edit()
                    .remove(KEY_LOCKED_SET).apply()

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

    // ── Polling logic ──────────────────────────────────────────────────────────

    private fun checkForegroundApp() {
        val fg = getForegroundPackage() ?: return

        // Never block our own app
        if (fg == packageName) return

        if (fg in lockedPackages) {
            // ── Check emergency window ──────────────────────────────────────
            // Flutter writes emergencyEndEpochMs to its SharedPreferences file
            // when emergency unlock is activated. We read it here so the native
            // service respects the 2-minute window without any Dart timer.
            val flutterPrefs = getSharedPreferences(FLUTTER_PREFS, MODE_PRIVATE)
            val emergencyEnd = flutterPrefs.getLong(KEY_EMERGENCY_END, 0L)
            if (System.currentTimeMillis() < emergencyEnd) {
                // Emergency still active — clear debounce so overlay fires again
                // the moment the emergency window expires.
                lastBlockedPkg = null
                return
            }

            // ── Trigger overlay (debounced) ────────────────────────────────
            if (fg != lastBlockedPkg) {
                lastBlockedPkg = fg
                notifyFlutter("onBlockedAppDetected", mapOf("package" to fg))
            }
        } else {
            // User navigated away from the blocked app (home screen, other app)
            if (lastBlockedPkg != null) {
                lastBlockedPkg = null
                notifyFlutter("onBlockedAppLeft", null)
            }
        }
    }

    /**
     * Returns the package of the most recently foregrounded app via
     * UsageStatsManager (requires PACKAGE_USAGE_STATS permission).
     */
    private fun getForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return null
        val now = System.currentTimeMillis()
        val stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY, now - 10_000L, now
        )
        return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
    }

    /**
     * Invokes a Dart method on the cached main Flutter engine.
     *
     * Using FlutterEngineCache means we always hold a reference to the live
     * engine even after Activity restarts. Because [AppMonitorService] is a
     * foreground service, the process (and therefore the Dart VM) stays alive.
     * MethodChannel calls are delivered to the Dart isolate's message queue
     * and processed as soon as the engine schedules a task.
     */
    private fun notifyFlutter(method: String, args: Any?) {
        val engine = FlutterEngineCache.getInstance().get(ENGINE_CACHE_ID) ?: return
        // invokeMethod must be called from the platform (main) thread
        handler.post {
            MethodChannel(engine.dartExecutor.binaryMessenger, MONITOR_CHANNEL)
                .invokeMethod(method, args)
        }
    }

    // ── Notification ───────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "Focus Monitor", NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps focus mode running in background"
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
            .setContentTitle("Dopamine Detox \u2014 Focus Active")
            .setContentText("Monitoring locked apps. Stay focused! \uD83D\uDCAA")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}
