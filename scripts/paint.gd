## Paints cardboard cut-outs. Every shape gets a pale cardboard border with
## a dark rim (the cut edge), then a paper-grain fill and an ink line.
## Figures face right; the standee flips them in 3D.
class_name Paint
extends RefCounted

const INK := Color(0.17, 0.11, 0.06)
const RIM := Color(0.36, 0.26, 0.16)
const EDGE := Color(0.88, 0.79, 0.62)
const WOOD := Color(0.58, 0.40, 0.24)
const METAL := Color(0.74, 0.76, 0.80)
const BORDER := 2.4

## Jointed figures are painted as separate pieces, side by side in one
## texture (one column per piece). Each piece: name, pivot in figure units,
## layer (negative = behind the body). See rig().
const RIG_PARTS := {
	"person": [["back", Vector2(0, -99), -3], ["back_arm", Vector2(-10.5, -95), -2],
		["back_leg", Vector2(-5, -60), -1.5], ["front_leg", Vector2(5, -60), -1],
		["body", Vector2(0, -60), 0], ["front_arm", Vector2(9.75, -95), 1]],
	"wolf": [["tail", Vector2(-33, -36), -2], ["far_back", Vector2(-22, -30), -1],
		["far_front", Vector2(18, -30), -1], ["body", Vector2(0, -36), 0],
		["near_back", Vector2(-16, -30), 1], ["near_front", Vector2(26, -30), 1]],
	"troll": [["back_arm", Vector2(-26, -82), -2], ["back_leg", Vector2(-12.5, -34), -1.5],
		["front_leg", Vector2(13.5, -34), -1], ["body", Vector2(0, -60), 0],
		["front_arm", Vector2(22, -82), 1]],
	"chibi": [["back", Vector2(0, -47), -3], ["back_arm", Vector2(-9, -44), -2],
		["back_leg", Vector2(-5.5, -21), -1.5], ["front_leg", Vector2(5.5, -21), -1],
		["body", Vector2(0, -20), 0], ["head", Vector2(1, -48), 0.5], ["front_arm", Vector2(9, -44), 1]],
	"chibi_front": [["back", Vector2(0, -47), -3], ["back_arm", Vector2(-11, -45), 1],
		["back_leg", Vector2(-5, -21), -1], ["front_leg", Vector2(5, -21), -1],
		["body", Vector2(0, -20), 0], ["head", Vector2(0, -48), 2], ["front_arm", Vector2(11, -45), -1]],
	"chibi_back": [["back_arm", Vector2(-11, -45), 1], ["back_leg", Vector2(-5, -21), -1],
		["front_leg", Vector2(5, -21), -1], ["body", Vector2(0, -20), 0], ["head", Vector2(0, -48), 2],
		["back", Vector2(0, -47), 2.5], ["front_arm", Vector2(11, -45), 1]],
	"fluffox": [["tail", Vector2(-30, -40), -2], ["far_back", Vector2(-18, -24), -1],
		["far_front", Vector2(17, -24), -1], ["body", Vector2(0, -32), 0],
		["near_back", Vector2(-13, -24), 1], ["near_front", Vector2(21, -24), 1]],
	"pebblet": [["back_arm", Vector2(-26, -62), -2], ["back_leg", Vector2(-12.5, -22), -1.5],
		["front_leg", Vector2(11.5, -22), -1], ["body", Vector2(0, -50), 0], ["front_arm", Vector2(24, -62), 1]],
	"slime": [["body", Vector2(0, -2), 0]],
	"shroom": [["back_leg", Vector2(-6, -17), -1.5], ["front_leg", Vector2(6, -17), -1], ["body", Vector2(0, -17), 0]],
	"bat": [["far_wing", Vector2(-11, -46), -1], ["body", Vector2(0, -40), 0], ["near_wing", Vector2(11, -46), 1]],
	"boss": [["back_arm", Vector2(-36, -112), -2], ["body", Vector2(0, -60), 0], ["front_arm", Vector2(36, -112), 1]],
}
const UNITS := {"wolf": Vector2(122, 72), "troll": Vector2(100, 124), "chibi": Vector2(80, 118), "chibi_front": Vector2(80, 118), "chibi_back": Vector2(80, 118),
	"fluffox": Vector2(110, 80), "pebblet": Vector2(100, 110), "slime": Vector2(74, 66),
	"shroom": Vector2(74, 92), "bat": Vector2(124, 84), "boss": Vector2(170, 196)}

static var _part := ""
static var _ox := 0.0


## Rig description for a jointed kind: column size, and per piece its name,
## pivot in column pixels and layer.
static func rig(kind: String, p: Dictionary, col: Vector2) -> Dictionary:
	var parts: Array = []
	for d in RIG_PARTS[kind]:
		parts.append({"name": d[0], "pivot": unit_to_px(kind, p, col, d[1]), "z": float(d[2])})
	var swing := 0.3 if p.get("weapon", "") == "spear" else 1.0
	return {"kind": kind, "col": col, "parts": parts, "arm_swing": swing}


static func unit_to_px(kind: String, p: Dictionary, size: Vector2, u: Vector2) -> Vector2:
	var origin := Vector2(size.x * 0.5, size.y - 7.0)
	if kind == "person":
		var s := (size.y - 14.0) / 152.0
		return origin + Vector2(u.x * s * float(p.get("wide", 1.0)), u.y * s)
	var un: Vector2 = UNITS[kind]
	var s2 := minf((size.y - 14.0) / un.y, (size.x - 14.0) / un.x)
	return origin + u * s2


static func paint(c: CanvasItem, kind: String, p: Dictionary, size: Vector2) -> void:
	if p.has("parts"):
		var names: Array = p["parts"]
		for i in names.size():
			_part = names[i]
			_ox = size.x * i
			_paint_one(c, kind, p, size)
		_part = ""
		_ox = 0.0
		c.draw_set_transform(Vector2.ZERO)
		return
	_paint_one(c, kind, p, size)


## True when the current piece is `name` (or the whole figure is painted).
static func _on(name: String) -> bool:
	return _part == "" or _part == name


static func _paint_one(c: CanvasItem, kind: String, p: Dictionary, size: Vector2) -> void:
	match kind:
		"person":
			_person(c, p, size)
		"wolf":
			PaintBeasts.wolf(c, size)
		"troll":
			PaintBeasts.troll(c, size)
		"tree":
			_tree(c, p, size)
		"bush":
			_bush(c, p, size)
		"fence":
			_fence(c, size)
		"facade":
			_facade(c, p, size)
		"hills":
			_hills(c, size)
		"cloud":
			_cloud(c, size)
		"sun":
			_sun(c)
		"star":
			_star(c)
		"chibi":
			PaintCute.chibi(c, p, size)
		"chibi_front":
			PaintCute.chibi_front(c, p, size, false)
		"chibi_back":
			PaintCute.chibi_front(c, p, size, true)
		"fluffox":
			PaintBeasts.fluffox(c, size)
		"pebblet":
			PaintBeasts.pebblet(c, size)
		"slime":
			PaintBeasts.slime(c, p, size)
		"shroom":
			PaintBeasts.shroom(c, p, size)
		"bat":
			PaintBeasts.bat(c, p, size)
		"boss":
			PaintBeasts.boss(c, p, size)
		"item":
			PaintCute.item(c, p, size)
		_:
			PaintProps.paint(c, kind, p, size)


# ---------- helpers ----------

static func _begin(c: CanvasItem, size: Vector2, units_w: float, units_h: float) -> void:
	var s := minf((size.y - 14.0) / units_h, (size.x - 14.0) / units_w)
	c.draw_set_transform(Vector2(size.x * 0.5 + _ox, size.y - 7.0), 0.0, Vector2(s, s))


static func _r(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func _e(cx: float, cy: float, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(pts)
	out.append(pts[0])
	return out


## Rounds every corner of a closed polygon, the sharper the corner the more.
## Hand-cut cardboard has no needle tips: scissors leave soft, slightly
## irregular points. r is the base cut-back distance in figure units; it is
## capped per corner so short edges are never eaten. Near-straight corners
## (smooth ellipses) are left alone.
static func soften(pts: PackedVector2Array, r: float = 3.0) -> PackedVector2Array:
	if pts.size() < 3 or r <= 0.0:
		return pts
	# drop repeated points (leaf tips repeat), which break triangulation
	var src := PackedVector2Array()
	for q in pts:
		if src.is_empty() or src[src.size() - 1].distance_squared_to(q) > 0.0025:
			src.append(q)
	if src.size() > 1 and src[0].distance_squared_to(src[src.size() - 1]) <= 0.0025:
		src.remove_at(src.size() - 1)
	var base := pts
	pts = src
	var n := pts.size()
	if n < 3:
		return base
	var out := PackedVector2Array()
	for i in n:
		var p := pts[i]
		var da := pts[(i + n - 1) % n] - p
		var db := pts[(i + 1) % n] - p
		var la := da.length()
		var lb := db.length()
		if la < 0.01 or lb < 0.01:
			out.append(p)
			continue
		var ua := da / la
		var ub := db / lb
		var cosang := ua.dot(ub)
		if cosang < -0.92:
			out.append(p)
			continue
		var sharp := (1.0 + cosang) * 0.5
		var d := minf(r * (0.55 + sharp * 1.3), 0.42 * minf(la, lb))
		if d < 0.2:
			out.append(p)
			continue
		var a := p + ua * d
		var b := p + ub * d
		for k in 6:
			var t := float(k) / 5.0
			out.append(a * (1.0 - t) * (1.0 - t) + p * 2.0 * t * (1.0 - t) + b * t * t)
	if Geometry2D.triangulate_polygon(out).is_empty():
		if not Geometry2D.triangulate_polygon(pts).is_empty():
			return pts
		return base
	return out


static func _outline(c: CanvasItem, pts: PackedVector2Array, col: Color, r: float) -> void:
	c.draw_colored_polygon(pts, col)
	c.draw_polyline(_closed(pts), col, r * 2.0, true)
	# round the joins; softened outlines are dense, so every third point is plenty
	var step := 1 if pts.size() < 24 else 3
	for i in range(0, pts.size(), step):
		c.draw_circle(pts[i], r, col)


static func _fill(c: CanvasItem, pts: PackedVector2Array, col: Color, uv_scale: float = 1.0 / 140.0) -> void:
	var uvs := PackedVector2Array()
	for pt in pts:
		uvs.append(pt * uv_scale + Vector2(0.5, 0.8))
	c.draw_polygon(pts, PackedColorArray([col]), uvs, Cardboard.paper())


## shapes: Array of [PackedVector2Array, Color] or [pts, Color, piece].
## Untagged shapes belong to the "body" piece.
static func _cut(c: CanvasItem, all: Array) -> void:
	var shapes: Array = []
	for s in all:
		if _on(s[2] if s.size() > 2 else "body"):
			var q: Array = s.duplicate()
			q[0] = soften(s[0], 2.2)
			shapes.append(q)
	for s in shapes:
		_outline(c, s[0], RIM, BORDER + 0.9)
	for s in shapes:
		_outline(c, s[0], EDGE, BORDER)
	for s in shapes:
		_fill(c, s[0], s[1])
		c.draw_polyline(_closed(s[0]), INK, 0.9, true)


# ---------- people ----------

## Realistic proportions (about 7 heads tall), blank faces: no eyes, no
## mouth, no expression. Units: feet at y=0, top of head near y=-121.
## Params: skin, cloth, pants, hair, hat (short, long, bald, toque, helmet,
## hood, cap), hat_col, weapon, apron, cape, beard, dress, wide (0.85-1.2).
static func _person(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	var units_h := 152.0
	var s := (size.y - 14.0) / units_h
	var wide: float = p.get("wide", 1.0)
	c.draw_set_transform(Vector2(size.x * 0.5 + _ox, size.y - 7.0), 0.0, Vector2(s * wide, s))
	var skin: Color = p.get("skin", Color(0.95, 0.8, 0.64))
	var cloth: Color = p.get("cloth", Color(0.4, 0.5, 0.7))
	var pants: Color = p.get("pants", Color(0.3, 0.25, 0.22))
	var hair: Color = p.get("hair", Color(0.3, 0.2, 0.12))
	var hat: String = p.get("hat", "short")
	var hat_col: Color = p.get("hat_col", hair)
	var weapon: String = p.get("weapon", "none")
	var shoe := Color(0.22, 0.15, 0.09)
	var back_cloth := cloth.darkened(0.18)
	var sh: Array = []
	if p.has("cape"):
		sh.append([PackedVector2Array([Vector2(-12, -98), Vector2(12, -98), Vector2(17, -36), Vector2(-17, -36)]), p["cape"], "back"])
	if hat == "long":
		sh.append([PackedVector2Array([Vector2(-8, -118), Vector2(4, -121), Vector2(6, -108), Vector2(4, -92), Vector2(-9, -90), Vector2(-10, -104)]), hair, "back"])
	# back arm, hanging
	sh.append([PackedVector2Array([Vector2(-13, -97), Vector2(-8, -97), Vector2(-11, -60), Vector2(-16, -60)]), back_cloth, "back_arm"])
	sh.append([_e(-13.5, -56, 3.0, 4.2, 12), skin.darkened(0.08), "back_arm"])
	# legs, tapered
	sh.append([PackedVector2Array([Vector2(-9.5, -62), Vector2(-0.5, -62), Vector2(-2, -5), Vector2(-8.5, -5)]), pants.darkened(0.1), "back_leg"])
	sh.append([PackedVector2Array([Vector2(0.5, -62), Vector2(9.5, -62), Vector2(8, -5), Vector2(1.5, -5)]), pants, "front_leg"])
	sh.append([_r(-10, -5, 9.5, 5), shoe, "back_leg"])
	sh.append([_r(1, -5, 11, 5), shoe, "front_leg"])
	if p.get("dress", false):
		sh.append([PackedVector2Array([Vector2(-10, -64), Vector2(10, -64), Vector2(15, -24), Vector2(-15, -24)]), cloth.darkened(0.06)])
	# torso
	sh.append([PackedVector2Array([Vector2(-10, -58), Vector2(10, -58), Vector2(12, -96), Vector2(8, -100), Vector2(-8, -100), Vector2(-12, -96)]), cloth])
	if p.has("apron"):
		sh.append([PackedVector2Array([Vector2(-8, -38), Vector2(9, -38), Vector2(8, -92), Vector2(-6, -92)]), p["apron"]])
	sh.append([_r(-10.5, -64, 21, 3), Color(0.30, 0.19, 0.10)])
	# neck and head (profile toward +x, blank)
	sh.append([_r(-2.5, -105, 6, 7), skin])
	if hat == "hood":
		sh.append([PackedVector2Array([Vector2(-11, -96), Vector2(-11, -114), Vector2(-5, -124), Vector2(5, -125), Vector2(11, -117), Vector2(10, -98)]), hat_col])
	sh.append([PackedVector2Array([Vector2(-6.5, -106), Vector2(-7.5, -116), Vector2(-4, -121.5), Vector2(3, -122), Vector2(7.5, -117), Vector2(8, -112), Vector2(9.5, -110), Vector2(8, -108.5), Vector2(7.5, -105), Vector2(3, -102.5), Vector2(-2, -103)]), skin])
	if p.get("beard", false):
		sh.append([PackedVector2Array([Vector2(-2, -108), Vector2(7.5, -107), Vector2(7, -102), Vector2(2, -99.5), Vector2(-2.5, -103)]), hair])
	match hat:
		"short", "long":
			sh.append([PackedVector2Array([Vector2(-7.5, -108), Vector2(-8, -117), Vector2(-4, -122.5), Vector2(3, -123), Vector2(8, -118.5), Vector2(8.5, -115.5), Vector2(3, -117), Vector2(-2, -115.5), Vector2(-3.5, -110)]), hair])
		"toque":
			sh.append([_e(0.5, -129, 9.5, 6), hat_col])
			sh.append([_r(-7, -126, 15, 5), hat_col])
		"helmet":
			sh.append([PackedVector2Array([Vector2(-8, -110), Vector2(-8, -118), Vector2(-4, -124), Vector2(4, -124), Vector2(8.5, -118), Vector2(8.5, -112), Vector2(-8, -112)]), hat_col])
			sh.append([_r(6.5, -115, 2, 7), hat_col])
		"cap":
			sh.append([_e(0.5, -119.5, 8.5, 4), hat_col])
			sh.append([PackedVector2Array([Vector2(4, -119.5), Vector2(13, -119), Vector2(12.5, -117), Vector2(4, -117.5)]), hat_col.darkened(0.2)])
	var w0 := sh.size()
	match weapon:
		"axe":
			sh.append([_r(11.5, -92, 3, 46), WOOD])
			sh.append([PackedVector2Array([Vector2(13, -94), Vector2(23, -99), Vector2(25, -85), Vector2(13, -86)]), METAL])
		"spear":
			sh.append([_r(11.8, -138, 2.6, 128), WOOD])
			sh.append([PackedVector2Array([Vector2(10.5, -138), Vector2(13.1, -150), Vector2(15.7, -138)]), METAL])
		"hammer":
			sh.append([_r(11.5, -82, 3, 30), WOOD])
			sh.append([_r(6.5, -88, 13, 7), Color(0.42, 0.42, 0.47)])
		"pin":
			sh.append([_r(4, -58, 19, 4), WOOD.lightened(0.25)])
		"mug":
			sh.append([_r(11, -63, 8, 9), WOOD])
			sh.append([_e(15, -63.5, 4.5, 2, 12), Color(0.98, 0.95, 0.85)])
		"sword":
			sh.append([PackedVector2Array([Vector2(12, -60), Vector2(15, -60), Vector2(15, -100), Vector2(13.5, -105), Vector2(12, -100)]), METAL])
			sh.append([_r(9.5, -61, 8, 2.5), Color(0.5, 0.35, 0.15)])
	for i in range(w0, sh.size()):
		sh[i].append("front_arm")
	# front arm, hanging
	sh.append([PackedVector2Array([Vector2(7, -97), Vector2(12.5, -97), Vector2(15.5, -60), Vector2(10.5, -60)]), cloth, "front_arm"])
	sh.append([_e(13, -56, 3.2, 4.4, 12), skin, "front_arm"])
	_cut(c, sh)
	if not _on("body"):
		return
	# fabric fold lines only, the face stays blank
	c.draw_line(Vector2(-3, -100), Vector2(1, -94), INK, 0.6, true)
	c.draw_line(Vector2(0.5, -60), Vector2(0.8, -34), INK.lightened(0.2), 0.5, true)


# ---------- monsters ----------

static func _wolf(c: CanvasItem, size: Vector2) -> void:
	_begin(c, size, 122.0, 72.0)
	var fur := Color(0.52, 0.44, 0.36)
	var dark := fur.darkened(0.2)
	var sh: Array = []
	sh.append([PackedVector2Array([Vector2(-32, -38), Vector2(-52, -50), Vector2(-58, -42), Vector2(-36, -30)]), dark, "tail"])
	sh.append([_r(-26, -28, 8, 28), dark, "far_back"])
	sh.append([_r(14, -28, 8, 28), dark, "far_front"])
	sh.append([_e(-2, -36, 33, 16), fur])
	sh.append([_r(-20, -28, 8, 28), fur, "near_back"])
	sh.append([_r(22, -28, 8, 28), fur, "near_front"])
	sh.append([PackedVector2Array([Vector2(16, -46), Vector2(32, -58), Vector2(44, -56), Vector2(60, -46), Vector2(58, -38), Vector2(42, -34), Vector2(24, -30)]), fur])
	sh.append([PackedVector2Array([Vector2(32, -56), Vector2(35, -68), Vector2(42, -57)]), dark])
	_cut(c, sh)
	if not _on("body"):
		return
	c.draw_circle(Vector2(45, -50), 2.8, Color(0.9, 0.15, 0.1))
	c.draw_circle(Vector2(45.6, -50), 1.2, INK)
	c.draw_line(Vector2(41, -54), Vector2(48, -52), INK, 1.0, true)
	c.draw_circle(Vector2(59, -44), 2.2, INK)
	for tx in [46.0, 50.0, 54.0]:
		c.draw_colored_polygon(PackedVector2Array([Vector2(tx, -38), Vector2(tx + 1.5, -34), Vector2(tx + 3, -38)]), Color.WHITE)


static func _troll(c: CanvasItem, size: Vector2) -> void:
	_begin(c, size, 100.0, 124.0)
	var skin := Color(0.52, 0.64, 0.40)
	var dark := skin.darkened(0.2)
	var sh: Array = []
	sh.append([PackedVector2Array([Vector2(-30, -82), Vector2(-22, -86), Vector2(-26, -40), Vector2(-34, -40)]), dark, "back_arm"])
	sh.append([_e(-30, -38, 6, 6), dark, "back_arm"])
	sh.append([_r(-20, -36, 15, 36), dark, "back_leg"])
	sh.append([_r(6, -36, 15, 36), dark.lightened(0.06), "front_leg"])
	sh.append([_e(-13, -3, 11, 4), dark, "back_leg"])
	sh.append([_e(14, -3, 11, 4), dark.lightened(0.06), "front_leg"])
	sh.append([_e(0, -60, 30, 30), skin])
	sh.append([PackedVector2Array([Vector2(-27, -44), Vector2(27, -44), Vector2(20, -26), Vector2(-20, -26)]), Color(0.45, 0.32, 0.2)])
	sh.append([PackedVector2Array([Vector2(-4, -100), Vector2(-14, -108), Vector2(-6, -92)]), skin])
	sh.append([_e(10, -96, 16, 15), skin])
	sh.append([PackedVector2Array([Vector2(16, -82), Vector2(28, -84), Vector2(32, -40), Vector2(22, -40)]), skin, "front_arm"])
	sh.append([PackedVector2Array([Vector2(24, -36), Vector2(32, -38), Vector2(46, -98), Vector2(32, -102)]), WOOD, "front_arm"])
	sh.append([_e(27, -38, 7, 7), skin, "front_arm"])
	sh.append([PackedVector2Array([Vector2(14, -86), Vector2(16, -95), Vector2(19, -86)]), Color(0.97, 0.95, 0.85)])
	sh.append([PackedVector2Array([Vector2(21, -86), Vector2(23, -94), Vector2(26, -86)]), Color(0.97, 0.95, 0.85)])
	_cut(c, sh)
	if not _on("body"):
		return
	c.draw_circle(Vector2(14, -100), 3.0, Color(0.98, 0.85, 0.2))
	c.draw_circle(Vector2(22, -100), 3.0, Color(0.98, 0.85, 0.2))
	c.draw_circle(Vector2(14.8, -100), 1.3, INK)
	c.draw_circle(Vector2(22.8, -100), 1.3, INK)
	c.draw_line(Vector2(10, -105), Vector2(25, -103), INK, 1.4, true)
	c.draw_circle(Vector2(-8, -64), 2.0, dark)
	c.draw_circle(Vector2(6, -52), 1.6, dark)


# ---------- nature and props ----------

static func _tree(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	_begin(c, size, 92.0, 140.0)
	var col: Color = p.get("col", Color(0.42, 0.62, 0.34))
	var dot: Color = p.get("dot", Color(0.85, 0.25, 0.2))
	var sh: Array = []
	sh.append([PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(6, -70), Vector2(-6, -70)]), WOOD])
	sh.append([_e(-22, -84, 24, 22), col])
	sh.append([_e(22, -86, 24, 22), col])
	sh.append([_e(0, -110, 30, 27), col])
	sh.append([_e(-6, -74, 22, 18), col.darkened(0.08)])
	sh.append([_e(12, -72, 20, 16), col.darkened(0.08)])
	_cut(c, sh)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(col.r * 1000.0)
	for i in 14:
		c.draw_circle(Vector2(rng.randf_range(-36, 36), rng.randf_range(-128, -66)), 2.6, dot)
	for i in 10:
		var a := Vector2(rng.randf_range(-34, 30), rng.randf_range(-126, -68))
		c.draw_line(a, a + Vector2(6, -4), col.darkened(0.3), 0.8, true)


static func _bush(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	_begin(c, size, 92.0, 54.0)
	var col: Color = p.get("col", Color(0.4, 0.6, 0.34))
	var dot: Color = p.get("dot", Color(0.95, 0.95, 0.6))
	_cut(c, [[_e(-26, -18, 20, 17), col], [_e(26, -17, 20, 16), col], [_e(0, -26, 24, 24), col.lightened(0.05)]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 9:
		c.draw_circle(Vector2(rng.randf_range(-36, 36), rng.randf_range(-40, -8)), 2.2, dot)


static func _fence(c: CanvasItem, size: Vector2) -> void:
	_begin(c, size, 94.0, 40.0)
	var sh: Array = []
	sh.append([_r(-46, -27, 92, 5), WOOD.darkened(0.15)])
	sh.append([_r(-46, -13, 92, 5), WOOD.darkened(0.15)])
	var x := -44.0
	for i in 5:
		sh.append([PackedVector2Array([Vector2(x, 0), Vector2(x + 11, 0), Vector2(x + 11, -32), Vector2(x + 5.5, -38), Vector2(x, -32)]), WOOD])
		x += 18.0
	_cut(c, sh)


static func _facade(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	var wall: Color = p["wall"]
	var trim: Color = p["trim"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 1))
	var W := size.x
	var H := size.y
	_fill(c, _r(0, 0, W, H), wall, 1.0 / 300.0)
	# crayon strokes
	for i in 110:
		var a := Vector2(rng.randf() * W, rng.randf() * H)
		c.draw_line(a, a + Vector2(16, -11), wall.darkened(0.12), 2.0, true)
	for i in 6:
		var br := Rect2(rng.randf_range(10, W - 40), rng.randf_range(H * 0.3, H - 30), 26, 12)
		c.draw_rect(br, Color(0.76, 0.36, 0.28))
		c.draw_rect(br, INK, false, 1.5)
	# windows with shutters
	for wx in [W * 0.08, W * 0.72]:
		var ww := W * 0.2
		var wh := H * 0.2
		var wy := H * 0.36
		c.draw_rect(Rect2(wx - ww * 0.32, wy, ww * 0.3, wh), trim)
		c.draw_rect(Rect2(wx + ww * 1.02, wy, ww * 0.3, wh), trim)
		c.draw_rect(Rect2(wx - ww * 0.32, wy, ww * 0.3, wh), INK, false, 2.0)
		c.draw_rect(Rect2(wx + ww * 1.02, wy, ww * 0.3, wh), INK, false, 2.0)
		c.draw_rect(Rect2(wx, wy, ww, wh), Color(0.98, 0.93, 0.7))
		c.draw_line(Vector2(wx + ww * 0.5, wy), Vector2(wx + ww * 0.5, wy + wh), INK, 2.0)
		c.draw_line(Vector2(wx, wy + wh * 0.5), Vector2(wx + ww, wy + wh * 0.5), INK, 2.0)
		c.draw_rect(Rect2(wx, wy, ww, wh), INK, false, 3.0)
	# arched door
	var dw := W * 0.28
	var dh := H * 0.42
	var dx := W * 0.5 - dw * 0.5
	var dy := H - dh
	var door := trim.darkened(0.25)
	c.draw_rect(Rect2(dx, dy, dw, dh), door)
	c.draw_circle(Vector2(W * 0.5, dy), dw * 0.5, door)
	c.draw_arc(Vector2(W * 0.5, dy), dw * 0.5, PI, TAU, 18, INK, 3.0)
	c.draw_line(Vector2(dx, dy), Vector2(dx, H), INK, 3.0)
	c.draw_line(Vector2(dx + dw, dy), Vector2(dx + dw, H), INK, 3.0)
	for i in 3:
		var lx := dx + dw * (0.25 + 0.25 * i)
		c.draw_line(Vector2(lx, dy - dw * 0.35), Vector2(lx, H), door.darkened(0.3), 1.5)
	c.draw_circle(Vector2(dx + dw * 0.78, dy + dh * 0.5), 4.0, Color(0.9, 0.78, 0.3))
	# sign
	var shop_name: String = p.get("name", "")
	if shop_name != "":
		var sr := Rect2(W * 0.14, H * 0.07, W * 0.72, H * 0.17)
		c.draw_rect(sr, Color(0.95, 0.87, 0.66))
		c.draw_rect(sr, INK, false, 3.0)
		var font: Font = p["font"]
		var fs := int(sr.size.y * 0.62)
		c.draw_string(font, Vector2(sr.position.x, sr.position.y + sr.size.y * 0.74), shop_name, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, fs, INK)
	c.draw_rect(Rect2(2, 2, W - 4, H - 4), INK, false, 4.0)


static func _hills(c: CanvasItem, size: Vector2) -> void:
	var W := size.x
	var H := size.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# far mountains, jagged
	var top := PackedVector2Array()
	var x := 0.0
	while x <= W:
		top.append(Vector2(x, H * 0.22 + rng.randf_range(0.0, H * 0.22)))
		x += rng.randf_range(40.0, 90.0)
	top.append(Vector2(W, H * 0.35))
	_layer(c, top, W, H, Color(0.66, 0.72, 0.84))
	# mid hills, rolling
	var mid := PackedVector2Array()
	for i in 41:
		var mx := W * float(i) / 40.0
		mid.append(Vector2(mx, H * 0.52 + sin(mx * 0.012) * H * 0.08 + sin(mx * 0.031) * H * 0.04))
	_layer(c, mid, W, H, Color(0.48, 0.66, 0.40))
	# castle on a hill
	var cx := W * 0.68
	var cy := H * 0.5
	var stone := Color(0.72, 0.72, 0.70)
	for t in [[-30.0, 34.0], [-10.0, 26.0], [10.0, 26.0], [30.0, 34.0]]:
		var tw := 16.0
		var rect := Rect2(cx + t[0] - tw * 0.5, cy - t[1], tw, t[1] + 8.0)
		c.draw_rect(rect, stone)
		c.draw_rect(rect, INK, false, 2.0)
	c.draw_line(Vector2(cx + 30, cy - 34), Vector2(cx + 30, cy - 52), INK, 2.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(cx + 30, cy - 52), Vector2(cx + 46, cy - 47), Vector2(cx + 30, cy - 42)]), Color(0.85, 0.3, 0.2))
	# near hills
	var near := PackedVector2Array()
	for i in 41:
		var nx := W * float(i) / 40.0
		near.append(Vector2(nx, H * 0.72 + sin(nx * 0.017 + 1.3) * H * 0.06))
	_layer(c, near, W, H, Color(0.40, 0.58, 0.34))


static func _layer(c: CanvasItem, top: PackedVector2Array, W: float, H: float, col: Color) -> void:
	var poly := PackedVector2Array(top)
	poly.append(Vector2(W, H))
	poly.append(Vector2(0, H))
	_fill(c, poly, col, 1.0 / 400.0)
	c.draw_polyline(top, Color(0.98, 0.97, 0.93), 5.0, true)
	c.draw_polyline(top, INK, 1.5, true)


static func _cloud(c: CanvasItem, size: Vector2) -> void:
	_begin(c, size, 100.0, 56.0)
	var w := Color(0.98, 0.98, 0.96)
	_cut(c, [[_e(-26, -20, 22, 16), w], [_e(26, -20, 22, 16), w], [_e(0, -30, 28, 22), w], [_e(0, -14, 40, 12), w]])


static func _sun(c: CanvasItem) -> void:
	c.draw_set_transform(Vector2(128, 128), 0.0, Vector2(2.4, 2.4))
	var gold := Color(0.98, 0.80, 0.25)
	var sh: Array = []
	for i in 12:
		var a := TAU * float(i) / 12.0
		var tip := 50.0 if i % 2 == 0 else 43.0
		sh.append([PackedVector2Array([Vector2(cos(a - 0.14), sin(a - 0.14)) * 28.0, Vector2(cos(a), sin(a)) * tip, Vector2(cos(a + 0.14), sin(a + 0.14)) * 28.0]), gold])
	sh.append([_e(0, 0, 30, 30, 28), gold])
	_cut(c, sh)
	c.draw_circle(Vector2(-10, -6), 2.6, INK)
	c.draw_circle(Vector2(10, -6), 2.6, INK)
	c.draw_arc(Vector2(0, 2), 14.0, 0.35, PI - 0.35, 16, INK, 1.6, true)
	c.draw_circle(Vector2(-16, 4), 4.0, Color(0.95, 0.5, 0.35, 0.5))
	c.draw_circle(Vector2(16, 4), 4.0, Color(0.95, 0.5, 0.35, 0.5))


static func _star(c: CanvasItem) -> void:
	c.draw_set_transform(Vector2(64, 64), 0.0, Vector2(1.1, 1.1))
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0 - PI * 0.5
		var r := 50.0 if i % 2 == 0 else 22.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	_cut(c, [[pts, Color(1.0, 0.82, 0.25)]])
