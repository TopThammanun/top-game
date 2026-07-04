---
id: slice-sheets-at-registry-boundary
type: team_decision
title: Slice sprite and tile sheets at the AssetRegistry boundary
domain: assets
tags: [assets, spritesheets, tilesheets, godot-runtime]
status: proposed
enforcement: block
applies_to: [assets, "asset/**", "data/asset_catalog.json", "scripts/**"]
source: ai
supersedes: ""
related: [catalog-generator-schema, shortcuts-are-the-swap-layer]
timestamp: 2026-07-04T00:00:00Z
---

Source atlases stay whole on disk. When a runtime presenter needs one character
pose or one map tile, it MUST ask `AssetRegistry` for a cropped region/cell/frame
instead of drawing the whole sheet or reimplementing crop math in the scene.

Do:

- Preserve original files under `asset/`.
- Record grid facts in the generated catalog when the source asset is a sheet.
- Use `AssetRegistry.load_sprite_frame(...)` for unit poses.
- Use `AssetRegistry.load_grid_cell(...)` for map tile composition.

Avoid:

- Hand-cropping files into new asset folders as the first fix.
- Displaying a full sprite sheet as a character.
- Displaying a full tilesheet as a map background.
- Copying sheet coordinate math into every scene script.
