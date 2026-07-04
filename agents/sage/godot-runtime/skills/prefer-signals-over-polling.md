---
id: prefer-signals-over-polling
type: skill
title: Prefer signals over _process polling
domain: godot-runtime
status: proposed
source: ai
enforcement: advise
tags: [signals, performance, godot, decoupling]
---

In Godot 4.x, decouple systems with signals instead of watching state from
`_process`. Signals are event-driven and fire once per state change; polling
runs every frame whether anything changed or not. For an idle game that stays
open for hours, avoidable per-frame work is exactly the shape of bug that
eats battery on mobile and pins CPUs on desktop.

The `AssetRegistry` autoload in this repo already models it — `catalog_ready`
is a one-shot signal; callers connect with `CONNECT_ONE_SHOT` and never poll
`AssetRegistry.loaded` in `_process`.

**Do:**

- Expose `signal wave_cleared(wave_number)`, `signal unit_died(unit_id)`,
  `signal drop_granted(item_id)`. Connect UI/audio/save-writer to them.
- Use `await some_node.signal_name` for one-shot flows (cutscene beats,
  reward ceremonies) — reads like synchronous code.
- Disconnect signals in `_exit_tree` when the emitter outlives the receiver,
  or use `CONNECT_ONE_SHOT` when the receiver only wants the first fire.

**Avoid:**

- `if some_flag: do_thing()` inside `_process` — that's a signal in disguise.
- Long `_process` bodies on nodes that don't animate every frame; use `set_process(false)` on idle.
- Direct parent→child method calls that reach across scene boundaries; emit,
  don't reach.
