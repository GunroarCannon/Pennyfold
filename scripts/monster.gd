## A wild monster. Wanders near its den, hunts the player or a townsperson who
## comes close, winds up (a readable tell you can dodge) and strikes.
##
## Danger tiers: the same kind of beast gets nastier the further it lives from
## the town (0 normal, 1 Fierce, 2 Dire). Higher tiers are faster, tougher,
## keep hunting well past their aggro radius and pounce: a short, very fast
## lunge you have to sidestep. A Dire wolf outruns a walking player, and only
## a sprint (which tires you out) gets you away.
##
## Ranged kinds (bat, boss) lock onto a spot, show a warning strip on the
## ground while they charge, then fire a beam along it: step aside to dodge.
class_name Monster
extends RefCounted

const BASE_TYPES := {
	"wolf": {"name": "Wolf", "cute": "Fluffox", "hp": 30.0, "speed": 112.0, "dmg": 7.0, "reach": 36.0, "windup": 0.35,
		"cd": 1.2, "aggro": 220.0, "height": 1.35, "cute_h": 1.35, "knock": 260.0, "drops": {"hide": 1, "meat": 1},
		"pounce": 250.0, "pounce_tier": 1},
	"troll": {"name": "Bog Troll", "cute": "Pebblet", "hp": 90.0, "speed": 62.0, "dmg": 16.0, "reach": 52.0, "windup": 0.7,
		"cd": 2.0, "aggro": 180.0, "height": 2.9, "cute_h": 2.2, "knock": 90.0, "drops": {"ore": 2, "hide": 1},
		"pounce": 230.0, "pounce_tier": 2},
	"slime": {"name": "Bog Ooze", "cute": "Gloop", "hp": 22.0, "speed": 72.0, "dmg": 5.0, "reach": 30.0, "windup": 0.45,
		"cd": 1.3, "aggro": 170.0, "height": 1.0, "cute_h": 1.0, "knock": 300.0, "drops": {"gel": 1},
		"pounce": 170.0, "pounce_tier": 2},
	"shroom": {"name": "Creeper Cap", "cute": "Puffcap", "hp": 34.0, "speed": 66.0, "dmg": 9.0, "reach": 34.0, "windup": 0.5,
		"cd": 1.6, "aggro": 180.0, "height": 1.35, "cute_h": 1.3, "knock": 220.0, "drops": {"herb": 1}},
	"bat": {"name": "Cave Bat", "cute": "Zapwing", "hp": 18.0, "speed": 125.0, "dmg": 8.0, "reach": 34.0, "windup": 0.85,
		"cd": 2.4, "aggro": 270.0, "height": 1.3, "cute_h": 1.3, "knock": 260.0, "drops": {"hide": 1}, "ranged": 240.0,
		"pounce": 280.0, "pounce_tier": 1},
	"boss": {"name": "Thorn Warden", "cute": "Bramble King", "hp": 420.0, "speed": 48.0, "dmg": 22.0, "reach": 74.0, "windup": 0.9,
		"cd": 2.2, "aggro": 340.0, "height": 4.8, "cute_h": 4.8, "knock": 25.0, "drops": {"blade": 1, "ore": 3, "gel": 3}, "ranged": 330.0},
}
static var TYPES: Dictionary = BASE_TYPES.duplicate(true)
static var BEAM_COL := {"bat": Color(1.0, 0.85, 0.3), "boss": Color(0.55, 1.0, 0.5)}
static var _loaded := false


## Adds the sprite beasts from data/bestiary.json to TYPES (once).
static func load_bestiary() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open("res://data/bestiary.json", FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	for k in d["beasts"]:
		var b: Dictionary = d["beasts"][k]
		var t: Dictionary = b.duplicate(true)
		var hh := float(b["h"]) * (1.0 if bool(b.get("boss", false)) else 1.25)
		t["height"] = hh
		t["cute_h"] = hh
		TYPES[k] = t
		if b.has("beam"):
			var c: Array = b["beam"]
			BEAM_COL[k] = Color(c[0], c[1], c[2])


## True for single big fights (the Thorn Warden and the dragons).
static func is_big(k: String) -> bool:
	return k == "boss" or bool(TYPES[k].get("boss", false))


static func is_sprite(k: String) -> bool:
	return TYPES[k].has("sprite")

## per tier: hp, speed, damage, aggro radius, size
const TIERS := [
	{"hp": 1.0, "speed": 1.0, "dmg": 1.0, "aggro": 1.0, "size": 1.0, "prefix": "", "cd": 1.0},
	{"hp": 1.7, "speed": 1.3, "dmg": 1.35, "aggro": 1.35, "size": 1.12, "prefix": "Fierce ", "cd": 0.85},
	{"hp": 2.8, "speed": 1.75, "dmg": 1.9, "aggro": 1.8, "size": 1.3, "prefix": "Dire ", "cd": 0.65},
]
const TIER_TINT := [Color(1, 1, 1), Color(1.0, 0.78, 0.55), Color(1.0, 0.38, 0.32)]

var kind := "wolf"
var tier := 0
var display_name := "Wolf"
var pos := Vector2.ZERO
var home := Vector2.ZERO
var hp := 30.0
var max_hp := 30.0
var speed := 100.0
var dmg := 7.0
var reach := 36.0
var ranged := 0.0
var pounce_range := 0.0
var windup_time := 0.35
var cd := 1.2
var aggro := 210.0
var knock_power := 200.0
var wander := Vector2.ZERO
var wait := 0.0
var attack_cd := 0.0
var windup := 0.0
var windup_kind := ""        # "", "melee", "beam", "pounce"
var aim := Vector2.ZERO
var telegraph: Node3D
var moving := 0.0
var heading := Vector2.RIGHT
var knock := Vector2.ZERO
var killer_id := ""
var target_npc: Npc = null
var target_is_player := false
var view: Standee
var hunt := 0.0              # keeps chasing for a while after losing sight
var dash_t := 0.0
var dash_dir := Vector2.ZERO
var dash_hit := false
var stagger := 0.0           # staggered monsters cannot act (set by heavy hits)
var pack: Array = []         # wolves hunt together


static func rig_kind(k: String, cute: bool) -> String:
	if is_sprite(k):
		return "sprite"
	if cute and k == "wolf":
		return "fluffox"
	if cute and k == "troll":
		return "pebblet"
	return k


static func height_of(k: String, cute: bool) -> float:
	return float(TYPES[k]["cute_h" if cute else "height"])


static func name_of(k: String, cute: bool) -> String:
	return String(TYPES[k]["cute" if cute else "name"])


func setup(k: String, cute: bool, p_tier := 0) -> void:
	kind = k
	tier = clampi(p_tier, 0, 2) if not is_big(k) else 2
	var t: Dictionary = TYPES[k]
	var tt: Dictionary = TIERS[tier] if not is_big(k) else TIERS[0]
	display_name = String(tt["prefix"]) + name_of(k, cute)
	hp = float(t["hp"]) * float(tt["hp"])
	max_hp = hp
	speed = float(t["speed"]) * float(tt["speed"])
	dmg = float(t["dmg"]) * float(tt["dmg"])
	reach = t["reach"]
	ranged = float(t.get("ranged", 0.0))
	windup_time = float(t["windup"]) * (1.0 if tier < 2 else 0.8)
	cd = float(t["cd"]) * float(tt["cd"])
	aggro = float(t["aggro"]) * float(tt["aggro"])
	knock_power = float(t["knock"]) / (1.0 + tier * 0.5)
	if t.has("pounce") and tier >= int(t.get("pounce_tier", 1)):
		pounce_range = float(t["pounce"])


func size_mult() -> float:
	return 1.0 if is_big(kind) else float(TIERS[tier]["size"])


func update(delta: float, world) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	hunt = maxf(0.0, hunt - delta)
	if knock.length() > 5.0:
		pos = world.try_move(pos, knock * delta, 10.0)
		knock = knock.move_toward(Vector2.ZERO, 700.0 * delta)
	if stagger > 0.0:
		stagger -= delta
		moving = 0.0
		return
	if dash_t > 0.0:
		_dash(delta, world)
		return
	if windup > 0.0:
		windup -= delta
		moving = 0.0
		if windup_kind == "pounce":
			heading = (aim - pos).normalized()
		if windup <= 0.0:
			match windup_kind:
				"beam":
					world.monster_beam(self)
				"pounce":
					dash_t = 0.34
					dash_dir = (aim - pos).normalized()
					dash_hit = false
					world.monster_pounce(self)
				_:
					world.monster_strike(self)
			windup_kind = ""
		return

	var tp: Vector2 = world.player["pos"]
	var target := Vector2.INF
	target_npc = null
	target_is_player = false
	var d_player := pos.distance_to(tp)
	var seen: bool = d_player < aggro and not world.player_safe()
	# a hunting beast keeps coming well past its aggro radius
	if seen:
		hunt = 3.5 + tier * 1.5
	if (seen or (hunt > 0.0 and d_player < aggro * 2.2)) and not world.player_safe():
		target = tp
		target_is_player = true
	else:
		var n = world.nearest_npc(pos, aggro * 0.7)
		if n != null:
			target = n.pos
			target_npc = n
	if target != Vector2.INF:
		var d := pos.distance_to(target)
		heading = (target - pos).normalized()
		if d <= reach:
			moving = 0.0
			if attack_cd <= 0.0:
				windup = windup_time
				windup_kind = "melee"
				attack_cd = cd + windup_time
		elif pounce_range > 0.0 and attack_cd <= 0.0 and d > reach * 2.2 and d < pounce_range and target_is_player:
			windup_kind = "pounce"
			aim = target + (target - pos).normalized() * 40.0
			windup = windup_time * 0.9
			attack_cd = cd + windup + 0.5
			world.monster_tell(self, pos, aim)
		elif ranged > 0.0 and d < ranged and d > reach * 1.6 and attack_cd <= 0.0 and target_is_player:
			windup_kind = "beam"
			aim = target
			windup = windup_time * (1.4 if tier < 2 else 1.1)
			attack_cd = cd + windup
			world.monster_charge(self)
		elif kind == "bat" and d < 110.0:
			_step(pos - heading * 60.0, delta, world, 0.8)
		else:
			_step(target, delta, world, _chase_mult(d))
		return

	wait -= delta
	if wait <= 0.0:
		wander = home + Vector2(randf_range(-120.0, 120.0), randf_range(-100.0, 100.0))
		wait = randf_range(2.0, 5.0)
	_step(wander, delta, world, 0.45)


## Beasts close the gap faster when the player is trying to get away.
func _chase_mult(d: float) -> float:
	return 1.0 + (0.25 if tier >= 1 and d > reach * 4.0 else 0.0)


func _dash(delta: float, world) -> void:
	dash_t -= delta
	var before := pos
	pos = world.try_move(pos, dash_dir * 620.0 * delta, 10.0)
	moving = 1.0
	heading = dash_dir
	if not dash_hit:
		var tp: Vector2 = world.player["pos"]
		if target_is_player and pos.distance_to(tp) <= reach * 1.5:
			dash_hit = true
			world.monster_strike(self)
	if pos.distance_to(before) < 0.5:
		dash_t = 0.0


func _step(dest: Vector2, delta: float, world, mult: float) -> void:
	var d := dest - pos
	if d.length() < 3.0:
		moving = 0.0
		return
	var before := pos
	pos = world.try_move(pos, d.normalized() * speed * mult * delta, 10.0)
	moving = 1.0 if pos.distance_to(before) > 0.01 else 0.0
	heading = d.normalized()
	if moving == 0.0:
		wait = 0.0
