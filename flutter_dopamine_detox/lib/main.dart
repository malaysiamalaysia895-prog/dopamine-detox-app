import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'providers/app_state_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/lock_overlay_screen.dart';
import 'services/billing_service.dart';

/// Overlay entry-point — runs in a SEPARATE Flutter engine isolate.
/// Must be minimal: no Provider, no BillingService, no main app state.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final billingService = BillingService();
  // init() may return false in pre-warmed background context — that's safe;
  // it retries when buyPenalty() is first called.
  await billingService.init();

  // ── Global overlay_control channel ─────────────────────────────────────────
  // ForegroundMonitorService calls these methods via the pre-warmed
  // FlutterEngine (App.kt) even when MainActivity is destroyed.
  // Registering here (outside HomeScreen) means the handler is always alive.
  _registerOverlayControlChannel(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider(prefs)),
        Provider<BillingService>.value(value: billingService),
      ],
      child: const DopamineDetoxApp(),
    ),
  );
}

/// Registers the MethodChannel that ForegroundMonitorService calls from Kotlin
/// to show/close the overlay. This must be at app level (not inside a widget)
/// so it survives navigation and Activity destruction.
void _registerOverlayControlChannel(SharedPreferences prefs) {
  const ch = MethodChannel('com.example.dopamine_detox/overlay_control');
  ch.setMethodCallHandler((call) async {
    switch (call.method) {

      case 'showOverlay':
        final granted = await FlutterOverlayWindow.isPermissionGranted();
        if (!granted) return;
        try {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: false,
            overlayTitle: 'Study Focus',
            overlayContent: 'Blocked app detected',
            flag: OverlayFlag.defaultFlag,
            alignment: OverlayAlignment.center,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.auto,
            height: WindowSize.fullCover,
            width: WindowSize.fullCover,
          );
          // Feed initial timer data from SharedPreferences so overlay
          // shows correct time immediately (even if HomeScreen is gone).
          _broadcastTimerToOverlay(prefs);
        } catch (_) {}
        break;

      case 'closeOverlay':
        try {
          await FlutterOverlayWindow.closeOverlay();
        } catch (_) {}
        break;
    }
  });
}

/// Reads wall-clock timer state from SharedPreferences and sends one
/// timer_update shareData to the overlay. Called each time the overlay
/// is shown from native code.
void _broadcastTimerToOverlay(SharedPreferences prefs) {
  final startMs   = prefs.getInt('startEpochMs') ?? 0;
  final durSecs   = prefs.getInt('durationSecs') ?? 0;
  if (startMs == 0 || durSecs == 0) return;

  final start     = DateTime.fromMillisecondsSinceEpoch(startMs);
  final elapsed   = DateTime.now().difference(start);
  final remaining = Duration(seconds: durSecs) - elapsed;
  if (remaining.isNegative) return;

  final h = remaining.inHours.toString().padLeft(2, '0');
  final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
  final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
  final progress = elapsed.inSeconds / durSecs;

  FlutterOverlayWindow.shareData({
    'type': 'timer_update',
    'time': '$h:$m:$s',
    'progress': progress.clamp(0.0, 1.0),
    'emergencyLeft': 10,
    'appName': 'Blocked App',
  });
}

// ─── Main App ──────────────────────────────────────────────────────────────────
class DopamineDetoxApp extends StatefulWidget {
  const DopamineDetoxApp({super.key});

  @override
  State<DopamineDetoxApp> createState() => _DopamineDetoxAppState();
}

class _DopamineDetoxAppState extends State<DopamineDetoxApp> {
  bool _hasInternet = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final ok = results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
      if (mounted) setState(() => _hasInternet = ok);
    });
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final ok = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
    if (mounted) setState(() => _hasInternet = ok);
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dopamine Detox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: Stack(
        children: [
          const OnboardingScreen(),
          if (!_hasInternet) const _NoInternetOverlay(),
        ],
      ),
    );
  }
}

// ─── No-Internet Blocking Overlay ─────────────────────────────────────────────
class _NoInternetOverlay extends StatelessWidget {
  const _NoInternetOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Container(
          color: AppTheme.bg.withOpacity(0.97),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF6B9D).withOpacity(0.1),
                    border: Border.all(
                        color: const Color(0xFFFF6B9D).withOpacity(0.35),
                        width: 2),
                  ),
                  child: const Icon(Icons.wifi_off_rounded,
                      color: Color(0xFFFF6B9D), size: 44),
                ),
                const SizedBox(height: 30),
                const Text('Internet Required',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'An active connection is needed for billing '
                    'and security features. Please reconnect.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFF8888AA),
                        fontSize: 14,
                        height: 1.6),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B9D).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFF6B9D).withOpacity(0.3)),
                  ),
                  child: const Text('⏳ Waiting for connection...',
                      style: TextStyle(
                          color: Color(0xFFFF6B9D),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay mini-app — separate Flutter engine, separate isolate.
class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: const LockOverlayScreen(),
    );
  }
}

// ─── Global Theme ─────────────────────────────────────────────────────────────
class AppTheme {
  static const Color primary    = Color(0xFF7C4DFF);
  static const Color secondary  = Color(0xFF00E5FF);
  static const Color accent     = Color(0xFFFF6B9D);
  static const Color bg         = Color(0xFF0D0D1A);
  static const Color surface    = Color(0xFF1A1A2E);
  static const Color cardBg     = Color(0xFF16213E);
  static const Color glassWhite = Color(0x1AFFFFFF);

  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5),
        displayMedium: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge:
            TextStyle(fontSize: 16, color: Color(0xFFCCCCDD)),
        bodyMedium:
            TextStyle(fontSize: 14, color: Color(0xFF9999BB)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}
