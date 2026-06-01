// ============================================================
// main.dart
// Tech Tycoon Merge — App Entry Point
//
// ════════════════════════════════════════════════════════════
// SETUP INSTRUCTIONS
// ════════════════════════════════════════════════════════════
//
// 1. pubspec.yaml — add these dependencies:
//
//    dependencies:
//      flutter:
//        sdk: flutter
//      flutter_riverpod: ^2.5.1
//      google_mobile_ads: ^5.1.0
//
// 2. android/app/src/main/AndroidManifest.xml
//    Inside the <manifest> tag, ensure INTERNET permission:
//      <uses-permission android:name="android.permission.INTERNET"/>
//
//    Inside the <application> tag, add the AdMob App ID:
//      <meta-data
//        android:name="com.google.android.gms.ads.APPLICATION_ID"
//        android:value="ca-app-pub-8566652140087308~1114269136"/>
//
// 3. ios/Runner/Info.plist — inside the root <dict>:
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
// 4. android/app/build.gradle — ensure minSdkVersion >= 21:
//      defaultConfig {
//        minSdkVersion 21
//      }
//
// 5. Run: flutter pub get
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ad_manager.dart';
import 'game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation for the merge grid
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set immersive full-screen mode
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialise AdMob SDK and pre-load ads
  await AdManagerService.instance.initialize();

  runApp(
    // ProviderScope is the Riverpod root — must wrap the entire app
    const ProviderScope(
      child: TechTycoonMergeApp(),
    ),
  );
}

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
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
