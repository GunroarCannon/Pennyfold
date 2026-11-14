## Autoload "Game": settings that survive a scene reload (art style).
extends Node

## The game's name, in one place.
const TITLE := "Pennyfold"
const TAGLINE := "Don't fold under pressure."
const SETTINGS := "user://settings.cfg"

## "cute" (chibi people, round monsters) or "real" (realistic proportions).
var style := "cute"
## True once the player pressed Play on the title card (or a debug arg skips it).
var started := false
## True when Play was pressed on the title card (debug args skip the title and the tutorial).
var via_title := false
var tutorial_done := false
var force_tutorial := false

## The hero made on the character screen: name, look and stat points.
## `made` is false until the player has been through the creator once.
## A creator draft kept across the scene reload that an art-style switch needs.
var hero_draft: Dictionary = {}
var resume_creator := false
var hero := {"made": false, "name": "You", "skin": 0, "hair": 0, "cloth": 0, "style": 0, "owned": [], "equip": {},
	"stats": {"might": 2, "vigor": 2, "spirit": 2, "swift": 2, "luck": 2}}


## True when the player plays by touch (web on a phone, a mobile export, or the
## first finger that touches the screen). Desktop keeps mouse and keyboard.
var touch := false
## True on web and mobile: smaller bakes, fewer extras, so low-end devices cope.
var low_end := false
signal touch_changed(on: bool)

## The player's own NEAR testnet account ("" = playing as a guest). On the web it
## comes from the wallet login (window.pennyfold in web/shell.html); on desktop
## it is typed on the title screen and remembered in settings.cfg. It is optional:
## the game never needs it to play.
var account := ""
signal account_changed


func _ready() -> void:
	low_end = OS.has_feature("web") or OS.has_feature("mobile") or "--low-end" in OS.get_cmdline_user_args()
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or "--touch" in OS.get_cmdline_user_args():
		touch = true
	elif OS.has_feature("web") and _web_touch_device():
		touch = true
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		tutorial_done = bool(cf.get_value("game", "tutorial_done", false))
		account = str(cf.get_value("chain", "account", ""))
	if OS.has_feature("web"):
		var wa := str(JavaScriptBridge.eval("(window.pennyfold && window.pennyfold.account) || ''"))
		if wa != "":
			account = wa
	for a in OS.get_cmdline_user_args():
		if a == "--tutorial":
			force_tutorial = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--style="):
			style = a.substr(8)
			started = true
		if a.begins_with("--shot=") or a.begins_with("--report="):
			started = true
	# --title keeps the title card up even when another arg would skip it
	if "--title" in OS.get_cmdline_user_args():
		started = false


## A phone or tablet browser: coarse pointer plus touch points.
func _web_touch_device() -> bool:
	var r: Variant = JavaScriptBridge.eval("((navigator.maxTouchPoints || 0) > 0) && window.matchMedia('(pointer: coarse)').matches", true)
	return r == true


## Called by the touch layer on the first finger. Mouse-left stops swinging the
## sword, because a tap on the world would otherwise attack.
func enable_touch() -> void:
	if touch:
		return
	touch = true
	drop_mouse_attack()
	touch_changed.emit(true)


func drop_mouse_attack() -> void:
	if not InputMap.has_action("attack"):
		return
	for ev in InputMap.action_get_events("attack"):
		if ev is InputEventMouseButton:
			InputMap.action_erase_event("attack", ev)


func _input(ev: InputEvent) -> void:
	if not touch and ev is InputEventScreenTouch:
		enable_touch()


## A valid-looking NEAR testnet name: lowercase letters, digits, - _ . and a
## ".testnet" (or 64 hex) ending. The relayer checks that it really exists.
static func valid_account(a: String) -> bool:
	if a.length() < 2 or a.length() > 64:
		return false
	var re := RegEx.new()
	re.compile("^(([a-z0-9]+[-_])*[a-z0-9]+[.])*([a-z0-9]+[-_])*[a-z0-9]+$")
	return re.search(a) != null and (a.ends_with(".testnet") or a.length() == 64)


func set_account(a: String) -> void:
	account = a
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("chain", "account", a)
	cf.save(SETTINGS)
	if OS.has_feature("web") and a == "":
		JavaScriptBridge.eval("window.pennyfold && window.pennyfold.logout()")
	account_changed.emit()


func finish_tutorial() -> void:
	tutorial_done = true
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("game", "tutorial_done", true)
	cf.save(SETTINGS)


func wants_tutorial() -> bool:
	return force_tutorial or (via_title and not tutorial_done)


func stat(n: String) -> int:
	return int(hero["stats"].get(n, 1))


func cute() -> bool:
	return style == "cute"
