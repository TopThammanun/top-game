# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-07-05

## User Preferences

<!-- How the user likes things done. Code style, tools, patterns, communication. -->

## Key Learnings

- **Project:** top-game
- **Description:** Starter Godot project for prototyping **TBH: Task Bar Hero**, an idle + turn-based RPG set in **Whisker Realm** on the world of **Purralia**.
- **Overworld autotile tiles have scalloped TRANSPARENT corners.** The `map.default_tilesheet` grass/sand/water tiles (e.g. `grass`, `sand`) are autotile pieces meant to composite over an opaque base — used as flat full tiles their transparent gaps let whatever is behind (the sky gradient) bleed through as murky specks. Fix: draw an **opaque ground ColorRect behind the tilemap** (see `battle_view.gd` `_render_map` base/shore fills) before laying tiles.
- **`asset/map/Examples/*.gif`** are the target look for maps (connected coastlines, sand shore between grass/water, winding paths). `Tilesheet (Animated Reference).gif` shows the sheet layout: nature/decor top, water+sand autotile blobs mid, buildings/market/tents lower.
- **Reference tiles by sliced PNG, not guesswork.** `asset_sliced/tiles/<sheet>/1x/*.png` + `index.json` (tile_col/tile_row + role) are ground truth for what a named tile actually looks like; the `terrain_swatch_foliage_*` 3x3 blocks are decorative sample frames, not terrain.
- **Mini icons:** `ui_2x_mini_icon_icon_NN` (01-32). Handy glyphs: 01 star, 03 heart, 09 sword, 10 blue shield, 13 magic sparkle, 14 red cross.
- **Skill UI pattern (`battle_view.gd`):** bottom `Control` skill bar, one `Button` (flat, transparent) per ally-with-skill over a `Panel` (StyleBoxFlat, gold border + shadow when ready) + `ColorRect` cooldown shade draining top→down + `TAP`/seconds label. Skills are manual tap-to-cast with a `AUTO_CAST_GRACE` (2.2s) auto-fire fallback so the game stays hands-off.
- **Shared map plan:** `data/maps/emberhearth_map_plan.json` drives BOTH the legacy `emberhearth_map_view.gd` (TileGrid) and the new `battle_view.gd` background. Editing its `map_width`/`map_height` affects both; `bootstrap_test.gd` derives expected TileGrid cell count from the plan (don't hardcode).
- **HUD draw order = child order in the CanvasLayer.** A translucent panel added AFTER a label draws over (dims) it. Fix by reordering: `_hud_layer.move_child(_taskbar, 0)` pushes the taskbar bg behind the title/wave labels. (bug: faded taskbar title.)
- **Combat approach model (`battle_view.gd` `_act`/`_walk_toward`):** each unit walks toward nearest enemy until `abs(dx) <= attack_range` (from archetypes.json: melee 90-120 close in, support/healer 280, ranged 320 shoot from afar), then attacks on cadence. `anim="move"` uses the Move sheet frames; `flip_h = dx > 0` faces travel dir. Movement owns `sprite.position.x` — never tween x at the same time (they fight).
- **Wave warp:** on clear, survivors march offscreen-right (0.6s tween), a full-screen `_warp_rect` flash (CanvasLayer layer=20) covers `_spawn_wave()` at ~0.8s (march must finish BEFORE the swap frees those sprites), then allies drop in at the left edge and `_act` walks them back into range.
- **Battle speed:** `Engine.time_scale` (1x/2x/3x cycle) is the whole-scene speed control; reset to 1.0 in `_ready`.

## Do-Not-Repeat

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->
