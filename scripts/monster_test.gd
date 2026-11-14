## Preview of every beast in a grid, front to back: the built-in procedural
## monsters, the sprite beasts from data/bestiary.json, and (with --raw) every
## cardboard-ized sprite in assets/beasts. Run:
##   godot --path . scenes/monster_test.tscn -- [--raw] [--shot=out.png --frames=60]
## Mouse wheel zooms, arrow keys pan, Esc quits.
extends Node3D

const FONT := "res://assets/fonts/PatrickHand-Regular.ttf"
const SIZES := {"wolf": Vector2i(320, 224), "troll": Vector2i(288, 352), "fluffox": Vector2i(320, 240),
	"pebblet": Vector2i(288, 320), "slime": Vector2i(224, 200), "shroom": Vector2i(224, 288),
	"bat": Vector2i(320, 224), "boss": Vector2i(384, 448)}

var cam: Camera3D
var shot := ""
var frames := 60
var frame := 0
var raw := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
		elif a == "--raw":
			raw = true
	Monster.load_bestiary()
	var font: Font = load(FONT)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)

	var items: Array = []
	if raw:
		var man = JSON.parse_string(FileAccess.open("res://assets/beasts/MANIFEST.json", FileAccess.READ).get_as_text())
		for f in (man["kept"] as Dictionary).keys():
			items.append({"label": String(f).get_basename(), "file": f, "h": 2.0})
	else:
		for k in Monster.TYPES:
			var t: Dictionary = Monster.TYPES[k]
			items.append({"label": Monster.name_of(k, true), "kind": k, "h": float(t["cute_h"])})
	var cols := 8 if raw else 6
	var bake_root := Node.new()
	add_child(bake_root)
	var gap := 4.2
	for i in items.size():
		var it: Dictionary = items[i]
		var tex: Texture2D
		var rig: Dictionary
		if it.has("file"):
			tex = load("res://assets/beasts/" + it["file"])
			var sz := tex.get_size()
			rig = {"kind": "sprite", "col": sz, "flip": 1.0, "parts": [{"name": "body", "pivot": Vector2(sz.x * 0.5, sz.y), "z": 0}]}
		else:
			var k: String = it["kind"]
			if Monster.is_sprite(k):
				var t: Dictionary = Monster.TYPES[k]
				tex = load("res://assets/beasts/" + String(t["sprite"]))
				var sz2 := tex.get_size()
				rig = {"kind": "sprite", "col": sz2, "flip": -1.0 if t.get("face", "front") == "left" else 1.0, "parts": [{"name": "body", "pivot": Vector2(sz2.x * 0.5, sz2.y), "z": 0}]}
			else:
				var rk := Monster.rig_kind(k, true)
				var baked: Dictionary = Bake.make_rig(bake_root, rk, {"cute": true}, SIZES[rk])
				tex = baked["tex"]
				rig = baked["rig"]
		var s := Standee.new()
		add_child(s)
		s.setup(tex, rig, float(it["h"]), String(it["label"]), font)
		var row := i / cols
		var col := i % cols
		s.position = Vector3((col - (cols - 1) * 0.5) * gap, 0, row * 3.4)
		s.set_meta("moving", i % 2)
	var rows := (items.size() + cols - 1) / cols
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.position = Vector3(0, 7.5 + rows * 1.3, rows * 3.4 * 0.5 + 12.0 + rows * 1.2)
	cam.look_at(Vector3(0, 1.0, (rows - 1) * 3.4 * 0.5), Vector3.UP)


func _process(delta: float) -> void:
	for c in get_children():
		if c is Standee:
			c.facing = 1.0
			c.animate(delta, float(c.get_meta("moving", 0)))
	if shot != "":
		frame += 1
		if frame >= frames:
			get_viewport().get_texture().get_image().save_png(shot)
			get_tree().quit()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		get_tree().quit()
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.position.z -= 1.5
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.position.z += 1.5
