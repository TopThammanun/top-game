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

## Roguelike run (Slice 1)

The pivot's real-time driver (`scripts/combat/battle_view.gd`) now wraps combat in
a Vampire-Survivors-style card-draft run, layered on top of the Combat Core above
without changing it. Full design: `docs/superpowers/specs/2026-07-12-roguelike-draft-pivot-design.md`.

Pure-logic classes under `scripts/roguelike/` (all `RefCounted`, headless-tested
via `tests/roguelike_test.tscn` / `tests/roguelike_gamestate_test.tscn`, same
preload-const pattern as Combat Core):

- **`run_state.gd`** (`RunState`) — the run-scoped numbers: shared party XP curve
  (`xp_to_next`/`add_xp`, quadratic-ish growth), `party_ids` roster, `pending_levelups`
  counter, `party_cap` (5), and `upgrades`/`passives` — the accumulated, resolved
  non-recruit picks from every draft this run.
- **`card_data.gd`** (`CardData`) — one draft card parsed from `data/roguelike/cards.json`
  (`recruit` / `stat` / `skill` / `passive` types); `bind_to_unit(clan_id)` clones a
  card scoped to one specific ally.
- **`card_system.gd`** (`CardSystem`) — the pool + weighted 3-card draw
  (`data/roguelike/cards.json`, rarity-weighted, recruit weight tapers as the party
  fills up); `resolve(card, run)` returns a scene-free descriptor dictionary the
  scene applies (never touches `StatSystem` itself); guarantees at least one
  non-recruit upgrade per draft when the pool has one.
- **`scripts/ui/draft_view.gd`** (`DraftView`) — the modal 3-card overlay (reused
  for both the pre-run starter pick and every level-up draft), emits `chosen(index)`.

**The loop, driven by `battle_view.gd`:**

1. **Pre-run pick** — `_begin_starter_pick()` freezes on boot (`_phase = "levelup"`,
   `_picking_starter = true`) and shows one card per starter clan. Picking calls
   `GameState.seed_run_party(clan_id)` (party of 1) and creates the `RunState`.
2. **Shared XP** — kills and wave-clears feed `RunState.add_xp(...)`; `_process()`
   gates on `_phase == "fighting" and _run.pending_levelups > 0` and calls
   `_open_draft()`, which sets `Engine.time_scale = 0.0` (pausing combat; input is
   not time-scaled so the overlay stays interactive) and draws 3 cards via
   `CardSystem.draw`.
3. **Pick applies** — `_apply_pick` routes a resolved card to `_apply_recruit` (grows
   `RunState.party_ids`, arrives next wave) or `_apply_one_upgrade` (stat/skill/passive,
   appended to `RunState.upgrades` and applied immediately to living allies via the
   existing `StatModifier`/`CombatSkill` mutation paths). Multiple pending levels
   re-open the draft until `pending_levelups` reaches 0, then time scale resumes.

**Key invariant — upgrades are re-applied every wave.** `_spawn_wave` rebuilds each
ally's `StatSystem`/`CombatSkill` from scratch every wave swap, so a permanent draft
buff would be lost on the next wave if it only lived on the old (freed) unit. To
prevent this, `_spawn_wave` replays the full `RunState.upgrades` list onto every
freshly-built unit before the wave starts. Treat `RunState.upgrades` as the single
source of truth for permanent run buffs — never mutate a built unit's stats/skill
outside that list without also recording the resolved descriptor there.

**Recruit next-wave:** a `recruit` pick calls `GameState.recruit_member(clan_id)`
(appends a `UnitState`, de-duped) and `RunState.add_member(clan_id)`; the new ally
does not spawn mid-wave — `_do_wave_swap` re-reads `GameState.party` on the next
`_spawn_wave`, so the recruit appears at the start of the following wave.

**Endless procedural scaling:** past the authored `MAX_WAVE` (10) catalog, `WaveState.for_wave`
(`scripts/runtime/wave_state.gd`) generates enemies procedurally instead of erroring
(boss every 5th wave, `wave_number % 5 == 0`), and `battle_view._scale_enemy` layers a
per-wave stat multiplier (`HP`/`ATK` × `1.12^(wave-1)`, as a permanent `StatModifier`)
onto each spawned enemy — so the run never "wins", it only ends on a wipe. The wave/party
caps that previously hard-stopped at wave 10 / a party of 4 are lifted for run mode
(`GameState.advance_to_wave`, `RunState.party_cap`).

**End of run:** on a wipe, `_end("lost")` calls `GameState.end_run(result, reward)`,
which banks an end-of-run currency reward (`_wave * 8`), updates `best_wave`, and saves.
This is separate from the in-run currency income the pivot driver already grants — a
per-kill gold drip in `_kill` (`6 + _wave * 2` per enemy) and the BASE-screen collect —
none of which routes through the legacy `mark_wave_cleared`/`mark_wipe` path (that path
belongs to the retired turn-based `BattleEngine` and is unrelated to this loop).

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
