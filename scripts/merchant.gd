## A travelling merchant. A townsperson with a real wallet and a cart (a shop
## in Economy with no city, so it never joins the town's own trade) that
## walks the roads between cities: it asks Economy.best_trade for the most
## profitable haul, buys it where it is cheap, walks it to the city where it is
## dear, sells, rests at the caravanserai, repeats. Monsters can frighten it,
## weak ones it fights, strong ones kill it (its coins go to a treasury).
## The player can trade with it like with any shop (E, "Show me your wares").
class_name Merchant
extends Npc

var carry := 6
var min_profit := 3
var rest_secs := 14.0
var phase := "rest"
var trade: Dictionary = {}
var rest_t := 4.0
var cart_id := ""
var route_note := ""
var _said_flee := false
var _fled_to := Vector2.INF
var profit_total := 0


func _init() -> void:
	city = "road"
	job_kind = "merchant"
	job_title = "Merchant"
	wake = 0.0
	bed = 25.0


func cargo() -> Dictionary:
	return Economy.shops[cart_id]["stock"]


## "From -> to" description for the dialog.
func route_text(world) -> String:
	if phase == "to_buy" or phase == "to_sell":
		var f: String = Economy.shops[trade["from"]]["city"]
		var t: String = Economy.shops[trade["to"]]["city"]
		return "%d %s, %s to %s" % [int(trade["qty"]), String(Economy.GOODS[trade["good"]]["name"]).to_lower(), _cname(f), _cname(t)]
	return "resting, deciding where the money is"


func _cname(c: String) -> String:
	return String(Economy.city_def(c).get("name", c))


func update(delta: float, world) -> void:
	atk_cd = maxf(0.0, atk_cd - delta)
	if hp < max_hp:
		hp = minf(max_hp, hp + delta * 0.6)
	inside = false
	# frightened by monsters: weak ones are fought, the rest are outrun to the nearest city
	var threat = world.nearest_monster(pos, 190.0)
	if threat != null:
		var weak: bool = threat.tier == 0 and threat.kind != "boss" and threat.kind != "troll" and hp > max_hp * 0.5
		if weak:
			if pos.distance_to(threat.pos) < 46.0:
				moving = 0.0
				facing = signf(threat.pos.x - pos.x) if absf(threat.pos.x - pos.x) > 12.0 else facing
				if atk_cd <= 0.0:
					atk_cd = 0.9
					world.npc_strike(self, threat, 9.0)
			else:
				_go(threat.pos, delta, world, 40.0)
			return
		if not _said_flee:
			_said_flee = true
			say("%s! My poor cart!" % threat.display_name)
		state = "flee"
		_fled_to = world.nearest_town_pos(pos)
		_go(_fled_to, delta, world, 60.0)
		rest_t = maxf(rest_t, 6.0)
		return
	_said_flee = false
	if state == "flee":
		state = "idle"
		path_reset()

	match phase:
		"rest":
			state = "rest"
			var spot: Vector2 = world.merchant_rest_spot(pos)
			if _go(spot, delta, world, 40.0):
				rest_t -= delta
				if rest_t <= 0.0:
					_plan(world)
		"to_buy":
			state = "work"
			if not Economy.shops.has(trade["from"]):
				phase = "rest"
				return
			if _go(world.door_of(trade["from"]) + Vector2(0, 20), delta, world, 30.0):
				_buy(world)
		"to_sell":
			state = "work"
			if _go(world.door_of(trade["to"]) + Vector2(0, 20), delta, world, 30.0):
				_sell(world)


func path_reset() -> void:
	_path = PackedVector2Array()
	_path_goal = Vector2.INF


func _plan(world) -> void:
	var from_city := ""
	var best := Economy.best_trade(coins(), carry, from_city, min_profit, cart_id)
	if best.is_empty():
		rest_t = 6.0
		say("Nothing worth hauling. Prices are boring.")
		return
	trade = best
	phase = "to_buy"
	var f: String = Economy.shops[best["from"]]["city"]
	var t: String = Economy.shops[best["to"]]["city"]
	var line: String = String(Economy.data["merchants"]["leave"][randi() % Economy.data["merchants"]["leave"].size()])
	say(line % _cname(t))
	route_note = "%s to %s" % [_cname(f), _cname(t)]


func _buy(world) -> void:
	var got := 0
	for i in int(trade["qty"]):
		if Economy.buy(trade["from"], trade["good"], id):
			# the unit goes from the purse items onto the cart
			Economy.use_item(id, trade["good"])
			cargo()[trade["good"]] = int(cargo().get(trade["good"], 0)) + 1
			got += 1
		else:
			break
	if got == 0:
		phase = "rest"
		rest_t = 5.0
		return
	trade["qty"] = got
	phase = "to_sell"
	say("Loaded %d. Off I go." % got)


func _sell(world) -> void:
	var good: String = trade["good"]
	var sold := 0
	var before := coins()
	while int(cargo().get(good, 0)) > 0:
		Economy.add_item(id, good, 1)
		cargo()[good] = int(cargo()[good]) - 1
		if Economy.sell(trade["to"], good, id):
			sold += 1
		else:
			# the shop would not take it: keep it on the cart
			Economy.use_item(id, good)
			cargo()[good] = int(cargo().get(good, 0)) + 1
			break
	var gain := coins() - before
	profit_total += gain
	var arrive: Array = Economy.data["merchants"]["arrive"]
	say(String(arrive[randi() % arrive.size()]) % [_cname(Economy.shops[trade["from"]]["city"]), String(Economy.GOODS[good]["name"]).to_lower()])
	if sold > 0:
		Economy.message.emit("%s sold %d %s in %s for %d coins." % [display_name, sold, String(Economy.GOODS[good]["name"]).to_lower(), _cname(Economy.shops[trade["to"]]["city"]), gain])
	phase = "rest"
	rest_t = rest_secs
	trade = {}
