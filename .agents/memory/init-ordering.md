---
name: Init ordering
description: AdMob and Audio init must NOT block runApp() or the app shows a white screen.
---

**Rule:** Call runApp() FIRST, then fire-and-forget AdManager.instance.initialize() and AudioManager.instance.initialize().

**Why:** MobileAds.instance.initialize() can block for 1–4 seconds on Android cold start. Awaiting it before runApp() holds the Dart main isolate and produces a white/black screen. Both managers guard every method with _initialized checks, so calling them before init completes is safe — missing calls simply retry or skip gracefully.

**How to apply:** In main.dart, the pattern must always be:
```dart
runApp(const ProviderScope(child: TechTycoonMergeApp()));
AdManager.instance.initialize();    // no await
AudioManager.instance.initialize(); // no await
```
