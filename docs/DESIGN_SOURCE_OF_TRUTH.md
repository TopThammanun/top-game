# Design Source Of Truth

This file implements steps 2-10 of `docs/TBH_GAME_SPEC_1_TO_100.md`.

## Authority Order

When documents disagree, resolve them in this order:

1. `project_main_setting.md` for lore, tone, world, clans, magic, monetization principles, and sound direction.
2. `docs/TBH_GAME_SPEC_1_TO_100.md` for implementation sequence and acceptance criteria.
3. `docs/PROJECT_IDENTITY.md` and `data/project_identity.json` for canonical names.
4. `docs/ASSET_MAP.md`, `data/asset_catalog.json`, and `data/asset_shortcuts.json` for asset usage.
5. Local scene/script README files for folder-specific intent.

## Engine Contract

- Engine family: Godot 4.x
- Project file: `project.godot`
- Main scene: `scenes/main/main.tscn`
- Runtime asset service: `scripts/autoload/asset_registry.gd`

## Asset Contract

- Original source assets stay under `asset/`.
- Godot/runtime code should prefer `AssetRegistry` lookups and role shortcuts.
- Stable gameplay aliases live in `data/asset_shortcuts.json`.
- Full generated catalog lives in `data/asset_catalog.json`.
- Regenerate the catalog after asset changes:

```powershell
powershell -ExecutionPolicy Bypass -File tools/generate_asset_catalog.ps1
```

## Folder Contract

- `scenes/main`: boot scene and prototype shell.
- `scenes/maps`: playable map scenes.
- `scenes/ui`: taskbar and reusable UI scenes.
- `scripts/autoload`: global services.
- `scripts/main`: prototype composition.
- `scripts/maps`: map-specific behavior.
- `scripts/ui`: UI-specific behavior.
- `resources/units`: future unit data resources.
- `resources/commands`: future taskbar command resources.

## AI Rule

Before making gameplay, lore, asset, or UI changes, read:

- `project_main_setting.md`
- `docs/TBH_GAME_SPEC_1_TO_100.md`
- `docs/DESIGN_SOURCE_OF_TRUTH.md`
- `docs/PROJECT_IDENTITY.md`
- `docs/ASSET_MAP.md`
