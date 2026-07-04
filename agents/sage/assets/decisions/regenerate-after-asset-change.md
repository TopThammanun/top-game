---
id: regenerate-after-asset-change
type: team_decision
title: Regenerate the asset catalog after any change under asset/
domain: assets
tags: [pipeline, catalog, generator]
status: proposed
enforcement: block
applies_to: [assets, "asset/**", "data/asset_catalog.json"]
source: ai
related: [catalog-generator-schema]
timestamp: 2026-07-04T00:00:00Z
---

Any addition, rename, or deletion under `asset/` MUST be followed by:

```powershell
powershell -ExecutionPolicy Bypass -File tools/generate_asset_catalog.ps1
```

This rewrites both `data/asset_catalog.json` and
`docs/ASSET_INDEX.generated.md`. Commit them together with the asset change so
`AssetRegistry` never points at a stale id.

Why "block":

- `AssetRegistry.load_texture` fails silently (`push_warning`, returns `null`)
  when an id is missing — a stale catalog looks like "the code is broken", not
  "the catalog wasn't regenerated".
- Shortcut resolution (`data/asset_shortcuts.json` → catalog id) breaks the
  moment the target id no longer exists; downstream scenes render blank.

If you renamed something on purpose, also update any shortcut in
`data/asset_shortcuts.json` that pointed at the old id — the shortcuts file is
hand-curated and the generator will not update it for you.
