---
title: godot-runtime standing rules
domain: godot-runtime
status: proposed
source: ai
applies_to: [godot-runtime, "scripts/**", "scenes/**", "project.godot"]
---

## Engine contract

- Godot 4.x (`config/features=PackedStringArray("4.2")` in `project.godot`).
- GDScript for all game code (no C#). Static typing everywhere: `var x: int`, `func f() -> void`.
- Main scene: `scenes/main/main.tscn`. Autoloads: registered in `project.godot` under `[autoload]`.
- Default viewport `1280x720`, `canvas_items` stretch with `expand` aspect.
- Default texture filter is `0` (nearest) — this is a pixel-art project; never change it without reason.
- Default font is a bitmap TTF (`FantasyRPGtext (size 8).ttf` at size 16). Match the pixel aesthetic when picking fonts.

## Runtime asset loading

- **Always go through `AssetRegistry`** for textures, tilesheets, fonts, and any file under `asset/`. Never hard-code `res://asset/...` paths in game code.
- Prefer shortcut ids (`"unit.player_idle"`, `"ui.taskbar_panel"`) over raw catalog ids so art can be swapped without touching scenes.
- Gate any asset use on `AssetRegistry.loaded` or the `catalog_ready` signal — the autoload reads JSON on `_ready()`, callers cannot assume it's populated.

## Folder contract (mirrors `data/design_sources.json`)

- `scenes/main` — boot scene and prototype shell.
- `scenes/maps` — playable map scenes.
- `scenes/ui` — taskbar and reusable UI scenes.
- `scripts/autoload` — global autoload services (one node per file, `extends Node`).
- `scripts/main` — prototype composition.
- `scripts/maps` — map-specific behaviour.
- `scripts/ui` — UI-specific behaviour.
- `scripts/runtime` — pure game state and simulation (no scene tree, no rendering). `GameState` autoload + data classes like `UnitState` / `WaveState` live here.
- `resources/units` — future unit definition `.tres` resources.
- `resources/commands` — future taskbar command `.tres` resources.
- `tests` — headless test scripts. Run with `godot --headless -s res://tests/<name>.gd` or via `tools/gate_check.ps1`.

Add a new folder only when it maps to one of the domains above; if it doesn't
fit, extend `data/design_sources.json` first so the contract stays truthful.

## Style patterns observed

- Snake_case for files, funcs, vars, signals. PascalCase for node names (`"MapPanel"`, `"TaskbarRow"`).
- `_ready()` composes the whole scene tree in code when the scene file is a stub Control — small helpers (`_make_panel`, `_make_margin`, `_make_label`, `_make_texture_rect`) keep it readable.
- Signals connect with `CONNECT_ONE_SHOT` when the receiver only needs the first fire (e.g. `catalog_ready`).
- Failure reporting uses `push_warning` for recoverable gaps (missing asset) and `push_error` for contract violations (catalog wrong shape). Never `printerr` or silent swallow.
- Panels use `StyleBoxFlat` with a warm border colour (`Color(0.33, 0.27, 0.18)`) — this is the project's UI accent; reuse it for parity.

## Reusable assets

- `AssetRegistry` (autoload) — the runtime asset service. Full API in `decisions/asset-registry-api.md`.
- `scripts/main/main.gd`'s `_make_*` helpers — the current pattern for building Controls in code. Lift them into a shared helper only when a second caller appears; until then, duplication is fine.
