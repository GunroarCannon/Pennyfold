## A cardboard puppet in the 3D town. Every limb is its own cut-out piece
## pinned at a joint (like a paper doll with split pins), with a darker back
## layer for thickness. Legs and arms swing when walking, the weapon arm
## winds up and chops when attacking, workers hammer away at their job, capes
## and tails trail behind. Also: a soft ground blob, a name tag, a speech line
## and an hp bar. Flips like paper when turning, falls flat when it dies.
class_name Standee
extends Node3D

const EDGE := Color(0.50, 0.37, 0.22)
const INK := Color(0.17, 0.11, 0.06)
const LAYER := 0.02
## Stride speed (radians per second at full walking speed).
const STRIDE := {"person": 10.0, "wolf": 14.0, "troll": 6.5, "chibi": 13.0, "fluffox": 15.0,
	"pebblet": 9.0, "slime": 7.0, "shroom": 12.0, "bat": 6.0, "boss": 4.0}

var body: Node3D
var joints := {}
var sprites: Array[Sprite3D] = []
var name_label: Label3D
var bubble: SpeechBubble
var hp_bar: MeshInstance3D
var _hp_mat: ShaderMaterial
var _hp_value := 1.0
var _hp_trail := 1.0
var facing := 1.0
var windup_target := 0.0
var busy := false
var height := 1.8
var rig_kind := ""
var arm_swing := 1.0
## Set while this figure is in a conversation: head bobs, hands gesture.
var talking := false
## "side", "front" or "back" when the figure has those views (cute people).
var view := "side"
var views := {}
## Ranged attackers glow while charging a beam.
var charges := false
var base_tint := Color(1, 1, 1)   # danger-tier monsters glow warmer/redder

var _turn := 1.0
var _t := 0.0
var _phase := 0.0
var _amp := 0.0
var _busy := 0.0
var _flash := 0.0
var _lunge := 0.0
var _windup := 0.0
var _dead := false


## tex holds one column per piece; rig comes from Paint.rig().
func setup(tex: Texture2D, rig: Dictionary, world_h: float, label: String, font: Font) -> void:
	height = world_h
	_t = randf() * 10.0
	_phase = randf() * TAU
	rig_kind = rig["kind"]
	arm_swing = rig.get("arm_swing", 1.0)
	add_child(_blob(world_h))
	add_view("side", tex, rig)
	_use_view("side")
	_finish_setup(world_h, label, font)


## Adds another angle of the same figure (front, back). Pieces must share
## names with the side view so the same animation drives them.
func add_view(view_name: String, tex: Texture2D, rig: Dictionary) -> void:
	var v := _build_body(tex, rig)
	v["body"].visible = view_name == view
	views[view_name] = v


func set_view(view_name: String) -> void:
	if view_name == view or not views.has(view_name):
		return
	var old: Node3D = body
	_use_view(view_name)
	body.transform = old.transform
	old.visible = false
	body.visible = true


func _use_view(view_name: String) -> void:
	view = view_name
	var v: Dictionary = views[view_name]
	body = v["body"]
	joints = v["joints"]
	sprites = v["sprites"]


func _build_body(tex: Texture2D, rig: Dictionary) -> Dictionary:
	var b := Node3D.new()
	add_child(b)
	var js := {}
	var sp: Array[Sprite3D] = []
	var col: Vector2 = rig["col"]
	var px := height / col.y
	var parts: Array = rig["parts"]
	for i in parts.size():
		var part: Dictionary = parts[i]
		var pv: Vector2 = part["pivot"]
		var joint := Node3D.new()
		joint.position = Vector3((pv.x - col.x * 0.5) * px, (col.y - pv.y) * px, float(part["z"]) * LAYER)
		joint.set_meta("base", joint.position)
		b.add_child(joint)
		var region := Rect2(col.x * i, 0.0, col.x, col.y)
		var offset := Vector3(-joint.position.x, -joint.position.y, 0.0)
		var back := make_sprite(tex, px, region)
		back.modulate = EDGE
		back.position = offset + Vector3(0.025, -0.01, -LAYER * 0.4)
		back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		joint.add_child(back)
		var front := make_sprite(tex, px, region)
		front.position = offset
		joint.add_child(front)
		sp.append(front)
		js[part["name"]] = joint
	return {"body": b, "joints": js, "sprites": sp}


func _finish_setup(world_h: float, label: String, font: Font) -> void:
	var top := world_h * 0.86
	name_label = _label(font, label, 40)
	name_label.position = Vector3(0, top + 0.16, 0)
	add_child(name_label)
	bubble = SpeechBubble.new(font)
	bubble.position = Vector3(0, top + 0.42, 0)
	add_child(bubble)
	hp_bar = _make_hp_bar()
	hp_bar.position = Vector3(0, top + 0.02, 0)
	add_child(hp_bar)
	set_hp(1.0)


## A cut-out sprite whose bottom centre sits at its origin. With a region,
## only that part of the texture is shown.
static func make_sprite(tex: Texture2D, px: float, region := Rect2()) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = px
	s.centered = true
	var h := float(tex.get_height())
	if region.has_area():
		s.region_enabled = true
		s.region_rect = region
		h = region.size.y
	s.offset = Vector2(0, h * 0.5)
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return s


func _label(font: Font, text: String, size: int) -> Label3D:
	var l := Label3D.new()
	l.font = font
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0045
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = INK
	l.outline_size = 10
	l.outline_modulate = Color(0.95, 0.88, 0.70)
	return l


func _make_hp_bar() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.98, 0.2)
	mi.mesh = q
	_hp_mat = ShaderMaterial.new()
	_hp_mat.shader = preload("res://shaders/bar.gdshader")
	_hp_mat.set_shader_parameter("size_m", q.size)
	_hp_mat.set_shader_parameter("value", 1.0)
	_hp_mat.set_shader_parameter("trail", 1.0)
	_hp_mat.render_priority = 10
	mi.material_override = _hp_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _blob(world_h: float) -> MeshInstance3D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.42))
	g.set_color(1, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = gt
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pm := PlaneMesh.new()
	pm.size = Vector2(maxf(0.9, world_h * 0.5), 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Joint angles are in the figure's own frame (it faces +x before the paper
## flip): a positive angle swings a hanging limb forward.
func animate(delta: float, moving: float) -> void:
	if _dead:
		return
	_t += delta
	_amp = move_toward(_amp, clampf(moving, 0.0, 1.0), delta * 6.0)
	_phase += delta * float(STRIDE.get(rig_kind, 10.0)) * _amp
	_busy = move_toward(_busy, 1.0 if busy else 0.0, delta * 4.0)
	_turn = move_toward(_turn, facing, delta * 7.0)
	var sx := _turn
	if absf(sx) < 0.06:
		sx = 0.06 if facing > 0.0 else -0.06
	var swing := sin(_phase) * _amp
	var bob := absf(sin(_phase)) * _amp
	var breathe := sin(_t * 2.2) * 0.012
	_lunge = maxf(0.0, _lunge - delta * 3.2)
	_windup = move_toward(_windup, windup_target, delta * 6.0)
	var lk := sin(_lunge * PI)
	body.rotation.z = -swing * 0.04 - facing * lk * 0.22 + facing * _windup * 0.22
	body.position = Vector3(facing * (lk * 0.3 - _windup * 0.12), bob * 0.07, 0.0)
	body.scale = Vector3(sx, 1.0 + breathe, 1.0)

	var idle := sin(_t * 1.7) * 0.04
	var talk := sin(_t * 9.0) if talking else 0.0
	match rig_kind:
		"chibi" when view != "side":
			body.position.y = bob * 0.1
			_lift("back_leg", maxf(0.0, sin(_phase)) * 0.09 * _amp)
			_lift("front_leg", maxf(0.0, -sin(_phase)) * 0.09 * _amp)
			_rot("back_leg", 0.0)
			_rot("front_leg", 0.0)
			_rot("back_arm", -0.12 - absf(swing) * 0.25 + idle)
			var farm := 0.12 + absf(swing) * 0.25 - idle
			if talking:
				farm = 0.5 + talk * 0.3
			farm = lerpf(farm, -_hammer() * 0.6, _busy)
			_rot("front_arm", _strike(farm, -2.2, -0.4) if view == "front" else _strike(farm, 2.2, -1.2))
			_rot("head", sin(_t * 2.0) * 0.05 + talk * 0.08 + swing * 0.04)
			_rot("back", -swing * 0.06)
		"chibi":
			body.position.y = bob * 0.12
			_rot("back_leg", swing * 0.75)
			_rot("front_leg", -swing * 0.75)
			_rot("back_arm", -swing * 0.7 + idle * 1.5)
			var carm := swing * 0.7 * arm_swing - idle * 1.5
			if talking:
				carm = -0.6 + talk * 0.35
			carm = lerpf(carm, _hammer(), _busy)
			_rot("front_arm", _strike(carm, 2.5, 1.6))
			_rot("head", sin(_t * 2.0) * 0.05 + talk * 0.09 - swing * 0.05 + _windup * 0.15)
			_rot("back", -_amp * 0.22 + sin(_t * 2.6) * 0.04 - lk * 0.2)
		"person":
			_rot("back_leg", swing * 0.55)
			_rot("front_leg", -swing * 0.55)
			_rot("back_arm", -swing * 0.5 + idle)
			var arm := swing * 0.5 * arm_swing - idle
			arm = lerpf(arm, _hammer(), _busy)
			_rot("front_arm", _strike(arm, 2.4, 1.5))
			_rot("back", -_amp * 0.16 + sin(_t * 2.6) * 0.03 - lk * 0.2)
			if talking:
				_rot("front_arm", -0.5 + talk * 0.3)
				body.rotation.z += talk * 0.02
		"troll", "pebblet":
			_rot("back_leg", swing * 0.4)
			_rot("front_leg", -swing * 0.4)
			_rot("back_arm", -swing * 0.35 + idle)
			_rot("front_arm", _strike(swing * 0.25 - idle, 2.0, 1.3))
		"boss":
			body.position.y = 0.0
			_rot("back_arm", sin(_t * 1.3) * 0.18 - swing * 0.2)
			_rot("front_arm", _strike(sin(_t * 1.1) * 0.15, 1.8, 1.2))
			body.scale.y = 1.0 + sin(_t * 1.6) * 0.03
		"slime":
			var hop := absf(sin(_phase))
			body.position.y = hop * 0.45 * _amp
			var sq := 1.0 + (hop - 0.5) * 0.3 * _amp + sin(_t * 3.0) * 0.04
			sq = lerpf(sq, 0.7, _windup)
			sq = lerpf(sq, 1.25, lk)
			body.scale = Vector3(sx * (2.0 - sq), sq, 1.0)
			body.rotation.z = -facing * lk * 0.3
		"shroom":
			body.position.y = bob * 0.08
			_rot("back_leg", swing * 0.8)
			_rot("front_leg", -swing * 0.8)
			body.rotation.z += facing * (_windup * 0.35 - lk * 0.6)
		"bat":
			var flap := sin(_t * (13.0 + 8.0 * _windup))
			_rot("far_wing", -flap * 0.55)
			_rot("near_wing", flap * 0.55)
			body.position.y = 0.9 + sin(_t * 3.0) * 0.14 + flap * 0.04
			body.rotation.z = -swing * 0.1
		"wolf", "fluffox":
			var reach := lk * 0.7 - _windup * 0.3
			_rot("far_back", swing * 0.6 - reach * 0.6)
			_rot("near_front", swing * 0.6 + reach)
			_rot("near_back", -swing * 0.6 - reach * 0.6)
			_rot("far_front", -swing * 0.6 + reach)
			_rot("tail", sin(_t * (4.0 + 8.0 * _amp)) * 0.25 - _windup * 0.3)

	_flash = maxf(0.0, _flash - delta * 5.0)
	var tint := base_tint
	if charges and _windup > 0.01:
		tint = tint.lerp(Color(1.6, 1.5, 0.7), _windup * (0.6 + 0.4 * sin(_t * 30.0)))
	tint = tint.lerp(Color(1.0, 0.35, 0.3), _flash)
	for s in sprites:
		s.modulate = tint
	if _hp_trail > _hp_value:
		_hp_trail = maxf(_hp_value, _hp_trail - delta * 0.55)
		_hp_mat.set_shader_parameter("trail", _hp_trail)


func _lift(joint: String, dy: float) -> void:
	if joints.has(joint):
		var j: Node3D = joints[joint]
		j.position = j.get_meta("base") + Vector3(0, dy, 0)


func _rot(joint: String, angle: float) -> void:
	if joints.has(joint):
		joints[joint].rotation.z = angle


## Working at a shop: the arm lifts slowly and comes down hard.
func _hammer() -> float:
	var c := fmod(_t * 1.3, 1.0)
	if c < 0.7:
		return lerpf(0.3, -1.7, c / 0.7)
	return lerpf(-1.7, 0.3, (c - 0.7) / 0.3)


## Weapon arm: raised back while winding up, then a fast chop forward.
func _strike(rest: float, raise: float, chop: float) -> float:
	var up := lerpf(rest, -raise, _windup)
	if _lunge <= 0.0:
		return up
	var t := 1.0 - _lunge
	if t < 0.2:
		return lerpf(up, -raise, t / 0.2)
	if t < 0.45:
		return lerpf(-raise, chop, (t - 0.2) / 0.25)
	return lerpf(chop, rest, (t - 0.45) / 0.55)


## style: 0 round, 1 shout, 2 thought, 3 cut paper (default).
func say(text: String, secs: float = 3.0, fill := Color(0.99, 0.985, 0.96), style := 3) -> void:
	bubble.show_text(text, secs, style, fill)
	Sfx.play("pop", -6.0)


func flash() -> void:
	_flash = 1.0


func lunge() -> void:
	_lunge = 1.0


func set_hp(frac: float) -> void:
	var show := frac < 0.999 and not _dead
	hp_bar.visible = show
	var f := clampf(frac, 0.0, 1.0)
	if f < _hp_value - 0.001:
		_hp_mat.set_shader_parameter("hot", 1.0)
		var tw := create_tween()
		tw.tween_property(_hp_mat, "shader_parameter/hot", 0.0, 0.2)
	if f > _hp_trail:
		_hp_trail = f
		_hp_mat.set_shader_parameter("trail", f)
	_hp_value = f
	_hp_mat.set_shader_parameter("value", f)


## Tips over flat like a knocked-down cardboard cut-out, then fades away.
func fall() -> void:
	_dead = true
	name_label.visible = false
	bubble.hide_bubble()
	hp_bar.visible = false
	var tw := create_tween()
	tw.tween_property(body, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if joints.has("front_arm"):
		tw.parallel().tween_property(joints["front_arm"], "rotation:z", 1.2, 0.45)
	tw.tween_interval(1.4)
	tw.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.35)
	tw.tween_callback(queue_free)
