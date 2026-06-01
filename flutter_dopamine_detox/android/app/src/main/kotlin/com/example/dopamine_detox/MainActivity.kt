package com.example.dopamine_detox

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        // Accessed by ForegroundMonitorService to push foreground-app events to Flutter.
        // Marked @Volatile for cross-thread visibility; all actual .success() calls are
        // made from the service's main-looper Handler so they are thread-safe.
        @Volatile
        var eventSink: EventChannel.EventSink? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── EventChannel: foreground-app changes → Flutter ─────────────────────
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.dopamine_detox/foreground_app"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(args: Any?) {
                eventSink = null
            }
        })

        // ── MethodChannel: Flutter → start / stop monitor service ──────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.dopamine_detox/monitor"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    @Suppress("UNCHECKED_CAST")
                    val blocked = call.argument<List<String>>("blocked") ?: emptyList()
                    startMonitor(ArrayList(blocked))
                    result.success(null)
                }
                "stop" -> {
                    val stopIntent = Intent(this, ForegroundMonitorService::class.java).apply {
                        action = ForegroundMonitorService.ACTION_STOP
                    }
                    startService(stopIntent)
                    result.success(null)
                }
                "updateBlocked" -> {
                    @Suppress("UNCHECKED_CAST")
                    val blocked = call.argument<List<String>>("blocked") ?: emptyList()
                    // Re-start service with updated blocked list
                    startMonitor(ArrayList(blocked))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startMonitor(blocked: ArrayList<String>) {
        val intent = Intent(this, ForegroundMonitorService::class.java).apply {
            putStringArrayListExtra(ForegroundMonitorService.EXTRA_BLOCKED, blocked)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
