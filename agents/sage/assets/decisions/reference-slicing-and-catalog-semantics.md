---
id: reference-slicing-and-catalog-semantics
type: team_decision
title: Offline reference slicing + semantic catalog fields for asset comprehension
domain: assets
tags: [assets, spritesheets, tilesheets, catalog, documentation, ai-context]
status: proposed
enforcement: advise
applies_to: [assets, "asset/**", "asset_sliced/**", "data/asset_catalog.json", "tools/*.ps1", "docs/ASSET_GUIDE.md"]
source: ai
supersedes: ""
related: [slice-sheets-at-registry-boundary, catalog-generator-schema, id-naming-scheme]
timestamp: 2026-07-04T00:00:00Z
---

Agents kept failing to *use* the art because they could not tell what each asset
was or whether a PNG was a combined sheet or a finished image. Two additions fix
that without weakening the runtime rule.

## 1. Catalog carries meaning, not just facts

`tools/generate_asset_catalog.ps1` now writes four semantic fields on every entry,
derived deterministically from `kind` + naming (so all ~2500 entries are covered):

- `is_atlas` (bool) — true = combined sheet that MUST be sliced (unit_sprite,
  tilesheet, fog_of_war, ui spritesheet/reference, bitmap_font); false = isolated,
  use directly.
- `description` — one plain sentence: what it is + grid/frame facts.
- `usage` — how to consume it (which `AssetRegistry` call, or "ready to use").
- `prompt` — an image-gen-style description (fixed shape; see ASSET_GUIDE §6).
- `sliced_reference` (atlas map assets only) — path into `asset_sliced/`.

When adding a new `kind`, add a branch to `Get-AssetSemantics` — don't leave an
entry with only the generic default.

## 2. `asset_sliced/` is a REFERENCE layer, distinct from runtime slicing

`tools/slice_sheets.ps1` cuts the map sheets into individual pieces under
`asset_sliced/` (unit frames + per-row strips; tilesheet/fog objects via
alpha connected-component labelling, tagged by tile-role, with an `index.json`).

This does **not** violate `slice-sheets-at-registry-boundary`:

- Originals under `asset/` are untouched.
- The **running game still slices through `AssetRegistry`** — `asset_sliced/` is
  never loaded at runtime; it is a preview/understanding artifact for humans + AI.
- It is generated and disposable; regenerate, never hand-edit.

Rule of thumb: **reference/preview cut-outs → `asset_sliced/` (offline tool).
Runtime pixels → `AssetRegistry.load_grid_cell` / `load_sprite_frame`.** Never
point game code at `asset_sliced/`.

## 3. The human/AI map

`docs/ASSET_GUIDE.md` is the narrative guide (packs, atlas-vs-isolated, the
tilesheet tile-role map, UI groups, prompt shape). Keep its tile-role bands in
sync with the `role` strings emitted by `slice_sheets.ps1`.
