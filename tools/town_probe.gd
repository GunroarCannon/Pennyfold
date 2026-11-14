## Prints how each town shape lays out. Run:
##   godot --headless --path . --script tools/town_probe.gd
extends SceneTree


func _init() -> void:
	var f := FileAccess.open("res://data/economy_data.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for id in d["cities"]:
		var kinds: Array = d["cities"][id]["kinds"]
		for sd in [1, 7, 42]:
			var L: Dictionary = TownGen.layout(id, sd, kinds)
			var counts := {}
			for b in L["buildings"]:
				counts[b["kind"]] = int(counts.get(b["kind"], 0)) + 1
			print("%s seed %d shape %s roads %d bridges %d buildings %d %s lamps %d points %d" % [id, sd, L["shape"], L["roads"].size(), L["bridges"].size(), L["buildings"].size(), counts, L["lamps"].size(), L["points"].size()])
	quit()
