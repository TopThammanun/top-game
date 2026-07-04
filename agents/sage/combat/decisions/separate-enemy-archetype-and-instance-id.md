---
id: separate-enemy-archetype-and-instance-id
type: team_decision
title: Separate enemy archetype ids from runtime instance ids
domain: combat
tags: [combat, enemies, identity, targeting, ui]
status: proposed
enforcement: warn
applies_to: [combat, "scripts/runtime/**", "scripts/maps/**", "data/combat/**"]
source: ai
supersedes: ""
related: []
timestamp: 2026-07-04T00:00:00Z
---

## Pattern

When a wave can spawn the same enemy archetype more than once, each spawned unit
needs a unique runtime instance `id`. Keep the source archetype id in a separate
field such as `enemy_id`.

## Why

- Targeting signals (`damage_dealt`, `unit_defeated`) need to point at one
  concrete unit, not every enemy of the same kind.
- Presenter lookup tables such as `_cells_by_unit_id` collapse duplicate keys.
- Effects, HP refresh, defeat states, and layout positions become ambiguous when
  two live units share the same id.

## Do

- Generate a unique instance id when building the wave runtime state.
- Preserve the archetype id for balancing, loot tables, display rules, and
  analytics.
- Use instance ids in combat events and UI anchors.
- Add a test for any wave format that allows duplicate enemy ids.

## Avoid

- Using the catalog/data archetype id as the only runtime identity.
- Inferring uniqueness from display names; names are player-facing labels, not
  keys.
