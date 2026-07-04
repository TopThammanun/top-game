# TBH Project Brief

## Canonical identity

- Production title: **TBH: Task Bar Hero**
- Fantasy title: **Whisker Realm**
- Primary world: **Purralia**
- Setting source: `project_main_setting.md`

## Starter shape

TBH is currently structured as a tactical-map-and-taskbar prototype for an idle + turn-based RPG set in Whisker Realm:

- The map area is the main play surface.
- The taskbar is the command surface for hero actions, units, resources, and quick slots.
- Asset lookup should go through `AssetRegistry` whenever possible.
- Original assets stay in `asset/`; generated lookup data lives in `data/`.

## Suggested scene split

- `scenes/main/main.tscn`: boot scene and prototype shell.
- `scenes/maps/`: future playable map scenes.
- `scenes/ui/`: future reusable taskbar, slot, command, and resource widgets.
- `scripts/autoload/asset_registry.gd`: global asset lookup.
- `scripts/main/main.gd`: current prototype composition.

## Design source chain

- `project_main_setting.md`: source of truth for lore and tone.
- `docs/TBH_GAME_SPEC_1_TO_100.md`: implementation sequence.
- `docs/DESIGN_SOURCE_OF_TRUTH.md`: source authority and folder contracts.
- `docs/world/WORLD_BIBLE.md`: Purralia/Great Weave/Yarnthread/The Unravel foundation.
- `docs/world/STORY_AND_REGIONS.md`: act 1-5 campaign spine.
- `docs/world/TONE_GUIDE.md`: tone guardrails.
- `docs/world/PEOPLES_AND_CLANS.md`: playable people, six clans, and starter party rules.
- `docs/systems/CORE_LOOP.md`: idle/session loop.
- `docs/systems/COMBAT_SYSTEM.md`: party, waves, affinities, boss, and UI rules.
- `docs/systems/MAP_AND_TASKBAR.md`: screen model and taskbar command surface.
- `docs/systems/PROGRESSION_AND_ECONOMY.md`: progression, equipment, currencies.
- `docs/systems/MONETIZATION_POLICY.md`: fair gacha, battle pass, cosmetics, ads.
- `docs/audio/SOUND_AND_FEEL.md`: music/SFX/cat voice/reward audio direction.
- `docs/production/MILESTONES_AND_ACCEPTANCE.md`: milestone acceptance criteria.
- `docs/production/ISSUE_PLAN.md`: issue-ready implementation slices.
- `docs/production/PLAYABLE_GAME_BUILD_PLAN.md`: practical order for turning the preview into a playable game.

## Near-term build path

1. Create a real TileSet resource from `map.default_tilesheet`.
2. Add a playable `MapView` scene with TileMapLayer nodes.
3. Extract the bottom command area into `scenes/ui/taskbar.tscn`.
4. Create command data resources for taskbar buttons.
5. Create unit data resources that reference catalog ids for idle/move sprites.
