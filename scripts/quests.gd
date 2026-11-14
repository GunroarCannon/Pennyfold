## Quests posted by the town's shops and treasury. A quest's reward is real
## money: when you accept, the giver moves the coins into the quest board's
## escrow wallet, and the board pays you on completion (or refunds the giver
## if you drop the quest). No coins are created for rewards.
## Kinds: gather (bring goods from the wild to the giver), hunt (defeat
## monsters), visit (reach a landmark), deliver (carry goods to a landmark).
class_name Quests
extends RefCounted

const ESCROW := "board"
const MAX_ACTIVE := 3

var offers: Array = []
var active: Array = []
var completed := 0
var tracked := 0
var _next := 1


static func templates() -> Array:
	return [
		{"giver_kind": "bakery", "kind": "gather", "good": "wheat", "count": 3, "reward": 18, "where": "farm",
			"title": "Wheat for the oven", "desc": "The bakery is short of flour. Cut 3 sheaves of wheat at Sunfield Farm and bring them in."},
		{"giver_kind": "smithy", "kind": "gather", "good": "ore", "count": 3, "reward": 24, "where": "mine",
			"title": "Ore run", "desc": "Chip 3 lumps of ore at the Old Copper Mine for the forge."},
		{"giver_kind": "market", "kind": "gather", "good": "herb", "count": 3, "reward": 15, "where": "wood",
			"title": "Herbs for the shelf", "desc": "Pick 3 herbs in Whisper Wood or by Mirror Lake."},
		{"giver_kind": "lodge", "kind": "hunt", "monster": "wolf", "count": 3, "reward": 20, "where": "wood",
			"title": "Thin the pack", "desc": "Wild %s keep raiding the traps. Take down 3 of them."},
		{"giver_kind": "guard", "kind": "hunt", "monster": "slime", "count": 4, "reward": 16, "where": "lake",
			"title": "Sticky trouble", "desc": "%s are oozing onto the roads. Clear 4."},
		{"giver_kind": "guard", "kind": "hunt", "monster": "boss", "count": 1, "reward": 60, "where": "ruins",
			"title": "Topple the ruin lord", "desc": "The %s rules Thorn Ruins. End its reign."},
		{"giver_kind": "tavern", "kind": "deliver", "good": "ale", "count": 2, "reward": 14, "where": "farm",
			"title": "Thirsty farmhands", "desc": "Carry 2 ales out to Sunfield Farm. Buy them at the tavern if you have none."},
		{"giver_kind": "guard", "kind": "visit", "reward": 10, "where": "lookout",
			"title": "Eyes on the hills", "desc": "Climb Lookout Hill and check the land."},
		{"giver_kind": "lodge", "kind": "hunt", "monster": "bat", "count": 3, "reward": 22, "where": "mine",
			"title": "Things in the dark", "desc": "%s nest near the mine. Drive off 3."},
	]


## Keeps a few funded offers on the board. world: Main.
func refresh(world) -> void:
	offers = offers.filter(func(q): return _funded(world, q))
	var tries := 0
	while offers.size() < 4 and tries < 20:
		tries += 1
		var t: Dictionary = templates()[world.rng.randi() % templates().size()]
		if _has(t["title"]):
			continue
		var giver: String = world._shop_of_kind(t["giver_kind"]) if t["giver_kind"] != "guard" else world._guard_post_id()
		if giver == "" or not Economy.wallets.has(giver):
			continue
		var q: Dictionary = t.duplicate()
		q["id"] = _next
		_next += 1
		q["giver"] = giver
		q["giver_name"] = world.building(giver).get("name", "Town")
		q["progress"] = 0
		q["count"] = int(q.get("count", 1))
		q["where_name"] = world.world.landmark(q["where"]).get("name", "")
		if q.has("monster"):
			q["desc"] = String(q["desc"]) % world.monster_name(q["monster"], true)
		if _funded(world, q):
			offers.append(q)


func _has(title: String) -> bool:
	for q in offers + active:
		if q["title"] == title:
			return true
	return false


func _funded(world, q: Dictionary) -> bool:
	return Economy.wallets.has(q["giver"]) and int(Economy.wallets[q["giver"]]["coins"]) >= int(q["reward"]) + 10


## Moves the reward into escrow. Returns false if the giver cannot pay.
func accept(world, q: Dictionary) -> bool:
	if active.size() >= MAX_ACTIVE or not _funded(world, q):
		return false
	if not Economy.pay(q["giver"], ESCROW, int(q["reward"])):
		return false
	offers.erase(q)
	active.append(q)
	tracked = active.size() - 1
	Economy.message.emit("Quest taken: %s. %d coins held in escrow by the quest board." % [q["title"], int(q["reward"])])
	return true


func abandon(q: Dictionary) -> void:
	if not active.has(q):
		return
	Economy.pay(ESCROW, q["giver"], int(q["reward"]))
	active.erase(q)
	tracked = clampi(tracked, 0, maxi(0, active.size() - 1))
	Economy.message.emit("Quest dropped: %s. The reward went back to the %s." % [q["title"], q["giver_name"]])


func current() -> Dictionary:
	if active.is_empty():
		return {}
	return active[clampi(tracked, 0, active.size() - 1)]


func cycle() -> void:
	if not active.is_empty():
		tracked = (tracked + 1) % active.size()


func _finish(world, q: Dictionary) -> void:
	Economy.pay(ESCROW, "player", int(q["reward"]))
	active.erase(q)
	tracked = clampi(tracked, 0, maxi(0, active.size() - 1))
	completed += 1
	Economy.message.emit("Quest complete: %s. +%d coins from escrow." % [q["title"], int(q["reward"])])
	world.quest_done(q)


func on_kill(world, kind: String) -> void:
	for q in active.duplicate():
		if q["kind"] == "hunt" and q["monster"] == kind:
			q["progress"] = int(q["progress"]) + 1
			if int(q["progress"]) >= int(q["count"]):
				_finish(world, q)


func on_visit(world, landmark_id: String) -> void:
	for q in active.duplicate():
		if q["where"] != landmark_id:
			continue
		if q["kind"] == "visit":
			q["progress"] = 1
			_finish(world, q)
		elif q["kind"] == "deliver" and _held(q) >= int(q["count"]):
			for i in int(q["count"]):
				Economy.use_item("player", q["good"])
			q["progress"] = q["count"]
			_finish(world, q)


## Called when the player presses E at a shop door. Returns true if a quest
## was handed in there.
func hand_in(world, shop_id: String) -> bool:
	for q in active.duplicate():
		if q["kind"] == "gather" and q["giver"] == shop_id and _held(q) >= int(q["count"]):
			var s: Dictionary = Economy.shops.get(shop_id, {})
			for i in int(q["count"]):
				if Economy.use_item("player", q["good"]) and not s.is_empty():
					s["stock"][q["good"]] = int(s["stock"].get(q["good"], 0)) + 1
			q["progress"] = q["count"]
			_finish(world, q)
			return true
	return false


func _held(q: Dictionary) -> int:
	return int(Economy.wallets["player"]["items"].get(q.get("good", ""), 0))


func progress_text(q: Dictionary) -> String:
	match String(q["kind"]):
		"gather":
			var n := mini(_held(q), int(q["count"]))
			if n >= int(q["count"]):
				return "Bring them to the %s" % q["giver_name"]
			return "%s: %d / %d" % [Economy.GOODS[q["good"]]["name"], n, int(q["count"])]
		"hunt":
			return "Defeated %d / %d" % [int(q["progress"]), int(q["count"])]
		"deliver":
			var n2 := mini(_held(q), int(q["count"]))
			if n2 >= int(q["count"]):
				return "Carry them to %s" % q["where_name"] if q.has("where_name") else "Carry them out"
			return "%s in pack: %d / %d" % [Economy.GOODS[q["good"]]["name"], n2, int(q["count"])]
		_:
			return "Reach the spot"


## Where the quest pointer should aim, in pixels.
func target_of(world, q: Dictionary) -> Vector2:
	var lm: Vector2 = world.world.landmark(q["where"])["pos"]
	match String(q["kind"]):
		"gather":
			if _held(q) >= int(q["count"]):
				return world.door_of(q["giver"])
			return lm
		"hunt":
			var m = world.nearest_monster_of(q["monster"], world.player["pos"], 1400.0)
			return m.pos if m != null else lm
		"deliver":
			if _held(q) < int(q["count"]):
				var shop: String = world.nearest_shop_with(world.player["pos"], q["good"])
				if shop != "":
					return world.door_of(shop)
			return lm
		_:
			return lm
