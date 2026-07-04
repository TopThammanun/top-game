---
id: offline-cap-and-afk-chest
type: skill
title: Cap offline gains at 8–12h and deliver them as one AFK chest
domain: idle
status: proposed
source: ai
enforcement: advise
tags: [idle, offline, afk, retention, dopamine]
---

Idle games gain their "cozy" from the *return* moment, not from unbounded
accrual. Cap offline progression at **8–12 hours** (the setting doc §2.2
picks the same window) and hand the whole batch back as **one AFK chest with
a ceremony** — jingle, orb sweep, number tick-up. Unbounded offline gains
train the player to check less often; a bounded cap plus a satisfying
delivery trains them to check twice a day.

On resume, compute the delta as `min(elapsed_secs, cap_secs) * rate` — do the
math from timestamps stored at close time; never trust in-memory counters
that could have been paused. Persist `last_close_ts` on `NOTIFICATION_WM_CLOSE_REQUEST`
and on `NOTIFICATION_APPLICATION_PAUSED` (mobile background).

**Do:**

- Cap = 8h for a very cozy loop, 12h for softer players who check overnight.
  Longer caps train "I don't need to open the game" — the opposite of retention.
- One "AFK chest" open per return; sub-batching kills the ceremony.
- Show the elapsed time and cap ("You were away 14h — capped at 12h") so the
  cap is honest, not a hidden nerf.
- Reconcile combat progress separately — offline waves use `deterministic-rng-per-battle`
  so the simulated fight is replayable, not "roughly what would have happened".

**Avoid:**

- Uncapped offline gains. First it feels generous; then it's the reason
  players stop opening the game.
- Real-money speed-ups on the AFK cap ("open now for +4h!") — cozy-audience
  poison, and it inverts the ceremony into anxiety.
- Silent partial deliveries. If you cap, tell the player. If you split, tell
  the player. Every reward moment is a chance to build or erode trust.
