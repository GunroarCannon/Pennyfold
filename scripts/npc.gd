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


func update(delta: float, world) -> void:
	hunger = minf(100.0, hunger + delta * 0.4)
	eat_cd = maxf(0.0, eat_cd - delta)
	fun_cd = maxf(0.0, fun_cd - delta)
	atk_cd = maxf(0.0, atk_cd - delta)
	if hunger >= 100.0:
		hp -= delta * 0.8
		if randf() < delta * 0.05:
			say("So hungry...")
	elif hp < max_hp:
		hp = minf(max_hp, hp + delta * (2.5 if inside else 0.8))
	var hour: float = world.hour
	var awake: bool = hour >= wake and hour < bed

	# 1. flee (everyone but guards)
	if job_kind != "guard":
		var threat = world.nearest_monster(pos, 170.0)
		if threat != null:
			if state != "flee":
				say("%s! Run!" % threat.display_name)
			state = "flee"
			scare = 4.0
		if state == "flee":
			if threat == null:
				scare -= delta
			if _go(world.door_of(home_id), delta, world, 12.0):
				inside = true
			if scare <= 0.0:
				state = "idle"
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
	pos = world.try_move(pos, dir * SPEED * delta, 8.0)
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
