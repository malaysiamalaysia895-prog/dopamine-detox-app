---
name: Android-only workflow
description: This project is a Flutter Android game. Replit is IDE only. APK is built by GitHub Actions.
---

This is a Flutter Android game (Tech Tycoon Merge), NOT a web app.

**Rule:** Never stub, bypass, or remove game logic, state management, or level mechanics to satisfy a Replit web-preview or local build. Replit workflow failures (Flutter/Android code can't run as a web server) are expected and harmless.

**Workflow:**
1. Write/fix code in Replit (flutter_export/lib/)
2. Push to GitHub branch: Merge-app
3. GitHub Actions (.github/workflows/build-app.yml) builds the Android APK
4. APK is uploaded as artifact "Mera-Game-APK"

**Why:** The developer explicitly set this up this way and previous agents broke the game by stripping logic to make Replit previews work.

**How to apply:** On every session, confirm you are writing code for Android performance, not for web compatibility. Ignore Replit workflow failures entirely.
