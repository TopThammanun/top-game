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
