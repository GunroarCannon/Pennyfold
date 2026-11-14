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
var _local := Transform2D.IDENTITY
var _rest_pos := Vector2.ZERO


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
	_rest_pos = rest
	return {"pos": pos, "open": open, "fire": fire}


func _draw() -> void:
	if not _active:
		return
	var p := _pose()
	var pos: Vector2 = p["pos"]
	var open: float = p["open"]
	var fire: float = p["fire"]
	var k := K * clampf(size.y / 720.0, 0.7, 1.6)
	# The sheet faces LEFT; flip it to face right. Tilt the snout downward.
	var rig := Transform2D(_dir * 0.28, Vector2(-_dir * k, k), 0.0, Vector2.ZERO).translated_local(-HINGE)
	# put the snout (at rest) just in front of the player, whatever the screen size
	var want := _target + Vector2(_dir * 120.0, -70.0)
	var shift := want - (rig * MOUTH)
	var travel := pos - _rest_pos
	_local = rig
	_local.origin += shift + travel
	if fire > 0.02:
		_flame(fire)
	_head(open)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A shape filled and outlined like a cardboard cut-out piece.
func _piece(pts: PackedVector2Array, fill: Color, line := 3.0) -> void:
	_fill(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, INK, line, true)


## draw_colored_polygon that quietly skips shapes it cannot triangulate.
func _fill(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() >= 3 and not Geometry2D.triangulate_polygon(pts).is_empty():
		draw_colored_polygon(pts, c)


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


## The head, in sheet pixels, snout pointing left. The jaws pivot on HINGE.
## Offsets were matched against the assembled picture on the original sheet.
const HINGE := Vector2(302, 272)
const NEAR_AT := Vector2(-16, 205)
const FAR_AT := Vector2(12, 223)
const MOUTH := Vector2(8, 292)
const PAD := Vector2(14, 14)  ## transparent margin round each cut-out
const K := 0.62  ## sheet pixels -> screen pixels at 720p

static var _tex := {}


func _t_of(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load("res://assets/dragon/%s.png" % n)
	return _tex[n]


func _head(open: float) -> void:
	var jaw := -open * 0.72
	var jt := _local.translated_local(HINGE).rotated_local(jaw).translated_local(-HINGE)
	# mouth cavity, dark, behind the teeth and in front of the far jaw
	var tip := (jt * (NEAR_AT + Vector2(6, 30)))
	if open > 0.05:
		draw_set_transform_matrix(_local)
		var cav := PackedVector2Array([MOUTH + Vector2(40, -10), HINGE + Vector2(-10, -26), HINGE + Vector2(10, 40), _local.affine_inverse() * tip])
		_fill(cav, Color(0.36, 0.04, 0.06))
		var tong := PackedVector2Array([MOUTH + Vector2(70, 8), HINGE + Vector2(-30, -4), HINGE + Vector2(-4, 28), _local.affine_inverse() * tip + Vector2(40, -10)])
		_fill(tong, Color(0.80, 0.30, 0.34))
	draw_set_transform_matrix(jt)
	draw_texture(_t_of("jaw_far"), FAR_AT - PAD)
	draw_set_transform_matrix(_local)
	draw_texture(_t_of("head"), -PAD)
	draw_set_transform_matrix(jt)
	draw_texture(_t_of("jaw_near"), NEAR_AT - PAD)
	draw_set_transform_matrix(_local)


## A fan of torn-paper flame tongues out of the open mouth, toward -x.
func _flame(a: float) -> void:
	draw_set_transform_matrix(_local)
	var mouth := MOUTH + Vector2(-6, 8)
	var cols := [Color(0.95, 0.36, 0.08, 0.95), Color(1.0, 0.64, 0.14, 0.96), Color(1.0, 0.92, 0.5, 0.98)]
	for layer in 3:
		var tongues := 7 - layer * 2
		for i in tongues:
			var f := float(i) / float(maxi(tongues - 1, 1)) - 0.5
			var wob := sin(_t * 42.0 + float(i) * 1.9 + float(layer)) * 0.12
			var ang := PI + f * 0.9 + wob + 0.18
			var ln := (820.0 - layer * 220.0) * a * (0.7 + 0.3 * sin(float(i) * 2.7 + _t * 30.0 + layer))
			var wd := (120.0 - layer * 30.0) * a
			var d := Vector2(cos(ang), sin(ang))
			var n := Vector2(-d.y, d.x)
			var tip := mouth + d * ln
			var pts := PackedVector2Array([mouth + n * wd * 0.5, mouth + d * ln * 0.55 + n * wd * 0.42, tip, mouth + d * ln * 0.5 - n * wd * 0.4, mouth - n * wd * 0.5])
			_fill(pts, cols[layer])
			if layer == 0:
				pts.append(pts[0])
				draw_polyline(pts, Color(INK.r, INK.g, INK.b, 0.6), 3.0, true)
