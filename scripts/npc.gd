## A townsperson. Needs: hunger and hp. Has a home, a wallet (Economy, keyed
## by id), a job or a daily day-labour job, and a schedule. Each frame it
## picks one goal in priority order: flee, guard (guards only), eat, sleep,
## work, an evening ale, stroll. Movement follows A* paths on the town grid.
class_name Npc
extends RefCounted

const SPEED := 70.0
const ATE := ["That hits the spot.", "Back to it.", "Fresh, for once."]

var id := ""
var display_name := ""
var home_id := ""
## City id ("sunny", "copperhead"...), or "road" for a travelling merchant.
var city := "sunny"
var job_id := ""
var job_kind := ""
var job_title := "Resident"
var day_job := ""
var lead_to := ""
## A small errand in the leisure hours: "clean", "herbs", "hunt" or "mayor".
var errand := ""
var errand_pts: Array = []
var errand_i := 0
var errand_wait := 0.0
var errand_cd := 20.0
var lead_t := 0.0
var pos := Vector2.ZERO
var hunger := 20.0
var hp := 40.0
var max_hp := 40.0
var state := "idle"
var shop_target := ""
var shop_good := ""
var wander_target := Vector2.ZERO
var wait := 0.0
var eat_cd := 0.0
var fun_cd := 0.0
var atk_cd := 0.0
var scare := 0.0
var moving := 0.0
var facing := 1.0
var inside := false
var worked_today := false
var speech := ""
var wake := 6.0
var bed := 21.0
var work_start := 7.5
var work_end := 17.0
var last_hurt_by := ""
var view: Standee

var _path := PackedVector2Array()
var _path_i := 0
var _path_goal := Vector2.INF
var _stuck := 0.0
var _stuck_total := 0.0
var _side_t := 0.0
var _side_sign := 1.0


func say(text: String) -> void:
	speech = text


func coins() -> int:
	return int(Economy.wallets[id]["coins"])


var run := 1.0


## A steady one in five of the townsfolk is brave enough to fight.
func is_hero() -> bool:
	return job_kind != "guard" and not (self is Merchant) and absi(id.hash()) % 5 == 0


func update(delta: float, world) -> void:
	hunger = minf(100.0, hunger + delta * 0.3)
	eat_cd = maxf(0.0, eat_cd - delta)
	fun_cd = maxf(0.0, fun_cd - delta)
	atk_cd = maxf(0.0, atk_cd - delta)
	if hunger >= 100.0:
		hp -= delta * 0.35
		if randf() < delta * 0.05:
			say("So hungry...")
	elif hp < max_hp:
		hp = minf(max_hp, hp + delta * (2.5 if inside else 0.8))
	var hour: float = world.hour
	var awake: bool = hour >= wake and hour < bed

	# 0. heroes: about one townsperson in five stands and fights a beast that
	# comes into town, and is paid a bounty from the treasury if it falls
	if is_hero() and hp >= max_hp * 0.4 and awake:
		var foe = world.nearest_monster(pos, 240.0)
		if foe != null and world.in_defense_zone(foe.pos) and not Monster.is_big(foe.kind):
			inside = false
			if state != "fight":
				say("Not in my town!")
			state = "fight"
			if pos.distance_to(foe.pos) < 46.0:
				moving = 0.0
				if absf(foe.pos.x - pos.x) > 12.0:
					facing = signf(foe.pos.x - pos.x)
				if atk_cd <= 0.0:
					atk_cd = 0.9
					world.npc_strike(self, foe, 7.0)
			else:
				_go(foe.pos, delta, world, 40.0)
			return
		if state == "fight":
			state = "idle"

	# 1. flee (everyone but guards, and heroes while they are healthy)
	if job_kind != "guard" and not (is_hero() and hp >= max_hp * 0.4):
		var threat = world.nearest_monster(pos, 170.0)
		if threat != null:
			if state != "flee":
				say("%s! Run!" % threat.display_name)
			state = "flee"
			scare = 4.0
		if state == "flee":
			if threat == null:
				scare -= delta
			# run for home if that is away from the monster, otherwise straight
			# away from it, and faster than a stroll
			var hd: Vector2 = world.door_of(home_id)
			var dest := hd
			if threat != null and hd.distance_to(threat.pos) < pos.distance_to(threat.pos) + 20.0:
				var away: Vector2 = (pos - threat.pos).normalized()
				dest = pos + away * 220.0
				if not world.walkable(dest):
					dest = pos + away.rotated(1.2) * 220.0
				if not world.walkable(dest):
					dest = hd
			run = 1.7
			var arrived: bool = _go(dest, delta, world, 12.0)
			run = 1.0
			if arrived and dest == hd:
				inside = true
			if scare <= 0.0:
				state = "idle"
			return

	# 1b. leading the player to the shop door, then letting them in
	if state == "lead":
		lead_t += delta
		if Vector2(world.player["pos"]).distance_to(pos) > 280.0 and lead_t < 60.0:
			moving = 0.0
			return
		if lead_t > 60.0:
			state = "idle"
		elif _go(world.door_of(lead_to), delta, world, 26.0):
			state = "idle"
			wait = 3.0
			say("Here is my store.")
			world.lead_arrived(self, lead_to)
			return
		else:
			if randf() < delta * 0.12:
				say("This way...")
			return

	# 2. guard duty: defend the town edge, fall back when badly hurt
	if job_kind == "guard" and awake:
		if hp < max_hp * 0.3 or state == "recover":
			state = "recover" if hp < max_hp * 0.8 else "idle"
			if state == "recover":
				if _go(world.door_of(job_id), delta, world, 12.0):
					inside = true
				return
		var mon = world.nearest_monster(pos, 300.0)
		if mon != null and world.in_defense_zone(mon.pos):
			inside = false
			state = "fight"
			if pos.distance_to(mon.pos) < 46.0:
				moving = 0.0
				if absf(mon.pos.x - pos.x) > 12.0:
					facing = signf(mon.pos.x - pos.x)
				if atk_cd <= 0.0:
					atk_cd = 0.75
					world.npc_strike(self, mon, 12.0)
			else:
				_go(mon.pos, delta, world, 40.0)
			return
		if state == "fight":
			state = "idle"

	# 3. eat: bread or meat, wherever is closest
	if state != "eat" and hunger >= 55.0 and eat_cd <= 0.0:
		var food: Array = world.nearest_food(pos)
		if food.size() == 2:
			state = "eat"
			shop_target = food[0]
			shop_good = food[1]
			inside = false
		else:
			eat_cd = 15.0
			say("No food anywhere in town.")
	if state == "eat":
		if _go(world.door_of(shop_target), delta, world, 20.0):
			if Economy.buy(shop_target, shop_good, id):
				Economy.use_item(id, shop_good)
				hunger = 0.0
				say(ATE[randi() % ATE.size()])
			elif world.food_relief(self, shop_target, shop_good) and Economy.buy(shop_target, shop_good, id):
				Economy.use_item(id, shop_good)
				hunger = 0.0
				say("The town purse bought my supper.")
			else:
				say("I cannot afford food.")
			eat_cd = 20.0
			state = "idle"
			wait = 2.0
		return

	# 4. sleep
	if not awake:
		state = "home"
		if _go(world.door_of(home_id), delta, world, 12.0):
			inside = true
		return
	inside = false

	# 5. work (residents find a day job at the richest shop)
	if hour >= work_start and hour < work_end:
		var place := job_id
		if place == "":
			if day_job == "":
				day_job = world.richest_employer(city)
				if day_job != "":
					say("Looking for a day's work at the %s." % world.building(day_job)["name"])
			place = day_job
		if place != "":
			state = "work"
			if _go(world.door_of(place) + Vector2(-26.0, 8.0), delta, world, 10.0):
				worked_today = true
			return

	# 6. evening ale, if there is money to spare
	if state == "drink":
		if _go(world.door_of(shop_target), delta, world, 20.0):
			if Economy.buy(shop_target, "ale", id):
				Economy.use_item(id, "ale")
				say("Cheers.")
			state = "idle"
			wait = 4.0
		return
	if hour >= 17.0 and fun_cd <= 0.0 and coins() >= 18 and hunger < 50.0:
		fun_cd = 60.0
		var tavern: String = world.shop_with("ale", city)
		if tavern != "" and randf() < 0.5:
			state = "drink"
			shop_target = tavern
			return

	# 7a. errands: sweep the doorways, forage, hunt, or (the mayor) do the rounds
	errand_cd = maxf(0.0, errand_cd - delta)
	if errand != "":
		if _do_errand(delta, world):
			return
	elif errand_cd <= 0.0 and hunger < 60.0:
		errand_cd = randf_range(50.0, 110.0)
		if randf() < 0.55:
			_start_errand(world)

	# 7. stroll along the roads, pause, stroll on
	if state != "idle":
		state = "idle"
		wait = 0.0
		wander_target = pos
	if wait > 0.0:
		wait -= delta
		moving = 0.0
		return
	if _go(wander_target, delta, world, 10.0):
		wait = randf_range(3.0, 8.0)
		wander_target = world.random_road_point(city)


## Walks along an A* path. Returns true when within `arrive` of dest.
## Townsfolk steer around each other (so two people heading for the same door
## slide past instead of shoving head-on), accept a looser arrival when the
## door is crowded, and sidestep at random when they get stuck.
func _go(dest: Vector2, delta: float, world, arrive: float) -> bool:
	var crowd: int = world.npc_neighbors(dest, 34.0, self).size()
	if pos.distance_to(dest) <= arrive + 9.0 * minf(float(crowd), 3.0):
		moving = 0.0
		_stuck_total = 0.0
		return true
	if _path_goal.distance_to(dest) > 20.0 or _stuck > 1.2:
		_path = world.find_path(pos, dest)
		_path_i = 0
		_path_goal = dest
		if _stuck > 1.2:
			_side_t = randf_range(0.4, 0.9)
			_side_sign = 1.0 if randf() < 0.5 else -1.0
		_stuck = 0.0
	while _path_i < _path.size() and pos.distance_to(_path[_path_i]) < 14.0:
		_path_i += 1
	var wp := dest
	if _path_i < _path.size():
		wp = _path[_path_i]
	var dir := (wp - pos).normalized()
	var avoid := Vector2.ZERO
	for o in world.npc_neighbors(pos, 36.0, self):
		var d: Vector2 = pos - o.pos
		var l := maxf(d.length(), 0.1)
		avoid += d / l * (36.0 - l) / 36.0
	if avoid != Vector2.ZERO:
		# push away, plus a nudge to the right so head-on pairs pass each other
		dir = (dir + avoid * 1.5 + Vector2(-dir.y, dir.x) * minf(avoid.length(), 1.0) * 0.8).normalized()
	if _side_t > 0.0:
		_side_t -= delta
		dir = (dir + Vector2(-dir.y, dir.x) * _side_sign * 0.9).normalized()
	var before := pos
	pos = world.try_move(pos, dir * SPEED * run * delta, 8.0)
	moving = 1.0
	if absf(dir.x) > 0.45:
		facing = signf(dir.x)
	if pos.distance_to(before) < SPEED * delta * 0.2:
		_stuck += delta
		_stuck_total += delta
		if _stuck_total > 3.0:
			# Last resort: hop to the next waypoint so nobody freezes forever.
			pos = wp if world.walkable(wp) else world.door_of(home_id)
			_stuck_total = 0.0
	else:
		_stuck = 0.0
		_stuck_total = maxf(0.0, _stuck_total - delta)
	return false


const CLEAN_LINES := ["Sweeping up.", "Dust everywhere.", "Somebody tracked mud in.", "Swept. Again."]
const HERB_LINES := ["Sage, and a bit of thyme.", "Found a good patch.", "Mind the nettles.", "Look at this one."]
const HUNT_LINES := ["Quiet. Too quiet.", "Tracks. Fresh ones.", "Nothing yet.", "Something moved."]
const MAYOR_LINES := ["Nobody voted for the pothole.", "The board looks full. Good.", "Order, order.", "A tidy town is a paid-up town."]


func _start_errand(world) -> void:
	var kinds: Array = ["clean", "clean", "herbs", "hunt"]
	if job_title == "Mayor":
		kinds = ["mayor", "mayor", "clean"]
	elif job_id != "":
		kinds = ["clean"]
	errand = kinds[randi() % kinds.size()]
	errand_pts = world.errand_points(self, errand)
	errand_i = 0
	errand_wait = 0.0
	if errand_pts.is_empty():
		errand = ""
		return
	match errand:
		"herbs":
			say("Off to pick herbs.")
		"hunt":
			say("Off to hunt for supper.")
		"mayor":
			say("Time for my rounds.")
		_:
			say("Time to tidy up.")


## Walks the errand's points one after another. True while it is still going.
func _do_errand(delta: float, world) -> bool:
	if errand_i >= errand_pts.size():
		errand = ""
		state = "idle"
		wait = 2.0
		return false
	state = "errand"
	var dest: Vector2 = errand_pts[errand_i]
	if errand_wait > 0.0:
		errand_wait -= delta
		moving = 0.0
		if errand_wait <= 0.0:
			errand_i += 1
		return true
	if _go(dest, delta, world, 22.0):
		errand_wait = randf_range(2.0, 4.0)
		var lines: Array = CLEAN_LINES
		match errand:
			"herbs":
				lines = HERB_LINES
			"hunt":
				lines = HUNT_LINES
			"mayor":
				lines = MAYOR_LINES
		if errand_i < errand_pts.size() - 1 or errand == "clean":
			say(lines[randi() % lines.size()])
		elif errand == "herbs":
			say("Home with a basketful.")
		elif errand == "hunt":
			say("Nothing today. Tomorrow.")
	return true
