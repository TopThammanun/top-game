---
id: game-state-owns-prototype-json-save
type: team_decision
title: GameState owns the prototype JSON save boundary
domain: persistence
tags: [godot, save, prototype, game-state]
status: proposed
enforcement: advise
applies_to: [persistence, "scripts/runtime/game_state.gd", "scripts/main/**"]
source: ai
supersedes: ""
related: [save-schema-versioning, resource-save-with-json-mirror]
timestamp: 2026-07-04T00:00:00Z
---

For an early playable Godot prototype, `GameState` may own a small
schema-versioned `user://save.json` directly when no shipped `Resource` save
type exists yet.

Do:

- Keep the save boundary in the same autoload that owns the numbers being saved.
- Include `schema_version` from the first save.
- Save only gameplay progression fields, not presenter state.
- Treat JSON-primary as a prototype bridge toward the later `.res` plus JSON
  mirror production shape.

Avoid:

- Writing saves from UI scenes.
- Storing duplicate currency, wave, upgrade, or HP values in presenters.
- Treating prototype JSON as authoritative for leaderboards or anti-cheat.
