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
