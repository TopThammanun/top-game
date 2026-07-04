---
id: enum-fsm-for-battle-actors
type: skill
title: Use an enum-based FSM for battle actors
domain: godot-runtime
status: proposed
source: ai
enforcement: advise
tags: [state-machine, combat, actors, godot]
---

Auto-battle units cycle through a small, fixed set of states — Idle,
Winding-Up, Attacking, Recovering, Casting, Stunned, Dead. Model them as an
`enum State { IDLE, WINDUP, ATTACK, RECOVER, CAST, STUN, DEAD }` with a
single `func _set_state(next: State)` transition point. That gives you one
place to emit `state_changed(prev, next)`, one place to reject illegal
transitions (`DEAD` is terminal), and one place to fire animations / SFX.

This scales better than the two common failure modes: (a) booleans
(`is_attacking`, `is_stunned`) that can contradict each other, and
(b) heavyweight `Node`-based state machines that add scene complexity for
what is really seven values.

**Do:**

- Store one `State` per actor. Route all changes through `_set_state`.
- Fire `state_changed` on transition; let anim/SFX/UI listen.
- Guard illegal transitions (`assert(current != State.DEAD)`).
- Reserve `WINDUP` and `RECOVER` frames as the intervention window — this is
  where the player's "gut check to fire NP" input lands (per §2.1 of the setting).

**Avoid:**

- A pile of `is_x` booleans on the actor. They drift out of sync.
- Full node-based FSMs for every actor — the ceremony isn't worth it at 6-clan
  scale. Reach for a node FSM only when a unit's state graph exceeds ~10 nodes.
- Coupling animation state to gameplay state 1:1; animations can outlive the
  gameplay state (recovery frames continuing after `DEAD`).
