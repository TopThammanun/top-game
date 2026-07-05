# Combat System

Implements steps 41-50 of `docs/TBH_GAME_SPEC_1_TO_100.md`.

## Combat Core — auto-battler engine (Plan A)

The combat is pivoting to a real-time 2.5D side-scrolling auto-battler (Cookie Run:
Kingdom architecture), keeping the TBH/Whisker Realm world. See the spec
`docs/superpowers/specs/2026-07-05-auto-battler-combat-pivot-design.md`. **Plan A**
(this section) is the pure-logic engine — no scene dependencies, fully headless-tested
via `tests/combat_core_test.tscn`. The live scene, state machine, and side-scroll
(Plan B) will consume it and replace the turn-based `BattleEngine`.

Pure-logic classes under `scripts/combat/` (all `RefCounted`; they cross-reference
each other via `const XxxClass = preload("res://…")`, not bare global `class_name`,
so the module resolves headless without a `.godot` class-cache import — see
`agents/sage/godot-runtime/decisions/headless-global-class-cache.md`):

- **`combat_enums.gd`** — `FsmState`, `Archetype`, `Lane`, `StatKey`, `ModifierType`,
  `BattlePhase`, plus `*_from_string` JSON parsers.
- **`stat_modifier.gd`** — one flat/percent modifier; permanence captured at creation
  (a temporary whose duration decrements past 0 is never mistaken for permanent).
- **`stat_system.gd`** — base stats (`HP/ATK/DEF`) + advanced stats (`CRIT_CHANCE`,
  `CRIT_DMG`, `ATK_SPD`, `COOLDOWN_REDUCTION`, `DMG_RESIST`, `DMG_RESIST_BYPASS`,
  `AMPLIFY`). Final value = `(base + Σ flat) × (1 + Σ percent)`. Current HP tracked
  separately; gear (deferred) plugs in as permanent modifiers.
- **`damage_calculator.gd`** — pipeline: `raw = ATK×ratio` → DEF ratio mitigation
  `raw×(raw/(raw+DEF))` → crit `×(1+CRIT_DMG)` → resist `×(1 − clamp(DMG_RESIST −
  attacker.DMG_RESIST_BYPASS, 0, 0.9))` → `×(1+AMPLIFY)` → floor at 1.
- **`combat_skill.gd`** — CRK "Starting Cooldown" (`remaining` begins at
  `starting_cooldown`), cooldown ticked as `delta × (1 + COOLDOWN_REDUCTION)`.
- **`skill_effect.gd`** — resolves `aoe_damage` / `heal` / `buff` / `stun`; stat
  effects mutate targets, `stun` returns a control descriptor for the FSM layer.
- **`character_factory.gd`** — JSON → battle-ready profile: `base = round(clan.base_* ×
  archetype.weights.*)` plus archetype/row advanced stats, lane, range, move speed,
  sprite shortcuts, and the clan's skill.

**Archetypes** (`data/combat/archetypes.json`) — `front_defense`, `front_charge`,
`mid_magic`, `ambush`, `bomber`, `ranged`, `support`, `healer` — each sets a default
lane, stat weighting, attack range, move speed, AI intent, and role-based sprite
shortcuts. TBH clans map onto them in `data/units/clans.json`; skills live in
`data/combat/skills.json`.

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
Combat feedback should be event-driven: the combat driver emits combat facts,
`GameState` owns the numbers, and presenter nodes play disposable tweens,
flashes, floating labels, and taskbar pulses. In the auto-battler pivot the
turn-based `BattleEngine` is replaced by `BattleManager` (Plan B), which
**re-emits the same signal vocabulary** (`damage_dealt`, `unit_defeated`,
`skill_used`, `boss_telegraph`) so this presenter layer keeps working.
