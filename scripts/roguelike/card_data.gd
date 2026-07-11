class_name CardData
extends RefCounted

var id: String = ""
var type: String = ""
var rarity: String = "common"
var title: String = ""
var target: String = "party"
var effect: Dictionary = {}
var unit_key: String = ""


static func from_dict(d: Dictionary) -> CardData:
	var c = new()
	c.id = str(d.get("id", ""))
	c.type = str(d.get("type", "stat"))
	c.rarity = str(d.get("rarity", "common"))
	c.title = str(d.get("title", ""))
	c.target = str(d.get("target", "party"))
	var eff = d.get("effect", {})
	if typeof(eff) == TYPE_DICTIONARY:
		c.effect = eff
	else:
		c.effect = {}
	c.unit_key = str(d.get("unit_key", ""))
	return c


func bind_to_unit(clan_id: String) -> CardData:
	var c = from_dict({
		"id": id, "type": type, "rarity": rarity, "title": title,
		"target": target, "effect": effect,
	})
	c.unit_key = clan_id
	return c


func is_upgrade() -> bool:
	return type == "stat" or type == "skill" or type == "passive"
