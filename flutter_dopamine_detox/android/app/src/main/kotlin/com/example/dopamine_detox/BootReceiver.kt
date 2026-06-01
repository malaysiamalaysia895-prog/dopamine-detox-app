package com.example.dopamine_detox

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * BootReceiver — restarts ForegroundMonitorService after device reboot.
 *
 * If the device reboots mid-session, the service dies. On first boot-complete
 * we check SharedPreferences: if a challenge was active, restart the service.
 * The wall-clock timer in AppStateProvider (Dart) recalculates remaining time
 * from the persisted startEpochMs, so the timer is still correct.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences(
            MainActivity.PREFS_NAME, Context.MODE_PRIVATE
        )

        val isActive = prefs.getBoolean(MainActivity.KEY_ACTIVE, false)
        if (!isActive) return

        val blocked = prefs.getStringSet(MainActivity.KEY_BLOCKED, emptySet())
            ?: emptySet()
        if (blocked.isEmpty()) return

        val serviceIntent = Intent(context, ForegroundMonitorService::class.java).apply {
            putStringArrayListExtra(
                ForegroundMonitorService.EXTRA_BLOCKED,
                ArrayList(blocked)
            )
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
