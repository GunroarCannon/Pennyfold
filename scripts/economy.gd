## Autoload "Economy". Every coin and every item lives in a wallet, so coins
## are conserved: they move between wallets but never appear from nothing.
## Goods are produced by shop recipes; prices follow stock levels, and random
## events (see data/economy_data.json) nudge them. All numbers, goods, buildings
## and events live in that JSON file, so tuning the economy never needs code.
extends Node

signal changed
signal message(text: String)
## Every coin movement, for the on-chain settlement (see chain.gd).
signal transferred(from_id: String, to_id: String, amount: int, memo: String)

const DATA_PATH := "res://data/economy_data.json"

## The whole data file, as loaded.
var data: Dictionary = {}
## good_id -> {name, base, target}
var GOODS: Dictionary = {}
var STOCK_CAP := 12
var _elasticity := 0.8
var _pmin := 0.35
var _pmax := 3.0
var _ask := 1.25
var _bid := 0.8

## shop_id -> {name, kind, city, recipe, stock, buys}
var shops: Dictionary = {}
## wallet_id -> {coins, items}
var wallets: Dictionary = {}
## Running events: {id, name, city, until, goods, text}
var active_events: Array = []


func _ready() -> void:
	load_data()


func load_data() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_error("economy_data.json missing")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("economy_data.json is not valid JSON")
		return
	data = parsed
	GOODS = data["goods"]
	var p: Dictionary = data.get("price", {})
	_elasticity = float(p.get("elasticity", 0.8))
	_pmin = float(p.get("min", 0.35))
	_pmax = float(p.get("max", 3.0))
	_ask = float(p.get("ask_margin", 1.25))
	_bid = float(p.get("bid_margin", 0.8))
	STOCK_CAP = int(p.get("stock_cap", 12))


func reset() -> void:
	shops.clear()
	wallets.clear()
	active_events.clear()


## One building kind, as the data file describes it (name, recipe, stock...).
func building(kind: String) -> Dictionary:
	return data["buildings"].get(kind, {})


func city_def(city: String) -> Dictionary:
	return data["cities"].get(city, {})


func add_wallet(id: String, coins: int) -> void:
	wallets[id] = {"coins": coins, "items": {}}


## `buys` may be the string "*" (any good) or a list of good ids.
func add_shop(id: String, shop_name: String, recipe: Dictionary, stock: Dictionary, buys: Variant, coins: int, city := "", kind := "") -> void:
	var list: Array = []
	if typeof(buys) == TYPE_STRING and buys == "*":
		list = GOODS.keys()
	else:
		list = (buys as Array).duplicate()
	shops[id] = {
		"name": shop_name,
		"kind": kind,
		"city": city,
		"recipe": recipe.duplicate(true),
		"stock": stock.duplicate(),
		"buys": list,
	}
	add_wallet(id, coins)


func price_factor(good: String, qty: int, city := "") -> float:
	var target: float = float(GOODS[good]["target"])
	var f := clampf(pow((target + 1.0) / (float(qty) + 1.0), _elasticity), _pmin, _pmax)
	return f * event_mult(good, city)


## Product of the active event multipliers on a good in a city ("" = anywhere).
func event_mult(good: String, city: String) -> float:
	var m := 1.0
	for e in active_events:
		if e["city"] != "" and e["city"] != city:
			continue
		m *= float(e["goods"].get(good, 1.0))
	return m


func _city_of(shop_id: String) -> String:
	return String(shops[shop_id].get("city", ""))


## What the shop asks when a buyer takes one unit.
func buy_price(shop_id: String, good: String) -> int:
	var s: Dictionary = shops[shop_id]
	var qty: int = s["stock"].get(good, 0)
	var base: float = float(GOODS[good]["base"])
	return maxi(1, roundi(base * price_factor(good, qty, _city_of(shop_id)) * _ask))


## What the shop pays when a seller hands over one unit.
func sell_price(shop_id: String, good: String) -> int:
	var s: Dictionary = shops[shop_id]
	var qty: int = s["stock"].get(good, 0)
	var base: float = float(GOODS[good]["base"])
	return maxi(1, roundi(base * price_factor(good, qty, _city_of(shop_id)) * _bid))


func buy(shop_id: String, good: String, buyer_id: String) -> bool:
	var s: Dictionary = shops[shop_id]
	var have: int = s["stock"].get(good, 0)
	if have <= 0:
		return false
	var price := buy_price(shop_id, good)
	var w: Dictionary = wallets[buyer_id]
	if int(w["coins"]) < price:
		return false
	w["coins"] = int(w["coins"]) - price
	wallets[shop_id]["coins"] = int(wallets[shop_id]["coins"]) + price
	s["stock"][good] = have - 1
	w["items"][good] = int(w["items"].get(good, 0)) + 1
	transferred.emit(buyer_id, shop_id, price, "buy " + good)
	changed.emit()
	return true


func sell(shop_id: String, good: String, seller_id: String) -> bool:
	var s: Dictionary = shops[shop_id]
	if not (good in s["buys"]):
		return false
	var w: Dictionary = wallets[seller_id]
	if int(w["items"].get(good, 0)) <= 0:
		return false
	var price := sell_price(shop_id, good)
	if int(wallets[shop_id]["coins"]) < price:
		return false
	_take_item(seller_id, good, 1)
	w["coins"] = int(w["coins"]) + price
	wallets[shop_id]["coins"] = int(wallets[shop_id]["coins"]) - price
	s["stock"][good] = int(s["stock"].get(good, 0)) + 1
	transferred.emit(shop_id, seller_id, price, "sell " + good)
	changed.emit()
	return true


func pay(from_id: String, to_id: String, amount: int) -> bool:
	var src: Dictionary = wallets[from_id]
	if int(src["coins"]) < amount:
		return false
	src["coins"] = int(src["coins"]) - amount
	wallets[to_id]["coins"] = int(wallets[to_id]["coins"]) + amount
	if amount > 0:
		transferred.emit(from_id, to_id, amount, "pay")
	changed.emit()
	return true


func add_item(wallet_id: String, good: String, n: int = 1) -> void:
	var w: Dictionary = wallets[wallet_id]
	w["items"][good] = int(w["items"].get(good, 0)) + n
	changed.emit()


## Shop-to-shop purchase: the buyer shop pays the seller's asking price and
## the unit moves from one stock to the other.
func b2b(seller_id: String, buyer_id: String, good: String) -> bool:
	var s: Dictionary = shops[seller_id]
	var have := int(s["stock"].get(good, 0))
	if have <= 0:
		return false
	var price := buy_price(seller_id, good)
	if int(wallets[buyer_id]["coins"]) < price:
		return false
	wallets[buyer_id]["coins"] = int(wallets[buyer_id]["coins"]) - price
	wallets[seller_id]["coins"] = int(wallets[seller_id]["coins"]) + price
	transferred.emit(buyer_id, seller_id, price, "b2b " + good)
	s["stock"][good] = have - 1
	var b: Dictionary = shops[buyer_id]
	b["stock"][good] = int(b["stock"].get(good, 0)) + 1
	return true


## Consumes one item from a wallet. Returns false if there is none.
func use_item(wallet_id: String, good: String) -> bool:
	var w: Dictionary = wallets[wallet_id]
	if int(w["items"].get(good, 0)) <= 0:
		return false
	_take_item(wallet_id, good, 1)
	changed.emit()
	return true


func _take_item(wallet_id: String, good: String, n: int) -> void:
	var w: Dictionary = wallets[wallet_id]
	var left := int(w["items"].get(good, 0)) - n
	if left <= 0:
		w["items"].erase(good)
	else:
		w["items"][good] = left


## Each shop with a recipe consumes its inputs and adds its outputs.
func produce() -> void:
	for id in shops:
		var s: Dictionary = shops[id]
		var recipe: Dictionary = s["recipe"]
		if recipe.is_empty():
			continue
		# raw goods the workers bring in themselves (ore from the pit, wood from the forest)
		var src: Dictionary = recipe.get("src", {})
		for g in src:
			s["stock"][g] = mini(STOCK_CAP, int(s["stock"].get(g, 0)) + int(src[g]))
		var ins: Dictionary = recipe.get("in", {})
		var outs: Dictionary = recipe.get("out", {})
		var ready := false
		for g in outs:
			if int(s["stock"].get(g, 0)) < STOCK_CAP:
				ready = true
		for g in ins:
			if int(s["stock"].get(g, 0)) < int(ins[g]):
				ready = false
		if not ready:
			continue
		for g in ins:
			s["stock"][g] = int(s["stock"][g]) - int(ins[g])
		for g in outs:
			s["stock"][g] = mini(STOCK_CAP, int(s["stock"].get(g, 0)) + int(outs[g]))
	changed.emit()


func total_coins() -> int:
	var t := 0
	for id in wallets:
		t += int(wallets[id]["coins"])
	return t


# ---------------- why prices are what they are ----------------

## One plain sentence on why a good costs what it does in a city's shops, or "".
## Walks the shops of that city, finds the scarcest/most abundant stock.
func price_reason(city: String, good: String, rng: RandomNumberGenerator = null) -> String:
	var r: Dictionary = data["reasons"]
	var gname: String = GOODS[good]["name"].to_lower()
	var cname: String = String(city_def(city).get("name", city))
	for e in active_events:
		if (e["city"] == "" or e["city"] == city) and e["goods"].has(good):
			return String(e["text"]) % cname
	var total := 0
	var makers := 0
	for id in shops:
		var s: Dictionary = shops[id]
		if s["city"] != city or s["kind"] == "":
			continue
		total += int(s["stock"].get(good, 0))
		makers += 1
	if makers == 0:
		return ""
	var avg := float(total) / float(makers)
	var target := float(GOODS[good]["target"])
	var pick := func(a: Array) -> String:
		return String(a[(rng.randi() if rng != null else 0) % a.size()])
	if avg < target * 0.5:
		var why: String = pick.call(r["why_scarce"]) % total
		return String(pick.call(r["scarce"])) % [gname.capitalize(), cname, why.capitalize()]
	if avg > target * 1.4:
		var why2: String = pick.call(r["why_glut"]) % total
		return String(pick.call(r["glut"])) % [gname.capitalize(), cname, why2.capitalize()]
	return ""


## The most notable price story in a city: a good that is scarce, in glut or
## hit by an event. Returns "" if prices are quiet.
func city_news(city: String, rng: RandomNumberGenerator) -> String:
	var best := ""
	var best_dev := 0.0
	for g in GOODS:
		var total := 0
		var makers := 0
		for id in shops:
			var s: Dictionary = shops[id]
			if s["city"] != city or s["kind"] == "":
				continue
			total += int(s["stock"].get(g, 0))
			makers += 1
		if makers == 0:
			continue
		var dev := absf(log(maxf(0.05, price_factor(g, int(round(float(total) / float(makers))), city))))
		if dev > best_dev:
			best_dev = dev
			best = g
	if best == "" or best_dev < 0.25:
		return String(data["reasons"]["nothing"])
	var line := price_reason(city, best, rng)
	return line if line != "" else String(data["reasons"]["nothing"])


# ---------------- events ----------------

## Rolls today's events. Returns the announcements to show. `cities` is the
## list of city ids in this world. One roll a day, ~45% chance to start one.
func roll_events(day: int, cities: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var keep: Array = []
	for e in active_events:
		if int(e["until"]) > day:
			keep.append(e)
		else:
			out.append("The %s is over." % String(e["name"]).to_lower())
	active_events = keep
	if rng.randf() > 0.45 or active_events.size() >= 2:
		return out
	var pool: Array = []
	var wsum := 0.0
	for ev in data["events"]:
		var where: String = ev["where"]
		if where != "any" and not (where in cities):
			continue
		pool.append(ev)
		wsum += float(ev["weight"])
	if pool.is_empty():
		return out
	var roll := rng.randf() * wsum
	var chosen: Dictionary = pool[0]
	for ev in pool:
		roll -= float(ev["weight"])
		if roll <= 0.0:
			chosen = ev
			break
	var city: String = chosen["where"]
	if city == "any":
		city = String(cities[rng.randi() % cities.size()])
	for e in active_events:
		if e["id"] == chosen["id"]:
			return out
	active_events.append({"id": chosen["id"], "name": chosen["name"], "city": city, "until": day + int(chosen["days"]), "goods": chosen["goods"], "text": chosen["text"], "npc": chosen.get("npc", ""), "danger": int(chosen.get("danger", 0))})
	var sup: Dictionary = chosen.get("supply", {})
	for sid in shops:
		var s: Dictionary = shops[sid]
		if s["city"] != city or not sup.has(s["kind"]):
			continue
		for g in sup[s["kind"]]:
			s["stock"][g] = mini(STOCK_CAP, int(s["stock"].get(g, 0)) + int(sup[s["kind"]][g]))
	out.append(String(chosen["text"]) % String(city_def(city).get("name", city)))
	changed.emit()
	return out


## True while a road-danger event is running (raiders).
func road_danger() -> int:
	var d := 0
	for e in active_events:
		d += int(e.get("danger", 0))
	return d


# ---------------- travelling merchants ----------------

## The best single haul for a trader with `coins` and room for `cap` units:
## buy a good where it is cheap and sell where it is dear, in another city.
## Returns {} if nothing beats `min_profit`. Prices are quoted as each shop
## would quote them right now, stepping with each unit.
func best_trade(coins: int, cap: int, from_city: String, min_profit: int, trader_id := "") -> Dictionary:
	var best: Dictionary = {}
	var best_profit := min_profit - 1
	for a in shops:
		var sa: Dictionary = shops[a]
		if a == trader_id or sa["kind"] == "" or sa["city"] == "":
			continue
		if from_city != "" and sa["city"] != from_city:
			continue
		for g in sa["stock"]:
			var have: int = int(sa["stock"][g])
			if have <= 1:
				continue
			var unit := buy_price(a, g)
			if unit <= 0:
				continue
			var qty := mini(mini(have - 1, cap), coins / unit)
			if qty <= 0:
				continue
			for b in shops:
				var sb: Dictionary = shops[b]
				if b == a or b == trader_id or sb["kind"] == "" or sb["city"] == sa["city"] or sb["city"] == "":
					continue
				if not (g in sb["buys"]):
					continue
				var got := 0
				var q := 0
				var till := int(wallets[b]["coins"])
				var cost := 0
				var stock_b: int = int(sb["stock"].get(g, 0))
				var cost_a := 0
				for i in qty:
					var ask := buy_price_at(a, g, have - i)
					var bid := sell_price_at(b, g, stock_b + i)
					if got + bid > till:
						break
					got += bid
					cost_a += ask
					q += 1
				cost = cost_a
				var profit := got - cost
				if q > 0 and profit > best_profit and cost <= coins:
					best_profit = profit
					best = {"from": a, "to": b, "good": g, "qty": q, "profit": profit, "cost": cost}
	return best


func buy_price_at(shop_id: String, good: String, qty: int) -> int:
	var base: float = float(GOODS[good]["base"])
	return maxi(1, roundi(base * price_factor(good, qty, _city_of(shop_id)) * _ask))


func sell_price_at(shop_id: String, good: String, qty: int) -> int:
	var base: float = float(GOODS[good]["base"])
	return maxi(1, roundi(base * price_factor(good, qty, _city_of(shop_id)) * _bid))
