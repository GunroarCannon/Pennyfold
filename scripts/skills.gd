## The player's skill tree: points, learned skills and cooldowns. Numbers live
## in data/skills.json. A RefCounted owned by Main, like Career and Story.
class_name Skills
extends RefCounted

var data: Dictionary = {}
var by_id: Dictionary = {}
## id -> rank (1 for actives, up to `ranks` for passives)
var known: Dictionary = {}
var points := 0
var cool: Dictionary = {}


func _init() -> void:
	var f := FileAccess.open("res://data/skills.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			data = parsed
	for s in data.get("skills", []):
		by_id[String(s["id"])] = s
	points = int(data.get("start_points", 1))


func def(id: String) -> Dictionary:
	return by_id.get(id, {})


func rank(id: String) -> int:
	return int(known.get(id, 0))


func has(id: String) -> bool:
	return known.has(id)


func max_rank(id: String) -> int:
	return int(def(id).get("ranks", 1))


## Why a skill cannot be learned right now ("" when it can).
func why_not(id: String, level: int) -> String:
	var s := def(id)
	if s.is_empty():
		return "Unknown skill."
	if rank(id) >= max_rank(id):
		return "Fully learned."
	if level < int(s["min_level"]):
		return "Needs level %d." % int(s["min_level"])
	for n in s["needs"]:
		if not has(String(n)):
			return "Needs %s first." % String(def(String(n)).get("name", n))
	if points < int(s["cost"]):
		return "Needs %d skill point%s." % [int(s["cost"]), "" if int(s["cost"]) == 1 else "s"]
	return ""


func learn(id: String, level: int) -> bool:
	if why_not(id, level) != "":
		return false
	points -= int(def(id)["cost"])
	known[id] = rank(id) + 1
	return true


func grant(n: int) -> void:
	points += n


## Learned active skills in the order of the data file (hotbar order).
func actives() -> Array:
	var out: Array = []
	for s in data.get("skills", []):
		if s["kind"] == "active" and has(String(s["id"])):
			out.append(String(s["id"]))
	return out


## Sum of a passive stat over all learned ranks (hp, speed, ink, dmg).
func bonus(stat: String) -> float:
	var t := 0.0
	for id in known:
		var s := def(String(id))
		if s.get("kind", "") == "passive" and s.has(stat):
			t += float(s[stat]) * rank(String(id))
	return t


func tick(delta: float) -> void:
	for k in cool.keys():
		cool[k] = maxf(0.0, float(cool[k]) - delta)


func cool_frac(id: String) -> float:
	var c := float(cool.get(id, 0.0))
	var full := float(def(id).get("cool", 1.0))
	return clampf(c / maxf(full, 0.01), 0.0, 1.0)
