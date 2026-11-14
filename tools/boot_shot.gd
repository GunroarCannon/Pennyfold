## Renders the loading card alone and saves a PNG: godot --path . --script tools/boot_shot.gd -- out.png
extends SceneTree

var _n := 0


func _initialize() -> void:
	return


func _go() -> void:
	var b = root.get_node("Boot")
	b.begin("Unfolding the kingdom")
	b.progress(0.5)


func _process(_d: float) -> bool:
	_n += 1
	if _n == 2:
		_go()
	if _n == 25:
		var out := "boot.png"
		for a in OS.get_cmdline_user_args():
			out = a
		root.get_texture().get_image().save_png(out)
		quit()
	return false
