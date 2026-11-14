## The first scene: black ink on kraft cardboard. The studio's box mark sits
## still for a beat, then a jolt shakes the board, the box cracks along its
## lightning seam and CRITBOX slams in underneath. Then the loading card
## (boot.gd) takes over while the game builds itself.
## Debug runs (any --flag after --) and headless go straight to the game.
extends Control

const BOOT := "res://assets/splash/boot.png"
const CRACK := "res://assets/splash/crack.png"
const GAME := "res://scenes/main.tscn"
const HOLD := 0.55
const SHOW := 1.5
const INK := Color(0.12, 0.08, 0.05)

var _pic: TextureRect
var _name: Label
var _shake := 0.0
var _t := 0.0
var _go_at := -1.0
var _gone := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.62, 0.44, 0.27)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_pic = TextureRect.new()
	_pic.texture = load(BOOT) as Texture2D
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pic)
	_name = Label.new()
	_name.text = "CRITBOX"
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_override("font", load("res://assets/fonts/LilitaOne-Regular.ttf"))
	_name.add_theme_color_override("font_color", INK)
	_name.modulate.a = 0.0
	add_child(_name)
	resized.connect(_layout)
	_layout()
	var straight := DisplayServer.get_name() == "headless"
	var shot_mode := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--splash="):
			shot_mode = a.substr(9)
		elif a.begins_with("--"):
			straight = true
	if shot_mode != "":
		_debug_shot(shot_mode)
		return
	if straight:
		_start_game(false)
		return
	var tw := create_tween()
	tw.tween_interval(HOLD)
	tw.tween_callback(_jolt)
	tw.tween_interval(SHOW)
	tw.tween_callback(_start_game)


func _layout() -> void:
	var short := minf(size.x, size.y)
	var fs := int(short * 0.11)
	_name.add_theme_font_size_override("font_size", fs)
	_name.size = Vector2(size.x, fs * 1.4)
	_name.position = Vector2(0.0, size.y * 0.5 + short * 0.24)
	_name.pivot_offset = _name.size * 0.5


func _jolt() -> void:
	_pic.texture = load(CRACK) as Texture2D
	_shake = 1.0
	_name.scale = Vector2(1.8, 1.8)
	Sfx.play("boom", -2.0, 0.0)
	Sfx.play("rip", 0.0, 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_name, "modulate:a", 1.0, 0.12)
	tw.tween_property(_name, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta / 0.45, 0.0)
		var amp := minf(size.x, size.y) * 0.03 * _shake * _shake
		_pic.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amp
		_name.position.x = _pic.position.x * 0.6


func _input(ev: InputEvent) -> void:
	# a tap or key skips the show
	if (ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.is_pressed() and _t > 0.2:
		_start_game()


func _start_game(card := true) -> void:
	if _gone:
		return
	_gone = true
	if card:
		Boot.begin("Unfolding the kingdom")
	# one frame so the card is on screen before the heavy scene starts building
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME)


## `--splash=boot|crack|load --shot=file.png`: renders one frame of the intro.
func _debug_shot(mode: String) -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7)
	if mode == "crack":
		_jolt()
	elif mode == "load":
		Boot.begin("Waking the townsfolk")
		Boot.progress(0.6)
		_pic.visible = false
		_name.visible = false
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
