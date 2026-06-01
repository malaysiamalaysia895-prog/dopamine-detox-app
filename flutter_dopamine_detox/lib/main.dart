import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'providers/app_state_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_overlay_screen.dart';
import 'services/billing_service.dart';

/// Overlay entry point (separate isolate — must stay lean)
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
  final isOnboarded = prefs.getBool('isOnboarded') ?? false;

  final billingService = BillingService();
  await billingService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider(prefs)),
        Provider<BillingService>.value(value: billingService),
      ],
      child: DopamineDetoxApp(isOnboarded: isOnboarded),
    ),
  );
}

class DopamineDetoxApp extends StatefulWidget {
  final bool isOnboarded;
  const DopamineDetoxApp({super.key, required this.isOnboarded});

  @override
  State<DopamineDetoxApp> createState() => _DopamineDetoxAppState();
}

class _DopamineDetoxAppState extends State<DopamineDetoxApp> {
  bool _hasInternet = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    // Listen for connectivity changes in real time
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final connected = results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
      if (mounted) setState(() => _hasInternet = connected);
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final connected = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
    if (mounted) setState(() => _hasInternet = connected);
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
          // Main app content
          widget.isOnboarded ? const HomeScreen() : const OnboardingScreen(),

          // ── Blocking internet overlay ──────────────────────────────────
          if (!_hasInternet)
            const _NoInternetOverlay(),
        ],
      ),
    );
  }
}

// ─── No Internet Blocking Overlay ─────────────────────────────────────────────
class _NoInternetOverlay extends StatelessWidget {
  const _NoInternetOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bg.withOpacity(0.97),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF6B9D).withOpacity(0.15),
                    border: Border.all(
                      color: const Color(0xFFFF6B9D).withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Color(0xFFFF6B9D),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Internet Connection\nRequired',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'This app requires an active internet connection '
                    'for billing and security features. '
                    'Please reconnect to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8888AA),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B9D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFF6B9D).withOpacity(0.3)),
                  ),
                  child: const Text(
                    '⏳ Waiting for connection...',
                    style: TextStyle(
                      color: Color(0xFFFF6B9D),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mini app rendered inside the overlay window (separate isolate).
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
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white),
        titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white),
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
