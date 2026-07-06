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
- **Combat approach model (`battle_view.gd` `_act`/`_walk_toward`):** each unit walks toward nearest enemy until `abs(dx) <= attack_range` (from archetypes.json: melee 90-120 close in, support/healer 280, ranged 320 shoot from afar), then attacks on cadence. Ranges (archetypes.json): melee 90-120 close in; bomber 360, mid_magic 420, support/healer 400, ranged 500 attack from afar. `anim="move"` uses the Move sheet frames; `flip_h = dx > 0` faces travel dir. Movement owns `sprite.position.x` — never tween x at the same time (they fight).
- **Wave warp:** on clear, survivors march offscreen-right (0.6s tween), a full-screen `_warp_rect` flash (CanvasLayer layer=20) covers `_spawn_wave()` at ~0.8s (march must finish BEFORE the swap frees those sprites), then allies drop in at the left edge and `_act` walks them back into range.
- **Battle speed:** `Engine.time_scale` (1x/2x/3x cycle) is the whole-scene speed control; reset to 1.0 in `_ready`.
- **Formation by lane makes ranged look ranged.** Just bumping `attack_range` isn't enough — sort each side by `lane` (FRONT=0, MIDDLE=1, REAR=2) in `_place_side` so front-liners stand nearest the enemy (allies: lane DESC → front rightmost; enemies: lane ASC → front leftmost) and the backline sits behind them. Otherwise a squishy rear unit can spawn closest to the enemy. Ranges now: melee 90-120, bomber 480, mid_magic 560, support/healer 560, ranged 680.
- **UI kit (Franuka `asset/ui`, `asset/ui/Examples` = reference look):** warm parchment nine-slice panels + wooden buttons + banner ribbons. Curated shortcuts already exist: `ui.taskbar_panel`/`ui.panel_bright`(bgbox_02a)/`ui.panel_dark`(bgbox_03a), `ui.title_banner`, `ui.button_normal`/`_pressed`/`_selected`, `ui.slot_*`. All panels/buttons have LIGHT parchment centers → text must be dark brown (`INK`), except banner (dark wood → gold/cream text). Build via `NinePatchRect` (panels/bg) + `StyleBoxTexture` on `Button` (normal/hover/pressed = normal/selected/pressed textures); prefer the `_2x_` variant (swap `_1x_`→`_2x_` on the resolved id) for crisp margins that don't overlap at HUD sizes. Sizes: button 48x16, bgbox 48x48, banner 48x32, slot 16x16 (x2/x3 scaled).
- **More RPG UI pieces:** `Spellbook & Tabs/` (open book 256x160 + tabs + page-fold), `Sliders & Bars/` (SliderNN_Box frame 48x16 + Bar01-08 fills), `Resource orbs/` (Orb_HP/MP 48x48 + frames). Shortcuts added: `ui.book`, `ui.hp_bar_frame`(slider02_box), `ui.hp_bar_fill`, `ui.hp_orb_frame`.
- **Unit HP bars** (`_draw_hp`): draw the slider `_hp_frame_tex` (loaded 1x so its 16px height maps cleanly) via `draw_texture_rect` FIRST — the box has its own dark track — then a color-by-HP `draw_rect` fill inset ~4px inside it (green / yellow <34% / red enemy).
- **Book party menu** (`_build_book_content`): a modal on its own CanvasLayer (`_book_layer` layer=15). A full-rect `Button` with a translucent-black stylebox = dim backdrop that closes on click (NOT `flat=true` — flat skips stylebox overrides); the `ui.book` TextureRect (mouse STOP so book clicks don't close) with "PARTY" title + per-hero rows (skill icon + name + `_hp_bar_node` + HP text) split 2-per-page; wooden Close button. It's a snapshot built on open (Party button → `_toggle_book`).
- **Full-screen map:** author the plan at an aspect ~= the window (28x16 ~= 16:9). `_render_map` sets `tile_px = view.x / mw`, so width fills EXACTLY (28*45.7=1280) and height slightly overflows (no black band); `y_off = view.y - map_h` bottom-anchors. `_battle_y = y_off + map_h*0.55` puts the fight lane mid-screen. Opaque base fill uses `land_h = map_h*0.84` (water at rows 14-15). Don't leave the map short — the leftover sky gradient reads as "black empty space".
- **JRPG command HUD** (chosen over parchment for a "standard game" look): `_build_skill_bar` builds two dark `_jrpg_window` panels at the bottom — a PARTY window (`_build_party_row` → `_party_rows`: name + live HP bar + HP text, updated every frame in `_update_skill_bar`) and a SKILLS window (`_build_command_row` → `_skill_slots`: icon + name + cooldown/READY state, transparent Button per row → `_on_skill_pressed`). Taskbar + buttons + menu dropdown all use flat dark `StyleBoxFlat` (navy, steel border) to match. The parchment book menu is kept as the themed detail view.

## Do-Not-Repeat

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->
