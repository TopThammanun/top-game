# Map And Taskbar Experience

Implements steps 51-60 of `docs/TBH_GAME_SPEC_1_TO_100.md`.

## Screen Model

The screen is split into:

- **Map / battle strip:** shows region, wave, party, monsters, HP, and the lane
  of action in one compact horizontal surface.
- **Taskbar / command surface:** contains skills, inventory, upgrades, quests, and reward claims.

This keeps the Task Bar Hero identity clear: the player commands the adventure through a compact persistent bar while the party continues acting.

## Battle Strip Layout

`EmberhearthMapView` renders the tile map as a layered side-on battle surface,
then places party and monster unit cells on one lower lane. Each visible map cell
has a base terrain tile and may have an overlay object stamp from the same
tilesheet. The `TileGrid` uses zero horizontal and vertical separation so map
blocks sit edge-to-edge. Party units anchor from left toward center; monsters
anchor from right toward center. This keeps the core action readable in a
taskbar-sized composition and avoids the old dashboard feel where the map and
combatants lived in separate rows.

The current stage intentionally reads more like a compact side battle strip than
a top-down board:

```text
[TileGrid background: village / road / water strip]
   |
   v
[UnitLayer lower lane]
   |-- party cells from left -> center
   |-- monster cells from right -> center
   |-- melee attackers temporarily walk toward target, then return
   |
   v
[Taskbar command surface]
```

Repeated monsters must have unique runtime ids. The enemy archetype remains in
`enemy_id`, while `id` is the instance id used by targeting, effects, and unit
cell lookup.

Unit cells use real role shortcuts:

- Party idle roles: `unit.tank_idle`, `unit.striker_idle`, `unit.support_idle`,
  `unit.healer_idle`.
- Party move roles: `unit.tank_move`, `unit.striker_move`, `unit.support_move`,
  `unit.healer_move`.
- Enemy idle roles: `unit.enemy_grunt_idle`, `unit.enemy_brute_idle`,
  `unit.enemy_boss_idle`.
- Enemy move roles: `unit.enemy_grunt_move`, `unit.enemy_brute_move`,
  `unit.enemy_boss_move`.
- The older generic roles (`unit.player_idle`, `unit.scout_idle`, etc.) remain
  available as compatibility shortcuts, but should not be used for new
  role-specific presentation.

## Emberhearth Map Start

The first playable map represents Emberhearth near Pawmont:

- a clear sandy battle lane
- grass variation and a water edge
- market stalls and crates
- house and tent object stamps
- banner/marker props near the monster side

Use `map.default_tilesheet` first. If later tileset work identifies a better
Emberhearth tile mix, update `data/asset_shortcuts.json` instead of hard-coding
paths.

Map plans should use named tiles from `data/maps/tile_names.json`, not raw
`[col,row]` pairs. Large props use object stamps:

```jsonc
{
  "x": 3,
  "y": 0,
  "width": 3,
  "height": 3,
  "tile": "house_orange",
  "mode": "stamp"
}
```

`tile` is the top-left name in `tile_names.json`. The renderer asks
`AssetRegistry.load_map_tile_offset(...)` for each cell in the stamp, so runtime
still slices through `AssetRegistry` and never loads from `asset_sliced/`.

## Taskbar Asset Shortcuts

Use:

- `ui.taskbar_panel`
- `ui.panel_dark`
- `ui.slot_empty`
- `ui.slot_weapon`
- `ui.slot_potion`
- `ui.button_normal`
- `ui.button_pressed`
- `ui.button_selected`
- `ui.hp_orb`
- `ui.mp_orb`
- `ui.energy_orb`
- `ui.icon_primary`

## Taskbar Commands

First command groups:

- skill slots
- inventory
- upgrade
- quest
- AFK chest
- replay

Command buttons should use distinct command icons/orbs from
`data/ui/taskbar_commands.json`, inside a stable slot frame. The taskbar panel
can stay visually quiet; the command surface should read through recognizable
icon silhouettes rather than a large decorative background.

## Current Game-Feel Feedback

The playable prototype now uses the map and taskbar as a reactive combat HUD:

- Party and monster sprites cycle real idle frames while visible.
- Units with `tank`, `dps`, or `enemy` roles switch to walk frames, move toward
  the target cell, strike, then return to their lane slot.
- Support and healer roles keep a short in-place ranged pulse instead of
  walking into melee.
- Hits flash and shake the target, then spawn red floating damage numbers.
- Heals flash green and spawn green floating recovery numbers.
- Skills pulse the party and the pressed taskbar slot.
- Cooldowns dim slots, show a numeric timer, and glow when ready.
- Boss telegraphs pulse the status line and flash living monsters purple.
- Loot, currency, AFK chest, and victory events pulse the feed/header and spawn
  short reward burst text.
- The current visual gate verifies the richer map and command bar through
  `tools/gate_check.ps1`, which runs `tests/bootstrap_test.gd` and captures
  `godot_runtime_screenshot.png`.

All effects are presenter-owned and temporary. They must not mutate HP, wave,
currency, save data, or battle outcomes.

Animation is also presenter-owned:

- `UnitState` exposes `idle_asset` and `move_asset` from unit/enemy data.
- `EmberhearthMapView` loads frame arrays through
  `AssetRegistry.load_sprite_frames(...)`.
- `EmberhearthMapView` swaps the visible `TextureRect.texture` during `_process`.
- A missing move sheet falls back to idle frames.
- Combat damage remains decided before the visual walk tween starts.

## Readability Rules

- Map view must be understandable at a glance.
- Keep background blocks flush; do not rely on visible grid gaps for separation.
- Do not hide combat state behind long text.
- Use icons, tooltips, pulses, and sound cues.
- Put reusable UI scenes in `scenes/ui`.
- Put map scenes in `scenes/maps`.
- Keep `main.gd` as composition, not the permanent home for every system.
- Keep source art under `asset/` immutable. Use `asset_sliced/` only as an
  offline reference for choosing tile names or object top-left positions.
