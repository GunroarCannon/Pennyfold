## Test lineup for the chibi painter: bakes archetypes (see Archetypes) in all
## three views and shows them side by side. Run:
##   godot --path . res://scenes/look_test.tscn -- --shot=out.png --frames=200
## Args: --page=N --per=N (figures per page) --scale=F --cols=N --ids=a,b,c
##       --look=key:value;key:value (extra params for --ids figures)
##       --mode=strip (raw baked column strips) --size=WxH
extends Node2D

const COL := Vector2i(208, 260)
const KINDS := [["chibi", "side"], ["chibi_front", "front"], ["chibi_back", "back"]]

var figs: Array = []
var shot_path := ""
var shot_frames := 200
var frame := 0
var scale_f := 0.62
var cols := 4
var mode := ""
var bake_root: Node
var labels: Array = []
var cell := Vector2.ZERO
var saved := false


func _arg(prefix: String, def: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return def


func _ready() -> void:
	shot_path = _arg("--shot=")
	shot_frames = int(_arg("--frames=", "200"))
	scale_f = float(_arg("--scale=", "0.62"))
	mode = _arg("--mode=")
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var sz := _arg("--size=", "1600x960").split("x")
	win.size = Vector2i(int(sz[0]), int(sz[1]))
	PaintCute.debug_tri = _arg("--debug") != ""
	bake_root = Node.new()
	add_child(bake_root)
	var ids: Array = []
	if _arg("--ids=") != "":
		ids = Array(_arg("--ids=").split(","))
	else:
		ids = Archetypes.ids()
		var per := int(_arg("--per=", "20"))
		var page := int(_arg("--page=", "0"))
		ids = ids.slice(page * per, (page + 1) * per)
	cols = int(_arg("--cols=", "4"))
	var extra := {}
	for kv in _arg("--look=").split(";", false):
		var parts := kv.split(":")
		if parts.size() == 2:
			extra[parts[0]] = _val(parts[1])
	var skin := Color(0.98, 0.85, 0.72)
	for id in ids:
		var look := Archetypes.get_look(id)
		if look.is_empty():
			continue
		for k in extra:
			look[k] = extra[k]
		if not look.has("skin"):
			look["skin"] = skin
		if not look.has("hair"):
			look["hair"] = Color(0.32, 0.20, 0.14)
		var views: Array = []
		for kd in KINDS:
			var d := Bake.make_rig(bake_root, kd[0], look, COL)
			views.append(d)
		figs.append({"id": id, "views": views})
	var vw := 3.0 if mode != "strip" else 7.0
	cell = Vector2(vw * COL.x * scale_f + 10.0, COL.y * scale_f + 26.0)
	queue_redraw()


func _val(s: String) -> Variant:
	if s == "true":
		return true
	if s == "false":
		return false
	if s.is_valid_float():
		return float(s)
	if s.begins_with("#"):
		return Color(s)
	return s


func _baked(d: Dictionary) -> bool:
	var t: ImageTexture = d["tex"]
	return t.get_image().get_width() > 1


func _all_baked() -> bool:
	for f in figs:
		for d in f["views"]:
			if not _baked(d):
				return false
	return true


func _process(_dt: float) -> void:
	frame += 1
	queue_redraw()
	if shot_path != "" and frame >= shot_frames and not saved and _all_baked():
		saved = true
		_save()


func _save() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_path)
	print("saved ", shot_path)
	get_tree().quit()


func _draw() -> void:
	var win := Vector2(get_window().size)
	draw_rect(Rect2(Vector2.ZERO, win), Color(0.80, 0.72, 0.58))
	var font := ThemeDB.fallback_font
	var i := 0
	for f in figs:
		var origin := Vector2(float(i % cols) * cell.x + 8.0, float(i / cols) * cell.y + 6.0)
		draw_rect(Rect2(origin - Vector2(4, 2), cell - Vector2(2, 2)), Color(0.88, 0.80, 0.66))
		draw_string(font, origin + Vector2(2, 16), String(f["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.17, 0.11, 0.06))
		var views: Array = f["views"]
		if mode == "strip":
			var d: Dictionary = views[0]
			if _baked(d):
				draw_texture_rect(d["tex"], Rect2(origin + Vector2(0, 22), Vector2(COL.x * 7, COL.y) * scale_f), false)
		else:
			for v in views.size():
				_draw_view(views[v], origin + Vector2(float(v) * COL.x * scale_f, 22.0))
		i += 1


## Stacks the piece columns at the same position (they share their origin).
func _draw_view(d: Dictionary, pos: Vector2) -> void:
	if not _baked(d):
		return
	var rig: Dictionary = d["rig"]
	var parts: Array = rig["parts"]
	var order: Array = []
	for j in parts.size():
		order.append([float(parts[j]["z"]), j])
	order.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for o in order:
		var j: int = o[1]
		draw_texture_rect_region(d["tex"], Rect2(pos, Vector2(COL) * scale_f), Rect2(COL.x * j, 0, COL.x, COL.y))
