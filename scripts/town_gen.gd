## Seeded town layouts with real shapes. Each city has a "shape":
##   green  - a village around a green, lanes bending off a winding main street
##   hill   - a mining town stacked up a mountainside on switchback roads
##   river  - a port split by a river, with bridges and quays
##   ring   - a walled market town: ring road, four gates, a central square
## Everything here is in LOCAL tile coordinates (floats are tile centres); the
## caller adds the city's origin. A layout holds: buildings, road segments and
## plaza discs, a wall (fence tiles with a rotation), named gates, lamp spots,
## the start/board/legend spots, and an optional river with its bridges.
class_name TownGen
extends RefCounted

const TILE := 48
const COLS := 26
const ROWS := 20
## Road half-width in tiles.
const ROAD_HW := 0.55

## kind -> footprint in tiles (w, h). Anything not listed is 3x2.
const SIZES := {
	"market": Vector2i(4, 3), "tavern": Vector2i(4, 3), "inn": Vector2i(4, 3), "temple": Vector2i(4, 3),
	"exchange": Vector2i(4, 3), "caravanserai": Vector2i(4, 3), "guard": Vector2i(3, 3), "smithy": Vector2i(3, 3),
	"foundry": Vector2i(4, 3), "dock": Vector2i(4, 2), "lighthouse": Vector2i(2, 2), "house": Vector2i(3, 2),
}
const CIVIC := ["market", "tavern", "inn", "temple", "exchange", "caravanserai", "bakery", "weaver"]

static var _cache := {}
static var _towns := {}


static func town_data(id: String) -> Dictionary:
	if _towns.is_empty():
		var f := FileAccess.open("res://data/towns.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_towns = parsed
	return _towns.get(id, {})


## Layout for a city, cached per seed. `kinds` is the city's building list.
static func layout(id: String, seed_value: int, kinds: Array) -> Dictionary:
	var key := "%s/%d" % [id, seed_value]
	if _cache.has(key):
		return _cache[key]
	var shape: String = String(town_data(id).get("shape", "green"))
	var L := _shape(shape, seed_value + hash(id) % 997)
	L["id"] = id
	L["shape"] = shape
	_place_buildings(L, kinds, seed_value + hash(id) % 991)
	_finish(L)
	_cache[key] = L
	return L


# ---------------- shapes ----------------

static func _empty() -> Dictionary:
	return {"size": Vector2i(COLS, ROWS), "roads": [], "discs": [], "fence": [], "gates": {}, "lamps": [], "river": [],
		"river_w": 0.0, "bridges": [], "center": Vector2(COLS * 0.5, ROWS * 0.5), "props": [], "buildings": [],
		"mountain": "", "plaza_r": 2.6}


static func _poly(L: Dictionary, pts: Array, hw := ROAD_HW) -> void:
	for i in pts.size() - 1:
		L["roads"].append([pts[i], pts[i + 1], hw])


static func _shape(shape: String, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var L := _empty()
	match shape:
		"hill":
			_shape_hill(L, rng)
		"river":
			_shape_river(L, rng)
		"ring":
			_shape_ring(L, rng)
		_:
			_shape_green(L, rng)
	return L


static func _j(rng: RandomNumberGenerator, a := 0.6) -> float:
	return rng.randf_range(-a, a)


static func _shape_green(L: Dictionary, rng: RandomNumberGenerator) -> void:
	var c := Vector2(13.0, 10.2)
	L["center"] = c
	L["plaza_r"] = 2.7
	L["discs"].append([c, 2.7])
	# a winding main street through the green
	_poly(L, [Vector2(-3, 10), Vector2(3, 9.4 + _j(rng)), Vector2(8, 10.8 + _j(rng)), c, Vector2(18.5, 9.6 + _j(rng)),
		Vector2(23, 10.6 + _j(rng)), Vector2(29, 10)])
	# lanes that curl away north and south
	_poly(L, [Vector2(6.5, 10.4), Vector2(5.6, 6.2 + _j(rng)), Vector2(7.4, 2.6), Vector2(6.5, -3)])
	_poly(L, [c, Vector2(12.0, 6.0), Vector2(14.4, 2.4), Vector2(13, -3)])
	_poly(L, [Vector2(7.6, 10.7), Vector2(7.4, 14.2), Vector2(6.0, 18.0), Vector2(6.5, 23)])
	_poly(L, [c, Vector2(14.2, 14.6), Vector2(15.4, 18.2), Vector2(14, 23)])
	_poly(L, [Vector2(19, 9.8), Vector2(20.5, 5.4), Vector2(23.5, 2.8)])
	_poly(L, [Vector2(20.5, 10.4), Vector2(21.4, 14.6), Vector2(24, 17.5)])
	L["gates"] = {"w": Vector2(-3, 10), "e": Vector2(29, 10), "n1": Vector2(6.5, -3), "n2": Vector2(13, -3),
		"s1": Vector2(6.5, 23), "s2": Vector2(14, 23)}
	L["legend_at"] = c + Vector2(-0.9, -0.4)


static func _shape_hill(L: Dictionary, rng: RandomNumberGenerator) -> void:
	L["mountain"] = "n"
	var c := Vector2(13.0, 11.0)
	L["center"] = c
	L["plaza_r"] = 2.0
	# the lower street runs east-west, the stair zigzags up to the mine mouth
	_poly(L, [Vector2(-3, 17.5), Vector2(5, 17.0 + _j(rng, 0.3)), Vector2(13, 17.6), Vector2(21, 17.0), Vector2(29, 17.5)])
	_poly(L, [Vector2(13, 17.4), Vector2(14.5, 15.0), Vector2(8.0, 13.6), Vector2(6.2, 11.4)])
	_poly(L, [Vector2(6.2, 11.4), Vector2(11.0, 10.0), Vector2(18.0, 11.6), Vector2(20.6, 8.6)])
	_poly(L, [Vector2(20.6, 8.6), Vector2(15.0, 7.2), Vector2(9.0, 7.0), Vector2(8.2, 4.4)])
	_poly(L, [Vector2(8.2, 4.4), Vector2(12.0, 3.2), Vector2(14.0, 1.6)])
	_poly(L, [Vector2(21, 17.2), Vector2(23.4, 13.8), Vector2(20.6, 8.8)])
	L["discs"].append([Vector2(14.0, 1.8), 1.6])
	L["gates"] = {"w": Vector2(-3, 17.5), "e": Vector2(29, 17.5), "n": Vector2(14, -1), "s": Vector2(13, 23)}
	L["legend_at"] = Vector2(14.0, 3.2)
	# a retaining wall between switchbacks
	for i in 9:
		var t := Vector2(7.0 + i * 1.3, 15.4 - i * 0.28)
		L["fence"].append({"p": t, "rot": 0.0})
	for i in 7:
		L["fence"].append({"p": Vector2(16.0 + i * 1.3, 9.2 - i * 0.15), "rot": 0.0})


static func _shape_river(L: Dictionary, rng: RandomNumberGenerator) -> void:
	var c := Vector2(11.0, 10.0)
	L["center"] = c
	# the river bends through the middle, from the north-east corner to the west edge
	var r: Array = [Vector2(29, 1), Vector2(23, 3.4), Vector2(19, 7), Vector2(16.5, 11.5), Vector2(12.5, 14.0),
		Vector2(8.0, 14.6), Vector2(3.5, 13.2), Vector2(-3, 14.6)]
	L["river"] = r
	L["river_w"] = 2.8
	# the long road follows the north bank, two streets cross over bridges
	_poly(L, [Vector2(-3, 8.2), Vector2(4, 7.6), Vector2(9, 8.4), Vector2(14, 6.8), Vector2(19.5, 4.4 + _j(rng, 0.3)), Vector2(29, 6.2)])
	_poly(L, [Vector2(10.5, 8.2), Vector2(10.2, 11.4), Vector2(10.4, 17.0), Vector2(11.6, 23)])
	_poly(L, [Vector2(18.5, 5.0), Vector2(21.0, 9.0), Vector2(23.0, 13.0), Vector2(23.6, 18.0), Vector2(22, 23)])
	_poly(L, [Vector2(5.2, 7.8), Vector2(4.6, 3.8), Vector2(6.0, -3)])
	_poly(L, [Vector2(14.2, 6.8), Vector2(14.0, 2.6), Vector2(15.4, -3)])
	_poly(L, [Vector2(10.4, 17.2), Vector2(5.0, 17.8), Vector2(-3, 17.2)])
	L["discs"].append([Vector2(10.5, 8.2), 1.9])
	L["gates"] = {"w": Vector2(-3, 8.2), "e": Vector2(29, 6.2), "n": Vector2(15.4, -3), "n2": Vector2(6.0, -3), "s": Vector2(11.6, 23)}
	L["legend_at"] = Vector2(12.2, 7.0)
	L["plaza_r"] = 1.9


static func _shape_ring(L: Dictionary, rng: RandomNumberGenerator) -> void:
	L["size"] = Vector2i(30, 26)
	var c := Vector2(15.0, 13.0)
	L["center"] = c
	L["plaza_r"] = 2.8
	var ring_r := 5.0
	var wall_r := 11.6
	L["discs"].append([c, 2.8])
	var pts: Array = []
	for i in 21:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a), sin(a)) * ring_r)
	_poly(L, pts)
	# four spokes out through the gates
	for k in 4:
		var a3 := PI * 0.5 * k
		var d := Vector2(cos(a3), sin(a3))
		_poly(L, [c, c + d * ring_r, c + d * (wall_r + 3.4)])
	L["gates"] = {"e": c + Vector2(wall_r + 3.0, 0), "s": c + Vector2(0, wall_r + 3.0), "w": c + Vector2(-wall_r - 3.0, 0), "n": c + Vector2(0, -wall_r - 3.0)}
	# the wall: a ring of fence tiles with gaps at the gates
	var steps := 96
	for i in steps:
		var a4 := TAU * float(i) / float(steps)
		var d2 := Vector2(cos(a4), sin(a4))
		var near_gate := false
		for g in L["gates"].values():
			if (c + d2 * wall_r).distance_to(g) < 4.6:
				near_gate = true
		if near_gate:
			continue
		var t := Vector2(-d2.y, d2.x)
		L["fence"].append({"p": c + d2 * wall_r, "rot": atan2(-t.y, t.x)})
	L["legend_at"] = c + Vector2(0.0, -0.4)
	L["round"] = true


# ---------------- buildings ----------------

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _rect_dist(r: Rect2, p: Vector2) -> float:
	var c := r.get_center()
	var h := r.size * 0.5
	var q := Vector2(maxf(absf(p.x - c.x) - h.x, 0.0), maxf(absf(p.y - c.y) - h.y, 0.0))
	return q.length()


## True when a segment comes within `lim` tiles of the rectangle.
static func _rect_near_seg(r: Rect2, a: Vector2, b: Vector2, lim: float) -> bool:
	var len := a.distance_to(b)
	var n := maxi(1, int(len / 0.45))
	for i in n + 1:
		if _rect_dist(r, a.lerp(b, float(i) / float(n))) < lim:
			return true
	return false


static func _rect_clear(L: Dictionary, r: Rect2, placed: Array) -> bool:
	var sz: Vector2i = L["size"]
	if r.position.x < 1.0 or r.position.y < 1.0 or r.end.x > sz.x - 1.0 or r.end.y > sz.y - 1.0:
		return false
	var big := r.grow(0.6)
	for q in placed:
		if big.intersects(q):
			return false
	# keep out of the road bodies
	for s in L["roads"]:
		if _rect_near_seg(r, s[0], s[1], float(s[2]) + 0.3):
			return false
	for d in L["discs"]:
		if _rect_dist(r, d[0]) < float(d[1]) + 0.6:
			return false
	var rv: Array = L["river"]
	for i in rv.size() - 1:
		if _rect_near_seg(r, rv[i], rv[i + 1], float(L["river_w"]) * 0.5 + 1.0):
			return false
	for f in L["fence"]:
		if _rect_dist(r.grow(0.3), f["p"]) < 0.5:
			return false
	# a ring town keeps to its band between the ring road and the wall, or sits outside
	if L.get("round", false):
		var c: Vector2 = L["center"]
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		var dmin := 99.0
		var dmax := 0.0
		for q4 in corners:
			dmin = minf(dmin, q4.distance_to(c))
			dmax = maxf(dmax, q4.distance_to(c))
		if not (dmin > 5.8 and dmax < 11.0) and not (dmin > 12.4):
			return false
	return true


static func _candidates(L: Dictionary, size: Vector2i, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	for s in L["roads"]:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var len := a.distance_to(b)
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var steps := maxi(1, int(len / 0.6))
		for i in steps + 1:
			var p := a + dir * (len * float(i) / float(steps))
			for side in [-1.0, 1.0]:
				var off := float(s[2]) + 0.55 + absf(nrm.x) * hx + absf(nrm.y) * hy
				for extra in [0.0, 0.6, 1.4, 2.4, 3.6]:
					var cen: Vector2 = p + nrm * side * (off + extra)
					out.append(Rect2((cen - Vector2(hx, hy)).round(), Vector2(size)))
	return out


static func _place_buildings(L: Dictionary, kinds: Array, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var want: Array = kinds.duplicate()
	# every town gets an inn and a few more houses than the old grid had
	if not ("inn" in want):
		want.insert(maxi(0, mini(want.size(), 4)), "inn")
	for i in 5:
		want.append("house")
	var placed: Array = []
	var out: Array = []
	var c: Vector2 = L["center"]
	var gate_list: Array = L["gates"].values()
	var idx := 0
	# civic first (near the middle), then the rest, houses last
	var order: Array = []
	for k in want:
		if k in CIVIC:
			order.append(k)
	for k in want:
		if not (k in CIVIC) and k != "house":
			order.append(k)
	for k in want:
		if k == "house":
			order.append(k)
	for kind in order:
		var sizes: Array = [SIZES.get(kind, Vector2i(3, 2)), Vector2i(3, 2), Vector2i(2, 2)]
		if kind == "house" and rng.randf() < 0.4:
			sizes = [Vector2i(2, 2), Vector2i(3, 2)]
		var cands: Array = []
		var best := Rect2()
		var best_s := INF
		for size in sizes:
			cands = _candidates(L, size, rng)
			for r in cands:
				if _rect_clear(L, r, placed):
					best_s = 0.0
					break
			if best_s == 0.0:
				break
		best_s = INF
		for r in cands:
			if not _rect_clear(L, r, placed):
				continue
			var s := 0.0
			var cen: Vector2 = r.get_center()
			if kind in CIVIC:
				s = cen.distance_to(c) + rng.randf() * 2.5
			elif kind == "guard":
				s = INF
				for g in gate_list:
					s = minf(s, cen.distance_to(g))
				s += rng.randf() * 2.0
			elif kind == "dock" or kind == "lighthouse":
				s = 99.0
				var rv: Array = L["river"]
				for i in rv.size() - 1:
					s = minf(s, _seg_dist(cen, rv[i], rv[i + 1]))
				if rv.is_empty():
					s = -cen.y + rng.randf() * 3.0
			else:
				s = rng.randf() * 10.0 + cen.distance_to(c) * 0.2
			if s < best_s:
				best_s = s
				best = r
		if best_s == INF and best.size == Vector2.ZERO:
			continue
		if best.size == Vector2.ZERO:
			continue
		placed.append(best)
		out.append({"id": "%s_%d" % [kind, out.size()], "kind": kind, "rect": Rect2i(Vector2i(best.position), Vector2i(best.size))})
		idx += 1
	# a hillside or a riverbank can crowd houses out: scan the open ground for a few more
	var houses := 0
	for bb in out:
		if bb["kind"] == "house":
			houses += 1
	if houses < 4:
		var sz: Vector2i = L["size"]
		var spots: Array = []
		for gy in range(1, sz.y - 2):
			for gx in range(1, sz.x - 2):
				var rr := Rect2(Vector2(gx, gy), Vector2(2, 2))
				if _rect_clear(L, rr, placed):
					var dr := 99.0
					for sg in L["roads"]:
						dr = minf(dr, _seg_dist(rr.get_center(), sg[0], sg[1]))
					if dr < 5.5:
						spots.append([dr + rng.randf() * 2.0, rr])
		spots.sort_custom(func(x, y): return x[0] < y[0])
		for sp in spots:
			if houses >= 4:
				break
			if _rect_clear(L, sp[1], placed):
				placed.append(sp[1])
				out.append({"id": "house_%d" % out.size(), "kind": "house", "rect": Rect2i(Vector2i(sp[1].position), Vector2i(2, 2))})
				houses += 1
	L["buildings"] = out


# ---------------- finishing ----------------

static func _intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Variant:
	var r := b - a
	var s := d - c
	var den := r.x * s.y - r.y * s.x
	if absf(den) < 0.0001:
		return null
	var t := ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / den
	var u := ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / den
	if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
		return a + r * t
	return null


static func _finish(L: Dictionary) -> void:
	# bridges where a road crosses the river
	var rv: Array = L["river"]
	if not rv.is_empty():
		var last := Vector2(-999, -999)
		for s in L["roads"]:
			for i in rv.size() - 1:
				var hit: Variant = _intersect(s[0], s[1], rv[i], rv[i + 1])
				if hit != null and (hit as Vector2).distance_to(last) > 3.0:
					last = hit
					var dir: Vector2 = (s[1] - s[0]).normalized()
					L["bridges"].append({"pos": hit, "dir": dir})
	# lamps along the roads, a little off to one side
	var acc := 0.0
	for s in L["roads"]:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var len := a.distance_to(b)
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var d := fmod(acc, 4.5)
		while d < len:
			var p := a + dir * d + nrm * (float(s[2]) + 0.45)
			if _free_of_buildings(L, p, 0.4) and not _in_river(L, p):
				L["lamps"].append(p)
			d += 4.5
		acc += len
	# a start plaza spot, the quest board and the well, near the centre
	var c: Vector2 = L["center"]
	L["start"] = _free_spot(L, c + Vector2(0.0, 1.2))
	L["board"] = _free_spot(L, c + Vector2(-2.6, -1.8))
	L["well"] = _free_spot(L, c + Vector2(2.4, -1.4))
	L["legend_pos"] = _free_spot(L, L.get("legend_at", c))
	# walkable points on the roads (for strolling townsfolk and merchants)
	var pts: Array = []
	for s2 in L["roads"]:
		var a2: Vector2 = s2[0]
		var b2: Vector2 = s2[1]
		var len2 := a2.distance_to(b2)
		var n := maxi(1, int(len2 / 1.6))
		for i in n + 1:
			var p2: Vector2 = a2.lerp(b2, float(i) / float(n))
			var sz: Vector2i = L["size"]
			if p2.x > 0.5 and p2.y > 0.5 and p2.x < sz.x - 0.5 and p2.y < sz.y - 0.5 and not _in_river(L, p2) and _free_of_buildings(L, p2, 0.2):
				pts.append(p2)
	L["points"] = pts


static func _in_river(L: Dictionary, p: Vector2) -> bool:
	var rv: Array = L["river"]
	for i in rv.size() - 1:
		if _seg_dist(p, rv[i], rv[i + 1]) < float(L["river_w"]) * 0.5 + 0.4:
			for br in L["bridges"]:
				if _seg_dist(p, br["pos"] - br["dir"] * 4.0, br["pos"] + br["dir"] * 4.0) < 1.3:
					return false
			return true
	return false


static func _free_of_buildings(L: Dictionary, p: Vector2, pad: float) -> bool:
	for b in L["buildings"]:
		var r := Rect2(Vector2(b["rect"].position), Vector2(b["rect"].size)).grow(pad)
		if r.has_point(p):
			return false
	return true


## The nearest spot to `want` that is clear of buildings and water.
static func _free_spot(L: Dictionary, want: Vector2) -> Vector2:
	if _free_of_buildings(L, want, 0.5) and not _in_river(L, want):
		return want
	for ring in range(1, 8):
		for k in 12:
			var a := TAU * float(k) / 12.0
			var q := want + Vector2(cos(a), sin(a)) * ring * 0.6
			if _free_of_buildings(L, q, 0.5) and not _in_river(L, q):
				return q
	return want


## Tiles (local) that are water and not under a bridge.
static func river_tiles(L: Dictionary) -> Array:
	var out: Array = []
	var sz: Vector2i = L["size"]
	for ty in range(-6, sz.y + 6):
		for tx in range(-6, sz.x + 6):
			if _in_river(L, Vector2(tx + 0.5, ty + 0.5)):
				out.append(Vector2i(tx, ty))
	return out
