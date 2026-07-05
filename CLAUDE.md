# OpenWolf

@.wolf/OPENWOLF.md

This project uses OpenWolf for context management. Read and follow .wolf/OPENWOLF.md every session. Check .wolf/cerebrum.md before generating code. Check .wolf/anatomy.md before reading files.


# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**TBH: Task Bar Hero** — a Godot 4.x prototype for an idle + turn-based RPG set in Whisker Realm / Purralia. The repo is currently a starter shell: one boot scene, one autoload, and a large body of design data + docs that drive future implementation.

## Sage protocol is mandatory

`AGENTS.md` at the repo root defines the **Sage** cognition protocol. It is not optional for coding tasks — before writing or modifying code you must run the §1 pipeline: pick a role from `agents/sage/roles/`, read the relevant `agents/sage/<domain>/` knowledge, do a reuse scan, print the reply header + risk verdict, then after coding run tests, refresh docs, capture new knowledge, and close with the mandatory §4b summary block. Read `AGENTS.md` in full before your first response. Sage knowledge lives in `agents/sage/`; roles like `role-designer.md` already exist there.

## Common commands (PowerShell — Windows shell)

```powershell
# Run the game. Godot is resolved in this order:
#   -GodotPath arg → $env:GODOT_EXE → Godot*.exe in the project root → godot on PATH → common install dirs
.\run_game.ps1

# Open the Godot editor for this project
.\run_game.ps1 -Editor

# Point at a specific Godot binary
.\run_game.ps1 -GodotPath "C:\Path\To\Godot_v4.x-stable_win64.exe"

# Regenerate data/asset_catalog.json + docs/ASSET_INDEX.generated.md
# Run this whenever files under asset/ are added, renamed, or removed.
powershell -ExecutionPolicy Bypass -File tools/generate_asset_catalog.ps1

# Runtime smoke check: launch, screenshot the window, kill Godot
powershell -NoProfile -ExecutionPolicy Bypass -File tools\capture_runtime_screenshot.ps1
```

`run_game.sh` and `run_game.bat` are the Git-Bash and cmd equivalents of `run_game.ps1`.

There is no test/lint suite yet. "Verify it runs" (Sage §1 post-code step 1) currently means running `run_game.ps1` or the screenshot capture and reporting the actual output; state this explicitly rather than skipping the step.

## Architecture

### Boot flow

1. `project.godot` points `run/main_scene` at `scenes/main/main.tscn`.
2. The `[autoload]` block registers **`AssetRegistry`** (`scripts/autoload/asset_registry.gd`) as a global singleton — it loads before any scene.
3. `AssetRegistry._ready()` calls `load_catalog()`, which reads `data/asset_catalog.json` and `data/asset_shortcuts.json`, then emits `catalog_ready`.
4. `scripts/main/main.gd` builds a Control-based prototype layout entirely in code, waits for `catalog_ready` (or fires immediately if already loaded), then paints previews via `AssetRegistry.load_texture(...)`.

### Asset pipeline (the load-bearing seam in this repo)

Source art lives untouched under `asset/` (Franuka packs — keep the license files). Runtime code never hard-codes those paths. Instead:

- `tools/generate_asset_catalog.ps1` walks `asset/` and emits `data/asset_catalog.json` (one entry per file, with a stable `id`, `godot_path`, `tags`, and typed metadata like `unit_class`/`biome`) plus a human-readable `docs/ASSET_INDEX.generated.md`.
- `data/asset_shortcuts.json` is a **hand-curated** alias table mapping stable gameplay roles (e.g. `unit.player_idle`, `ui.taskbar_panel`) to catalog ids. Change the shortcut, not the caller, when art gets swapped.
- `AssetRegistry` resolves shortcut → id → entry → `godot_path`, and exposes: `get_asset_path`, `load_texture`, `has_asset`, `find_assets(filters)`, `ids_for(filters)`. Filter keys include the entry fields plus `name_contains`, `tag`, `tags_all`, `tags_any`.

Rule: **prefer shortcuts, then catalog ids, then filters. Never hard-code a `res://asset/...` path in gameplay code.** After any asset add/rename/remove, regenerate the catalog before committing.

**Before using any art, read [`docs/ASSET_AI_PLAYBOOK.md`](docs/ASSET_AI_PLAYBOOK.md)** — the "I want X → use this asset, load it this way" playbook (intent recipes, atlas-vs-isolated, the loader per kind, named map tiles). Deeper reference: [`docs/ASSET_GUIDE.md`](docs/ASSET_GUIDE.md). Map tiles are referenced by **name** via `data/maps/tile_names.json` (`AssetRegistry.load_map_tile("grass")`), never raw `[col,row]`. Each catalog entry also carries `is_atlas` / `description` / `usage` / `prompt` to say what it is and how to use it.

### Data-driven design

`data/` also holds authored gameplay data that future scripts are expected to consume: `data/world/regions.json`, `data/units/clans.json`, `data/units/starter_party.json`, `data/combat/mvp_waves.json`, `data/economy/*.json`, `data/ui/taskbar_commands.json`, `data/audio/*.json`, `data/systems/core_loop.json`, `data/production/milestones.json`, `data/maps/emberhearth_map_plan.json`. These files are the machine-readable projections of the design docs — keep the two in sync when either changes.

### Folder contract (from `docs/DESIGN_SOURCE_OF_TRUTH.md`)

- `scenes/main` — boot scene + prototype shell.
- `scenes/maps` — playable map scenes (empty; README stub only).
- `scenes/ui` — taskbar and reusable UI scenes (empty; README stub only).
- `scripts/autoload` — global services (currently just `AssetRegistry`).
- `scripts/main`, `scripts/maps`, `scripts/ui` — matched to their scene folders.
- `resources/units`, `resources/commands` — future Godot `.tres` resources.

## Source-of-truth order

When two documents disagree, resolve in this order (from `docs/DESIGN_SOURCE_OF_TRUTH.md`):

1. `project_main_setting.md` — lore, tone, world, clans, magic, monetization principles, sound direction.
2. `docs/TBH_GAME_SPEC_1_TO_100.md` — numbered implementation sequence + acceptance criteria.
3. `docs/PROJECT_IDENTITY.md` and `data/project_identity.json` — canonical names ("TBH: Task Bar Hero" / "Whisker Realm" / "Purralia").
4. `docs/ASSET_MAP.md`, `data/asset_catalog.json`, `data/asset_shortcuts.json` — asset usage.
5. Local `README.md` files under `scenes/` and `scripts/` — folder-specific intent.

## Notes

- Godot version target: **4.x** (project declares `config/features=("4.2")`).
- No `.tscn`-authored layout exists yet — new UI should follow the code-first pattern in `main.gd` until scene files start landing under `scenes/ui`.
- Default texture filter is nearest-neighbor (`textures/canvas_textures/default_texture_filter=0`) because the art is pixel-scale — do not enable linear filtering globally.
