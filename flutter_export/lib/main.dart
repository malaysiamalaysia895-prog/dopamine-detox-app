// ============================================================
// main.dart — Tech Tycoon Merge — App Entry Point
//
// ════════════════════════════════════════════════════════════
// SETUP (do this BEFORE flutter pub get)
// ════════════════════════════════════════════════════════════
//
// 1. android/app/src/main/AndroidManifest.xml
//    Inside <manifest>:
//      <uses-permission android:name="android.permission.INTERNET"/>
//      <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
//    Inside <application>:
//      <meta-data
//        android:name="com.google.android.gms.ads.APPLICATION_ID"
//        android:value="ca-app-pub-8566652140087308~1114269136"/>
//
// 2. ios/Runner/Info.plist — inside root <dict>:
//      <key>GADApplicationIdentifier</key>
//      <string>ca-app-pub-8566652140087308~1114269136</string>
//      <key>SKAdNetworkItems</key>
//      <array>
//        <dict>
//          <key>SKAdNetworkIdentifier</key>
//          <string>cstr6suwn9.skadnetwork</string>
//        </dict>
//      </array>
//
// 3. android/app/build.gradle:
//      defaultConfig { minSdkVersion 21 }
//
// 4. Place .mp3 files in assets/audio/:
//      bgm_garage.mp3, bgm_office.mp3, bgm_silicon.mp3,
//      bgm_megacorp.mp3, bgm_universe.mp3,
//      spawn_pop.mp3, merge_snap.mp3, error_buzz.mp3,
//      level_victory_fanfare.mp3, time_warning.mp3
//
// 5. Run: flutter pub get && flutter run
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/game_provider.dart';
import 'screens/level_map_screen.dart';
import 'screens/game_board_screen.dart';
import 'services/audio_manager.dart';
import 'services/ad_manager.dart';
import 'services/network_gate.dart';
import 'models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Portrait-only lock ──────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Immersive full-screen ───────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:              Colors.transparent,
    statusBarIconBrightness:     Brightness.light,
    systemNavigationBarColor:    Colors.black,
    navigationBarIconBrightness: Brightness.light,
  ));
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // ── AdMob SDK ───────────────────────────────────────────────────────────────
  await AdManager.instance.initialize();

  // ── Audio init ──────────────────────────────────────────────────────────────
  await AudioManager.instance.initialize();

  runApp(
    const ProviderScope(child: TechTycoonMergeApp()),
  );
}

// ─── App ──────────────────────────────────────────────────────────────────────

class TechTycoonMergeApp extends StatelessWidget {
  const TechTycoonMergeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tech Tycoon Merge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // NetworkGate wraps the entire game tree.
      // Any offline state → un-dismissible blocking screen.
      home: const NetworkGate(child: _AppRoot()),
    );
  }
}

// ─── App Root — switches between Level Map and Game Board ─────────────────────

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screen = ref.watch(screenProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: switch (screen) {
        AppScreen.map  => const LevelMapScreen(key: ValueKey('map')),
        AppScreen.game => const GameBoardScreen(key: ValueKey('game')),
      },
    );
  }
}
