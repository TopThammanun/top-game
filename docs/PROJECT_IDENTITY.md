# Project Identity

This file implements step 1 of `docs/TBH_GAME_SPEC_1_TO_100.md`.

## Canonical Names

- **Production title:** TBH: Task Bar Hero
- **Fantasy title:** Whisker Realm
- **Primary world:** Purralia (เพอร์ราเลีย)
- **Genre:** Idle + Turn-based RPG
- **Tone:** cozy medieval fantasy

## Usage Rules

- Use **TBH: Task Bar Hero** for the Godot project name, repository docs, builds, and technical references.
- Use **Whisker Realm** as the fantasy-facing title when discussing the world, story package, or player-facing setting.
- Use **Purralia** as the main world/continent name inside narrative, region progression, and lore.
- Treat `project_main_setting.md` as the source of truth for lore and tone.
- Treat `data/project_identity.json` as the machine-readable identity file for AI agents and scripts.

## One-Line Pitch

TBH: Task Bar Hero is an idle + turn-based RPG set in Whisker Realm, where a party of cat knights restores Purralia by reweaving the Yarnthread before The Unravel pulls the world apart.

## Current Implementation Touchpoints

- `project.godot` uses `TBH: Task Bar Hero` as `config/name`.
- `README.md` introduces the project with the canonical production and fantasy names.
- `docs/TBH_PROJECT_BRIEF.md` points future work at the same identity.
- `docs/TBH_GAME_SPEC_1_TO_100.md` remains the numbered implementation roadmap.
