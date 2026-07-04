---
id: deterministic-rng-per-battle
type: skill
title: Seed a per-battle RNG so results reproduce
domain: combat
status: proposed
source: ai
enforcement: advise
tags: [rng, determinism, combat, replays, offline, support]
---

Auto-battle turn-based games live and die on **reproducibility**. Player says
"the boss one-shot me on wave 47" — you want a seed and a replay, not a
guess. Create a per-battle `RandomNumberGenerator` seeded from
`(player_id XOR encounter_id XOR attempt_index)` and route **every** combat
roll (damage variance, crit, dodge, drop rolls) through it. Never call the
global `randi()` from combat code.

Determinism also unlocks offline reconciliation: when a player closes the game
mid-wave and reopens, replay the seeded run rather than "estimating" what
happened. And it lets QA reproduce Bengalis' burst crit chain on demand.

**Do:**

- Create `var rng := RandomNumberGenerator.new(); rng.seed = compute_seed(...)`
  at battle start; pass it into every roll.
- Log the seed on the battle-result screen (visible in a debug flag,
  copyable in a support ticket).
- Store the seed alongside the encounter in the save; a re-fight uses the
  same seed unless `attempt_index` increments.
- For "friendly" gacha rolls that must feel non-deterministic to the player,
  use a **separate** RNG seeded from wall-clock — combat determinism and
  gacha feel are different concerns.

**Avoid:**

- Global `randi()` / `randf()` inside combat logic. The moment two battles
  can share state, replays lie.
- Using `Time.get_unix_time_from_system()` for combat seeds — non-reproducible,
  and hostile to soft-launch bug reports.
- Multiple RNG streams that share a seed — one battle, one stream.
