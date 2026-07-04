# Issue Plan

Implements the issue-ready part of step 100.

For the playable-game build sequence, use `docs/production/PLAYABLE_GAME_BUILD_PLAN.md` as the practical implementation order.

## Prototype Issues

1. Create Emberhearth `MapView` using `map.default_tilesheet`.
2. Extract taskbar UI into `scenes/ui/taskbar.tscn`.
3. Create command slot UI using `data/ui/taskbar_commands.json`.
4. Create starter party data resources from `data/units/starter_party.json`.
5. Implement MVP 10-wave combat using `data/combat/mvp_waves.json`.
6. Implement Threadweaving affinities from `data/combat/affinities.json`.
7. Add AFK reward chest loop from `data/systems/core_loop.json`.
8. Add first reward SFX placeholders from `data/audio/sound_cues.json`.
9. Add level/skill/equipment progression data from `data/economy`.
10. Add prototype acceptance checklist from `docs/production/MILESTONES_AND_ACCEPTANCE.md`.

## Vertical Slice Issues

1. Add friendly gacha and visible pity.
2. Add duplicate conversion to shard/exchange currency.
3. Add equipment affix reroll.
4. Add The Loomstead base progression.
5. Add cosmetics inventory.
6. Add adaptive music layer state machine.
7. Add second region: Silkspiredale or Tuna Coast.

## Soft Launch Issues

1. Add third playable region.
2. Add daily and weekly tasks.
3. Add guild or social-lite contribution system.
4. Add battle pass free and premium tracks.
5. Add first seasonal event loop.
6. Add KPI telemetry hooks for retention and session length.
