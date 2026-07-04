---
id: presenter-owned-game-feel-effects
type: team_decision
title: Presenter-owned game-feel effects do not own gameplay state
domain: godot-runtime
tags: [godot, ui, effects, state-boundary, game-feel]
status: proposed
enforcement: warn
applies_to: [godot-runtime, "scripts/**/*.gd", "scenes/**/*.tscn"]
source: ai
supersedes: ""
related: [game-state-is-single-owner-of-session-numbers]
timestamp: 2026-07-04T00:00:00Z
---

## Pattern

Combat and reward effects are presenter-owned reactions to existing signals.
They may create tweens, flashes, temporary labels, and short-lived helper nodes,
but they must not compute or mutate HP, currency, waves, rewards, saves, or run
status.

## Why

- Keeps `GameState` and `BattleEngine` authoritative even when effects overlap,
  get interrupted, or are skipped in headless mode.
- Lets visual polish improve without changing balance or persistence.
- Keeps effect failures best-effort: a missing cell, freed sprite, or completed
  scene transition should no-op instead of breaking the run.
- Prevents temporary labels and particles from changing layout size and pushing
  required UI such as the taskbar off screen.

## Do

- Drive effects from existing signals such as `damage_dealt`,
  `boss_telegraph`, `loot_event`, `currency_changed`, and `run_ended`.
- Put unit-local floating labels and sparks under the visible unit sprite or a
  dedicated non-layout overlay.
- Put screen-level reward bursts under a root-level overlay or presenter node,
  not inside a `VBoxContainer`, `HBoxContainer`, or content grid.
- Guard lookups: if the unit cell, sprite, or slot is gone, return without
  error.
- Free temporary effect nodes with `queue_free()` when their tween ends.

## Avoid

- Mutating `GameState` from an effect method.
- Letting a tween completion decide battle outcomes or rewards.
- Adding temporary labels directly to layout containers where their minimum size
  can move the map, feed, or taskbar.
- Hard-coding asset paths for effects when existing visible textures or
  `AssetRegistry` shortcuts can be reused.
