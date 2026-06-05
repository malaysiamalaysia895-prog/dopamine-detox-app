---
name: StateNotifier no mounted
description: Riverpod StateNotifier has no mounted property — use a _disposed flag instead
---

## Rule
`StateNotifier` (Riverpod) does NOT expose a `mounted` getter like `State<T>` does. Using `if (!mounted) return;` inside a `StateNotifier` causes a compile error.

**Why:** `mounted` is a `State<T>` API from Flutter's `StatefulWidget` system. `StateNotifier` is a separate class from the `state_notifier` package. The two hierarchies are unrelated.

**How to apply:**
1. Add `bool _disposed = false;` as a field on the `StateNotifier` subclass.
2. In `dispose()`, set `_disposed = true;` before calling `super.dispose()`.
3. Guard all timer callbacks: `if (_disposed) { t.cancel(); return; }`.
