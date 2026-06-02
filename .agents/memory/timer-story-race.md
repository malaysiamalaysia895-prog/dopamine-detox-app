---
name: Timer-story race condition
description: The countdown timer must only start AFTER the story dialog is dismissed, not in startLevel().
---

**Rule:** In game_provider.dart, set timerActive: false in startLevel() and call _startTimer() inside dismissStory() after setting timerActive: true.

**Why:** startLevel() shows ActiveDialog.story immediately. If _startTimer() is called in startLevel(), the timer ticks down while the player is reading the story brief. Worse, if the timer expires before the player taps "Let's Go", _onTimerExpired() tries to set ActiveDialog.timeFail while ActiveDialog.story is still active — a bad-state condition that causes a crash or freeze on the "Let's Go" button tap.

**How to apply:**
- startLevel(): timerActive: false, do NOT call _startTimer()
- dismissStory(): set timerActive: cfg.hasTimer, then if (cfg.hasTimer) _startTimer()
