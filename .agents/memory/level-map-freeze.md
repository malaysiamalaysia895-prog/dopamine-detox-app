---
name: Level map AnimationController freeze
description: Never create 50 AnimationControllers simultaneously on the Level Map screen.
---

**Rule:** Use two separate widget classes for level nodes: _AnimatedLevelNode (StatefulWidget with SingleTickerProviderStateMixin, only for the one "next" level) and _StaticLevelNode (StatelessWidget, for all other 49 levels).

**Why:** Creating 50 AnimationController objects simultaneously in initState() causes a 4–5 second UI freeze on the Level Map screen on Android. Only the "next" level node needs to bounce-animate; all others are purely static.

**How to apply:** In level_map_screen.dart, _LevelNode (ConsumerWidget) reads highestLvlProvider and delegates to either _AnimatedLevelNode or _StaticLevelNode. Exactly one AnimationController exists at any time on this screen.
