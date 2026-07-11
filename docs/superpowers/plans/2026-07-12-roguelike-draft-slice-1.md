# Roguelike Draft — Slice 1 (Core In-Run Loop) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the fixed-party auto-battler into the first playable roguelike run — pick 1 cat before the run, gain shared XP from kills, pause on level-up to draft 1 of 3 cards (recruit/stat/skill/passive), grow the party to 5, survive escalating endless waves until wipe, and bank a run reward.

**Architecture:** A pure-logic roguelike core (`scripts/roguelike/{run_state,card_data,card_system}.gd`, all `RefCounted`, headless-tested) owns the run's numbers and card pool. A presentation script `scripts/ui/draft_view.gd` renders the 3-card overlay. `scripts/combat/battle_view.gd` gets thin hooks that delegate to the core. `GameState`/`WaveState`/`UnitState` gain a pre-run party seed, a recruit path, a run-reward, and endless procedural waves. **Key invariant:** `_spawn_wave()` rebuilds every ally's `StatSystem` from `CharacterFactory` each wave, so run upgrades live in `RunState.upgrades` and are **re-applied on every `_spawn_wave`** (this also makes recruits inherit party upgrades for free).

**Tech Stack:** Godot 4.x, GDScript. Tests use the repo's headless scene harness (`tests/*.tscn` → `extends Node`, collect `failures`, print `PASS`/`FAIL`, `get_tree().quit(0|1)`).

**Spec:** `docs/superpowers/specs/2026-07-12-roguelike-draft-pivot-design.md` (Slice 1 = §10 first bullet).

## Global Constraints

- **Godot target:** 4.x (repo declares `config/features=("4.2")`; local binary is Godot 4.7). GDScript only.
- **Warnings are errors — never `:=` from a Variant.** `Dictionary.get()`, dict/array index, and untyped fields are `Variant`; inferring a type from them (`var x := dict.get(...)`) is a FATAL parse error → black screen. Always annotate (`var x: int = ...`) or wrap (`int(...)`, `str(...)`, `float(...)`). gdtoolkit does NOT catch this; only Godot does.
- **Cross-reference sibling scripts via `const XxxClass = preload("res://…")`, not bare global `class_name`** (headless class-cache convention — see `game_state.gd`, `battle_view.gd`). Where a param's type is another such class, leave it untyped.
- **No hard-coded `res://asset/...` paths** in gameplay code — resolve art via `AssetRegistry` shortcuts; add shortcuts to `data/asset_shortcuts.json` rather than new callers.
- **Data is JSON** under `data/`, following existing convention; keep spec and JSON in sync.
- **New global `class_name`s must not collide.** Taken: `UnitState`, `WaveState`, `BattleEngine`, `AssetRegistry`, `GameState`, `CombatEnums`, `StatSystem`, `StatModifier`, `DamageCalculator`, `CombatSkill`, `SkillEffect`, `CharacterFactory`. Free: `RunState`, `CardData`, `CardSystem`, `DraftView`.
- **Test invocation:** `<godot> --headless res://tests/<name>.tscn`, `<godot>` resolved as in `run_game.ps1`. PASS = exit 0. Determinism: seed a `RandomNumberGenerator` in tests that touch the draw RNG.
- **Verify with a real Godot run**, not just gdtoolkit, before claiming a `.gd` change works (Do-Not-Repeat 2026-07-11). If no Godot binary resolves in the environment, say so explicitly and run the headless test scenes with a fetched portable Godot 4.x.

---

### Task 1: RunState (shared XP, party roster, draft resources)

**Files:**
- Create: `scripts/roguelike/run_state.gd`
- Create: `data/roguelike/run_config.json`
- Create: `tests/roguelike_test.gd`
- Create: `tests/roguelike_test.tscn`

**Interfaces:**
- Produces:
  - `RunState.new(config: Dictionary = {}, starter_clan_id: String = "")`; fields `mode:String`, `party_ids:Array`, `run_level:int`, `run_xp:int`, `pending_levelups:int`, `rerolls:int`, `banishes:int`, `passives:Array`, `upgrades:Array`, `meta:Dictionary`.
  - `party_size()->int`, `party_cap()->int`, `has_member(clan_id:String)->bool`, `add_member(clan_id:String)->void`.
  - `xp_to_next(level:int)->int` = `int(base + lin*(level-1) + floor(level*level*quad))`.
  - `add_xp(amount:int)->int` — adds XP, crosses levels, increments `pending_levelups`, returns # level-ups gained.
  - `recruit_arrival_level()->int` = `max(1, floor(run_level * ratio))`.

- [ ] **Step 1: Write `data/roguelike/run_config.json`**

```json
{
  "xp_base": 10.0,
  "xp_lin": 6.0,
  "xp_quad": 0.4,
  "draft_size": 3,
  "party_cap": 5,
  "recruit_arrival_ratio": 0.7,
  "endless": { "boss_every": 5, "stat_scale_base": 1.12 }
}
```

- [ ] **Step 2: Write the failing test `tests/roguelike_test.gd`**

```gdscript
extends Node

# Headless unit tests for the roguelike core (scripts/roguelike/*).
# Invoke via: <godot> --headless res://tests/roguelike_test.tscn
# Mirrors tests/combat_core_test.gd: collect failures, print PASS/FAIL, quit 0/1.

const RunStateClass = preload("res://scripts/roguelike/run_state.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_check_run_state()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _check_run_state() -> void:
	var rs = RunStateClass.new({}, "maincoon_ironmane")
	_expect(rs.party_size() == 1, "starter seeds party of 1, got %d" % rs.party_size())
	_expect(rs.has_member("maincoon_ironmane"), "starter should be a member")
	_expect(rs.run_level == 1, "run starts at level 1")

	# XP curve: xp_to_next(1) = 10 + 0 + floor(1*1*0.4) = 10
	_expect(rs.xp_to_next(1) == 10, "xp_to_next(1) should be 10, got %d" % rs.xp_to_next(1))
	# xp_to_next(2) = 10 + 6 + floor(4*0.4=1.6) = 17
	_expect(rs.xp_to_next(2) == 17, "xp_to_next(2) should be 17, got %d" % rs.xp_to_next(2))

	# add_xp crosses exactly one level (10 -> level 2, 0 carry)
	var gained: int = rs.add_xp(10)
	_expect(gained == 1, "10 xp should grant 1 level, got %d" % gained)
	_expect(rs.run_level == 2, "run_level should be 2, got %d" % rs.run_level)
	_expect(rs.pending_levelups == 1, "pending_levelups should be 1, got %d" % rs.pending_levelups)

	# a big chunk can cross several levels
	var g2: int = rs.add_xp(1000)
	_expect(g2 >= 2, "1000 xp should cross multiple levels, got %d" % g2)

	# recruit arrival = floor(level*0.7), min 1
	rs.run_level = 10
	_expect(rs.recruit_arrival_level() == 7, "arrival at lvl10 should be 7, got %d" % rs.recruit_arrival_level())

	# party cap + de-dup
	for cid in ["a", "b", "c", "d", "e", "f"]:
		rs.add_member(cid)
	_expect(rs.party_size() == 5, "party caps at 5, got %d" % rs.party_size())
	rs.add_member("a")
	_expect(rs.party_size() == 5, "duplicate/over-cap add is a no-op")


func _finish() -> void:
	if _failures.is_empty():
		print("[roguelike_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[roguelike_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
```

- [ ] **Step 3: Write `tests/roguelike_test.tscn`**

```
[gd_scene load_steps=2 format=3 uid="uid://c0tbroguelike01"]

[ext_resource type="Script" path="res://tests/roguelike_test.gd" id="1_rl"]

[node name="RoguelikeTest" type="Node"]
script = ExtResource("1_rl")
```

- [ ] **Step 4: Run the test — verify it FAILS** (`RunState` not found)

Run: `<godot> --headless res://tests/roguelike_test.tscn` — Expected: FAIL / parse error, exit non-zero.

- [ ] **Step 5: Write `scripts/roguelike/run_state.gd`**

```gdscript
class_name RunState
extends RefCounted

# Run-scoped roguelike state. Pure logic — no scene/GameState deps.
# The battle scene owns live units; RunState owns the numbers that drive the
# draft cadence, plus the accumulated `upgrades` re-applied to freshly-built
# units each wave (battle_view._spawn_wave rebuilds StatSystems per wave).

const DEFAULTS := {
	"xp_base": 10.0, "xp_lin": 6.0, "xp_quad": 0.4,
	"party_cap": 5, "recruit_arrival_ratio": 0.7,
}

var mode: String = "endless"
var party_ids: Array = []            # Array[String] clan_ids, in join order
var run_level: int = 1
var run_xp: int = 0
var pending_levelups: int = 0
var rerolls: int = 0
var banishes: int = 0
var passives: Array = []             # Array[Dictionary] active party-wide passives
var upgrades: Array = []             # Array[Dictionary] resolved non-recruit picks
var meta: Dictionary = {}

var _cfg: Dictionary = {}


func _init(config: Dictionary = {}, starter_clan_id: String = "") -> void:
	_cfg = DEFAULTS.duplicate()
	for k in config:
		_cfg[k] = config[k]
	if starter_clan_id != "":
		party_ids = [starter_clan_id]


func party_size() -> int:
	return party_ids.size()


func party_cap() -> int:
	return int(_cfg.get("party_cap", 5))


func has_member(clan_id: String) -> bool:
	return party_ids.has(clan_id)


func add_member(clan_id: String) -> void:
	if not party_ids.has(clan_id) and party_size() < party_cap():
		party_ids.append(clan_id)


func xp_to_next(level: int) -> int:
	var base: float = float(_cfg.get("xp_base", 10.0))
	var lin: float = float(_cfg.get("xp_lin", 6.0))
	var quad: float = float(_cfg.get("xp_quad", 0.4))
	return int(base + lin * float(level - 1) + floor(float(level) * float(level) * quad))


func add_xp(amount: int) -> int:
	var gained: int = 0
	run_xp += max(0, amount)
	while run_xp >= xp_to_next(run_level):
		run_xp -= xp_to_next(run_level)
		run_level += 1
		gained += 1
	pending_levelups += gained
	return gained


func recruit_arrival_level() -> int:
	var ratio: float = float(_cfg.get("recruit_arrival_ratio", 0.7))
	return int(max(1.0, floor(float(run_level) * ratio)))
```

- [ ] **Step 6: Run the test — verify it PASSES**

Run: `<godot> --headless res://tests/roguelike_test.tscn` — Expected: `[roguelike_test] PASS`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add scripts/roguelike/run_state.gd data/roguelike/run_config.json tests/roguelike_test.gd tests/roguelike_test.tscn
git commit -m "feat(roguelike): RunState — shared XP curve, party roster, draft resources"
```

---

### Task 2: CardData (one draft card)

**Files:**
- Create: `scripts/roguelike/card_data.gd`
- Modify: `tests/roguelike_test.gd` (add `_check_card_data()` + call it)

**Interfaces:**
- Produces:
  - `CardData.from_dict(d: Dictionary) -> CardData`; fields `id,type,rarity,title,target,effect(Dictionary),unit_key`.
  - `bind_to_unit(clan_id: String) -> CardData` (copy with `unit_key` set).
  - `is_upgrade() -> bool` (`type in [stat, skill, passive]`).

- [ ] **Step 1: Add the failing test — append to `tests/roguelike_test.gd`**

Add `_check_card_data()` in `_ready()` before `_finish()`, add the preload at the top:

```gdscript
const CardDataClass = preload("res://scripts/roguelike/card_data.gd")
```

```gdscript
func _check_card_data() -> void:
	var c = CardDataClass.from_dict({
		"id": "atk_party_s", "type": "stat", "rarity": "common", "title": "Sharpened Claws",
		"target": "party", "effect": { "stat": "atk", "mod": "percent", "value": 0.08 },
	})
	_expect(c.id == "atk_party_s", "id parsed")
	_expect(c.type == "stat" and c.is_upgrade(), "stat is an upgrade")
	_expect(float(c.effect.get("value", 0.0)) == 0.08, "effect value parsed")
	_expect(c.unit_key == "", "unbound card has empty unit_key")

	var bound = c.bind_to_unit("bengalis_wildstripe")
	_expect(bound.unit_key == "bengalis_wildstripe", "bind sets unit_key")
	_expect(c.unit_key == "", "bind does not mutate the original")

	var rec = CardDataClass.from_dict({ "id": "r", "type": "recruit", "effect": { "clan_id": "x" } })
	_expect(not rec.is_upgrade(), "recruit is not an upgrade")
```

- [ ] **Step 2: Run — verify FAILS** (`CardData` not found). Exit non-zero.

- [ ] **Step 3: Write `scripts/roguelike/card_data.gd`**

```gdscript
class_name CardData
extends RefCounted

# One draft card. Parsed from data/roguelike/cards.json. `unit_key` is empty for
# party/global cards, or a clan_id when the card is bound to one specific ally.

var id: String = ""
var type: String = ""          # "recruit" | "stat" | "skill" | "passive"
var rarity: String = "common"
var title: String = ""
var target: String = "party"   # "party" | "unit" | "self"
var effect: Dictionary = {}
var unit_key: String = ""


static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = str(d.get("id", ""))
	c.type = str(d.get("type", "stat"))
	c.rarity = str(d.get("rarity", "common"))
	c.title = str(d.get("title", ""))
	c.target = str(d.get("target", "party"))
	var eff = d.get("effect", {})
	c.effect = eff if typeof(eff) == TYPE_DICTIONARY else {}
	c.unit_key = str(d.get("unit_key", ""))
	return c


func bind_to_unit(clan_id: String) -> CardData:
	var c := from_dict({
		"id": id, "type": type, "rarity": rarity, "title": title,
		"target": target, "effect": effect,
	})
	c.unit_key = clan_id
	return c


func is_upgrade() -> bool:
	return type == "stat" or type == "skill" or type == "passive"
```

- [ ] **Step 4: Run — verify PASSES.** Exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/roguelike/card_data.gd tests/roguelike_test.gd
git commit -m "feat(roguelike): CardData — parse + unit-binding + upgrade check"
```

---

### Task 3: CardSystem (pool, weighting, draw, resolve, describe)

**Files:**
- Create: `scripts/roguelike/card_system.gd`
- Create: `data/roguelike/cards.json`
- Modify: `tests/roguelike_test.gd` (add `_check_card_system()` + call it)

**Interfaces:**
- Consumes: `CardData`, a `RunState`, a `RandomNumberGenerator`.
- Produces:
  - `CardSystem.new()`; `load_from_array(rows: Array)`, `load_all(path := "res://data/roguelike/cards.json")`.
  - `CardSystem.recruit_weight(party_size: int) -> float` (static) = `clampf(0.45 - 0.06*party_size, 0.0, 0.45)`.
  - `candidates(run, roster_ids: Array) -> Array` (Array[CardData], filtered/expanded, no dead cards).
  - `draw(run, roster_ids: Array, rng) -> Array` (≤ draft_size distinct, rarity+recruit weighted, ≥1 upgrade).
  - `resolve(card, run) -> Dictionary` (scene-applies descriptor; `kind in [recruit,stat,skill,passive,none]`).
  - `describe(card) -> String` (card delta text).

- [ ] **Step 1: Write `data/roguelike/cards.json`** (Slice-1 pool — recruit uses the roster clan_ids; unit cards are auto-expanded per party member)

```json
[
  { "id": "atk_party_s", "type": "stat", "rarity": "common", "title": "Sharpened Claws",
    "target": "party", "effect": { "stat": "atk", "mod": "percent", "value": 0.08 } },
  { "id": "hp_party_s", "type": "stat", "rarity": "common", "title": "Hearty Meal",
    "target": "party", "effect": { "stat": "hp", "mod": "percent", "value": 0.10 } },
  { "id": "def_party_s", "type": "stat", "rarity": "common", "title": "Padded Coat",
    "target": "party", "effect": { "stat": "def", "mod": "percent", "value": 0.12 } },
  { "id": "atk_unit_m", "type": "stat", "rarity": "rare", "title": "Focus Training",
    "target": "unit", "effect": { "stat": "atk", "mod": "percent", "value": 0.20 } },
  { "id": "hp_unit_m", "type": "stat", "rarity": "rare", "title": "Thick Fur",
    "target": "unit", "effect": { "stat": "hp", "mod": "percent", "value": 0.25 } },
  { "id": "spd_party_r", "type": "stat", "rarity": "rare", "title": "Quick Paws",
    "target": "party", "effect": { "stat": "atk_spd", "mod": "percent", "value": 0.15 } },
  { "id": "cdr_unit_e", "type": "skill", "rarity": "epic", "title": "Faster Skill",
    "target": "unit", "effect": { "field": "cooldown", "op": "mul", "value": 0.75 } },
  { "id": "power_unit_e", "type": "skill", "rarity": "epic", "title": "Empowered Skill",
    "target": "unit", "effect": { "field": "skill_ratio", "op": "mul", "value": 1.30 } },
  { "id": "passive_might", "type": "passive", "rarity": "epic", "title": "Warcry Aura",
    "effect": { "passive_id": "might", "stat": "atk", "mod": "percent", "value": 0.12 } },
  { "id": "passive_crit", "type": "passive", "rarity": "epic", "title": "Keen Instinct",
    "effect": { "passive_id": "crit", "stat": "crit_chance", "mod": "flat", "value": 0.10 } },
  { "id": "passive_ward", "type": "passive", "rarity": "legendary", "title": "Guardian Ward",
    "effect": { "passive_id": "ward", "stat": "dmg_resist", "mod": "flat", "value": 0.10 } },
  { "id": "recruit_ironmane", "type": "recruit", "rarity": "rare", "title": "Ironmane",
    "effect": { "clan_id": "maincoon_ironmane" } },
  { "id": "recruit_wildstripe", "type": "recruit", "rarity": "rare", "title": "Wildstripe",
    "effect": { "clan_id": "bengalis_wildstripe" } },
  { "id": "recruit_voicecasters", "type": "recruit", "rarity": "rare", "title": "Voicecasters",
    "effect": { "clan_id": "siamheart_voicecasters" } },
  { "id": "recruit_silkpaw", "type": "recruit", "rarity": "rare", "title": "Silkpaw",
    "effect": { "clan_id": "persephone_silkpaw" } },
  { "id": "recruit_cloudfur", "type": "recruit", "rarity": "rare", "title": "Cloudfur",
    "effect": { "clan_id": "ragdollan_cloudfur" } },
  { "id": "recruit_emberpaw", "type": "recruit", "rarity": "rare", "title": "Emberpaw",
    "effect": { "clan_id": "shorthold_emberpaw" } },
  { "id": "recruit_quillwhisker", "type": "recruit", "rarity": "epic", "title": "Quillwhisker",
    "effect": { "clan_id": "abyssian_quillwhisker" } },
  { "id": "recruit_tinkertail", "type": "recruit", "rarity": "epic", "title": "Tinkertail",
    "effect": { "clan_id": "devonrex_tinkertail" } }
]
```

- [ ] **Step 2: Add the failing test — append to `tests/roguelike_test.gd`**

Add `_check_card_system()` in `_ready()` before `_finish()`, add the preload:

```gdscript
const CardSystemClass = preload("res://scripts/roguelike/card_system.gd")
```

```gdscript
func _check_card_system() -> void:
	# recruit weight curve
	_expect(abs(CardSystemClass.recruit_weight(1) - 0.39) < 0.001, "recruit_weight(1) ~ 0.39")
	_expect(abs(CardSystemClass.recruit_weight(5) - 0.15) < 0.001, "recruit_weight(5) ~ 0.15")
	_expect(CardSystemClass.recruit_weight(8) == 0.0, "recruit_weight(8) clamps to 0")

	var rows: Array = [
		{ "id": "s1", "type": "stat", "rarity": "common", "target": "party",
		  "effect": { "stat": "atk", "mod": "percent", "value": 0.08 } },
		{ "id": "u1", "type": "stat", "rarity": "rare", "target": "unit",
		  "effect": { "stat": "hp", "mod": "percent", "value": 0.2 } },
		{ "id": "rk", "type": "recruit", "rarity": "rare", "title": "Kilo",
		  "effect": { "clan_id": "kilo" } },
		{ "id": "rz", "type": "recruit", "rarity": "rare", "title": "Zulu",
		  "effect": { "clan_id": "zulu" } },
	]
	var cs = CardSystemClass.new()
	cs.load_from_array(rows)

	var roster: Array = ["alpha", "kilo", "zulu"]
	var run = RunStateClass.new({}, "alpha")

	# candidates: 1 party stat + 1 unit-expanded (party has 1 member) + 2 recruits = 4
	var cand: Array = cs.candidates(run, roster)
	_expect(cand.size() == 4, "candidates should be 4, got %d" % cand.size())

	# fill the party -> no recruit candidates remain
	for cid in ["kilo", "zulu", "b", "c"]:
		run.add_member(cid)
	var cand_full: Array = cs.candidates(run, roster)
	for c in cand_full:
		_expect(c.type != "recruit", "no recruit candidates when party is full")

	# draw: 3 distinct cards, deterministic under a seeded rng, >=1 upgrade
	var run2 = RunStateClass.new({}, "alpha")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var drawn: Array = cs.draw(run2, roster, rng)
	_expect(drawn.size() == 3, "draw returns 3, got %d" % drawn.size())
	var ids := {}
	for c in drawn:
		ids[c.id + c.unit_key] = true
	_expect(ids.size() == 3, "drawn cards are distinct")
	var has_up := false
	for c in drawn:
		if c.is_upgrade():
			has_up = true
	_expect(has_up, "draw guarantees at least one upgrade")

	# resolve shapes
	var stat_card = CardDataClass.from_dict(rows[0])
	var r1: Dictionary = cs.resolve(stat_card, run2)
	_expect(str(r1.get("kind", "")) == "stat" and str(r1.get("scope", "")) == "party", "party stat resolves")
	var rec_card = CardDataClass.from_dict(rows[2])
	var r2: Dictionary = cs.resolve(rec_card, run2)
	_expect(str(r2.get("kind", "")) == "recruit" and str(r2.get("clan_id", "")) == "kilo", "recruit resolves clan_id")
```

- [ ] **Step 3: Run — verify FAILS** (`CardSystem` not found). Exit non-zero.

- [ ] **Step 4: Write `scripts/roguelike/card_system.gd`**

```gdscript
class_name CardSystem
extends RefCounted

# The draft card pool + weighted draw. Pure logic; `run` is a RunState, `rng` is
# a RandomNumberGenerator (seed it in tests). resolve() returns a scene-free
# descriptor the battle scene applies; the scene owns all StatSystem mutation.

const CardDataClass = preload("res://scripts/roguelike/card_data.gd")

const RARITY_WEIGHT := { "common": 60.0, "rare": 28.0, "epic": 10.0, "legendary": 2.0 }
const DRAFT_SIZE := 3

var _cards: Array = []        # Array[CardData]


func load_from_array(rows: Array) -> void:
	_cards.clear()
	for r in rows:
		if typeof(r) == TYPE_DICTIONARY:
			_cards.append(CardDataClass.from_dict(r))


func load_all(path: String = "res://data/roguelike/cards.json") -> void:
	var rows: Array = []
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_ARRAY:
			rows = parsed
	load_from_array(rows)


static func recruit_weight(party_size: int) -> float:
	return clampf(0.45 - 0.06 * float(party_size), 0.0, 0.45)


func candidates(run, roster_ids: Array) -> Array:
	var out: Array = []
	var can_recruit: bool = run.party_size() < run.party_cap()
	for c in _cards:
		match c.type:
			"recruit":
				var cid: String = str(c.effect.get("clan_id", ""))
				if can_recruit and roster_ids.has(cid) and not run.has_member(cid):
					out.append(c)
			"stat", "skill":
				if c.target == "unit":
					for pid in run.party_ids:
						out.append(c.bind_to_unit(str(pid)))
				else:
					out.append(c)
			"passive":
				out.append(c)
	return out


func draw(run, roster_ids: Array, rng) -> Array:
	var pool: Array = candidates(run, roster_ids)
	var picked: Array = []
	var recruit_w: float = recruit_weight(run.party_size())
	while picked.size() < DRAFT_SIZE and pool.size() > 0:
		var idx: int = _weighted_index(pool, recruit_w, rng)
		picked.append(pool[idx])
		pool.remove_at(idx)
	# guarantee at least one upgrade if the pool has one
	if not _has_upgrade(picked) and picked.size() > 0:
		var up = _first_upgrade(candidates(run, roster_ids), picked)
		if up != null:
			picked[picked.size() - 1] = up
	return picked


func _weighted_index(pool: Array, recruit_w: float, rng) -> int:
	var weights: Array = []
	var total: float = 0.0
	for c in pool:
		var w: float = float(RARITY_WEIGHT.get(c.rarity, 10.0))
		if c.type == "recruit":
			w *= (recruit_w / 0.45)
		weights.append(w)
		total += w
	if total <= 0.0:
		return 0
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for i in weights.size():
		acc += float(weights[i])
		if roll <= acc:
			return i
	return weights.size() - 1


func _has_upgrade(cards: Array) -> bool:
	for c in cards:
		if c.is_upgrade():
			return true
	return false


func _first_upgrade(pool: Array, exclude: Array):
	for c in pool:
		if c.is_upgrade() and not exclude.has(c):
			return c
	return null


func resolve(card, run) -> Dictionary:
	match card.type:
		"recruit":
			return {
				"kind": "recruit", "clan_id": str(card.effect.get("clan_id", "")),
				"arrival_level": run.recruit_arrival_level(),
			}
		"stat":
			return {
				"kind": "stat", "scope": ("unit" if card.target == "unit" else "party"),
				"unit_key": card.unit_key,
				"stat": str(card.effect.get("stat", "atk")),
				"mod": str(card.effect.get("mod", "percent")),
				"value": float(card.effect.get("value", 0.1)),
			}
		"skill":
			return {
				"kind": "skill", "unit_key": card.unit_key,
				"field": str(card.effect.get("field", "cooldown")),
				"op": str(card.effect.get("op", "mul")),
				"value": float(card.effect.get("value", 0.9)),
			}
		"passive":
			return {
				"kind": "passive", "passive_id": str(card.effect.get("passive_id", "")),
				"scope": "party", "unit_key": "",
				"stat": str(card.effect.get("stat", "atk")),
				"mod": str(card.effect.get("mod", "percent")),
				"value": float(card.effect.get("value", 0.1)),
			}
	return { "kind": "none" }


func describe(card) -> String:
	match card.type:
		"recruit":
			return "Recruit %s" % card.title
		"stat":
			var pct: int = int(round(float(card.effect.get("value", 0.0)) * 100.0))
			var who: String = ("party" if card.target != "unit" else card.unit_key)
			return "+%d%% %s (%s)" % [pct, str(card.effect.get("stat", "")).to_upper(), who]
		"skill", "passive":
			return card.title
	return card.title
```

- [ ] **Step 5: Run — verify PASSES.** Exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/roguelike/card_system.gd data/roguelike/cards.json tests/roguelike_test.gd
git commit -m "feat(roguelike): CardSystem — pool, recruit/rarity weighting, draw, resolve"
```

---

### Task 4: Roster data (2 new cats) + `UnitState.from_clan` + shortcuts

**Files:**
- Modify: `data/units/clans.json` (add `sprite_shortcut` to the 6 existing; append 2 new cats)
- Modify: `data/combat/skills.json` (append 2 new skills)
- Modify: `data/asset_shortcuts.json` (add `unit.bomber_*` + card-UI shortcuts)
- Modify: `scripts/runtime/unit_state.gd` (add `from_clan`)
- Modify: `tests/roguelike_test.gd` (add `_check_roster()` + call it)

**Interfaces:**
- Consumes: `CharacterFactory`, `UnitState`, `data/units/clans.json`.
- Produces: `UnitState.from_clan(clan: Dictionary) -> UnitState` (builds a party unit from a clan row via `sprite_shortcut`).

- [ ] **Step 1: Add `sprite_shortcut` to each existing clan in `data/units/clans.json`**

Add the key to each of the 6 objects (keep all other fields):

| clan `id` | add |
|---|---|
| `maincoon_ironmane` | `"sprite_shortcut": "unit.tank_idle"` |
| `siamheart_voicecasters` | `"sprite_shortcut": "unit.mage_idle"` |
| `persephone_silkpaw` | `"sprite_shortcut": "unit.support_idle"` |
| `bengalis_wildstripe` | `"sprite_shortcut": "unit.striker_idle"` |
| `ragdollan_cloudfur` | `"sprite_shortcut": "unit.healer_idle"` |
| `shorthold_emberpaw` | `"sprite_shortcut": "unit.player_idle"` |

- [ ] **Step 2: Append 2 new clans to `data/units/clans.json`** (inside the top-level array)

```json
{
  "id": "abyssian_quillwhisker",
  "clan": "Abyssian",
  "public_name": "Quillwhisker",
  "reference_breed": "Abyssinian",
  "role": "ranged_dps",
  "lane": "rear",
  "archetype": "ranged",
  "skill_id": "quillwhisker_volley",
  "sprite_shortcut": "unit.ranged_idle",
  "identity": "keen-eyed archer",
  "gameplay_tags": ["ranged", "poke", "multi_hit"],
  "cute_hook": "twitchy ears and a feathered quiver",
  "base_hp": 78,
  "base_atk": 13,
  "base_def": 4,
  "affinity": "galeweave"
},
{
  "id": "devonrex_tinkertail",
  "clan": "Devon Rex",
  "public_name": "Tinkertail",
  "reference_breed": "Devon Rex",
  "role": "bomber",
  "lane": "middle",
  "archetype": "bomber",
  "skill_id": "tinkertail_flask",
  "sprite_shortcut": "unit.bomber_idle",
  "identity": "gadget-tossing tinkerer",
  "gameplay_tags": ["aoe", "amplify"],
  "cute_hook": "goggles and a satchel of fizzing flasks",
  "base_hp": 92,
  "base_atk": 12,
  "base_def": 5,
  "affinity": "emberweave"
}
```

- [ ] **Step 3: Append 2 new skills to `data/combat/skills.json`** (SUPPORTED effect types only — `aoe_damage`)

```json
{ "id": "quillwhisker_volley", "clan_id": "abyssian_quillwhisker", "starting_cooldown": 3.0, "cooldown": 6.0,
  "skill_ratio": 1.6, "effect_type": "aoe_damage", "target_side": "enemy", "max_targets": 3 },
{ "id": "tinkertail_flask", "clan_id": "devonrex_tinkertail", "starting_cooldown": 3.0, "cooldown": 7.0,
  "skill_ratio": 1.4, "effect_type": "aoe_damage", "target_side": "enemy", "max_targets": 0 }
```

- [ ] **Step 4: Add shortcuts to `data/asset_shortcuts.json`** — then verify each catalog id exists

Add these keys (inside the top-level object):

```json
"unit.bomber_idle": "map_1x_unit_sapper_01_idle",
"unit.bomber_move": "map_1x_unit_sapper_01_move",
"ui.card_frame": "ui_1x_background_box_bgbox_04a",
"ui.card_title": "ui_1x_title_banner_bannersmall_01a",
"ui.portrait_frame": "ui_1x_item_slot_slot_02_empty"
```

Verify each mapped id resolves in the catalog (adjust the id if a variant name differs):

Run: `powershell -Command "$c = Get-Content data/asset_catalog.json -Raw; foreach ($id in 'map_1x_unit_sapper_01_idle','map_1x_unit_sapper_01_move','ui_1x_background_box_bgbox_04a','ui_1x_title_banner_bannersmall_01a','ui_1x_item_slot_slot_02_empty') { if ($c -match [regex]::Escape($id)) { \"OK  $id\" } else { \"MISS $id\" } }"`
Expected: five `OK` lines. For any `MISS`, grep the catalog for the nearest id (`sapper`, `bgbox`, `bannersmall`, `slot_02`) and use the real one.

- [ ] **Step 5: Add `from_clan` to `scripts/runtime/unit_state.gd`** (after `from_enemy`)

```gdscript
static func from_clan(clan: Dictionary):
	var u = new()
	u.clan_id = str(clan.get("id", ""))
	u.id = "party_%s" % u.clan_id
	u.display_name = str(clan.get("public_name", clan.get("id", "")))
	u.party_role = str(clan.get("role", ""))
	u.lane = str(clan.get("lane", "front"))
	u.idle_asset = str(clan.get("sprite_shortcut", ""))
	u.move_asset = _move_asset_from_row(clan, u.idle_asset)
	u.modulate_hint = ""
	u.base_hp_max = int(clan.get("base_hp", 100))
	u.base_atk = int(clan.get("base_atk", 10))
	u.base_def = int(clan.get("base_def", 5))
	u.hp_max = u.base_hp_max
	u.hp_current = u.hp_max
	u.atk = u.base_atk
	u.def = u.base_def
	u.affinity = str(clan.get("affinity", "emberweave"))
	return u
```

- [ ] **Step 6: Add the failing test — append `_check_roster()` to `tests/roguelike_test.gd`**

Add the call in `_ready()` before `_finish()`, add the preloads:

```gdscript
const CharacterFactoryClass = preload("res://scripts/combat/character_factory.gd")
const UnitStateClass = preload("res://scripts/runtime/unit_state.gd")
```

```gdscript
func _check_roster() -> void:
	var f = CharacterFactoryClass.new()
	f.load_all()
	for cid in ["abyssian_quillwhisker", "devonrex_tinkertail"]:
		_expect(f.has_clan(cid), "clan %s should exist" % cid)
		var p: Dictionary = f.build_from_clan(cid)
		var stats = p.get("stats")
		_expect(stats != null and stats.get_stat(CombatEnumsForRoster().HP) > 0.0, "clan %s has HP>0" % cid)
		_expect(p.get("skill") != null, "clan %s has a skill" % cid)

	# from_clan builds a party unit with a sprite shortcut
	var rows := _read_clans()
	var iron: Dictionary = {}
	for r in rows:
		if str(r.get("id", "")) == "maincoon_ironmane":
			iron = r
	var u = UnitStateClass.from_clan(iron)
	_expect(u.clan_id == "maincoon_ironmane", "from_clan sets clan_id")
	_expect(u.idle_asset == "unit.tank_idle", "from_clan reads sprite_shortcut, got %s" % u.idle_asset)
	_expect(u.move_asset == "unit.tank_move", "from_clan derives move shortcut, got %s" % u.move_asset)
	_expect(u.base_hp_max > 0, "from_clan sets base hp")


func CombatEnumsForRoster():
	return preload("res://scripts/combat/combat_enums.gd").StatKey


func _read_clans() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/units/clans.json"))
	return parsed if typeof(parsed) == TYPE_ARRAY else []
```

- [ ] **Step 7: Run — verify PASSES** (the 2 new clans build, `from_clan` maps sprite). Exit 0.

- [ ] **Step 8: Commit**

```bash
git add data/units/clans.json data/combat/skills.json data/asset_shortcuts.json scripts/runtime/unit_state.gd tests/roguelike_test.gd
git commit -m "feat(roguelike): 2 new cats + sprite_shortcut per clan + UnitState.from_clan"
```

---

### Task 5: Endless procedural waves (`WaveState`)

**Files:**
- Modify: `scripts/runtime/wave_state.gd` (procedural generation past the authored catalog)
- Modify: `tests/roguelike_test.gd` (add `_check_waves()` + call it)

**Interfaces:**
- Produces: `WaveState.for_wave(...)` now returns a **procedurally-composed** wave (grunt/brute mix by index; `hollowmew_captain` boss on `wave % 5 == 0`) when `wave_number` is not in the authored catalog, instead of `push_error` + empty. Stat *scaling* is applied by the scene (Task 8 `_scale_enemy`), not here — `WaveState` only decides composition.

- [ ] **Step 1: Add the failing test — append `_check_waves()` to `tests/roguelike_test.gd`**

Add the call in `_ready()` before `_finish()`, add the preload:

```gdscript
const WaveStateClass = preload("res://scripts/runtime/wave_state.gd")
```

```gdscript
func _check_waves() -> void:
	var enemies_by_id := _enemies_index()
	# past the authored catalog (>10) it must generate, not error/empty
	var w11 = WaveStateClass.for_wave(11, [], enemies_by_id)
	_expect(w11.enemies.size() > 0, "wave 11 generates enemies, got %d" % w11.enemies.size())
	# boss cadence: wave 15 (15 %% 5 == 0) includes the boss id
	var w15 = WaveStateClass.for_wave(15, [], enemies_by_id)
	var has_boss := false
	for e in w15.enemies:
		if str(e.enemy_id).begins_with("hollowmew_captain"):
			has_boss = true
	_expect(has_boss, "wave 15 is a boss wave")
	# non-boss wave has no boss id
	var w12 = WaveStateClass.for_wave(12, [], enemies_by_id)
	var boss12 := false
	for e in w12.enemies:
		if str(e.enemy_id).begins_with("hollowmew_captain"):
			boss12 = true
	_expect(not boss12, "wave 12 is not a boss wave")


func _enemies_index() -> Dictionary:
	var out: Dictionary = {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/enemies.json"))
	if typeof(parsed) == TYPE_ARRAY:
		for r in parsed:
			if typeof(r) == TYPE_DICTIONARY and r.has("id"):
				out[str(r["id"])] = r
	return out
```

- [ ] **Step 2: Run — verify FAILS** (wave 11 currently errors → empty enemies). Exit non-zero.

- [ ] **Step 3: Edit `scripts/runtime/wave_state.gd`** — replace the final `push_error(...)` + `return ws` (the not-found fallback at the end of `for_wave`) with a call to a new `_procedural` generator, and add the generator.

Replace:

```gdscript
	push_error("Wave not found in catalog: %d" % wave_number)
	return ws
```

with:

```gdscript
	# Past the authored catalog: generate procedurally (endless mode).
	return _procedural(wave_number, enemies_by_id)


static func _procedural(wave_number: int, enemies_by_id: Dictionary):
	var ws = new()
	ws.wave = wave_number
	var is_boss: bool = wave_number % 5 == 0
	var comp: Array = []
	if is_boss:
		ws.type = "boss"
		comp.append("hollowmew_captain")
		var grunts: int = 2 + int(wave_number / 10)
		for i in grunts:
			comp.append("tangleborn_yarnling")
	else:
		ws.type = "endless"
		var count: int = 3 + int(wave_number / 2)
		for i in count:
			comp.append("tangleborn_snarlbeast" if i % 3 == 0 else "tangleborn_yarnling")
	var spawn_index: int = 0
	for enemy_id in comp:
		var enemy_row = enemies_by_id.get(str(enemy_id))
		if enemy_row == null:
			continue
		spawn_index += 1
		var enemy = UnitStateClass.from_enemy(enemy_row)
		enemy.id = "%s_%02d" % [enemy.enemy_id, spawn_index]
		ws.enemies.append(enemy)
	return ws
```

- [ ] **Step 4: Run — verify PASSES.** Exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/runtime/wave_state.gd tests/roguelike_test.gd
git commit -m "feat(roguelike): endless procedural waves with boss-every-5"
```

---

### Task 6: GameState — pre-run party seed, recruit, run reward, endless cap lift

**Files:**
- Modify: `scripts/runtime/game_state.gd`
- Create: `tests/roguelike_gamestate_test.gd`
- Create: `tests/roguelike_gamestate_test.tscn`

**Interfaces:**
- Produces on `GameState`:
  - `seed_run_party(clan_id: String) -> void` — replace `party` with a single `UnitState.from_clan`.
  - `recruit_member(clan_id: String) -> bool` — append a `UnitState.from_clan` if room + not present.
  - `get_clan_row(clan_id: String)` — clan dict or null.
  - `end_run(result: String, reward: int) -> void` — set status, bank reward, save, emit `run_ended`.
  - `advance_to_wave(n)` no longer caps at `MAX_WAVE`; `best_wave` load no longer clamps to `MAX_WAVE`.

- [ ] **Step 1: Relax the party-size assert** — in `_bootstrap_state`, replace:

```gdscript
	if party.size() != 4:
		push_error("Expected 4 starter party members, got %d" % party.size())
```

with:

```gdscript
	if party.size() < 1:
		push_warning("Party bootstrapped empty; a run must seed a starter cat")
```

- [ ] **Step 2: Lift the endless cap** — replace `advance_to_wave`:

```gdscript
func advance_to_wave(n: int) -> void:
	if n > MAX_WAVE:
		push_warning("Wave %d exceeds MVP cap (%d)" % [n, MAX_WAVE])
		return
	_load_wave(n)
```

with:

```gdscript
func advance_to_wave(n: int) -> void:
	_load_wave(n)
```

And in `load_save`, replace the `best_wave` clamp:

```gdscript
	best_wave = clamp(int(parsed.get("best_wave", 1)), 1, MAX_WAVE)
```

with:

```gdscript
	best_wave = max(1, int(parsed.get("best_wave", 1)))
```

- [ ] **Step 3: Add the new methods** — append to `scripts/runtime/game_state.gd`

```gdscript
func get_clan_row(clan_id: String):
	return _clans_by_id.get(clan_id)


func _party_has_clan(clan_id: String) -> bool:
	for u in party:
		if u.clan_id == clan_id:
			return true
	return false


func seed_run_party(clan_id: String) -> void:
	party.clear()
	if _clans_by_id.has(clan_id):
		party.append(UnitStateClass.from_clan(_clans_by_id[clan_id]))
	else:
		push_error("seed_run_party: unknown clan_id %s" % clan_id)
	_apply_upgrade_bonus_to_party(true)
	party_changed.emit()


func recruit_member(clan_id: String) -> bool:
	if _clans_by_id.has(clan_id) and not _party_has_clan(clan_id):
		party.append(UnitStateClass.from_clan(_clans_by_id[clan_id]))
		_apply_upgrade_bonus_to_party(false)
		party_changed.emit()
		return true
	return false


func end_run(result: String, reward: int) -> void:
	run_status = result
	best_wave = max(best_wave, wave)
	add_currency(max(0, reward))
	progression_changed.emit()
	save_game()
	run_ended.emit(result)
```

- [ ] **Step 4: Write the failing test `tests/roguelike_gamestate_test.gd`** (awaits the `GameState` autoload bootstrap)

```gdscript
extends Node

# Drives the GameState autoload (waits for bootstrap) to check the roguelike
# seams: single-cat seed, recruit, end_run reward, endless wave past the cap.

var _failures: Array[String] = []


func _ready() -> void:
	if not GameState.is_ready:
		await GameState.state_ready
	_run_checks()
	_finish()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _run_checks() -> void:
	# seed a single starter
	GameState.seed_run_party("maincoon_ironmane")
	_expect(GameState.party.size() == 1, "seed_run_party gives party of 1, got %d" % GameState.party.size())
	_expect(GameState.party[0].clan_id == "maincoon_ironmane", "seeded the chosen clan")

	# recruit grows the party and de-dups
	_expect(GameState.recruit_member("bengalis_wildstripe"), "recruit succeeds")
	_expect(GameState.party.size() == 2, "party grows to 2")
	_expect(not GameState.recruit_member("bengalis_wildstripe"), "duplicate recruit is rejected")

	# endless: advancing past MAX_WAVE loads a non-empty wave
	GameState.advance_to_wave(GameState.MAX_WAVE + 3)
	_expect(GameState.wave == GameState.MAX_WAVE + 3, "advanced past the cap")
	_expect(GameState.wave_state != null and GameState.wave_state.enemies.size() > 0, "endless wave has enemies")

	# end_run banks the reward and sets status
	var before: int = GameState.currency
	GameState.end_run("wiped", 40)
	_expect(GameState.currency == before + 40, "end_run adds reward")
	_expect(GameState.run_status == "wiped", "end_run sets status")


func _finish() -> void:
	if _failures.is_empty():
		print("[roguelike_gamestate_test] PASS")
		get_tree().quit(0)
	else:
		printerr("[roguelike_gamestate_test] FAIL — %d assertion(s):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		get_tree().quit(1)
```

- [ ] **Step 5: Write `tests/roguelike_gamestate_test.tscn`**

```
[gd_scene load_steps=2 format=3 uid="uid://c0tbroguelikegs01"]

[ext_resource type="Script" path="res://tests/roguelike_gamestate_test.gd" id="1_rlgs"]

[node name="RoguelikeGameStateTest" type="Node"]
script = ExtResource("1_rlgs")
```

- [ ] **Step 6: Run — verify PASSES** (autoloads load in the headless scene).

Run: `<godot> --headless res://tests/roguelike_gamestate_test.tscn` — Expected: `[roguelike_gamestate_test] PASS`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add scripts/runtime/game_state.gd tests/roguelike_gamestate_test.gd tests/roguelike_gamestate_test.tscn
git commit -m "feat(roguelike): GameState pre-run seed, recruit, end_run, endless cap lift"
```

---

### Task 7: DraftView (the 3-card overlay + reusable pick UI)

**Files:**
- Create: `scripts/ui/draft_view.gd`

**Interfaces:**
- Produces: `DraftView` (`extends CanvasLayer`, `class_name DraftView`).
  - Signal `chosen(index: int)`.
  - `show_cards(views: Array, view_size: Vector2) -> void` — `views[i] = { title, desc, rarity, sprite_shortcut }`.
  - `close() -> void`.
- Consumes: `AssetRegistry` (`load_texture`, `load_sprite_frame`).

This task has no unit test (pure presentation); it is verified via the runtime smoke in Task 10.

- [ ] **Step 1: Write `scripts/ui/draft_view.gd`**

```gdscript
class_name DraftView
extends CanvasLayer

# The level-up draft overlay. Modal: a full-rect dim (MOUSE_FILTER_STOP) covers
# the whole screen (including the top nav) so combat/nav can't be touched while
# time_scale is 0. Also reused for the pre-run starter pick (same card UI).
# Presentation only — the battle scene supplies the card views and applies picks.

signal chosen(index: int)

const RARITY_COL := {
	"common": Color(0.60, 0.62, 0.67), "rare": Color(0.37, 0.68, 1.0),
	"epic": Color(0.73, 0.55, 1.0), "legendary": Color(1.0, 0.82, 0.40),
}

var _root: Control


func _init() -> void:
	layer = 18   # above the nav screen layer (16), below the warp flash (20)


func show_cards(views: Array, view_size: Vector2) -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var title := _label("LEVEL UP — choose one", 28, Color(1.0, 0.9, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, view_size.y * 0.14)
	title.size = Vector2(view_size.x, 40)
	_root.add_child(title)

	var n := views.size()
	var card_w := 200.0
	var card_h := 300.0
	var gap := 28.0
	var total := float(n) * card_w + float(max(0, n - 1)) * gap
	var start_x := view_size.x * 0.5 - total * 0.5
	var y := view_size.y * 0.26
	for i in n:
		_build_card(views[i], start_x + float(i) * (card_w + gap), y, card_w, card_h, i)


func _build_card(v: Dictionary, x: float, y: float, w: float, h: float, index: int) -> void:
	var frame := NinePatchRect.new()
	var frame_tex := AssetRegistry.load_texture("ui.card_frame")
	if frame_tex != null:
		frame.texture = frame_tex
	else:
		var bg := ColorRect.new()   # fallback if the shortcut is missing
		bg.color = Color(0.16, 0.12, 0.22)
		bg.position = Vector2(x, y)
		bg.size = Vector2(w, h)
		_root.add_child(bg)
	frame.position = Vector2(x, y)
	frame.size = Vector2(w, h)
	_root.add_child(frame)

	var ribbon := ColorRect.new()   # rarity tint
	ribbon.color = RARITY_COL.get(str(v.get("rarity", "common")), Color.WHITE)
	ribbon.position = Vector2(x + 14.0, y + 14.0)
	ribbon.size = Vector2(w - 28.0, 8.0)
	_root.add_child(ribbon)

	var shortcut := str(v.get("sprite_shortcut", ""))
	if shortcut != "":
		var portrait := TextureRect.new()
		var ptex := AssetRegistry.load_sprite_frame(shortcut, 0, 0)   # idle, frame 0
		if ptex != null:
			portrait.texture = ptex
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.position = Vector2(x + w * 0.5 - 48.0, y + 40.0)
		portrait.size = Vector2(96.0, 96.0)
		_root.add_child(portrait)

	var name_lbl := _label(str(v.get("title", "")), 16, Color(0.22, 0.13, 0.07))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(x + 10.0, y + 150.0)
	name_lbl.size = Vector2(w - 20.0, 24.0)
	_root.add_child(name_lbl)

	var desc_lbl := _label(str(v.get("desc", "")), 12, Color(0.30, 0.20, 0.12))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.position = Vector2(x + 12.0, y + 180.0)
	desc_lbl.size = Vector2(w - 24.0, 60.0)
	_root.add_child(desc_lbl)

	var btn := Button.new()
	btn.text = "PICK"
	btn.position = Vector2(x + w * 0.5 - 45.0, y + h - 46.0)
	btn.size = Vector2(90.0, 32.0)
	btn.pressed.connect(func() -> void: chosen.emit(index))
	_root.add_child(btn)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


func close() -> void:
	if _root != null:
		_root.queue_free()
		_root = null
```

- [ ] **Step 2: Sanity-parse** (no runtime yet — a real check happens in Task 10)

Run: `python -c "import gdtoolkit.parser as p; p.parser.parse(open(r'scripts/ui/draft_view.gd').read())"` (if gdtoolkit is available) — Expected: no parse error. (Note: gdtoolkit does NOT catch `:=`-from-Variant; the true check is the Godot run in Task 10.)

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/draft_view.gd
git commit -m "feat(roguelike): DraftView — modal 3-card level-up overlay"
```

---

### Task 8: Wire the roguelike loop into `battle_view.gd`

**Files:**
- Modify: `scripts/combat/battle_view.gd`

**Interfaces:**
- Consumes: `RunState`, `CardSystem`, `DraftView`, `StatModifier`, `CombatEnums`, and the new `GameState` methods.
- Produces: the live loop — XP on kill, wave-clear XP, level-up pause + draft, pick application (with per-wave re-apply), enemy wave-scaling, endless never-win, run reward.

- [ ] **Step 1: Add preload consts** — after the existing `SkillEffectClass` preload (line ~14):

```gdscript
const RunStateClass = preload("res://scripts/roguelike/run_state.gd")
const CardSystemClass = preload("res://scripts/roguelike/card_system.gd")
const DraftViewClass = preload("res://scripts/ui/draft_view.gd")
const StatModifierClass = preload("res://scripts/combat/stat_modifier.gd")

const BASE_STARTER_IDS := [
	"maincoon_ironmane", "shorthold_emberpaw", "bengalis_wildstripe",
	"siamheart_voicecasters", "persephone_silkpaw", "ragdollan_cloudfur",
]
```

- [ ] **Step 2: Add member vars** — near the other state vars (after line ~167):

```gdscript
var _run                                   # RunState
var _card_system                           # CardSystem
var _draft                                 # DraftView
var _roster_ids: Array = []                # clan_ids recruitable this run
var _rng: RandomNumberGenerator
var _pending_cards: Array = []             # CardData currently shown in the draft
var _picking_starter: bool = false
var _starter_ids_cache: Array = []
```

- [ ] **Step 3: Init RNG + card system in `_ready`/`_try_start`.** In `_ready()` (after `Engine.time_scale = 1.0`, line 200) add:

```gdscript
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
```

In `_try_start()`, replace the final `_spawn_wave()` (line ~229) with the card-system init + starter pick:

```gdscript
	_card_system = CardSystemClass.new()
	_card_system.load_all()
	_roster_ids = _factory.clan_ids()
	_begin_starter_pick()
```

- [ ] **Step 4: Add the starter-pick + draft flow** — append these functions to `battle_view.gd`:

```gdscript
# ---------------------------------------------------------------- roguelike run

func _ensure_draft() -> void:
	if _draft == null:
		_draft = DraftViewClass.new()
		add_child(_draft)
		_draft.chosen.connect(_on_draft_chosen)


func _begin_starter_pick() -> void:
	_phase = "levelup"                       # freeze the boot frame; no combat yet
	_picking_starter = true
	_starter_ids_cache = BASE_STARTER_IDS.duplicate()
	var views: Array = []
	for cid in _starter_ids_cache:
		var row = GameState.get_clan_row(str(cid))
		if row == null:
			continue
		views.append({
			"title": str(row.get("public_name", cid)),
			"desc": "Start as %s" % str(row.get("role", "")),
			"rarity": "rare",
			"sprite_shortcut": str(row.get("sprite_shortcut", "")),
		})
	_ensure_draft()
	_draft.show_cards(views, _view_size)


func _on_draft_chosen(index: int) -> void:
	if _picking_starter:
		_finish_starter_pick(index)
	else:
		_on_levelup_chosen(index)


func _finish_starter_pick(index: int) -> void:
	if index < 0 or index >= _starter_ids_cache.size():
		return
	var cid: String = str(_starter_ids_cache[index])
	GameState.seed_run_party(cid)
	_run = RunStateClass.new({}, cid)
	_picking_starter = false
	_draft.close()
	_phase = "fighting"
	_spawn_wave()


func _open_draft() -> void:
	_phase = "levelup"
	Engine.time_scale = 0.0
	_pending_cards = _card_system.draw(_run, _roster_ids, _rng)
	var views: Array = []
	for c in _pending_cards:
		views.append({
			"title": c.title,
			"desc": _card_system.describe(c),
			"rarity": c.rarity,
			"sprite_shortcut": _card_sprite(c),
		})
	_ensure_draft()
	_draft.show_cards(views, _view_size)


func _on_levelup_chosen(index: int) -> void:
	if index < 0 or index >= _pending_cards.size():
		return
	_apply_pick(_card_system.resolve(_pending_cards[index], _run))
	_run.pending_levelups = max(0, _run.pending_levelups - 1)
	_draft.close()
	if _run.pending_levelups > 0:
		_open_draft()
	else:
		Engine.time_scale = SPEED_STEPS[_speed_idx]
		_phase = "fighting"


func _card_sprite(card) -> String:
	# recruit -> the recruited clan's sprite; unit-bound -> that ally's sprite;
	# party/passive -> the first party member's sprite as a stand-in.
	var cid: String = ""
	if card.type == "recruit":
		cid = str(card.effect.get("clan_id", ""))
	elif card.unit_key != "":
		cid = card.unit_key
	elif _run != null and _run.party_size() > 0:
		cid = str(_run.party_ids[0])
	var row = GameState.get_clan_row(cid)
	return str(row.get("sprite_shortcut", "")) if row != null else ""


func _apply_pick(res: Dictionary) -> void:
	if str(res.get("kind", "")) == "recruit":
		_apply_recruit(res)
		return
	_run.upgrades.append(res)
	if str(res.get("kind", "")) == "passive":
		_run.passives.append(res)
	_apply_one_upgrade(res, _living("ally"))


func _apply_recruit(res: Dictionary) -> void:
	var clan_id: String = str(res.get("clan_id", ""))
	if clan_id == "":
		return
	if GameState.recruit_member(clan_id):
		_run.add_member(clan_id)   # the recruit spawns next wave via _do_wave_swap


func _apply_one_upgrade(res: Dictionary, allies: Array) -> void:
	match str(res.get("kind", "")):
		"stat", "passive":
			_apply_stat_mod(res, allies)
		"skill":
			_apply_skill_mod(res, allies)


func _apply_stat_mod(res: Dictionary, allies: Array) -> void:
	var stat_key: int = CombatEnumsClass.stat_key_from_string(str(res.get("stat", "atk")))
	if stat_key == -1:
		return
	var mod_type: int = (CombatEnumsClass.ModifierType.PERCENT
		if str(res.get("mod", "percent")) == "percent"
		else CombatEnumsClass.ModifierType.FLAT)
	var value: float = float(res.get("value", 0.1))
	var scope: String = str(res.get("scope", "party"))
	var key: String = str(res.get("unit_key", ""))
	var source: String = "draft" if str(res.get("kind", "")) == "stat" else "passive"
	for u in allies:
		if scope == "unit" and str(u.get("clan_id", "")) != key:
			continue
		u["stats"].add_modifier(StatModifierClass.new(stat_key, mod_type, value, source, 0.0))
		if stat_key == CombatEnumsClass.StatKey.HP:
			u["hp_max"] = maxf(1.0, u["stats"].get_stat(CombatEnumsClass.StatKey.HP))


func _apply_skill_mod(res: Dictionary, allies: Array) -> void:
	var key: String = str(res.get("unit_key", ""))
	var field: String = str(res.get("field", "cooldown"))
	var op: String = str(res.get("op", "mul"))
	var value: float = float(res.get("value", 0.9))
	for u in allies:
		if key != "" and str(u.get("clan_id", "")) != key:
			continue
		var sk = u["skill"]
		if sk == null:
			continue
		match field:
			"cooldown":
				sk.cooldown = maxf(0.5, sk.cooldown * value) if op == "mul" else maxf(0.5, sk.cooldown + value)
			"skill_ratio":
				sk.skill_ratio = sk.skill_ratio * value if op == "mul" else sk.skill_ratio + value
			"max_targets":
				sk.max_targets = int(sk.max_targets + value)


func _scale_enemy(eu: Dictionary, wave: int) -> void:
	if eu["stats"] == null:
		return
	var mult: float = pow(1.12, float(max(0, wave - 1)))
	if mult <= 1.0:
		return
	var pct: float = mult - 1.0
	eu["stats"].add_modifier(StatModifierClass.new(CombatEnumsClass.StatKey.HP, CombatEnumsClass.ModifierType.PERCENT, pct, "wavescale", 0.0))
	eu["stats"].add_modifier(StatModifierClass.new(CombatEnumsClass.StatKey.ATK, CombatEnumsClass.ModifierType.PERCENT, pct, "wavescale", 0.0))
	eu["stats"].current_hp = eu["stats"].get_stat(CombatEnumsClass.StatKey.HP)
	eu["hp_max"] = maxf(1.0, eu["stats"].get_stat(CombatEnumsClass.StatKey.HP))
```

- [ ] **Step 5: Store `clan_id` on ally unit dicts + re-apply run upgrades + scale enemies in `_spawn_wave`.**

(a) In `_build_unit`'s returned dict (line ~544, after `"base_mod": ...`) add:

```gdscript
		"clan_id": "",
```

(b) In `_spawn_wave`, tag allies with their clan_id and re-apply run upgrades. Replace the ally-build loop (lines 454-456):

```gdscript
	var allies: Array = []
	for u in party:
		allies.append(_build_unit(_factory.build_from_clan(str(u.clan_id)), str(u.display_name), "ally", str(u.idle_asset), str(u.move_asset)))
```

with:

```gdscript
	var allies: Array = []
	for u in party:
		var au := _build_unit(_factory.build_from_clan(str(u.clan_id)), str(u.display_name), "ally", str(u.idle_asset), str(u.move_asset))
		au["clan_id"] = str(u.clan_id)
		allies.append(au)
	# Allies are rebuilt each wave from fresh StatSystems, so re-apply the run's
	# accumulated upgrades (this also makes recruits inherit party upgrades).
	if _run != null:
		for res in _run.upgrades:
			_apply_one_upgrade(res, allies)
		for a in allies:
			a["stats"].current_hp = a["stats"].get_stat(CombatEnumsClass.StatKey.HP)
			a["hp_max"] = maxf(1.0, a["stats"].get_stat(CombatEnumsClass.StatKey.HP))
```

(c) In `_spawn_wave`, scale enemies by wave. Replace the enemy-build loop (lines 459-461):

```gdscript
	if GameState.wave_state != null:
		for e in GameState.wave_state.enemies:
			enemies.append(_build_unit(_factory.build_from_enemy(str(e.enemy_id)), str(e.display_name), "enemy", str(e.idle_asset), str(e.move_asset)))
```

with:

```gdscript
	if GameState.wave_state != null:
		for e in GameState.wave_state.enemies:
			var eu := _build_unit(_factory.build_from_enemy(str(e.enemy_id)), str(e.display_name), "enemy", str(e.idle_asset), str(e.move_asset))
			_scale_enemy(eu, _wave)
			enemies.append(eu)
```

- [ ] **Step 6: XP hooks.**

(a) Kill XP — in `_kill`, inside the `if target["side"] == "enemy":` block (after line 1704, `_yarn += 1`), add:

```gdscript
		if _run != null:
			_run.add_xp(1)
```

(b) Wave-clear bonus XP — in `_do_wave_swap`, after `_refresh_wave_label()` (line 1814) and before `_phase = "fighting"` (line 1815), add:

```gdscript
	if _run != null:
		_run.add_xp(5 + _wave)
```

- [ ] **Step 7: Level-up check + endless wave end + run reward.**

(a) In `_process`, after `_update_skill_bar()` (line 604), before `if _phase == "fighting":` (line 605), add:

```gdscript
	if _phase == "fighting" and _run != null and _run.pending_levelups > 0:
		_open_draft()
		return
```

(b) Endless never-win — in `_check_wave_end`, replace:

```gdscript
	elif enemies_alive == 0:
		if _wave >= GameState.MAX_WAVE:
			_end("won")
		else:
			_advance_wave()
```

with:

```gdscript
	elif enemies_alive == 0:
		_advance_wave()
```

(c) Run reward — in `_end`, after `_post_timer = 3.0` (line 1831), add:

```gdscript
	if _run != null:
		GameState.end_run(result, _wave * 8)
```

- [ ] **Step 8: Verify it launches + a draft appears** (runtime — see Task 10 for the full smoke). Quick check:

Run: `.\run_game.ps1` (or the fetched portable Godot). Expected: the game boots into a **starter-pick** overlay of 6 cats; picking one starts the fight; killing enemies fills XP and a **3-card level-up** overlay pauses the battle; picking a card resumes. No parse/black-screen errors in the log.

- [ ] **Step 9: Commit**

```bash
git add scripts/combat/battle_view.gd
git commit -m "feat(roguelike): wire run loop into battle_view — XP, draft, recruit, endless, reward"
```

---

### Task 9: Full headless suite + runtime smoke + docs

**Files:**
- Modify: `docs/systems/COMBAT_SYSTEM.md` (add a "Roguelike run (Slice 1)" section)
- Modify: `.wolf/anatomy.md` (add the new `scripts/roguelike/*`, `scripts/ui/draft_view.gd`, `data/roguelike/*`, new tests)

- [ ] **Step 1: Run every headless test scene — all must pass**

```
<godot> --headless res://tests/roguelike_test.tscn
<godot> --headless res://tests/roguelike_gamestate_test.tscn
<godot> --headless res://tests/combat_core_test.tscn
<godot> --headless res://tests/bootstrap_test.tscn
```
Expected: `[roguelike_test] PASS`, `[roguelike_gamestate_test] PASS`, `[combat_core_test] PASS`, `[bootstrap_test] PASS`, all exit 0. The combat-core and bootstrap tests must still pass — Slice 1 adds files and data keys but changes no existing combat-core code.

- [ ] **Step 2: Runtime smoke** (prove the loop end-to-end)

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\capture_runtime_screenshot.ps1` (pass `-GodotPath <exe>` if needed). Confirm from the screenshot + log: starter-pick overlay renders → after picking, the side-scroll fight runs → a level-up overlay with 3 cards appears and pauses combat → picking resumes. Report the ACTUAL output; if no Godot binary resolves, say so explicitly and fetch a portable Godot 4.x to run the headless suite + a `--quit-after` boot of `res://scenes/combat/battle.tscn` to confirm no parse/runtime errors.

- [ ] **Step 3: Document** — add to `docs/systems/COMBAT_SYSTEM.md` a short "Roguelike run (Slice 1)" section: the `scripts/roguelike/*` classes, the XP→draft loop, that `RunState.upgrades` is re-applied each `_spawn_wave` (because allies rebuild per wave), recruit-next-wave, and endless procedural scaling. Link the spec.

- [ ] **Step 4: Update `.wolf/anatomy.md`** with the new files (RunState, CardData, CardSystem, DraftView, cards.json, run_config.json, the two roguelike test scenes) and append a one-line entry to `.wolf/memory.md`.

- [ ] **Step 5: Commit**

```bash
git add docs/systems/COMBAT_SYSTEM.md .wolf/anatomy.md .wolf/memory.md
git commit -m "docs(roguelike): document Slice 1 run loop + refresh anatomy"
```

---

## Self-Review

**Spec coverage (Slice 1 scope only):**
- Pre-run hero pick (start with 1) → Task 6 (`seed_run_party`) + Task 8 (`_begin_starter_pick`, reuses DraftView) ✅
- Shared run XP + curve → Task 1 (RunState) + Task 8 (kill XP 1699+, wave-clear XP in `_do_wave_swap`) ✅
- Level-up pause + DraftView (4 card types) → Task 3 (CardSystem), Task 7 (DraftView), Task 8 (`_open_draft`/`_apply_pick`) ✅
- Recruit next-wave → Task 6 (`recruit_member`) + Task 8 (`_apply_recruit`; arrives via `_do_wave_swap` re-read) ✅
- Endless escalating waves → Task 5 (procedural `WaveState`) + Task 6 (cap lift) + Task 8 (`_scale_enemy`, never-win) ✅
- Wipe/end → run reward → Task 6 (`end_run`) + Task 8 (`_end` hook) ✅
- Headless tests for CardSystem + WaveState → Tasks 3, 5, 6 ✅
- Persistence of run upgrades across per-wave rebuilds → Task 8 Step 5b (re-apply `_run.upgrades` in `_spawn_wave`) ✅
- New skills use only supported effect types (`aoe_damage`) → Task 4 ✅
- No hard-coded asset paths (shortcuts + verify step) → Task 4 ✅

**Placeholder scan:** No "TBD/TODO/handle appropriately". Every code step has complete code. Task 4 Step 4 includes a real verification command with an explicit fallback for a mismatched catalog id (data reconciliation, not a code placeholder).

**Type consistency (across tasks):** `RunState` fields (`party_ids/run_level/run_xp/pending_levelups/upgrades/passives`) and methods (`add_xp/party_size/party_cap/has_member/add_member/recruit_arrival_level`) are used identically in Tasks 1, 3, 8. `CardSystem.draw(run, roster_ids, rng)`, `candidates(run, roster_ids)`, `resolve(card, run)->{kind,...}`, `describe(card)` match between Tasks 3 and 8. `resolve` descriptor keys (`kind/scope/unit_key/stat/mod/value/field/op/clan_id/arrival_level`) are produced in Task 3 and consumed field-for-field in Task 8's `_apply_*`. `UnitState.from_clan(clan)->UnitState` defined in Task 4, called in Task 6 (`seed_run_party`/`recruit_member`). `GameState.seed_run_party/recruit_member/get_clan_row/end_run` defined in Task 6, called in Task 8. Unit dicts gain `clan_id` in Task 8 Step 5a and are read by `_apply_stat_mod`/`_apply_skill_mod`. `DraftView.show_cards(views, view_size)` + signal `chosen(index)` defined in Task 7, used in Task 8.

**Scope check:** Slice 1 is one cohesive subsystem (the in-run roguelike loop) producing working, testable software. Slice 2 (campaign, reroll/skip/banish, boss-every-N variety, pity) and Slice 3 (meta-progression, evolutions, mid-wave recruit, UI polish) are separate plans, per the spec.
