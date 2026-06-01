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
/// Must stay minimal — no Provider, no shared state.
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

  // ── Overlay bridge ────────────────────────────────────────────────────────
  // The main app is the single source of truth for timer state.
  // It broadcasts to the overlay every second and handles all overlay messages.
  StreamSubscription<dynamic>? _overlayMsgSub;
  Timer? _overlayBroadcastTimer;

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

    // Overlay bridge must start after the first frame so Provider context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initOverlayBridge());
  }

  // ── Overlay bridge ─────────────────────────────────────────────────────────

  void _initOverlayBridge() {
    final provider = context.read<AppStateProvider>();
    final billing = context.read<BillingService>();

    // ── Global billing success handler ─────────────────────────────────────
    // Covers billing triggered from both the overlay AND individual screens.
    // Individual screens that previously set onPurchaseSuccess can still
    // override this, but this acts as a safe fallback.
    billing.onPurchaseSuccess = () {
      provider.unlockAll();
      // Tell overlay to close; also close it forcefully in case message drops.
      FlutterOverlayWindow.shareData({'type': 'unlock'});
      FlutterOverlayWindow.closeOverlay();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Penalty paid — lock removed.')),
        );
      }
    };

    // ── Listen to messages FROM the overlay ────────────────────────────────
    _overlayMsgSub =
        FlutterOverlayWindow.overlayListener.listen(_handleOverlayMessage);

    // ── Broadcast timer state TO the overlay every second ─────────────────
    // Without this, the overlay always shows "--:--:--".
    _overlayBroadcastTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      _broadcastTimerState(provider);
    });
  }

  /// Receives messages sent by the overlay widget via FlutterOverlayWindow.shareData().
  void _handleOverlayMessage(dynamic data) {
    if (data is! Map) return;
    final type = data['type'] as String? ?? '';
    final provider = context.read<AppStateProvider>();
    final billing = context.read<BillingService>();

    switch (type) {
      // User long-pressed the emergency unlock button in the overlay.
      case 'emergency_unlock_requested':
        final activated = provider.activateEmergencyUnlock();
        if (activated) {
          // Main app re-shows the overlay after the 2-min emergency window.
          // We do this here (not in the overlay isolate) because the overlay
          // widget is disposed when the overlay closes — its timers die with it.
          Future.delayed(const Duration(minutes: 2), () async {
            if (provider.isLocked && !provider.emergencyUnlockActive) {
              await _showOverlayWindow();
            }
          });
        }
        break;

      // User tapped "Pay ₹99" on the overlay — trigger Google Play billing.
      case 'open_billing':
        billing.buyPenalty().catchError((e) {
          debugPrint('[OverlayBridge] billing error: $e');
        });
        break;

      // Overlay requesting current state (e.g. after re-open).
      case 'request_state':
        _broadcastTimerState(provider);
        break;
    }
  }

  /// Sends the current timer/challenge state to the overlay.
  /// Called every second by _overlayBroadcastTimer.
  void _broadcastTimerState(AppStateProvider provider) {
    if (!provider.isLocked) return;
    final r = provider.remainingTime;
    final h = r.inHours.toString().padLeft(2, '0');
    final m = (r.inMinutes % 60).toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');

    FlutterOverlayWindow.shareData({
      'type': 'timer_update',
      'time': '$h:$m:$s',
      'emergencyUsesLeft': provider.emergencyUsesLeft,
      'isMobileLock':
          provider.activeChallenge == ChallengeType.mobileLock,
      'progress': provider.progressFraction,
      'emergencyActive': provider.emergencyUnlockActive,
      'emergencyRemainingSeconds':
          provider.emergencyRemaining.inSeconds,
    });
  }

  /// Shows the full-screen overlay window.
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
      debugPrint('[OverlayBridge] showOverlay error: $e');
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

/// Overlay window mini-app (separate isolate).
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
