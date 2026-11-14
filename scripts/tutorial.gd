## The first-play guide: a card at the top of the screen that asks for one
## thing at a time (move, strike, dodge, talk, trade, look at the ledger) and
## ticks each off when the game sees the player actually do it. Skippable,
## shown once (remembered in user://settings.cfg), `--tutorial` forces it.
class_name Tutorial
extends PanelContainer

const STEPS := [
	{"id": "move", "title": "Take a walk", "text": "Move with W A S D. Hold Shift to run, but running tires you out.", "keys": ["WASD", "Shift"], "t_text": "Drag the stick at the lower left to walk. Push it all the way out (or tap the arrows disc) to run, but running tires you out.", "t_keys": ["Stick", "Arrows"]},
	{"id": "strike", "title": "Strike!", "text": "Click (or J) to swing. Chain three clicks for a combo, the third hits hardest. Swing at a tree to chop wood.", "keys": ["Click", "J"], "t_text": "Tap the big sword disc to swing. Chain three taps for a combo, the third hits hardest. Swing at a tree to chop wood.", "t_keys": ["Sword"]},
	{"id": "dodge", "title": "Dodge", "text": "Press X to roll. You cannot be hurt mid-roll: dodge through an attack for a Perfect Dodge.", "keys": ["X"], "t_text": "Tap the swirl disc to roll. You cannot be hurt mid-roll: dodge through an attack for a Perfect Dodge.", "t_keys": ["Swirl"]},
	{"id": "talk", "title": "Say hello", "text": "Walk up to a townsperson and press E to talk.", "keys": ["E"], "t_text": "Walk up to a townsperson and tap the speech bubble disc to talk.", "t_keys": ["Bubble"]},
	{"id": "shop", "title": "Trade at a door", "text": "Stand at a shop door and press E. Every coin that changes hands is real ledger money.", "keys": ["E"], "t_text": "Stand at a shop door and tap the speech bubble disc. Every coin that changes hands is real ledger money.", "t_keys": ["Bubble"]},
	{"id": "ledger", "title": "Open the ledger", "text": "Press Tab. It lists every shop's coins, and everybody else's.", "keys": ["Tab"], "t_text": "Tap the book disc at the top right. It lists every shop's coins, and everybody else's.", "t_keys": ["Book"]},
	{"id": "settle", "title": "Settle the day", "text": "In the ledger, press the gold button \"Settle day\". It bundles everything bought, sold and paid so far into NEAR transfers (buy or sell something first so there is something to send).", "keys": ["Tab"], "t_text": "In the ledger, tap the gold button \"Settle day\". It bundles everything bought, sold and paid so far into NEAR transfers (buy or sell something first so there is something to send).", "t_keys": ["Book"]},
]

var hud: Hud
var idx := 0
var finished := false
var _moved := 0.0
var _last_pos := Vector2.INF
var _strikes := 0
var _title: Label
var _text: Label
var _count: Label
var _keys: HBoxContainer
var _dots: HBoxContainer
var _flash := 0.0
var _ticks: Control
var _log0 := 0


func _init(p_hud: Hud) -> void:
	hud = p_hud
	var sb := hud._style(Hud.NOTE)
	sb.torn = CardBox.RIGHT
	sb.rip = 6.0
	sb.shadow = Vector2(2, 3)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(340, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	_count = hud._label("1/7", 15, Hud.INK.lightened(0.35))
	top.add_child(_count)
	_title = hud._label("", 24)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_title)
	var skip := hud._button("Skip", Hud.PAPER_LIGHT)
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	skip.add_theme_font_size_override("font_size", 14)
	skip.pressed.connect(finish)
	top.add_child(skip)
	_text = hud._label("", 17)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.custom_minimum_size = Vector2(312, 0)
	vb.add_child(_text)
	_keys = HBoxContainer.new()
	_keys.add_theme_constant_override("separation", 6)
	_keys.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_keys)
	_ticks = StepTicks.new(self)
	vb.add_child(_ticks)
	_show_step()


func _show_step() -> void:
	var s: Dictionary = STEPS[idx]
	_title.text = s["title"]
	_text.text = s["t_text"] if Game.touch and s.has("t_text") else s["text"]
	_count.text = "%d/%d" % [idx + 1, STEPS.size()]
	for c in _keys.get_children():
		c.queue_free()
	for k in (s["t_keys"] if Game.touch and s.has("t_keys") else s["keys"]):
		# plain handwritten keys, underlined like the key strip at the bottom
		var cap := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(1, 1, 1, 0.0)
		cs.border_width_bottom = 2
		cs.border_color = Hud.INK
		cs.content_margin_left = 4
		cs.content_margin_right = 4
		cap.add_theme_stylebox_override("panel", cs)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cl := hud._label(k, 16)
		cl.add_theme_font_override("font", hud.head_font)
		cap.add_child(cl)
		_keys.add_child(cap)
	_log0 = Chain.day_log.size()
	_ticks.queue_redraw()
	reset_size()
	pivot_offset = size * 0.5
	scale = Vector2(0.85, 0.85)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Called every frame by the HUD while the game is running.
func update(main, delta: float) -> void:
	if finished:
		return
	var p: Vector2 = main.player["pos"]
	if _last_pos != Vector2.INF:
		_moved += p.distance_to(_last_pos)
	_last_pos = p
	if Input.is_action_just_pressed("attack") and not hud.blocking():
		_strikes += 1
	var done := false
	match String(STEPS[idx]["id"]):
		"move":
			done = _moved > 160.0
		"strike":
			done = _strikes >= 3
		"dodge":
			done = float(main.player["dash_t"]) > 0.0
		"talk":
			done = main.dialog_npc != null
		"shop":
			done = hud.shop_id != ""
		"ledger":
			done = hud.ledger_panel.visible
		"settle":
			done = Chain.day_log.size() > _log0 or Chain.mode == "offline"
	if done:
		_advance()


func _advance() -> void:
	Sfx.play("coin", -4.0)
	idx += 1
	if idx >= STEPS.size():
		_title.text = "You are ready!"
		_text.text = "Explore the world. Red glowing beasts in the Ruins and the Mine are far deadlier than anything near town."
		_count.text = ""
		for c in _keys.get_children():
			c.queue_free()
		_ticks.visible = false
		reset_size()
		finished = true
		get_tree().create_timer(6.0).timeout.connect(finish)
		return
	_show_step()


func finish() -> void:
	Game.finish_tutorial()
	hud.tutorial = null
	queue_free()


## A row of little hand-inked boxes, one per step: ticked when done, a marker
## blot on the current one.
class StepTicks:
	extends Control
	var tut: Tutorial

	func _init(t: Tutorial) -> void:
		tut = t
		custom_minimum_size = Vector2(0, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := Tutorial.STEPS.size()
		var gap := minf(36.0, (size.x - 20.0) / float(n))
		var x0 := size.x * 0.5 - gap * (n - 1) * 0.5
		var ink := Color(0.20, 0.13, 0.08, 0.9)
		for i in n:
			var c := Vector2(x0 + gap * i, 11.0)
			var box := PackedVector2Array([c + Vector2(-8, -7), c + Vector2(8, -8), c + Vector2(7, 8), c + Vector2(-8, 7), c + Vector2(-8, -7)])
			draw_polyline(box, ink, 1.6, true)
			if i < tut.idx:
				draw_polyline(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-2, 5), c + Vector2(9, -9)]), Color(0.22, 0.55, 0.25), 3.0, true)
			elif i == tut.idx:
				for k in 4:
					draw_line(c + Vector2(-6 + k * 3.5, 6), c + Vector2(-3 + k * 3.5, -6), Color(0.88, 0.52, 0.12, 0.95), 2.6, true)
