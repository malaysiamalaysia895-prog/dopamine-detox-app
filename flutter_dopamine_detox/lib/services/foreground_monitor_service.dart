import 'package:flutter/services.dart';

/// Dart bridge to ForegroundMonitorService (Kotlin) via a single MethodChannel.
///
/// WHY MethodChannel polling instead of EventChannel:
///   EventChannel.StreamHandler.onCancel() fires when the Flutter activity goes
///   to background, setting eventSink = null. Every subsequent detection event
///   from the Kotlin service is silently dropped. Using polling via MethodChannel
///   + SharedPreferences works regardless of activity lifecycle.
///
/// Flutter calls [getForeground()] every 500 ms from a Timer.periodic in
/// HomeScreen. The Kotlin service writes the current foreground package to
/// SharedPreferences; [getForeground()] reads it back.
class ForegroundMonitorService {
  static const _ch = MethodChannel('com.example.dopamine_detox/monitor');

  /// Start the Kotlin foreground service with [blockedPackages].
  /// Also persists the list to SharedPreferences so the service
  /// survives process death.
  static Future<void> start(List<String> blockedPackages) =>
      _ch.invokeMethod('start', {'blocked': blockedPackages});

  /// Stop the Kotlin foreground service.
  static Future<void> stop() => _ch.invokeMethod('stop');

  /// Returns the package name of the current foreground app.
  /// Called by HomeScreen every 500 ms via Timer.periodic.
  static Future<String> getForeground() async {
    final result = await _ch.invokeMethod<String>('getForeground');
    return result ?? '';
  }

  /// Tells the native side whether the emergency 2-min bypass is active.
  /// The Kotlin service stores this; Flutter reads it when deciding to show overlay.
  static Future<void> setEmergencyBypass({required bool active}) =>
      _ch.invokeMethod('setEmergencyBypass', {'active': active});

  /// Persist the blocked list to SharedPreferences (called on app restore).
  static Future<void> saveBlocked(List<String> blockedPackages) =>
      _ch.invokeMethod('saveBlocked', {'blocked': blockedPackages});
}
