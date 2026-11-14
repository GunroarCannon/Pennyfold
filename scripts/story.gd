## The story spine: the Penny Crown, torn into four corners. Chapters come
## from data/story.json. Each is given by the guard captain of its city; the
## goal is checked by events (kills, the pack's contents) and the reward is real
## money from the crown vault. Finishing the last chapter plays the ending
## and starts New Game Plus (tougher beasts).
class_name Story
extends RefCounted

const PATH := "res://data/story.json"
const VAULT := "crown"

var data: Dictionary = {}
var chapter := 0
## "idle" (not yet told), "active" (the goal is running)
var state := "idle"
var progress := 0
var finished := false
var plus := 0
var unlocked: Dictionary = {"sunny": true}
var log: Array = []


func _init() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			data = d
	if data.is_empty():
		push_error("Story: could not read %s" % PATH)


func vault_coins() -> int:
	return int(data.get("vault", 500))


func current() -> Dictionary:
	var ch: Array = data.get("chapters", [])
	if finished or chapter >= ch.size():
		return {}
	return ch[chapter]


func monster_mult() -> float:
	return 1.0 + float(data.get("plus_hp", 0.45)) * plus


## The chapter's story NPC: the guard of its city.
func giver(world) -> Npc:
	var c := current()
	if c.is_empty():
		return null
	for n in world.npcs:
		if n.job_kind == "guard" and n.city == c["city"]:
			return n
	return null


func is_giver(world, n: Npc) -> bool:
	return giver(world) == n


func goal_text(world) -> String:
	var c := current()
	if c.is_empty():
		return ""
	var g: Dictionary = c["goal"]
	match String(g["type"]):
		"hunt":
			var what: String = "beasts" if g["monster"] == "any" else world.monster_name(g["monster"], true)
			return "Defeat %d %s (%d/%d)" % [int(g["count"]), what, mini(progress, int(g["count"])), int(g["count"])]
		"deliver":
			return "Bring %d %s to the captain of %s (you carry %d)" % [int(g["count"]), String(Economy.GOODS[g["good"]]["name"]).to_lower(), _cname(c["city"]), held(g)]
		"boss":
			return "Defeat the %s at Thorn Ruins" % world.monster_name("boss", false)
	return ""


func held(g: Dictionary) -> int:
	return int(Economy.wallets["player"]["items"].get(g.get("good", ""), 0))


func _cname(city: String) -> String:
	return String(Economy.city_def(city).get("name", city))


func goal_met(world) -> bool:
	var c := current()
	if c.is_empty() or state != "active":
		return false
	var g: Dictionary = c["goal"]
	match String(g["type"]):
		"hunt", "boss":
			return progress >= int(g["count"])
		"deliver":
			return held(g) >= int(g["count"])
	return false


func level_ok(world) -> bool:
	var c := current()
	return not c.is_empty() and world.career.level >= int(c["level"])


func on_kill(world, kind: String) -> void:
	var c := current()
	if c.is_empty() or state != "active":
		return
	var g: Dictionary = c["goal"]
	if String(g["type"]) in ["hunt", "boss"] and (g["monster"] == "any" or g["monster"] == kind):
		progress += 1
		if progress == int(g["count"]):
			Economy.message.emit("Story goal reached: go back to the captain of %s." % _cname(c["city"]))


## Dialog options a guard captain adds for the story.
func options(world, n: Npc) -> Array:
	var out: Array = []
	if finished:
		out.append({"text": "Tell me about the Crown.", "story": "recap"})
	elif is_giver(world, n):
		if state == "idle":
			out.append({"text": "The Penny Crown? (%s)" % current()["title"], "story": "intro"})
		elif goal_met(world):
			out.append({"text": "It is done. (%s)" % current()["title"], "story": "finish"})
		else:
			out.append({"text": "About the Crown task...", "story": "remind"})
	if n.job_kind == "guard":
		for id in unlocked:
			if id != n.city and unlocked[id]:
				out.append({"text": "Send me to %s." % _cname(id), "travel": id})
	return out


## Handles a story dialog choice; returns what the captain says.
func choose(world, kind: String) -> String:
	var c := current()
	match kind:
		"recap":
			return "The Crown is whole, thanks to you. Beasts roam tougher now (New Game Plus %d). %s" % [plus, String(data.get("blurb", ""))]
		"intro":
			if not level_ok(world):
				return "%s\n\nCome back at level %d. You are level %d. Practise on the road first." % [data.get("blurb", ""), int(c["level"]), world.career.level]
			state = "active"
			progress = 0
			log.append(c["title"])
			Economy.message.emit("Story: %s. %s" % [c["title"], goal_text(world)])
			return "%s\n\nGoal: %s" % [String(data["blurb"]) + "\n\n" + String(c["intro"]) if chapter == 0 else String(c["intro"]), goal_text(world)]
		"remind":
			return "Still at it? Goal: %s" % goal_text(world)
		"finish":
			return _complete(world)
	return ""


func _complete(world) -> String:
	var c := current()
	var g: Dictionary = c["goal"]
	if String(g["type"]) == "deliver":
		for i in int(g["count"]):
			Economy.use_item("player", g["good"])
	var pay := mini(int(c["reward"]), int(Economy.wallets[VAULT]["coins"]))
	if pay > 0:
		Economy.pay(VAULT, "player", pay)
	world.career.gain(world, int(c["xp"]), c["title"])
	world.sfx("quest")
	Fx.burst(world, world._to3(world.player["pos"]) + Vector3(0, 2.0, 0), [Color(1, 0.85, 0.3), Color(0.95, 0.45, 0.55), Color(0.5, 0.8, 0.95), Color(1, 1, 1)], 50, 6.0)
	var done_text: String = c["done"]
	var unlock: String = c["unlocks"]
	if unlock != "":
		unlocked[unlock] = true
		var tn: Dictionary = world.town_by_id(unlock)
		if not tn.is_empty():
			world.hud.reveal_town(tn)
	world.hud.rip("level", "CHAPTER %d DONE" % (chapter + 1), String(c["title"]), Color(1.0, 0.8, 0.25))
	world.hud.banner(String(c["title"]), "+%d coins from the crown vault" % pay)
	Economy.message.emit("Story: %s complete. +%d coins." % [c["title"], pay])
	chapter += 1
	state = "idle"
	progress = 0
	if chapter >= (data["chapters"] as Array).size():
		finished = true
		plus += 1
		var e: Dictionary = data["ending"]
		world.get_tree().create_timer(2.4).timeout.connect(func() -> void:
			world.hud.rip("boss", String(e["title"]), String(e["sub"]), Color(1.0, 0.82, 0.3))
			world.hud.banner(String(e["title"]), String(e["sub"]))
			Economy.message.emit(String(e["text"])))
		done_text += "\n\n" + String(data["ending"]["text"])
	return done_text


## Short text for the journal tab.
func journal(world) -> Array:
	var lines: Array = []
	var ch: Array = data.get("chapters", [])
	for i in ch.size():
		var mark := "[x] " if i < chapter or finished else ("[>] " if i == chapter else "[ ] ")
		lines.append(mark + String(ch[i]["title"]) + " (" + _cname(ch[i]["city"]) + ")")
	return lines
