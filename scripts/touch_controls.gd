## On-screen controls for phones and tablets, drawn as cardboard cut-outs.
##
## One node owns every finger so the stick, the buttons, the camera drag and the
## pinch never fight over a touch. It feeds the normal Input Map with
## Input.action_press / action_release, so main.gd's input code is unchanged:
## the left stick drives move_*, the discs press attack, dodge, jump and so on.
## Menu discs (map, quests, ledger, help) call the HUD directly.
##
## Only visible in touch mode (Game.touch) after Play. While a panel is open
## (shop, dialog, map, quests) the stick and action discs are hidden and only
## the menu column stays, with a close disc on top.
class_name TouchControls
extends Control

## Stick travel below this fraction does nothing; Godot rescales the rest.
const DEAD := 0.18
## Pushed this far out, the stick also sprints.
const SPRINT_AT := 0.93
## A tap must hold the action at least this long so main.gd's per-frame
## is_action_just_pressed sees it.
const MIN_HOLD := 0.09

## kind, action ("" for special ones), anchor offset from the bottom-right corner
## (dx from right, dy from bottom), radius, fill colour.
const ACTIONS := [
	{"id": "attack", "act": "attack", "at": Vector2(80, 80), "r": 58.0, "col": Color(0.96, 0.62, 0.64)},
	{"id": "jump", "act": "jump", "at": Vector2(212, 58), "r": 42.0, "col": Color(0.60, 0.86, 0.68)},
	{"id": "interact", "act": "interact", "at": Vector2(172, 168), "r": 42.0, "col": Color(0.99, 0.78, 0.26)},
	{"id": "dodge", "act": "dodge", "at": Vector2(80, 212), "r": 42.0, "col": Color(0.62, 0.80, 0.97)},
	{"id": "beam", "act": "beam", "at": Vector2(300, 128), "r": 38.0, "col": Color(0.62, 0.80, 0.97)},
	{"id": "dragon", "act": "dragon", "at": Vector2(258, 242), "r": 38.0, "col": Color(0.96, 0.62, 0.64)},
	{"id": "eat", "act": "eat", "at": Vector2(142, 308), "r": 38.0, "col": Color(0.94, 0.84, 0.66)},
	{"id": "sprint", "act": "", "at": Vector2(330, 38), "r": 38.0, "col": Color(0.94, 0.84, 0.66)},
]
const MENU := ["close", "map", "quests", "ledger", "beasts", "help"]

var hud: Hud
var main: Node

var _sc := 1.0
var _vs := Vector2(1280, 720)
var _inset := Vector4.ZERO  # left, top, right, bottom
var _discs: Array = []  # {id, act, c, r, col}
var _menu: Array = []  # {id, c, r}
var _stick_home := Vector2(180, 540)
var _stick_c := Vector2(180, 540)
var _stick_r := 100.0
var _stick_zone := Rect2()
var _stick := Vector2.ZERO
var _fingers := {}  # index -> {"kind": String, "id": String, "pos": Vector2}
var _pressed_at := {}  # action -> time it went down
var _release_at := {}  # action -> time to let go
var _axis_on := {}  # move actions we are holding
var _sprint_toggle := false
var _sprint_held := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		InputMap.action_set_deadzone(a, DEAD)
	Game.touch_changed.connect(func(_on: bool) -> void: _fingers.clear())
	_layout()


func _active() -> bool:
	return Game.touch and Game.started and hud != null and not hud.title_panel.visible


func _panels_open() -> bool:
	return hud.blocking()


# ---------------- layout ----------------

## Notch and gesture-bar insets, in viewport pixels.
func _safe_inset() -> Vector4:
	if not (OS.has_feature("mobile") or OS.has_feature("web")):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return Vector4.ZERO
	var sa := Rect2(DisplayServer.get_display_safe_area())
	if sa.size.x <= 0.0 or sa.size.y <= 0.0:
		return Vector4.ZERO
	var k := _vs / win
	return Vector4(maxf(0.0, sa.position.x) * k.x, maxf(0.0, sa.position.y) * k.y,
			maxf(0.0, win.x - sa.end.x) * k.x, maxf(0.0, win.y - sa.end.y) * k.y)


func _layout() -> void:
	_vs = get_viewport_rect().size
	_inset = _safe_inset()
	# Portrait phones are tall, so the same pixel sizes would be tiny to a thumb.
	_sc = 1.0 if _vs.x >= _vs.y * 1.1 else 1.5
	var corner := Vector2(_vs.x - _inset.z, _vs.y - _inset.w)
	_discs.clear()
	for d in ACTIONS:
		var at: Vector2 = d["at"]
		_discs.append({"id": d["id"], "act": d["act"], "c": corner - at * _sc, "r": float(d["r"]) * _sc, "col": d["col"]})
	_stick_r = 100.0 * _sc
	_stick_home = Vector2(_inset.x + 190.0 * _sc, _vs.y - _inset.w - 180.0 * _sc)
	if not _fingers.values().any(func(f: Dictionary) -> bool: return f["kind"] == "stick"):
		_stick_c = _stick_home
	_stick_zone = Rect2(_inset.x, _vs.y * 0.34, _vs.x * 0.42 if _vs.x >= _vs.y else _vs.x * 0.5, _vs.y * 0.66 - _inset.w)
	_menu.clear()
	var mr := 28.0 * _sc
	var mx := _vs.x - _inset.z - 14.0 - 212.0 - 14.0 - mr
	if hud != null and hud.minimap != null:
		mx = hud.minimap.position.x - 14.0 - mr
	for i in MENU.size():
		_menu.append({"id": MENU[i], "c": Vector2(mx, _inset.y + 80.0 * _sc + i * (mr * 2.0 + 10.0)), "r": mr})


# ---------------- touches ----------------

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if not Game.touch:
			Game.enable_touch()
		if not _active():
			return
		if ev.pressed:
			_down(ev.index, ev.position)
		else:
			_up(ev.index)
	elif ev is InputEventScreenDrag and _active():
		_drag(ev.index, ev.position, ev.relative)


func _hit(c: Vector2, r: float, p: Vector2) -> bool:
	return c.distance_to(p) <= r * 1.12


func _down(idx: int, p: Vector2) -> void:
	_layout()
	for m in _menu:
		if not _menu_visible(m["id"]):
			continue
		if _hit(m["c"], m["r"], p):
			_fingers[idx] = {"kind": "menu", "id": m["id"], "pos": p}
			get_viewport().set_input_as_handled()
			Sfx.play("click")
			_menu_press(m["id"])
			return
	if _panels_open():
		return  # panels take touches through the mouse that Godot emulates
	for d in _discs:
		if _hit(d["c"], d["r"], p):
			_fingers[idx] = {"kind": "disc", "id": d["id"], "pos": p}
			get_viewport().set_input_as_handled()
			_disc_press(d)
			return
	if _stick_zone.has_point(p) and not _has_kind("stick"):
		_fingers[idx] = {"kind": "stick", "id": "", "pos": p}
		var half := _stick_r
		_stick_c = Vector2(clampf(p.x, _stick_zone.position.x + half, maxf(_stick_zone.end.x - half, _stick_zone.position.x + half)),
				clampf(p.y, _stick_zone.position.y + half, maxf(_stick_zone.end.y - half, _stick_zone.position.y + half)))
		_stick = (p - _stick_c) / _stick_r
		get_viewport().set_input_as_handled()
		return
	_fingers[idx] = {"kind": "cam", "id": "", "pos": p}
	get_viewport().set_input_as_handled()


func _has_kind(kind: String) -> bool:
	for f in _fingers.values():
		if f["kind"] == kind:
			return true
	return false


func _drag(idx: int, p: Vector2, rel: Vector2) -> void:
	if not _fingers.has(idx):
		return
	var f: Dictionary = _fingers[idx]
	var prev: Vector2 = f["pos"]
	f["pos"] = p
	match String(f["kind"]):
		"stick":
			_stick = ((p - _stick_c) / _stick_r).limit_length(1.0)
		"cam":
			var others: Array = []
			for k in _fingers:
				if k != idx and _fingers[k]["kind"] == "cam":
					others.append(_fingers[k]["pos"])
			if others.is_empty():
				main.cam_yaw -= rel.x * 0.009
				main.cam_pitch = clampf(main.cam_pitch + rel.y * 0.005, 0.18, 1.15)
			else:
				# two fingers pinch: spreading them zooms in
				var o: Vector2 = others[0]
				var gain := p.distance_to(o) - prev.distance_to(o)
				main.cam_dist = clampf(main.cam_dist - gain * 0.03, 6.0, 24.0)


func _up(idx: int) -> void:
	if not _fingers.has(idx):
		return
	var f: Dictionary = _fingers[idx]
	_fingers.erase(idx)
	match String(f["kind"]):
		"stick":
			_stick = Vector2.ZERO
		"disc":
			for d in _discs:
				if d["id"] == f["id"] and d["act"] != "":
					_schedule_release(d["act"])


func _disc_press(d: Dictionary) -> void:
	Sfx.play("tick", -3.0, 0.05)
	if d["id"] == "sprint":
		_sprint_toggle = not _sprint_toggle
		return
	var act: String = d["act"]
	_release_at.erase(act)
	_pressed_at[act] = Time.get_ticks_msec() / 1000.0
	Input.action_press(act)


func _schedule_release(act: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_release_at[act] = maxf(now, float(_pressed_at.get(act, now)) + MIN_HOLD)


func _menu_visible(id: String) -> bool:
	if id == "close":
		return _panels_open()
	return true


func _menu_press(id: String) -> void:
	match id:
		"close":
			hud.close_all()
			main._close_dialog()
		"map":
			hud.toggle_map()
		"quests":
			hud.toggle_quests()
		"ledger":
			hud.toggle_ledger()
		"beasts":
			hud.toggle_bestiary()
		"help":
			hud.toggle_keys()


# ---------------- per frame ----------------

func _process(_delta: float) -> void:
	var on := _active()
	visible = on
	if not on:
		_release_everything()
		return
	_layout()
	if _panels_open():
		# stick and discs make no sense under a panel; drop what they were doing
		for k in _fingers.keys():
			if _fingers[k]["kind"] in ["stick", "disc", "cam"]:
				_up(k)
		_stick = Vector2.ZERO
	_apply_stick()
	var now := Time.get_ticks_msec() / 1000.0
	for act in _release_at.keys():
		if now >= float(_release_at[act]):
			Input.action_release(act)
			_release_at.erase(act)
			_pressed_at.erase(act)
	queue_redraw()


func _apply_stick() -> void:
	var v := _stick
	_axis("move_left", maxf(-v.x, 0.0))
	_axis("move_right", maxf(v.x, 0.0))
	_axis("move_up", maxf(-v.y, 0.0))
	_axis("move_down", maxf(v.y, 0.0))
	var want := _sprint_toggle or _stick.length() >= SPRINT_AT
	if want != _sprint_held:
		_sprint_held = want
		if want:
			Input.action_press("sprint")
		else:
			Input.action_release("sprint")


func _axis(act: String, s: float) -> void:
	if s > 0.001:
		Input.action_press(act, s)
		_axis_on[act] = true
	elif _axis_on.has(act):
		Input.action_release(act)
		_axis_on.erase(act)


func _release_everything() -> void:
	_fingers.clear()
	_stick = Vector2.ZERO
	_apply_stick()
	for act in _release_at.keys():
		Input.action_release(act)
	_release_at.clear()
	_pressed_at.clear()


# ---------------- drawing ----------------

func _draw() -> void:
	var open := _panels_open()
	if not open:
		_draw_stick()
		for d in _discs:
			_draw_disc(d)
	for m in _menu:
		if _menu_visible(m["id"]):
			_draw_round(m["c"], m["r"], Color(0.94, 0.84, 0.66) if m["id"] != "close" else Color(0.96, 0.62, 0.64), _is_down("menu", m["id"]), absi(str(m["id"]).hash()) % 97)
			_icon(m["id"], m["c"], m["r"])


func _is_down(kind: String, id: String) -> bool:
	for f in _fingers.values():
		if f["kind"] == kind and f["id"] == id:
			return true
	return false


## A hand-cut cardboard piece: uneven polygon (scissors, not a compass), a pale
## corrugated edge showing on the thick side, a dark rim, flutes across the
## face, and masking tape on the bigger ones. Pressed pieces sink onto their shadow.
func _cut_poly(c: Vector2, r: float, seed_: int, sides := 11) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 7919 + 13
	for i in sides:
		var a := TAU * float(i) / float(sides) + rng.randf_range(-0.06, 0.06)
		pts.append(c + Vector2.from_angle(a) * r * rng.randf_range(0.93, 1.03))
	return pts


func _shift(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + off)
	return out


func _draw_round(c: Vector2, r: float, col: Color, down: bool, seed_ := 1) -> void:
	var lift := Vector2(3, 4) * _sc if down else Vector2.ZERO
	var thick := Vector2(2.5, 3.5) * _sc if not down else Vector2(1, 1.5) * _sc
	var base := _cut_poly(c + lift, r, seed_)
	var face := col.darkened(0.14) if down else col.darkened(0.04)
	if not down:
		draw_colored_polygon(_shift(base, thick + Vector2(3, 4) * _sc), Color(0.16, 0.10, 0.05, 0.30))
	# the pale corrugated core, seen along the thick edge
	draw_colored_polygon(_shift(base, thick), CardBox.CORE)
	draw_polyline(_closed(_shift(base, thick)), Hud.INK, 2.0 * _sc, true)
	draw_colored_polygon(base, face)
	draw_polyline(_closed(base), Hud.INK, 2.6 * _sc, true)
	# flutes: faint ribs across the face
	for i in range(-3, 4):
		var y := float(i) * r * 0.24
		var hw := sqrt(maxf(0.0, r * r * 0.82 - y * y))
		draw_line(c + lift + Vector2(-hw, y), c + lift + Vector2(hw, y), Color(0.45, 0.30, 0.16, 0.16), 1.6)
	if r > 50.0 * _sc and not down:
		_tape(c + Vector2(-r * 0.55, -r * 0.72), -0.6)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


## A strip of masking tape stuck on a corner.
func _tape(at: Vector2, rot: float) -> void:
	var w := 34.0 * _sc
	var h := 13.0 * _sc
	var pts := PackedVector2Array()
	for q in [Vector2(-w, -h), Vector2(w, -h * 0.8), Vector2(w, h), Vector2(-w, h * 0.7)]:
		pts.append(at + (q as Vector2).rotated(rot))
	draw_colored_polygon(pts, Color(0.93, 0.89, 0.74, 0.82))
	draw_polyline(_closed(pts), Color(Hud.INK, 0.25), 1.2, true)


func _draw_disc(d: Dictionary) -> void:
	var down := _is_down("disc", d["id"])
	var col: Color = d["col"]
	if d["id"] == "sprint" and (_sprint_toggle or _sprint_held):
		col = Hud.GOLD
		down = true
	_draw_round(d["c"], d["r"], col, down, absi(str(d["id"]).hash()) % 97)
	var lift := Vector2(3, 4) * _sc if down else Vector2.ZERO
	_icon(d["id"], d["c"] + lift, d["r"])


func _draw_stick() -> void:
	var held := _has_kind("stick")
	var base := _stick_c if held else _stick_home
	var a := 1.0 if held else 0.75
	var ink := Color(Hud.INK, a)
	# a square plate of board with cut corners, thick pale edge, flutes
	var h := _stick_r * 0.92
	var ch := 26.0 * _sc
	var plate := PackedVector2Array([Vector2(-h + ch, -h), Vector2(h - ch * 0.6, -h + 2), Vector2(h, -h + ch), Vector2(h - 3, h - ch * 0.8),
			Vector2(h - ch, h), Vector2(-h + ch * 0.7, h - 2), Vector2(-h, h - ch), Vector2(-h + 2, -h + ch * 0.7)])
	var pts := PackedVector2Array()
	for p in plate:
		pts.append(base + p)
	var thick := Vector2(4, 6) * _sc
	draw_colored_polygon(_shift(pts, thick + Vector2(3, 5) * _sc), Color(0.16, 0.10, 0.05, 0.26 * a))
	draw_colored_polygon(_shift(pts, thick), Color(CardBox.CORE, a))
	draw_polyline(_closed(_shift(pts, thick)), ink, 2.0 * _sc, true)
	draw_colored_polygon(pts, Color(Hud.PAPER_DARK, 0.9 * a))
	draw_polyline(_closed(pts), ink, 2.6 * _sc, true)
	for i in range(-4, 5):
		var y := float(i) * h * 0.2
		draw_line(base + Vector2(-h + 6, y), base + Vector2(h - 6, y), Color(0.30, 0.18, 0.08, 0.14 * a), 1.6)
	# inked guide: a ring and four arrows, drawn with a marker
	draw_arc(base, h * 0.62, 0.0, TAU, 36, Color(Hud.INK, 0.35 * a), 2.2 * _sc, true)
	for i in 4:
		var dir := Vector2.from_angle(i * PI * 0.5 - PI * 0.5)
		var perp := dir.orthogonal()
		var tip := base + dir * (h - 14.0 * _sc)
		var back := base + dir * (h - 34.0 * _sc)
		draw_polyline(PackedVector2Array([back + perp * 10.0 * _sc, tip, back - perp * 10.0 * _sc]), Color(Hud.INK, 0.6 * a), 3.2 * _sc, true)
	if not held:
		_tape(base + Vector2(-h * 0.7, -h * 0.9), -0.5)
	# the knob: a round card cut-out
	var thumb := base + _stick * _stick_r * 0.78
	var sprint := _stick.length() >= SPRINT_AT
	var tr := 42.0 * _sc
	var knob := _cut_poly(thumb, tr, 5, 12)
	draw_colored_polygon(_shift(knob, Vector2(4, 6) * _sc), Color(0.16, 0.10, 0.05, 0.30 * a))
	draw_colored_polygon(_shift(knob, Vector2(2, 3.5) * _sc), Color(CardBox.CORE, a))
	draw_polyline(_closed(_shift(knob, Vector2(2, 3.5) * _sc)), ink, 1.8 * _sc, true)
	draw_colored_polygon(knob, Color(Hud.GOLD if sprint else Hud.PAPER_LIGHT, a))
	draw_polyline(_closed(knob), ink, 2.6 * _sc, true)
	for i in range(-2, 3):
		var y := float(i) * tr * 0.3
		var hw := sqrt(maxf(0.0, tr * tr * 0.8 - y * y))
		draw_line(thumb + Vector2(-hw, y), thumb + Vector2(hw, y), Color(0.45, 0.30, 0.16, 0.16 * a), 1.5)


# ---------------- hand-drawn icons ----------------
# Everything is a few pen strokes in a unit square (-1..1), scaled by the disc.

func _icon(id: String, c: Vector2, r: float) -> void:
	var u := r * 0.52
	var ink := Hud.INK
	var w := maxf(3.0, r * 0.075)
	match id:
		"attack":
			_line(c, u, [Vector2(-0.55, 0.55), Vector2(0.62, -0.62)], ink, w * 1.5)
			_line(c, u, [Vector2(-0.46, -0.06), Vector2(0.06, 0.46)], ink, w * 1.3)
			draw_circle(c + Vector2(-0.62, 0.62) * u, w * 1.2, ink)
		"jump":
			_line(c, u, [Vector2(-0.6, -0.05), Vector2(0.0, -0.6), Vector2(0.6, -0.05)], ink, w * 1.3)
			_line(c, u, [Vector2(-0.6, 0.5), Vector2(0.0, -0.05), Vector2(0.6, 0.5)], ink, w * 1.3)
		"interact":
			var bub := PackedVector2Array([Vector2(-0.7, -0.5), Vector2(0.7, -0.5), Vector2(0.7, 0.3), Vector2(0.1, 0.3),
					Vector2(-0.3, 0.7), Vector2(-0.3, 0.3), Vector2(-0.7, 0.3), Vector2(-0.7, -0.5)])
			_line(c, u, bub, ink, w)
			_line(c, u, [Vector2(0.0, -0.32), Vector2(0.0, 0.05)], ink, w * 1.3)
			draw_circle(c + Vector2(0.0, 0.18) * u, w * 0.9, ink)
		"dodge":
			draw_arc(c, u * 0.62, deg_to_rad(150), deg_to_rad(400), 18, ink, w * 1.3, true)
			var tip := c + Vector2.from_angle(deg_to_rad(40)) * u * 0.62
			_line(tip, u, [Vector2(-0.34, -0.4), Vector2(0.0, 0.0), Vector2(-0.5, 0.2)], ink, w * 1.3)
		"beam":
			_line(c, u, [Vector2(0.25, -0.75), Vector2(-0.3, 0.05), Vector2(0.15, 0.05), Vector2(-0.25, 0.78)], ink, w * 1.4)
			_line(c, u, [Vector2(0.55, -0.1), Vector2(0.8, -0.3)], ink, w)
			_line(c, u, [Vector2(-0.55, 0.15), Vector2(-0.82, 0.3)], ink, w)
		"dragon":
			var flame := PackedVector2Array([Vector2(0.0, -0.8), Vector2(0.3, -0.35), Vector2(0.5, 0.1), Vector2(0.36, 0.55),
					Vector2(0.0, 0.78), Vector2(-0.36, 0.55), Vector2(-0.5, 0.15), Vector2(-0.28, -0.1), Vector2(-0.12, -0.3)])
			var pts := PackedVector2Array()
			for p in flame:
				pts.append(c + p * u)
			draw_colored_polygon(pts, Color(0.98, 0.70, 0.30))
			_line(c, u, flame + PackedVector2Array([flame[0]]), ink, w)
			_line(c, u, [Vector2(0.0, 0.2), Vector2(0.12, 0.45), Vector2(-0.08, 0.6)], ink, w * 0.8)
		"eat":
			var loaf := PackedVector2Array()
			for i in 25:
				var a := TAU * float(i) / 24.0
				loaf.append(Vector2(cos(a) * 0.82, sin(a) * 0.5))
			_line(c, u, loaf, ink, w)
			for x in [-0.35, 0.0, 0.35]:
				_line(c, u, [Vector2(x - 0.1, -0.3), Vector2(x + 0.1, 0.12)], ink, w * 0.9)
		"sprint":
			_line(c, u, [Vector2(-0.6, -0.55), Vector2(-0.05, 0.0), Vector2(-0.6, 0.55)], ink, w * 1.3)
			_line(c, u, [Vector2(0.05, -0.55), Vector2(0.6, 0.0), Vector2(0.05, 0.55)], ink, w * 1.3)
		"map":
			_line(c, u, [Vector2(-0.7, -0.5), Vector2(-0.25, -0.7), Vector2(0.25, -0.5), Vector2(0.7, -0.7), Vector2(0.7, 0.5),
					Vector2(0.25, 0.7), Vector2(-0.25, 0.5), Vector2(-0.7, 0.7), Vector2(-0.7, -0.5)], ink, w * 0.9)
			_line(c, u, [Vector2(-0.25, -0.7), Vector2(-0.25, 0.5)], ink, w * 0.7)
			_line(c, u, [Vector2(0.25, -0.5), Vector2(0.25, 0.7)], ink, w * 0.7)
		"quests":
			_line(c, u, [Vector2(-0.5, -0.7), Vector2(0.5, -0.7), Vector2(0.5, 0.7), Vector2(-0.5, 0.7), Vector2(-0.5, -0.7)], ink, w * 0.9)
			for y in [-0.35, 0.0, 0.35]:
				_line(c, u, [Vector2(-0.28, y), Vector2(0.28, y)], ink, w * 0.8)
		"ledger":
			_line(c, u, [Vector2(-0.75, -0.55), Vector2(0.0, -0.4), Vector2(0.75, -0.55), Vector2(0.75, 0.55), Vector2(0.0, 0.7),
					Vector2(-0.75, 0.55), Vector2(-0.75, -0.55)], ink, w * 0.9)
			_line(c, u, [Vector2(0.0, -0.4), Vector2(0.0, 0.7)], ink, w * 0.7)
			draw_circle(c + Vector2(-0.38, 0.05) * u, u * 0.18, ink)
			_line(c, u, [Vector2(0.22, -0.1), Vector2(0.55, -0.15)], ink, w * 0.7)
			_line(c, u, [Vector2(0.22, 0.2), Vector2(0.55, 0.15)], ink, w * 0.7)
		"beasts":
			# a little horned head
			_line(c, u, [Vector2(-0.55, 0.6), Vector2(-0.6, -0.1), Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(0.6, -0.1), Vector2(0.55, 0.6), Vector2(-0.55, 0.6)], ink, w * 0.9)
			_line(c, u, [Vector2(-0.35, -0.35), Vector2(-0.55, -0.75)], ink, w * 0.9)
			_line(c, u, [Vector2(0.35, -0.35), Vector2(0.55, -0.75)], ink, w * 0.9)
			draw_circle(c + Vector2(-0.2, 0.05) * u, u * 0.09, ink)
			draw_circle(c + Vector2(0.2, 0.05) * u, u * 0.09, ink)
		"help":
			var f: Font = hud.head_font
			var fs := int(r * 1.15)
			var sz := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, c + Vector2(-sz.x * 0.5, sz.y * 0.28), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		"close":
			_line(c, u, [Vector2(-0.5, -0.5), Vector2(0.5, 0.5)], ink, w * 1.5)
			_line(c, u, [Vector2(0.5, -0.5), Vector2(-0.5, 0.5)], ink, w * 1.5)


## A pen stroke through unit-square points.
func _line(c: Vector2, u: float, pts: Variant, col: Color, w: float) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + Vector2(p) * u)
	draw_polyline(out, col, w, true)
