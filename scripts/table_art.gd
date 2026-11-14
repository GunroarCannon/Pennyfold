## The title and character-creator backdrop: a crafting table seen from above,
## strewn with torn paper, tape, pencils and coins. Drawn, not 3D, so it is
## cheap everywhere (web, phones) and never shows the world behind it.
class_name TableArt
extends Control

const WOOD := Color(0.47, 0.33, 0.22)
const PAPERS: Array[Color] = [Color(0.93, 0.86, 0.68), Color(0.82, 0.66, 0.45), Color(0.96, 0.93, 0.84),
	Color(0.88, 0.45, 0.36), Color(0.52, 0.72, 0.62), Color(0.45, 0.62, 0.82), Color(0.95, 0.78, 0.35)]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40


func _ragged(c: Vector2, w: float, h: float, rot: float, rng: RandomNumberGenerator, jag: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 7
	var corners := [Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		for i in n:
			var p := a.lerp(b, float(i) / n)
			p += Vector2(rng.randf_range(-jag, jag), rng.randf_range(-jag, jag))
			pts.append(c + p.rotated(rot))
	return pts


func _scrap(c: Vector2, w: float, h: float, rot: float, col: Color, rng: RandomNumberGenerator) -> void:
	var shadow := _ragged(c + Vector2(6, 9), w, h, rot, rng, 3.0)
	draw_colored_polygon(shadow, Color(0.12, 0.07, 0.04, 0.35))
	var body := _ragged(c, w, h, rot, rng, 3.0)
	draw_colored_polygon(body, col)
	# a faint fold and a few ruled lines
	var d := Vector2(w, 0).rotated(rot)
	draw_line(c - d, c + d, col.darkened(0.12), 2.0)
	if col.v > 0.9:
		for i in 3:
			var o := Vector2(0, -h * 0.5 + i * h * 0.35).rotated(rot)
			draw_line(c - d * 0.8 + o, c + d * 0.8 + o, Color(0.45, 0.6, 0.85, 0.5), 1.5)
	draw_polyline(body + PackedVector2Array([body[0]]), col.darkened(0.45), 2.0)


func _tape(c: Vector2, rot: float) -> void:
	var d := Vector2(34, 0).rotated(rot)
	var n := Vector2(0, 13).rotated(rot)
	draw_colored_polygon(PackedVector2Array([c - d - n, c + d - n * 1.1, c + d + n, c - d + n * 1.1]), Color(0.98, 0.92, 0.6, 0.65))


func _pencil(c: Vector2, rot: float, col: Color) -> void:
	var d := Vector2(95, 0).rotated(rot)
	var n := Vector2(0, 7).rotated(rot)
	draw_colored_polygon(PackedVector2Array([c - d + Vector2(5, 8), c + d * 0.7 + Vector2(5, 8), c + d * 0.7 + n + Vector2(5, 8), c - d + n + Vector2(5, 8)]), Color(0, 0, 0, 0.25))
	draw_colored_polygon(PackedVector2Array([c - d - n, c + d * 0.7 - n, c + d * 0.7 + n, c - d + n]), col)
	draw_colored_polygon(PackedVector2Array([c + d * 0.7 - n, c + d, c + d * 0.7 + n]), Color(0.93, 0.8, 0.6))
	draw_colored_polygon(PackedVector2Array([c + d * 0.9 - n * 0.2, c + d, c + d * 0.9 + n * 0.2]), Color(0.2, 0.2, 0.22))
	draw_colored_polygon(PackedVector2Array([c - d - n, c - d * 0.9 - n, c - d * 0.9 + n, c - d + n]), Color(0.85, 0.55, 0.55))


func _coin(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(4, 6), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color(0.78, 0.58, 0.18))
	draw_circle(c, r * 0.82, Color(0.95, 0.78, 0.30))
	draw_arc(c, r * 0.6, 0.4, 2.2, 10, Color(1, 0.95, 0.7, 0.8), 2.0)


func _roll(c: Vector2, r: float) -> void:
	draw_circle(c + Vector2(5, 8), r, Color(0, 0, 0, 0.3))
	draw_circle(c, r, Color(0.98, 0.92, 0.6, 0.9))
	draw_circle(c, r * 0.55, WOOD)
	draw_arc(c, r * 0.55, 0.0, TAU, 20, Color(0.7, 0.6, 0.3), 3.0)


func _scissors(c: Vector2, rot: float) -> void:
	var d := Vector2(1, 0).rotated(rot)
	var n := Vector2(0, 1).rotated(rot)
	for s in [-1.0, 1.0]:
		var blade := PackedVector2Array([c + d * 10 + n * s * 2, c + d * 105 + n * s * 9, c + d * 10 + n * s * 10])
		draw_colored_polygon(blade, Color(0.8, 0.82, 0.85))
		draw_arc(c - d * 28 + n * s * 14, 16.0, 0.0, TAU, 16, Color(0.8, 0.25, 0.2), 7.0)


func _draw() -> void:
	var vs := size
	draw_rect(Rect2(Vector2.ZERO, vs), WOOD)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	# planks and grain
	var ph := 150.0
	var y := 0.0
	var i := 0
	while y < vs.y:
		var tone := WOOD.lightened(0.05 * ((i % 3) - 1))
		draw_rect(Rect2(0, y, vs.x, ph), tone)
		draw_line(Vector2(0, y), Vector2(vs.x, y), WOOD.darkened(0.45), 3.0)
		for g in 14:
			var gy := y + rng.randf_range(8, ph - 8)
			var gx := rng.randf_range(-100, vs.x)
			draw_line(Vector2(gx, gy), Vector2(gx + rng.randf_range(120, 420), gy + rng.randf_range(-3, 3)), tone.darkened(0.13), 2.0)
		y += ph
		i += 1
	# a cutting mat in the middle
	var mat := Rect2(vs.x * 0.06, vs.y * 0.08, vs.x * 0.88, vs.y * 0.84)
	draw_rect(Rect2(mat.position + Vector2(10, 14), mat.size), Color(0, 0, 0, 0.25))
	draw_rect(mat, Color(0.22, 0.38, 0.33))
	var step := 48.0
	var gx2 := mat.position.x
	while gx2 < mat.end.x:
		draw_line(Vector2(gx2, mat.position.y), Vector2(gx2, mat.end.y), Color(1, 1, 1, 0.08), 1.5)
		gx2 += step
	var gy2 := mat.position.y
	while gy2 < mat.end.y:
		draw_line(Vector2(mat.position.x, gy2), Vector2(mat.end.x, gy2), Color(1, 1, 1, 0.08), 1.5)
		gy2 += step
	# torn paper, scattered; denser near the edges so the middle stays calm
	for k in 26:
		var edge := rng.randf() < 0.75
		var p := Vector2(rng.randf_range(0.03, 0.97) * vs.x, rng.randf_range(0.03, 0.97) * vs.y)
		if edge:
			p = Vector2(vs.x * (rng.randf_range(0.0, 0.2) if rng.randf() < 0.5 else rng.randf_range(0.8, 1.0)), rng.randf_range(0.0, vs.y))
		var w := rng.randf_range(36, 110)
		var h := rng.randf_range(28, 85)
		_scrap(p, w, h, rng.randf_range(-0.6, 0.6), PAPERS[rng.randi() % PAPERS.size()], rng)
		if rng.randf() < 0.4:
			_tape(p + Vector2(w * 0.7, -h * 0.8), rng.randf_range(-0.8, 0.8))
	_pencil(Vector2(vs.x * 0.16, vs.y * 0.86), -0.35, Color(0.9, 0.3, 0.25))
	_pencil(Vector2(vs.x * 0.86, vs.y * 0.14), 2.6, Color(0.3, 0.55, 0.85))
	_scissors(Vector2(vs.x * 0.9, vs.y * 0.82), -2.4)
	_roll(Vector2(vs.x * 0.1, vs.y * 0.16), 34.0)
	for c in 7:
		_coin(Vector2(vs.x * rng.randf_range(0.04, 0.96), vs.y * rng.randf_range(0.05, 0.95)), rng.randf_range(15, 22))
	# warm light from the top left
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.1, 0.06, 0.03, 0.18))
