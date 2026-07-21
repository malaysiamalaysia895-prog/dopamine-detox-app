---
name: Spaceship boss entry cinematic invisibility bug
description: Why a full-screen entry animation (ship descent) can appear to not play at all on real devices
---

An entry-cinematic animation (large scaled sprite flying in from off-screen, shrinking down to its resting size) can look completely absent on real devices even though the AnimationController genuinely runs and the widget tree is correct.

**Why:** if the sprite's off-screen start offset is combined with a very large peak scale multiplier (e.g. 4-5x), the scaled bounding box can extend far outside the viewport for most of the descent — the user only sees the final 1-2 frames where it's already near its resting size/position, which reads as "it just appeared with no animation," not as a rendering/wiring bug.

**How to apply:** when building any fly-in/zoom-in entry cinematic, verify concretely (in the math, since visual devices aren't available here) that the scaled sprite's bounds stay within the screen through most of the timeline — keep peak scale modest (~2x) and start offsets proportional to screen size rather than large fixed pixel offsets. Also avoid near-opaque (>0.7) full-screen dark overlays layered on top of the moving sprite, since they can make even in-view motion unreadable.
