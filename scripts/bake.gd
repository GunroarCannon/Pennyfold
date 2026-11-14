## Bakes cardboard cut-out pictures into textures. A SubViewport renders the
## Cutout nodes once; right after that draw the picture is copied into a
## mipmapped ImageTexture and the viewport is freed.
##
## Every function returns that ImageTexture straight away (1x1 but reporting
## its final size) and fills it in place a few frames later, so callers keep
## a single reference. Bakes are queued and drawn a few per frame:
## - a SubViewport allocates a render target as soon as it is created, so
##   viewports are only created when their batch draws;
## - each cut-out records hundreds of small draw commands, and drawing them
##   all in one frame ran integrated GPUs out of memory;
## - mipmaps keep small faces crisp when a 300 px cut-out is drawn 70 px
##   tall, instead of shimmering.
class_name Bake
extends RefCounted

## Pixels of bake viewports drawn per frame.
const BUDGET := 3_000_000
## Viewports drawn per frame.
const PER_FRAME := 10

## Waiting bakes: {holder, size, cuts: Array of [kind, params, cell size, x], out}.
static var _waiting: Array = []
static var _pumping := false


static func make(holder: Node, kind: String, params: Dictionary, size: Vector2i) -> Texture2D:
	return _queue(holder, size, [[kind, params, Vector2(size), 0.0]])


## Bakes a jointed figure: every piece in its own column of one texture.
## Returns {"tex": Texture2D, "rig": Dictionary} (see Paint.rig).
static func make_rig(holder: Node, kind: String, params: Dictionary, col: Vector2i) -> Dictionary:
	var rig := Paint.rig(kind, params, Vector2(col))
	var p := params.duplicate()
	p["parts"] = rig["parts"].map(func(d): return d["name"])
	var size := Vector2i(col.x * rig["parts"].size(), col.y)
	return {"tex": _queue(holder, size, [[kind, p, Vector2(col), 0.0]]), "rig": rig}


## Bakes several cut-outs side by side into one atlas texture.
## items: Array of [kind, params]. Cell i covers x in [i*cell.x, (i+1)*cell.x).
static func make_atlas(holder: Node, items: Array, cell: Vector2i) -> Texture2D:
	var cuts: Array = []
	for i in items.size():
		cuts.append([items[i][0], items[i][1], Vector2(cell), float(cell.x * i)])
	return _queue(holder, Vector2i(cell.x * items.size(), cell.y), cuts)


static func _queue(holder: Node, size: Vector2i, cuts: Array) -> ImageTexture:
	var out := ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	out.set_size_override(size)
	if DisplayServer.get_name() == "headless":
		return out  # nothing is ever drawn headless
	_waiting.append({"holder": holder, "size": size, "cuts": cuts, "out": out})
	if not _pumping:
		_pump()
	return out


## Creates a batch of viewports, lets them draw once, copies each picture into
## its texture with mipmaps, frees the batch, and goes on with the next.
static func _pump() -> void:
	_pumping = true
	while not _waiting.is_empty():
		var batch: Array = []
		var px := 0
		while not _waiting.is_empty() and (batch.is_empty() or (batch.size() < PER_FRAME and px + _area(_waiting[0]) <= BUDGET)):
			var job: Dictionary = _waiting.pop_front()
			if not is_instance_valid(job["holder"]):
				continue
			job["vp"] = _viewport(job)
			job["holder"].add_child(job["vp"])
			batch.append(job)
			px += _area(job)
		await RenderingServer.frame_post_draw
		for job in batch:
			var vp: SubViewport = job["vp"]
			if not is_instance_valid(vp):
				continue
			var img := vp.get_texture().get_image()
			if img != null and not img.is_empty():
				if img.get_format() != Image.FORMAT_RGBA8:
					img.convert(Image.FORMAT_RGBA8)
				img.fix_alpha_edges()
				img.generate_mipmaps()
				(job["out"] as ImageTexture).set_image(img)
			vp.queue_free()
	_pumping = false


static func _viewport(job: Dictionary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = job["size"]
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	for c in job["cuts"]:
		var cut := Cutout.new()
		cut.kind = c[0]
		cut.params = c[1]
		cut.canvas_size = c[2]
		cut.position = Vector2(c[3], 0.0)
		vp.add_child(cut)
	return vp


static func _area(job: Dictionary) -> int:
	var s: Vector2i = job["size"]
	return s.x * s.y
