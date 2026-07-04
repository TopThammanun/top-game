# Playable Game Build Plan

This plan turns the current asset/runtime preview into a playable Godot game.

## Current Reality

The project currently has:

- Godot project booting successfully.
- Runtime asset catalog and shortcut lookup.
- An Emberhearth game shell with header, loot feed, map, party, monsters, and taskbar.
- Design/data specs for world, clans, loop, combat, economy, sound, and milestones.
- A four-hero starter party loaded from `data/units/starter_party.json`.
- A 10-wave Tangleborn combat run loaded from `data/combat/mvp_waves.json`.
- Timer-driven auto-battle with damage, healing, wave advance, wipe, and victory.
- Taskbar commands for burst, heal, AFK chest, upgrade, quest/inventory stubs, and replay.
- Local `user://save.json` persistence for Pawcoins, best wave, Reweave level, and AFK chest time.
- A screenshot smoke test that proves the playable window renders.

The project does **not** yet have:

- player-controlled map movement
- equipment loot drops or inventory management
- real audio cues
- production boss art or encounter scripting beyond the MVP telegraph
- the later `.res` + JSON mirror save format recommended for shipped builds

## Playable MVP Target

The first playable version should be a **single-region idle combat prototype**:

> The player opens the game, sees the Emberhearth map/taskbar, starts a 10-wave run, watches four cat heroes auto-battle enemies, triggers skills from the taskbar, wins a boss chest, claims rewards, upgrades party stats, and can replay the run stronger.

## MVP Acceptance

MVP is playable when all are true:

- Game boots into an Emberhearth screen, not an asset preview.
- Party of four heroes is visible.
- A run advances from wave 1 to wave 10.
- Enemies spawn per wave and can be defeated.
- Heroes and enemies have HP.
- At least two taskbar skill buttons are clickable.
- The boss on wave 10 has a telegraph and reward.
- Loot is awarded after waves and boss.
- Player can spend loot on at least one upgrade.
- Save/load persists currency, upgrade level, and best wave.
- `tools/capture_runtime_screenshot.ps1` captures a nonblank playable screen.

## Build Slices

### Slice 1 - Replace Preview With Game Shell

Goal: turn `main.tscn` from asset preview into a game shell.

Create:

- `scenes/ui/taskbar.tscn`
- `scripts/ui/taskbar.gd`
- `scenes/maps/emberhearth_map_view.tscn`
- `scripts/maps/emberhearth_map_view.gd`

Keep:

- `AssetRegistry`
- existing smoke screenshot workflow

Acceptance:

- Main screen has map area, taskbar area, wave label, currency label.
- Still renders with `tools/capture_runtime_screenshot.ps1`.

### Slice 2 - Unit And Enemy Runtime Data

Goal: instantiate party and enemies from data.

Create:

- `scripts/runtime/game_state.gd`
- `scripts/runtime/unit_state.gd`
- `scripts/runtime/wave_state.gd`
- `data/combat/enemies.json`

Acceptance:

- Four starter heroes load from `data/units/starter_party.json`.
- Wave 1 enemy appears.
- HP bars or numeric HP are visible.

### Slice 3 - Auto-Battle Loop

Goal: run combat automatically.

Implement:

- hero basic attacks
- enemy basic attacks
- target selection
- defeat detection
- wave advance

Acceptance:

- Running the game unattended clears early waves if stats allow.
- If all heroes die, run stops and shows retry.

### Slice 4 - Taskbar Skills

Goal: make the player do something meaningful.

Implement first two skills:

- Ironmane shield/taunt
- Cloudfur heal/cleanse

Optional third:

- Wildstripe burst attack

Acceptance:

- Clicking taskbar buttons changes combat outcome.
- Buttons show cooldown/readiness.

### Slice 5 - Rewards And Upgrade

Goal: finish the short idle loop.

Implement:

- wave coin rewards
- boss chest reward
- upgrade button
- simple party attack/HP upgrade

Acceptance:

- Clearing waves increases currency.
- Spending currency improves next run.
- First 5-minute session reaches a reward and upgrade.

### Slice 6 - Save/Load

Goal: make progression persistent.

Implement:

- save currency
- save upgrade level
- save best wave
- save last AFK timestamp placeholder

Acceptance:

- Closing and reopening preserves progress.

Status: landed for the prototype via `user://save.json` with
`schema_version: 1`. It persists Pawcoins, best wave, Reweave level, and the AFK
chest clock. A later production pass can move the primary save to `.res` and
keep JSON as a support mirror.

### Slice 7 - AFK Chest

Goal: add idle identity.

Implement:

- reward accrues over time while game is closed/open
- claim button in taskbar
- simple chest open feedback

Acceptance:

- Wait, claim, spend, replay loop works.

Status: landed at MVP level. `AFK Chest` grants capped local idle Pawcoins from
the saved chest clock, then saves immediately.

### Slice 8 - Boss And Polish Pass

Goal: make wave 10 feel like a real endpoint.

Implement:

- boss telegraph
- boss skill
- reward burst
- clearer visual feedback
- placeholder SFX if available or generated later

Acceptance:

- Wave 10 feels different from normal waves.
- Boss clear produces a clear reward moment.

Status: landed at MVP level. Wave 10 emits a Hushweave telegraph before the
boss strike window, and boss clear awards the visible boss chest currency
reward through the loot feed.

## Recommended File Architecture

- `scripts/runtime/`: pure game state and simulation.
- `scripts/maps/`: map presentation.
- `scripts/ui/`: taskbar, command slots, HP/currency labels.
- `data/combat/`: enemies, waves, affinities.
- `data/units/`: starter party and future unit definitions.
- `data/save/` should not be committed; runtime saves go through `user://`.

## First Implementation Order

1. Build `GameState` autoload with currency, wave, party, enemies.
2. Replace preview `main.gd` layout with real shell nodes.
3. Add four hero panels and one enemy panel.
4. Add a timer-driven auto-attack loop.
5. Add wave clear and wave advance.
6. Add taskbar buttons for shield/heal.
7. Add rewards and upgrade.
8. Add save/load.
9. Add AFK chest.
10. Polish boss/screenshot validation.

## Guardrails

- Do not build gacha before the basic combat loop is fun.
- Do not build multiple regions before Emberhearth wave 1-10 works.
- Do not add complex TileSet editing before the MVP proves the loop.
- Prefer readable gameplay state over visual polish for the first playable pass.
- Keep asset paths behind `AssetRegistry`.

## Next Concrete Task

Start Slice 1:

> Replace the asset preview main scene with a real game shell: Emberhearth map panel, taskbar panel, wave/currency labels, and placeholder party/enemy areas.
