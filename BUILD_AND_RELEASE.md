# Dopamine Detox — Build & Release Guide

---

## STEP 1 — Prerequisites (on your local machine)

```bash
# Verify Flutter is installed and up to date
flutter --version          # Needs 3.10.0+
flutter doctor             # Fix any issues shown in red

# Verify Java / keytool is available
java -version              # Needs JDK 17 recommended
keytool -help
```

---

## STEP 2 — Generate Upload Keystore (do this ONCE only)

> ⚠️ Keep your keystore file and passwords safe. Losing them means you can
> NEVER update your Play Store app. Store them in a password manager.

```bash
# Create the keystore directory inside the android folder
mkdir -p android/keystore

# Generate the upload keystore
keytool -genkey -v \
  -keystore android/keystore/upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload \
  -dname "CN=Dopamine Detox, OU=Mobile, O=YourCompanyName, L=Delhi, S=Delhi, C=IN"
```

You will be prompted to set:
- **Keystore password** (remember this!)
- **Key password** (can be same as above)

---

## STEP 3 — Create key.properties (never commit this file!)

Create `android/key.properties` with the following content:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../android/keystore/upload-keystore.jks
```

Verify it's ignored by git:
```bash
cat android/.gitignore   # Should show key.properties and keystore/
git status               # key.properties must NOT appear here
```

---

## STEP 4 — Get dependencies

```bash
flutter pub get
```

---

## STEP 5 — Build RELEASE APK (for manual install / physical device testing)

```bash
flutter build apk --release
```

Output file:
```
build/app/outputs/flutter-apk/app-release.apk
```

Transfer to device:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## STEP 6 — Build RELEASE AAB (for Google Play Store upload)

```bash
flutter build appbundle --release
```

Output file:
```
build/app/outputs/bundle/release/app-release.aab
```

> Upload this `.aab` file to Google Play Console → Production / Internal Testing.

---

## STEP 7 — Verify the release build is signed correctly

```bash
# Check APK signing
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk

# Check AAB signing
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

You should see your CN/OU details printed back.

---

## STEP 8 — Play Store checklist before submitting

| Item | Status |
|---|---|
| `applicationId` changed from `com.example.*` to your real package | ☐ |
| `versionCode` and `versionName` bumped in `pubspec.yaml` | ☐ |
| Google Play product `unlock_penalty_99` created in Play Console → Monetization | ☐ |
| `PACKAGE_USAGE_STATS` permission usage explained in Play Console declaration | ☐ |
| `QUERY_ALL_PACKAGES` permission policy declaration submitted | ☐ |
| `SYSTEM_ALERT_WINDOW` permission usage explained | ☐ |
| App icon (512×512 PNG) uploaded | ☐ |
| Screenshots (min 2, phone) uploaded | ☐ |
| Privacy Policy URL provided (required for permissions above) | ☐ |

---

## QUICK REFERENCE — All build commands

```bash
# Debug run on connected device
flutter run

# Release APK (manual install / testing)
flutter build apk --release

# Release AAB (Play Store)
flutter build appbundle --release

# Split APKs by ABI (smaller download size per device)
flutter build apk --release --split-per-abi

# Analyze app size
flutter build apk --analyze-size
```

---

## ProGuard / R8 note

`minifyEnabled true` + `shrinkResources true` in `build.gradle` activates R8
(Google's replacement for ProGuard). Combined with `proguard-rules.pro`, this:

- Removes all unused classes and methods
- Obfuscates class/method names (renames to `a`, `b`, `c` etc.)
- Strips all `Log.d` / `Log.v` calls from the binary
- Reduces APK size by 30–50%

The `proguard-rules.pro` file keeps all Flutter engine, plugin, and billing
classes intact so nothing breaks at runtime.
