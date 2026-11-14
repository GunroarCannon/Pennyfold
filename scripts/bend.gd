## The rolling-log world: ground falls away the further it is from the camera
## focus, mostly along the view direction, so the town curves over a horizon.
##
## Meshes bend per vertex in their shaders (shaders/bend.gdshaderinc reads the
## global shader parameters set here). Cut-outs (sprites, labels, particles,
## lights) are flat cards, so they are lowered as a whole by the same curve:
## standees in Main._sync_views, effects when they spawn, and everything else
## built at startup is collected by track_tree() and moved in update().
class_name Bend
extends RefCounted

## Drop per metre squared along the view direction, and across it.
const K := 0.0095
const KS := 0.0009

static var origin := Vector3.ZERO
static var fwd := Vector2(0, -1)
static var enabled := true
## [node, base local position, parent y scale]
static var _tracked: Array = []


## How far the world sinks at a world position.
static func drop(p: Vector3) -> float:
	if not enabled:
		return 0.0
	var d := Vector2(p.x - origin.x, p.z - origin.z)
	var a := d.dot(fwd)
	var s := d.x * fwd.y - d.y * fwd.x
	var a_drop := (a * a) if a > 0.0 else (a * a * 0.35)
	return K * a_drop + KS * s * s


## A world position moved onto the curved world.
static func at(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y - drop(p), p.z)


static func reset() -> void:
	_tracked.clear()
	RenderingServer.global_shader_parameter_set("bend_k", K if enabled else 0.0)
	RenderingServer.global_shader_parameter_set("bend_ks", KS if enabled else 0.0)


## Collects the cut-outs under root that the shaders do not bend. A tracked
## node carries its children along, so the walk stops there.
static func track_tree(root: Node, skip: Array) -> void:
	for c in root.get_children():
		if c in skip or c is Standee or c is CanvasLayer or c is Camera3D or c is DirectionalLight3D:
			continue
		if c is MeshInstance3D or c is MultiMeshInstance3D:
			var mat: Material = (c as GeometryInstance3D).material_override
			if mat is ShaderMaterial:
				continue  # bends in its shader
			_track(c)
		elif c is VisualInstance3D or c is Light3D:
			_track(c)
		elif c is Node3D:
			track_tree(c, skip)


static func _track(n: Node3D) -> void:
	_tracked.append([n, n.position])


## Moves the curve to follow the camera. focus: the point the camera looks
## at; forward: the camera's view direction flattened onto the ground.
static func update(focus: Vector3, forward: Vector2) -> void:
	origin = focus
	if forward.length() > 0.001:
		fwd = forward.normalized()
	RenderingServer.global_shader_parameter_set("bend_origin", origin)
	RenderingServer.global_shader_parameter_set("bend_fwd", fwd)
	for i in range(_tracked.size() - 1, -1, -1):
		var e: Array = _tracked[i]
		if not is_instance_valid(e[0]):
			_tracked.remove_at(i)
			continue
		var n: Node3D = e[0]
		var base: Vector3 = e[1]
		var parent := n.get_parent() as Node3D
		var world := parent.global_transform * base if parent != null else base
		var dy := drop(world)
		if parent != null:
			dy /= maxf(parent.global_transform.basis.get_scale().y, 0.001)
		n.position = Vector3(base.x, base.y - dy, base.z)
