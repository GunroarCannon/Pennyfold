## Shared assets: the wrinkled paper grain and the icon atlas
## (Magnific / Limofeus, see CREDITS.md).
class_name Cardboard
extends RefCounted

static var _paper: Texture2D
static var _atlas: Texture2D
static var _atlas_map: Dictionary = {}


static var _face: Texture2D
static var _core: Texture2D
static var _tape: Texture2D


## Flat kraft liner, greyscale: tinted by each panel.
static func face_tex() -> Texture2D:
	if _face == null:
		_face = load("res://assets/paper/cardboard_face.png")
	return _face


## The pale ribbed layer inside corrugated board.
static func core_tex() -> Texture2D:
	if _core == null:
		_core = load("res://assets/paper/cardboard_core.png")
	return _core


static func tape_tex() -> Texture2D:
	if _tape == null:
		_tape = load("res://assets/paper/tape.png")
	return _tape


static func paper() -> Texture2D:
	if _paper == null:
		_paper = load("res://assets/paper/wrinkled.jpg")
	return _paper


static func icon(icon_name: String) -> Texture2D:
	if _atlas == null:
		_atlas = load("res://assets/atlas/icons.png")
		var f := FileAccess.open("res://assets/atlas/icons.json", FileAccess.READ)
		var d: Dictionary = JSON.parse_string(f.get_as_text())
		_atlas_map = d["icons"]
	if not _atlas_map.has(icon_name):
		return null
	var r: Array = _atlas_map[icon_name]
	var at := AtlasTexture.new()
	at.atlas = _atlas
	at.region = Rect2(r[0], r[1], r[2], r[3])
	return at
