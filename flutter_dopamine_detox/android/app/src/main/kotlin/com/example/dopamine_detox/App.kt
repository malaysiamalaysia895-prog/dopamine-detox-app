package com.example.dopamine_detox

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * App — Application subclass that pre-warms the Flutter engine.
 *
 * WHY THIS EXISTS:
 *   If MainActivity is killed (user clears from recents), the Flutter engine
 *   would normally be destroyed too. ForegroundMonitorService would then have
 *   no way to trigger the overlay — SharedPreferences are written but nobody
 *   reads them.
 *
 *   By pre-warming the engine here and caching it, the engine outlives the
 *   Activity. ForegroundMonitorService calls Dart overlay methods via this
 *   engine even when no Activity is attached.
 *
 *   MainActivity.shouldDestroyEngineWithHost() returns false to prevent the
 *   engine from being destroyed when the Activity is detached.
 */
class App : Application() {

    companion object {
        /** Cache key used to retrieve the engine from anywhere in the process. */
        const val ENGINE_ID = "dopamine_main_engine"
    }

    override fun onCreate() {
        super.onCreate()

        // Create and warm up the Flutter engine. executeDartEntrypoint()
        // runs main() — initialising providers, billing, and registering
        // the overlay_control MethodChannel handler.
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }
}
