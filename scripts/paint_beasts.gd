## The bestiary: every monster cut-out, drawn like a crayon storybook villain.
## Real mode gets the grim wolf, troll, bat, ooze, creeper and Thorn Warden;
## cute mode keeps its round shapes (PaintCute) and gains fangs, scowls and
## spikes on top, so even the Fluffox looks like it means it. Characters live
## in paint_cute.gd.
class_name PaintBeasts
extends RefCounted

const INK := Paint.INK
const WOOD := Paint.WOOD
const BONE := Color(0.97, 0.94, 0.84)
const MAW := Color(0.42, 0.08, 0.10)


static func V(x: float, y: float) -> Vector2:
	return Vector2(x, y)


static func E(cx: float, cy: float, rx: float, ry: float, n: int = 22) -> PackedVector2Array:
	return Paint._e(cx, cy, rx, ry, n)


static func R(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return Paint._r(x, y, w, h)


## A white fang pointing along `dir`, tip `len` away from the base point.
static func _fang(c: CanvasItem, base: Vector2, dir: Vector2, len: float, wid: float) -> void:
	var side := dir.orthogonal().normalized() * wid * 0.5
	var pts := PackedVector2Array([base - side, base + dir.normalized() * len, base + side])
	c.draw_colored_polygon(pts, BONE)
	c.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2]]), INK, 0.7, true)


## A glowing slit eye: soft halo, bright iris, thin dark pupil, scowling lid.
static func _glow_eye(c: CanvasItem, e: Vector2, r: float, col: Color, tilt: float = -0.35) -> void:
	c.draw_circle(e, r * 2.6, Color(col.r, col.g, col.b, 0.16))
	c.draw_circle(e, r * 1.7, Color(col.r, col.g, col.b, 0.28))
	c.draw_colored_polygon(E(e.x, e.y, r * 1.15, r * 0.85, 14), col)
	c.draw_colored_polygon(E(e.x + r * 0.1, e.y, r * 0.3, r * 0.8, 8), INK)
	var up := V(-r * 1.5, -r * 0.2 + tilt * r * 1.6)
	var dn := V(r * 1.5, -r * 0.2 - tilt * r * 1.6)
	c.draw_colored_polygon(PackedVector2Array([e + V(-r * 1.6, -r * 1.9), e + V(r * 1.6, -r * 1.9), e + dn, e + up]), INK.lightened(0.05))


static func _spikes(c: CanvasItem, from: Vector2, to: Vector2, n: int, h: float, col: Color) -> void:
	for i in n:
		var t0 := float(i) / float(n)
		var t1 := float(i + 1) / float(n)
		var a := from.lerp(to, t0)
		var b := from.lerp(to, t1)
		var out := (b - a).orthogonal().normalized() * h * (0.8 + 0.4 * sin(float(i) * 2.1))
		var tip := (a + b) * 0.5 + out
		c.draw_colored_polygon(PackedVector2Array([a, tip, b]), col)
		c.draw_polyline(PackedVector2Array([a, tip, b]), INK, 0.8, true)


## Real mode wolf: a lean, scarred grey-brown wolf, jaw open.
static func wolf(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 122.0, 72.0)
	var fur := Color(0.46, 0.40, 0.35)
	var dark := fur.darkened(0.24)
	var sh: Array = []
	sh.append([PackedVector2Array([V(-30, -42), V(-48, -60), V(-52, -52), V(-62, -50), V(-56, -40), V(-36, -28)]), dark, "tail"])
	sh.append([Paint._r(-26, -28, 8, 28), dark, "far_back"])
	sh.append([Paint._r(14, -28, 8, 28), dark, "far_front"])
	sh.append([E(-2, -36, 33, 16), fur])
	sh.append([Paint._r(-20, -28, 8, 28), fur, "near_back"])
	sh.append([Paint._r(22, -28, 8, 28), fur, "near_front"])
	for f in [["near_back", -20.0], ["near_front", 22.0], ["far_back", -26.0], ["far_front", 14.0]]:
		var x: float = f[1]
		sh.append([PackedVector2Array([V(x + 7, -5), V(x + 15, -0.5), V(x + 7, -0.5)]), BONE, f[0]])
	# shoulder hackles
	sh.append([PackedVector2Array([V(-18, -50), V(-12, -64), V(-8, -50), V(-2, -66), V(4, -50), V(10, -62), V(16, -48)]), dark])
	# head: upper jaw
	sh.append([PackedVector2Array([V(16, -48), V(30, -62), V(42, -60), V(62, -48), V(60, -42), V(30, -38)]), fur])
	# lower jaw, hanging open
	sh.append([PackedVector2Array([V(28, -37), V(58, -38), V(56, -28), V(40, -24), V(26, -30)]), dark.darkened(0.05)])
	# torn ear
	sh.append([PackedVector2Array([V(30, -60), V(33, -76), V(40, -62), V(37, -64), V(35, -68)]), dark])
	Paint._cut(c, sh)
	if not Paint._on("body"):
		return
	c.draw_colored_polygon(PackedVector2Array([V(32, -38), V(58, -39), V(55, -34), V(34, -33)]), MAW)
	for tx in [36.0, 42.0, 48.0, 54.0]:
		_fang(c, V(tx, -39), V(0.0, 1.0), 6.0, 3.6)
	for tx in [38.0, 46.0, 53.0]:
		_fang(c, V(tx, -34), V(0.0, -1.0), 4.4, 3.0)
	c.draw_circle(V(61, -46), 2.5, INK)
	_glow_eye(c, V(44, -54), 3.0, Color(1.0, 0.78, 0.10))
	c.draw_line(V(26, -44), V(32, -54), Color(0.75, 0.15, 0.12), 1.2, true)
	c.draw_line(V(28, -42), V(34, -52), Color(0.75, 0.15, 0.12), 0.9, true)


## Real mode troll: a hulking tusked brute with a spiked club.
static func troll(c: CanvasItem, size: Vector2) -> void:
	Paint._begin(c, size, 100.0, 124.0)
	var skin := Color(0.46, 0.58, 0.36)
	var dark := skin.darkened(0.22)
	var sh: Array = []
	sh.append([PackedVector2Array([V(-30, -82), V(-22, -86), V(-26, -40), V(-34, -40)]), dark, "back_arm"])
	sh.append([E(-30, -38, 7, 7), dark, "back_arm"])
	sh.append([Paint._r(-20, -36, 15, 36), dark, "back_leg"])
	sh.append([Paint._r(6, -36, 15, 36), dark.lightened(0.06), "front_leg"])
	sh.append([E(-13, -3, 11, 4), dark, "back_leg"])
	sh.append([E(14, -3, 11, 4), dark.lightened(0.06), "front_leg"])
	sh.append([E(0, -62, 31, 31), skin])
	# loincloth and belt with a skull buckle
	sh.append([PackedVector2Array([V(-27, -46), V(27, -46), V(20, -24), V(-20, -24)]), Color(0.40, 0.27, 0.17)])
	sh.append([Paint._r(-27, -48, 54, 5), Color(0.25, 0.17, 0.10)])
	# horns and head
	sh.append([PackedVector2Array([V(-2, -104), V(-13, -118), V(2, -111)]), BONE])
	sh.append([PackedVector2Array([V(14, -108), V(15, -120), V(24, -108)]), BONE])
	sh.append([E(10, -96, 17, 15), skin])
	# front arm with a spiked club
	sh.append([PackedVector2Array([V(16, -82), V(28, -84), V(32, -40), V(22, -40)]), skin, "front_arm"])
	sh.append([PackedVector2Array([V(24, -36), V(32, -38), V(48, -98), V(34, -104)]), WOOD, "front_arm"])
	sh.append([PackedVector2Array([V(36, -80), V(46, -84), V(40, -74)]), Color(0.7, 0.7, 0.76), "front_arm"])
	sh.append([PackedVector2Array([V(42, -94), V(54, -96), V(44, -88)]), Color(0.7, 0.7, 0.76), "front_arm"])
	sh.append([PackedVector2Array([V(30, -90), V(24, -98), V(36, -96)]), Color(0.7, 0.7, 0.76), "front_arm"])
	sh.append([E(27, -38, 8, 8), skin, "front_arm"])
	Paint._cut(c, sh)
	if not Paint._on("body"):
		return
	# tusks and lower-jaw teeth
	c.draw_colored_polygon(PackedVector2Array([V(12, -88), V(20, -88), V(18, -86), V(13, -86)]), MAW)
	_fang(c, V(11, -88), V(-1.0, -1.0), 9.0, 3.4)
	_fang(c, V(21, -88), V(0.5, -1.0), 9.0, 3.4)
	_glow_eye(c, V(15, -100), 2.8, Color(1.0, 0.82, 0.12))
	_glow_eye(c, V(24, -100), 2.8, Color(1.0, 0.82, 0.12))
	# brow, warts and a skull on the belt
	c.draw_line(V(8, -106), V(26, -103), INK, 1.8, true)
	for w in [V(-8, -66), V(8, -56), V(-14, -76), V(18, -70)]:
		c.draw_circle(w, 1.8, dark)
		c.draw_circle(w + V(-0.4, -0.4), 0.7, skin.lightened(0.15))
	c.draw_circle(V(0, -46), 3.6, BONE)
	c.draw_circle(V(-1.3, -46.5), 0.8, INK)
	c.draw_circle(V(1.3, -46.5), 0.8, INK)
	c.draw_line(V(-18, -70), V(-6, -58), dark.darkened(0.2), 1.0, true)


## Fluffox (cute wolf): round and orange, but those eyes are scowling.
static func fluffox(c: CanvasItem, size: Vector2) -> void:
	PaintCute.fluffox(c, size)
	if not Paint._on("body"):
		return
	# dorsal tuft
	_spikes(c, V(-22, -48), V(8, -50), 5, 9.0, Color(0.84, 0.46, 0.2))
	# scowl over both eyes
	c.draw_line(V(24, -58), V(34, -54), INK, 2.0, true)
	c.draw_line(V(46, -58), V(37, -54), INK, 2.0, true)
	# little fangs
	_fang(c, V(44, -38), V(0.0, 1.0), 5.0, 3.0)
	_fang(c, V(50, -39), V(0.0, 1.0), 4.0, 2.6)


## Pebblet (cute troll): a mossy boulder with crystal spikes and a cracked glow.
static func pebblet(c: CanvasItem, size: Vector2) -> void:
	PaintCute.pebblet(c, size)
	if not Paint._on("body"):
		return
	var crystal := Color(0.62, 0.44, 0.92)
	for t in [[V(-22, -76), V(-30, -100), V(-12, -80)], [V(-4, -84), V(-2, -108), V(8, -86)], [V(16, -78), V(26, -98), V(28, -72)]]:
		c.draw_colored_polygon(PackedVector2Array(t), crystal)
		c.draw_polyline(PackedVector2Array(t), INK, 0.8, true)
		c.draw_line(t[0].lerp(t[1], 0.25), t[1].lerp(t[2], 0.2), crystal.lightened(0.5), 1.0, true)
	c.draw_line(V(-12, -62), V(-6, -50), Color(1.0, 0.62, 0.2), 1.8, true)
	c.draw_line(V(-6, -50), V(-12, -40), Color(1.0, 0.62, 0.2), 1.8, true)
	c.draw_line(V(2, -66), V(10, -70), INK, 2.0, true)
	c.draw_line(V(24, -66), V(16, -70), INK, 2.0, true)


static func slime(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	PaintCute.slime(c, p, size)
	if not Paint._on("body"):
		return
	# scowl and a pair of fangs
	c.draw_line(V(-1, -37), V(8, -33), INK, 1.8, true)
	c.draw_line(V(21, -37), V(13, -33), INK, 1.8, true)
	_fang(c, V(6, -17), V(0.0, 1.0), 5.0, 3.0)
	_fang(c, V(13, -17), V(0.0, 1.0), 5.0, 3.0)


static func shroom(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	PaintCute.shroom(c, p, size)
	if not Paint._on("body"):
		return
	c.draw_line(V(-1, -43), V(6, -39), INK, 1.5, true)
	c.draw_line(V(17, -43), V(10, -39), INK, 1.5, true)
	_fang(c, V(5, -26), V(0.0, 1.0), 4.0, 2.6)
	_fang(c, V(10, -26), V(0.0, 1.0), 4.0, 2.6)


static func bat(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	PaintCute.bat(c, p, size)
	if not Paint._on("body"):
		return
	c.draw_line(V(-12, -48), V(-3, -44), INK, 1.6, true)
	c.draw_line(V(12, -48), V(3, -44), INK, 1.6, true)
	_fang(c, V(-3, -33), V(0.0, 1.0), 6.0, 3.0)
	_fang(c, V(3, -33), V(0.0, 1.0), 6.0, 3.0)


## The Bramble King / Thorn Warden: crowned in thorns, a maw full of teeth.
static func boss(c: CanvasItem, p: Dictionary, size: Vector2) -> void:
	PaintCute.boss(c, p, size)
	if not Paint._on("body"):
		return
	var cute: bool = p.get("cute", true)
	var body := Color(0.46, 0.74, 0.40) if cute else Color(0.24, 0.34, 0.20)
	# thorns all over the shoulders
	_spikes(c, V(-44, -112), V(-6, -140), 5, 10.0, body.darkened(0.35))
	_spikes(c, V(6, -140), V(44, -112), 5, 10.0, body.darkened(0.35))
	# jagged maw
	var top := V(-8, -80)
	var jaw: Array = [top, V(0, -74), V(6, -82), V(12, -74), V(18, -82), V(24, -74), V(30, -80), V(26, -62), V(0, -62)]
	c.draw_colored_polygon(PackedVector2Array(jaw), MAW)
	c.draw_polyline(PackedVector2Array(jaw), INK, 1.2, true)
	for i in 4:
		_fang(c, V(-4 + i * 11.0, -80), V(0.0, 1.0), 8.0, 5.0)
	for i in 3:
		_fang(c, V(2 + i * 11.0, -63), V(0.0, -1.0), 6.0, 4.0)
	# scowl
	c.draw_line(V(-12, -112), V(10, -104), INK, 3.0, true)
	c.draw_line(V(34, -112), V(18, -104), INK, 3.0, true)
	var eye_col := Color(1.0, 0.25, 0.12)
	_glow_eye(c, V(-2, -98), 5.0, eye_col)
	_glow_eye(c, V(24, -97), 5.0, eye_col)
