# Tech Tycoon Merge + Dopamine Detox

Two Flutter projects live in this repo, plus a Node.js API server scaffold.

## Projects

### 1. Tech Tycoon Merge (Flutter game)
The main game — a merge-puzzle with boss battles, alien/creature/spaceship villains, ad monetisation, and BGM.

- **Active source of truth:** `flutter_export/` — this is the directory to edit
- Entry point: `flutter_export/lib/main.dart`
- Screens: `flutter_export/lib/screens/` (game_board_screen, level_map_screen, settings_screen)
- State: `flutter_export/lib/providers/game_provider.dart` (Riverpod `GameNotifier`)
- Villain controllers: `flutter_export/lib/controllers/` (alien, creature, malware, octopus_alien, snake_alien, spaceship_boss)
- Villain overlays: `flutter_export/lib/widgets/` (octopus_alien_overlay, snake_alien_overlay, spaceship_boss_overlay)
- Audio: `flutter_export/lib/services/audio_manager.dart`
- Assets: `flutter_export/assets/audio/` (MP3s), `flutter_export/assets/` (models, fonts)
- Android config: `flutter_export/android/`

**Branch:** All game changes live on the `Merge-app` branch of the GitHub remote (`malaysiamalaysia895-prog/dopamine-detox-app`). Pull from there to get the latest.

**Audio track mapping:**
- Alien boss levels (31–33): `bgm_alien.mp3`
- Data Kraken levels (23, 25, 27, 29): `bgm_malware.mp3`

### 2. Dopamine Detox (Flutter utility app)
App-blocking / focus timer app. Source in `flutter_dopamine_detox/`. Versioned tar archives (`flutter_dopamine_detox_v*.tar.gz`) are snapshots.

### 3. Node.js API server (scaffold)
- Located in `artifacts/api-server/`
- Stack: Express 5, Drizzle ORM, PostgreSQL, Zod
- Run: `pnpm --filter @workspace/api-server run dev` (port 5000)
- Requires `DATABASE_URL` env var

## Run & Operate

| Command | What it does |
|---|---|
| `pnpm --filter @workspace/api-server run dev` | Run the API server (port 5000) |
| `pnpm run typecheck` | Full typecheck across all packages |
| `pnpm run build` | Typecheck + build all packages |

## Stack

- Flutter 3.10+ (game + utility app)
- pnpm workspaces, Node.js 24, TypeScript 5.9 (API server)
- Riverpod (game state), Provider (detox app state)
- audioplayers ^6.0.0 (BGM + SFX with Android audio focus management)
- AdMob (interstitial + rewarded ads)

## Architecture decisions

- BGM and SFX use separate AudioPlayer instances with distinct Android audio focus modes — BGM holds `AUDIOFOCUS_GAIN`, SFX use `AUDIOFOCUS_NONE` so they never interrupt the music.
- `playBgm()` strips the `assets/` prefix automatically; callers can pass either `'audio/foo.mp3'` or `'assets/audio/foo.mp3'`.
- Ad anti-fatigue: no interstitials on levels 1–3, 3-min cooldown between interstitials, rewarded ad suppresses the next interstitial.

## User preferences

_Populate as you build — explicit user instructions worth remembering across sessions._

## Gotchas

- Always edit `flutter_export/` not the root `lib/` — the root `lib/` is a separate (older) copy.
- Missing audio files should be mapped to the nearest existing track rather than silently failing.
- The `Merge-app` GitHub branch is the source of truth for game code; `main` lags behind.

## Pointers

- See `CHANGELOG.md` for a feature-by-feature log of recent game changes
- See `BUILD_AND_RELEASE.md` for the Play Store build/release process
- See the `pnpm-workspace` skill for workspace structure and TypeScript setup
