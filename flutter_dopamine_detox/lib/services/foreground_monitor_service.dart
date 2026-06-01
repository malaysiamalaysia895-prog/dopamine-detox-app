import 'package:flutter/services.dart';

/// Dart wrapper around the native ForegroundMonitorService.
///
/// Architecture:
///   • [start]  → starts the Kotlin foreground service with a blocked-packages list
///   • [stop]   → stops the service
///   • [foregroundAppStream] → EventChannel stream; emits a package name
///     every time the foreground app changes on the device
///
/// The native service polls UsageStatsManager every 500 ms.
/// Flutter (HomeScreen) decides whether to show/hide the overlay based on
/// whether the emitted package is in the blocked list.
class ForegroundMonitorService {
  static const _method =
      MethodChannel('com.example.dopamine_detox/monitor');

  static const _event =
      EventChannel('com.example.dopamine_detox/foreground_app');

  /// Stream of foreground package names (e.g. "com.instagram.android").
  /// Emits only when the foreground app CHANGES.
  static Stream<String> get foregroundAppStream =>
      _event.receiveBroadcastStream().map((e) => e.toString());

  /// Start monitoring with [blockedPackages].
  /// Safe to call multiple times — each call updates the blocked list.
  static Future<void> start(List<String> blockedPackages) async {
    await _method.invokeMethod<void>('start', {'blocked': blockedPackages});
  }

  /// Update the blocked packages list without restarting the service.
  static Future<void> updateBlocked(List<String> blockedPackages) async {
    await _method
        .invokeMethod<void>('updateBlocked', {'blocked': blockedPackages});
  }

  /// Stop the foreground monitoring service entirely.
  static Future<void> stop() async {
    await _method.invokeMethod<void>('stop');
  }
}
