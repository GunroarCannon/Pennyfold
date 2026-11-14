## Autoload "Game": settings that survive a scene reload (art style).
extends Node

## The game's name, in one place.
const TITLE := "Pennyfold"
const TAGLINE := "A world of cut paper. A ledger of real coins."
const SETTINGS := "user://settings.cfg"

## "cute" (chibi people, round monsters) or "real" (realistic proportions).
var style := "cute"
## True once the player pressed Play on the title card (or a debug arg skips it).
var started := false
## True when Play was pressed on the title card (debug args skip the title and the tutorial).
var via_title := false
var tutorial_done := false
var force_tutorial := false


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		tutorial_done = bool(cf.get_value("game", "tutorial_done", false))
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


func finish_tutorial() -> void:
	tutorial_done = true
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("game", "tutorial_done", true)
	cf.save(SETTINGS)


func wants_tutorial() -> bool:
	return force_tutorial or (via_title and not tutorial_done)


func cute() -> bool:
	return style == "cute"
