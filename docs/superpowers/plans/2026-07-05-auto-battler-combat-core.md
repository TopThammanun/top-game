# Auto-Battler Combat Core & Data — Implementation Plan (Plan A of 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-logic combat core (stats, damage, skills, effects) and the combat data files for the Cookie-Run-Kingdom-style auto-battler, all headless-testable, with zero scene dependencies.

**Architecture:** All classes are `RefCounted` global `class_name`s under `scripts/combat/`. They know nothing about nodes, scenes, or `GameState` — the live scene layer (Plan B) will consume them. Data is JSON under `data/combat/` and `data/units/`, loaded by a pure `CharacterFactory` that turns a clan/enemy + archetype into a battle-ready `StatSystem` profile.

**Tech Stack:** Godot 4.x, GDScript. Tests use the repo's existing headless scene harness (`tests/*.tscn` → script `extends Node`, collects `failures`, prints `PASS`/`FAIL`, `get_tree().quit(0|1)`).

**Spec:** `docs/superpowers/specs/2026-07-05-auto-battler-combat-pivot-design.md` (§3 StatSystem, §4 DamageCalculator, §5 archetypes, part of §6/§7 skills).

## Global Constraints

- **Godot target:** 4.x (repo declares `config/features=("4.2")`; local binary is Godot 4.7). GDScript only.
- **No hard-coded `res://asset/...` paths** in gameplay code — art is resolved via `AssetRegistry` shortcuts (relevant to Plan B; Plan A only stores shortcut *names* as strings in data).
- **Data is JSON**, following the existing `data/` convention; keep design docs and JSON in sync.
- **Class names are global** (`class_name X`) — new names must not collide with existing ones (`UnitState`, `WaveState`, `BattleEngine`, `AssetRegistry`, `GameState` are taken; the names below are free).
- **Test invocation:** `<godot> --headless res://tests/<name>.tscn`, where `<godot>` is resolved as in `run_game.ps1` (arg → `$env:GODOT_EXE` → `Godot*.exe` in project root → PATH). Pass = exit 0.
- **Determinism in tests:** damage crit uses RNG; every damage test passes an explicit `crit_roll` so results are deterministic.
- **Cross-references use preload consts, not bare global `class_name`** (added during execution). A new `class_name` script is not registered in the `.godot` class cache without a slow/fragile import, so `scripts/combat/*` and the tests reference siblings via `const XxxClass = preload("res://scripts/combat/xxx.gd")` (project convention — see `game_state.gd`, and `agents/sage/godot-runtime/decisions/headless-global-class-cache.md`). Scripts keep their `class_name`, but where a param's type is another combat class it is left untyped, and a `:=` local derived from an untyped value is given an explicit type. **The code blocks below that reference classes by bare global name (`CombatEnums`, `StatSystem`, …) are superseded by this constraint; the committed code and the Task 4/5 briefs use the `preload`-const form.**

---

### Task 1: Combat enums, StatModifier, StatSystem

**Files:**
- Create: `scripts/combat/combat_enums.gd`
- Create: `scripts/combat/stat_modifier.gd`
- Create: `scripts/combat/stat_system.gd`
- Create: `tests/combat_core_test.gd`
- Create: `tests/combat_core_test.tscn`

**Interfaces:**
- Produces:
  - `CombatEnums.FsmState { IDLE, MOVE, BASIC_ATTACK, CAST_SKILL, STUNNED, DEAD }`
  - `CombatEnums.Archetype { FRONT_DEFENSE, FRONT_CHARGE, MID_MAGIC, AMBUSH, BOMBER, RANGED, SUPPORT, HEALER }`
  - `CombatEnums.Lane { FRONT, MIDDLE, REAR }`
  - `CombatEnums.StatKey { HP, ATK, DEF, CRIT_CHANCE, CRIT_DMG, ATK_SPD, COOLDOWN_REDUCTION, DMG_RESIST, DMG_RESIST_BYPASS, AMPLIFY }`
  - `CombatEnums.ModifierType { FLAT, PERCENT }`
  - `CombatEnums.BattlePhase { INIT, WAVE_SPAWNING, FIGHTING, TRANSITIONING, BOSS_ENCOUNTER, VICTORY, DEFEAT }`
  - `CombatEnums.stat_key_from_string(s: String) -> int` (returns `-1` if unknown)
  - `CombatEnums.archetype_from_string(s: String) -> int`, `CombatEnums.lane_from_string(s: String) -> int`
  - `StatModifier.new(stat:int, type:int, value:float, source:String="", duration:float=0.0)`; fields `stat,type,value,source,duration`; `is_permanent() -> bool`
  - `StatSystem.new(base_stats: Dictionary = {})` where keys are `StatKey` ints; `set_base(stat,value)`, `get_base(stat)->float`, `get_stat(stat)->float`, `add_modifier(mod)`, `remove_modifiers_from(source)`, `tick_modifiers(delta)`, `current_hp:float`, `is_alive()->bool`, `take_damage(amount)`, `heal(amount)`

- [ ] **Step 1: Write `scripts/combat/combat_enums.gd`**

```gdscript
class_name CombatEnums
extends RefCounted

# Shared combat enums + JSON string parsers. Pure data, no scene deps.

enum FsmState { IDLE, MOVE, BASIC_ATTACK, CAST_SKILL, STUNNED, DEAD }
enum Archetype { FRONT_DEFENSE, FRONT_CHARGE, MID_MAGIC, AMBUSH, BOMBER, RANGED, SUPPORT, HEALER }
enum Lane { FRONT, MIDDLE, REAR }
enum StatKey { HP, ATK, DEF, CRIT_CHANCE, CRIT_DMG, ATK_SPD, COOLDOWN_REDUCTION, DMG_RESIST, DMG_RESIST_BYPASS, AMPLIFY }
enum ModifierType { FLAT, PERCENT }
enum BattlePhase { INIT, WAVE_SPAWNING, FIGHTING, TRANSITIONING, BOSS_ENCOUNTER, VICTORY, DEFEAT }


static func stat_key_from_string(s: String) -> int:
	match s.to_lower():
		"hp": return StatKey.HP
		"atk": return StatKey.ATK
		"def": return StatKey.DEF
		"crit_chance": return StatKey.CRIT_CHANCE
		"crit_dmg": return StatKey.CRIT_DMG
		"atk_spd": return StatKey.ATK_SPD
		"cooldown_reduction": return StatKey.COOLDOWN_REDUCTION
		"dmg_resist": return StatKey.DMG_RESIST
		"dmg_resist_bypass": return StatKey.DMG_RESIST_BYPASS
		"amplify": return StatKey.AMPLIFY
	return -1


static func archetype_from_string(s: String) -> int:
	match s.to_lower():
		"front_defense": return Archetype.FRONT_DEFENSE
		"front_charge": return Archetype.FRONT_CHARGE
		"mid_magic": return Archetype.MID_MAGIC
		"ambush": return Archetype.AMBUSH
		"bomber": return Archetype.BOMBER
		"ranged": return Archetype.RANGED
		"support": return Archetype.SUPPORT
		"healer": return Archetype.HEALER
	return -1


static func lane_from_string(s: String) -> int:
	match s.to_lower():
		"front": return Lane.FRONT
		"middle": return Lane.MIDDLE
		"rear": return Lane.REAR
	return -1
```

- [ ] **Step 2: Write `scripts/combat/stat_modifier.gd`**

```gdscript
class_name StatModifier
extends RefCounted

# One flat or percent modifier applied to a StatSystem stat.
# A modifier created with duration <= 0 is permanent (e.g. gear); one created
# with duration > 0 counts down via tick_modifiers and is removed when it
# expires. Permanence is captured at creation so a temporary whose duration
# decrements past 0 is never mistaken for permanent.

var stat: int          # CombatEnums.StatKey
var type: int          # CombatEnums.ModifierType
var value: float
var source: String
var duration: float
var permanent: bool


func _init(p_stat: int, p_type: int, p_value: float, p_source: String = "", p_duration: float = 0.0) -> void:
	stat = p_stat
	type = p_type
	value = p_value
	source = p_source
	duration = p_duration
	permanent = p_duration <= 0.0


func is_permanent() -> bool:
	return permanent
```

- [ ] **Step 3: Write `scripts/combat/stat_system.gd`**

```gdscript
class_name StatSystem
extends RefCounted

# Base + advanced stats with a modifier stack. Final value:
#   (base + sum FLAT) * (1 + sum PERCENT). Current HP tracked separately.

var _base: Dictionary = {}      # StatKey(int) -> float
var _modifiers: Array = []      # Array[StatModifier]
var current_hp: float = 0.0


func _init(base_stats: Dictionary = {}) -> void:
	for k in base_stats:
		_base[int(k)] = float(base_stats[k])
	current_hp = get_stat(CombatEnums.StatKey.HP)


func set_base(stat: int, value: float) -> void:
	_base[stat] = float(value)


func get_base(stat: int) -> float:
	return float(_base.get(stat, 0.0))


func add_modifier(mod: StatModifier) -> void:
	_modifiers.append(mod)


func remove_modifiers_from(source: String) -> void:
	_modifiers = _modifiers.filter(func(m): return m.source != source)


func get_stat(stat: int) -> float:
	var flat := 0.0
	var pct := 0.0
	for m in _modifiers:
		if m.stat != stat:
			continue
		if m.type == CombatEnums.ModifierType.FLAT:
			flat += m.value
		else:
			pct += m.value
	return (get_base(stat) + flat) * (1.0 + pct)


func tick_modifiers(delta: float) -> void:
	for m in _modifiers:
		if not m.is_permanent():
			m.duration -= delta
	_modifiers = _modifiers.filter(func(m): return m.is_permanent() or m.duration > 0.0)


func is_alive() -> bool:
	return current_hp > 0.0


func take_damage(amount: float) -> void:
	current_hp = max(0.0, current_hp - amount)


func heal(amount: float) -> void:
	current_hp = min(get_stat(CombatEnums.StatKey.HP), current_hp + amount)
```

- [ ] **Step 4: Write the failing test `tests/combat_core_test.gd`**

Start the shared combat-core test file. Later tasks append `_check_*` helpers and call them from `_ready()`.

```gdscript
extends Node

# Headless unit tests for the pure-logic combat core (scripts/combat/*).
# Invoke via: <godot> --headless res://tests/combat_core_test.tscn
# Mirrors tests/bootstrap_test.gd: collect failures, print PASS/FAIL, quit 0/1.

var _failures: Array[String] = []


func _ready() -> void:
	_check_stat_system()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _approx(a: float, b: float, eps: float = 0.001) -> bool:
	return abs(a - b) <= eps


func _check_stat_system() -> void:
	var S := CombatEnums.StatKey
	var s := StatSystem.new({ S.HP: 100.0, S.ATK: 20.0, S.DEF: 5.0 })
	_expect(_approx(s.get_stat(S.ATK), 20.0), "base ATK should be 20, got %f" % s.get_stat(S.ATK))
	_expect(_approx(s.current_hp, 100.0), "current_hp should init to max HP 100, got %f" % s.current_hp)

	# flat + percent stack: (20 + 10) * (1 + 0.5) = 45
	s.add_modifier(StatModifier.new(S.ATK, CombatEnums.ModifierType.FLAT, 10.0, "buffA"))
	s.add_modifier(StatModifier.new(S.ATK, CombatEnums.ModifierType.PERCENT, 0.5, "buffB"))
	_expect(_approx(s.get_stat(S.ATK), 45.0), "flat+percent ATK should be 45, got %f" % s.get_stat(S.ATK))

	# remove by source
	s.remove_modifiers_from("buffA")
	_expect(_approx(s.get_stat(S.ATK), 30.0), "after removing flat, ATK should be 30, got %f" % s.get_stat(S.ATK))

	# duration expiry
	s.add_modifier(StatModifier.new(S.ATK, CombatEnums.ModifierType.FLAT, 100.0, "temp", 1.0))
	# (20 + 100) * (1 + 0.5) = 180 — the percent multiplier still applies to the flat add
	_expect(_approx(s.get_stat(S.ATK), 180.0), "temp buff active should give 180, got %f" % s.get_stat(S.ATK))
	s.tick_modifiers(1.5)
	_expect(_approx(s.get_stat(S.ATK), 30.0), "temp buff should expire back to 30, got %f" % s.get_stat(S.ATK))

	# hp
	s.take_damage(40.0)
	_expect(_approx(s.current_hp, 60.0), "hp after 40 dmg should be 60, got %f" % s.current_hp)
	s.heal(1000.0)
	_expect(_approx(s.current_hp, 100.0), "heal should cap at max HP 100, got %f" % s.current_hp)
	s.take_damage(1000.0)
	_expect(not s.is_alive(), "unit should be dead after lethal damage")


func _finish() -> void:
	if _failures.is_empty():
		print("[combat_core_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[combat_core_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
```

- [ ] **Step 5: Write `tests/combat_core_test.tscn`**

```
[gd_scene load_steps=2 format=3 uid="uid://c0tbcombatcore01"]

[ext_resource type="Script" path="res://tests/combat_core_test.gd" id="1_ccore"]

[node name="CombatCoreTest" type="Node"]
script = ExtResource("1_ccore")
```

- [ ] **Step 6: Run the test — verify it PASSES**

Run: `powershell -ExecutionPolicy Bypass -Command "& (Resolve-Path .\Godot_v4.7-stable_win64.exe\*.exe) --headless res://tests/combat_core_test.tscn"`
(or `.\run_game.ps1` conventions; any resolved Godot 4.x binary with `--headless res://tests/combat_core_test.tscn`)
Expected: prints `[combat_core_test] PASS`, exit code 0.

- [ ] **Step 7: Commit**

```bash
git add scripts/combat/combat_enums.gd scripts/combat/stat_modifier.gd scripts/combat/stat_system.gd tests/combat_core_test.gd tests/combat_core_test.tscn
git commit -m "feat(combat): StatSystem, StatModifier, combat enums + headless tests"
```

---

### Task 2: DamageCalculator

**Files:**
- Create: `scripts/combat/damage_calculator.gd`
- Modify: `tests/combat_core_test.gd` (add `_check_damage()` + call it)

**Interfaces:**
- Consumes: `StatSystem`, `CombatEnums.StatKey`
- Produces: `DamageCalculator.compute(attacker: StatSystem, defender: StatSystem, skill_ratio: float = 1.0, crit_roll: float = -1.0) -> Dictionary` returning `{ "amount": int, "is_crit": bool }`. Pipeline: `raw = ATK*ratio` → DEF ratio mitigation `raw*(raw/(raw+DEF))` → crit (`crit_roll < CRIT_CHANCE`, else `randf()` when `crit_roll < 0`) → resist `clamp(DMG_RESIST - attacker.DMG_RESIST_BYPASS, 0, 0.9)` → amplify → floor at 1, rounded int.

- [ ] **Step 1: Write the failing test — append to `tests/combat_core_test.gd`**

Add the call inside `_ready()` (before `_finish()`):

```gdscript
	_check_damage()
```

Add this method:

```gdscript
func _check_damage() -> void:
	var S := CombatEnums.StatKey
	# ATK 100 vs DEF 100, no crit (crit_roll = 1.0 forces no crit):
	# raw=100, mitigated = 100 * (100/200) = 50
	var atkr := StatSystem.new({ S.ATK: 100.0 })
	var deff := StatSystem.new({ S.HP: 999.0, S.DEF: 100.0 })
	var r := DamageCalculator.compute(atkr, deff, 1.0, 1.0)
	_expect(r.amount == 50, "100 ATK vs 100 DEF should be 50, got %d" % r.amount)
	_expect(r.is_crit == false, "forced crit_roll 1.0 should not crit")

	# crit doubles when CRIT_DMG = 1.0 and crit_roll below CRIT_CHANCE
	var critr := StatSystem.new({ S.ATK: 100.0, S.CRIT_CHANCE: 0.5, S.CRIT_DMG: 1.0 })
	var rc := DamageCalculator.compute(critr, deff, 1.0, 0.0)
	_expect(rc.amount == 100, "crit (x2) on 50 base should be 100, got %d" % rc.amount)
	_expect(rc.is_crit == true, "crit_roll 0.0 < 0.5 should crit")

	# resist reduces; bypass negates it. DEF 0 so raw passes: raw=100.
	var noDef := StatSystem.new({ S.HP: 999.0, S.DEF: 0.0, S.DMG_RESIST: 0.5 })
	var plain := StatSystem.new({ S.ATK: 100.0 })
	_expect(DamageCalculator.compute(plain, noDef, 1.0, 1.0).amount == 50,
		"50% resist should halve 100 to 50")
	var piercer := StatSystem.new({ S.ATK: 100.0, S.DMG_RESIST_BYPASS: 0.5 })
	_expect(DamageCalculator.compute(piercer, noDef, 1.0, 1.0).amount == 100,
		"0.5 bypass vs 0.5 resist should negate resist -> 100")

	# resist clamps at 0.9 (never 100% immune)
	var wall := StatSystem.new({ S.HP: 999.0, S.DEF: 0.0, S.DMG_RESIST: 5.0 })
	_expect(DamageCalculator.compute(plain, wall, 1.0, 1.0).amount == 10,
		"resist clamps at 0.9 -> 100 becomes 10, got %d" % DamageCalculator.compute(plain, wall, 1.0, 1.0).amount)

	# floor at 1
	var tiny := StatSystem.new({ S.ATK: 1.0 })
	var tank := StatSystem.new({ S.HP: 999.0, S.DEF: 10000.0 })
	_expect(DamageCalculator.compute(tiny, tank, 1.0, 1.0).amount >= 1, "damage floors at 1")
```

- [ ] **Step 2: Run the test — verify it FAILS**

Run: `<godot> --headless res://tests/combat_core_test.tscn`
Expected: FAIL (parser error / `DamageCalculator` not found), exit code non-zero.

- [ ] **Step 3: Write `scripts/combat/damage_calculator.gd`**

```gdscript
class_name DamageCalculator
extends RefCounted

# CRK-style pipeline (spec §4). Static utility; pass crit_roll >= 0 in tests
# for determinism, or -1.0 to roll randf() at runtime.

static func compute(attacker: StatSystem, defender: StatSystem, skill_ratio: float = 1.0, crit_roll: float = -1.0) -> Dictionary:
	var S := CombatEnums.StatKey
	var atk := attacker.get_stat(S.ATK)
	var deff := defender.get_stat(S.DEF)
	var raw := atk * skill_ratio

	# 1. DEF mitigation (ratio curve, diminishing returns, never negative)
	var dmg := 0.0
	if raw + deff > 0.0:
		dmg = raw * (raw / (raw + deff))

	# 2. Crit
	var is_crit := false
	var roll := crit_roll if crit_roll >= 0.0 else randf()
	if roll < attacker.get_stat(S.CRIT_CHANCE):
		is_crit = true
		dmg *= (1.0 + attacker.get_stat(S.CRIT_DMG))

	# 3. Resist (final multiplier), reduced by attacker bypass, clamped < 1
	var resist: float = clamp(
		defender.get_stat(S.DMG_RESIST) - attacker.get_stat(S.DMG_RESIST_BYPASS),
		0.0, 0.9)
	dmg *= (1.0 - resist)

	# 4. Amplify
	dmg *= (1.0 + attacker.get_stat(S.AMPLIFY))

	return { "amount": int(max(1.0, round(dmg))), "is_crit": is_crit }
```

- [ ] **Step 4: Run the test — verify it PASSES**

Run: `<godot> --headless res://tests/combat_core_test.tscn`
Expected: `[combat_core_test] PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/damage_calculator.gd tests/combat_core_test.gd
git commit -m "feat(combat): DamageCalculator with DEF curve, crit, resist/bypass"
```

---

### Task 3: CombatSkill (cooldown, starting cooldown, CDR)

**Files:**
- Create: `scripts/combat/combat_skill.gd`
- Modify: `tests/combat_core_test.gd` (add `_check_skill()` + call it)

**Interfaces:**
- Produces: `CombatSkill.new(config: Dictionary = {})` reading keys `id, starting_cooldown(=3.0), cooldown(=8.0), skill_ratio(=1.0), effect_type(="aoe_damage"), effect_params(={}), target_side(="enemy"), max_targets(=0)`. Fields mirror those. Methods: `tick(delta: float, cooldown_reduction: float)` → `remaining = max(0, remaining - delta*(1+cdr))`; `is_ready() -> bool` (`remaining <= 0`); `trigger()` → `remaining = cooldown`. `remaining` initializes to `starting_cooldown`.

- [ ] **Step 1: Write the failing test — append to `tests/combat_core_test.gd`**

Add call in `_ready()` before `_finish()`:

```gdscript
	_check_skill()
```

Add method:

```gdscript
func _check_skill() -> void:
	var sk := CombatSkill.new({
		"id": "wildstripe_burst", "starting_cooldown": 3.0, "cooldown": 8.0,
		"skill_ratio": 2.0, "effect_type": "aoe_damage",
	})
	_expect(_approx(sk.remaining, 3.0), "skill should start on starting_cooldown 3.0, got %f" % sk.remaining)
	_expect(not sk.is_ready(), "skill should not be ready at battle start")

	# CDR scales the tick: 1.0s of delta at 0.5 CDR ticks 1.5s
	sk.tick(1.0, 0.5)
	_expect(_approx(sk.remaining, 1.5), "3.0 - 1.0*(1.5) should be 1.5, got %f" % sk.remaining)
	sk.tick(2.0, 0.5)
	_expect(sk.is_ready(), "skill should be ready after enough ticks (remaining clamps at 0)")
	_expect(_approx(sk.remaining, 0.0), "remaining should clamp at 0, got %f" % sk.remaining)

	# trigger resets to full cooldown (not starting cooldown)
	sk.trigger()
	_expect(_approx(sk.remaining, 8.0), "trigger should set remaining to cooldown 8.0, got %f" % sk.remaining)
```

- [ ] **Step 2: Run the test — verify it FAILS**

Run: `<godot> --headless res://tests/combat_core_test.tscn`
Expected: FAIL (`CombatSkill` not found), exit non-zero.

- [ ] **Step 3: Write `scripts/combat/combat_skill.gd`**

```gdscript
class_name CombatSkill
extends RefCounted

# One skill instance owned by an entity. Implements the CRK "Starting Cooldown"
# (spec §7): remaining begins at starting_cooldown, not 0 and not full cooldown.

var id: String
var starting_cooldown: float
var cooldown: float
var skill_ratio: float
var effect_type: String
var effect_params: Dictionary
var target_side: String     # "enemy" | "ally" | "self"
var max_targets: int        # 0 = all valid targets
var remaining: float


func _init(config: Dictionary = {}) -> void:
	id = str(config.get("id", ""))
	starting_cooldown = float(config.get("starting_cooldown", 3.0))
	cooldown = float(config.get("cooldown", 8.0))
	skill_ratio = float(config.get("skill_ratio", 1.0))
	effect_type = str(config.get("effect_type", "aoe_damage"))
	effect_params = config.get("effect_params", {})
	target_side = str(config.get("target_side", "enemy"))
	max_targets = int(config.get("max_targets", 0))
	remaining = starting_cooldown


func tick(delta: float, cooldown_reduction: float) -> void:
	remaining = max(0.0, remaining - delta * (1.0 + cooldown_reduction))


func is_ready() -> bool:
	return remaining <= 0.0


func trigger() -> void:
	remaining = cooldown
```

- [ ] **Step 4: Run the test — verify it PASSES**

Run: `<godot> --headless res://tests/combat_core_test.tscn`
Expected: `[combat_core_test] PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/combat_skill.gd tests/combat_core_test.gd
git commit -m "feat(combat): CombatSkill with starting cooldown + CDR-scaled ticking"
```

---

### Task 4: SkillEffect (damage / heal / buff / stun resolution)

**Files:**
- Create: `scripts/combat/skill_effect.gd`
- Modify: `tests/combat_core_test.gd` (add `_check_effect()` + call it)

**Interfaces:**
- Consumes: `StatSystem`, `DamageCalculator`, `StatModifier`, `CombatEnums`
- Produces: `SkillEffect.apply(skill: CombatSkill, caster: StatSystem, targets: Array, crit_roll: float = -1.0) -> Array` where `targets` is `Array[StatSystem]`. Returns an `Array` of per-target result dicts. Behavior by `skill.effect_type`:
  - `"aoe_damage"`: for each target, `DamageCalculator.compute(caster, t, skill.skill_ratio, crit_roll)`, apply `t.take_damage(amount)`, push `{ "target_index": i, "amount", "is_crit" }`.
  - `"heal"`: `amount = round(caster.ATK * skill.skill_ratio)`; each target `heal(amount)`; push `{ "target_index": i, "heal": amount }`.
  - `"buff"`: add a PERCENT `StatModifier` (`stat` from `effect_params.stat` string, `value`, `duration`) to each target; push `{ "target_index": i, "buff": value }`.
  - `"stun"`: apply nothing to stats; push `{ "target_index": i, "stun": duration }` (a control descriptor the entity layer in Plan B consumes to force `STUNNED`).

- [ ] **Step 1: Write the failing test — append to `tests/combat_core_test.gd`**

Add call in `_ready()` before `_finish()`:

```gdscript
	_check_effect()
```

Add method:

```gdscript
func _check_effect() -> void:
	var S := CombatEnums.StatKey

	# aoe_damage hits every target and mutates their hp
	var caster := StatSystem.new({ S.ATK: 100.0 })
	var e1 := StatSystem.new({ S.HP: 999.0, S.DEF: 100.0 })
	var e2 := StatSystem.new({ S.HP: 999.0, S.DEF: 100.0 })
	var dmg_skill := CombatSkill.new({ "effect_type": "aoe_damage", "skill_ratio": 1.0 })
	var results := SkillEffect.apply(dmg_skill, caster, [e1, e2], 1.0)
	_expect(results.size() == 2, "aoe should return one result per target, got %d" % results.size())
	_expect(_approx(e1.current_hp, 949.0), "e1 should take 50 dmg (999->949), got %f" % e1.current_hp)
	_expect(_approx(e2.current_hp, 949.0), "e2 should take 50 dmg (999->949), got %f" % e2.current_hp)

	# heal scales off caster ATK
	var healer := StatSystem.new({ S.ATK: 40.0 })
	var wounded := StatSystem.new({ S.HP: 100.0 })
	wounded.take_damage(60.0)  # -> 40
	var heal_skill := CombatSkill.new({ "effect_type": "heal", "skill_ratio": 1.0, "target_side": "ally" })
	SkillEffect.apply(heal_skill, healer, [wounded])
	_expect(_approx(wounded.current_hp, 80.0), "heal 40 should bring 40 -> 80, got %f" % wounded.current_hp)

	# buff adds a percent modifier from a string stat key
	var ally := StatSystem.new({ S.ATK: 100.0 })
	var buff_skill := CombatSkill.new({
		"effect_type": "buff", "target_side": "ally",
		"effect_params": { "stat": "atk", "value": 0.3, "duration": 5.0 },
	})
	SkillEffect.apply(buff_skill, ally, [ally])
	_expect(_approx(ally.get_stat(S.ATK), 130.0), "atk buff +30%% should give 130, got %f" % ally.get_stat(S.ATK))

	# stun returns a control descriptor, mutates no stats
	var target := StatSystem.new({ S.HP: 100.0 })
	var stun_skill := CombatSkill.new({ "effect_type": "stun", "effect_params": { "duration": 1.5 } })
	var stun_res := SkillEffect.apply(stun_skill, caster, [target])
	_expect(stun_res.size() == 1 and _approx(stun_res[0].get("stun", 0.0), 1.5), "stun should report 1.5s descriptor")
	_expect(_approx(target.current_hp, 100.0), "stun should not damage the target")
```

- [ ] **Step 2: Run the test — verify it FAILS**

Run: `<godot> --headless res://tests/combat_core_test.tscn`
Expected: FAIL (`SkillEffect` not found), exit non-zero.

- [ ] **Step 3: Write `scripts/combat/skill_effect.gd`**

```gdscript
class_name SkillEffect
extends RefCounted

# Resolves a CombatSkill's effect against StatSystem targets. Stat-only effects
# (damage/heal/buff) mutate targets directly; control effects (stun) return a
# descriptor for the entity/FSM layer (Plan B) to act on.

static func apply(skill: CombatSkill, caster: StatSystem, targets: Array, crit_roll: float = -1.0) -> Array:
	var out: Array = []
	match skill.effect_type:
		"aoe_damage":
			for i in targets.size():
				var t: StatSystem = targets[i]
				var r := DamageCalculator.compute(caster, t, skill.skill_ratio, crit_roll)
				t.take_damage(float(r.amount))
				out.append({ "target_index": i, "amount": r.amount, "is_crit": r.is_crit })
		"heal":
			var amount := int(round(caster.get_stat(CombatEnums.StatKey.ATK) * skill.skill_ratio))
			for i in targets.size():
				var t: StatSystem = targets[i]
				t.heal(float(amount))
				out.append({ "target_index": i, "heal": amount })
		"buff":
			var stat_key := CombatEnums.stat_key_from_string(str(skill.effect_params.get("stat", "atk")))
			var value := float(skill.effect_params.get("value", 0.3))
			var duration := float(skill.effect_params.get("duration", 5.0))
			for i in targets.size():
				var t: StatSystem = targets[i]
				t.add_modifier(StatModifier.new(stat_key, CombatEnums.ModifierType.PERCENT, value, "skill:%s" % skill.id, duration))
				out.append({ "target_index": i, "buff": value })
		"stun":
			var duration := float(skill.effect_params.get("duration", 1.5))
			for i in targets.size():
				out.append({ "target_index": i, "stun": duration })
	return out
```

- [ ] **Step 4: Run the test — verify it PASSES**

Run: `<godot> --headless res://tests/combat_core_test.tscn`
Expected: `[combat_core_test] PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/skill_effect.gd tests/combat_core_test.gd
git commit -m "feat(combat): SkillEffect resolution for damage/heal/buff/stun"
```

---

### Task 5: Combat data files + CharacterFactory

**Files:**
- Create: `data/combat/archetypes.json`
- Create: `data/combat/skills.json`
- Modify: `data/units/clans.json` (add `archetype` + advanced stats per clan)
- Modify: `data/combat/enemies.json` (add `archetype` + advanced stats)
- Create: `scripts/combat/character_factory.gd`
- Modify: `tests/combat_core_test.gd` (add `_check_factory()` + call it)

**Interfaces:**
- Consumes: `StatSystem`, `CombatSkill`, `CombatEnums`
- Produces:
  - `CharacterFactory.new()`; `load_all()` reads the four JSON files (`res://data/combat/archetypes.json`, `res://data/combat/skills.json`, `res://data/units/clans.json`, `res://data/combat/enemies.json`).
  - `build_from_clan(clan_id: String) -> Dictionary` and `build_from_enemy(enemy_id: String) -> Dictionary`, each returning a **profile**: `{ "stats": StatSystem, "archetype": int, "lane": int, "attack_range": float, "move_speed": float, "idle_shortcut": String, "move_shortcut": String, "skill": CombatSkill (or null) }`.
  - `archetype_ids() -> Array[String]`, `has_clan(id)`, `has_enemy(id)`.
  - Stat build rule: `base_stat = round(clan.base_* * archetype.weight_*)` for HP/ATK/DEF; advanced stats come from the archetype defaults, overridden by any per-clan/enemy value.

- [ ] **Step 1: Write `data/combat/archetypes.json`**

```json
[
  { "archetype": "front_defense", "lane": "front", "attack_range": 90.0, "move_speed": 60.0,
    "idle_shortcut": "unit.tank_idle", "move_shortcut": "unit.tank_move", "ai_intent": "taunt",
    "weights": { "hp": 1.8, "atk": 0.6, "def": 2.0 },
    "advanced": { "dmg_resist": 0.15, "atk_spd": 0.9 } },
  { "archetype": "front_charge", "lane": "front", "attack_range": 100.0, "move_speed": 95.0,
    "idle_shortcut": "unit.striker_idle", "move_shortcut": "unit.striker_move", "ai_intent": "disrupt",
    "weights": { "hp": 1.4, "atk": 1.1, "def": 1.2 },
    "advanced": { "dmg_resist": 0.08, "atk_spd": 1.0 } },
  { "archetype": "mid_magic", "lane": "middle", "attack_range": 260.0, "move_speed": 70.0,
    "idle_shortcut": "unit.mage_idle", "move_shortcut": "unit.mage_move", "ai_intent": "aoe",
    "weights": { "hp": 0.7, "atk": 1.8, "def": 0.5 },
    "advanced": { "crit_chance": 0.1, "crit_dmg": 0.5 } },
  { "archetype": "ambush", "lane": "middle", "attack_range": 120.0, "move_speed": 110.0,
    "idle_shortcut": "unit.striker_idle", "move_shortcut": "unit.striker_move", "ai_intent": "burst",
    "weights": { "hp": 0.9, "atk": 1.6, "def": 0.7 },
    "advanced": { "crit_chance": 0.2, "crit_dmg": 0.6, "dmg_resist_bypass": 0.1 } },
  { "archetype": "bomber", "lane": "middle", "attack_range": 220.0, "move_speed": 70.0,
    "idle_shortcut": "unit.mage_idle", "move_shortcut": "unit.mage_move", "ai_intent": "dot",
    "weights": { "hp": 1.0, "atk": 1.4, "def": 0.8 },
    "advanced": { "amplify": 0.1 } },
  { "archetype": "ranged", "lane": "rear", "attack_range": 320.0, "move_speed": 65.0,
    "idle_shortcut": "unit.ranged_idle", "move_shortcut": "unit.ranged_move", "ai_intent": "poke",
    "weights": { "hp": 0.8, "atk": 1.3, "def": 0.6 },
    "advanced": { "atk_spd": 1.3, "crit_chance": 0.1 } },
  { "archetype": "support", "lane": "rear", "attack_range": 280.0, "move_speed": 65.0,
    "idle_shortcut": "unit.support_idle", "move_shortcut": "unit.support_move", "ai_intent": "buff",
    "weights": { "hp": 0.9, "atk": 1.0, "def": 0.7 },
    "advanced": { "cooldown_reduction": 0.1 } },
  { "archetype": "healer", "lane": "rear", "attack_range": 280.0, "move_speed": 65.0,
    "idle_shortcut": "unit.healer_idle", "move_shortcut": "unit.healer_move", "ai_intent": "heal",
    "weights": { "hp": 0.9, "atk": 1.1, "def": 0.7 },
    "advanced": { "cooldown_reduction": 0.15 } }
]
```

- [ ] **Step 2: Write `data/combat/skills.json`**

```json
[
  { "id": "wildstripe_burst", "clan_id": "emberstripe", "starting_cooldown": 2.0, "cooldown": 8.0,
    "skill_ratio": 2.2, "effect_type": "aoe_damage", "target_side": "enemy", "max_targets": 0 },
  { "id": "cloudfur_mend", "clan_id": "cloudfur", "starting_cooldown": 2.0, "cooldown": 7.0,
    "skill_ratio": 1.4, "effect_type": "heal", "target_side": "ally", "max_targets": 0 },
  { "id": "ironpaw_bulwark", "clan_id": "ironpaw", "starting_cooldown": 3.0, "cooldown": 9.0,
    "skill_ratio": 0.0, "effect_type": "buff", "target_side": "ally", "max_targets": 0,
    "effect_params": { "stat": "dmg_resist", "value": 0.2, "duration": 4.0 } },
  { "id": "gale_volley", "clan_id": "galewhisker", "starting_cooldown": 3.0, "cooldown": 6.0,
    "skill_ratio": 1.6, "effect_type": "aoe_damage", "target_side": "enemy", "max_targets": 0 }
]
```

> **Note for the implementer:** the `clan_id` values above are placeholders keyed to whatever
> clans exist in `data/units/clans.json`. In Step 3 you set each clan's `skill_id` to the matching
> skill; if a clan has no skill yet, leave `skill_id` unset and `build_from_clan` returns `skill: null`.

- [ ] **Step 3: Modify `data/units/clans.json`**

For **each** clan object, add an `"archetype"` string (one of the 8 archetype ids) and, optionally, a `"skill_id"` matching `skills.json`, plus any advanced-stat overrides. Example shape to apply to every clan (values illustrative — pick an archetype that fits each clan's existing role):

```json
{
  "id": "emberstripe",
  "archetype": "front_charge",
  "skill_id": "wildstripe_burst",
  "advanced": { "crit_chance": 0.05 }
}
```

Keep all existing clan fields (`base_hp`, `base_atk`, `base_def`, `affinity`, …) intact — only add keys.

- [ ] **Step 4: Modify `data/combat/enemies.json`**

For each enemy object, add an `"archetype"` string. Bosses (e.g. the wave-10 enemy) should use `"front_defense"` or `"bomber"`; grunts `"front_charge"`; ranged enemies `"ranged"`. Keep existing fields intact.

- [ ] **Step 5: Write the failing test — append to `tests/combat_core_test.gd`**

Add call in `_ready()` before `_finish()`:

```gdscript
	_check_factory()
```

Add method:

```gdscript
func _check_factory() -> void:
	var f := CharacterFactory.new()
	f.load_all()

	# all 8 archetypes present
	_expect(f.archetype_ids().size() == 8, "expected 8 archetypes, got %d" % f.archetype_ids().size())

	# every clan builds a valid profile with a positive-HP StatSystem and a known lane
	var clan_ids := f.clan_ids()
	_expect(clan_ids.size() >= 1, "expected at least one clan to build from")
	for cid in clan_ids:
		var p := f.build_from_clan(cid)
		var stats: StatSystem = p.get("stats")
		_expect(stats != null, "clan %s should produce a StatSystem" % cid)
		_expect(stats != null and stats.get_stat(CombatEnums.StatKey.HP) > 0.0,
			"clan %s should have HP > 0" % cid)
		_expect(int(p.get("lane", -1)) in [CombatEnums.Lane.FRONT, CombatEnums.Lane.MIDDLE, CombatEnums.Lane.REAR],
			"clan %s should map to a valid lane" % cid)
		_expect(str(p.get("idle_shortcut", "")) != "", "clan %s should carry an idle_shortcut" % cid)
		_expect(float(p.get("attack_range", 0.0)) > 0.0, "clan %s should have attack_range > 0" % cid)

	# every enemy builds too
	for eid in f.enemy_ids():
		var pe := f.build_from_enemy(eid)
		var es: StatSystem = pe.get("stats")
		_expect(es != null and es.get_stat(CombatEnums.StatKey.HP) > 0.0, "enemy %s should have HP > 0" % eid)
```

- [ ] **Step 6: Run the test — verify it FAILS**

Run: `<godot> --headless res://tests/combat_core_test.tscn`
Expected: FAIL (`CharacterFactory` not found), exit non-zero.

- [ ] **Step 7: Write `scripts/combat/character_factory.gd`**

```gdscript
class_name CharacterFactory
extends RefCounted

# Pure-logic bridge: JSON (clans/enemies/archetypes/skills) -> battle-ready
# profiles. No scene deps; the live layer (Plan B) instantiates nodes from these.

const ARCHETYPES_PATH := "res://data/combat/archetypes.json"
const SKILLS_PATH := "res://data/combat/skills.json"
const CLANS_PATH := "res://data/units/clans.json"
const ENEMIES_PATH := "res://data/combat/enemies.json"

var _archetypes: Dictionary = {}   # archetype id string -> row
var _skills: Dictionary = {}       # skill id string -> row
var _clans: Dictionary = {}        # clan id string -> row
var _enemies: Dictionary = {}      # enemy id string -> row


func load_all() -> void:
	_archetypes = _index(_read_array(ARCHETYPES_PATH), "archetype")
	_skills = _index(_read_array(SKILLS_PATH), "id")
	_clans = _index(_read_array(CLANS_PATH), "id")
	_enemies = _index(_read_array(ENEMIES_PATH), "id")


func archetype_ids() -> Array: return _archetypes.keys()
func clan_ids() -> Array: return _clans.keys()
func enemy_ids() -> Array: return _enemies.keys()
func has_clan(id: String) -> bool: return _clans.has(id)
func has_enemy(id: String) -> bool: return _enemies.has(id)


func build_from_clan(clan_id: String) -> Dictionary:
	return _build(_clans.get(clan_id, {}))


func build_from_enemy(enemy_id: String) -> Dictionary:
	return _build(_enemies.get(enemy_id, {}))


func _build(row: Dictionary) -> Dictionary:
	var arch_id := str(row.get("archetype", "front_charge"))
	var arch: Dictionary = _archetypes.get(arch_id, {})
	var weights: Dictionary = arch.get("weights", {})

	var S := CombatEnums.StatKey
	var base_hp := float(row.get("base_hp", 100.0)) * float(weights.get("hp", 1.0))
	var base_atk := float(row.get("base_atk", 10.0)) * float(weights.get("atk", 1.0))
	var base_def := float(row.get("base_def", 5.0)) * float(weights.get("def", 1.0))
	var base_stats := {
		S.HP: round(base_hp), S.ATK: round(base_atk), S.DEF: round(base_def),
	}
	# advanced: archetype defaults, then per-row overrides
	for src in [arch.get("advanced", {}), row.get("advanced", {})]:
		for key in src:
			var sk := CombatEnums.stat_key_from_string(str(key))
			if sk != -1:
				base_stats[sk] = float(src[key])

	var stats := StatSystem.new(base_stats)

	var skill = null
	var skill_id := str(row.get("skill_id", ""))
	if skill_id != "" and _skills.has(skill_id):
		skill = CombatSkill.new(_skills[skill_id])

	return {
		"stats": stats,
		"archetype": CombatEnums.archetype_from_string(arch_id),
		"lane": CombatEnums.lane_from_string(str(arch.get("lane", "front"))),
		"attack_range": float(arch.get("attack_range", 100.0)),
		"move_speed": float(arch.get("move_speed", 70.0)),
		"idle_shortcut": str(arch.get("idle_shortcut", "")),
		"move_shortcut": str(arch.get("move_shortcut", "")),
		"skill": skill,
	}


func _index(rows: Array, key: String) -> Dictionary:
	var out: Dictionary = {}
	for r in rows:
		if typeof(r) == TYPE_DICTIONARY and r.has(key):
			out[str(r[key])] = r
	return out


func _read_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("CharacterFactory: missing data file %s" % path)
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_ARRAY else []
```

- [ ] **Step 8: Run the test — verify it PASSES**

Run: `<godot> --headless res://tests/combat_core_test.tscn`
Expected: `[combat_core_test] PASS`, exit 0.

- [ ] **Step 9: Regenerate no assets, then commit**

(No files under `asset/` changed, so the asset catalog does not need regenerating.)

```bash
git add data/combat/archetypes.json data/combat/skills.json data/units/clans.json data/combat/enemies.json scripts/combat/character_factory.gd tests/combat_core_test.gd
git commit -m "feat(combat): archetypes/skills data + CharacterFactory profile builder"
```

---

### Task 6: Run the full suite + document the core

**Files:**
- Modify: `docs/systems/COMBAT_SYSTEM.md` (add a "Combat core (Plan A)" section describing the new classes and the damage formula)

**Interfaces:** none (docs + verification only).

- [ ] **Step 1: Run both headless test scenes — verify BOTH pass**

Run:
```
<godot> --headless res://tests/combat_core_test.tscn
<godot> --headless res://tests/bootstrap_test.tscn
```
Expected: `[combat_core_test] PASS` (exit 0) and `[bootstrap_test] PASS` (exit 0). The bootstrap test must still pass — Plan A adds new files but changes no existing runtime code, so it should be unaffected.

- [ ] **Step 2: Add a "Combat core" section to `docs/systems/COMBAT_SYSTEM.md`**

Document: the six new `scripts/combat/*` classes and their responsibilities; the exact damage pipeline (spec §4); the archetype→stat-weighting rule; and that this is the pure-logic layer consumed by the live battle scene in Plan B. Keep it factual and short; link the spec.

- [ ] **Step 3: Commit**

```bash
git add docs/systems/COMBAT_SYSTEM.md
git commit -m "docs: document the auto-battler combat core (Plan A)"
```

---

## Self-Review

**Spec coverage (Plan A scope only):**
- §3 StatSystem → Task 1 ✅
- §4 DamageCalculator → Task 2 ✅
- §7 Starting Cooldown / CDR (skill mechanic) → Task 3 ✅
- Skill effects (`ISkillEffect` analog) → Task 4 ✅
- §5 archetypes + `CharacterData` template + role→sprite mapping → Task 5 ✅
- Testing via existing headless harness (spec §10) → Tasks 1–6 ✅
- **Deferred to Plan B (correctly out of scope here):** BattleEntity FSM + spatial aggro (§6), BattleManager phase machine + auto-cast controller + side-scroll (§7), `battle.tscn`, re-pointing `main.gd`/taskbar + retiring `battle_engine.gd` + signal-vocabulary seam (§2), the five Sage flow-doc updates (§10). These require the scene layer and are Plan B.

**Placeholder scan:** No "TBD/TODO/handle appropriately". The one explicit note (Task 5 Step 2) tells the implementer to reconcile `skill_id` with the real clan ids — that is a data-reconciliation instruction, not a code placeholder.

**Type consistency:** `StatSystem`, `StatModifier`, `DamageCalculator.compute(...)->{amount,is_crit}`, `CombatSkill` (fields `remaining/cooldown/starting_cooldown/skill_ratio/effect_type/effect_params`), `SkillEffect.apply(skill,caster,targets,crit_roll)->Array`, `CharacterFactory.build_from_clan/enemy(...)->profile dict` are used identically across all tasks and tests. `crit_roll` convention (`>=0` forces, `<0` rolls) is consistent between `DamageCalculator` and `SkillEffect`.

**Scope check:** Plan A is a single cohesive subsystem (pure-logic core + its data) that produces working, headless-testable software on its own. Plan B (live scene + integration) is the sequel and will be planned after Plan A lands.
