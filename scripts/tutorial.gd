## The first-play guide: a card at the top of the screen that asks for one
## thing at a time (move, strike, dodge, talk, trade, look at the ledger) and
## ticks each off when the game sees the player actually do it. Skippable,
## shown once (remembered in user://settings.cfg), `--tutorial` forces it.
class_name Tutorial
extends PanelContainer

const STEPS := [
	{"id": "move", "title": "Take a walk", "text": "Move with W A S D. Hold Shift to run, but running tires you out.", "keys": ["WASD", "Shift"]},
	{"id": "strike", "title": "Strike!", "text": "Click (or J) to swing. Chain three clicks for a combo, the third hits hardest. Swing at a tree to chop wood.", "keys": ["Click", "J"]},
	{"id": "dodge", "title": "Dodge", "text": "Press X to roll. You cannot be hurt mid-roll: dodge through an attack for a Perfect Dodge.", "keys": ["X"]},
	{"id": "talk", "title": "Say hello", "text": "Walk up to a townsperson and press E to talk.", "keys": ["E"]},
	{"id": "shop", "title": "Trade at a door", "text": "Stand at a shop door and press E. Every coin that changes hands is real ledger money.", "keys": ["E"]},
	{"id": "ledger", "title": "See the ledger", "text": "Press Tab. The town's coins settle on NEAR; press Settle day now to send them to the chain.", "keys": ["Tab"]},
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


func _init(p_hud: Hud) -> void:
	hud = p_hud
	var sb := hud._style(Hud.NOTE)
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(430, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	_count = hud._label("1/6", 15, Hud.INK.lightened(0.35))
	top.add_child(_count)
	_title = hud._label("", 26)
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
	_text.custom_minimum_size = Vector2(400, 0)
	vb.add_child(_text)
	_keys = HBoxContainer.new()
	_keys.add_theme_constant_override("separation", 6)
	_keys.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_keys)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_dots)
	_show_step()


func _show_step() -> void:
	var s: Dictionary = STEPS[idx]
	_title.text = s["title"]
	_text.text = s["text"]
	_count.text = "%d/%d" % [idx + 1, STEPS.size()]
	for c in _keys.get_children():
		c.queue_free()
	for k in s["keys"]:
		var cap := hud._tag(k, Hud.GOLD, 15)
		cap.get_node("L").add_theme_font_override("font", hud.head_font)
		_keys.add_child(cap)
	for c in _dots.get_children():
		c.queue_free()
	for i in STEPS.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(22, 6)
		d.color = Color(0.40, 0.72, 0.38) if i < idx else (Hud.GOLD if i == idx else Hud.INK.lightened(0.7))
		_dots.add_child(d)
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
		for c in _dots.get_children():
			c.queue_free()
		reset_size()
		finished = true
		get_tree().create_timer(6.0).timeout.connect(finish)
		return
	_show_step()


func finish() -> void:
	Game.finish_tutorial()
	hud.tutorial = null
	queue_free()
