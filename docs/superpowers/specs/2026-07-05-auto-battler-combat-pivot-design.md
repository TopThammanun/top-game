# Design: Pivot combat to a real-time auto-battler (Cookie Run: Kingdom architecture)

- **Date:** 2026-07-05
- **Status:** Approved design — foundational slice
- **Source research:** `CookieRunKingdom.html` (Thai-language deep-dive on Cookie Run: Kingdom's
  auto-battler combat + 6 engineered Unity/C# "AI prompts"). This spec **adapts** that
  Unity/C# architecture to **Godot 4.x / GDScript**.
- **Setting decision:** Keep the existing TBH: Task Bar Hero / Whisker Realm world, cat clans,
  units, and art assets. Only the combat **architecture** follows the research.

## 1. Goal & scope

Replace the current turn-based, `Timer`-tick combat with a **real-time 2.5D side-scrolling
auto-battler**: allies auto-advance left→right through waves, each entity runs its own finite
state machine with spatial aggro, damage flows through a proper stat/damage engine, and skills
fire on an auto-cast queue governed by a "Starting Cooldown".

This spec covers the **foundational playable slice only**. Two research systems are deliberately
deferred to follow-up specs (see §9).

### Research prompt → this slice mapping

| Research prompt (Unity/C#)                          | This slice (Godot) |
|-----------------------------------------------------|--------------------|
| P1 — BattleManager state machine + side-scroll + BaseEntity | ✅ `battle_manager.gd` + `battle_entity.gd` |
| P2 — Entity FSM + spatial aggro + Front/Middle/Rear lanes    | ✅ FSM + axis aggro + lanes |
| P3 — StatSystem + DamageCalculator + class archetypes        | ✅ `stat_system.gd` + `damage_calculator.gd` + archetypes |
| P4 — SkillManager + Starting Cooldown + AutoCast             | ✅ `skill.gd` + auto-cast in manager (basic) |
| P5 — Toppings + Treasures equipment                          | ⏸ Deferred (StatSystem accepts gear as modifiers) |
| P6 — Parallax camera + portrait UI + floating damage pool    | ⏸ Basic camera follow + HP bars + minimal HUD only |

## 2. Architecture: module map & boundaries

Two layers with a strict one-way dependency: **the live scene layer depends on the pure-logic
core; the core never depends on the scene.** The existing meta/idle layer is preserved.

### Keep (meta / persistence layer)
- `scripts/autoload/asset_registry.gd` — asset loading. Unchanged.
- `scripts/runtime/game_state.gd` — autoload: party roster, currency, upgrades, save, waves
  catalog. The battle reports results back via `mark_wave_cleared()` / `mark_wipe()`, so the
  idle/currency/save loop survives the pivot.
- `scripts/runtime/wave_state.gd` — defines which enemies spawn per wave (lightly adapted).

### Retire (with care — it is more entangled than a lone file)
- `scripts/runtime/battle_engine.gd` — the `Timer`-based turn engine, replaced by the real-time
  system. **Blast radius (traced):** `scripts/main/main.gd` instantiates it and drives the
  current playable prototype through it; `EmberhearthMapView` consumes its signals
  (`damage_dealt`, `unit_defeated`, `skill_used`, `boss_telegraph`) to render game-feel effects
  (lunges, hit flashes, camera); the taskbar routes skill buttons to it. It is documented across
  five Sage flow docs and `docs/systems/COMBAT_SYSTEM.md`.
- **Seam that de-risks the cutover (design decision):** the new `BattleManager` / `BattleEntity`
  **re-emit the same combat signal vocabulary** (`damage_dealt(source_id, target_id, amount)`,
  `unit_defeated(unit_id)`, `skill_used(skill_id)`, `boss_telegraph(message)`). The existing
  presentation/feedback layer keeps working against that contract, so retiring the turn engine
  does not orphan the map-view/taskbar feedback — only the tick source changes, not the events.
- `scripts/main/main.gd` and `scripts/ui/taskbar.gd` are **re-pointed**, not deleted: the "Start
  Battle" action loads `battle.tscn`, and skill buttons call `BattleManager.request_cast(...)`
  instead of `BattleEngine.trigger_skill_*()`.

### New — pure-logic core (`scripts/combat/`, all `RefCounted`, headless-testable)
| File | Responsibility |
|---|---|
| `combat_enums.gd` | `EntityFsmState`, `ClassArchetype`, `Lane`, `StatKey`, `ModifierType`, `BattlePhase` |
| `stat_system.gd` | base + advanced stats; holds modifiers; computes final values; tracks current HP |
| `stat_modifier.gd` | one flat/percent modifier (`stat`, `type`, `value`, `source`, optional `duration`) |
| `damage_calculator.gd` | static — the CRK damage pipeline (§4) |
| `skill.gd` | starting-cooldown init, cooldown ticked with CDR scaling, readiness query |
| `skill_effect.gd` | base effect + concrete effects (AoE damage / heal / buff / stun) — the `ISkillEffect` analog |

### New — live scene layer (`scripts/combat/` + `scenes/combat/`)
| File | Responsibility |
|---|---|
| `battle_manager.gd` (`Node2D`) | phase state machine, wave spawning, side-scroll advance, auto-cast controller |
| `battle_entity.gd` (`CharacterBody2D`) | wraps a `StatSystem`, runs per-entity FSM, spatial aggro, renders sprite via `AssetRegistry`, emits `died` / `damaged` / `skill_cast` |
| `scenes/combat/battle.tscn` | battle scene root, formation/spawn anchors, camera, background, minimal HUD |

## 3. StatSystem (research P3)

Every entity owns one `StatSystem`.

- **Base stats:** `HP`, `ATK`, `DEF`.
- **Advanced stats:** `CRIT_CHANCE`, `CRIT_DMG`, `ATK_SPD`, `COOLDOWN_REDUCTION`, `DMG_RESIST`,
  `DMG_RESIST_BYPASS`, `AMPLIFY`.
- **Final value:** `get_stat(key) = (base + Σ flat modifiers) × (1 + Σ percent modifiers)`.
- **Modifiers:** each carries a `source` string and optional `duration` (seconds). Buffs/debuffs
  expire on tick; **Toppings/Treasures (deferred) are simply permanent modifiers from a gear
  source** — the design needs no change to accept them later.
- **HP:** `current_hp` is tracked separately from the `HP` stat (which is max HP). `take_damage`,
  `heal`, `is_alive` live here.

## 4. DamageCalculator (research P3)

Static utility. Pipeline, strictly in order:

1. `raw = attacker.ATK × skill_ratio` (basic attacks use `skill_ratio = 1.0`).
2. **DEF mitigation (ratio curve):** `dmg = raw × (raw / (raw + defender.DEF))`.
   - Chosen over flat `ATK − DEF` for sane scaling across ~100 waves (diminishing returns,
     never negative, no hard `max(1, …)` cliff).
3. **Crit:** if `randf() < CRIT_CHANCE` → `dmg × (1 + CRIT_DMG)`.
4. **Resist (final multiplier):** `effective_resist = clamp(DMG_RESIST − attacker.DMG_RESIST_BYPASS, 0, 0.9)`;
   `dmg × (1 − effective_resist)`.
5. **Amplify:** `dmg × (1 + attacker.AMPLIFY)`.
6. Floor at `1`, round to int. Return a small result struct `{ amount, is_crit }` for UI/logs.

## 5. Class archetypes (research P3 `CharacterData` template)

Enum `ClassArchetype`: `FRONT_DEFENSE`, `FRONT_CHARGE`, `MID_MAGIC`, `AMBUSH`, `BOMBER`,
`RANGED`, `SUPPORT`, `HEALER`. Each archetype (in `data/combat/archetypes.json`) defines:
default `lane`, stat weighting (multipliers applied to a clan's base numbers), `attack_range`,
`move_speed`, and an AI intent tag. Existing TBH cat clans are mapped onto these archetypes.

| Archetype | Lane | Character |
|---|---|---|
| `FRONT_DEFENSE` | Front | high HP/DEF, low ATK, taunt/shield |
| `FRONT_CHARGE` | Front | high HP, mid DEF, disruption |
| `MID_MAGIC` | Middle | glass cannon, AoE + debuff |
| `AMBUSH` | Mid/Rear | single-target burst, brief intangible frames |
| `BOMBER` | Mid/Rear | DoT, cluster damage |
| `RANGED` | Rear | safe-range DPS, high ATK SPD |
| `SUPPORT` | Mid/Rear | buffs / summons |
| `HEALER` | Rear | heal scales off ATK |

## 6. Entity FSM & spatial model (research P2)

- **FSM states:** `IDLE → MOVE → BASIC_ATTACK → CAST_SKILL → STUNNED → DEAD`.
- **Spatial layout:** battle runs on a horizontal X axis. Allies spawn left and advance right;
  enemies spawn right. **Lanes** (Front/Middle/Rear) are an X-offset within the ally formation
  plus a Y band for visual separation.
- **Aggro:** an entity targets the **nearest opposing entity within `attack_range`** along X
  (within a lane tolerance). Out of range → `MOVE` toward it; in range → `BASIC_ATTACK` on an
  `ATK_SPD` cadence; skill ready + auto-cast permits → `CAST_SKILL`.
- **Interrupts:** entering `STUNNED` immediately cancels any in-progress attack/skill (the
  research's interrupt mechanic).
- **Anti-clipping:** if more than 2 entities occupy the same lane slot, later ones are nudged to
  the next slot (research §9). Basic separation is sufficient for this slice.

## 7. BattleManager state machine + auto-cast (research P1 & P4)

- **Phases** (`BattlePhase`): `INIT → WAVE_SPAWNING → FIGHTING → TRANSITIONING → BOSS_ENCOUNTER
  → VICTORY / DEFEAT`, all signal-driven.
- **Transitions:** enemies cleared → `TRANSITIONING` (allies side-scroll right until a boundary
  trigger) → next `WAVE_SPAWNING`. All allies dead → `DEFEAT`. Final wave → `BOSS_ENCOUNTER`.
- **Startup:** reads `GameState.party` (with upgrade bonuses already applied), seeds each
  `BattleEntity`'s `StatSystem` from clan + archetype data, builds enemy waves from the catalog.
- **Starting Cooldown:** every skill initializes at battle start with a `starting_cooldown`
  (2–4s), NOT immediately ready.
- **Cooldown tick:** `remaining -= delta × (1 + COOLDOWN_REDUCTION)`.
- **Auto-cast:** each frame, poll ready allied skills; cast the **front-most X** one; then impose
  a global ~0.3s execution delay before the next cast — the deliberate interruption window.
- **Manual override:** `request_cast(entity)` is **implemented** and wired to the existing
  taskbar skill buttons this slice (they replace `BattleEngine.trigger_skill_*`). It bypasses the
  auto-cast queue and forces the entity's `CAST_SKILL` if the cooldown permits. Only the fancier
  *portrait-ring* tap UI (P6) is deferred.

## 8. Scene, boot wiring, and data

### Scene (`scenes/combat/battle.tscn`)
Root `BattleManager` (`Node2D`); a `Camera2D` following average ally X with smooth damping
(basic follow only); background painted from existing assets via `AssetRegistry`; three left-side
lane formation anchors + a right-side enemy spawn zone; each `BattleEntity` renders its
idle/move sprite via the existing **role-based** shortcuts (`unit.tank_*`, `unit.healer_*`,
`unit.ranged_*`, `unit.mage_*`, `unit.enemy_boss_*`, …) — these map cleanly onto archetypes, so
`archetypes.json` carries an `idle_shortcut` / `move_shortcut` per archetype (no new art) — with a small HP bar; a minimal
HUD (wave number + skill-button row wired to `request_cast`). Victory/Defeat reports to
`GameState` then returns to the meta hub.

### Boot wiring
`AssetRegistry` + `GameState` autoloads still load first (unchanged). The existing `main` scene
remains the meta hub; a "Start Battle" action transitions into `battle.tscn` and back.

### Data (JSON, following existing convention)
- `data/units/clans.json` — add `archetype`, advanced stats, `attack_range`, `move_speed` per clan.
- `data/combat/enemies.json` — add archetype + advanced stats + range.
- `data/combat/archetypes.json` *(new)* — archetype → default lane, stat weighting, range, speed, AI intent.
- `data/combat/skills.json` *(new)* — per skill: `starting_cooldown`, `cooldown`, effect type + params, scaling ratio.
- `data/combat/mvp_waves.json` — kept for wave composition.

## 9. Explicitly deferred (out of this slice)

- **Research P5 — Toppings + Treasures.** StatSystem already accepts them as modifier sources; no
  gear data/UI in this slice. Own follow-up spec.
- **Research P6 — full presentation.** Multi-layer parallax camera, portrait `BattleUIController`
  with radial cooldown rings, floating-damage object pool. This slice ships basic camera follow +
  HP bars + minimal HUD only. Own follow-up spec.
- Domains/environments, Cookie Alliance mode, Beascuits — later.

## 10. Testing

- **Headless unit tests** — follow the **existing scene-based harness** (`tests/bootstrap_test.tscn`
  drives `tests/bootstrap_test.gd`); add a combat test scene that `new()`s the `RefCounted` core
  classes and asserts:
  - `DamageCalculator` — DEF ratio curve, crit multiplier, `resist − bypass` clamp, int floor.
  - `StatSystem` — flat + percent stacking order, modifier expiry by duration.
  - `Skill` — starting cooldown seeds `remaining`, CDR scaling of tick, readiness ordering.
- **Docs to update (Sage `update-docs`) — retiring the turn engine makes these stale:**
  `docs/systems/COMBAT_SYSTEM.md` and the five `agents/sage/flows/*` docs that describe
  `BattleEngine` (`playable-party-combat-mvp-flow`, `game-feel-effects-flow`,
  `taskbar-battle-strip-layout-flow`, `tbh-combat-animation-and-camera-flow`,
  and the presenter decision under `agents/sage/godot-runtime/decisions/`). Update them to the new
  `BattleManager` architecture (they keep describing the same signal vocabulary, per §2's seam).
- **Runtime smoke** (Sage automate-test): `run_game.ps1` + `tools/capture_runtime_screenshot.ps1`
  to prove the battle scene launches and renders; report the actual output, not "should pass".

## 11. Risks & notes

- **Godot target:** 4.x (repo declares 4.2 features; local binary is Godot 4.7).
- **Biggest churn:** retiring `battle_engine.gd` is not a one-file delete — it is wired into
  `main.gd`, the taskbar skill routing, and `EmberhearthMapView`'s game-feel effects, and
  documented across six docs (§10). Two seams keep this tractable: (1) `GameState` stays the
  meta layer (currency/save/progression intact), and (2) the new nodes re-emit the existing
  combat **signal vocabulary** (§2) so the presentation layer survives with re-pointing, not a
  rewrite.
- **Determinism:** crit uses RNG; unit tests inject a seeded/forced roll so damage math is
  deterministic under test.
- **Source-of-truth:** per `docs/DESIGN_SOURCE_OF_TRUTH.md`, `project_main_setting.md` outranks
  this pivot on lore/world — hence "keep TBH world, adopt CRK mechanics".
