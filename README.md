# Gunvanti: Brahm-Mani — Flutter Prototype

This repository currently opens a Flutter prototype for **Gunvanti: Brahm-Mani**. It shows:

- an animated anime-style English story briefing,
- a cinematic intro for Gunwanti, Maharudra, Bhairav, and Vicky,
- a night-ruins demo gameplay screen with Brahm-Mani fragment collection.

## Preview kaise dekhein

### 1. Flutter install/check karo

```bash
flutter --version
flutter doctor
```

Agar `flutter` command nahi chalti, pehle Flutter SDK install karo:
<https://docs.flutter.dev/get-started/install>

### 2. Project dependencies lao

Repository folder me command chalao:

```bash
flutter pub get
```

### 3. Browser me quick preview dekho

Chrome/web preview ke liye:

```bash
flutter run -d chrome
```

Ye local browser me app kholega. Pehle **Animated Story Mode** screen dikhegi. Button **Watch cinematic intro** dabao, intro dekho, phir **Skip** ya intro complete hone ke baad gameplay screen par jao.

### 4. Android phone par preview dekho

1. Phone me Developer Options aur USB Debugging on karo.
2. Phone ko USB se laptop/PC se connect karo.
3. Device detect hua ya nahi check karo:

```bash
flutter devices
```

4. Debug app run karo:

```bash
flutter run
```

### 5. APK bana kar phone me install karna ho

```bash
flutter build apk --debug
```

APK yahan milega:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Phone me install karne ke liye:

```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

## Important note

Ye abhi **prototype/demo** hai, final Play Store 3D game nahi. Full Play Store game ke liye next production phase me real 3D assets, combat, puzzles, sound effects, optimization, signing, privacy policy, aur release build setup chahiye.
