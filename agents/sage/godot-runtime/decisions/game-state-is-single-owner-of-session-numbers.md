---
id: game-state-is-single-owner-of-session-numbers
type: team_decision
title: GameState autoload is the single mutable owner of session numbers
domain: godot-runtime
tags: [autoload, state, gameplay, boundary]
status: proposed
enforcement: advise
applies_to: [godot-runtime, "scripts/**", "scenes/**"]
source: ai
supersedes: ""
related: []
timestamp: 2026-07-04T00:00:00Z
---

## Pattern

Session-lifetime gameplay numbers — currency, wave index, party unit state,
run status — live in **exactly one** autoload (`GameState` for TBH). Every
other scene, node, or script is a **reader**. Only `GameState`'s own methods
(`apply_damage`, `add_currency`, `advance_to_wave`, …) may mutate the fields.

## Why

- Prevents the "who owns this number" bug — the classic RPG symptom where two
  scenes both track HP and drift apart under lag or scene reload.
- Lets us swap presentation (map view, taskbar, arena view) without ever
  worrying about whether the new view will re-init the state.
- Makes save/load trivial: `GameState.snapshot()` and `GameState.restore()` are
  the only two entry points that ever touch persistence.
- Godot autoloads persist across scene changes for free — matches the shape of
  the data.

## Do

- Put mutable session state under a single autoload node.
- Expose typed getters (`get_unit_by_id`) and named mutators (`apply_damage`,
  `add_currency`, `advance_to_wave`).
- Emit signals for every mutation (`party_changed`, `currency_changed`,
  `wave_changed`) so presenters bind once and forget.
- Guard `_bootstrap_state()` with `if ready: return` — idempotent.

## Avoid

- Reading gameplay numbers directly off scene nodes (`hp_bar.value` is a
  presentation artifact, not a source of truth).
- Mutating `GameState` fields from outside its own methods — Godot GDScript
  cannot enforce private, so we enforce it by convention and by never wiring
  the mutation into a foreign script.
- Storing the same number in two places (e.g. `GameState.wave` AND
  `MapView.current_wave`). The presenter reads `GameState.wave` every frame it
  needs it, or subscribes to `wave_changed`.
