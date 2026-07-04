---
id: unit-animation-assets-are-data-driven
type: team_decision
title: Unit animation assets are data-driven
domain: godot-runtime
tags: [godot, animation, assets, presenter]
status: proposed
enforcement: advise
applies_to: [godot-runtime, "scripts/maps/**", "scripts/runtime/**", "data/units/**", "data/combat/**"]
source: ai
supersedes: ""
related: [presenter-owned-game-feel-effects, slice-sheets-at-registry-boundary, shortcuts-are-the-swap-layer]
timestamp: 2026-07-05T00:00:00Z
---

Unit runtime data should carry explicit animation role ids such as `idle_asset`
and `move_asset`. Presenter scenes may switch states and advance frames, but
they should not guess catalog ids, hard-code sprite paths, or crop sheets
themselves.

Do:

- Put role choices in unit/enemy data.
- Resolve role ids through `AssetRegistry`.
- Load frame rows with `AssetRegistry.load_sprite_frames(...)`.
- Keep animation state presenter-owned and temporary.
- Fall back from missing move frames to idle frames.

Avoid:

- Inferring every animation pair inside a scene script.
- Changing combat state from animation callbacks.
- Loading from `asset_sliced/` at runtime.
