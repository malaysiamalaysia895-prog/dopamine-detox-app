# Tech Tycoon Merge — Changelog

All notable changes to the Flutter build are documented here.
Work lives on the **Merge-app** branch. The `main` branch is kept clean.

---

## [Unreleased] — Merge-app

### 🔊 Audio — Dual-Volume BGM + SFX Mixing
**File:** `flutter_export/lib/services/audio_manager.dart`
**Commit:** `e3d43b7`

- Added `_kBgmVolume = 0.10` and `_kSfxVolume = 1.00` as named constants.
- **BGM volume** dropped from 0.6 → **0.1 (10%)** — calm, non-distracting background presence.
- **SFX volume** set to **1.0 (100%)** — applied via `player.setVolume()` before every spawn, merge, error, and victory sound.
- **Auto-start BGM on open**: `initialize()` now calls `playBgm('audio/bgm_garage.mp3')` automatically after SDK setup, so music begins the moment the app launches (runs after `runApp()` — never blocks cold-start UI).
- `toggleMute()` now restores BGM to `_kBgmVolume` (0.1) instead of the old hardcoded 0.6.
- Phase transitions unchanged — `game_provider` still switches to the phase-specific BGM track when a level is entered.

---

### 📢 Ad Monetisation — Anti-Fatigue Strategy
**Files:** `flutter_export/lib/services/ad_manager.dart`, `flutter_export/lib/providers/game_provider.dart`
**Commits:** `7d4b8f3`, `457372b`

Four strict rules implemented to protect player retention and avoid ad fatigue:

#### Rule 1 — Grace Period (Levels 1–3)
- No Interstitial Ads after completing Level 1, 2, or 3.
- First eligible level: **Level 4**.
- Constant: `_kInterstitialGraceLevel = 4`.

#### Rule 2 — 3-Minute Frequency Cap
- Even when eligible (level ≥ 4), an Interstitial is **skipped** if fewer than 180 seconds have elapsed since the last one was shown.
- Tracked in-memory via `_lastInterstitialShownAt` (DateTime?).
- Timestamp is recorded the instant `ad.show()` succeeds — rolls back to `null` if `show()` throws.
- Constant: `_kInterstitialCooldown = Duration(seconds: 180)`.

#### Rule 3 — Rewarded ↔ Interstitial Mutual Exclusion
- If the player watches the **"3× Coins" Rewarded Ad** on the Victory screen, the subsequent Interstitial is **suppressed** for that transition.
- Tracked via `_rewardedWatchedThisVictory` (bool on `GameNotifier`), set inside the `onUserEarnedReward` callback only.
- Reset to `false` at the start of every new level completion.

#### Rule 4 — Gameplay Loop Is Sacrosanct
- `canShowInterstitial()` is called **only** from two button-tap handlers:
  - `goToNextLevel()` — "Next Level" button on Victory screen.
  - `retryLevel()` — "Restart Level" button.
- No background timer, no proactive hook. Active gameplay is **100% uninterrupted**.

#### Rule 5 — Strict Reward Validation
- Coins and Energy are granted **only** inside `onUserEarnedReward`.
- No reward on skip, early close, or failed ad load.
- This was already enforced; explicitly documented and comment-confirmed in code.

#### Additional: Pre-warm on Victory
- `prewarmInterstitial()` is called in `_onLevelComplete()` when `lvlNum >= 4`.
- The ad downloads while the player is on the Victory dialog, so it fires instantly on "Next Level" with no 3-second loading poll.

---

### 🌿 Branch Discipline
- All Flutter work lives on **`Merge-app`** branch.
- `main` branch was accidentally polluted with three commits (`6ccfb7a`, `e0d12c9`, `c8b0a8e`) and has been restored to its clean state via revert commit `8ee799b`.
- Rule: **never commit or push to `main`**. All PRs and pushes target `Merge-app`.

---

## Previous Releases (on Merge-app)

| Commit | Summary |
|--------|---------|
| `0c4f46f` | Fix audio playback and ad loading issues, replacing placeholder files |
| `8b17428` | Improve ad loading speed by pre-fetching during level completion |
