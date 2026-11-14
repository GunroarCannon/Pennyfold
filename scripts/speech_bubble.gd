## A speech bubble that floats over a figure: a cut-paper bubble (see
## shaders/bubble.gdshader) sized to its text, with a typewriter reveal, a pop
## in and a fade out. The node's origin is the tip of the bubble's tail.
class_name SpeechBubble
extends Node3D

const SHADER := preload("res://shaders/bubble.gdshader")
const PIXEL := 0.0037
const INK := Color(0.17, 0.11, 0.07)
const PAD := 0.22
const TAIL := 0.26

var font: Font
var _quad: MeshInstance3D
var _mat: ShaderMaterial
var _label: Label3D
var _full := ""
var _hide_t := 0.0
var _tween: Tween
var _alive := false


func _init(p_font: Font = null) -> void:
	font = p_font
	visible = false


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_quad = MeshInstance3D.new()
	_quad.mesh = QuadMesh.new()
	_quad.material_override = _mat
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_quad)
	_label = Label3D.new()
	_label.font = font
	_label.font_size = 44
	_label.pixel_size = PIXEL
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = INK
	_label.outline_size = 0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.render_priority = 30
	_label.outline_render_priority = 29
	_label.shaded = false
	add_child(_label)
	_mat.render_priority = 20


## style: 0 round, 1 shout, 2 thought, 3 cut paper. max_px: widest line.
func show_text(text: String, secs := 3.0, style := 3, fill := Color(0.995, 0.99, 0.965), max_px := 380.0, text_col := INK, typed := true) -> void:
	if _quad == null:
		return
	var lines := _wrap(text, max_px)
	var widest := 0.0
	for l in lines:
		widest = maxf(widest, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.font_size).x)
	var line_h := font.get_height(_label.font_size) * 1.05
	var bw := maxf(widest * PIXEL + PAD * 2.0, 0.7)
	var bh := lines.size() * line_h * PIXEL + PAD * 1.25
	_full = "\n".join(PackedStringArray(lines))
	_label.line_spacing = 0.0
	_label.modulate = text_col
	_mat.set_shader_parameter("body_m", Vector2(bw, bh))
	_mat.set_shader_parameter("tail_m", TAIL)
	_mat.set_shader_parameter("style", style)
	_mat.set_shader_parameter("fill", fill)
	_mat.set_shader_parameter("fade", 1.0)
	(_quad.mesh as QuadMesh).size = Vector2(bw + 0.28, bh + TAIL + 0.28)
	var cy := bh * 0.5 + TAIL * 0.5 + 0.02
	_quad.position = Vector3(0, cy, 0)
	# the bubble body is centred TAIL/2 above the quad centre; the text sits exactly there
	_label.position = Vector3(0.0, cy + TAIL * 0.5, 0.0)
	_hide_t = secs
	_alive = true
	visible = true
	if _tween:
		_tween.kill()
	scale = Vector3.ONE * 0.3
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector3(1.12, 1.12, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if typed and _full.length() > 2:
		_label.text = ""
		var dur := clampf(_full.length() * 0.022, 0.2, 1.6)
		_tween.parallel().tween_method(_type, 0.0, float(_full.length()), dur).set_delay(0.08)
	else:
		_label.text = _full


## Keeps the bubble up (a conversation) until hide_bubble() is called.
func hold() -> void:
	_hide_t = 9999.0


func set_line(text: String, style := 3, fill := Color(0.995, 0.99, 0.965), max_px := 520.0) -> void:
	show_text(text, 9999.0, style, fill, max_px)


func _type(n: float) -> void:
	# keep the line breaks of the full text but hide the untyped tail with spaces, so the
	# centred block does not shift while it types
	var shown := _full.substr(0, int(n))
	var rest := _full.substr(int(n))
	var blank := ""
	for ch in rest:
		blank += "
" if ch == "
" else " "
	_label.text = shown + blank


func hide_bubble() -> void:
	if not _alive:
		return
	_alive = false
	_hide_t = 0.0
	if _tween:
		_tween.kill()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.1, 0.1, 1.0), 0.14).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	if not _alive:
		return
	_hide_t -= delta
	if _hide_t <= 0.0:
		hide_bubble()


func _wrap(text: String, max_px: float) -> Array:
	var lines: Array = []
	for para in text.split("\n"):
		var cur := ""
		for w in para.split(" "):
			var cand := w if cur == "" else cur + " " + w
			if cur != "" and font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x > max_px:
				lines.append(cur)
				cur = w
			else:
				cur = cand
		lines.append(cur)
	return lines
