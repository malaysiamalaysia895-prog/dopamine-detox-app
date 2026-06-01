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

/// Overlay entry-point — runs in a SEPARATE Flutter isolate.
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
  await billingService.init();

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

class DopamineDetoxApp extends StatefulWidget {
  const DopamineDetoxApp({super.key});

  @override
  State<DopamineDetoxApp> createState() => _DopamineDetoxAppState();
}

class _DopamineDetoxAppState extends State<DopamineDetoxApp> {
  bool _hasInternet = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  // ── Native app-monitor channel ────────────────────────────────────────────
  // Talks to AppMonitorService.kt — starts/stops background polling and
  // receives callbacks when a blocked app enters the foreground.
  static const _kMonitorChannel =
      MethodChannel('com.example.dopamine_detox/app_monitor');

  // ── Overlay bridge state ──────────────────────────────────────────────────
  StreamSubscription<dynamic>? _overlayMsgSub;
  Timer? _overlayBroadcastTimer;

  // Kept so we can removeListener in dispose()
  AppStateProvider? _provider;

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

    // Bridge needs Provider context — defer to first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBridge());
  }

  // ── Bridge init ────────────────────────────────────────────────────────────

  void _initBridge() {
    _provider = context.read<AppStateProvider>();
    final billing = context.read<BillingService>();

    // ── Billing success (covers overlay-triggered and in-screen billing) ───
    billing.onPurchaseSuccess = () {
      _provider!.unlockAll();
      FlutterOverlayWindow.shareData({'type': 'unlock'});
      FlutterOverlayWindow.closeOverlay();
      _stopMonitor();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Penalty paid — lock removed.')),
        );
      }
    };

    // ── Overlay → main app messages ────────────────────────────────────────
    _overlayMsgSub =
        FlutterOverlayWindow.overlayListener.listen(_handleOverlayMsg);

    // ── Native monitor → Flutter callback ─────────────────────────────────
    // AppMonitorService calls these methods on us when a blocked app is
    // detected or when the user navigates away from a blocked app.
    _kMonitorChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onBlockedAppDetected':
          if (_provider!.isLocked && !_provider!.emergencyUnlockActive) {
            await _showOverlayWindow();
          }
          break;
        case 'onBlockedAppLeft':
          // Optionally close overlay when user leaves blocked app.
          // We leave this as a no-op; the overlay stays until
          // emergency/penalty/timer-end so the user can't sneak back.
          break;
      }
    });

    // ── Provider listener: start/stop monitor on challenge changes ─────────
    _provider!.addListener(_onProviderChanged);

    // Sync initial state (app might have been killed mid-session)
    _syncMonitor();

    // ── Timer broadcast to overlay every second ────────────────────────────
    _overlayBroadcastTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      _broadcastTimerState();
    });
  }

  // ── Provider-change handler ────────────────────────────────────────────────

  void _onProviderChanged() {
    _syncMonitor();
    _broadcastTimerState();
  }

  /// Starts the native monitor when study focus is active,
  /// stops it when any challenge ends.
  void _syncMonitor() {
    final p = _provider;
    if (p == null) return;

    if (p.activeChallenge == ChallengeType.studyFocus &&
        p.lockedPackages.isNotEmpty) {
      _startMonitor(p.lockedPackages);
    } else if (!p.isLocked) {
      _stopMonitor();
    }
    // MobileLock: overlay is shown immediately by StudyFocusScreen/HomeScreen;
    // no per-app monitoring needed — the overlay persists unconditionally.
  }

  void _startMonitor(List<String> packages) {
    _kMonitorChannel
        .invokeMethod('startMonitoring', {'packages': packages})
        .catchError((e) => debugPrint('[Monitor] start error: $e'));
  }

  void _stopMonitor() {
    _kMonitorChannel
        .invokeMethod('stopMonitoring')
        .catchError((e) => debugPrint('[Monitor] stop error: $e'));
  }

  // ── Overlay message handler ────────────────────────────────────────────────

  void _handleOverlayMsg(dynamic data) {
    if (data is! Map) return;
    final type = data['type'] as String? ?? '';
    final billing = context.read<BillingService>();

    switch (type) {
      case 'emergency_unlock_requested':
        final ok = _provider!.activateEmergencyUnlock();
        if (ok) {
          Future.delayed(const Duration(minutes: 2), () async {
            if (_provider!.isLocked && !_provider!.emergencyUnlockActive) {
              await _showOverlayWindow();
            }
          });
        }
        break;
      case 'open_billing':
        billing.buyPenalty().catchError((e) {
          debugPrint('[Bridge] billing error: $e');
        });
        break;
      case 'request_state':
        _broadcastTimerState();
        break;
    }
  }

  // ── Overlay helpers ────────────────────────────────────────────────────────

  void _broadcastTimerState() {
    final p = _provider;
    if (p == null || !p.isLocked) return;
    final r = p.remainingTime;
    final h = r.inHours.toString().padLeft(2, '0');
    final m = (r.inMinutes % 60).toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');

    FlutterOverlayWindow.shareData({
      'type': 'timer_update',
      'time': '$h:$m:$s',
      'emergencyUsesLeft': p.emergencyUsesLeft,
      'isMobileLock': p.activeChallenge == ChallengeType.mobileLock,
      'progress': p.progressFraction,
      'emergencyActive': p.emergencyUnlockActive,
      'emergencyRemainingSeconds': p.emergencyRemaining.inSeconds,
    });
  }

  static Future<void> _showOverlayWindow() async {
    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        overlayTitle: 'Challenge Active',
        overlayContent: 'Kripya apna challenge complete karein.',
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.center,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: WindowSize.fullCover,
        width: WindowSize.fullCover,
      );
    } catch (e) {
      debugPrint('[Bridge] showOverlay error: $e');
    }
  }

  // ── Connectivity ───────────────────────────────────────────────────────────

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
    _provider?.removeListener(_onProviderChanged);
    _connectivitySub.cancel();
    _overlayMsgSub?.cancel();
    _overlayBroadcastTimer?.cancel();
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

// ─── No-Internet Banner ────────────────────────────────────────────────────────
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
                        color: Color(0xFF8888AA), fontSize: 14, height: 1.6),
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

/// Overlay window mini-app (separate Flutter isolate).
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
  static const Color primary = Color(0xFF7C4DFF);
  static const Color secondary = Color(0xFF00E5FF);
  static const Color accent = Color(0xFFFF6B9D);
  static const Color bg = Color(0xFF0D0D1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color cardBg = Color(0xFF16213E);
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
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFCCCCDD)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF9999BB)),
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
