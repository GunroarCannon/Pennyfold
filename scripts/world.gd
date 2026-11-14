## The open world around the town: a seeded heightmap with rolling hills,
## a mountain rim, a lake, winding dirt roads out to six landmarks, and
## thousands of cut-out trees, flowers and rocks. Builds the terrain chunks,
## water, the prop scatter (one MultiMesh per chunk), landmark structures,
## the far mountain ring, and a picture of the whole map for the HUD.
## Positions in the simulation are pixels (48 per tile); 3D units = px * K.
class_name World
extends RefCounted

const TILE := 48.0
const K := 1.5 / 48.0
const T0 := Vector2i(-96, -96)
const TN := Vector2i(210, 206)
const CHUNK := 30
const WATER := -0.55
const TOWN_RECT := Rect2(-1, -1, 28, 22)
const TOWN_C := Vector2(13, 10)

## id -> name, offset from town centre (tiles), radius (tiles), icon, good
const LANDMARKS := [
	{"id": "farm", "name": "Sunfield Farm", "off": Vector2(46, -26), "r": 9.0, "icon": "house", "good": "wheat"},
	{"id": "mine", "name": "Old Copper Mine", "off": Vector2(-50, -46), "r": 7.0, "icon": "pipe", "good": "ore"},
	{"id": "lake", "name": "Mirror Lake", "off": Vector2(-36, 44), "r": 12.0, "icon": "water_drop", "good": "herb"},
	{"id": "ruins", "name": "Thorn Ruins", "off": Vector2(58, 50), "r": 9.0, "icon": "crown", "good": ""},
	{"id": "wood", "name": "Whisper Wood", "off": Vector2(-60, 4), "r": 12.0, "icon": "pine", "good": "herb"},
	{"id": "lookout", "name": "Lookout Hill", "off": Vector2(12, -60), "r": 6.0, "icon": "flag", "good": ""},
]
## Roads: gate tile -> list of landmark ids visited in order.
## Entries can be a landmark id or a Vector2 tile waypoint. The extra cities
## append their own links in generate() from data/economy_data.json.
const ROUTES := [
	[Vector2(13, -3), ["lookout"]],
	[Vector2(-3, 10), ["wood", "mine"]],
	[Vector2(14, 23), ["ruins"]],
]

var cute := true
var seed_value := 1
var h := PackedFloat32Array()
var road := PackedFloat32Array()
var colors := PackedColorArray()
var solid := PackedByteArray()
var landmarks: Array = []
## Extra cities: {id, name, origin (tile), rect (tiles), ground (Color), palette}
var cities: Array = []
## id -> TownGen layout (local tiles), for every town including Sunny
var layouts := {}
## [a, b] tile-space segments of every bridge deck, for walking over water
var bridge_list: Array = []
var routes: Array = []
var roads: Array = []
var gather_spots: Array = []
var map_image: Image
var noise := FastNoiseLite.new()
var ridge := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var props_material: ShaderMaterial
var props_atlas: Texture2D
## Every choppable tree: {mm, q, pos (px), hp, i, j, k, w, h, o, gone, regrow}
var trees: Array = []
var stride := 0


func generate(seed_in: int, is_cute: bool) -> void:
	seed_value = seed_in
	cute = is_cute
	rng.seed = seed_in * 31 + 7
	noise.seed = seed_in
	noise.frequency = 0.022
	noise.fractal_octaves = 4
	ridge.seed = seed_in + 1
	ridge.frequency = 0.05
	detail.seed = seed_in + 2
	detail.frequency = 0.09
	landmarks.clear()
	for l in LANDMARKS:
		var d: Dictionary = l.duplicate()
		d["tile"] = TOWN_C + d["off"] + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		d["pos"] = d["tile"] * TILE
		landmarks.append(d)
	_setup_cities()
	bridge_list.clear()
	for c in cities:
		for br in layouts[c["id"]]["bridges"]:
			var o2: Vector2 = c["origin"]
			bridge_list.append([o2 + br["pos"] - br["dir"] * 5.0, o2 + br["pos"] + br["dir"] * 5.0])
	stride = TN.x + 1
	var n := stride * (TN.y + 1)
	h.resize(n)
	road.resize(n)
	road.fill(0.0)
	for j in TN.y + 1:
		for i in TN.x + 1:
			h[j * stride + i] = _base(Vector2(T0.x + i, T0.y + j))
	_carve_roads()
	_paint_colors()
	_mark_solid()
	_make_map_image()


## Reads the extra cities from the economy data: where they sit, and the
## roads that join them to the main town and on to the landmarks.
func _setup_cities() -> void:
	cities.clear()
	layouts.clear()
	routes = ROUTES.duplicate(true)
	var defs: Dictionary = Economy.data.get("cities", {})
	layouts["sunny"] = TownGen.layout("sunny", seed_value, defs["sunny"]["kinds"])
	for id in defs:
		var c: Dictionary = defs[id]
		if not c.has("offset"):
			continue
		var o := Vector2(float(c["offset"][0]), float(c["offset"][1]))
		var pal: Dictionary = c.get("palette", {})
		var g: Array = pal.get("ground", [0.80, 0.72, 0.58])
		var L: Dictionary = TownGen.layout(id, seed_value, c["kinds"])
		layouts[id] = L
		var ctr: Vector2 = o + (L["center"] as Vector2)
		cities.append({"id": id, "name": c["name"], "origin": o, "rect": Rect2(o.x - 1.0, o.y - 1.0, float(L["size"].x) + 2.0, float(L["size"].y) + 2.0), "ground": Color(g[0], g[1], g[2]), "tile": ctr, "pos": ctr * TILE})
		var start: Vector2 = (o + (L["start"] as Vector2)) * TILE
		landmarks.append({"id": id, "name": c["name"], "off": Vector2.ZERO, "r": 11.0, "icon": "house", "good": "", "city": true, "tile": ctr, "pos": ctr * TILE, "spot": start})
		var link: Dictionary = c["link"]
		var gate: Vector2 = o + (L["gates"][String(link["gate"])] as Vector2)
		var sg: Vector2 = layouts["sunny"]["gates"][String(link["main_gate"])] as Vector2
		routes.append([sg, [gate]])
		var on: Dictionary = c.get("onward", {})
		if not on.is_empty():
			var og: Vector2 = o + (L["gates"][String(on["gate"])] as Vector2)
			var seq: Array = []
			for lid in on["to"]:
				seq.append(String(lid))
			routes.append([og, seq])


func city(id: String) -> Dictionary:
	for c in cities:
		if c["id"] == id:
			return c
	return {}


## Distance in tiles to the nearest town or city block.
func town_dist(p: Vector2) -> float:
	var d := _rect_dist(p, TOWN_RECT)
	for c in cities:
		d = minf(d, _rect_dist(p, c["rect"]))
	return d


func landmark(id: String) -> Dictionary:
	for l in landmarks:
		if l["id"] == id:
			return l
	return {}


# ---------- height ----------

func _bump(p: Vector2, c: Vector2, r: float) -> float:
	return exp(-p.distance_squared_to(c) / (r * r))


func _base(p: Vector2) -> float:
	var town_d := town_dist(p)
	var n := noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5
	var y := n * lerpf(1.0, 6.5, smoothstep(10.0, 46.0, town_d)) - 0.4
	var edge := minf(minf(p.x - T0.x, T0.x + TN.x - p.x), minf(p.y - T0.y, T0.y + TN.y - p.y))
	var rim := 1.0 - smoothstep(4.0, 28.0, edge)
	var rg := 1.0 - absf(ridge.get_noise_2d(p.x, p.y))
	y += rim * rim * (16.0 + rg * 14.0)
	var look: Vector2 = landmark("lookout")["tile"]
	y += 8.0 * _bump(p, look, 8.0)
	var mine: Vector2 = landmark("mine")["tile"]
	y += 13.0 * _bump(p, mine + Vector2(-9, -8), 11.0)
	var lake: Vector2 = landmark("lake")["tile"]
	var ld := p.distance_to(lake)
	if ld < 17.0:
		y = lerpf(maxf(y, 0.35), y, smoothstep(13.0, 17.0, ld))
		y = lerpf(y, -2.2, 1.0 - smoothstep(7.0, 10.5, ld))
	# flat plateaus for the town and the landmarks
	y = lerpf(0.0, y, smoothstep(1.5, 9.0, town_d))
	y = _town_terrain(p, y)
	for l in landmarks:
		if l["id"] == "lake" or l["id"] == "lookout" or l.get("city", false):
			continue
		var core: float = l["r"]
		var t := smoothstep(core * 0.6, core * 1.4, p.distance_to(l["tile"]))
		y = lerpf(_flat_level(l), y, t)
	if l_top(p, look):
		y = maxf(y, 7.2)
	return y


## Rivers cut through their towns and a mountain can rise behind one.
func _town_terrain(p: Vector2, y: float) -> float:
	for c in cities:
		var L: Dictionary = layouts[c["id"]]
		var o: Vector2 = c["origin"]
		if L["mountain"] != "":
			var peak := o + Vector2(13.0, -10.0)
			y += 24.0 * _bump(p, peak, 8.5) * smoothstep(-2.0, 4.0, o.y - p.y + 4.0)
		var rv: Array = L["river"]
		if rv.is_empty():
			continue
		var lp := p - o
		var best := 99.0
		for i in rv.size() - 1:
			best = minf(best, _seg_d(lp, rv[i], rv[i + 1]))
		var rw: float = float(L["river_w"])
		if best < rw * 0.5 + 2.5:
			var t := 1.0 - smoothstep(rw * 0.28, rw * 0.5 + 1.4, best)
			y = lerpf(y, -1.4, t)
	return y


func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func l_top(p: Vector2, look: Vector2) -> bool:
	return p.distance_to(look) < 2.5


func _flat_level(l: Dictionary) -> float:
	match String(l["id"]):
		"mine":
			return 2.6
		"ruins":
			return 1.8
		"farm":
			return 0.8
		_:
			return 0.6


func _rect_dist(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()


func _idx(i: int, j: int) -> int:
	return clampi(j, 0, TN.y) * stride + clampi(i, 0, TN.x)


## Height in world units at a pixel position (bilinear between corners).
func height_at(px: Vector2) -> float:
	var bh := _bridge_h(px)
	if bh > -90.0:
		return bh
	var tx := px.x / TILE - T0.x
	var ty := px.y / TILE - T0.y
	var i := floori(tx)
	var j := floori(ty)
	var fx := tx - i
	var fy := ty - j
	var a := lerpf(h[_idx(i, j)], h[_idx(i + 1, j)], fx)
	var b := lerpf(h[_idx(i, j + 1)], h[_idx(i + 1, j + 1)], fx)
	return lerpf(a, b, fy)


func to3(px: Vector2) -> Vector3:
	return Vector3(px.x * K, height_at(px), px.y * K)


# ---------- roads ----------

func _carve_roads() -> void:
	roads.clear()
	var target := PackedFloat32Array()
	var weight := PackedFloat32Array()
	target.resize(h.size())
	weight.resize(h.size())
	target.fill(0.0)
	weight.fill(0.0)
	for route in routes:
		var pts: Array = [route[0]]
		for id in route[1]:
			if id is Vector2:
				pts.append(id)
				continue
			var lt: Vector2 = landmark(id)["tile"]
			if id == "lake":
				var prev: Vector2 = pts[pts.size() - 1]
				lt += (prev - lt).normalized() * 13.5
				landmark(id)["spot"] = lt * TILE
			pts.append(lt)
		for k in pts.size() - 1:
			var path := _meander(pts[k], pts[k + 1])
			roads.append(path)
			# smooth the height along the path so the road climbs gently
			var hs: Array = []
			for q in path:
				hs.append(_sample_raw(q))
			for s in path.size():
				var acc := 0.0
				var cnt := 0
				for o in range(-10, 11):
					var q := clampi(s + o, 0, path.size() - 1)
					acc += hs[q]
					cnt += 1
				var hv := acc / cnt
				var q2: Vector2 = path[s]
				for dj in range(-3, 4):
					for di in range(-3, 4):
						var vi := int(round(q2.x)) + di - T0.x
						var vj := int(round(q2.y)) + dj - T0.y
						if vi < 0 or vj < 0 or vi > TN.x or vj > TN.y:
							continue
						var d := Vector2(vi + T0.x, vj + T0.y).distance_to(q2)
						var w := 1.0 - smoothstep(1.2, 3.2, d)
						if w <= 0.0:
							continue
						var id2 := vj * stride + vi
						target[id2] += hv * w
						weight[id2] += w
						road[id2] = maxf(road[id2], 1.0 - smoothstep(0.7, 1.9, d))
	for idx in h.size():
		if weight[idx] > 0.0:
			h[idx] = lerpf(h[idx], target[idx] / weight[idx], minf(1.0, weight[idx]))


func _sample_raw(q: Vector2) -> float:
	return h[_idx(int(round(q.x)) - T0.x, int(round(q.y)) - T0.y)]


func _meander(a: Vector2, b: Vector2) -> PackedVector2Array:
	var curve := Curve2D.new()
	var span := a.distance_to(b)
	var n := (b - a).normalized()
	var perp := Vector2(-n.y, n.x)
	var pts: Array = [a]
	for t in [0.28, 0.55, 0.8]:
		pts.append(a.lerp(b, t) + perp * rng.randf_range(-0.13, 0.13) * span)
	pts.append(b)
	for i in pts.size():
		var prev: Vector2 = pts[maxi(0, i - 1)]
		var next: Vector2 = pts[mini(pts.size() - 1, i + 1)]
		var tg := (next - prev) * 0.22
		curve.add_point(pts[i], -tg, tg)
	curve.bake_interval = 0.5
	return curve.get_baked_points()


# ---------- colours and walkability ----------

func _paint_colors() -> void:
	colors.resize(h.size())
	var grass := Color(0.56, 0.80, 0.40) if cute else Color(0.42, 0.58, 0.29)
	var meadow := Color(0.74, 0.84, 0.44) if cute else Color(0.58, 0.62, 0.34)
	var deep := Color(0.40, 0.66, 0.38) if cute else Color(0.30, 0.46, 0.25)
	var dirt := Color(0.86, 0.72, 0.50) if cute else Color(0.66, 0.54, 0.38)
	var rock := Color(0.66, 0.64, 0.66) if cute else Color(0.52, 0.50, 0.48)
	var sand := Color(0.95, 0.86, 0.64)
	var town := Color(0.80, 0.72, 0.58)
	var farm: Vector2 = landmark("farm")["tile"]
	var wood: Vector2 = landmark("wood")["tile"]
	var lake: Vector2 = landmark("lake")["tile"]
	for j in TN.y + 1:
		for i in TN.x + 1:
			var idx := j * stride + i
			var p := Vector2(T0.x + i, T0.y + j)
			var y := h[idx]
			var m := detail.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			var col := grass.lerp(meadow, smoothstep(0.55, 0.8, m)).lerp(deep, smoothstep(0.45, 0.2, m))
			if p.distance_to(wood) < 20.0:
				col = col.lerp(deep.darkened(0.08), 1.0 - smoothstep(12.0, 20.0, p.distance_to(wood)))
			var slope := absf(h[_idx(i + 1, j)] - h[_idx(i - 1, j)]) + absf(h[_idx(i, j + 1)] - h[_idx(i, j - 1)])
			col = col.lerp(rock, smoothstep(1.4, 2.4, slope))
			col = col.lerp(rock, smoothstep(10.0, 13.0, y))
			col = col.lerp(Color(0.97, 0.97, 1.0), smoothstep(19.0, 22.0, y))
			if p.distance_to(lake) < 19.0 and y < 0.4:
				col = col.lerp(sand, 1.0 - smoothstep(-0.2, 0.4, y))
			var fd := p.distance_to(farm)
			if fd < 11.0:
				var patch := (int(floor((p.x - farm.x) / 4.0)) + int(floor((p.y - farm.y) / 3.0))) % 2 == 0
				var crop := Color(0.95, 0.82, 0.40) if patch else Color(0.62, 0.80, 0.36)
				col = col.lerp(crop, 1.0 - smoothstep(8.0, 11.0, fd))
			col = col.lerp(town, _town_mask(p, TOWN_RECT))
			for c in cities:
				col = col.lerp(c["ground"], _town_mask(p, c["rect"]))
			col = col.lerp(dirt, road[idx])
			colors[idx] = col


## Deck height when px is on a bridge, else a big negative number.
func _bridge_h(px: Vector2) -> float:
	if bridge_list.is_empty():
		return -99.0
	var p := px / TILE
	for br in bridge_list:
		if _seg_d(p, br[0], br[1]) < 0.55:
			return 0.18
	return -99.0


func _on_bridge(p: Vector2) -> bool:
	for c in cities:
		var L: Dictionary = layouts[c["id"]]
		for br in L["bridges"]:
			var lp: Vector2 = p - c["origin"]
			if _seg_d(lp, br["pos"] - br["dir"] * 5.0, br["pos"] + br["dir"] * 5.0) < 1.15:
				return true
	return false


## A soft, wobbly oval round a town instead of a square patch of ground.
func _town_mask(p: Vector2, r: Rect2) -> float:
	var c := r.get_center()
	var hx := r.size.x * 0.58
	var hy := r.size.y * 0.58
	var d := sqrt(pow((p.x - c.x) / hx, 2.0) + pow((p.y - c.y) / hy, 2.0))
	d += (detail.get_noise_2d(p.x * 1.7, p.y * 1.7) * 0.5) * 0.35
	return 1.0 - smoothstep(0.72, 1.0, d)


func _mark_solid() -> void:
	solid.resize(TN.x * TN.y)
	solid.fill(0)
	for j in TN.y:
		for i in TN.x:
			var a := h[j * stride + i]
			var b := h[j * stride + i + 1]
			var c := h[(j + 1) * stride + i]
			var d := h[(j + 1) * stride + i + 1]
			var lo := minf(minf(a, b), minf(c, d))
			var hi := maxf(maxf(a, b), maxf(c, d))
			var on_road := maxf(maxf(road[j * stride + i], road[(j + 1) * stride + i + 1]), 0.0) > 0.35
			if on_road or _on_bridge(Vector2(T0.x + i + 0.5, T0.y + j + 0.5)):
				continue
			if lo < WATER + 0.1 or hi - lo > 1.7 or (a + b + c + d) * 0.25 > 12.0:
				solid[j * TN.x + i] = 1


## True when the tile at tile coords is blocked by water, cliffs or peaks.
## The nearest standing tree within r (px) of p, in front of heading hd.
func tree_near(p: Vector2, r: float, hd: Vector2) -> Dictionary:
	var best := {}
	var bd := r
	for t in trees:
		if t["gone"]:
			continue
		var d: Vector2 = t["pos"] - p
		var l := d.length()
		if l < bd and (l < 34.0 or d.normalized().dot(hd) > 0.2):
			bd = l
			best = t
	return best


func set_tree_standing(t: Dictionary, standing: bool) -> void:
	t["gone"] = not standing
	var o: Vector3 = t["o"]
	var sc := Vector3(t["w"], t["h"], 1.0) if standing else Vector3.ZERO
	t["mm"].set_instance_transform(t["q"], Transform3D(Basis().scaled(sc), o))
	var tile: Vector2i = t["tile"]
	solid[(tile.y - T0.y) * TN.x + (tile.x - T0.x)] = 1 if standing else 0


func tile_solid(t: Vector2i) -> bool:
	var i := t.x - T0.x
	var j := t.y - T0.y
	if i < 0 or j < 0 or i >= TN.x or j >= TN.y:
		return true
	return solid[j * TN.x + i] == 1


func road_at(px: Vector2) -> float:
	var i := int(round(px.x / TILE)) - T0.x
	var j := int(round(px.y / TILE)) - T0.y
	return road[_idx(i, j)]


func _make_map_image() -> void:
	map_image = Image.create(TN.x, TN.y, false, Image.FORMAT_RGB8)
	for j in TN.y:
		for i in TN.x:
			var idx := j * stride + i
			var y := h[idx]
			var col := colors[idx]
			if y < WATER:
				col = Color(0.45, 0.68, 0.88)
			var shade := clampf((h[_idx(i + 1, j + 1)] - h[_idx(i - 1, j - 1)]) * 0.12, -0.25, 0.25)
			col = col.darkened(maxf(0.0, shade)).lightened(maxf(0.0, -shade))
			if fmod(y + 0.5 + 100.0, 2.2) < 0.18 and y > WATER:
				col = col.darkened(0.15)
			map_image.set_pixel(i, j, col)


# ---------- 3D build ----------

func build(parent: Node3D, bake_root: Node, grain: Texture2D) -> void:
	var tmat := ShaderMaterial.new()
	tmat.shader = load("res://shaders/terrain.gdshader")
	tmat.set_shader_parameter("grain", grain)
	for cj in range(0, TN.y, CHUNK):
		for ci in range(0, TN.x, CHUNK):
			parent.add_child(_chunk_mesh(ci, cj, mini(ci + CHUNK, TN.x), mini(cj + CHUNK, TN.y), tmat))
	_build_water(parent, grain)
	_build_props(parent, bake_root, grain)
	_build_backdrop(parent, bake_root)


func _chunk_mesh(i0: int, j0: int, i1: int, j1: int, mat: Material) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idxs := PackedInt32Array()
	var w := i1 - i0 + 1
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var x := (T0.x + i) * 1.5
			var z := (T0.y + j) * 1.5
			var y := h[_idx(i, j)]
			verts.append(Vector3(x, y, z))
			var nx := h[_idx(i - 1, j)] - h[_idx(i + 1, j)]
			var nz := h[_idx(i, j - 1)] - h[_idx(i, j + 1)]
			norms.append(Vector3(nx, 3.0, nz).normalized())
			cols.append(colors[_idx(i, j)])
			uvs.append(Vector2(x, z) * 0.11)
	for j in range(j1 - j0):
		for i in range(i1 - i0):
			var a := j * w + i
			idxs.append_array(PackedInt32Array([a, a + 1, a + w, a + 1, a + w + 1, a + w]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idxs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	return mi


func _build_water(parent: Node3D, grain: Texture2D) -> void:
	var lake: Vector2 = landmark("lake")["tile"]
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(36, 36)
	pm.subdivide_width = 24
	pm.subdivide_depth = 24
	mi.mesh = pm
	mi.position = Vector3(lake.x * 1.5, WATER, lake.y * 1.5)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("grain", grain)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	for c in cities:
		var L: Dictionary = layouts[c["id"]]
		var rv: Array = L["river"]
		if rv.size() < 2:
			continue
		var o: Vector2 = c["origin"]
		var hw: float = float(L["river_w"]) * 0.5 + 1.0
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idxs := PackedInt32Array()
		var samples: Array = []
		for i in rv.size() - 1:
			for k in 8:
				samples.append((rv[i] as Vector2).lerp(rv[i + 1], float(k) / 8.0))
		samples.append(rv[rv.size() - 1])
		for i in samples.size():
			var a: Vector2 = samples[maxi(0, i - 1)]
			var b: Vector2 = samples[mini(samples.size() - 1, i + 1)]
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x)
			var pt: Vector2 = (o + samples[i]) * 1.5
			verts.append(Vector3(pt.x - n.x * hw * 1.5, WATER, pt.y - n.y * hw * 1.5))
			verts.append(Vector3(pt.x + n.x * hw * 1.5, WATER, pt.y + n.y * hw * 1.5))
			uvs.append(Vector2(0, float(i)))
			uvs.append(Vector2(1, float(i)))
			if i > 0:
				var q := (i - 1) * 2
				idxs.append_array(PackedInt32Array([q, q + 2, q + 1, q + 1, q + 2, q + 3]))
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idxs
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var rmi := MeshInstance3D.new()
		rmi.mesh = am
		rmi.material_override = m
		rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(rmi)


## Picks a prop for a tile, or "" for nothing. Returns [atlas index, scale].
func _pick_prop(p: Vector2, y: float, slope: float) -> int:
	var wood: Vector2 = landmark("wood")["tile"]
	var lake: Vector2 = landmark("lake")["tile"]
	var ruins: Vector2 = landmark("ruins")["tile"]
	var forest := noise.get_noise_2d(p.x * 2.3 + 50.0, p.y * 2.3) * 0.5 + 0.5
	forest = smoothstep(0.55, 0.8, forest) * 0.22
	forest += (1.0 - smoothstep(6.0, 18.0, p.distance_to(wood))) * 0.55
	forest += smoothstep(40.0, 70.0, p.distance_to(TOWN_C)) * 0.05
	var r := rng.randf()
	if y > 12.0 or slope > 1.6:
		return 5 if r < 0.05 else (3 if r < 0.08 and y < 16.0 else -1)
	if p.distance_to(lake) < 17.0 and y < 0.6 and y > WATER - 0.1:
		return 9 if r < 0.25 else -1
	if r < forest:
		if y > 6.0 or p.y < TOWN_C.y - 45.0:
			return 3
		if p.distance_to(ruins) < 18.0:
			return 10
		var r2 := rng.randf()
		if r2 < 0.12:
			return 1
		return 0 if r2 < 0.55 else (2 if r2 < 0.85 else 3)
	r = rng.randf()
	if r < 0.16:
		return 7
	if r < 0.205:
		return 6
	if r < 0.22:
		return 4
	if r < 0.232:
		return 5
	if r < 0.240 and p.distance_to(wood) < 22.0:
		return 8
	if r < 0.244:
		return 11
	return -1


func _build_props(parent: Node3D, bake_root: Node, grain: Texture2D) -> void:
	var items: Array = []
	for a in PaintProps.ATLAS:
		items.append([a[0], {"cute": cute}])
	var atlas := Bake.make_atlas(bake_root, items, Vector2i(256, 320))
	props_material = ShaderMaterial.new()
	props_material.shader = load("res://shaders/props.gdshader")
	props_material.set_shader_parameter("atlas", atlas)
	props_atlas = atlas
	props_material.set_shader_parameter("grain", grain)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.center_offset = Vector3(0, 0.5, 0)
	var n := float(PaintProps.ATLAS.size())
	var buckets := {}
	for j in range(1, TN.y - 1):
		for i in range(1, TN.x - 1):
			var p := Vector2(T0.x + i + rng.randf_range(0.1, 0.9), T0.y + j + rng.randf_range(0.1, 0.9))
			if town_dist(p) < 3.0:
				continue
			var idx := j * stride + i
			if road[idx] > 0.02 or road[_idx(i + 1, j + 1)] > 0.02:
				continue
			var near_lm := false
			for l in landmarks:
				if p.distance_to(l["tile"]) < float(l["r"]) * (0.4 if l["id"] in ["wood", "lake"] else 0.85):
					near_lm = true
			if near_lm:
				continue
			var y := height_at(p * TILE)
			if y < WATER + 0.05 and y > WATER - 0.3:
				pass
			elif y < WATER:
				continue
			var slope := absf(h[_idx(i + 1, j)] - h[_idx(i - 1, j)]) + absf(h[_idx(i, j + 1)] - h[_idx(i, j - 1)])
			var k := _pick_prop(p, y, slope)
			if k < 0:
				continue
			var a: Array = PaintProps.ATLAS[k]
			var s := rng.randf_range(0.82, 1.2)
			var key := Vector2i(i / CHUNK, j / CHUNK)
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append([Vector3(p.x * 1.5, y - 0.06, p.y * 1.5), float(a[2]) * s, float(a[1]) * s, k, i, j])
			if k <= 3 or k == 10:
				solid[(j) * TN.x + i] = 1
	for key in buckets:
		var list: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = list.size()
		for q in list.size():
			var e: Array = list[q]
			var b := Basis().scaled(Vector3(e[1], e[2], 1.0))
			mm.set_instance_transform(q, Transform3D(b, e[0]))
			mm.set_instance_custom_data(q, Color(float(e[3]) / n, 1.0 / n, rng.randf(), 0.0))
			if int(e[3]) <= 3 or int(e[3]) == 10:
				var o: Vector3 = e[0]
				trees.append({"mm": mm, "q": q, "pos": Vector2(o.x, o.z) / K, "hp": 3, "i": int(e[4]), "j": int(e[5]),
					"k": int(e[3]), "w": float(e[1]), "h": float(e[2]), "o": o, "gone": false, "regrow": 0.0,
					"cd": Color(float(e[3]) / n, 1.0 / n, 0.0, 0.0), "tile": Vector2i(T0.x + int(e[4]), T0.y + int(e[5]))})
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = props_material
		parent.add_child(mmi)


func _build_backdrop(parent: Node3D, bake_root: Node) -> void:
	var center := Vector3((T0.x + TN.x * 0.5) * 1.5, 0.0, (T0.y + TN.y * 0.5) * 1.5)
	var rings := [
		[205.0, Color(0.56, 0.66, 0.60) if cute else Color(0.42, 0.50, 0.44), 46.0, false],
		[245.0, Color(0.62, 0.70, 0.84), 70.0, true],
		[290.0, Color(0.74, 0.80, 0.92), 96.0, true],
	]
	for r in rings.size():
		var ring: Array = rings[r]
		var tex := Bake.make(bake_root, "range", {"col": ring[1], "snow": ring[3], "seed": seed_value + r * 13}, Vector2i(1024, 256))
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var radius: float = ring[0]
		var segs := 18
		var w := TAU * radius / segs * 1.12
		for s in segs:
			var a := TAU * (s + r * 0.33) / segs
			var mi := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(w, ring[2])
			mi.mesh = qm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			mi.position = center + Vector3(cos(a) * radius, float(ring[2]) * 0.5 - 6.0, sin(a) * radius)
			mi.look_at(Vector3(center.x, mi.position.y, center.z), Vector3.UP)
