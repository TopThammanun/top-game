# godot-runtime - Godot 4.x scene/script conventions

Rules the team follows for anything that runs inside Godot: autoloads, scenes,
scripts, and asset loading at runtime.

## Entries

- [rules.md](rules.md) - the standing rules
- [decisions/asset-registry-api.md](decisions/asset-registry-api.md) - the full `AssetRegistry` export surface (proposed - advise)
- [decisions/asset-registry-is-only-runtime-lookup.md](decisions/asset-registry-is-only-runtime-lookup.md) - always route runtime asset loads through `AssetRegistry` (proposed - block)
- [decisions/build-ui-in-code-from-shortcuts.md](decisions/build-ui-in-code-from-shortcuts.md) - prototype UIs assemble Controls in `_ready` using shortcut ids (proposed - advise)
- [decisions/wait-for-catalog-ready.md](decisions/wait-for-catalog-ready.md) - gate asset use on `AssetRegistry.loaded` or the `catalog_ready` signal (proposed - block)
- [decisions/game-state-is-single-owner-of-session-numbers.md](decisions/game-state-is-single-owner-of-session-numbers.md) - one autoload owns session numbers; presenters only read (proposed - advise)
- [decisions/presenter-owned-game-feel-effects.md](decisions/presenter-owned-game-feel-effects.md) - visual effects react to signals without owning state or layout (proposed - warn)
- [decisions/class-name-fails-inside-autoload-preloads.md](decisions/class-name-fails-inside-autoload-preloads.md) - use `const preload` + drop annotations inside preload chains (proposed - block)
- [decisions/unit-animation-assets-are-data-driven.md](decisions/unit-animation-assets-are-data-driven.md) - keep unit animation role ids in data and frame playback in presenters (proposed - advise)

## Skills

- [skills/prefer-signals-over-polling.md](skills/prefer-signals-over-polling.md) - event-driven wiring beats per-frame checks (proposed - advise)
- [skills/resources-for-data-not-scripts.md](skills/resources-for-data-not-scripts.md) - units/skills/items as `.tres` Resources (proposed - advise)
- [skills/enum-fsm-for-battle-actors.md](skills/enum-fsm-for-battle-actors.md) - one enum + one `_set_state` transition point per actor (proposed - advise)
- [skills/audio-bus-layout.md](skills/audio-bus-layout.md) - Music / SFX / Ambient / Voice / UI buses (proposed - advise)
- [skills/tilemaplayer-one-per-layer.md](skills/tilemaplayer-one-per-layer.md) - Godot 4.3+ `TileMapLayer`, one node per layer (proposed - advise)
