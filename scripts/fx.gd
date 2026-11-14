## Special effects. Everything with a shape (slashes, blasts, danger strips,
## rings, sparks, beams, light pillars) is a small shader drawing a distance
## field, so ends are round and edges soft; nothing is a hard rectangle.
## Ground effects are built along the terrain and bent like it. Tweens drive
## the shader parameters. Particles (confetti, smoke, rain) stay CPUParticles.
class_name Fx
extends RefCounted

const K := 1.5 / 48.0

static var world: World
static var puff_tex: Texture2D
static var glow_tex: Texture2D
static var _confetti_mat: StandardMaterial3D
static var _quad_mesh: QuadMesh
static var _sh_decal: Shader
static var _sh_slash: Shader
static var _sh_beam: Shader
static var _sh_spr: Shader
static var _sh_add: Shader


static func setup(bake_root: Node) -> void:
	puff_tex = Bake.make(bake_root, "puff", {}, Vector2i(96, 96))
	glow_tex = Bake.make(bake_root, "glow", {"col": Color(1.0, 0.95, 0.7)}, Vector2i(128, 128))
	_confetti_mat = StandardMaterial3D.new()
	_confetti_mat.vertex_color_use_as_albedo = true
	_confetti_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_confetti_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_confetti_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2(1, 1)
	_sh_decal = load("res://shaders/decal.gdshader")
	_sh_slash = load("res://shaders/slash.gdshader")
	_sh_beam = load("res://shaders/beam.gdshader")
	_sh_spr = load("res://shaders/fx_sprite.gdshader")
	_sh_add = load("res://shaders/fx_sprite_add.gdshader")


# ---------- building blocks ----------

static func ground_y(p: Vector3) -> float:
	if world == null:
		return p.y
	return world.height_at(Vector2(p.x, p.z) / K)


static func _cam_basis(parent: Node) -> Basis:
	var vp := parent.get_viewport()
	if vp != null and vp.get_camera_3d() != null:
		return vp.get_camera_3d().global_transform.basis
	return Basis()


## A camera-facing shape sprite (see shaders/fx_shapes). size is in metres.
static func spr(parent: Node, at: Vector3, shape: int, col: Color, size: float, additive := true, aspect := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad_mesh
	var m := _new_mat()
	m.shader = _sh_add if additive else _sh_spr
	m.set_shader_parameter("shape", shape)
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("fade", 1.0)
	mi.material_override = m
	mi.scale = Vector3(size * aspect, size, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Bend.at(at)
	parent.add_child(mi)
	return mi


## Every shader that Fx tweens starts with progress and fade set, since a tween
## cannot animate a parameter that has no value yet.
static func _new_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.set_shader_parameter("progress", 0.0)
	m.set_shader_parameter("fade", 1.0)
	return m


static func _mat(mi: MeshInstance3D) -> ShaderMaterial:
	return mi.material_override as ShaderMaterial


## Grows a sprite, then fades and frees it.
static func _pulse(mi: MeshInstance3D, grow: float, t_in: float, t_out: float) -> void:
	var m := _mat(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", mi.scale * grow, t_in).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(m, "shader_parameter/fade", 0.0, t_in + t_out).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)


## A grid of vertices laid on the terrain, for decals. o = start of the strip
## (world), dir = direction on the ground, rel = the node's own position (the
## mesh is stored relative to it). u runs across, v along the strip.
static func _grid(o: Vector3, dir: Vector2, length: float, width: float, nx: int, nz: int, rel: Vector3, lift := 0.07) -> ArrayMesh:
	var d := dir.normalized()
	var perp := Vector2(-d.y, d.x)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in nz + 1:
		for i in nx + 1:
			var fj := float(j) / nz
			var fi := float(i) / nx
			var xz := Vector2(o.x, o.z) + d * (fj * length) + perp * ((fi - 0.5) * width)
			var w := Vector3(xz.x, 0.0, xz.y)
			w.y = ground_y(w) + lift
			verts.append(w - rel)
			uvs.append(Vector2(fi, fj))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			idx.append_array(PackedInt32Array([a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


static func _decal_node(parent: Node, rel: Vector3, mesh: Mesh, mode: int, col: Color, size_m: Vector2) -> Node3D:
	var root := Node3D.new()
	root.position = rel
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _new_mat()
	m.shader = _sh_decal
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("size_m", size_m)
	m.set_shader_parameter("seed", randf() * 50.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16.0
	root.add_child(mi)
	root.set_meta("mat", m)
	return root


static func _disc(parent: Node, at: Vector3, radius_m: float, mode: int, col: Color) -> Node3D:
	var rel := Vector3(at.x, 0.0, at.z)
	var mesh := _grid(Vector3(at.x, 0.0, at.z - radius_m), Vector2(0, 1), radius_m * 2.0, radius_m * 2.0, 14, 14, rel)
	return _decal_node(parent, rel, mesh, mode, col, Vector2(radius_m * 2.0, radius_m * 2.0))


static func _dm(root: Node3D) -> ShaderMaterial:
	return root.get_meta("mat") as ShaderMaterial


# ---------- weapon strikes ----------

## A crescent slash. variant 0: high-to-low sweep, 1: low-to-high, 2: big
## overhead finisher (wider, with a shockwave ring).
static func slash(parent: Node, at: Vector3, flip: bool, col := Color(1, 1, 1), variant := 0) -> void:
	at = Bend.at(at)
	var mi := MeshInstance3D.new()
	mi.mesh = _quad_mesh
	var m := _new_mat()
	m.shader = _sh_slash
	m.set_shader_parameter("col", Color(1, 1, 1))
	m.set_shader_parameter("rim_col", col.lerp(Color(1.0, 0.75, 0.35), 0.3) if col.get_luminance() > 0.85 else col)
	m.set_shader_parameter("flip", -1.0 if flip else 1.0)
	m.set_shader_parameter("seed", randf() * 10.0)
	var size := 2.5
	match variant:
		0:
			m.set_shader_parameter("center_ang", 0.55)
			m.set_shader_parameter("span", 2.6)
		1:
			m.set_shader_parameter("center_ang", -0.55)
			m.set_shader_parameter("span", 2.6)
			m.set_shader_parameter("progress", 0.0)
		_:
			m.set_shader_parameter("center_ang", 1.5)
			m.set_shader_parameter("span", 3.3)
			m.set_shader_parameter("thick", 0.4)
			size = 3.6
	mi.material_override = m
	mi.scale = Vector3(size, size, 1.0)
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(m, "shader_parameter/progress", 1.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "shader_parameter/fade", 0.0, 0.14)
	tw.tween_callback(mi.queue_free)
	if variant == 2:
		ring(parent, at - Vector3(0, 0.8, 0), col, 2.6)


## Claw marks across a target: three parallel slashes.
static func claw(parent: Node, at: Vector3, flip: bool, col := Color(1.0, 0.3, 0.25)) -> void:
	var cb := _cam_basis(parent)
	for i in 3:
		var off := cb.x * (float(i) - 1.0) * 0.32 * (-1.0 if flip else 1.0)
		var s := Vector3(at.x, at.y, at.z) + off
		var mi := MeshInstance3D.new()
		mi.mesh = _quad_mesh
		var m := _new_mat()
		m.shader = _sh_slash
		m.set_shader_parameter("col", Color(1, 0.92, 0.85))
		m.set_shader_parameter("rim_col", col)
		m.set_shader_parameter("flip", -1.0 if flip else 1.0)
		m.set_shader_parameter("center_ang", 0.9)
		m.set_shader_parameter("span", 1.5)
		m.set_shader_parameter("thick", 0.2)
		m.set_shader_parameter("radius", 0.7)
		m.set_shader_parameter("seed", float(i))
		mi.material_override = m
		mi.scale = Vector3(2.0, 2.0, 1.0)
		mi.position = Bend.at(s)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		var tw := mi.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(m, "shader_parameter/progress", 1.0, 0.1)
		tw.tween_property(m, "shader_parameter/fade", 0.0, 0.2)
		tw.tween_callback(mi.queue_free)
	impact(parent, at, col, 0.7)


## A bite: two curved jaws snapping shut.
static func chomp(parent: Node, at: Vector3, col := Color(1.0, 0.9, 0.8)) -> void:
	for sgn in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = _quad_mesh
		var m := _new_mat()
		m.shader = _sh_slash
		m.set_shader_parameter("col", Color(1, 1, 1))
		m.set_shader_parameter("rim_col", col)
		m.set_shader_parameter("center_ang", 1.57 * sgn)
		m.set_shader_parameter("span", 2.0)
		m.set_shader_parameter("thick", 0.26)
		m.set_shader_parameter("radius", 0.6)
		mi.material_override = m
		mi.scale = Vector3(2.0, 2.0, 1.0)
		mi.position = Bend.at(at + Vector3(0, 0.0, 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		var tw := mi.create_tween()
		tw.tween_property(m, "shader_parameter/progress", 1.0, 0.09)
		tw.tween_property(m, "shader_parameter/fade", 0.0, 0.16)
		tw.tween_callback(mi.queue_free)
	impact(parent, at, col, 0.6)


## A hit flash: star, radial streaks, a ring and sparks. power scales it.
static func impact(parent: Node, at: Vector3, col := Color(1.0, 0.9, 0.6), power := 1.0) -> void:
	var star := spr(parent, at, 2, Color(1.0, 0.96, 0.8), 1.7 * power)
	star.rotation_degrees.z = 0.0
	_pulse(star, 1.5, 0.08, 0.14)
	var core := spr(parent, at, 0, col.lightened(0.3), 1.9 * power)
	_pulse(core, 1.3, 0.06, 0.16)
	var rng_ring := spr(parent, at, 3, col, 0.5 * power, false)
	_mat(rng_ring).set_shader_parameter("aux", 0.18)
	_pulse(rng_ring, 4.0, 0.22, 0.08)
	var cb := _cam_basis(parent)
	var n := int(7.0 + 5.0 * power)
	for i in n:
		var a := TAU * float(i) / float(n) + randf() * 0.4
		var dir := (cb.x * cos(a) + cb.y * sin(a)).normalized()
		var s := spr(parent, at, 1, col.lightened(0.45), randf_range(0.9, 1.5) * power)
		_mat(s).set_shader_parameter("rot", a)
		var tw := s.create_tween()
		tw.tween_property(s, "position", s.position + dir * randf_range(0.7, 1.3) * power, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(_mat(s), "shader_parameter/fade", 0.0, 0.2)
		tw.parallel().tween_property(s, "scale", s.scale * Vector3(0.4, 0.6, 1.0), 0.2)
		tw.tween_callback(s.queue_free)
	sparks(parent, at, col, int(8 * power))


## Glowing bits thrown out and pulled down by gravity.
static func sparks(parent: Node, at: Vector3, col: Color, amount := 10, speed := 5.0) -> void:
	at = Bend.at(at)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.55
	p.explosiveness = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = _particle_mat(glow_tex, true)
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12.0, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	var c := Curve.new()
	c.add_point(Vector2(0, 1.0))
	c.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = c
	p.color = col.lightened(0.3)
	p.position = at
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A heavy ground pound: cracks, a shockwave ring, dust and flying chunks.
static func slam(parent: Node, at: Vector3, radius := 3.0, col := Color(1.0, 0.8, 0.45)) -> void:
	var cr := _disc(parent, at, radius * 0.8, 3, Color(0.25, 0.16, 0.1, 0.9))
	var m := _dm(cr)
	var tw := cr.create_tween()
	tw.tween_property(m, "shader_parameter/fade", 0.0, 1.4).set_delay(0.5)
	tw.tween_callback(cr.queue_free)
	ring(parent, at, col, radius)
	var sc := _disc(parent, at, radius * 0.5, 4, Color(0.12, 0.08, 0.05, 0.6))
	var tw2 := sc.create_tween()
	tw2.tween_property(_dm(sc), "shader_parameter/fade", 0.0, 2.0).set_delay(0.3)
	tw2.tween_callback(sc.queue_free)
	for i in 10:
		var a := TAU * float(i) / 10.0 + randf() * 0.5
		puff(parent, at + Vector3(cos(a), 0.0, sin(a)) * radius * 0.5, 0.7, Color(0.9, 0.85, 0.75))
	burst(parent, at + Vector3(0, 0.3, 0), [Color(0.55, 0.42, 0.3), Color(0.75, 0.65, 0.5), Color(0.4, 0.3, 0.2)], 26, 7.0)


# ---------- ground warnings and rings ----------

## A rounded danger strip on the ground along a coming beam or lunge. Returns
## the node so the caller can free it. charge_time fills it as the attack winds up.
static func telegraph(parent: Node, a: Vector3, b: Vector3, col: Color, width: float = 0.5, charge_time := 0.8) -> Node3D:
	var dir := Vector2(b.x - a.x, b.z - a.z)
	var length := dir.length()
	if length < 0.05:
		var empty := Node3D.new()
		empty.position = a
		parent.add_child(empty)
		return empty
	var rel := Vector3(a.x, a.y, a.z)
	var mesh := _grid(Vector3(a.x, 0.0, a.z), dir, length, width * 1.5, 3, maxi(8, int(length * 1.2)), rel)
	var root := _decal_node(parent, rel, mesh, 0, col, Vector2(width * 1.5, length))
	var m := _dm(root)
	m.set_shader_parameter("progress", 0.0)
	var tw := root.create_tween()
	tw.tween_property(m, "shader_parameter/progress", 1.0, maxf(charge_time, 0.05))
	return root


## A round area warning that fills as an attack winds up.
static func area(parent: Node, at: Vector3, radius: float, col: Color, charge_time := 0.8) -> Node3D:
	var root := _disc(parent, at, radius, 2, col)
	var m := _dm(root)
	m.set_shader_parameter("progress", 0.0)
	var tw := root.create_tween()
	tw.tween_property(m, "shader_parameter/progress", 1.0, maxf(charge_time, 0.05))
	return root


## A ring that expands along the ground (shockwave, level up).
static func ring(parent: Node, at: Vector3, col: Color, radius: float = 3.0) -> void:
	var root := _disc(parent, at, radius, 1, col)
	var m := _dm(root)
	m.set_shader_parameter("progress", 0.1)
	var tw := root.create_tween()
	tw.tween_property(m, "shader_parameter/progress", 0.95, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(m, "shader_parameter/fade", 0.0, 0.45).set_delay(0.12)
	tw.tween_callback(root.queue_free)


## A dark burn mark that fades.
static func scorch(parent: Node, at: Vector3, radius := 1.2) -> void:
	var sc := _disc(parent, at, radius, 4, Color(0.1, 0.07, 0.05, 0.7))
	var tw := sc.create_tween()
	tw.tween_property(_dm(sc), "shader_parameter/fade", 0.0, 3.0).set_delay(0.6)
	tw.tween_callback(sc.queue_free)


## A target ring under the enemy you are fighting. Returns the node; the
## caller moves it (set its position to the enemy's ground point).
static func target_ring(parent: Node) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.2, 2.2)
	mi.mesh = pm
	var m := _new_mat()
	m.shader = _sh_decal
	m.set_shader_parameter("mode", 1)
	m.set_shader_parameter("col", Color(1.0, 0.85, 0.3, 0.95))
	m.set_shader_parameter("progress", 0.8)
	m.set_shader_parameter("thick", 0.07)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.1
	root.add_child(mi)
	var tw := root.create_tween().set_loops()
	tw.tween_property(mi, "scale", Vector3(1.1, 1.0, 1.1), 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mi, "scale", Vector3(0.92, 1.0, 0.92), 0.4).set_trans(Tween.TRANS_SINE)
	return root


# ---------- beams ----------

## A glowing beam from a to b: a tapered, rounded energy tube with a flowing
## core, a muzzle flash, an impact star and a scorch mark.
static func beam(parent: Node, a: Vector3, b: Vector3, col: Color, width: float = 0.35, life: float = 0.35) -> void:
	a = Bend.at(a)
	b = Bend.at(b)
	var dist := a.distance_to(b)
	if dist < 0.01:
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.position = a
	root.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
	for layer in 2:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := width * (1.0 if layer == 0 else 0.45)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = dist
		cm.radial_segments = 14
		cm.rings = 24
		mi.mesh = cm
		mi.rotation.x = -PI * 0.5
		mi.position.z = -dist * 0.5
		var m := _new_mat()
		m.shader = _sh_beam
		m.set_shader_parameter("col", col if layer == 0 else Color(1, 1, 1))
		m.set_shader_parameter("height", dist)
		m.set_shader_parameter("flow", 1.0 if layer == 0 else -1.4)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var tw := root.create_tween()
	root.scale = Vector3(0.25, 0.25, 1.0)
	tw.tween_property(root, "scale", Vector3(1.2, 1.2, 1.0), 0.06).set_trans(Tween.TRANS_BACK)
	tw.tween_property(root, "scale", Vector3(0.03, 0.03, 1.0), life).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	var muzzle := spr(parent, a, 0, col.lightened(0.3), width * 7.0)
	_pulse(muzzle, 0.2, 0.05, life)
	var hit := spr(parent, b, 2, Color(1, 0.97, 0.85), width * 9.0)
	_pulse(hit, 1.4, 0.1, life)
	impact(parent, b, col, 0.8 + width)
	scorch(parent, Vector3(b.x, ground_y(b), b.z), width * 3.5)


# ---------- confetti, dust and the rest ----------

## A paper dust puff at the feet (walking, landing, spawning).
static func puff(parent: Node, at: Vector3, size: float = 0.5, col := Color(1, 1, 1)) -> void:
	at = Bend.at(at)
	var s := Sprite3D.new()
	s.texture = puff_tex
	s.pixel_size = size / 96.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.modulate = col
	s.position = at + Vector3(randf_range(-0.15, 0.15), 0.15, randf_range(-0.1, 0.1))
	s.scale = Vector3.ONE * 0.4
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 1.25, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(s, "position:y", at.y + 0.5, 0.45)
	tw.parallel().tween_property(s, "scale", Vector3.ONE * 0.01, 0.2).set_delay(0.3)
	tw.tween_callback(s.queue_free)


## Confetti of paper bits (hits, kills, quest done).
static func burst(parent: Node, at: Vector3, colors: Array, amount: int = 24, speed: float = 4.0) -> void:
	at = Bend.at(at)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 0.95
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.09)
	q.material = _confetti_mat
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.color_initial_ramp = _ramp(colors)
	p.position = at
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A pillar of light rising from the ground (quest complete, level up).
static func pillar(parent: Node, at: Vector3, col: Color, height := 7.0) -> void:
	var mi := spr(parent, at + Vector3(0, height * 0.5, 0), 5, col, height, true, 0.35)
	var tw := mi.create_tween()
	mi.scale = Vector3(0.2, 0.2, 1.0)
	tw.tween_property(mi, "scale", Vector3(height * 0.35, height, 1.0), 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_mat(mi), "shader_parameter/fade", 0.0, 0.7)
	tw.tween_callback(mi.queue_free)
	ring(parent, at, col, 3.0)


## Green motes drifting up (healing, eating).
static func heal(parent: Node, at: Vector3, col := Color(0.55, 1.0, 0.6)) -> void:
	for i in 9:
		var s := spr(parent, at + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.6), randf_range(-0.4, 0.4)), 2, col, 0.45)
		var tw := s.create_tween()
		tw.tween_interval(randf() * 0.25)
		tw.tween_property(s, "position:y", s.position.y + 1.6, 0.8).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(_mat(s), "shader_parameter/fade", 0.0, 0.8)
		tw.tween_callback(s.queue_free)


## A soul wisp that rises from a defeated monster.
static func soul(parent: Node, at: Vector3, col := Color(0.85, 0.95, 1.0)) -> void:
	var s := spr(parent, at, 0, col, 1.0)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", s.position.y + 3.2, 1.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "scale", s.scale * 0.3, 1.3)
	tw.parallel().tween_property(_mat(s), "shader_parameter/fade", 0.0, 1.3).set_delay(0.3)
	tw.tween_callback(s.queue_free)


## A trail of ghosts and streaks along a dash.
static func dash_trail(parent: Node, from: Vector3, to: Vector3, col := Color(0.95, 0.95, 1.0)) -> void:
	for i in 6:
		var t := float(i) / 5.0
		var p := from.lerp(to, t) + Vector3(0, 0.9, 0)
		var g := spr(parent, p, 0, col, 1.3 - 0.15 * i, false)
		var tw := g.create_tween()
		tw.tween_interval(0.02 * i)
		tw.tween_property(_mat(g), "shader_parameter/fade", 0.0, 0.3).from(0.5)
		tw.tween_callback(g.queue_free)
	var cb := _cam_basis(parent)
	var dir3 := (to - from)
	var ang := atan2(dir3.dot(cb.y), dir3.dot(cb.x))
	for i in 3:
		var s := spr(parent, from.lerp(to, 0.5) + Vector3(0, 0.5 + 0.3 * i, 0), 1, Color(1, 1, 1), 2.6)
		_mat(s).set_shader_parameter("rot", ang)
		_pulse(s, 1.2, 0.05, 0.2)


## Dark mist rising off a monster: attach to the figure so it follows it.
static func aura(parent: Node3D, col: Color, size := 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(10.0 * size)
	p.lifetime = 1.6
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7) * size
	var m := _particle_mat(puff_tex, false)
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6 * size
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.3, 0)
	p.local_coords = false
	var c := Curve.new()
	c.add_point(Vector2(0, 0.3))
	c.add_point(Vector2(0.5, 1.0))
	c.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.add_point(0.3, Color(col.r, col.g, col.b, 0.2))
	g.set_color(g.get_point_count() - 1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, 0.8 * size, 0)
	parent.add_child(p)
	return p


## A cloud of spores that hangs over a spot.
static func spores(parent: Node, at: Vector3, radius: float, col := Color(0.6, 0.9, 0.3)) -> void:
	at = Bend.at(at)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 30
	p.lifetime = 1.2
	p.explosiveness = 0.9
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	q.material = _particle_mat(puff_tex, false)
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.5
	p.direction = Vector3.UP
	p.spread = 90.0
	p.initial_velocity_min = radius * 0.8
	p.initial_velocity_max = radius * 1.6
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.gravity = Vector3(0, 0.2, 0)
	p.color = Color(col.r, col.g, col.b, 0.7)
	p.position = at + Vector3(0, 0.4, 0)
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Continuous paper smoke from a chimney.
static func smoke(parent: Node3D, at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 8
	p.lifetime = 3.0
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	var m := StandardMaterial3D.new()
	m.albedo_texture = puff_tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.mesh = q
	p.direction = Vector3(0.3, 1, 0)
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.15, 0.05, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.1
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -30.0
	p.angular_velocity_max = 30.0
	var c := Curve.new()
	c.add_point(Vector2(0, 0.4))
	c.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.95, 0.95, 1))
	g.set_color(1, Color(0.75, 0.75, 0.78, 1))
	p.color_ramp = g
	p.position = at
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


## Cardboard flames: orange paper flakes rising, plus a warm light.
static func campfire(parent: Node3D, at: Vector3) -> void:
	FireFx.campfire(parent, at, 1.0)
	var glow := spr(parent, at + Vector3(0, 0.6, 0), 0, Color(1.0, 0.6, 0.25, 0.6), 2.8)
	var gt := glow.create_tween().set_loops()
	gt.tween_property(_mat(glow), "shader_parameter/fade", 0.6, 0.25)
	gt.tween_property(_mat(glow), "shader_parameter/fade", 1.0, 0.3)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.65, 0.3)
	l.omni_range = 6.0
	l.light_energy = 1.4
	l.position = at + Vector3(0, 0.8, 0)
	parent.add_child(l)


static func _particle_mat(tex: Texture2D, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if tex != null:
		m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cc := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cc.append(cols[i])
	g.offsets = offs
	g.colors = cc
	return g


## Weather and ambience that follow the player: drifting petals or leaves
## by day, fireflies at night, paper rain during showers.
static func ambient(parent: Node3D, cute: bool) -> Dictionary:
	var petals := CPUParticles3D.new()
	petals.amount = 28 if Game.low_end else 70
	petals.lifetime = 9.0
	petals.preprocess = 9.0
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.10)
	q.material = _confetti_mat
	petals.mesh = q
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	petals.emission_box_extents = Vector3(28, 1, 28)
	petals.direction = Vector3(1, -0.3, 0.4)
	petals.spread = 30.0
	petals.initial_velocity_min = 0.6
	petals.initial_velocity_max = 1.4
	petals.gravity = Vector3(0.3, -0.7, 0.15)
	petals.angular_velocity_min = -200.0
	petals.angular_velocity_max = 200.0
	petals.local_coords = false
	petals.color_initial_ramp = _ramp([Color(1.0, 0.75, 0.82), Color(1, 1, 1), Color(1.0, 0.88, 0.5)] if cute else [Color(0.55, 0.65, 0.3), Color(0.75, 0.55, 0.3), Color(0.6, 0.45, 0.25)])
	petals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(petals)

	var flies := CPUParticles3D.new()
	flies.amount = 18 if Game.low_end else 45
	flies.lifetime = 4.0
	var fq := QuadMesh.new()
	fq.size = Vector2(0.28, 0.28)
	fq.material = _particle_mat(glow_tex, true)
	flies.mesh = fq
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(22, 1.5, 22)
	flies.direction = Vector3.UP
	flies.spread = 180.0
	flies.initial_velocity_min = 0.1
	flies.initial_velocity_max = 0.5
	flies.gravity = Vector3.ZERO
	flies.local_coords = false
	var fc := Curve.new()
	fc.add_point(Vector2(0, 0))
	fc.add_point(Vector2(0.3, 1))
	fc.add_point(Vector2(0.7, 1))
	fc.add_point(Vector2(1, 0))
	flies.scale_amount_curve = fc
	flies.color = Color(0.85, 1.0, 0.45)
	flies.emitting = false
	flies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flies)

	var rain := CPUParticles3D.new()
	rain.amount = 500
	rain.lifetime = 0.9
	var rq := QuadMesh.new()
	rq.size = Vector2(0.05, 0.8)
	var rm := _particle_mat(null, false)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rq.material = rm
	rain.mesh = rq
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(24, 0.5, 24)
	rain.direction = Vector3(0.1, -1, 0)
	rain.spread = 3.0
	rain.initial_velocity_min = 15.0
	rain.initial_velocity_max = 19.0
	rain.gravity = Vector3(0, -6, 0)
	rain.local_coords = false
	rain.color = Color(0.86, 0.92, 1.0, 0.85)
	rain.emitting = false
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rain)
	return {"petals": petals, "flies": flies, "rain": rain}


## A quick twinkle (gatherables, treasure, level up).
static func glint(parent: Node, at: Vector3, col := Color(1, 0.95, 0.6)) -> void:
	var s := spr(parent, at, 2, col, 0.9)
	s.scale = Vector3.ONE * 0.1
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 0.9, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mat(s), "shader_parameter/fade", 0.0, 0.3)
	tw.tween_callback(s.queue_free)


## A glowing orb that swells while a monster charges its beam.
static func charge_orb(parent: Node3D, local: Vector3, col: Color, time: float) -> MeshInstance3D:
	var s := spr(parent, local, 0, col.lightened(0.2), 1.4)
	s.position = local - Vector3(0, Bend.drop(parent.global_position + local), 0)
	s.scale = Vector3.ONE * 0.2
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 1.8, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var tw2 := s.create_tween().set_loops()
	tw2.tween_property(_mat(s), "shader_parameter/fade", 0.6, 0.06)
	tw2.tween_property(_mat(s), "shader_parameter/fade", 1.0, 0.06)
	return s
