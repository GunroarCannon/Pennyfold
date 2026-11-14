## Seeded town layout. Same seed, same town. The town is a 3x3 grid of blocks
## split by two roads; each block holds one 2x2 cardboard building.
class_name TownGen
extends RefCounted

const TILE := 48
const COLS := 18
const ROWS := 14
const ROAD_X := [5, 11]
const ROAD_Y := [4, 9]
const BLOCKS_X := [[1, 4], [6, 10], [12, 16]]
const BLOCKS_Y := [[1, 3], [5, 8], [10, 12]]
const KIND_ORDER := ["bakery", "market", "tavern", "smithy", "lodge", "guard", "house", "house", "house"]


static func generate(seed_value: int, kind_order: Array = KIND_ORDER, origin := Vector2i.ZERO, prefix := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var kinds: Array = kind_order.duplicate()
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	var buildings: Array = []
	var idx := 0
	for by in BLOCKS_Y:
		for bx in BLOCKS_X:
			var ox := rng.randi_range(bx[0], bx[1] - 2)
			var oy := rng.randi_range(by[0], by[1] - 1)
			var kind: String = kinds[idx]
			buildings.append({"id": "%s%s_%d" % [prefix, kind, idx], "kind": kind, "rect": Rect2i(Vector2i(ox, oy) + origin, Vector2i(3, 2))})
			idx += 1
	return {"seed": seed_value, "buildings": buildings}
