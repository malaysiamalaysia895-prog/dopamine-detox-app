package com.techtycoon.merge

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val VIBRATION_CHANNEL = "com.techtycoon.merge/vibration"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VIBRATION_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    try {
                        @Suppress("UNCHECKED_CAST")
                        val pattern = call.argument<List<Int>>("pattern")
                        val duration = call.argument<Int>("duration") ?: 400
                        nativeVibrate(pattern, duration)
                        result.success(null)
                    } catch (e: Exception) {
                        result.success(null) // never fail the caller
                    }
                }
                "cancel" -> {
                    try { getVibrator()?.cancel() } catch (_: Exception) {}
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getVibrator(): Vibrator? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    } catch (_: Exception) { null }

    private fun nativeVibrate(pattern: List<Int>?, duration: Int) {
        val vib = getVibrator() ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = if (pattern != null) {
                VibrationEffect.createWaveform(
                    pattern.map { it.toLong() }.toLongArray(), -1
                )
            } else {
                VibrationEffect.createOneShot(
                    duration.toLong(), VibrationEffect.DEFAULT_AMPLITUDE
                )
            }
            vib.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            if (pattern != null) {
                vib.vibrate(pattern.map { it.toLong() }.toLongArray(), -1)
            } else {
                vib.vibrate(duration.toLong())
            }
        }
    }
}
