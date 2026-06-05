---
name: Stack overlay full-screen
description: Custom overlay widgets in a Flutter Stack must use SizedBox.expand() to fill the screen
---

## Rule
In a Flutter `Stack`, any non-`Positioned` child is sized to its *natural* size and pinned at the alignment origin (top-left by default). If an overlay widget (e.g. a VFX layer, a CustomPaint arc) doesn't explicitly fill the Stack, it will be tiny — the size of its leaf widget (e.g. a `Text` emoji).

**Why:** The arc overlay's `CustomPaint` was sized to the emoji `Text` child rather than the screen, causing trail paint to be clipped and the emoji to appear at the wrong position.

**How to apply:**
- Wrap the overlay's outermost widget with `SizedBox.expand()`.
- Or use `Positioned.fill` if placing inside a `Stack`.
- Then inside, use a `Stack` with `Positioned(left:, top:, ...)` for absolutely-positioned children.
- For `CustomPaint` that must draw across the entire screen, give it `child: const SizedBox.expand()` or wrap it in `Positioned.fill`.
