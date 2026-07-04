---
title: design-docs standing rules
domain: design-docs
status: proposed
source: ai
applies_to: [design-docs, "docs/**", "project_main_setting.md", "data/design_sources.json", "data/project_identity.json"]
---

## Where things live

- `project_main_setting.md` (repo root) — lore, tone, world, clans, magic,
  monetization principles, sound direction. The **canonical setting doc**.
- `docs/TBH_GAME_SPEC_1_TO_100.md` — the ordered implementation spec (100 steps).
  Companions: `docs/SPEC_PROGRESS_*.md` track which steps are done.
- `docs/DESIGN_SOURCE_OF_TRUTH.md` — the tie-break order and folder contract.
  Mirrors `data/design_sources.json`; keep them in sync.
- `docs/PROJECT_IDENTITY.md` + `data/project_identity.json` — canonical names.
- `docs/ASSET_MAP.md` — how AI agents find and use assets (paired with
  `data/asset_shortcuts.json` and `data/asset_catalog.json`).
- `docs/world/*.md` — WORLD_BIBLE, STORY_AND_REGIONS, TONE_GUIDE, PEOPLES_AND_CLANS.
- `docs/systems/*.md` — CORE_LOOP, COMBAT_SYSTEM, MAP_AND_TASKBAR, PROGRESSION_AND_ECONOMY, MONETIZATION_POLICY.
- `docs/audio/*.md` — SOUND_AND_FEEL.
- `docs/production/*.md` — MILESTONES_AND_ACCEPTANCE, ISSUE_PLAN, PLAYABLE_GAME_BUILD_PLAN.
- `docs/*.generated.md` — machine output. Regenerate, never edit.

## Style patterns observed

- Filenames are `SCREAMING_SNAKE_CASE.md` for design/spec docs; `README.md` for
  folder-scoped intent.
- Machine-parseable summaries live in `data/*.json` next to their prose sibling
  (e.g. `docs/PROJECT_IDENTITY.md` ↔ `data/project_identity.json`). Both must
  agree — treat the JSON as the machine-readable projection of the prose.
- Cross-references use repo-relative paths (`docs/systems/CORE_LOOP.md`), not
  absolute URLs, not `res://` paths.
- The **AI Rule** section in `docs/DESIGN_SOURCE_OF_TRUTH.md` lists the docs an
  agent must read before making gameplay/lore/asset/UI changes — respect it.

## Identity vocabulary (do not paraphrase)

- Production title: **TBH: Task Bar Hero** (for Godot project name, README, build labels).
- Fantasy title: **Whisker Realm** (for lore, marketing, in-world copy).
- Primary world: **Purralia** (for narrative setting, regions, lore).
- Player role: **Threadbound**.
- Core conflict: **The Unravel is loosening the Yarnthread that holds the Great Weave together.**
- Pillars: **Sound Design · Cuteness · Idle party optimization · Friendly monetization.**

Use each label in its lane — a build export never says "Whisker Realm", the
world bible never says "TBH: Task Bar Hero".
