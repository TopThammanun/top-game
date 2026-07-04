---
title: assets standing rules
domain: assets
status: proposed
source: ai
applies_to: [assets, "asset/**", "data/asset_*.json", "tools/generate_asset_catalog.ps1"]
---

## Source of truth

- Original source assets stay under `asset/` — never edit or rewrite them in
  place; the `License and details.txt` files must remain next to their packs.
- `data/asset_catalog.json` is **generated**, never hand-edited. Regenerate it
  after any add/rename/delete under `asset/`.
- `data/asset_shortcuts.json` is **hand-curated** — this is where gameplay
  roles map to catalog ids.
- `docs/ASSET_INDEX.generated.md` is generated alongside the catalog and is a
  summary for humans, not a machine input.

## Pipeline

```powershell
powershell -ExecutionPolicy Bypass -File tools/generate_asset_catalog.ps1
```

Optional flags: `-AssetRoot`, `-OutputJson`, `-OutputMarkdown`. Defaults are the
committed paths; don't override them in normal use.

## Catalog entry contract

Every catalog entry has these fields (see
`decisions/catalog-generator-schema.md` for the full table):

- `id` — stable slug id (never a path).
- `category`, `pack`, `kind`, `group`, `scale` — hierarchy tags.
- `name`, `extension`, `source_path`, `godot_path`, `file_size`, `width`, `height`
  — source-file facts.
- `tags` — deduped slug list built from the hierarchy fields plus any `Extra`.
- Kind-specific extras: `unit_class`, `variant`, `animation`, `biome`,
  `includes_water`, `state`.

## Id naming

- Ids are always lowercase snake_case, hierarchical, and slug-derived.
- Map ids: `map_{scale}_tilesheet_{biome}_{water|no_water}`,
  `map_{scale}_unit_{class}_{variant}_{idle|move}`,
  `map_{scale}_fog_of_war`.
- UI ids: `ui_{scale}_{kind}_{source_slug}`; fonts: `ui_font_{slug}`.
- Never invent an id in game code — ids come from the generator only.

## Shortcuts

- Shortcut keys use dot notation: `unit.player_idle`, `ui.taskbar_panel`,
  `map.default_tilesheet`. They describe a **role**, not a look.
- Add a new shortcut whenever runtime code would otherwise reach for a raw
  catalog id — that's the signal a role belongs in the swap layer.
- Shortcuts are the only place art choices are made; changing the look of the
  "player idle" unit is a one-line edit to this file.

## Legal

Asset packs are by Franuka. The `License and details.txt` files allow
commercial and non-commercial use with attribution. Keep them next to their
packs; the generator picks them up automatically as `map_license` / `ui_license`.
