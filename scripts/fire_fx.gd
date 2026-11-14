## Fire that is not made of squares: flame tongues cut from noise, four
## different shapes on one strip, used by particles for campfires, fire spit,
## inferno and burning monsters.
class_name FireFx
extends RefCounted

const W := 64
const H := 96
const FRAMES := 4

static var _tex: Texture2D
static var _mat: StandardMaterial3D


## A 4-frame strip of irregular, licking flame shapes (white-hot core,
## orange body, red ragged tips). Painted once and cached.
static func flame_tex() -> Texture2D:
	if _tex != null:
		return _tex
	var img := Image.create(W * FRAMES, H, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.frequency = 0.07
	for f in FRAMES:
		nz.seed = 11 + f * 37
		var phase := f * 1.7
		var lean := (f - 1.5) * 0.10
		for y in H:
			var t := float(y) / float(H - 1)           # 0 top .. 1 bottom
			var body := pow(sin(PI * pow(1.0 - t, 0.62)), 0.9) if t < 1.0 else 0.0
			# a slim tip, a fat belly low down, flat-ish base
			var half := (0.10 + 0.34 * body) * float(W) * 0.5
			var cx := float(W) * 0.5 + sin(t * 5.0 + phase) * (1.0 - t) * 7.0 + lean * (1.0 - t) * float(W)
			for x in W:
				var dx := float(x) - cx
				var n := nz.get_noise_2d(float(x) * 1.3 + f * 50.0, float(y) * 1.1)
				var edge := half * (1.0 + n * 0.55) - absf(dx)
				if edge <= 0.0:
					continue
				var a := clampf(edge / 4.0, 0.0, 1.0)
				# a notch bitten out of one side makes a second little tongue
				if t < 0.55 and dx * (1.0 if f % 2 == 0 else -1.0) > half * 0.15 and nz.get_noise_2d(float(x) * 2.0, float(y) * 2.0 + 90.0) > 0.18 - t * 0.2:
					a *= 0.0
				if a <= 0.0:
					continue
				var core := clampf(1.0 - absf(dx) / maxf(half * 0.65, 1.0), 0.0, 1.0) * clampf(t * 1.5 - 0.15, 0.0, 1.0)
				var col := Color(0.95, 0.20, 0.08).lerp(Color(1.0, 0.62, 0.12), clampf(t * 1.6, 0.0, 1.0))
				col = col.lerp(Color(1.0, 0.95, 0.60), core * core)
				img.set_pixel(f * W + x, y, Color(col.r, col.g, col.b, a))
	_tex = ImageTexture.create_from_image(img)
	return _tex


static func material() -> StandardMaterial3D:
	if _mat != null:
		return _mat
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_texture = flame_tex()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_mat.particles_anim_h_frames = FRAMES
	_mat.particles_anim_v_frames = 1
	_mat.particles_anim_loop = false
	return _mat


static func _ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1.0, 0.85, 0.75, 0.9), Color(0.6, 0.15, 0.1, 0.0)])
	return g


static func _flames(amount: int, life: float, size: Vector2, up: float, spread: float, radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	var q := QuadMesh.new()
	q.size = size
	q.material = material()
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = up * 0.6
	p.initial_velocity_max = up
	p.gravity = Vector3(0, 0.6, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.anim_offset_min = 0.0
	p.anim_offset_max = 1.0
	p.color_ramp = _ramp()
	var c := Curve.new()
	c.add_point(Vector2(0, 0.7))
	c.add_point(Vector2(0.35, 1.0))
	c.add_point(Vector2(1, 0.15))
	p.scale_amount_curve = c
	p.angle_min = -12.0
	p.angle_max = 12.0
	return p


## A standing fire (campfire, torch): loops forever.
static func campfire(parent: Node3D, at: Vector3, scale := 1.0) -> CPUParticles3D:
	var p := _flames(14, 0.9, Vector2(0.55, 0.8) * scale, 1.5 * scale, 14.0, 0.22 * scale)
	p.position = at + Vector3(0, 0.25, 0)
	parent.add_child(p)
	return p


## A burning creature: small tongues that follow it. Returns the emitter so
## the caller can free it when the burn ends.
static func burning(parent: Node3D, at: Vector3, scale := 1.0) -> CPUParticles3D:
	var p := _flames(9, 0.6, Vector2(0.38, 0.55) * scale, 1.3, 20.0, 0.30 * scale)
	p.position = at
	parent.add_child(p)
	return p


## A one-shot burst of flames: fire spit landing, inferno going off.
static func burst(parent: Node, at: Vector3, radius: float, amount := 26) -> void:
	var p := _flames(amount, 0.7, Vector2(0.75, 1.05), 2.8, 70.0, radius * 0.5)
	p.one_shot = true
	p.explosiveness = 0.85
	p.position = at + Vector3(0, 0.2, 0)
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## A fireball tearing along a line: a trail of flames behind a bright head.
static func bolt(parent: Node, from: Vector3, to: Vector3, secs := 0.28, on_hit := Callable()) -> void:
	var holder := Node3D.new()
	holder.position = from
	parent.add_child(holder)
	var p := _flames(20, 0.35, Vector2(0.7, 0.95), 0.6, 25.0, 0.18)
	holder.add_child(p)
	var tw := holder.create_tween()
	tw.tween_property(holder, "position", to, secs).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func() -> void:
		burst(parent, to, 1.0, 22)
		if on_hit.is_valid():
			on_hit.call()
		p.emitting = false)
	tw.tween_interval(0.5)
	tw.tween_callback(holder.queue_free)
