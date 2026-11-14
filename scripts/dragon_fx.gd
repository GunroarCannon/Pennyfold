## The dragon-head special attack: a big cardboard dragon head swoops in from
## off-screen behind the player's back (top-right corner when facing left,
## top-left when facing right), so only the head is ever seen. The jaws
## swing open on a hinge, it breathes a paper-flame cone toward where the
## player is facing, snaps shut, and flies away again.
## The head is assembled from separate parts (skull, upper jaw, lower jaw,
## teeth, horns, brow spikes, eye, nostril), drawn as flat cut-outs.
class_name DragonFx
extends Control

signal bite  ## the moment of the strike; the world applies damage here

const INK := Color(0.17, 0.08, 0.05)
const RED := Color(0.80, 0.14, 0.12)
const RED_DK := Color(0.55, 0.07, 0.08)
const RED_LT := Color(0.93, 0.34, 0.24)
const BONE := Color(0.96, 0.90, 0.68)
const DUR := 1.9

var _t := 0.0
var _active := false
var _dir := -1.0       ## screen direction the player faces: -1 left, +1 right
var _target := Vector2.ZERO  ## screen position the head aims at (the player)
var _bit := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func busy() -> bool:
	return _active


## `dir` is the screen side the player faces (-1 left, +1 right); `target` is
## the player's screen position.
func play(dir: float, target: Vector2) -> void:
	if _active:
		return
	_dir = -1.0 if dir < 0.0 else 1.0
	_target = target
	_t = 0.0
	_bit = false
	_active = true
	visible = true
	Sfx.play("beam", 0.0, 0.0)


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta / DUR
	if not _bit and _t >= 0.38:
		_bit = true
		bite.emit()
		Sfx.play("boom", 0.0, 0.0)
	if _t >= 1.0:
		_active = false
		visible = false
		return
	queue_redraw()


func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


func _ease_in(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return c * c * c


## Where the head's hinge is at the current time, and how open the jaws are.
func _pose() -> Dictionary:
	var vs := size
	# the head comes from the corner BEHIND the player and ends up in front of them
	var back := -_dir
	var start := Vector2(vs.x * (0.5 + back * 0.78), -vs.y * 0.35)
	var rest := _target + Vector2(back * 150.0, -vs.y * 0.17)
	var away := Vector2(vs.x * (0.5 + back * 0.85), -vs.y * 0.45)
	var pos: Vector2
	var open := 0.0
	var fire := 0.0
	var t := _t
	if t < 0.3:
		pos = start.lerp(rest, _ease_out(t / 0.3))
		open = 0.15 * (t / 0.3)
	elif t < 0.38:
		pos = rest
		open = lerpf(0.15, 1.0, (t - 0.3) / 0.08)
	elif t < 0.62:
		var u := (t - 0.38) / 0.24
		pos = rest + Vector2(_dir * 36.0 * sin(u * PI), 0.0)
		open = 1.0
		fire = sin(clampf(u, 0.0, 1.0) * PI) * 0.9 + 0.1
	elif t < 0.7:
		pos = rest
		open = 1.0 - _ease_out((t - 0.62) / 0.08)
	else:
		pos = rest.lerp(away, _ease_in((t - 0.7) / 0.3))
		open = 0.0
	var ang := (pos - _target).angle() * 0.0 + _dir * 0.38 * (1.0 if t > 0.0 else 0.0)
	return {"pos": pos, "open": open, "fire": fire, "ang": ang}


func _draw() -> void:
	if not _active:
		return
	var p := _pose()
	var pos: Vector2 = p["pos"]
	var open: float = p["open"]
	var fire: float = p["fire"]
	var sc := clampf(size.y / 720.0, 0.7, 1.6) * 1.15
	# The head is modelled facing LEFT; flip it to face right.
	draw_set_transform(pos, 0.0, Vector2(-_dir * sc, sc))
	if fire > 0.02:
		_flame(fire)
	_head(open)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A shape filled and outlined like a cardboard cut-out piece.
func _piece(pts: PackedVector2Array, fill: Color, line := 3.0) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, INK, line, true)


func _rot(pts: PackedVector2Array, a: float, pivot: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(pivot + (q - pivot).rotated(a))
	return out


func _tooth(base: Vector2, tip: Vector2, w: float, a: float, pivot: Vector2) -> void:
	var d := (tip - base).normalized()
	var n := Vector2(-d.y, d.x) * w * 0.5
	var tri := _rot(PackedVector2Array([base + n, tip, base - n]), a, pivot)
	_piece(tri, BONE, 1.8)


## Modelled with the snout pointing to -x and the hinge at the origin.
func _head(open: float) -> void:
	var hinge := Vector2.ZERO
	var jaw := open * 0.62
	# --- neck, tapering up and back
	_piece(PackedVector2Array([Vector2(40, -50), Vector2(210, -150), Vector2(260, -30), Vector2(200, 120), Vector2(30, 70)]), RED_DK)
	# belly scales along the neck
	for i in 4:
		var y := -10.0 + i * 38.0
		_piece(PackedVector2Array([Vector2(60 + i * 10, y), Vector2(140 + i * 22, y - 18), Vector2(150 + i * 22, y + 12), Vector2(70 + i * 8, y + 28)]), BONE.darkened(0.08), 1.6)
	# --- horns (two long swept-back cones) and the brow spikes
	_piece(PackedVector2Array([Vector2(-20, -92), Vector2(60, -190), Vector2(190, -330), Vector2(120, -160), Vector2(70, -84)]), BONE)
	_piece(PackedVector2Array([Vector2(-48, -86), Vector2(-5, -170), Vector2(60, -250), Vector2(40, -140), Vector2(10, -80)]), BONE.darkened(0.06))
	for i in 3:
		var bx := 90.0 + i * 46.0
		_piece(PackedVector2Array([Vector2(bx, -120 - i * 12), Vector2(bx + 46, -208 - i * 26), Vector2(bx + 66, -110 - i * 10)]), BONE, 2.2)
	# --- lower jaw: hinged at the origin, swings down
	var lower := PackedVector2Array([Vector2(10, 34), Vector2(-60, 62), Vector2(-170, 74), Vector2(-250, 64), Vector2(-268, 80), Vector2(-250, 100), Vector2(-150, 124), Vector2(-40, 120), Vector2(40, 96)])
	var lower_r := _rot(lower, jaw, hinge)
	# the inside of the mouth shows behind the jaws
	var mouth := PackedVector2Array([Vector2(-250, 6), Vector2(-60, -6), Vector2(20, 6), Vector2(20, 50), Vector2(-60, 64), Vector2(-250, 64)])
	var mouth_pts := PackedVector2Array([Vector2(-240, 20), _rot(PackedVector2Array([Vector2(-250, 66)]), jaw, hinge)[0], _rot(PackedVector2Array([Vector2(20, 60)]), jaw, hinge)[0], Vector2(20, 14)])
	if open > 0.05:
		draw_colored_polygon(mouth_pts, Color(0.38, 0.04, 0.07))
		# tongue
		var tg := _rot(PackedVector2Array([Vector2(-210, 56), Vector2(-120, 42), Vector2(-20, 52), Vector2(-120, 66)]), jaw, hinge)
		draw_colored_polygon(tg, Color(0.95, 0.45, 0.50))
	_piece(lower_r, RED)
	# jaw highlight stripe
	var strip := _rot(PackedVector2Array([Vector2(-150, 96), Vector2(-30, 94), Vector2(30, 84), Vector2(-40, 108), Vector2(-140, 112)]), jaw, hinge)
	draw_colored_polygon(strip, RED_LT)
	# lower teeth
	for i in 7:
		var tx := -240.0 + i * 33.0
		_tooth(Vector2(tx, 70 + i * 1.4), Vector2(tx - 3, 70 + i * 1.4 - 34), 15.0, jaw, hinge)
	# --- skull and upper jaw in one piece
	var skull := PackedVector2Array([Vector2(40, -60), Vector2(10, -118), Vector2(-60, -100), Vector2(-150, -70), Vector2(-246, -34), Vector2(-272, -14), Vector2(-250, 8), Vector2(-120, 10), Vector2(0, 20), Vector2(50, 36), Vector2(100, -10)])
	_piece(skull, RED)
	# cheek plate and snout shading
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -60), Vector2(30, -52), Vector2(70, -10), Vector2(10, 14), Vector2(-60, -6)]), RED_DK)
	draw_colored_polygon(PackedVector2Array([Vector2(-230, -26), Vector2(-130, -58), Vector2(-60, -84), Vector2(-120, -44), Vector2(-220, -10)]), RED_LT)
	# upper teeth (fangs get longer toward the front)
	for i in 8:
		var ux := -246.0 + i * 31.0
		var l := 22.0 + (7 - i) * 2.2
		_tooth(Vector2(ux, 4 + i * 0.7), Vector2(ux + 2, 4 + i * 0.7 + l), 14.0, 0.0, hinge)
	# nostril, brow ridge, eye
	draw_circle(Vector2(-248, -24), 6.0, INK)
	_piece(PackedVector2Array([Vector2(-110, -66), Vector2(-40, -90), Vector2(-14, -80), Vector2(-90, -52)]), RED_DK, 2.0)
	var eye := PackedVector2Array([Vector2(-96, -52), Vector2(-52, -70), Vector2(-40, -58), Vector2(-86, -42)])
	_piece(eye, Color(1.0, 0.86, 0.25), 2.2)
	draw_line(Vector2(-72, -66), Vector2(-66, -46), INK, 4.0, true)


## A fan of torn-paper flames out of the open mouth, toward -x.
func _flame(a: float) -> void:
	var mouth := Vector2(-262, 34)
	var len := 520.0 * a
	var wob := _t * 38.0
	var cols := [Color(0.98, 0.42, 0.10, 0.92), Color(1.0, 0.68, 0.16, 0.95), Color(1.0, 0.93, 0.55, 0.98)]
	for layer in 3:
		var l := len * (1.0 - layer * 0.24)
		var w := (190.0 - layer * 52.0) * a
		var pts := PackedVector2Array()
		pts.append(mouth)
		var n := 9
		for k in n + 1:
			var f := float(k) / float(n)
			var jag := sin(wob + f * 7.0 + layer * 1.7) * 14.0
			pts.append(mouth + Vector2(-l * f, -w * 0.5 * f * (0.7 + 0.3 * sin(f * 5.0 + wob * 0.3)) - jag))
			pts.append(mouth + Vector2(-l * f * 0.96, jag * 0.6) if k < n else mouth + Vector2(-l, 0))
		for k in range(n, -1, -1):
			var f := float(k) / float(n)
			var jag := sin(wob * 1.1 + f * 6.0 + layer) * 14.0
			pts.append(mouth + Vector2(-l * f, w * 0.5 * f * (0.7 + 0.3 * sin(f * 4.0 + wob * 0.4)) + jag))
		var fin := Geometry2D.convex_hull(pts)
		if fin.size() >= 3:
			draw_colored_polygon(fin, cols[layer])
			if layer == 0:
				var o := fin.duplicate()
				o.append(fin[0])
				draw_polyline(o, Color(INK.r, INK.g, INK.b, 0.55), 2.4, true)
