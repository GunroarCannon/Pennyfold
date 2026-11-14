## Cut-outs for the open world: nature props (baked into one atlas for the
## MultiMesh scatter), building surfaces (walls, shingles, awnings, cobbles),
## landmark pieces (windmill sails, mine mouth, ruin pillars, quest board),
## far mountain ranges and small effect sprites (puff, slash, glow).
class_name PaintProps
extends RefCounted

const INK := Paint.INK
const WOOD := Paint.WOOD

## Atlas order for the scatter. [name, world height, world width].
const ATLAS := [
	["tree_a", 4.4, 3.4], ["tree_b", 4.0, 3.2], ["tree_c", 4.6, 3.4], ["pine", 5.2, 2.8],
	["bush", 1.1, 1.9], ["rock", 1.0, 1.5], ["flowers", 0.62, 0.9], ["grass", 0.6, 0.85],
	["mushrooms", 0.55, 0.75], ["reed", 1.3, 0.9], ["deadtree", 3.8, 2.8], ["stump", 0.7, 0.9],
]


static func V(x: float, y: float) -> Vector2:
	return Vector2(x, y)


static func E(cx: float, cy: float, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	return Paint._e(cx, cy, rx, ry, n)


static func R(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return Paint._r(x, y, w, h)


static func paint(c: CanvasItem, kind: String, p: Dictionary, size: Vector2) -> bool:
	var cute: bool = p.get("cute", true)
	match kind:
		"tree_a":
			Paint._tree(c, {"col": Color(0.50, 0.78, 0.40) if cute else Color(0.36, 0.54, 0.28), "dot": Color(0.95, 0.30, 0.25)}, size)
		"tree_b":
			Paint._tree(c, {"col": Color(0.98, 0.70, 0.78) if cute else Color(0.62, 0.66, 0.30), "dot": Color(1.0, 0.92, 0.94)}, size)
		"tree_c":
			Paint._tree(c, {"col": Color(0.36, 0.64, 0.44) if cute else Color(0.24, 0.40, 0.24), "dot": Color(0.99, 0.88, 0.35)}, size)
		"pine":
			_pine(c, cute, size)
		"bush":
			Paint._bush(c, {"col": Color(0.46, 0.74, 0.40) if cute else Color(0.32, 0.50, 0.28), "dot": Color(0.99, 0.95, 0.6)}, size)
		"rock":
			_rock(c, size)
		"flowers":
			_flowers(c, size)
		"grass":
			_grass(c, cute, size)
		"mushrooms":
			_mushrooms(c, size)
		"reed":
			_reed(c, size)
		"deadtree":
			_deadtree(c, size)
		"stump":
			_stump(c, size)
		"wall":
			_wall(c, p, size)
		"shingles":
			_shingles(c, p, size)
		"awning":
			_awning(c, p, size)
		"cobble":
			_cobble(c, p, size)
		"board":
			_board(c, size)
		"sails":
			_sails(c, size)
		"mine":
			_mine(c, size)
		"pillar":
			_pillar(c, p, size)
		"arch":
			_arch(c, size)
		"crate":
			_crate(c, size)
		"barrel":
			_barrel(c, size)
		"lamp":
			_lamp(c, size)
		"well":
			_well(c, size)
		"node":
			_node(c, p, size)
		"range":
			_range(c, p, size)
		"puff":
			_puff(c, size)
		"slash":
			_slash(c, size)
		"glow":
			_glow(c, p, size)
		"marker":
			_marker(c, size)
		"signboard":
			_signboard(c, size)
		_:
			return false
	return true


# ---------- nature ----------

static func _pine(c: CanvasItem, cute: bool, size: Vector2) -> void:
	Paint._begin(c, size, 80.0, 150.0)
	var col := Color(0.30, 0.62, 0.46) if cute else Color(0.18, 0.36, 0.24)
	var sh: Array = [[R(-6, -26, 12, 26), WOOD]]
	for i in 4:
		var y := -24.0 - i * 28.0
		var w := 38.0 - i * 7.0
		sh.append([PackedVector2Array([V(-w, y), V(0, y - 46), V(w, y)]), col.lightened(i * 0.04)])
	Paint._cut(c, sh)
	if cute:
		for s in [V(-12, -40), V(14, -70), V(-6, -98)]:
			c.draw_circle(s, 3.0, Color(0.99, 0.95, 0.85))


static func _rock(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 100.0, 70.0)
	Paint._cut(c, [[PackedVector2Array([V(-46, 0), V(-40, -30), V(-18, -54), V(10, -60), V(34, -42), V(46, -14), V(42, 0)]), Color(0.66, 0.66, 0.68)],
		[PackedVector2Array([V(-22, -50), V(4, -58), V(-6, -36)]), Color(0.78, 0.78, 0.80)]])
	c.draw_line(V(-10, -30), V(4, -18), INK, 1.2, true)


static func _flowers(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 80.0, 60.0)
	var sh: Array = []
	var cols := [Color(0.98, 0.45, 0.55), Color(0.99, 0.85, 0.30), Color(0.62, 0.55, 0.95), Color(1, 1, 1)]
	for i in 6:
		var x := -30.0 + i * 12.0
		var y := -30.0 - float((i * 7) % 16)
		sh.append([R(x - 1, y, 2.2, -y), Color(0.36, 0.60, 0.28)])
		sh.append([E(x, y, 6.5, 6.5, 12), cols[i % cols.size()]])
	Paint._cut(c, sh)
	for i in 6:
		c.draw_circle(V(-30.0 + i * 12.0, -30.0 - float((i * 7) % 16)), 2.2, Color(0.99, 0.85, 0.3))


static func _grass(c: CanvasItem, cute: bool, size: Vector2) -> void:
	Paint._begin(c, size, 80.0, 56.0)
	var col := Color(0.50, 0.80, 0.40) if cute else Color(0.40, 0.58, 0.28)
	var pts := PackedVector2Array([V(-34, 0)])
	for i in 9:
		var x := -30.0 + i * 7.5
		pts.append(V(x - 3, -10))
		pts.append(V(x + float(i % 3 - 1) * 4.0, -30.0 - float((i * 13) % 20)))
		pts.append(V(x + 3, -10))
	pts.append(V(34, 0))
	Paint._cut(c, [[pts, col]])


static func _mushrooms(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 70.0, 56.0)
	var sh: Array = []
	for m in [[-14.0, 1.0], [10.0, 0.7], [24.0, 0.5]]:
		var x: float = m[0]
		var s: float = m[1]
		sh.append([R(x - 4 * s, -24 * s, 8 * s, 24 * s), Color(0.98, 0.94, 0.84)])
		sh.append([PaintCute.arc(x, -22 * s, 16 * s, 16 * s, PI, TAU, 12), Color(0.92, 0.34, 0.30)])
	Paint._cut(c, sh)
	c.draw_circle(V(-18, -32), 2.4, Color.WHITE)
	c.draw_circle(V(-9, -36), 2.0, Color.WHITE)


static func _reed(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 60.0, 110.0)
	var sh: Array = []
	for i in 5:
		var x := -20.0 + i * 10.0
		var h := 70.0 + float((i * 17) % 30)
		sh.append([R(x - 1.5, -h, 3, h), Color(0.42, 0.62, 0.30)])
		if i % 2 == 0:
			sh.append([E(x, -h - 6, 3.6, 10, 12), Color(0.52, 0.34, 0.20)])
	Paint._cut(c, sh)


static func _deadtree(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 90.0, 140.0)
	var bark := Color(0.48, 0.38, 0.30)
	Paint._cut(c, [[PackedVector2Array([V(-10, 0), V(10, 0), V(6, -70), V(30, -110), V(24, -114), V(2, -84), V(-2, -120), V(-8, -120), V(-6, -80), V(-28, -98), V(-32, -92), V(-6, -64)]), bark]])


static func _stump(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 70.0, 50.0)
	Paint._cut(c, [[R(-24, -30, 48, 30), WOOD], [E(0, -30, 24, 7, 16), Color(0.88, 0.72, 0.48)]])
	c.draw_arc(V(0, -30), 10.0, 0.0, TAU, 16, WOOD, 1.0, true)


# ---------- buildings ----------

## A wall face. Params: wall, trim, style (plain, timber, logs, stone),
## windows (count), door (bool), name (sign text), font, seed.
static func _wall(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	var wall: Color = p["wall"]
	var trim: Color = p["trim"]
	var style: String = p.get("style", "plain")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1))
	var W := size.x
	var H := size.y
	Paint._fill(c, R(0, 0, W, H), wall, 1.0 / 300.0)
	match style:
		"logs":
			var y := 0.0
			while y < H:
				c.draw_rect(Rect2(0, y, W, 22), wall.darkened(0.06 * float(int(y / 22) % 2)))
				c.draw_line(V(0, y + 22), V(W, y + 22), INK.lightened(0.2), 2.0)
				c.draw_circle(V(6, y + 11), 9.0, wall.lightened(0.15))
				c.draw_arc(V(6, y + 11), 9.0, 0.0, TAU, 14, INK, 1.5)
				y += 22.0
		"stone":
			var row := 0
			var yy := 0.0
			while yy < H:
				var x := -float(row % 2) * 22.0
				while x < W:
					var col := wall.darkened(rng.randf_range(0.0, 0.14))
					c.draw_rect(Rect2(x + 2, yy + 2, 40, 18), col)
					c.draw_rect(Rect2(x + 2, yy + 2, 40, 18), INK.lightened(0.15), false, 1.5)
					x += 44.0
				yy += 22.0
				row += 1
		"timber":
			for i in 120:
				var a := V(rng.randf() * W, rng.randf() * H)
				c.draw_line(a, a + V(16, -11), wall.darkened(0.08), 2.0, true)
			var beam := trim.darkened(0.35)
			c.draw_rect(Rect2(0, H * 0.48, W, 9), beam)
			c.draw_rect(Rect2(0, 0, 10, H), beam)
			c.draw_rect(Rect2(W - 10, 0, 10, H), beam)
			c.draw_line(V(10, H * 0.48), V(W * 0.3, 4), beam, 7.0)
			c.draw_line(V(W - 10, H * 0.48), V(W * 0.7, 4), beam, 7.0)
		_:
			for i in 120:
				var a := V(rng.randf() * W, rng.randf() * H)
				c.draw_line(a, a + V(16, -11), wall.darkened(0.12), 2.0, true)
			for i in 5:
				var br := Rect2(rng.randf_range(10, W - 40), rng.randf_range(H * 0.3, H - 30), 26, 12)
				c.draw_rect(br, Color(0.80, 0.42, 0.32))
				c.draw_rect(br, INK, false, 1.5)
	var nw: int = p.get("windows", 2)
	var door: bool = p.get("door", false)
	var slots: Array = []
	if nw == 1:
		slots = [0.5] if not door else [0.2]
	elif nw >= 2:
		slots = [0.2, 0.8] if door or nw == 2 else [0.2, 0.5, 0.8]
	for sx in slots:
		_window(c, V(W * sx, H * (0.36 if door else 0.42)), W * 0.17, H * 0.2, trim)
	if door:
		var dw := W * 0.26
		var dh := H * 0.44
		var dx := W * 0.5 - dw * 0.5
		var dy := H - dh
		var dc := trim.darkened(0.25)
		c.draw_rect(Rect2(dx, dy, dw, dh), dc)
		c.draw_circle(V(W * 0.5, dy), dw * 0.5, dc)
		c.draw_arc(V(W * 0.5, dy), dw * 0.5, PI, TAU, 18, INK, 3.0)
		c.draw_line(V(dx, dy), V(dx, H), INK, 3.0)
		c.draw_line(V(dx + dw, dy), V(dx + dw, H), INK, 3.0)
		for i in 3:
			var lx := dx + dw * (0.25 + 0.25 * i)
			c.draw_line(V(lx, dy - dw * 0.35), V(lx, H), dc.darkened(0.3), 1.5)
		c.draw_circle(V(dx + dw * 0.78, dy + dh * 0.5), 4.0, Color(0.95, 0.80, 0.3))
		c.draw_rect(Rect2(dx - 8, H - 8, dw + 16, 8), Color(0.62, 0.60, 0.58))
	var shop_name: String = p.get("name", "")
	if shop_name != "":
		var sr := Rect2(W * 0.16, H * 0.06, W * 0.68, H * 0.15)
		c.draw_rect(sr, Color(0.97, 0.90, 0.70))
		c.draw_rect(sr, INK, false, 3.0)
		var font: Font = p["font"]
		c.draw_string(font, V(sr.position.x, sr.position.y + sr.size.y * 0.76), shop_name, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(sr.size.y * 0.66), INK)
	c.draw_rect(Rect2(2, 2, W - 4, H - 4), INK, false, 4.0)


static func _window(c: CanvasItem, at: Vector2, ww: float, wh: float, trim: Color) -> void:
	var x := at.x - ww * 0.5
	var y := at.y - wh * 0.5
	for sx in [x - ww * 0.34, x + ww * 1.04]:
		c.draw_rect(Rect2(sx, y, ww * 0.3, wh), trim)
		c.draw_rect(Rect2(sx, y, ww * 0.3, wh), INK, false, 2.0)
	c.draw_rect(Rect2(x, y, ww, wh), Color(0.99, 0.93, 0.66))
	c.draw_line(V(x + ww * 0.5, y), V(x + ww * 0.5, y + wh), INK, 2.0)
	c.draw_line(V(x, y + wh * 0.5), V(x + ww, y + wh * 0.5), INK, 2.0)
	c.draw_rect(Rect2(x, y, ww, wh), INK, false, 3.0)
	# flower box
	c.draw_rect(Rect2(x - 4, y + wh, ww + 8, 9), WOOD)
	c.draw_rect(Rect2(x - 4, y + wh, ww + 8, 9), INK, false, 1.5)
	for i in 4:
		c.draw_circle(V(x + ww * (0.12 + 0.25 * i), y + wh - 1), 4.5, [Color(0.98, 0.45, 0.5), Color(0.99, 0.85, 0.3)][i % 2])


static func _shingles(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	var col: Color = p["col"]
	Paint._fill(c, R(0, 0, size.x, size.y), col.darkened(0.2), 1.0 / 300.0)
	var rows := 8
	var rh := size.y / rows
	var n := 8
	var rw := size.x / n
	for r in rows:
		for i in n + 1:
			var cx := i * rw + (rw * 0.5 if r % 2 == 1 else 0.0)
			var cy := r * rh
			var shade := col.darkened(0.08 * float((i + r) % 3))
			c.draw_rect(Rect2(cx - rw * 0.5, cy, rw, rh * 0.6), shade)
			c.draw_circle(V(cx, cy + rh * 0.6), rw * 0.5, shade)
			c.draw_arc(V(cx, cy + rh * 0.6), rw * 0.5, 0.0, PI, 10, INK.lightened(0.15), 2.0)


static func _awning(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	var a: Color = p.get("a", Color(0.95, 0.50, 0.62))
	var b: Color = p.get("b", Color(0.99, 0.96, 0.92))
	var W := size.x
	var H := size.y
	var n := 8
	var sw := W / n
	for i in n:
		var col := a if i % 2 == 0 else b
		var pts := PackedVector2Array([V(i * sw, 0), V((i + 1) * sw, 0), V((i + 1) * sw, H * 0.72)])
		for k in 7:
			var t := float(k) / 6.0
			pts.append(V((i + 1) * sw - t * sw, H * 0.72 + sin(t * PI) * H * 0.24))
		Paint._fill(c, pts, col, 1.0 / 200.0)
		c.draw_polyline(Paint._closed(pts), INK, 2.0, true)


static func _cobble(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	var base: Color = p.get("col", Color(0.74, 0.70, 0.64))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	c.draw_rect(Rect2(Vector2.ZERO, size), base.darkened(0.35))
	var n := 8
	var cell := size.x / n
	for gy in n:
		for gx in n:
			var cx := (gx + 0.5) * cell + rng.randf_range(-3, 3) + (cell * 0.5 if gy % 2 == 1 else 0.0)
			var cy := (gy + 0.5) * cell + rng.randf_range(-3, 3)
			var col := base.darkened(rng.randf_range(-0.06, 0.12))
			for wrap in [0.0, -size.x]:
				var pts := E(cx + wrap, cy, cell * 0.44, cell * 0.40, 12)
				c.draw_colored_polygon(pts, col)
				c.draw_polyline(Paint._closed(pts), INK.lightened(0.25), 1.6, true)
				c.draw_line(V(cx + wrap - 5, cy - 6), V(cx + wrap + 2, cy - 8), col.lightened(0.2), 2.0, true)


static func _board(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 110.0, 120.0)
	var sh: Array = [[R(-44, -120, 8, 120), WOOD], [R(36, -120, 8, 120), WOOD], [R(-52, -116, 104, 72), WOOD.lightened(0.15)]]
	var notes := [Color(0.99, 0.97, 0.88), Color(0.98, 0.90, 0.70), Color(0.92, 0.96, 0.99)]
	for i in 4:
		sh.append([R(-44 + i * 23.0, -108 + (i % 2) * 8.0, 19, 26), notes[i % 3]])
	Paint._cut(c, sh)
	for i in 4:
		var x := -44 + i * 23.0
		var y := -108 + (i % 2) * 8.0
		c.draw_circle(V(x + 9.5, y + 3), 2.2, Color(0.9, 0.2, 0.2))
		for k in 3:
			c.draw_line(V(x + 3, y + 10 + k * 5), V(x + 16, y + 10 + k * 5), INK.lightened(0.3), 1.0)


static func _sails(c: CanvasItem, size: Vector2) -> void:
	c.draw_set_transform(size * 0.5, 0.0, Vector2(size.x / 240.0, size.y / 240.0))
	var sh: Array = []
	for i in 4:
		var a := TAU * i / 4.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		sh.append([PackedVector2Array([d * 10 + n * 4, d * 112 + n * 4, d * 112 - n * 4, d * 10 - n * 4]), WOOD])
		sh.append([PackedVector2Array([d * 30 + n * 6, d * 110 + n * 6, d * 110 + n * 30, d * 30 + n * 24]), Color(0.98, 0.95, 0.88)])
	sh.append([E(0, 0, 13, 13, 16), WOOD.darkened(0.2)])
	Paint._cut(c, sh)


static func _mine(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 140.0, 120.0)
	var sh: Array = []
	sh.append([PackedVector2Array([V(-70, 0), V(-64, -70), V(-30, -112), V(20, -118), V(60, -84), V(70, 0)]), Color(0.60, 0.58, 0.56)])
	sh.append([PaintCute.arc(0, -10, 34, 74, PI, TAU, 16), Color(0.10, 0.08, 0.07)])
	sh.append([R(-40, -88, 10, 88), WOOD])
	sh.append([R(30, -88, 10, 88), WOOD])
	sh.append([R(-46, -96, 92, 12), WOOD.darkened(0.1)])
	Paint._cut(c, sh)
	c.draw_rect(Rect2(-60, -8, 120, 3), METAL_DARK())
	c.draw_line(V(-30, -20), V(-10, -30), Color(0.95, 0.8, 0.4), 2.0)


static func METAL_DARK() -> Color:
	return Color(0.40, 0.40, 0.44)


static func _pillar(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	Paint._begin(c, size, 50.0, 150.0)
	var stone := Color(0.80, 0.78, 0.72)
	var broken: bool = p.get("broken", false)
	var top := -96.0 if broken else -136.0
	var sh: Array = [[R(-22, -12, 44, 12), stone.darkened(0.1)], [R(-16, top, 32, -top - 12), stone]]
	if broken:
		sh.append([PackedVector2Array([V(-16, top), V(-6, top - 14), V(4, top - 4), V(16, top - 18), V(16, top)]), stone])
	else:
		sh.append([R(-22, top - 12, 44, 12), stone.darkened(0.1)])
	Paint._cut(c, sh)
	for x in [-8.0, 0.0, 8.0]:
		c.draw_line(V(x, top + 4), V(x, -16), stone.darkened(0.2), 1.4)
	c.draw_colored_polygon(E(-10, -60, 9, 5, 10), Color(0.48, 0.70, 0.36))


static func _arch(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 150.0, 140.0)
	var stone := Color(0.78, 0.76, 0.70)
	var pts := PackedVector2Array([V(-70, 0), V(-70, -96)])
	for q in PaintCute.arc(0, -96, 70, 40, PI, TAU, 16):
		pts.append(q)
	pts.append_array(PackedVector2Array([V(70, -96), V(70, 0), V(44, 0), V(44, -90)]))
	for q in PaintCute.arc(0, -90, 44, 24, TAU, PI, 16):
		pts.append(q)
	pts.append(V(-44, 0))
	Paint._cut(c, [[pts, stone]])
	c.draw_colored_polygon(E(40, -120, 14, 6, 12), Color(0.48, 0.70, 0.36))


static func _crate(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 60.0, 60.0)
	Paint._cut(c, [[R(-26, -50, 52, 50), WOOD.lightened(0.12)]])
	c.draw_line(V(-26, -50), V(26, 0), WOOD.darkened(0.25), 3.0)
	c.draw_line(V(-26, 0), V(26, -50), WOOD.darkened(0.25), 3.0)
	c.draw_rect(Rect2(-26, -50, 52, 50), WOOD.darkened(0.3), false, 3.0)


static func _barrel(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 50.0, 64.0)
	Paint._cut(c, [[PackedVector2Array([V(-18, 0), V(-22, -28), V(-18, -56), V(18, -56), V(22, -28), V(18, 0)]), WOOD]])
	for y in [-12.0, -44.0]:
		c.draw_line(V(-21, y), V(21, y), Color(0.40, 0.40, 0.44), 3.0)


static func _lamp(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 40.0, 150.0)
	var iron := Color(0.26, 0.26, 0.30)
	Paint._cut(c, [[R(-3, -120, 6, 120), iron], [R(-8, -6, 16, 6), iron],
		[PackedVector2Array([V(-11, -122), V(11, -122), V(8, -142), V(-8, -142)]), Color(0.99, 0.88, 0.50)],
		[PackedVector2Array([V(-13, -142), V(13, -142), V(0, -152)]), iron]])


static func _well(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 90.0, 110.0)
	Paint._cut(c, [[R(-34, -96, 6, 70), WOOD], [R(28, -96, 6, 70), WOOD],
		[PackedVector2Array([V(-44, -90), V(0, -112), V(44, -90)]), Color(0.66, 0.36, 0.26)],
		[R(-40, -40, 80, 40), Color(0.72, 0.70, 0.66)], [R(-6, -76, 12, 14), WOOD.darkened(0.1)]])
	for x in [-24.0, 0.0, 24.0]:
		c.draw_line(V(x, -40), V(x, 0), INK.lightened(0.3), 1.2)


## Gatherable: p.good = wheat, ore or herb.
static func _node(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	match String(p.get("good", "")):
		"wheat":
			Paint._begin(c, size, 60.0, 90.0)
			var sh: Array = []
			for i in 5:
				var x := -20.0 + i * 10.0
				sh.append([R(x - 1.2, -70, 2.4, 70), Color(0.78, 0.64, 0.30)])
				sh.append([E(x, -76, 4.5, 12, 12), Color(0.97, 0.82, 0.36)])
			Paint._cut(c, sh)
		"ore":
			_rock(c, size)
			for s in [V(-14, -30), V(8, -40), V(20, -20)]:
				c.draw_circle(s, 4.0, Color(0.98, 0.78, 0.32))
		_:
			Paint._begin(c, size, 60.0, 60.0)
			Paint._cut(c, [[E(-12, -18, 12, 8, 12), Color(0.46, 0.76, 0.38)], [E(12, -20, 12, 8, 12), Color(0.50, 0.80, 0.40)], [E(0, -32, 9, 13, 12), Color(0.56, 0.84, 0.44)]])
			c.draw_circle(V(0, -44), 3.0, Color(0.70, 0.55, 0.98))


## Far mountains for the backdrop ring. p.col, p.snow, p.seed.
static func _range(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	var W := size.x
	var H := size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 3))
	var col: Color = p["col"]
	var top := PackedVector2Array([V(0, H * 0.6)])
	var x := 0.0
	var peaks: Array = []
	while x < W:
		x += rng.randf_range(60, 140)
		var py := rng.randf_range(H * 0.12, H * 0.5)
		top.append(V(minf(x, W), py))
		peaks.append(V(minf(x, W), py))
		x += rng.randf_range(50, 110)
		top.append(V(minf(x, W), rng.randf_range(H * 0.5, H * 0.7)))
	var poly := PackedVector2Array(top)
	poly.append(V(W, H))
	poly.append(V(0, H))
	Paint._fill(c, poly, col, 1.0 / 500.0)
	if p.get("snow", false):
		for pk in peaks:
			if pk.y < H * 0.32:
				c.draw_colored_polygon(PackedVector2Array([pk, pk + V(26, 30), pk + V(10, 24), pk + V(-4, 34), pk + V(-24, 28)]), Color(0.98, 0.98, 1.0))
	c.draw_polyline(top, Color(0.99, 0.98, 0.94), 6.0, true)
	c.draw_polyline(top, INK, 2.0, true)


static func _puff(c: CanvasItem, size: Vector2) -> void:
	var cc := size * 0.5
	# Irregular multi-lobed paper cloud cutout (never a plain circle)
	var lobes: Array = [
		Vector2(-0.18, -0.15), Vector2(0.06, -0.22), Vector2(0.24, -0.06),
		Vector2(0.20, 0.17), Vector2(0.01, 0.24), Vector2(-0.21, 0.15),
		Vector2(-0.26, -0.02), Vector2(0.0, 0.0)
	]
	var rads: Array = [0.25, 0.27, 0.23, 0.22, 0.24, 0.25, 0.21, 0.30]
	var N := 44
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var shadow_pts := PackedVector2Array()
	var sh_off := Vector2(size.x * 0.035, size.y * 0.045)
	for i in N:
		var ang := TAU * float(i) / float(N)
		var dir := Vector2(cos(ang), sin(ang))
		var max_r := 0.0
		for li in lobes.size():
			var lp: Vector2 = lobes[li] * size.x
			var lr: float = rads[li] * size.x
			var d_proj := dir.dot(lp)
			var perp_sq := lp.length_squared() - d_proj * d_proj
			if lr * lr > perp_sq:
				var reach := d_proj + sqrt(maxf(0.0, lr * lr - perp_sq))
				if reach > max_r:
					max_r = reach
		var wobble := (sin(ang * 6.0) * 0.025 + cos(ang * 9.0) * 0.015) * size.x
		var pt := cc + dir * (max_r + wobble)
		outer.append(pt)
		shadow_pts.append(pt + sh_off)
		inner.append(cc + dir * ((max_r + wobble) * 0.88))
	c.draw_colored_polygon(shadow_pts, Color(0.17, 0.11, 0.07, 0.35))
	c.draw_colored_polygon(outer, Color(0.98, 0.97, 0.93))
	c.draw_polyline(Paint._closed(inner), Color(0.90, 0.88, 0.82), 1.5, true)
	c.draw_polyline(Paint._closed(outer), INK, 2.5, true)
	# Interior cartoon cloud swirls
	for li in [0, 1, 4]:
		var lpos = cc + lobes[li] * size.x
		var lr: float = rads[li] * size.x * 0.72
		var swirl := PackedVector2Array()
		for si in 7:
			var sa := lerpf(PI * 0.7, PI * 1.55, float(si) / 6.0)
			swirl.append(lpos + Vector2(cos(sa), sin(sa) * 0.85) * lr)
		c.draw_polyline(swirl, INK.lightened(0.25), 1.8, true)
	c.draw_circle(cc + Vector2(-size.x * 0.12, -size.y * 0.14), size.x * 0.09, Color(1, 1, 1, 0.95))


static func _slash(c: CanvasItem, size: Vector2) -> void:
	var cc := size * 0.5
	var r := size.x * 0.42
	var pts := PackedVector2Array()
	for i in 17:
		var a := lerpf(-PI * 0.8, PI * 0.1, float(i) / 16.0)
		pts.append(cc + Vector2(cos(a), sin(a)) * r)
	for i in 17:
		var a := lerpf(PI * 0.1, -PI * 0.8, float(i) / 16.0)
		var t := sin(float(i) / 16.0 * PI)
		pts.append(cc + Vector2(cos(a), sin(a)) * (r - t * size.x * 0.13))
	c.draw_colored_polygon(pts, Color(1, 1, 1))
	c.draw_polyline(Paint._closed(pts), INK, 3.0, true)


static func _glow(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	var col: Color = p.get("col", Color(1, 0.9, 0.4))
	var cc := size * 0.5
	for i in 12:
		var t := 1.0 - float(i) / 12.0
		c.draw_circle(cc, size.x * 0.5 * t, Color(col.r, col.g, col.b, 0.10 + 0.08 * (1.0 - t)))
	c.draw_circle(cc, size.x * 0.12, Color(1, 1, 1, 0.95))


## The quest marker: a bobbing cardboard arrow.
static func _marker(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 60.0, 80.0)
	Paint._cut(c, [[PackedVector2Array([V(-18, -78), V(18, -78), V(18, -40), V(30, -40), V(0, -4), V(-30, -40), V(-18, -40)]), Color(0.99, 0.80, 0.25)]])
	c.draw_circle(V(0, -60), 6.0, INK)


static func _signboard(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 80.0, 70.0)
	Paint._cut(c, [[R(-36, -56, 72, 52), Color(0.97, 0.90, 0.70)]])
	c.draw_line(V(-24, -56), V(-24, -70), INK, 2.0)
	c.draw_line(V(24, -56), V(24, -70), INK, 2.0)
