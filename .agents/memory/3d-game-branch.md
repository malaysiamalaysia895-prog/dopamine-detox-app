---
name: 3d-game branch static game
description: Where the standalone Three.js "Zombie Neon" runner game lives, how to preview it, and the push convention for that branch.
---

The project has a second product, a plain HTML/Three.js (r128) endless-runner game ("Zombie Neon"), that only exists on the `3d-game` git branch of `malaysiamalaysia895-prog/dopamine-detox-app` — not on `main`. It is not registered as a Replit artifact.

- Game source: `game/index.html` (single file — all game logic lives inline in one `<script>` tag; no build step, no bundler).
- Local preview: workflow "3D Game Preview" runs `node scripts/serve-3d-game.cjs`, a minimal static file server for `game/`, bound to port 8080.
- The headless screenshot tool used for verification cannot render WebGL ("WebGL is not available" fallback shows), so visual changes to this game can only be confidence-checked via `node --check` on the extracted script plus manual code review — not a real screenshot. A human needs to actually play it on a device to see jump animation, lighting, textures, etc.

**Why kept as a branch, not merged/artifact-ified:** user explicitly asked to work on this game only within the `3d-game` branch.

**How to apply:** any future work on this game should be done on the `3d-game` branch. Per user instruction, "push" requests while working here should target `3d-game`, not `main`.
