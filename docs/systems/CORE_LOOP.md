# Core Loop

Implements steps 31-40 of `docs/TBH_GAME_SPEC_1_TO_100.md`.

## Primary Loop

1. Open game.
2. Claim AFK rewards.
3. Open chest or collect loot feed.
4. Upgrade party, gear, or base.
5. Push waves or the next region node.
6. Return to idle progression.

## Moment Cadence

During active play, something positive should happen every 2-3 seconds:

- coin tick
- tiny loot drop
- skill ready pulse
- wave progress sound
- cute party animation
- AFK chest fill
- micro quest completion

If a prototype has more than 3 seconds of silence during active play, add feedback before adding new systems.

## Auto-Battle Rule

Combat is automated by default. Player agency comes from:

- triggering skills
- choosing upgrades
- choosing party composition
- selecting focus targets in boss moments
- claiming burst rewards
- deciding when to push or farm

## Session Targets

- First session: 5 minutes, ends with a clear reward and "one more run" feeling.
- Normal session: 3-10 minutes.
- Long idle session: can remain open without demanding attention.

## Balance Guardrails

- Offline rewards must feel useful but not make active play pointless.
- AFK chest opening must have strong audio/visual feedback.
- Progression walls must be treated as balance bugs unless intentionally declared as end-game gates.
- If retention drops, fix reward cadence and clarity before adding monetization.
