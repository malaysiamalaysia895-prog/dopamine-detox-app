---
name: Node scripts in this repo need .cjs
description: Why a plain require()-based Node script under scripts/ must use .cjs, not .js.
---

`scripts/package.json` declares `"type": "module"`, so every `.js` file under `scripts/` is loaded as an ES module by Node. A script written with `require(...)` will fail immediately with `ReferenceError: require is not defined in ES module scope`.

**Why:** the package.json module type is directory-scoped in Node's resolution — it's not visible until you actually try to run the file, so the failure only shows up in the workflow log, not at write time.

**How to apply:** when adding a new standalone Node script (e.g. a small static file server, a one-off maintenance script) anywhere under `scripts/`, either write it as an ESM (`import`/`export`) or give it a `.cjs` extension if it uses `require`/`module.exports`. Reference the workflow command accordingly (`node scripts/foo.cjs`).
