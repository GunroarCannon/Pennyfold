## The player's career: level and XP, one job at a time (apply, work a shift,
## get paid by the employer's real wallet, get fired or quit), and the grudges
## townsfolk hold. Numbers live in data/careers.json. Owned by Main, like
## Quests; the HUD reads it.
class_name Career
extends RefCounted

const PATH := "res://data/careers.json"

var data: Dictionary = {}
var level := 1
var xp := 0
var total_xp := 0
var kills := 0
## {"place", "kind", "city", "since", "shift_t", "missed", "shifts", "unpaid", "grace_day", "assaults"} or {} when unemployed.
var job: Dictionary = {}
## Average price paid per good, so selling above it counts as trading profit.
var basis: Dictionary = {}
## shop id -> last day it still refuses to deal with the player
var grudges: Dictionary = {}
var history: Array = []


func _init() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			data = d
	if data.is_empty():
		push_error("Career: could not read %s" % PATH)


func _x(key: String, fallback: float) -> float:
	return float(data.get("xp", {}).get(key, fallback))


# ---------------- levels ----------------

func needed(lv: int = -1) -> int:
	if lv < 0:
		lv = level
	return int(_x("base", 40.0) * pow(_x("growth", 1.38), lv - 1))


func max_level() -> int:
	return int(_x("max_level", 25.0))


func hp_for(lv: int) -> float:
	return 100.0 + _x("hp_per_level", 12.0) * (lv - 1)


func stamina_for(lv: int) -> float:
	return 100.0 + _x("stamina_per_level", 6.0) * (lv - 1)


func ink_for(lv: int) -> float:
	return 100.0 + _x("ink_per_level", 4.0) * (lv - 1)


var skills: Skills = null


func damage_mult() -> float:
	var m := 1.0 + _x("dmg_per_level", 0.07) * (level - 1) + 0.04 * (Game.stat("might") - 1)
	if skills != null:
		m += skills.bonus("dmg")
	return m


## Applies the level's stats to the player dictionary.
func apply_stats(world, heal := false) -> void:
	var p: Dictionary = world.player
	var sb: Skills = skills
	p["max_hp"] = hp_for(level) + 10.0 * (Game.stat("vigor") - 1) + (sb.bonus("hp") if sb != null else 0.0)
	p["max_stamina"] = stamina_for(level) + 6.0 * (Game.stat("swift") - 1)
	p["max_ink"] = ink_for(level) + 8.0 * (Game.stat("spirit") - 1) + (sb.bonus("ink") if sb != null else 0.0)
	if heal:
		p["hp"] = p["max_hp"]
		p["stamina"] = p["max_stamina"]
		p["ink"] = p["max_ink"]


func gain(world, amount: int, why := "") -> void:
	if amount <= 0 or level >= max_level():
		return
	xp += amount
	total_xp += amount
	world._pop_number(world._to3(world.player["pos"]) + Vector3(0.5, 2.2, 0), "+%d XP" % amount, Color(0.62, 0.9, 1.0))
	var up := 0
	while level < max_level() and xp >= needed():
		xp -= needed()
		level += 1
		up += 1
		if skills != null:
			skills.grant(int(skills.data.get("points_per_level", 1)))
	if up > 0:
		apply_stats(world, true)
		world.sfx("levelup")
		world.get_tree().create_timer(0.18).timeout.connect(func() -> void: world.sfx("heal", -3.0))
		Fx.ring(world, world._to3(world.player["pos"]), Color(1.0, 0.85, 0.3), 5.0)
		Fx.burst(world, world._to3(world.player["pos"]) + Vector3(0, 2.0, 0), [Color(1, 0.85, 0.3), Color(0.5, 0.85, 1.0), Color(1, 1, 1)], 50, 6.0)
		world.hud.rip("level", "LEVEL UP!", "Level %d" % level, Color(1.0, 0.62, 0.15))
		world.hud.banner("Level %d" % level, "A skill point to spend. Press T for the skill tree.")
		Economy.message.emit("Level up! You are level %d (%s)." % [level, why if why != "" else "well done"])


func kill_xp(kind: String, tier: int) -> int:
	var base := float(data.get("kills", {}).get(kind, maxf(6.0, float(Monster.TYPES[kind]["hp"]) / 7.0)))
	return int(round(base * (1.0 + tier * 0.6)))


func on_kill(world, m) -> void:
	kills += 1
	gain(world, kill_xp(m.kind, m.tier), "a %s fell" % m.display_name)
	# guards are paid a bounty from the city treasury for every beast
	if not job.is_empty() and job["kind"] == "guard" and world.in_defense_zone(m.pos):
		var bounty := int(data["jobs"]["guard"].get("bounty", 15))
		var tre: String = world._guard_post_id(job["city"])
		if tre != "player" and Economy.pay(tre, "player", bounty):
			Economy.message.emit("Guard bounty: %d coins from the %s treasury." % [bounty, world.building(tre)["name"]])
		else:
			Economy.message.emit("The treasury cannot pay your bounty today.")


func on_quest(world, q: Dictionary) -> void:
	gain(world, int(round(float(q["reward"]) * _x("quest", 0.8))), "quest done")


## Called for every player purchase / sale at a shop.
func on_trade(world, good: String, price: int, buying: bool) -> void:
	if buying:
		var held := int(Economy.wallets["player"]["items"].get(good, 0))
		var old := float(basis.get(good, price))
		basis[good] = (old * maxf(0.0, held - 1.0) + price) / maxf(1.0, held)
	else:
		var profit := price - int(round(float(basis.get(good, price))))
		if profit > 0:
			gain(world, maxi(1, int(round(profit * _x("trade_profit", 0.5)))), "trading profit")


# ---------------- jobs ----------------

func job_def(kind: String) -> Dictionary:
	return data.get("jobs", {}).get(kind, {})


func has_job() -> bool:
	return not job.is_empty()


func rank() -> int:
	if job.is_empty():
		return 0
	var f: Dictionary = data["fire"]
	return mini(int(f["max_rank"]), int(job["shifts"]) / int(f["raise_every"]))


func wage() -> int:
	if job.is_empty():
		return 0
	return int(job_def(job["kind"])["wage"]) + rank() * int(data["fire"]["raise"])


## Requirement lines for a job kind: [{text, ok}].
func requirements(world, kind: String) -> Array:
	var d := job_def(kind)
	var out: Array = []
	out.append({"text": "Level %d (you are %d)" % [int(d["min_level"]), level], "ok": level >= int(d["min_level"])})
	if int(d["quests"]) > 0:
		out.append({"text": "%d quest%s done (you did %d)" % [int(d["quests"]), "" if int(d["quests"]) == 1 else "s", world.quests.completed], "ok": world.quests.completed >= int(d["quests"])})
	if int(d["kills"]) > 0:
		out.append({"text": "%d beasts beaten (you beat %d)" % [int(d["kills"]), kills], "ok": kills >= int(d["kills"])})
	return out


func eligible(world, kind: String) -> bool:
	for r in requirements(world, kind):
		if not r["ok"]:
			return false
	return true


func requirement_text(world, kind: String) -> String:
	var parts: PackedStringArray = []
	for r in requirements(world, kind):
		parts.append(("[x] " if r["ok"] else "[ ] ") + String(r["text"]))
	return "\n".join(parts)


func offer_text(world, place: String) -> String:
	var b: Dictionary = world.building(place)
	var d := job_def(b["kind"])
	return "%s at the %s: %d coins a day, %d:00 to %d:00, paid by the %s from its real till.\n%s\n\nRequirements:\n%s" % [
		d["role"], b["name"], int(d["wage"]), int(d["shift"][0]), int(d["shift"][1]), b["name"], d["text"], requirement_text(world, b["kind"])]


## Returns "" on success, else the reason.
func apply(world, place: String) -> String:
	var b: Dictionary = world.building(place)
	if b.is_empty() or job_def(b["kind"]).is_empty():
		return "They are not hiring."
	if not job.is_empty():
		return "You already work at the %s. Quit first." % world.building(job["place"])["name"]
	if is_banned(world, place):
		return "They have not forgiven you yet."
	if not eligible(world, b["kind"]):
		return "You do not meet the requirements yet."
	job = {"place": place, "kind": b["kind"], "city": b["city"], "since": world.day_number(), "shift_t": 0.0, "missed": 0, "shifts": 0, "unpaid": 0, "grace_day": world.day_number(), "assaults": 0}
	var d := job_def(b["kind"])
	Economy.message.emit("Hired as %s at the %s. Shift %d:00 to %d:00 near the door." % [d["role"], b["name"], int(d["shift"][0]), int(d["shift"][1])])
	world.sfx("quest")
	world.hud.banner("New job", "%s, %s" % [d["role"], b["name"]])
	return ""


func quit(world) -> void:
	if job.is_empty():
		return
	var b: Dictionary = world.building(job["place"])
	Economy.message.emit("You quit your job at the %s. No hard feelings, mostly." % b["name"])
	history.append({"place": job["place"], "why": "quit", "day": world.day_number()})
	job = {}


func fire(world, why: String) -> void:
	if job.is_empty():
		return
	var b: Dictionary = world.building(job["place"])
	var role: String = String(job_def(job["kind"])["role"])
	history.append({"place": job["place"], "why": why, "day": world.day_number()})
	grudges[job["place"]] = world.day_number() + int(data["fire"]["grudge_days"])
	job = {}
	world.sfx("hurt")
	world.hud.rip("death", "FIRED", "Fired as %s" % role.to_lower(), Color(0.85, 0.3, 0.25))
	world.hud.banner("You are fired", "%s at the %s: %s" % [role, b["name"], why])
	Economy.message.emit("You were fired from the %s for %s." % [b["name"], why])


func is_banned(world, place: String) -> bool:
	return int(grudges.get(place, -1)) >= world.day_number()


## True when a shop will not deal with the player today.
func refuses(world, shop: String) -> bool:
	return is_banned(world, shop)


# ---------------- shifts ----------------

func on_shift(world) -> bool:
	if job.is_empty():
		return false
	var s: Array = job_def(job["kind"])["shift"]
	return world.hour >= float(s[0]) and world.hour < float(s[1])


func at_work(world) -> bool:
	if job.is_empty():
		return false
	return Vector2(world.player["pos"]).distance_to(world.door_of(job["place"])) < 230.0


func update(world, delta: float) -> void:
	if job.is_empty():
		return
	if on_shift(world) and at_work(world):
		var before := float(job["shift_t"])
		job["shift_t"] = before + delta
		if int(before / 12.5) != int(float(job["shift_t"]) / 12.5):
			world._pop_number(world._to3(world.player["pos"]) + Vector3(0, 2.0, 0), "working", Color(0.85, 0.8, 0.6))


func status_text(world) -> String:
	if job.is_empty():
		return ""
	var d := job_def(job["kind"])
	var s: Array = d["shift"]
	var len_h := float(s[1]) - float(s[0])
	var need := len_h * float(d["need"]) * 12.5
	var pct := int(clampf(float(job["shift_t"]) / maxf(need, 1.0), 0.0, 1.0) * 100.0)
	if on_shift(world):
		return "%s: on shift (%d%%)%s" % [d["role"], pct, "" if at_work(world) else " - get back to the door!"]
	return "%s: shift %d:00-%d:00 (%d coins)" % [d["role"], int(s[0]), int(s[1]), wage()]


## Evening: judge the day's shift, pay or warn or fire.
func payday(world) -> void:
	if job.is_empty():
		return
	var place: String = job["place"]
	var b: Dictionary = world.building(place)
	var d := job_def(job["kind"])
	var s: Array = d["shift"]
	var need := (float(s[1]) - float(s[0])) * float(d["need"]) * 12.5
	if int(job["grace_day"]) == world.day_number():
		# hired today: the first shift is tomorrow
		job["shift_t"] = 0.0
		return
	if float(job["shift_t"]) >= need:
		job["missed"] = 0
		job["shifts"] = int(job["shifts"]) + 1
		var w := wage()
		if Economy.wallets.has(place) and Economy.pay(place, "player", w):
			job["unpaid"] = 0
			Economy.message.emit("Payday: the %s paid you %d coins." % [b["name"], w])
		else:
			job["unpaid"] = int(job["unpaid"]) + 1
			Economy.message.emit("The %s's till is too empty to pay you today. You can quit if this goes on." % b["name"])
		gain(world, int(_x("shift", 6.0)) + rank(), "a full shift")
		if int(job["shifts"]) % int(data["fire"]["raise_every"]) == 0 and rank() > 0:
			Economy.message.emit("The %s gave you a raise: %d coins a day." % [b["name"], wage()])
	else:
		job["missed"] = int(job["missed"]) + 1
		var lim := int(data["fire"]["missed_limit"])
		if int(job["missed"]) >= lim:
			fire(world, "missing shifts")
		else:
			Economy.message.emit("You missed today's shift at the %s. Miss %d more and you are fired." % [b["name"], lim - int(job["missed"])])
	if not job.is_empty():
		job["shift_t"] = 0.0


func new_day() -> void:
	if not job.is_empty():
		job["shift_t"] = 0.0


## The player struck a townsperson. Hitting a colleague (or, as a guard, any
## townsperson of your city) loses the job at once; a second hit on anyone does too.
func on_assault(world, n: Npc) -> void:
	# the victim's shop remembers it
	var shop := n.job_id
	if shop != "":
		grudges[shop] = world.day_number() + int(data["fire"]["grudge_days"])
		n.say("I will not forget that.")
	if job.is_empty():
		return
	job["assaults"] = int(job["assaults"]) + 1
	var colleague: bool = n.job_id == job["place"] or (job["kind"] == "guard" and n.city == job["city"])
	if colleague:
		fire(world, "attacking staff")
	elif int(job["assaults"]) >= int(data["fire"]["assault_limit"]):
		fire(world, "striking townsfolk")
	else:
		Economy.message.emit("Careful: hit another townsperson and you lose your job.")
