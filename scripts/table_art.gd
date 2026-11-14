## The title and character-creator backdrop: a paper diorama built from real
## cardboard. Every layer is a flat colour with a photographed board texture
## laid over it, a corrugated cut edge and a soft shadow on the layer behind.
## The layers pop in one after another, back to front, like a pop-up book.
## Drawn, not 3D, so it is cheap on web and phones.
class_name TableArt
extends Control

const REVEAL_GAP := 0.2     # seconds between layers
const REVEAL_LEN := 0.65    # how long each layer takes to settle
const LAYERS := 5
const STRIP_AT := 0.35
const STRIP_LEN := 1.1
const LAYER_AT := 0.6

var _grain: Texture2D
var _torn: Texture2D
var _t := 0.0
## The cardboard strips live on their own node so they draw above the menu.
var strips_only := false
var _overlay: TableArt


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_grain = load("res://assets/paper/board_wrinkle.png")
	_torn = load("res://assets/paper/board_torn.png")
	resized.connect(queue_redraw)
	if strips_only:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 2   # relative to the backdrop (40): above the menu at 41
		return
	visibility_changed.connect(func() -> void:
		if visible:
			restart())
	_overlay = TableArt.new()
	_overlay.strips_only = true
	add_child(_overlay)


## Plays the pop-up again from the first layer.
func restart() -> void:
	_t = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()
	if _overlay != null:
		_overlay._t = _t
		_overlay.queue_redraw()
	if _t > LAYER_AT + REVEAL_GAP * LAYERS + REVEAL_LEN + 0.1:
		set_process(false)


## 0..1 progress of layer i, with a little overshoot so it lands like a card.
func _k(i: int) -> float:
	var f := clampf((_t - LAYER_AT - i * REVEAL_GAP) / REVEAL_LEN, 0.0, 1.0)
	var c1 := 1.4
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(f - 1.0, 3.0) + c1 * pow(f - 1.0, 2.0)


# ---------------- drawing helpers ----------------

## A flat-coloured cut-paper shape: soft shadow behind it (deeper the longer it
## has been down), the colour, board grain over the top and a dark cut edge.
func _paper(poly: PackedVector2Array, col: Color, depth := 1.0, edge := true) -> void:
	var sh := PackedVector2Array()
	for q in poly:
		sh.append(q + Vector2(6.0, -11.0) * depth)
	draw_colored_polygon(sh, Color(0.10, 0.06, 0.03, 0.20))
	var sh2 := PackedVector2Array()
	for q in poly:
		sh2.append(q + Vector2(3.0, -5.5) * depth)
	draw_colored_polygon(sh2, Color(0.10, 0.06, 0.03, 0.22))
	draw_colored_polygon(poly, col)
	_grain_over(poly, 0.34)
	if edge:
		draw_polyline(poly + PackedVector2Array([poly[0]]), col.darkened(0.55), 2.0)
		# a pale bevel along the top-left, where the board catches the light
		var hl := PackedVector2Array()
		for q in poly:
			hl.append(q + Vector2(1.5, 1.5))
		draw_polyline(hl + PackedVector2Array([hl[0]]), Color(1, 1, 1, 0.16), 1.2)


func _grain_over(poly: PackedVector2Array, a: float) -> void:
	if _grain == null:
		return
	var uvs := PackedVector2Array()
	var sz := _grain.get_size()
	for q in poly:
		uvs.append(q / sz)
	draw_polygon(poly, PackedColorArray([Color(1, 1, 1, a)]), uvs, _grain)


## A ridge of cut board: wavy top, filled to the bottom, with a corrugated band
## along the cut so you can see the flutes in the cross-section.
func _ridge(vs: Vector2, base: float, amp: float, freq: float, phase: float, col: Color, rng: RandomNumberGenerator, depth := 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x := -20.0
	while x <= vs.x + 20.0:
		var y := base + sin(x * freq + phase) * amp + sin(x * freq * 2.7 + phase * 1.9) * amp * 0.35 + rng.randf_range(-2.0, 2.0)
		pts.append(Vector2(x, y))
		x += 12.0
	var poly := pts.duplicate()
	poly.append(Vector2(vs.x + 20.0, vs.y + 60.0))
	poly.append(Vector2(-20.0, vs.y + 60.0))
	_paper(poly, col, depth, false)
	# corrugated cross-section band
	var band := PackedVector2Array()
	var low := PackedVector2Array()
	for q in pts:
		band.append(q)
		low.append(q + Vector2(0, 7))
	var strip := band.duplicate()
	low.reverse()
	strip.append_array(low)
	draw_colored_polygon(strip, Color(0.90, 0.76, 0.55))
	for i in pts.size() - 1:
		for k in 4:
			var p: Vector2 = pts[i].lerp(pts[i + 1], k / 4.0)
			draw_line(p + Vector2(0, 1), p + Vector2(0, 7), Color(0.55, 0.38, 0.20, 0.55 if k % 2 == 0 else 0.22), 1.4)
	draw_polyline(pts, col.darkened(0.55), 2.0)
	return pts


## A folded paper pine: tiers of triangles, each creased down the middle so the
## left half catches the light and the right half sits in shade.
func _pine(at: Vector2, h: float, col: Color) -> void:
	var w := h * 0.40
	_paper(PackedVector2Array([at + Vector2(-h * 0.045, h * 0.02), at + Vector2(-h * 0.045, -h * 0.22), at + Vector2(h * 0.045, -h * 0.22), at + Vector2(h * 0.045, h * 0.02)]), Color(0.47, 0.32, 0.19), 0.4)
	for t in 4:
		var y1 := at.y - h * (0.12 + t * 0.21)
		var ww := w * (1.0 - t * 0.2)
		var tip := Vector2(at.x, y1 - h * 0.34)
		var bl := Vector2(at.x - ww, y1)
		var br := Vector2(at.x + ww, y1)
		var mid := Vector2(at.x, y1 - h * 0.05)
		# the lower edge is notched like cut paper
		var nl := bl.lerp(mid, 0.5) + Vector2(0, h * 0.03)
		var nr := br.lerp(mid, 0.5) + Vector2(0, h * 0.03)
		_paper(PackedVector2Array([tip, bl, nl, mid, nr, br]), col, 0.5)
		draw_colored_polygon(PackedVector2Array([tip, bl, nl, mid]), col.lightened(0.14 + t * 0.03))
		draw_colored_polygon(PackedVector2Array([tip, mid, nr, br]), col.darkened(0.16))
		draw_line(tip, mid, col.darkened(0.45), 1.4)


## A cut-paper castle: a keep with a cone roof, two towers, a battlemented
## wall, a gate, arrow slits and a pennant. Left faces light, right faces shaded.
func _castle(at: Vector2, u: float) -> void:
	var wall := Color(0.95, 0.90, 0.78)
	var roof := Color(0.80, 0.34, 0.28)
	var slit := Color(0.25, 0.2, 0.3)
	# curtain wall with battlements
	var wl := at.x - u * 3.0
	var wr := at.x + u * 3.0
	var wt := at.y - u * 2.4
	var wall_poly := PackedVector2Array([Vector2(wl, at.y), Vector2(wl, wt)])
	var nb := 9
	for i in nb:
		var x0 := lerpf(wl, wr, float(i) / nb)
		var x1 := lerpf(wl, wr, (float(i) + 0.55) / nb)
		var up := 0.0 if i % 2 == 0 else u * 0.55
		wall_poly.append(Vector2(x0, wt - u * 0.55 + up))
		wall_poly.append(Vector2(x1, wt - u * 0.55 + up))
	wall_poly.append(Vector2(wr, wt))
	wall_poly.append(Vector2(wr, at.y))
	_paper(wall_poly, wall, 0.8)
	draw_colored_polygon(PackedVector2Array([Vector2(at.x, at.y), Vector2(at.x, wt - u * 0.5), Vector2(wr, wt - u * 0.5), Vector2(wr, at.y)]), wall.darkened(0.10))
	# towers
	for side in [-1.0, 1.0]:
		var cx: float = at.x + side * u * 3.0
		var tw := u * 1.15
		var th := u * 5.0
		_paper(PackedVector2Array([Vector2(cx - tw, at.y), Vector2(cx - tw, at.y - th), Vector2(cx + tw, at.y - th), Vector2(cx + tw, at.y)]), wall, 0.9)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, at.y), Vector2(cx, at.y - th), Vector2(cx + tw, at.y - th), Vector2(cx + tw, at.y)]), wall.darkened(0.12))
		_paper(PackedVector2Array([Vector2(cx - tw * 1.3, at.y - th), Vector2(cx, at.y - th - u * 2.4), Vector2(cx + tw * 1.3, at.y - th)]), roof, 0.9)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, at.y - th - u * 2.4), Vector2(cx + tw * 1.3, at.y - th), Vector2(cx, at.y - th)]), roof.darkened(0.15))
		draw_rect(Rect2(cx - u * 0.14, at.y - th * 0.7, u * 0.28, u * 0.8), slit)
	# the keep
	var kw := u * 1.5
	var kh := u * 6.2
	_paper(PackedVector2Array([Vector2(at.x - kw, at.y), Vector2(at.x - kw, at.y - kh), Vector2(at.x + kw, at.y - kh), Vector2(at.x + kw, at.y)]), wall.lightened(0.03), 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(at.x, at.y), Vector2(at.x, at.y - kh), Vector2(at.x + kw, at.y - kh), Vector2(at.x + kw, at.y)]), wall.darkened(0.12))
	_paper(PackedVector2Array([Vector2(at.x - kw * 1.25, at.y - kh), Vector2(at.x, at.y - kh - u * 2.8), Vector2(at.x + kw * 1.25, at.y - kh)]), roof, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(at.x, at.y - kh - u * 2.8), Vector2(at.x + kw * 1.25, at.y - kh), Vector2(at.x, at.y - kh)]), roof.darkened(0.15))
	# gate arch and windows
	var gate := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		gate.append(Vector2(at.x + cos(a) * u * 0.8, at.y - u * 1.3 + sin(a) * u * 0.9))
	gate.append(Vector2(at.x + u * 0.8, at.y))
	gate.append(Vector2(at.x - u * 0.8, at.y))
	draw_colored_polygon(gate, Color(0.30, 0.20, 0.16))
	draw_rect(Rect2(at.x - u * 0.2, at.y - kh * 0.62, u * 0.4, u * 1.1), slit)
	draw_rect(Rect2(at.x - u * 0.2, at.y - kh * 0.35, u * 0.4, u * 0.9), slit)
	# pennant
	var top := Vector2(at.x, at.y - kh - u * 2.8)
	draw_line(top, top + Vector2(0, -u * 2.0), Color(0.2, 0.12, 0.08), 2.5)
	_paper(PackedVector2Array([top + Vector2(0, -u * 2.0), top + Vector2(u * 1.6, -u * 1.5), top + Vector2(0, -u * 1.0)]), Color(0.95, 0.72, 0.2), 0.3, false)


func _cloud(at: Vector2, u: float, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	pts = _union_discs(at, u, [Vector3(-0.95, 0.12, 0.62), Vector3(0.0, -0.18, 0.85), Vector3(0.95, 0.12, 0.62), Vector3(0.0, 0.28, 0.7)])
	_paper(pts, Color(0.99, 0.97, 0.92), 0.7)


## Outline of several overlapping discs (x, y, radius in units of u), by
## sampling the angle and taking the farthest disc edge from the centre.
func _union_discs(at: Vector2, u: float, discs: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 72
	for k in n:
		var a := TAU * k / n
		var dir := Vector2(cos(a), sin(a))
		var best := 0.0
		for d in discs:
			var c := Vector2(d.x, d.y) * u
			var r: float = d.z * u
			# ray from the origin hits this circle at t = b + sqrt(b^2 - (|c|^2 - r^2))
			var b := dir.dot(c)
			var disc := b * b - (c.length_squared() - r * r)
			if disc >= 0.0:
				best = maxf(best, b + sqrt(disc))
		pts.append(at + dir * best)
	return pts


func _sun(c: Vector2, r: float) -> void:
	# rays as little cut triangles, then a clean disc
	for k in 14:
		var a := TAU * k / 14.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		_paper(PackedVector2Array([c + d * r * 1.12 + n * r * 0.13, c + d * r * 1.55, c + d * r * 1.12 - n * r * 0.13]), Color(0.98, 0.84, 0.40), 0.4, false)
	var disc := PackedVector2Array()
	for k in 48:
		var a2 := TAU * k / 48.0
		disc.append(c + Vector2(cos(a2), sin(a2)) * r)
	_paper(disc, Color(0.97, 0.76, 0.26), 0.8)
	var inner := PackedVector2Array()
	for k in 48:
		var a3 := TAU * k / 48.0
		inner.append(c + Vector2(cos(a3), sin(a3)) * r * 0.72)
	draw_colored_polygon(inner, Color(1.0, 0.86, 0.45, 0.8))


## Two big strips of real torn cardboard that start closed across the scene and
## slide apart to reveal it, then rest along the left and right edges. Their
## shadows fall onto the scene.
func _strips(vs: Vector2) -> void:
	var f := clampf((_t - STRIP_AT) / STRIP_LEN, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - f, 3.0)
	var wide := vs.x * 0.62
	var vis_l := vs.x * 0.075
	var vis_r := vs.x * 0.06
	var lr := lerpf(vs.x * 0.53, vis_l, e)         # right edge of the left strip
	var rl := lerpf(vs.x * 0.47, vs.x - vis_r, e)  # left edge of the right strip
	var h := vs.y * 1.12
	var sa := 0.38 * minf(1.0, e * 4.0 + 0.2)
	# left strip: mirrored so its ripped, corrugated edge faces the middle
	draw_set_transform(Vector2(lr - wide * 0.5, vs.y * 0.5), -0.012, Vector2(-1.0, 1.0))
	var lrect := Rect2(Vector2(-wide * 0.5, -h * 0.5), Vector2(wide, h))
	draw_texture_rect(_torn, Rect2(lrect.position + Vector2(-12, 6), lrect.size), false, Color(0.08, 0.05, 0.02, sa))
	draw_texture_rect(_torn, lrect, false, Color(0.95, 0.90, 0.82))
	draw_set_transform(Vector2(rl + wide * 0.5, vs.y * 0.5), 0.016, Vector2(1.0, -1.0))
	var rrect := Rect2(Vector2(-wide * 0.5, -h * 0.5), Vector2(wide, h))
	draw_texture_rect(_torn, Rect2(rrect.position + Vector2(12, -6), rrect.size), false, Color(0.08, 0.05, 0.02, sa))
	draw_texture_rect(_torn, rrect, false, Color(0.90, 0.84, 0.75))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _tape(c: Vector2, rot: float) -> void:
	var d := Vector2(38, 0).rotated(rot)
	var n := Vector2(0, 13).rotated(rot)
	var q := PackedVector2Array([c - d - n, c + d - n * 1.05, c + d + n, c - d + n * 1.05])
	var s := PackedVector2Array()
	for p in q:
		s.append(p + Vector2(1.5, 2.5))
	draw_colored_polygon(s, Color(0.1, 0.06, 0.03, 0.2))
	draw_colored_polygon(q, Color(0.97, 0.91, 0.62, 0.72))
	for i in 5:
		var f := -0.8 + i * 0.4
		draw_line(c + d * f - n * 0.9, c + d * f + n * 0.9, Color(1, 1, 1, 0.18), 1.0)


func _draw() -> void:
	var vs := size
	if vs.x < 10.0 or _grain == null:
		return
	if strips_only:
		_strips(vs)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var u := minf(vs.x, vs.y * 1.6) / 40.0

	# layer 0: the backing board with a pale paper sky glued on it
	var k0 := _k(0)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.62, 0.45, 0.28))
	_grain_over(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]), 0.5)
	var sky := PackedVector2Array([Vector2(14, 14), Vector2(vs.x - 14, 14), Vector2(vs.x - 14, vs.y - 14), Vector2(14, vs.y - 14)])
	for q in range(sky.size()):
		sky[q] = vs * 0.5 + (sky[q] - vs * 0.5) * (0.92 + 0.08 * k0)
	_paper(sky, Color(0.72, 0.84, 0.86), 1.0)

	# layer 1: sun and clouds drift down from above
	var k1 := _k(1)
	draw_set_transform(Vector2(0, -(1.0 - k1) * vs.y * 0.5), 0.0, Vector2.ONE)
	_sun(Vector2(vs.x * 0.82, vs.y * 0.2), u * 3.2)
	_cloud(Vector2(vs.x * 0.2, vs.y * 0.18), u * 2.2, rng)
	_cloud(Vector2(vs.x * 0.55, vs.y * 0.1), u * 1.7, rng)
	_cloud(Vector2(vs.x * 0.9, vs.y * 0.44), u * 1.5, rng)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# layer 2: far blue mountains rise from below
	draw_set_transform(Vector2(0, (1.0 - _k(2)) * vs.y * 0.6), 0.0, Vector2.ONE)
	_ridge(vs, vs.y * 0.56, u * 3.0, 0.006, 1.0, Color(0.50, 0.61, 0.73), rng, 1.0)

	# layer 3: green hills, the castle sunk behind them, and pines
	draw_set_transform(Vector2(0, (1.0 - _k(3)) * vs.y * 0.6), 0.0, Vector2.ONE)
	var cx := vs.x * 0.74
	var cy := vs.y * 0.66 + sin(cx * 0.004 + 3.0) * u * 1.6 + sin(cx * 0.0108 + 5.7) * u * 0.56 + u * 1.6
	_castle(Vector2(cx, cy), u * 0.9)
	_ridge(vs, vs.y * 0.66, u * 1.6, 0.004, 3.0, Color(0.55, 0.72, 0.50), rng, 1.2)
	for t in 7:
		var tx := vs.x * (0.04 + t * 0.075 + rng.randf_range(0.0, 0.03))
		if absf(tx - cx) > u * 5.0:
			_pine(Vector2(tx, vs.y * 0.69 + rng.randf_range(0.0, u)), u * rng.randf_range(2.6, 3.6), Color(0.33, 0.55, 0.40))

	# layer 4: the near brown ridge with taller pines
	draw_set_transform(Vector2(0, (1.0 - _k(4)) * vs.y * 0.6), 0.0, Vector2.ONE)
	_ridge(vs, vs.y * 0.82, u * 1.4, 0.005, 0.2, Color(0.60, 0.42, 0.28), rng, 1.4)
	for t in 9:
		var tx2 := vs.x * (0.03 + t * 0.12 + rng.randf_range(0.0, 0.05))
		_pine(Vector2(tx2, vs.y * 0.87 + rng.randf_range(0.0, vs.y * 0.08)), u * rng.randf_range(3.2, 4.8), Color(0.24, 0.45, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
