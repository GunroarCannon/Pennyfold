## A Persona-style screen tear in cardboard: the whole picture rips along a
## jagged line, the two halves slide apart over a fluted-cardboard backdrop
## with a big stamped word, hold for a beat, then snap back together as if
## nothing happened. Used for critical hits, big blasts, level-ups, knock-outs.
class_name RipFx
extends Control

const INK := Color(0.17, 0.11, 0.07)
const CORE := Color(0.93, 0.80, 0.58)

var _shot: ImageTexture
var _t := 0.0
var _dur := 0.7
var _gap := 90.0
var _text := ""
var _sub := ""
var _col := Color(1.0, 0.6, 0.2)
var _line := PackedVector2Array()
var _tilt := 0.0
var _active := false
var _seed := 1
var _spokes: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func busy() -> bool:
	return _active


## kind: "crit", "blast", "level", "death", "boss". `text` is stamped on the backdrop.
func play(kind: String, text: String, sub := "", col := Color(1.0, 0.6, 0.2)) -> void:
	if _active or DisplayServer.get_name() == "headless":
		return
	_active = true
	_text = text
	_sub = sub
	_col = col
	match kind:
		"crit":
			_dur = 0.62
			_gap = 70.0
		"blast":
			_dur = 0.8
			_gap = 105.0
		"level":
			_dur = 1.7
			_gap = 150.0
		"death":
			_dur = 1.9
			_gap = 170.0
		"boss":
			_dur = 1.9
			_gap = 150.0
		_:
			_dur = 0.7
			_gap = 90.0
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_active = false
		return
	_shot = ImageTexture.create_from_image(img)
	_seed = randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var vs := get_viewport_rect().size
	_tilt = rng.randf_range(0.10, 0.20) * (1.0 if rng.randf() < 0.5 else -1.0)
	if kind == "blast":
		_tilt *= 0.35
	var y0 := vs.y * rng.randf_range(0.40, 0.60)
	var y1 := y0 + tan(_tilt) * vs.x
	_line = PackedVector2Array()
	var steps := 44
	var walk := 0.0
	for i in steps + 1:
		var f := float(i) / float(steps)
		walk = clampf(walk + rng.randf_range(-9.0, 9.0), -26.0, 26.0)
		var jag := walk + rng.randf_range(-5.0, 5.0)
		var p := Vector2(vs.x * f, lerpf(y0, y1, f) + jag * (0.0 if i == 0 or i == steps else 1.0))
		_line.append(p)
	_spokes.clear()
	for i in 22:
		_spokes.append([rng.randf() * TAU, rng.randf_range(0.5, 1.0)])
	_t = 0.0
	visible = true
	Sfx.play("rip", 0.0, 0.0)
	Sfx.play("boom", -8.0, 0.0)


func _process(delta: float) -> void:
	if not _active or _shot == null:
		return
	_t += delta / _dur
	if _t >= 1.0:
		_active = false
		visible = false
		_shot = null
		return
	queue_redraw()


## 0 closed -> 1 fully open -> hold -> 0 closed again.
func _openness() -> float:
	var t := _t
	if t < 0.14:
		return 1.0 - pow(1.0 - t / 0.14, 3.0)
	if t < 0.62:
		return 1.0 + sin((t - 0.14) * 22.0) * 0.015
	var u := (t - 0.62) / 0.38
	return 1.0 - u * u * (3.0 - 2.0 * u) * 1.0


func _draw() -> void:
	if not _active or _shot == null:
		return
	var vs := size
	var a := clampf(_openness(), 0.0, 1.05)
	var gap := _gap * a
	var shake := Vector2(sin(_t * 90.0), cos(_t * 77.0)) * 4.0 * maxf(0.0, 1.0 - _t * 4.0)
	# backdrop through the gap: ribbed cardboard core, a burst of spokes, the word
	var mid := Vector2(vs.x * 0.5, lerpf(_line[0].y, _line[_line.size() - 1].y, 0.5))
	var ct := Cardboard.core_tex()
	var bg := PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), vs, Vector2(0, vs.y)])
	var uv := PackedVector2Array()
	for p in bg:
		uv.append(p / 512.0)
	draw_polygon(bg, PackedColorArray([CORE.lerp(_col, 0.35)]), uv, ct)
	for s in _spokes:
		var ang: float = s[0]
		var ln: float = s[1]
		var d := Vector2(cos(ang), sin(ang))
		var w := 0.10
		var p0 := mid + d * 40.0
		var p1 := mid + d.rotated(w) * vs.length() * ln
		var p2 := mid + d.rotated(-w) * vs.length() * ln
		draw_colored_polygon(PackedVector2Array([p0, p1, p2]), Color(_col.r, _col.g, _col.b, 0.28))
	# the word, stamped on a torn label, slightly crooked
	if a > 0.35:
		var k := clampf((a - 0.35) / 0.4, 0.0, 1.0)
		var font := Hud.head_font_static
		var fs := int(88.0 * (0.8 + 0.2 * k))
		draw_set_transform(mid + shake, _tilt * 0.45, Vector2.ONE)
		var tw := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		var label := CardBox.new(Color(0.99, 0.95, 0.84), 5, 0.0)
		label.torn = CardBox.LEFT | CardBox.RIGHT
		label.rip = 7.0
		label.tape = 0
		label.shadow = Vector2(6, 8)
		draw_style_box(label, Rect2(Vector2(-tw * 0.5 - 40.0, -fs * 0.62), Vector2(tw + 80.0, fs * 1.22)))
		draw_string_outline(font, Vector2(-tw * 0.5, fs * 0.32), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, INK)
		draw_string(font, Vector2(-tw * 0.5, fs * 0.32), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _col)
		if _sub != "":
			var sf := Hud.head_font_static
			var sw := sf.get_string_size(_sub, HORIZONTAL_ALIGNMENT_CENTER, -1, 30).x
			draw_string_outline(sf, Vector2(-sw * 0.5, fs * 0.95), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, INK)
			draw_string(sf, Vector2(-sw * 0.5, fs * 0.95), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the two halves of the screen
	for half in [0, 1]:
		var up: bool = half == 0
		var poly := PackedVector2Array()
		if up:
			poly.append(Vector2(0, -2))
			poly.append(Vector2(vs.x, -2))
			for i in range(_line.size() - 1, -1, -1):
				poly.append(_line[i])
		else:
			poly.append(Vector2(0, vs.y + 2))
			poly.append(Vector2(vs.x, vs.y + 2))
			for i in range(_line.size() - 1, -1, -1):
				poly.append(_line[i])
		var uvs := PackedVector2Array()
		for p in poly:
			uvs.append(Vector2(p.x / vs.x, p.y / vs.y))
		var dir := -1.0 if up else 1.0
		var off := Vector2(dir * gap * 0.22, dir * gap * 0.5) + shake * dir
		draw_set_transform(mid + off, dir * _tilt * 0.18 * a, Vector2.ONE)
		var shifted := PackedVector2Array()
		for p in poly:
			shifted.append(p - mid)
		var rim := PackedVector2Array()
		for p in _line:
			rim.append(p - mid)
		# fluted core showing along the torn edge
		var band := PackedVector2Array()
		var inward := Vector2(0, -1) if up else Vector2(0, 1)
		var band_d := 15.0
		for p in rim:
			band.append(p + Vector2(0, -band_d * 0.0))
		var band_poly := PackedVector2Array()
		for p in rim:
			band_poly.append(p)
		for i in range(rim.size() - 1, -1, -1):
			var jit := 7.0 + 8.0 * absf(sin(float(i) * 1.7 + float(_seed % 9)))
			band_poly.append(rim[i] + inward * jit)
		var buv := PackedVector2Array()
		for p in band_poly:
			buv.append((p + mid) / 512.0)
		draw_polygon(shifted, PackedColorArray([Color.WHITE]), uvs, _shot)
		draw_polygon(band_poly, PackedColorArray([CORE]), buv, ct)
		draw_polyline(rim, Color(0.30, 0.20, 0.10, 0.7), 2.0, true)
		var edge2 := PackedVector2Array()
		for i in range(rim.size() - 1, -1, -1):
			edge2.append(band_poly[band_poly.size() - 1 - (rim.size() - 1 - i)])
		draw_polyline(edge2, Color(0.30, 0.20, 0.10, 0.55), 1.4, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# white flash as the paper gives way
	if _t < 0.1:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, (1.0 - _t / 0.1) * 0.5))
