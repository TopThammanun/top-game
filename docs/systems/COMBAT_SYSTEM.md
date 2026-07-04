# Combat System

Implements steps 41-50 of `docs/TBH_GAME_SPEC_1_TO_100.md`.

## Party Model

The standard party has four units:

- Front: tank or sturdy starter.
- Middle: DPS, ambush, or caster.
- Rear: support and healer.

The default teaching formation is 1 tank, 1 DPS, 1 support, 1 healer.

## Action Model

Each unit has:

- automatic basic action
- passive identity
- active skill/ultimate
- optional auto-cast toggle later

Skill timing should be readable and satisfying without becoming high-APM.

## Waves

MVP combat is a 10-wave run:

- waves 1-3: basic enemies
- waves 4-6: mixed roles and first affinity lesson
- wave 7: reward milestone
- wave 8-9: pressure waves
- wave 10: boss

Wave milestones must create visible, audible, and numerical reward feedback.

## Threadweaving Affinities

- **Emberweave:** damage over time, burst, warmth.
- **Tideweave:** healing, flow, recovery.
- **Galeweave:** speed, crit, dodge.
- **Stoneweave:** shields, armor, stability.
- **Hushweave:** enemy corruption, silence, slow, Unravel threat.

Hushweave is not a normal hero element during early content. It marks forbidden or hostile Unravel influence.

## Boss Rule

Bosses need a short telegraph and one clear response window:

- shield now
- heal soon
- burst during exposed state
- cleanse Hushweave
- focus the knot

## Combat UI

Combat UI must show:

- party HP
- cooldown / skill readiness
- ultimate readiness
- enemy wave number
- loot feed
- boss telegraph

The UI must preserve taskbar feel and avoid covering the map with long instructions.
Combat feedback should be event-driven: `BattleEngine` emits combat facts,
`GameState` owns the numbers, and presenter nodes play disposable tweens,
flashes, floating labels, and taskbar pulses.
