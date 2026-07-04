---
id: priority-queue-turn-scheduler
type: skill
title: Schedule turns by time-to-act, not fixed round order
domain: combat
status: proposed
source: ai
enforcement: advise
tags: [scheduler, turn-order, speed, priority-queue, combat]
---

For a turn-based auto-battler with a Speed stat (and Galeweave buffs that
alter it), a **priority queue keyed by cumulative time-to-act** produces
natural, fair ordering. Every actor stores `time_to_next_act`; each tick
subtracts the smallest value across all actors, actor whose value hit zero
acts, then `time_to_next_act += base_cooldown / speed`. Fast units act more
often; slow ones catch up predictably.

This handles the common problems fixed-round schedulers stumble on:
speed-buff during a turn, revive mid-round, summon insertion, extra turns
from a proc. Add or remove an actor and the queue adjusts.

**Do:**

- Model as `class_name TurnQueue` with `push(actor)`, `pop_next()`, and
  `advance(dt)`; keep it engine-agnostic so you can unit-test it in headless.
- Break ties on equal `time_to_next_act` by a stable tiebreaker (party slot
  order, unit id) so re-runs match.
- Fire `signal actor_acts(actor)` from the scheduler; the actor listens and
  runs its FSM (see `godot-runtime/skills/enum-fsm-for-battle-actors.md`).
- Fold status effects into the scheduler as their own timed entries — DoTs
  and buffs "act" too, ticking on their own cadence.

**Avoid:**

- A hard-coded round loop (`for actor in party: actor.act()`) — you can't
  express extra turns, speed buffs, or interrupt priority without ugly flags.
- Recomputing turn order from scratch every tick — waste of CPU and doesn't
  compose with mid-turn effects.
- Coupling animation length to scheduler advance; the scheduler runs on
  logical time, animations are cosmetic — decouple them.
