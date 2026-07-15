---
name: 3d-game branch static game
description: Where the standalone Three.js "Zombie Neon" / "Multiverse Crash" game lives, how it's previewed, its offline asset layout, and how it gets built into a Play Store Android app.
---

## Game source
- Standalone Three.js r128 runner game lives in `game/index.html` on the `3d-game` git branch of `malaysiamalaysia895-prog/dopamine-detox-app`. Push work here, not `main`.
- It is a **mobile web game** (plays in a phone browser), explicitly not a native Expo/React Native app. Do not attempt Expo/React Native artifact creation for it — the user handles native packaging themselves (or via the Capacitor wrapper below).
- Previewed via workflow "3D Game Preview" (`node scripts/serve-3d-game.cjs`, port 8080). The headless screenshot tool reports "WebGL is not available" — that's a sandbox GPU limitation, not a bug; real visual verification needs a real device/browser.

## Offline asset layout (canonical)
- Everything the game needs is local under `game/assets/`: `assets/js/three.min.js` + Three.js r128 addon UMD builds (GLTFLoader, EffectComposer, RenderPass, ShaderPass, UnrealBloomPass, CopyShader, LuminosityHighPassShader — loaded in that dependency order, not yet wired into the active render loop, for future levels), `assets/fonts/*` (Creepster-Regular.ttf, Orbitron-900.woff2), and `assets/js/character.js` (reusable player-rig module, `window.ZombieCharacter.create(scene)`).
- No CDN references anywhere in `index.html` — keep it that way for offline play.

## Android build (currently: local test only, not Play Store)
- A Capacitor Android wrapper lives in `mobile-app/` (test appId `com.test.zombieneon`). It copies `game/` into `mobile-app/www/` and wraps it in a WebView via `npx cap sync android`.
- GitHub Actions workflow `.github/workflows/build-debug.yml` triggers on push to the `neon-game` branch and builds only an **unsigned debug APK** artifact for sideloading onto a phone to test gameplay — no keystore, no signing, no production package ID. The user explicitly asked to stop all Play Store/signing/production-ID work until the game itself is finished; do not reintroduce a release/signing workflow or ask for a production package ID unless the user asks again.
- If Play Store packaging is requested again later, a prior attempt used a separate `NEON_GAME_KEYSTORE_BASE64`/`NEON_GAME_KEY_ALIAS`/`NEON_GAME_KEY_PASSWORD`/`NEON_GAME_STORE_PASSWORD` GitHub-secrets pattern (repo Settings > Secrets and variables > Actions) with a `build-neon-game.yml` workflow — that workflow was deleted per this instruction but the pattern is still valid to redo if asked.
- The repo already had two unrelated Flutter-based Actions (`build.yml` on push to `main`, `build-apk.yml` on push to `Merge-app`) for a different app (`dopamine_detox`) — pushing to `3d-game`/`neon-game` never triggers those, which is expected, not a bug.

## Safety lesson
- `git remote get-url origin` in this repo prints an embedded GitHub PAT in cleartext (the origin URL has a token baked in) — never run/display that command's raw output; push directly instead (`git push origin <local>:<remote>`) without inspecting the URL.
