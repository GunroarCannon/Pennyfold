## A cardboard panel, drawn the way real board looks: a flat kraft face with
## faint flutes, mostly straight cut edges (a crisp dark rim and a little
## bevel), and ripped edges on one or two sides where the paper liner has
## peeled back and shows the pale ribbed core underneath. Masking tape lies
## across a corner. It draws itself at any size, so nothing is ever stretched.
class_name CardBox
extends StyleBox

const CORE := Color(0.93, 0.80, 0.58)
const CORE_RIB := Color(0.45, 0.30, 0.16, 0.42)
const TOP := 1
const RIGHT := 2
const BOTTOM := 4
const LEFT := 8

@export var bg := Color(0.84, 0.66, 0.43)
@export var ink := Color(0.20, 0.13, 0.08)
## Kept for older callers; ignored.
@export var rounded := false
@export var radius := 14.0
## Width of the rim on cut edges, in pixels.
@export var line := 2.0
## Corner chamfer in pixels (cut corners are small and straight-sided).
@export var cut := 4.0
## Tiny unevenness of cut edges, in pixels.
@export var wobble := 0.8
## Hard offset shadow. Zero hides it.
@export var shadow := Vector2(2, 3)
@export var shadow_col := Color(0.16, 0.10, 0.05, 0.20)
## Moves the whole card (a pressed button sinks onto its shadow).
@export var shift := Vector2.ZERO
## Subtle flute lines over the face.
@export var ply := true
## 0 none, 1 tape across the top-left corner, 2 tape on both top corners,
## 3 a strip across the top middle. -1 picks by seed for big panels.
@export var tape := -1
@export var seed := 1
## Which sides are ripped (TOP|RIGHT|BOTTOM|LEFT). -1 picks one by seed for big panels.
@export var torn := -1
## How deep the rip bites, in pixels.
@export var rip := 5.0
## Size of a folded-down top-right corner, in pixels. Zero for none.
@export var dogear := 0.0
## Kept for older callers; ignored.
@export var core := 0.0


func _init(p_bg := Color(0.84, 0.66, 0.43), p_seed := 1, margin := 14.0) -> void:
	bg = p_bg
	seed = p_seed
	set_content_margin_all(margin)


## A copy with a different fill (hover, pressed and disabled states).
func tinted(c: Color) -> CardBox:
	var s: CardBox = duplicate()
	s.bg = c
	return s


func _mask(rect: Rect2) -> int:
	if torn >= 0:
		return torn
	if rect.size.x < 220.0 or rect.size.y < 80.0:
		return 0
	var r := RandomNumberGenerator.new()
	r.seed = seed * 13 + 5
	var sides := [RIGHT, BOTTOM, LEFT, TOP]
	var m: int = sides[r.randi() % 4]
	if r.randf() < 0.3:
		m |= sides[r.randi() % 4]
	return m


## Points along one edge from a to b. `inward` is the unit vector pointing into
## the card. A ripped edge bites a ragged depth into the card (`bite`); a cut
## edge only trembles a little.
func _edge(a: Vector2, b: Vector2, inward: Vector2, ripped: bool, rng: RandomNumberGenerator, ext: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var length := a.distance_to(b)
	var step := 5.0 if ripped else 12.0
	var n := maxi(2, int(length / step))
	var dir := (b - a) / maxf(length, 0.01)
	var walk := rng.randf_range(-1.0, 1.0)
	for k in n + 1:
		var t := float(k) / float(n)
		var p := a.lerp(b, t)
		if ripped:
			# a slow random walk (the long swells of a tear) plus fibre-sized teeth
			walk = clampf(walk + rng.randf_range(-0.55, 0.55), -1.0, 1.0)
			var tooth := rng.randf_range(-1.0, 1.0) * 0.6
			var depth := rip * (0.55 + 0.45 * walk) + tooth * rip * 0.35 - ext
			var along := rng.randf_range(-1.6, 1.6)
			pts.append(p + inward * depth + dir * along)
		else:
			var j := rng.randf_range(-wobble, wobble) * (0.0 if k == 0 or k == n else 1.0)
			pts.append(p + inward * j)
	return pts


## The outline of the card inside `r`. With `ext` > 0 ripped edges poke out
## that much further (the pale core under the liner).
func _poly(r: Rect2, mask: int, seed_off: int, ext: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + seed_off
	var c := minf(cut, minf(r.size.x, r.size.y) * 0.25)
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)
	var pts := PackedVector2Array()
	# top edge: left to right
	pts.append_array(_edge(tl + Vector2(c, 0), tr - Vector2(c, 0), Vector2(0, 1), mask & TOP != 0, rng, ext))
	pts.append_array(_edge(tr + Vector2(0, c), br - Vector2(0, c), Vector2(-1, 0), mask & RIGHT != 0, rng, ext))
	pts.append_array(_edge(br - Vector2(c, 0), bl + Vector2(c, 0), Vector2(0, -1), mask & BOTTOM != 0, rng, ext))
	pts.append_array(_edge(bl - Vector2(0, c), tl + Vector2(0, c), Vector2(1, 0), mask & LEFT != 0, rng, ext))
	return pts


## Older callers ask for the outline directly.
func outline(rect: Rect2) -> PackedVector2Array:
	return _poly(rect.grow(-4.0), _mask(rect), 1, 0.0)


func _draw(ci: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	var mask := _mask(rect)
	var r := rect.grow(-4.0)
	r.position += shift
	var face := _poly(r, mask, 1, 0.0)
	var rim := _poly(r, mask, 2, 3.0 + rip * 0.2) if mask != 0 else PackedVector2Array()
	var base := rim if mask != 0 else face
	if shadow != Vector2.ZERO:
		var sh := PackedVector2Array()
		for p in base:
			sh.append(p + shadow)
		rs.canvas_item_add_polygon(ci, sh, PackedColorArray([shadow_col]))
	rs.canvas_item_set_default_texture_repeat(ci, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_MIRROR)
	var off := Vector2(float(seed % 7) * 0.13, float(seed % 5) * 0.17)
	# 1. the pale ribbed core, where the liner is ripped away
	if mask != 0:
		var cuv := PackedVector2Array()
		for p in rim:
			cuv.append(p * (1.0 / 512.0) + off)
		var ct := Cardboard.core_tex()
		rs.canvas_item_add_polygon(ci, rim, PackedColorArray([CORE.lerp(bg, 0.25)]), cuv, ct.get_rid() if ct != null else RID())
	# 2. the face, flat kraft with flutes and fibres
	var uvs := PackedVector2Array()
	for p in face:
		uvs.append(p * (1.0 / 512.0) + off * 1.7)
	var ft := Cardboard.face_tex()
	rs.canvas_item_add_polygon(ci, face, PackedColorArray([bg]), uvs, ft.get_rid() if ft != null else RID())
	# 3. the torn bite is shaded: a dark hairline where the liner lifts, and
	#    rib marks across the exposed core
	if mask != 0:
		_rip_marks(ci, face, rim, r, mask)
	# 4. bevel and rim on the cut edges
	_rims(ci, r, mask)
	# 5. a folded-down corner
	if dogear > 0.0:
		_dogear(ci, r)
	# 6. tape
	var tp := tape
	if tp < 0:
		tp = 0
		if rect.size.x > 240.0 and rect.size.y > 90.0:
			tp = 1 if seed % 3 == 0 else (2 if seed % 3 == 1 else 0)
	if tp > 0:
		var tr := RandomNumberGenerator.new()
		tr.seed = seed * 7 + 3
		match tp:
			1:
				_tape(ci, r.position + Vector2(14, 11), -0.72 + tr.randf_range(-0.08, 0.08), 58.0)
			2:
				_tape(ci, r.position + Vector2(14, 11), -0.72 + tr.randf_range(-0.08, 0.08), 58.0)
				_tape(ci, Vector2(r.end.x - 14, r.position.y + 11), 0.72 + tr.randf_range(-0.08, 0.08), 58.0)
			3:
				_tape(ci, Vector2(r.get_center().x + tr.randf_range(-24, 24), r.position.y + 1), tr.randf_range(-0.1, 0.1), 66.0)


func _rip_marks(ci: RID, face: PackedVector2Array, rim: PackedVector2Array, r: Rect2, mask: int) -> void:
	var rs := RenderingServer
	# hairline along the face's ripped boundary (not along cut edges)
	var n := face.size()
	var run := PackedVector2Array()
	for i in n:
		var p := face[i]
		var on_cut := _on_cut_edge(p, r, mask)
		if on_cut:
			if run.size() > 1:
				rs.canvas_item_add_polyline(ci, run, PackedColorArray([Color(0.36, 0.24, 0.12, 0.55)]), 1.2, true)
			run = PackedVector2Array()
		else:
			run.append(p)
	if run.size() > 1:
		rs.canvas_item_add_polyline(ci, run, PackedColorArray([Color(0.36, 0.24, 0.12, 0.55)]), 1.2, true)
	# ribs: short strokes from the core edge towards the face edge
	for i in mini(rim.size(), face.size()):
		if i % 2 != 0:
			continue
		var pr := rim[i]
		var pf := face[i]
		if _on_cut_edge(pf, r, mask) or pr.distance_to(pf) < 2.5:
			continue
		rs.canvas_item_add_line(ci, pr, pr.lerp(pf, 0.85), CORE_RIB, 1.1, true)
	# thin dark outline of the core where it pokes past the face
	var ring := PackedVector2Array()
	for i in rim.size():
		if not _on_cut_edge(rim[i], r, mask):
			ring.append(rim[i])
		else:
			if ring.size() > 1:
				rs.canvas_item_add_polyline(ci, ring, PackedColorArray([Color(0.30, 0.20, 0.10, 0.5)]), 1.0, true)
			ring = PackedVector2Array()
	if ring.size() > 1:
		rs.canvas_item_add_polyline(ci, ring, PackedColorArray([Color(0.30, 0.20, 0.10, 0.5)]), 1.0, true)


## True for a point that lies on a cut (un-ripped) side of the card.
func _on_cut_edge(p: Vector2, r: Rect2, mask: int) -> bool:
	var m := 9.0
	if p.y < r.position.y + m and mask & TOP == 0:
		return true
	if p.x > r.end.x - m and mask & RIGHT == 0:
		return true
	if p.y > r.end.y - m and mask & BOTTOM == 0:
		return true
	if p.x < r.position.x + m and mask & LEFT == 0:
		return true
	return false


## The crisp dark rim and a light/dark bevel on every cut side.
func _rims(ci: RID, r: Rect2, mask: int) -> void:
	var rs := RenderingServer
	var c := minf(cut, minf(r.size.x, r.size.y) * 0.25)
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)
	var hi := Color(1.0, 0.96, 0.84, 0.30)
	var lo := Color(0.20, 0.12, 0.06, 0.22)
	var edges := [
		[TOP, tl + Vector2(c, 0), tr - Vector2(c, 0), Vector2(0, 1), hi],
		[RIGHT, tr + Vector2(0, c), br - Vector2(0, c), Vector2(-1, 0), lo],
		[BOTTOM, br - Vector2(c, 0), bl + Vector2(c, 0), Vector2(0, -1), lo],
		[LEFT, bl - Vector2(0, c), tl + Vector2(0, c), Vector2(1, 0), hi],
	]
	var ink_c := ink
	ink_c.a = 0.92
	for e in edges:
		if mask & int(e[0]) != 0:
			continue
		var a: Vector2 = e[1]
		var b: Vector2 = e[2]
		var inw: Vector2 = e[3]
		# the chamfered corner joins are drawn once, below
		rs.canvas_item_add_line(ci, a, b, ink_c, line, true)
	# corner chamfers
	var corners := [[TOP | LEFT, tl + Vector2(0, c), tl + Vector2(c, 0)], [TOP | RIGHT, tr - Vector2(c, 0), tr + Vector2(0, c)],
		[BOTTOM | RIGHT, br - Vector2(0, c), br - Vector2(c, 0)], [BOTTOM | LEFT, bl + Vector2(c, 0), bl - Vector2(0, c)]]
	for cn in corners:
		if mask & int(cn[0]) == 0:
			rs.canvas_item_add_line(ci, cn[1], cn[2], ink_c, line, true)


func _dogear(ci: RID, r: Rect2) -> void:
	var rs := RenderingServer
	var d := dogear
	var tr := Vector2(r.end.x, r.position.y)
	# the cut-off corner shows the table; the flap is the folded paper
	var flap := PackedVector2Array([tr + Vector2(-d, 0), tr + Vector2(0, d), tr + Vector2(-d, d)])
	rs.canvas_item_add_polygon(ci, flap, PackedColorArray([bg.lightened(0.18)]))
	rs.canvas_item_add_polyline(ci, PackedVector2Array([flap[0], flap[1], flap[2], flap[0]]), PackedColorArray([Color(ink.r, ink.g, ink.b, 0.8)]), 1.4, true)
	rs.canvas_item_add_line(ci, flap[0] + Vector2(1, 3), flap[2] + Vector2(2, 2), Color(0, 0, 0, 0.18), 3.0, true)


## A strip of masking tape across a corner: pale, see-through, with torn ends.
func _tape(ci: RID, at: Vector2, ang: float, w: float) -> void:
	var rs := RenderingServer
	var hx := Vector2(w * 0.5, 0).rotated(ang)
	var hy := Vector2(0, 11).rotated(ang)
	var j := RandomNumberGenerator.new()
	j.seed = seed * 31 + 9
	var left: Array = []
	var right: Array = []
	for k in 4:
		var t := float(k) / 3.0
		left.append(at - hx + hy * (2.0 * t - 1.0) + Vector2(j.randf_range(-1.8, 1.8), 0).rotated(ang) * (1.0 if k % 2 == 0 else -1.0))
		right.append(at + hx + hy * (1.0 - 2.0 * t) + Vector2(j.randf_range(-1.8, 1.8), 0).rotated(ang) * (1.0 if k % 2 == 0 else -1.0))
	var q := PackedVector2Array()
	for p in left:
		q.append(p)
	for p in right:
		q.append(p)
	var uv := PackedVector2Array()
	for p in q:
		uv.append(p * (1.0 / 128.0))
	var tt := Cardboard.tape_tex()
	var shadow_q := PackedVector2Array()
	for p in q:
		shadow_q.append(p + Vector2(1.2, 2.0))
	rs.canvas_item_add_polygon(ci, shadow_q, PackedColorArray([Color(0.1, 0.06, 0.02, 0.18)]))
	rs.canvas_item_add_polygon(ci, q, PackedColorArray([Color(0.98, 0.93, 0.74, 0.74)]), uv, tt.get_rid() if tt != null else RID())
	var ring := q.duplicate()
	ring.append(q[0])
	rs.canvas_item_add_polyline(ci, ring, PackedColorArray([Color(0.62, 0.52, 0.30, 0.45)]), 1.0, true)
	# faint lengthwise creases
	rs.canvas_item_add_line(ci, at - hx * 0.9 + hy * 0.3, at + hx * 0.9 + hy * 0.3, Color(1, 1, 1, 0.22), 1.0, true)
