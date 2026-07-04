---
id: wait-for-catalog-ready
type: team_decision
title: Gate asset use on AssetRegistry.loaded or catalog_ready
domain: godot-runtime
tags: [assets, autoload, signals, initialization]
status: proposed
enforcement: block
applies_to: [godot-runtime, "scripts/**"]
source: ai
related: [asset-registry-api]
timestamp: 2026-07-04T00:00:00Z
---

`AssetRegistry._ready()` reads two JSON files from disk. Any caller whose own
`_ready()` needs asset data MUST NOT assume the registry is populated — Godot
does not guarantee autoload `_ready` ordering to be complete before scene
scripts run.

**Required pattern** (see `scripts/main/main.gd`):

```gdscript
if AssetRegistry.loaded:
    _populate_assets()
else:
    AssetRegistry.catalog_ready.connect(_populate_assets, CONNECT_ONE_SHOT)
```

- Use `CONNECT_ONE_SHOT` — the population step runs once per scene load, and a
  duplicate connect on re-entry would double-fire.
- Never call `AssetRegistry.load_texture` at the top of `_ready` without the
  `loaded` guard — you'll silently get `null` for the whole scene on cold boot.

Why this rule: the failure mode is silent — textures come back `null`, the UI
just renders blank, and the bug looks like "assets missing" instead of
"initialization race". This is exactly the kind of thing worth encoding once.
