## Pennyfold: a cardboard town in an open world. The town sim (wallets,
## shops, wages, hunger) runs as before; around it lie hills, a lake, a mine,
## a farm, ruins and a wood, linked by winding roads. Camera orbits behind
## the hero (Q/E or right-drag), figures are jointed cardboard puppets.
## Two art styles: Game.style "cute" (chibi) or "real".
## Debug args after --: --seed= --hour= --style= --shot=path --frames=N
## --demo=fight|dire|chop|near|beam|talk|shop|map|faces --report=1 --at=landmark_id
extends Node3D

const TILE := 48.0
const K := 1.5 / 48.0
const DAY_SECONDS := 300.0
const PLAYER_SPEED := 165.0
const PRODUCE_EVERY := 18.0
const WAGE := 10
const BOUNTY := 15
const MAX_MONSTERS := 14
const SKY := Color(0.62, 0.80, 0.95)
const NIGHT_SKY := Color(0.10, 0.12, 0.26)
const FONT_PATH := "res://assets/fonts/PatrickHand-Regular.ttf"
const CARD := preload("res://shaders/card.gdshader")
const ROAD := preload("res://shaders/road.gdshader")
const NAMES := ["Mara", "Tobin", "Ines", "Bram", "Yara", "Odo", "Pell", "Wren", "Kasia", "Hugo", "Lio", "Nadia", "Femi", "Sade",
	"Garrick", "Pippa", "Soren", "Thea", "Dax", "Lotte", "Ulf", "Maren", "Cato", "Bessie", "Ravi", "Edda", "Joss", "Nim", "Tamsin", "Orrin",
	"Vesna", "Kip", "Hildy", "Brax", "Fenna", "Moss", "Alba", "Rook", "Sunniva", "Teo", "Luma", "Gus", "Ysolde", "Perrin", "Dot", "Cass", "Bodil", "Ferris"]
const SKINS := [Color(0.98, 0.85, 0.72), Color(0.90, 0.70, 0.54), Color(0.74, 0.54, 0.38), Color(0.54, 0.38, 0.26), Color(0.42, 0.29, 0.20)]
const HAIRS := [Color(0.25, 0.16, 0.10), Color(0.10, 0.08, 0.07), Color(0.86, 0.68, 0.36), Color(0.64, 0.30, 0.14), Color(0.66, 0.66, 0.66)]
var KINDS := {
	"bakery": {"name": "Bakery", "wall": Color(0.97, 0.86, 0.66), "roof": Color(0.78, 0.40, 0.30), "job": "Baker", "shop": true, "h": 2.5,
		"style": "plain", "awning": [Color(0.96, 0.55, 0.66), Color(0.99, 0.96, 0.92)], "sign": "bread",
		"recipe": {"in": {}, "out": {"bread": 3}}, "buys": ["wheat"], "stock": {"bread": 6}, "coins": 200},
	"market": {"name": "General Store", "wall": Color(0.84, 0.92, 0.74), "roof": Color(0.36, 0.56, 0.40), "job": "Merchant", "shop": true, "h": 2.6,
		"style": "plain", "awning": [Color(0.40, 0.70, 0.48), Color(0.99, 0.97, 0.90)], "sign": "herb",
		"recipe": {}, "buys": ["bread", "ale", "meat", "hide", "ore", "blade", "gel", "herb", "wheat", "wood"],
		"stock": {"bread": 4, "ale": 4, "meat": 2, "ore": 3, "blade": 1}, "coins": 320},
	"tavern": {"name": "Tavern", "wall": Color(0.95, 0.84, 0.66), "roof": Color(0.60, 0.28, 0.24), "job": "Barkeep", "shop": true, "h": 3.2,
		"style": "timber", "awning": [Color(0.82, 0.30, 0.28), Color(0.99, 0.92, 0.78)], "sign": "ale",
		"recipe": {"in": {"bread": 1}, "out": {"ale": 2}}, "buys": ["bread"], "stock": {"ale": 4}, "coins": 160},
	"smithy": {"name": "Smithy", "wall": Color(0.76, 0.78, 0.82), "roof": Color(0.34, 0.36, 0.44), "job": "Smith", "shop": true, "h": 2.5,
		"style": "stone", "awning": [Color(0.42, 0.50, 0.66), Color(0.92, 0.92, 0.96)], "sign": "blade",
		"recipe": {"in": {"ore": 2}, "out": {"blade": 1}}, "buys": ["ore"], "stock": {"ore": 2, "blade": 1}, "coins": 220},
	"lodge": {"name": "Hunter Lodge", "wall": Color(0.70, 0.52, 0.34), "roof": Color(0.40, 0.52, 0.30), "job": "Hunter", "shop": true, "h": 2.5,
		"style": "logs", "awning": [Color(0.50, 0.62, 0.34), Color(0.94, 0.88, 0.70)], "sign": "meat",
		"recipe": {"in": {}, "out": {"meat": 2}}, "buys": ["meat", "hide"], "stock": {"meat": 1}, "coins": 180},
	"guard": {"name": "Guard Post", "wall": Color(0.80, 0.78, 0.74), "roof": Color(0.30, 0.30, 0.36), "job": "Guard", "shop": false, "h": 3.6,
		"style": "stone", "recipe": {}, "buys": [], "stock": {}, "coins": 120},
	"house": {"name": "House", "wall": Color(0.95, 0.84, 0.68), "roof": Color(0.66, 0.36, 0.28), "job": "", "shop": false, "h": 2.3,
		"style": "timber", "recipe": {}, "buys": [], "stock": {}, "coins": 0},
	"dock": {"wall": Color(0.76, 0.64, 0.48), "roof": Color(0.28, 0.50, 0.64), "h": 2.4, "style": "logs",
		"awning": [Color(0.30, 0.62, 0.74), Color(0.97, 0.96, 0.92)], "sign": "fish"},
	"saltworks": {"wall": Color(0.94, 0.94, 0.90), "roof": Color(0.52, 0.60, 0.70), "h": 2.4, "style": "plain",
		"awning": [Color(0.62, 0.74, 0.86), Color(0.99, 0.99, 0.96)], "sign": "salt"},
	"lighthouse": {"wall": Color(0.97, 0.96, 0.92), "roof": Color(0.82, 0.28, 0.26), "h": 5.4, "style": "stone"},
	"foundry": {"wall": Color(0.64, 0.60, 0.60), "roof": Color(0.28, 0.26, 0.30), "h": 2.8, "style": "stone",
		"awning": [Color(0.82, 0.40, 0.22), Color(0.95, 0.90, 0.80)], "sign": "ingot"},
	"lapidary": {"wall": Color(0.88, 0.86, 0.95), "roof": Color(0.42, 0.34, 0.64), "h": 2.5, "style": "plain",
		"awning": [Color(0.46, 0.62, 0.84), Color(0.98, 0.98, 1.0)], "sign": "gem"},
	"temple": {"wall": Color(0.94, 0.92, 0.86), "roof": Color(0.62, 0.50, 0.30), "h": 3.6, "style": "stone"},
	"weaver": {"wall": Color(0.98, 0.88, 0.90), "roof": Color(0.74, 0.38, 0.52), "h": 2.5, "style": "timber",
		"awning": [Color(0.88, 0.46, 0.62), Color(0.99, 0.94, 0.88)], "sign": "cloth"},
	"caravanserai": {"wall": Color(0.98, 0.82, 0.60), "roof": Color(0.78, 0.34, 0.24), "h": 3.0, "style": "plain",
		"awning": [Color(0.88, 0.60, 0.24), Color(0.99, 0.94, 0.80)], "sign": "spice"},
	"inn": {"name": "Inn", "wall": Color(0.96, 0.88, 0.72), "roof": Color(0.30, 0.46, 0.60), "job": "Innkeeper", "shop": false, "h": 3.3,
		"style": "timber", "awning": [Color(0.30, 0.50, 0.66), Color(0.99, 0.95, 0.85)], "sign": "ale",
		"recipe": {}, "buys": [], "stock": {}, "coins": 140},
	"exchange": {"wall": Color(0.92, 0.88, 0.70), "roof": Color(0.32, 0.48, 0.40), "h": 3.0, "style": "stone",
		"awning": [Color(0.30, 0.52, 0.40), Color(0.98, 0.96, 0.84)], "sign": "coin"},
}
## Which look (archetype) works each building, when it is not one of the
## original five (those have job_<kind> archetypes of their own).
const JOB_FOLK := {"dock": "fisher", "saltworks": "sailor", "lighthouse": "sailor", "foundry": "blacksmith", "lapidary": "alchemist",
	"temple": "priest", "inn": "job_tavern", "weaver": "bard", "caravanserai": "nomad_merchant", "exchange": "merchant"}
## city id -> archetypes.gd city theme
const CITY_FOLK_KEY := {"sunny": "home", "copperhead": "copper", "saltmere": "port", "highmarket": "souk"}
const HOUSE_WALLS := [Color(0.98, 0.88, 0.72), Color(0.86, 0.92, 0.98), Color(0.99, 0.84, 0.84), Color(0.90, 0.96, 0.82)]
const HOUSE_ROOFS := [Color(0.70, 0.36, 0.28), Color(0.36, 0.48, 0.70), Color(0.56, 0.40, 0.66), Color(0.40, 0.60, 0.44)]
const LOOKS := {
	"bakery": {"hat": "toque", "hat_col": Color(0.97, 0.96, 0.92), "weapon": "pin", "apron": Color(0.96, 0.94, 0.88)},
	"market": {"hat": "cap", "hat_col": Color(0.30, 0.40, 0.70), "weapon": "none"},
	"tavern": {"hat": "short", "weapon": "mug", "beard": true, "apron": Color(0.62, 0.52, 0.40)},
	"smithy": {"hat": "short", "weapon": "hammer", "apron": Color(0.30, 0.24, 0.20), "wide": 1.15},
	"lodge": {"hat": "hood", "hat_col": Color(0.30, 0.48, 0.28), "weapon": "spear"},
	"guard": {"hat": "helmet", "hat_col": Color(0.74, 0.76, 0.80), "weapon": "spear", "cape": Color(0.70, 0.20, 0.18)},
	"dock": {"hat": "cap", "hat_col": Color(0.30, 0.52, 0.66), "weapon": "none", "apron": Color(0.70, 0.78, 0.84)},
	"saltworks": {"hat": "cap", "hat_col": Color(0.90, 0.90, 0.86), "weapon": "none"},
	"lighthouse": {"hat": "cap", "hat_col": Color(0.82, 0.30, 0.26), "weapon": "none"},
	"foundry": {"hat": "short", "weapon": "hammer", "apron": Color(0.30, 0.24, 0.20), "wide": 1.15},
	"lapidary": {"hat": "short", "weapon": "none", "apron": Color(0.50, 0.44, 0.70)},
	"temple": {"hat": "hood", "hat_col": Color(0.90, 0.86, 0.74), "weapon": "none"},
	"weaver": {"hat": "short", "weapon": "none", "apron": Color(0.84, 0.52, 0.66)},
	"caravanserai": {"hat": "cap", "hat_col": Color(0.86, 0.50, 0.28), "weapon": "none"},
	"exchange": {"hat": "cap", "hat_col": Color(0.30, 0.46, 0.38), "weapon": "none"},
	"": {"hat": "short", "weapon": "none"},
}
const CHATTER := [
	["Fine day for it.", "Fine day indeed."],
	["Bread is %s coins today.", "Ugh. Again?"],
	["Saw a %s by the road.", "Stay inside the fence then."],
	["The till at the %s is full.", "Must be nice."],
	["Wages come at five.", "If they can pay."],
	["Heard the ruins are crawling.", "Not going near them."],
]

var cute := true
var font: Font
var world: World
var quests: Quests
var career: Career
var skills: Skills
var allies: Array = []
var burning := {}
var story: Story
var _npc_seq := 0
var _event_timer := 5.0
var nearby_temple := ""
var bestiary := {}
var _met_t := 0.0
var buildings: Array = []
## Each town: {id, name, origin (tile), rect (px), start (px), kinds, palette, folk, tone}. towns[0] is Sunny Town.
var towns: Array = []
var founding_main := 0
var inside_town := ""
var npcs: Array = []
var monsters: Array = []
var gathers: Array = []
var discovered := {}
var player: Dictionary = {}
var player_view: Standee
## The shared world connection (null when playing offline).
var net: Net
var rig_cache := {}
var prompt := ""
var clock := 0.0
var hour := 6.0
var nearby_shop := ""
var nearby_inn := ""
var mayors := {}
var nearby_npc: Npc = null
var nearby_gather := -1
var near_board := false
var dialog_npc: Npc = null
var inside_landmark := ""

var astar := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var clouds: Array = []
var lamps: Array = []
var fades: Array = []
var hud: Hud
var bake_root: Node
var tex_cache: Dictionary = {}
var cam_focus := Vector3.ZERO
var cam_yaw := 0.0
var cam_pitch := 0.55
var cam_dist := 14.0
var cam_fov := 50.0
var cam_shake := 1.0
var talk_k := 0.0
var player_idle := 0.0
var _player_prev_pos := Vector2.ZERO
var view_dir := {}
var fov_kick := 0.0
var target_ring_node: Node3D
var aim_target: Monster = null
var talk_focus := Vector3.ZERO
var shake := 0.0
var production_timer := 0.0
var spawn_timer := 0.0
var chatter_timer := 6.0
var dust_timer := 0.0
var boss_timer := 0.0
var shot_path := ""
var shot_frames := 150
var frame := 0
var start_pos := Vector2.ZERO
var founding_size := 0
var board_pos := Vector2.ZERO
var last_pos := {}
var marker: Node3D
var amb := {}
var raining := false
var rain_left := 0.0


# ---------------- setup ----------------

var ready_done := false


## Lets the loading card (boot.gd) draw a frame between build stages.
func _stage(f: float, text: String) -> void:
	if Boot.active:
		Boot.progress(f, text)
		await get_tree().process_frame


func _ready() -> void:
	await _stage(0.05, "Cutting the cardboard")
	_setup_input()
	cute = Game.cute()
	font = load(FONT_PATH)
	rng.seed = _seed_from_args()
	net = Net.new()
	add_child(net)
	if await net.join(self):
		rng.seed = net.seed_value
		clock = net.clock_value
	else:
		net.queue_free()
		net = null
	shot_path = _arg_value("--shot=")
	if _arg_value("--frames=") != "":
		shot_frames = int(_arg_value("--frames="))
	if _arg_value("--hour=") != "":
		clock = fposmod((float(_arg_value("--hour=")) - 6.0) / 24.0 * DAY_SECONDS, DAY_SECONDS)
	Economy.reset()
	Monster.load_bestiary()
	_merge_kinds()
	Economy.add_wallet(Quests.ESCROW, 0)
	story = Story.new()
	Economy.add_wallet(Story.VAULT, story.vault_coins())
	bake_root = Node.new()
	add_child(bake_root)
	Fx.setup(bake_root)

	await _stage(0.15, "Folding the hills")
	world = World.new()
	world.generate(rng.seed, cute)
	Fx.world = world
	_make_towns()
	_build_town_grid()
	_build_environment()
	world.build(self, bake_root, Cardboard.paper())
	for tn in towns:
		_build_town_ground(tn)
		_build_fence(tn)
		_build_town_props(tn)
	await _stage(0.4, "Gluing the towns together")
	_build_buildings()
	_build_landmarks()
	_build_clouds()
	amb = Fx.ambient(self, cute)
	if _arg_value("--weather=") == "rain":
		raining = true
		rain_left = 999.0

	start_pos = town_by_id("sunny")["start"]
	player = {"pos": start_pos, "hp": 100.0, "max_hp": 100.0, "facing": 1.0, "moving": 0.0, "heading": Vector2(0, -1),
		"cool": 0.0, "beam_cool": 0.0, "ink": 100.0, "knock": Vector2.ZERO, "last_hurt": -99.0, "sprint": false, "z": 0.0, "vz": 0.0,
		"stamina": 100.0, "tired": false,
		"combo": 0, "combo_t": 0.0, "hit_t": -1.0, "hit_step": 0, "dodge_cd": 0.0, "dash_t": 0.0,
		"dash_dir": Vector2.ZERO, "iframes": 0.0, "grace": 0.0, "perfected": false, "move_dir": Vector2.ZERO,
		"combo_hits": 0, "combo_show": 0.0}
	Economy.add_wallet("player", 60)
	skills = Skills.new()
	career = Career.new()
	career.skills = skills
	career.apply_stats(self, true)
	player_view = _make_standee(_bake_person(hero_look(), Vector2i(256, 320)), 1.75 if cute else 2.3, "You")
	player_view.show_hp = false

	await _stage(0.6, "Waking the townsfolk")
	# Sunny Town is populated now; the other cities fill up as you approach them
	# (baking every townsperson's cut-out at once would cost too much memory).
	_populate(town_by_id("sunny"))
	founding_main = npcs.size()
	founding_size = npcs.size()
	_spawn_merchants()

	camera = Camera3D.new()
	camera.fov = cam_fov
	camera.far = 420.0
	add_child(camera)
	camera.current = true
	cam_focus = _to3(start_pos)

	quests = Quests.new()
	quests.refresh(self)

	hud = Hud.new()
	hud.main = self
	add_child(hud)
	Economy.message.connect(hud.add_log)
	Economy.message.emit("Welcome to %s. Every coin here belongs to someone." % Game.TITLE)
	Economy.message.emit("Shops trade at their doors (E). The quest board pays real coins from escrow.")
	Chain.attach(self)
	Economy.transferred.connect(_on_gold)

	marker = _billboard(Bake.make(bake_root, "marker", {}, Vector2i(96, 128)), 0.9, Vector3.ZERO)
	marker.visible = false

	await _stage(0.85, "Letting the wolves out")
	for i in 6:
		_spawn_monster_near(true)
	_spawn_boss()
	_seed_danger_zones()
	Bend.reset()
	Bend.track_tree(self, clouds + amb.values() + [marker, bake_root])
	_apply_debug_args()
	if not Game.started:
		hud.show_title()
	ready_done = true
	if net != null:
		net.flush_pending()
		Economy.message.emit("Shared world: other players appear here. Enter to chat.")
	Boot.finish()


func _apply_debug_args() -> void:
	var tw := _arg_value("--town=")
	if tw != "" and not town_by_id(tw).is_empty():
		player["pos"] = town_by_id(tw)["start"]
		cam_focus = _to3(player["pos"])
	if _arg_value("--cam=") != "":
		var cp := _arg_value("--cam=").split(",")
		cam_dist = float(cp[0])
		if cp.size() > 1:
			cam_pitch = float(cp[1])
		cam_focus = _to3(player["pos"])
	var at := _arg_value("--at=")
	if at != "" and not world.landmark(at).is_empty():
		var l0 := world.landmark(at)
		player["pos"] = _free_spot_near(l0.get("spot", l0["pos"] + Vector2(0, 180)))
		cam_focus = _to3(player["pos"])
	# debug: --wear=plume,steel,sword,cape_red --style=3 puts gear on the hero for a screenshot
	if _arg_value("--wear=") != "":
		Gear.ensure()
		for id in _arg_value("--wear=").split(","):
			if Gear.ITEMS.has(id):
				Gear.toggle(id)
		if _arg_value("--hairstyle=") != "":
			Game.hero["style"] = int(_arg_value("--hairstyle="))
		apply_hero(false)
	match _arg_value("--demo="):
		"fight":
			for kind in ["wolf", "troll", "slime"]:
				var off := {"wolf": Vector2(130, 10), "troll": Vector2(-150, -20), "slime": Vector2(60, -110)}
				_add_monster(kind, Vector2(player["pos"]) + off[kind])
		"near":
			# Integration check without playing: sell some wheat so there is a real
			# coin flow, settle it right away, print the relayer's answer and quit.
			var sid := _shop_of_kind("bakery")
			Economy.add_item("player", "wheat", 2)
			Economy.sell(sid, "wheat", "player")
			Economy.sell(sid, "wheat", "player")
			get_tree().create_timer(2.0).timeout.connect(func(): Chain.settle_now(self))
			get_tree().create_timer(6.0).timeout.connect(func():
				print("NEAR TEST  mode=", Chain.mode, " network=", Chain.network, " account=", Chain.root_account)
				print("NEAR TEST  ", Chain.summary())
				for e in Chain.day_log:
					print("NEAR TEST  day ", e["day"], " status=", e["status"], " txs=", e.get("txs", []))
				if Chain.last_error != "":
					print("NEAR TEST  last_error=", Chain.last_error)
				get_tree().quit())
		"dire":
			for e in [["wolf", Vector2(120, 10)], ["wolf", Vector2(160, -50)], ["troll", Vector2(-170, -20)], ["bat", Vector2(40, -170)]]:
				_add_monster(e[0], Vector2(player["pos"]) + e[1], 2)
			player["heading"] = Vector2(1, 0)
			for t in [0.35, 0.65, 0.95]:
				get_tree().create_timer(t).timeout.connect(_player_attack)
		"chop":
			var best: Dictionary = {}
			var bd := INF
			for t in world.trees:
				var d: float = Vector2(t["pos"]).distance_to(player["pos"])
				if d < bd and d > 120.0 and not world.tile_solid(Vector2i(t["tile"]) + Vector2i(-1, 0)):
					bd = d
					best = t
			player["pos"] = Vector2(best["pos"]) + Vector2(-50, 10)
			player["heading"] = Vector2(1, -0.1).normalized()
			cam_focus = _to3(player["pos"])
			for tm in [0.3, 0.7, 1.1, 1.5]:
				get_tree().create_timer(tm).timeout.connect(_player_attack)
		"beam":
			_add_monster("bat", Vector2(player["pos"]) + Vector2(200, -60))
			_add_monster("shroom", Vector2(player["pos"]) + Vector2(-120, -40))
			player["heading"] = Vector2(1, -0.3).normalized()
			skills.known["blast"] = 1
			cast.call_deferred("blast")
		"title":
			Game.started = false
			hud.show_title.call_deferred()
		"creator":
			Game.hero["made"] = false
			hud.table.visible = true
			hud.menus.show_creator.call_deferred(func() -> void: pass)
		"skilltree":
			skills.known["blast"] = 1
			skills.known["mend"] = 1
			skills.known["tough"] = 2
			skills.points = 3
			career.level = 6
			hud.menus.toggle_skills.call_deferred()
		"pause":
			hud.menus.toggle_pause.call_deferred()
		"skills":
			for k in skills.by_id:
				skills.known[k] = 1
			player["ink"] = 400.0
			player["max_ink"] = 400.0
			player["heading"] = Vector2(1, 0)
			for off in [Vector2(200, -30), Vector2(260, 40), Vector2(150, 70)]:
				_add_monster("wolf", Vector2(player["pos"]) + off)
			get_tree().create_timer(0.3).timeout.connect(cast.bind("flame"))
			get_tree().create_timer(0.9).timeout.connect(cast.bind("summon"))
			get_tree().create_timer(1.5).timeout.connect(cast.bind("inferno"))
			get_tree().create_timer(2.4).timeout.connect(cast.bind("greater_blast"))
		"dragon":
			_add_monster("bat", Vector2(player["pos"]) + Vector2(-220, -30))
			_add_monster("shroom", Vector2(player["pos"]) + Vector2(-140, 20))
			player["heading"] = -_cam_right()
			skills.known["dragon"] = 1
			player["ink"] = 100.0
			get_tree().create_timer(1.0).timeout.connect(cast.bind("dragon"))
		"talk":
			var n: Npc = npcs[1]
			n.pos = Vector2(player["pos"]) + Vector2(70, -20)
			_open_dialog.call_deferred(n)
		"shop":
			var sid := _shop_of_kind("bakery")
			player["pos"] = _free_spot_near(door_of(sid))
			cam_focus = _to3(player["pos"])
			hud.open_shop.call_deferred(sid)
		"faces":
			# a row of townsfolk close to the camera, to check faces
			cam_dist = 6.5
			for i in mini(8, npcs.size()):
				var n: Npc = npcs[i]
				n.pos = Vector2(player["pos"]) + Vector2(-150.0 + i * 43.0, 50.0)
				n.wander_target = n.pos
		"career":
			get_tree().create_timer(0.5).timeout.connect(_career_selftest)
		"story":
			career.gain(self, 400, "test")
			var cap := story.giver(self)
			var say := func(opt: String) -> void: print("STORY ", opt, ": ", story.choose(self, opt).left(90).replace("
", " "))
			say.call("intro")
			for i in 4:
				story.state = "active"
				var g: Dictionary = story.current()["goal"]
				story.progress = int(g["count"]) if g["type"] != "deliver" else 0
				if g["type"] == "deliver":
					Economy.add_item("player", g["good"], int(g["count"]))
				print("STORY chapter ", story.chapter, " met=", story.goal_met(self), " coins=", Economy.wallets["player"]["coins"], " vault=", Economy.wallets["crown"]["coins"])
				say.call("finish")
			print("STORY finished=", story.finished, " plus=", story.plus, " level=", career.level, " total_coins=", Economy.total_coins())
			get_tree().create_timer(3.0).timeout.connect(func(): get_tree().quit())
		"beasts":
			var ks := ["spider", "scorpion", "skeleton", "golem", "ogre", "crocodog", "mummy", "dragon_red"]
			for i in ks.size():
				var ang := TAU * i / ks.size()
				_add_monster(ks[i], Vector2(player["pos"]) + Vector2(cos(ang), sin(ang)) * (230.0 + (80.0 if i == 7 else 0.0)))
			for m in monsters:
				m.aggro = 0.0
			cam_dist = 17.0
		"bestiary":
			for k in Monster.TYPES:
				if randf() < 0.6:
					bestiary[k] = {"seen": 30, "kills": randi() % 9, "best_tier": randi() % 3}
			hud.toggle_bestiary.call_deferred()
		"merchants":
			Engine.time_scale = 12.0
			get_tree().create_timer(25.0, true, false, true).timeout.connect(func():
				Engine.time_scale = 1.0
				for n in npcs:
					if n is Merchant:
						print("MERCHANT ", n.display_name, " phase=", n.phase, " coins=", n.coins(), " profit=", n.profit_total, " cargo=", n.cargo(), " route=", n.route_text(self), " hp=", n.hp)
				print("MERCHANT events=", Economy.active_events.size(), " day=", day_number(), " total_coins=", Economy.total_coins())
				get_tree().quit())
		"death":
			player["hurt_by"] = "a Dire Wolf"
			career.gain(self, 70, "test")
			get_tree().create_timer(0.4).timeout.connect(_knock_out)
		"guard":
			var wolf := _add_monster("wolf", town_by_id("sunny")["start"] + Vector2(260, 40), 0)
			get_tree().create_timer(14.0).timeout.connect(func():
				print("GUARD TEST wolf_alive=", monsters.has(wolf), " hp=", wolf.hp, " killer=", wolf.killer_id)
				get_tree().quit())
		"map":
			for l in world.landmarks:
				discovered[l["id"]] = true
				hud._reveal(l["pos"], int(l["r"]) + 10)
			hud.toggle_map.call_deferred()


## Headless check of the career rules: prints PASS/FAIL lines and quits.
func _career_selftest() -> void:
	var ok := func(name: String, cond: bool) -> void: print(("PASS " if cond else "FAIL ") + name)
	var lv0 := career.level
	career.gain(self, career.needed() + 1, "test")
	ok.call("level up", career.level == lv0 + 1 and float(player["max_hp"]) > 100.0)
	var bak := _shop_of_kind("bakery")
	ok.call("apply bakery", career.apply(self, bak) == "")
	ok.call("no 2nd job", career.apply(self, bak) != "")
	var smithy := _shop_of_kind("smithy")
	career.quit(self)
	ok.call("smithy needs more", career.apply(self, smithy) != "")
	career.apply(self, bak)
	career.job["grace_day"] = -5
	player["pos"] = door_of(bak)
	hour = 10.0
	career.update(self, 60.0)
	var coins0 := int(Economy.wallets["player"]["coins"])
	career.payday(self)
	ok.call("paid for full shift", int(Economy.wallets["player"]["coins"]) > coins0)
	career.payday(self)
	career.payday(self)
	ok.call("fired after 2 missed shifts", not career.has_job())
	ok.call("grudge blocks hire", career.apply(self, bak) != "")
	career.grudges.clear()
	career.apply(self, bak)
	var n: Npc = null
	for o in npcs:
		if o.job_id == bak:
			n = o
	career.on_assault(self, n)
	ok.call("fired for attacking staff", not career.has_job())
	ok.call("shop refuses after assault", career.refuses(self, bak))
	var coins1 := int(Economy.wallets["player"]["coins"])
	_knock_out()
	ok.call("knock out halves coins", int(Economy.wallets["player"]["coins"]) <= coins1 and player["down"])
	print("career: level ", career.level, " xp ", career.xp, "/", career.needed())
	get_tree().quit()


func _seed_from_args() -> int:
	var s := _arg_value("--seed=")
	return int(s) if s != "" else randi() % 100000


func _arg_value(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""


func _setup_input() -> void:
	var binds := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E], "attack": [KEY_J], "jump": [KEY_SPACE], "keys": [KEY_F1], "style": [KEY_F2], "beam": [KEY_K, KEY_R], "dragon": [KEY_V], "dodge": [KEY_X, KEY_CTRL], "eat": [KEY_F],
		"ledger": [KEY_TAB], "skills": [KEY_T], "skill_1": [KEY_1], "skill_2": [KEY_2], "skill_3": [KEY_3], "skill_4": [KEY_4], "skill_5": [KEY_5], "skill_6": [KEY_6], "map": [KEY_M], "quests": [KEY_L], "bestiary": [KEY_B], "cam_left": [KEY_Q], "cam_right": [KEY_C],
		"sprint": [KEY_SHIFT], "cancel": [KEY_ESCAPE],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in binds[action]:
			var ev := InputEventKey.new()
			ev.keycode = code
			InputMap.action_add_event(action, ev)
	if not Game.touch:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mb)


## Folds the economy data into the building looks: names, jobs, recipes,
## stock, coins. A building is a shop if it trades anything.
func _merge_kinds() -> void:
	for kind in KINDS:
		var e: Dictionary = Economy.building(kind)
		var k: Dictionary = KINDS[kind]
		for key in ["name", "job", "recipe", "buys", "stock", "coins"]:
			if e.has(key):
				k[key] = e[key]
		var buys: Variant = k.get("buys", [])
		k["shop"] = not (k.get("recipe", {}) as Dictionary).is_empty() or not (k.get("stock", {}) as Dictionary).is_empty() \
			or (typeof(buys) == TYPE_STRING) or not (buys as Array).is_empty()


## Lays out the towns: Sunny Town at the origin and the extra cities where the
## world put them, each with its own building list, look and people.
func _make_towns() -> void:
	towns.clear()
	var defs: Dictionary = Economy.data["cities"]
	var main_def: Dictionary = defs["sunny"]
	towns.append(_town_entry("sunny", main_def, Vector2i.ZERO))
	for c in world.cities:
		var d: Dictionary = defs[c["id"]]
		towns.append(_town_entry(c["id"], d, Vector2i(c["origin"])))


func _town_entry(id: String, d: Dictionary, origin: Vector2i) -> Dictionary:
	var L: Dictionary = world.layouts[id]
	var rect := Rect2(Vector2(origin) * TILE, Vector2(L["size"]) * TILE)
	return {"id": id, "name": d["name"], "origin": origin, "rect": rect, "population": int(d.get("population", 4)), "layout": L,
		"start": (Vector2(origin) + (L["start"] as Vector2)) * TILE,
		"kinds": d["kinds"], "palette": d.get("palette", {}), "folk": CITY_FOLK_KEY.get(id, "home"), "tone": d.get("tone", "cheery")}


func town_by_id(id: String) -> Dictionary:
	for tn in towns:
		if tn["id"] == id:
			return tn
	return {}


## The town whose walls (plus a margin of tiles) contain p, or "".
func town_at(p: Vector2, margin := 1.5) -> String:
	for tn in towns:
		if (tn["rect"] as Rect2).grow(margin * TILE).has_point(p):
			return tn["id"]
	return ""


func _build_town_grid() -> void:
	astar.region = Rect2i(World.T0, World.TN)
	astar.cell_size = Vector2(TILE, TILE)
	astar.offset = Vector2(TILE * 0.5, TILE * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	for tn in towns:
		var pref: String = "" if tn["id"] == "sunny" else tn["id"] + "_"
		var layout: Dictionary = tn["layout"]
		for b0 in layout["buildings"]:
			var b: Dictionary = b0.duplicate()
			b["id"] = pref + String(b0["id"])
			b["rect"] = Rect2i(b0["rect"].position + tn["origin"], b0["rect"].size)
			var r: Rect2i = b["rect"]
			var px := Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)
			var k: Dictionary = KINDS[b["kind"]]
			buildings.append({"id": b["id"], "kind": b["kind"], "name": k["name"], "rect": px, "city": tn["id"],
				"door": Vector2(px.get_center().x, px.end.y + 16.0), "shop": k["shop"]})
			for tx in range(r.position.x, r.end.x):
				for ty in range(r.position.y, r.end.y):
					astar.set_point_solid(Vector2i(tx, ty), true)
			if k["shop"]:
				Economy.add_shop(b["id"], k["name"], k["recipe"], k["stock"], k["buys"], k["coins"], tn["id"], b["kind"])
			elif int(k["coins"]) > 0:
				Economy.add_wallet(b["id"], k["coins"])
		for t in _fence_tiles(tn):
			astar.set_point_solid(t, true)


## Copies the world's blocked tiles (water, cliffs, trees) into the grid.
## Called after the scatter so tree trunks block too.
func _apply_world_solids() -> void:
	for j in World.TN.y:
		for i in World.TN.x:
			var t := Vector2i(World.T0.x + i, World.T0.y + j)
			if world.tile_solid(t):
				astar.set_point_solid(t, true)


func _fence_tiles(tn: Dictionary) -> Array:
	var o: Vector2 = Vector2(tn["origin"])
	var out: Array = []
	for f in tn["layout"]["fence"]:
		out.append(Vector2i((o + (f["p"] as Vector2)).floor()))
	return out


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.60, 0.92)
	sky_mat.sky_horizon_color = Color(0.86, 0.92, 0.98)
	sky_mat.ground_horizon_color = Color(0.86, 0.92, 0.98)
	sky_mat.ground_bottom_color = Color(0.5, 0.6, 0.5)
	sky_mat.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.92, 0.85)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.80, 0.88, 0.96)
	env.fog_density = 0.0042
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if Game.low_end:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 40.0
		RenderingServer.directional_shadow_atlas_set_size(1024, true)
	add_child(sun)


func _card(tex: Texture2D, tint: Color, uv: Vector2, cutout := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CARD
	if tex != null:
		m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("grain", Cardboard.paper())
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("uv_scale", uv)
	m.set_shader_parameter("cutout", cutout)
	return m


func _mesh(mesh: Mesh, mat: Material, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


func _build_town_ground(tn: Dictionary) -> void:
	var L: Dictionary = tn["layout"]
	var og := Vector2(tn["origin"]) * 1.5
	# One shader draws every road as a union of rounded strips: soft junction
	# fillets, round ends, a wobbly paper-cut edge and a curb lip.
	var cob := Bake.make(bake_root, "cobble", {"col": Color(0.80, 0.76, 0.70) if cute else Color(0.66, 0.63, 0.58)}, Vector2i(256, 256))
	var sz: Vector2i = L["size"]
	var x0 := -3.4
	var y0 := -3.4
	var x1 := sz.x + 3.4
	var y1 := sz.y + 3.4
	var segs := PackedVector4Array()
	var segw := PackedFloat32Array()
	for sg in L["roads"]:
		if segs.size() >= 64:
			break
		var a2: Vector2 = Vector2(tn["origin"]) + (sg[0] as Vector2)
		var b2: Vector2 = Vector2(tn["origin"]) + (sg[1] as Vector2)
		segs.append(Vector4(a2.x * 1.5, a2.y * 1.5, b2.x * 1.5, b2.y * 1.5))
		segw.append(float(sg[2]) * 1.5)
	var seg_n := segs.size()
	while segs.size() < 64:
		segs.append(Vector4(0, 0, 0, 0))
		segw.append(0.0)
	var discs := PackedVector4Array()
	for d in L["discs"]:
		var dc: Vector2 = Vector2(tn["origin"]) + (d[0] as Vector2)
		discs.append(Vector4(dc.x * 1.5, dc.y * 1.5, float(d[1]) * 1.5, 0.0))
	var disc_n := mini(discs.size(), 4)
	while discs.size() < 4:
		discs.append(Vector4(0, 0, 0, 0))
	var mat := ShaderMaterial.new()
	mat.shader = ROAD
	mat.set_shader_parameter("rects", PackedVector4Array([Vector4(0, 0, 0, 0)]))
	mat.set_shader_parameter("rect_n", 0)
	mat.set_shader_parameter("segs", segs)
	mat.set_shader_parameter("segw", segw)
	mat.set_shader_parameter("seg_n", seg_n)
	mat.set_shader_parameter("discs", discs)
	mat.set_shader_parameter("disc_n", disc_n)
	mat.set_shader_parameter("mode", 0)
	mat.set_shader_parameter("fillet", 0.55)
	mat.set_shader_parameter("tex", cob)
	mat.set_shader_parameter("grain", Cardboard.paper())
	mat.set_shader_parameter("base_col", Color(0.80, 0.76, 0.70) if cute else Color(0.66, 0.63, 0.58))
	var pm := PlaneMesh.new()
	pm.size = Vector2((x1 - x0) * 1.5, (y1 - y0) * 1.5)
	pm.subdivide_width = int(x1 - x0)
	pm.subdivide_depth = int(y1 - y0)
	_mesh(pm, mat, Vector3((x0 + x1) * 0.75 + og.x, 0.03, (y0 + y1) * 0.75 + og.y), self)


func _build_buildings() -> void:
	var idx := 0
	for b in buildings:
		idx += 1
		var k: Dictionary = KINDS[b["kind"]]
		var wall: Color = k["wall"]
		var roof: Color = k["roof"]
		var style: String = k["style"]
		var pal: Dictionary = town_by_id(b["city"]).get("palette", {})
		var pw: Array = pal.get("walls", [])
		var pr: Array = pal.get("roofs", [])
		if b["kind"] == "house":
			wall = HOUSE_WALLS[idx % HOUSE_WALLS.size()]
			roof = HOUSE_ROOFS[(idx * 3) % HOUSE_ROOFS.size()]
			style = "timber" if idx % 2 == 0 else "plain"
			if not pw.is_empty():
				var c: Array = pw[idx % pw.size()]
				wall = Color(c[0], c[1], c[2])
			if not pr.is_empty():
				var c2: Array = pr[(idx * 3) % pr.size()]
				roof = Color(c2[0], c2[1], c2[2])
		else:
			# shops keep their identity but lean towards the city's colours
			if not pw.is_empty():
				var c3: Array = pw[idx % pw.size()]
				wall = wall.lerp(Color(c3[0], c3[1], c3[2]), 0.35)
			if not pr.is_empty():
				var c4: Array = pr[(idx * 2) % pr.size()]
				roof = roof.lerp(Color(c4[0], c4[1], c4[2]), 0.30)
		var r: Rect2 = b["rect"].grow(-5.0)
		var w := r.size.x * K
		var d := r.size.y * K
		var hgt: float = float(k["h"]) * 1.3
		var root := Node3D.new()
		root.position = Vector3(r.get_center().x * K, 0.0, r.get_center().y * K)
		add_child(root)
		var mats: Array = []
		var base := {"wall": wall, "trim": roof, "style": style, "seed": idx, "font": font}
		var front := base.duplicate()
		front["door"] = true
		front["windows"] = 2
		front["name"] = k["name"] if k["shop"] else ""
		var side := base.duplicate()
		side["windows"] = 1
		var back := base.duplicate()
		back["windows"] = 2
		var ftex := Bake.make(bake_root, "wall", front, Vector2i(320, int(320.0 * hgt / w)))
		var stex := Bake.make(bake_root, "wall", side, Vector2i(256, int(256.0 * hgt / d)))
		var btex := Bake.make(bake_root, "wall", back, Vector2i(320, int(320.0 * hgt / w)))
		var faces := [[ftex, Vector2(w, hgt), Vector3(0, hgt * 0.5, d * 0.5), 0.0],
			[btex, Vector2(w, hgt), Vector3(0, hgt * 0.5, -d * 0.5), PI],
			[stex, Vector2(d, hgt), Vector3(w * 0.5, hgt * 0.5, 0), PI * 0.5],
			[stex, Vector2(d, hgt), Vector3(-w * 0.5, hgt * 0.5, 0), -PI * 0.5]]
		for f in faces:
			var qm := QuadMesh.new()
			qm.size = f[1]
			var m := _card(f[0], Color.WHITE, Vector2.ONE)
			mats.append(m)
			var mi := _mesh(qm, m, f[2], root)
			mi.rotation.y = f[3]
		if b["kind"] in ["guard", "lighthouse"]:
			_tower_top(root, w, d, hgt, wall, mats)
		else:
			_roof(root, w, d, hgt, wall, roof, mats)
		if b["kind"] in ["bakery", "smithy", "tavern", "house", "foundry", "saltworks"]:
			var ch := _mesh(_box(Vector3(0.45, 1.3, 0.45)), _card(null, Color(0.74, 0.38, 0.30), Vector2.ONE), Vector3(w * 0.3, hgt + 1.3, -d * 0.12), root)
			mats.append(ch.material_override)
			Fx.smoke(root, Vector3(w * 0.3, hgt + 2.0, -d * 0.12))
		if k.has("awning"):
			var aw := Bake.make(bake_root, "awning", {"a": k["awning"][0], "b": k["awning"][1]}, Vector2i(256, 96))
			var qa := QuadMesh.new()
			qa.size = Vector2(w * 0.86, 1.1)
			var am := _card(aw, Color.WHITE, Vector2.ONE, true)
			mats.append(am)
			var awn := _mesh(qa, am, Vector3(0, hgt * 0.64, d * 0.5 + 0.42), root)
			awn.rotation.x = -0.75
			var icon := Bake.make(bake_root, "item", {"good": k["sign"]}, Vector2i(128, 128))
			var board := _billboard(Bake.make(bake_root, "signboard", {}, Vector2i(160, 140)), 0.95, root.position + Vector3(w * 0.5 + 0.35, hgt * 0.62, d * 0.5 + 0.35), root)
			board.position = Vector3(w * 0.5 + 0.35, hgt * 0.62, d * 0.5 + 0.35)
			var ic := Standee.make_sprite(icon, 0.55 / 128.0)
			ic.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			ic.position = Vector3(0, 0.12, 0.02)
			board.add_child(ic)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.72, 0.38)
		lamp.omni_range = 5.5
		lamp.light_energy = 0.0
		lamp.position = Vector3(0, 1.4, d * 0.5 + 0.9)
		root.add_child(lamp)
		lamps.append(lamp)
		fades.append({"mats": mats, "rect": b["rect"], "fade": 1.0, "h": hgt})


func _box(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


## A gable roof: a wall-coloured prism for the gable ends under two
## shingled cardboard slabs with visible thickness.
func _roof(root: Node3D, w: float, d: float, hgt: float, wall: Color, roof: Color, mats: Array) -> void:
	var rh := 1.3 + d * 0.22
	var pm := PrismMesh.new()
	pm.size = Vector3(d, rh, w)
	var gm := _card(null, wall.darkened(0.08), Vector2.ONE)
	mats.append(gm)
	var gable := _mesh(pm, gm, Vector3(0, hgt + rh * 0.5, 0), root)
	gable.rotation.y = PI * 0.5
	var shingles := Bake.make(bake_root, "shingles", {"col": roof}, Vector2i(256, 256))
	var half := d * 0.5 + 0.35
	var slope := atan2(rh, d * 0.5)
	var length := Vector2(half, rh * half / (d * 0.5)).length()
	for side in [-1.0, 1.0]:
		var sm := _card(shingles, Color.WHITE, Vector2(w / 0.9, length / 0.9))
		mats.append(sm)
		var slab := _mesh(_box(Vector3(w + 0.6, 0.14, length)), sm, Vector3(0, hgt + rh * 0.5 - 0.05, side * d * 0.25), root)
		slab.rotation.x = side * slope
		slab.position = Vector3(0, hgt + rh - (length * 0.5) * sin(slope) + 0.02, side * (length * 0.5) * cos(slope))


func _tower_top(root: Node3D, w: float, d: float, hgt: float, wall: Color, mats: Array) -> void:
	var m := _card(null, wall.darkened(0.12), Vector2.ONE)
	mats.append(m)
	_mesh(_box(Vector3(w + 0.4, 0.3, d + 0.4)), m, Vector3(0, hgt + 0.15, 0), root)
	for i in 5:
		for s in [-1.0, 1.0]:
			_mesh(_box(Vector3(0.45, 0.55, 0.45)), m, Vector3(-w * 0.5 + w * i / 4.0, hgt + 0.55, s * (d * 0.5)), root)
	var flag := _billboard(Bake.make(bake_root, "item", {"good": "blade"}, Vector2i(96, 96)), 0.8, Vector3.ZERO, root)
	flag.position = Vector3(0, hgt + 1.0, 0)


## A cut-out that always turns to face the camera around Y.
func _billboard(tex: Texture2D, world_h: float, at: Vector3, parent: Node = null) -> Sprite3D:
	var s := Standee.make_sprite(tex, world_h / float(tex.get_height()))
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.position = at
	(parent if parent != null else self).add_child(s)
	return s


func _prop(tex: Texture2D, world_h: float, at: Vector3, rot_y: float) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = rot_y
	add_child(n)
	var px := world_h / float(tex.get_height())
	var back := Standee.make_sprite(tex, px)
	back.modulate = Standee.EDGE
	back.position = Vector3(0.03, -0.01, -0.04)
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(back)
	n.add_child(Standee.make_sprite(tex, px))
	return n


func _build_fence(tn: Dictionary) -> void:
	var tex := Bake.make(bake_root, "fence", {}, Vector2i(256, 128))
	var o := Vector2(tn["origin"])
	for f in tn["layout"]["fence"]:
		var p: Vector2 = (o + (f["p"] as Vector2)) * TILE
		_prop(tex, 0.95 if tn["layout"]["shape"] != "ring" else 1.9, _to3(p), float(f["rot"]))


func _build_town_props(tn: Dictionary) -> void:
	var o := Vector2(tn["origin"])
	var L: Dictionary = tn["layout"]
	var lamp_tex := Bake.make(bake_root, "lamp", {}, Vector2i(96, 320))
	var crate := Bake.make(bake_root, "crate", {}, Vector2i(128, 128))
	var barrel := Bake.make(bake_root, "barrel", {}, Vector2i(128, 160))
	var flowers := Bake.make(bake_root, "flowers", {"cute": cute}, Vector2i(160, 120))
	var lamp_n := 0
	for lp in L["lamps"]:
		lamp_n += 1
		if Game.low_end and lamp_n % 2 == 0:
			continue
		var p := (o + (lp as Vector2)) * TILE
		if astar.is_point_solid(_tile(p)):
			continue
		_billboard(lamp_tex, 2.6, _to3(p))
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.45)
		l.omni_range = 5.0
		l.light_energy = 0.0
		l.position = _to3(p) + Vector3(0, 2.4, 0)
		add_child(l)
		lamps.append(l)
	for b in buildings:
		if not b["shop"] or b["city"] != tn["id"]:
			continue
		var r: Rect2 = b["rect"]
		_billboard(crate if rng.randf() < 0.5 else barrel, 0.7, _to3(Vector2(r.position.x + 12.0, r.end.y + 8.0)))
		_billboard(flowers, 0.6, _to3(Vector2(r.end.x - 14.0, r.end.y + 6.0)))
	if tn["id"] == "sunny":
		board_pos = (o + (L["board"] as Vector2)) * TILE
		_billboard(Bake.make(bake_root, "board", {}, Vector2i(256, 280)), 2.0, _to3(board_pos))
		_board_arrow(_to3(board_pos) + Vector3(0, 4.6, 0))
	var well := (o + (L["well"] as Vector2)) * TILE
	_billboard(Bake.make(bake_root, "well", {}, Vector2i(220, 256)), 1.9, _to3(well))
	_build_legend(tn)
	_build_bridges(tn)


## The local legend of a town: a landmark prop with a small name over it.
func _build_legend(tn: Dictionary) -> void:
	var td := TownGen.town_data(tn["id"])
	var lg: Dictionary = td.get("legend", {})
	if lg.is_empty():
		return
	var o := Vector2(tn["origin"])
	var at := (o + (tn["layout"]["legend_pos"] as Vector2)) * TILE
	tn["legend_px"] = at
	var kind := String(lg.get("prop", "pillar"))
	var tex: Texture2D
	var hgt := 3.4
	match kind:
		"arch":
			tex = Bake.make(bake_root, "arch", {}, Vector2i(320, 300))
			hgt = 4.6
		"deadtree":
			tex = Bake.make(bake_root, "deadtree", {}, Vector2i(180, 280))
			hgt = 5.2
		_:
			tex = Bake.make(bake_root, "pillar", {}, Vector2i(96, 288))
			hgt = 3.8
	_billboard(tex, hgt, _to3(at))
	var lab := Label3D.new()
	lab.text = String(lg["title"])
	lab.font = font
	lab.font_size = 48
	lab.pixel_size = 0.0075
	lab.outline_size = 12
	lab.modulate = Color(0.20, 0.13, 0.08)
	lab.outline_modulate = Color(0.96, 0.88, 0.70)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position = _to3(at) + Vector3(0, hgt + 0.45, 0)
	add_child(lab)


## Plank bridges where a road crosses a town river.
func _build_bridges(tn: Dictionary) -> void:
	var L: Dictionary = tn["layout"]
	if L["bridges"].is_empty():
		return
	var o := Vector2(tn["origin"])
	var span := (float(L["river_w"]) + 2.6) * 1.5
	for br in L["bridges"]:
		var cen: Vector2 = (o + (br["pos"] as Vector2)) * 1.5
		var d: Vector2 = br["dir"]
		var yaw := atan2(-d.y, d.x)
		var root := Node3D.new()
		root.position = Vector3(cen.x, 0.0, cen.y)
		root.rotation.y = yaw
		add_child(root)
		var plank := _card(null, Color(0.74, 0.56, 0.36), Vector2.ONE)
		var rail := _card(null, Color(0.50, 0.36, 0.22), Vector2.ONE)
		_mesh(_box(Vector3(span, 0.16, 1.7)), plank, Vector3(0, 0.1, 0), root)
		for sgn in [-1.0, 1.0]:
			_mesh(_box(Vector3(span, 0.12, 0.1)), rail, Vector3(0, 0.62, sgn * 0.85), root)
			for k in 6:
				_mesh(_box(Vector3(0.12, 0.6, 0.12)), rail, Vector3(-span * 0.5 + 0.2 + k * (span - 0.4) / 5.0, 0.38, sgn * 0.85), root)


## A bobbing gold arrow over a quest board. It draws through walls, so the
## board can be found from anywhere in town even when buildings are in the way.
func _board_arrow(at: Vector3) -> void:
	var l := Label3D.new()
	l.text = "QUESTS
▼"
	l.font = font
	l.font_size = 64
	l.outline_size = 22
	l.modulate = Color(1.0, 0.82, 0.25)
	l.outline_modulate = Color(0.17, 0.11, 0.07)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0007
	l.render_priority = 5
	l.position = at
	add_child(l)
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "position:y", at.y + 0.5, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "position:y", at.y, 0.7).set_trans(Tween.TRANS_SINE)


func _build_landmarks() -> void:
	_apply_world_solids()
	var paper := Cardboard.paper()
	for l in world.landmarks:
		var c: Vector2 = l["pos"]
		var c3 := _to3(c)
		match String(l["id"]):
			"farm":
				var tower := _mesh(CylinderMesh.new(), _card(null, Color(0.97, 0.94, 0.88), Vector2.ONE), c3 + Vector3(-3, 3.0, -3), self)
				(tower.mesh as CylinderMesh).top_radius = 1.0
				(tower.mesh as CylinderMesh).bottom_radius = 1.5
				(tower.mesh as CylinderMesh).height = 6.0
				var cone := CylinderMesh.new()
				cone.top_radius = 0.05
				cone.bottom_radius = 1.4
				cone.height = 1.6
				_mesh(cone, _card(null, Color(0.80, 0.36, 0.30), Vector2.ONE), c3 + Vector3(-3, 6.8, -3), self)
				var sails := Standee.make_sprite(Bake.make(bake_root, "sails", {}, Vector2i(320, 320)), 7.0 / 320.0)
				sails.offset = Vector2.ZERO
				sails.position = c3 + Vector3(-3, 5.4, -1.4)
				add_child(sails)
				var tw := sails.create_tween().set_loops()
				tw.tween_property(sails, "rotation:z", -TAU, 9.0).from(0.0)
				# the tower is a solid thing: block the tiles under it
				var tc := c + Vector2(-96.0, -96.0)
				for tx in range(-2, 3):
					for ty in range(-2, 3):
						var tp := tc + Vector2(tx, ty) * TILE * 0.5
						if tp.distance_to(tc) < 62.0:
							astar.set_point_solid(_tile(tp), true)
				for i in 7:
					_add_gather("wheat", c + Vector2(rng.randf_range(-170, 170), rng.randf_range(-40, 150)))
			"mine":
				var mouth := _prop(Bake.make(bake_root, "mine", {}, Vector2i(320, 280)), 5.0, c3 + Vector3(0, -0.1, -2.5), 0.0)
				mouth.scale = Vector3(1.3, 1.3, 1.3)
				for i in 6:
					_add_gather("ore", c + Vector2(rng.randf_range(-170, 170), rng.randf_range(-20, 140)))
				_billboard(Bake.make(bake_root, "crate", {}, Vector2i(128, 128)), 0.8, c3 + Vector3(2.5, 0, -0.8))
				Fx.campfire(self, c3 + Vector3(-3, 0, 1.5))
			"lake":
				var spot: Vector2 = l.get("spot", c)
				var into := (c - spot).normalized()
				for i in 7:
					var plank := _mesh(_box(Vector3(1.5, 0.15, 1.0)), _card(paper, Paint.WOOD, Vector2.ONE), Vector3.ZERO, self)
					plank.position = _to3(spot + into * (40.0 + i * 32.0))
					plank.position.y = maxf(plank.position.y, World.WATER + 0.15)
					plank.rotation.y = -into.angle() + PI * 0.5
				for i in 5:
					var a := rng.randf() * TAU
					_add_gather("herb", c + Vector2(cos(a), sin(a)) * rng.randf_range(430, 560))
			"wood":
				for i in 6:
					_add_gather("herb", c + Vector2(rng.randf_range(-260, 260), rng.randf_range(-260, 260)))
				Fx.campfire(self, c3)
				for i in 4:
					var a2 := TAU * i / 4.0 + 0.4
					_billboard(Bake.make(bake_root, "stump", {}, Vector2i(128, 96)), 0.6, _to3(c + Vector2(cos(a2), sin(a2)) * 70.0))
			"ruins":
				var ptex := Bake.make(bake_root, "pillar", {}, Vector2i(96, 288))
				var btex := Bake.make(bake_root, "pillar", {"broken": true}, Vector2i(96, 288))
				for i in 8:
					var a3 := TAU * i / 8.0
					_billboard(btex if i % 3 == 0 else ptex, 4.2 if i % 3 != 0 else 3.0, _to3(c + Vector2(cos(a3), sin(a3)) * 260.0))
				_billboard(Bake.make(bake_root, "arch", {}, Vector2i(320, 300)), 5.5, _to3(c + Vector2(0, -300)))
			"lookout":
				var top := _to3(c)
				for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
					_mesh(_box(Vector3(0.22, 5.0, 0.22)), _card(paper, Paint.WOOD, Vector2.ONE), top + Vector3(s.x * 1.1, 2.5, s.y * 1.1), self)
				_mesh(_box(Vector3(3.0, 0.25, 3.0)), _card(paper, Paint.WOOD.lightened(0.1), Vector2.ONE), top + Vector3(0, 5.0, 0), self)
				var cone2 := CylinderMesh.new()
				cone2.top_radius = 0.05
				cone2.bottom_radius = 2.2
				cone2.height = 1.4
				_mesh(cone2, _card(null, Color(0.86, 0.32, 0.30), Vector2.ONE), top + Vector3(0, 6.6, 0), self)


func _add_gather(good: String, p: Vector2) -> void:
	p = _free_spot_near(p)
	if not tex_cache.has("node_" + good):
		tex_cache["node_" + good] = Bake.make(bake_root, "node", {"good": good}, Vector2i(160, 200))
	var s := _billboard(tex_cache["node_" + good], 1.1 if good == "wheat" else 0.85, _to3(p))
	gathers.append({"pos": p, "good": good, "node": s, "ready": true, "t": 0.0})


func _build_clouds() -> void:
	var cloud_tex := Bake.make(bake_root, "cloud", {}, Vector2i(256, 150))
	for i in (6 if Game.low_end else 14):
		var cl := Standee.make_sprite(cloud_tex, rng.randf_range(0.05, 0.09))
		cl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cl.shaded = false
		cl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cl.position = Vector3(rng.randf_range(-150, 170), rng.randf_range(32, 48), rng.randf_range(-150, 160))
		add_child(cl)
		clouds.append(cl)


## The hero's look from the character screen (a default hero until it is made).
## The character creator's live figure: a real standee in its own little world,
## so what you pick is exactly what you will play. Returns the standee.
func preview_standee(h: Dictionary, parent: Node3D, want_cute: bool) -> Standee:
	var was := cute
	cute = want_cute
	var baked := _bake_person(hero_look(h), Vector2i(256, 320))
	var st := _make_standee(baked, 1.75 if want_cute else 2.3, "")
	cute = was
	remove_child(st)
	parent.add_child(st)
	st.show_hp = false
	if st.views.size() >= 2:
		st.set_view("front")
	return st


func hero_look(draft: Dictionary = {}) -> Dictionary:
	var h: Dictionary = draft if not draft.is_empty() else Game.hero
	var cloth: Color = HudMenus.HERO_CLOTHS[int(h["cloth"]) % HudMenus.HERO_CLOTHS.size()]
	var look := {"skin": HudMenus.HERO_SKINS[int(h["skin"]) % HudMenus.HERO_SKINS.size()], "hair": HudMenus.HERO_HAIRS[int(h["hair"]) % HudMenus.HERO_HAIRS.size()],
		"cloth": cloth, "pants": Color(0.26, 0.24, 0.26), "weapon": "axe", "eyes": "tall", "brows": "dash", "chin": 0.22}
	look["hat"] = str(Gear.HAIR[int(h.get("style", 0)) % Gear.HAIR.size()][1])
	var eq: Variant = h.get("equip", {})
	if eq is Dictionary:
		look.merge(Gear.look(eq), true)
	return look


## Called when the character creator finishes: new look, new stats.
func apply_hero(heal := true) -> void:
	var old := player_view
	player_view = _make_standee(_bake_person(hero_look(), Vector2i(256, 320)), 1.75 if cute else 2.3, String(Game.hero["name"]))
	player_view.show_hp = false
	if old != null:
		old.queue_free()
	career.apply_stats(self, heal)
	if net != null:
		net.send_look()


func _make_standee(baked: Dictionary, h: float, label: String) -> Standee:
	var s := Standee.new()
	add_child(s)
	s.setup(baked["tex"], baked["rig"], h, label, font)
	for v in ["front", "back"]:
		if baked.has(v):
			s.add_view(v, baked[v]["tex"], baked[v]["rig"])
	return s


## Seeded face and hair traits for a cute townsperson (see PaintCute.face).
func _vary_face(look: Dictionary) -> void:
	look["eyes"] = _pick_weighted({"dot": 4, "tall": 3, "lash": 2, "happy": 1.5, "sleepy": 1})
	look["brows"] = _pick_weighted({"none": 3, "dash": 3, "arch": 2, "bold": 1.5})
	look["cheeks"] = _pick_weighted({"blush": 4, "freckles": 1.5, "both": 1, "none": 1.5})
	look["glasses"] = rng.randf() < 0.14
	look["chin"] = rng.randf_range(0.14, 0.38)
	look["face_w"] = rng.randf_range(21.5, 23.5)
	look["ribbon"] = Color.from_hsv(rng.randf(), 0.55, 0.9)
	if rng.randf() < 0.18:
		look["hair"] = [Color(0.93, 0.55, 0.62), Color(0.42, 0.62, 0.80), Color(0.60, 0.48, 0.78),
			Color(0.38, 0.62, 0.50)][rng.randi() % 4]
	if look.get("hat", "short") in ["short", "long"]:
		var styles := {"short": 3, "spiky": 1.5, "bob": 1.5, "pony": 1.5, "bun": 1.2} if look.get("hat", "short") == "short" \
			else {"long": 3, "bob": 1.5, "pony": 2, "bun": 1.5}
		look["hat"] = _pick_weighted(styles)


func _pick_weighted(w: Dictionary) -> String:
	var total := 0.0
	for k in w:
		total += float(w[k])
	var r := rng.randf() * total
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return w.keys()[0]


## Cute people get three angles (side, front, back); realistic ones a side view.
func _bake_person(look: Dictionary, col := Vector2i(208, 260)) -> Dictionary:
	if not cute:
		return Bake.make_rig(bake_root, "person", look, Vector2i(256, 320))
	var d := Bake.make_rig(bake_root, "chibi", look, col)
	d["front"] = Bake.make_rig(bake_root, "chibi_front", look, col)
	d["back"] = Bake.make_rig(bake_root, "chibi_back", look, col)
	return d


## Picks the angle from where the figure is heading relative to the camera.
## The current angle is sticky (hysteresis) so it does not flicker at the
## boundary, and a figure that stands still turns to show its face.
func _pick_view(v: Standee, dir: Vector2, moving: bool, idle_front: bool) -> void:
	if v.views.size() < 2:
		return
	if moving and dir.length() > 0.01:
		var f := dir.normalized().dot(_cam_forward())
		var to := "side"
		if v.view == "back":
			to = "back" if f > 0.4 else ("front" if f < -0.65 else "side")
		elif v.view == "front":
			to = "front" if f < -0.4 else ("back" if f > 0.65 else "side")
		else:
			to = "back" if f > 0.65 else ("front" if f < -0.65 else "side")
		v.set_view(to)
	elif idle_front:
		v.set_view("front")


func _job_archetype(job_kind: String, tn: Dictionary) -> String:
	if job_kind == "guard":
		return Archetypes.CITY_GUARD.get(tn["folk"], "job_guard")
	if JOB_FOLK.has(job_kind):
		return JOB_FOLK[job_kind]
	return "job_" + job_kind


## Gives a town its people: one per workplace and a few without a job.
func _populate(tn: Dictionary) -> void:
	if tn.get("populated", false):
		return
	tn["populated"] = true
	var houses: Array = buildings.filter(func(b): return b["kind"] == "house" and b["city"] == tn["id"])
	if houses.size() < 4:
		# crowded towns put some people up above the shops
		for b2 in buildings:
			if b2["city"] == tn["id"] and b2["kind"] in ["inn", "bakery", "tavern", "market", "weaver", "lapidary"] and houses.size() < 4:
				houses.append(b2)
	var workplaces: Array = buildings.filter(func(b): return KINDS[b["kind"]]["job"] != "" and b["city"] == tn["id"])
	for w in workplaces:
		_spawn_npc(w, houses, tn)
	var extra := int(tn["population"])
	if Game.low_end:
		extra = int(ceil(extra * 0.5))
	for i in extra:
		_spawn_npc({}, houses, tn)


## Cities wake up when the player gets within a couple of screens of them.
func _wake_towns() -> void:
	for tn in towns:
		if not tn.get("populated", false) and Vector2(player["pos"]).distance_to(tn["start"]) < 2600.0:
			_populate(tn)
			founding_size = npcs.size()


func _spawn_npc(work: Dictionary, houses: Array, tn: Dictionary) -> void:
	var idx := _npc_seq
	_npc_seq += 1
	var home: Dictionary = houses[(idx + 3 * hash(tn["id"])) % houses.size()]
	var n := Npc.new()
	n.id = "npc_%d" % idx
	n.city = tn["id"]
	n.display_name = NAMES[idx % NAMES.size()]
	n.home_id = home["id"]
	n.pos = home["door"] + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(4.0, 20.0))
	n.wander_target = n.pos
	n.wake = rng.randf_range(5.5, 7.0)
	n.bed = rng.randf_range(20.0, 22.5)
	n.work_start = rng.randf_range(7.0, 8.5)
	n.work_end = rng.randf_range(16.0, 18.0)
	n.hunger = rng.randf_range(0.0, 45.0)
	var job_kind: String = work.get("kind", "")
	var look: Dictionary = (LOOKS[job_kind] if LOOKS.has(job_kind) else LOOKS[""]).duplicate()
	look["skin"] = SKINS[rng.randi() % SKINS.size()]
	look["hair"] = HAIRS[rng.randi() % HAIRS.size()]
	look["cloth"] = Color.from_hsv(rng.randf(), 0.45 if cute else 0.42, 0.88 if cute else 0.80)
	look["pants"] = Color.from_hsv(rng.randf(), 0.25, 0.40 if cute else 0.35)
	if not look.has("wide"):
		look["wide"] = rng.randf_range(0.88, 1.12)
	if job_kind == "" and rng.randf() < 0.5:
		look["hat"] = "long"
		look["dress"] = rng.randf() < 0.6
	if cute:
		# Dragon Quest style archetypes: a job look for workers, a mixed
		# townsfolk pool for everyone else (see scripts/archetypes.gd).
		var aid := _job_archetype(job_kind, tn) if job_kind != "" else Archetypes.pick_for_city(tn["folk"], rng)
		var arch := Archetypes.randomized(aid, rng, SKINS, HAIRS)
		for k in ["skin", "hair", "wide"]:
			if not arch.has(k):
				arch[k] = look[k]
		look = arch
	if not work.is_empty():
		n.job_id = work["id"]
		n.job_kind = job_kind
		n.job_title = KINDS[job_kind]["job"]
	elif not mayors.has(tn["id"]) and job_kind == "":
		mayors[tn["id"]] = n.id
		n.job_title = "Mayor"
		n.display_name = "Mayor " + n.display_name
	Economy.add_wallet(n.id, 30 if founding_size == 0 else 0)
	if job_kind == "guard":
		n.max_hp = 90.0
		n.hp = 90.0
	var tall := rng.randf_range(1.55, 1.75) if cute else rng.randf_range(2.15, 2.45)
	n.view = _make_standee(_bake_person(look), tall, n.display_name)
	n.set_meta("look", look)
	npcs.append(n)


## Flat monster art as a one-piece rig: the cardboard-ized sprite on a single joint.
func _sprite_rig(kind: String) -> Dictionary:
	var key := "spr_" + kind
	if not rig_cache.has(key):
		var t: Dictionary = Monster.TYPES[kind]
		var tex: Texture2D = load("res://assets/beasts/" + String(t["sprite"]))
		if tex == null:
			var img := Image.load_from_file("res://assets/beasts/" + String(t["sprite"]))
			tex = ImageTexture.create_from_image(img) if img != null else null
		var sz := tex.get_size() if tex != null else Vector2(64, 64)
		var rig := {"kind": "sprite", "col": sz, "flip": -1.0 if t.get("face", "front") == "left" else 1.0,
			"parts": [{"name": "body", "pivot": Vector2(sz.x * 0.5, sz.y), "z": 0}]}
		rig_cache[key] = {"tex": tex, "rig": rig}
	return rig_cache[key]


func _monster_tex(kind: String) -> Dictionary:
	if Monster.is_sprite(kind):
		return _sprite_rig(kind)
	var rk := Monster.rig_kind(kind, cute)
	if not rig_cache.has(rk):
		var sizes := {"wolf": Vector2i(320, 224), "troll": Vector2i(288, 352), "fluffox": Vector2i(320, 240),
			"pebblet": Vector2i(288, 320), "slime": Vector2i(224, 200), "shroom": Vector2i(224, 288),
			"bat": Vector2i(320, 224), "boss": Vector2i(384, 448)}
		rig_cache[rk] = Bake.make_rig(bake_root, rk, {"cute": cute}, sizes[rk])
	return rig_cache[rk]


func _add_monster(kind: String, p: Vector2, tier := 0) -> Monster:
	var m := Monster.new()
	m.setup(kind, cute, tier)
	m.hp *= story.monster_mult()
	m.max_hp = m.hp
	m.pos = p
	m.home = p
	m.view = _make_standee(_monster_tex(kind), Monster.height_of(kind, cute) * m.size_mult(), m.display_name)
	m.view.charges = m.ranged > 0.0 or m.pounce_range > 0.0
	m.view.base_tint = Monster.TIER_TINT[m.tier] if not Monster.is_big(kind) else Color(1, 1, 1)
	if m.tier >= 2 and not Monster.is_big(kind):
		Fx.aura(m.view, Color(1.0, 0.25, 0.2), 0.8)
	m.view.position = _to3(p)
	m.view.scale = Vector3(1, 0.05, 1)
	Fx.puff(self, _to3(p), 1.3)
	var tw := m.view.create_tween()
	tw.tween_property(m.view, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	monsters.append(m)
	return m


func _nearest_landmark(p: Vector2) -> Array:
	var best := ""
	var bd := INF
	for l in world.landmarks:
		var d: float = p.distance_to(l["pos"])
		if d < bd:
			bd = d
			best = l["id"]
	return [best, bd]


## How dangerous the wilds are at p: 0 near town, 1 further out, 2 in the
## truly deadly places (the ruins, the mine, anywhere very far from home).
## Night makes everything one step worse.
func danger_tier_at(p: Vector2) -> int:
	var far := INF
	for tn in towns:
		far = minf(far, p.distance_to(tn["start"]))
	var t := 0
	if far > 1500.0:
		t = 1
	if far > 2600.0:
		t = 2
	var nl := _nearest_landmark(p)
	var id: String = nl[0]
	var bd: float = nl[1]
	if bd < 700.0:
		match id:
			"ruins", "mine":
				t = 2
			"wood", "lookout":
				t = maxi(t, 1)
	if (hour > 20.0 or hour < 5.0) and t < 2 and rng.randf() < 0.5:
		t += 1
	return t


func _region_kinds(p: Vector2, tier := 0) -> Array:
	var nl := _nearest_landmark(p)
	var best: String = nl[0]
	var bd: float = nl[1]
	var night := hour > 20.0 or hour < 5.0
	var kinds: Array = ["slime", "wolf"]
	if bd < 1100.0:
		match best:
			"wood":
				kinds = ["wolf", "shroom", "shroom", "slime"]
			"lake":
				kinds = ["slime", "slime", "shroom"]
			"mine":
				kinds = ["troll", "bat", "bat"]
			"ruins":
				kinds = ["troll", "bat", "shroom"]
			"lookout":
				kinds = ["wolf", "bat"]
	if tier >= 1:
		# the meek ones stay near town; the wilds breed hunters
		kinds = kinds.filter(func(k): return k != "slime" or tier == 1)
		kinds.append("wolf")
	if tier >= 2:
		kinds.append("troll")
		kinds.append("bat")
	# sprite beasts join the mix near their home landmark
	if bd < 1100.0:
		for k in Monster.TYPES:
			var t: Dictionary = Monster.TYPES[k]
			if t.has("regions") and not t.get("boss", false) and best in t["regions"] and int(t.get("min_tier", 0)) <= tier:
				kinds.append(k)
				kinds.append(k)
	if night:
		kinds.append("bat")
	return kinds


func _spawn_monster_near(initial: bool = false) -> void:
	var center: Vector2 = player["pos"]
	for attempt in 30:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(420.0, 1500.0) if initial else rng.randf_range(1100.0, 1800.0)
		var p := center + Vector2(cos(a), sin(a)) * dist
		if in_defense_zone(p) or _blocked(p, 12.0):
			continue
		var tier := danger_tier_at(p)
		var kinds := _region_kinds(p, tier)
		var kind: String = kinds[rng.randi() % kinds.size()]
		var lead := _add_monster(kind, p, tier)
		# wolves hunt in packs, deeper in the wilds the packs are bigger
		if kind == "wolf" and tier >= 1:
			for i in (1 if tier == 1 else 2):
				var q := _free_spot_near(p + Vector2(rng.randf_range(-60, 60), rng.randf_range(-60, 60)))
				var w := _add_monster("wolf", q, tier)
				w.home = lead.home
				lead.pack.append(w)
		return


## The deadly places are never empty: the mine and the ruins start with Dire
## beasts waiting, and the deep wood with a Fierce pack.
func _seed_danger_zones() -> void:
	var plan := {"mine": [["troll", 2], ["bat", 2], ["bat", 2]],
		"ruins": [["troll", 2], ["wolf", 2], ["wolf", 2], ["bat", 2]],
		"wood": [["wolf", 1], ["wolf", 1], ["shroom", 1]]}
	for id in plan:
		var c: Vector2 = world.landmark(id)["pos"]
		for e in plan[id]:
			var p := _free_spot_near(c + Vector2(rng.randf_range(-260, 260), rng.randf_range(-260, 260)))
			_add_monster(e[0], p, e[1])


## A rare dragon settles in one of the wild places: a single big fight, announced.
func _spawn_dragon() -> void:
	for m in monsters:
		if Monster.is_big(m.kind) and m.kind != "boss":
			return
	var kinds: Array = []
	for k in Monster.TYPES:
		if Monster.TYPES[k].get("rare", false):
			kinds.append(k)
	var kind: String = kinds[rng.randi() % kinds.size()]
	var lm: String = String(Monster.TYPES[kind]["regions"][0])
	if world.landmark(lm).is_empty():
		return
	var c: Vector2 = world.landmark(lm)["pos"]
	var m := _add_monster(kind, _free_spot_near(c + Vector2(rng.randf_range(-200, 200), rng.randf_range(-200, 200))))
	m.aggro = float(Monster.TYPES[kind]["aggro"])
	hud.banner("A dragon stirs", "%s near %s" % [m.display_name, String(world.landmark(lm).get("name", lm))])
	Economy.message.emit("A %s has been seen near %s. Only the bold (and level 5 or more) should go." % [m.display_name, String(world.landmark(lm).get("name", lm))])


# ---------------- shared raid (needs the world server) ----------------

var raid_mon: Monster
var raid_id := 0
var raid_dealt := 0.0
var _raid_mark := 1.0


## One message from the world server: start / hp / end of the raid dragon.
func raid_update(m: Dictionary) -> void:
	var state := str(m.get("state", ""))
	var mx := float(m.get("max", 1.0))
	var hp := float(m.get("hp", 0.0))
	if state == "start":
		if raid_mon != null and monsters.has(raid_mon):
			return
		var kind := str(m.get("kind", "dragon_red"))
		if not Monster.TYPES.has(kind):
			return
		var lm: String = String(Monster.TYPES[kind]["regions"][0])
		if world.landmark(lm).is_empty():
			return
		var c: Vector2 = world.landmark(lm)["pos"]
		raid_mon = _add_monster(kind, _free_spot_near(c))
		raid_mon.raid = true
		raid_mon.aggro = 520.0
		raid_mon.max_hp = mx
		raid_mon.hp = hp
		raid_id = int(m.get("id", 0))
		raid_dealt = 0.0
		_raid_mark = 1.0
		var nm := String(world.landmark(lm).get("name", lm))
		hud.banner("RAID: %s" % raid_mon.display_name, "Near %s. Everyone's hits count. %d seconds." % [nm, int(m.get("left", 0))])
		Economy.message.emit("RAID! A %s is attacking near %s. Everyone online can fight it, and the damage adds up." % [raid_mon.display_name, nm])
	elif state == "hp":
		if raid_mon != null and monsters.has(raid_mon):
			raid_mon.max_hp = mx
			raid_mon.hp = maxf(hp, 1.0)
			var f := hp / maxf(mx, 1.0)
			while f < _raid_mark - 0.25 and _raid_mark > 0.3:
				_raid_mark -= 0.25
				Economy.message.emit("The raid dragon is down to %d%%." % int(_raid_mark * 100))
	elif state == "end":
		var won := bool(m.get("won", false))
		var top: Array = m.get("top", [])
		var lines := ""
		for e in top:
			lines += "%s %d  " % [str(e[0]), int(e[1])]
		if raid_mon != null and monsters.has(raid_mon):
			if won:
				raid_mon.killer_id = "player" if raid_dealt > 0.0 else "raid"
				raid_mon.raid = false
				raid_mon.hp = 0.0
			else:
				monsters.erase(raid_mon)
				if is_instance_valid(raid_mon.telegraph):
					raid_mon.telegraph.queue_free()
				raid_mon.view.queue_free()
		raid_mon = null
		if won:
			hud.banner("RAID WON", "The dragon is down. You dealt %d." % int(raid_dealt))
			Economy.message.emit("The raid is won. Top damage: %s" % lines)
		else:
			hud.banner("The dragon got away", "Not enough damage in time.")
			Economy.message.emit("The raid dragon flew off. Top damage: %s" % lines)


func _spawn_boss() -> void:
	var c: Vector2 = world.landmark("ruins")["pos"]
	var m := _add_monster("boss", _free_spot_near(c))
	m.aggro = 300.0


func _free_spot_near(p: Vector2) -> Vector2:
	for r in range(0, 800, 24):
		for k in 12:
			var a := TAU * k / 12.0
			var q := p + Vector2(cos(a), sin(a)) * r
			if not _blocked(q, 14.0):
				return q
	return p


func _star_tex() -> Texture2D:
	if not tex_cache.has("star"):
		tex_cache["star"] = Bake.make(bake_root, "star", {}, Vector2i(128, 128))
	return tex_cache["star"]


# ---------------- world queries used by Npc / Monster / Quests / Hud ----------------

func _to3(p: Vector2) -> Vector3:
	return world.to3(p)


func _tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func _in_town_zone(p: Vector2) -> bool:
	return town_at(p, 2.0) != ""


func day_number() -> int:
	return 1 + int((clock + DAY_SECONDS * 0.25) / DAY_SECONDS)


func building(id: String) -> Dictionary:
	for b in buildings:
		if b["id"] == id:
			return b
	return {}


func door_of(id: String) -> Vector2:
	var b := building(id)
	if b.is_empty():
		var n := npc_by_id(id)
		if n == null:
			for m in npcs:
				if m is Merchant and m.cart_id == id:
					return m.pos
		return n.pos if n != null else start_pos
	return b["door"]


func random_road_point(city := "sunny") -> Vector2:
	var tn := town_by_id(city)
	var o := Vector2(tn.get("origin", Vector2i.ZERO))
	var pts: Array = tn["layout"]["points"] if tn.has("layout") else []
	if pts.is_empty():
		return start_pos
	return (o + (pts[rng.randi() % pts.size()] as Vector2)) * TILE


## Where an NPC's errand takes them: doorways to sweep, the edge of town for
## herbs and game (and back home), or the mayor's round of board, well and shops.
func errand_points(n: Npc, kind: String) -> Array:
	var out: Array = []
	var doors: Array = []
	for b in buildings:
		if b["city"] == n.city:
			doors.append(b["door"])
	match kind:
		"clean":
			doors.shuffle()
			for i in mini(3, doors.size()):
				out.append(doors[i] + Vector2(-20.0, 10.0))
		"herbs", "hunt":
			var tn := town_by_id(n.city)
			var o := Vector2(tn.get("origin", Vector2i.ZERO))
			var best := Vector2.INF
			var bd := -1.0
			for k in 4:
				var pt := random_road_point(n.city)
				var d := pt.distance_to(Vector2(tn["layout"]["center"] + o) * TILE) if tn.has("layout") and tn["layout"].has("center") else pt.distance_to(n.pos)
				if d > bd:
					bd = d
					best = pt
			out.append(best)
			out.append(door_of(n.home_id))
		"mayor":
			if board_pos != Vector2.ZERO:
				out.append(board_pos + Vector2(0, 50))
			doors.shuffle()
			for i in mini(2, doors.size()):
				out.append(doors[i] + Vector2(-20.0, 10.0))
	return out


func find_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ta := _tile(a)
	var tb := _tile(b)
	if not astar.is_in_boundsv(ta) or not astar.is_in_boundsv(tb):
		return PackedVector2Array()
	return astar.get_point_path(ta, tb, true)


func try_move(p: Vector2, v: Vector2, radius: float) -> Vector2:
	var np := p
	var tx := Vector2(p.x + v.x, p.y)
	if not _blocked(tx, radius):
		np.x = tx.x
	var ty := Vector2(np.x, p.y + v.y)
	if not _blocked(ty, radius):
		np.y = ty.y
	return np


func _blocked(p: Vector2, r: float) -> bool:
	for off in [Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r)]:
		var t := _tile(p + off)
		if not astar.is_in_boundsv(t) or astar.is_point_solid(t):
			return true
	return false


## The closest shop with `good` in stock. Standing inside a town, only that
## town's shops count (a long walk to the next city for lunch is not on).
func nearest_shop_with(p: Vector2, good: String) -> String:
	var here := town_at(p, 3.0)
	var best := ""
	var bd := INF
	for b in buildings:
		if not Economy.shops.has(b["id"]):
			continue
		if here != "" and b["city"] != here:
			continue
		var s: Dictionary = Economy.shops[b["id"]]
		if int(s["stock"].get(good, 0)) <= 0:
			continue
		var d: float = p.distance_to(b["door"])
		if d < bd:
			bd = d
			best = b["id"]
	return best


## Relief: a hungry person with no money gets the price of a meal from the city
## treasury (a real transfer, so coins stay conserved). Returns true if they can now buy.
func food_relief(n: Npc, shop: String, good: String) -> bool:
	var tre := _guard_post_id(n.city)
	if tre == "player" or not Economy.wallets.has(tre):
		return false
	var price := Economy.buy_price(shop, good)
	if int(Economy.wallets[tre]["coins"]) < price + 5:
		return false
	return Economy.pay(tre, n.id, price)


func nearest_food(p: Vector2) -> Array:
	var best: Array = []
	var bd := INF
	for good in ["bread", "meat"]:
		var id := nearest_shop_with(p, good)
		if id == "":
			continue
		var d := p.distance_to(door_of(id))
		if d < bd:
			bd = d
			best = [id, good]
	return best


func shop_with(good: String, city := "sunny") -> String:
	for b in buildings:
		if b["city"] == city and Economy.shops.has(b["id"]) and int(Economy.shops[b["id"]]["stock"].get(good, 0)) > 0:
			if KINDS[b["kind"]]["recipe"].get("out", {}).has(good):
				return b["id"]
	return nearest_shop_with(Vector2(town_by_id(city).get("start", Vector2.ZERO)), good)


func richest_employer(city := "sunny") -> String:
	var best := ""
	var most := 60
	for id in Economy.shops:
		if Economy.shops[id]["city"] != city or Economy.shops[id]["kind"] == "":
			continue
		var c := int(Economy.wallets[id]["coins"])
		if c > most:
			most = c
			best = id
	return best


func in_defense_zone(p: Vector2) -> bool:
	return town_at(p, 5.0) != ""


func walkable(p: Vector2) -> bool:
	var t := _tile(p)
	return astar.is_in_boundsv(t) and not astar.is_point_solid(t)


func _shop_of_kind(kind: String, city := "sunny") -> String:
	for b in buildings:
		if b["kind"] == kind and b["city"] == city and Economy.shops.has(b["id"]):
			return b["id"]
	return ""


func player_safe() -> bool:
	return not Game.started or dialog_npc != null or bool(player.get("down", false))


func monster_name(kind: String, plural: bool) -> String:
	var n := Monster.name_of(kind, cute)
	return n + "s" if plural and not n.ends_with("King") else n


func nearest_monster_of(kind: String, p: Vector2, r: float) -> Monster:
	var best: Monster = null
	var bd := r
	for m in monsters:
		if m.kind != kind:
			continue
		var d: float = p.distance_to(m.pos)
		if d < bd:
			bd = d
			best = m
	return best


## Shops top up from their neighbours: a shop whose recipe needs an input buys
## it from a city shop that has spare; general stores stock what makers make.
func _restock() -> void:
	for tn in towns:
		var mine: Array = Economy.shops.keys().filter(func(id): return Economy.shops[id]["city"] == tn["id"] and Economy.shops[id]["kind"] != "")
		for sid in mine:
			var s: Dictionary = Economy.shops[sid]
			var ins: Dictionary = s["recipe"].get("in", {})
			for good in ins:
				_pull(sid, mine, good, int(ins[good]) * 2)
			if s["kind"] in ["market", "caravanserai"]:
				for oid in mine:
					if oid == sid:
						continue
					for good in Economy.shops[oid]["recipe"].get("out", {}):
						_pull(sid, [oid], good, 3, 4)
	Economy.changed.emit()


## Moves up to 3 units of `good` into shop `buyer` from the first shop in
## `from_ids` holding more than `keep` of it, until the buyer has `want`.
func _pull(buyer: String, from_ids: Array, good: String, want: int, keep := 1) -> void:
	var tries := 0
	while int(Economy.shops[buyer]["stock"].get(good, 0)) < want and tries < 3:
		tries += 1
		var moved := false
		for sid in from_ids:
			if sid == buyer or int(Economy.shops[sid]["stock"].get(good, 0)) <= keep:
				continue
			if Economy.b2b(sid, buyer, good):
				moved = true
				break
		if not moved:
			return


func _newcomer() -> void:
	var here := npcs.filter(func(n): return n.city == "sunny").size()
	if here >= founding_main:
		return
	var treasury := _guard_post_id()
	var tn := town_by_id("sunny")
	var houses: Array = buildings.filter(func(b): return b["kind"] == "house" and b["city"] == "sunny")
	_spawn_npc({}, houses, tn)
	var n: Npc = npcs[npcs.size() - 1]
	n.pos = (Vector2(tn["origin"]) + (tn["layout"]["gates"]["s2"] as Vector2)) * TILE + Vector2(0, -40)
	Economy.pay(treasury, n.id, mini(20, int(Economy.wallets[treasury]["coins"])))
	n.say("Hello. I hear there is work here.")
	Economy.message.emit("%s arrived at the south gate looking for work." % n.display_name)


func nearest_monster(p: Vector2, r: float) -> Monster:
	var best: Monster = null
	var bd := r
	for m in monsters:
		var d: float = p.distance_to(m.pos)
		if d < bd:
			bd = d
			best = m
	return best


func nearest_npc(p: Vector2, r: float) -> Npc:
	var best: Npc = null
	var bd := r
	for n in npcs:
		if n.inside:
			continue
		var d: float = p.distance_to(n.pos)
		if d < bd:
			bd = d
			best = n
	return best


func npc_by_id(id: String) -> Npc:
	for n in npcs:
		if n.id == id:
			return n
	return null


# ---------------- combat ----------------

func npc_strike(n: Npc, m: Monster, dmg: float) -> void:
	n.view.lunge()
	Fx.slash(self, _to3(n.pos) + Vector3(0, 1.0, 0), (m.pos - n.pos).dot(_cam_right()) < 0.0)
	_damage_monster(m, dmg, n.id, n.pos)


func monster_strike(m: Monster) -> void:
	m.view.lunge()
	var tp := _to3(m.pos)
	if m.target_is_player:
		tp = _to3(player["pos"]) + Vector3(0, 1.0, 0)
	var flip := (Vector2(player["pos"]) - m.pos).dot(_cam_right()) < 0.0
	match m.kind:
		"wolf", "bat":
			if m.tier >= 1:
				Fx.claw(self, tp, flip, Color(1.0, 0.3, 0.25))
			else:
				Fx.chomp(self, tp)
		"troll":
			Fx.slam(self, _to3(m.pos + m.heading * 46.0), 2.0 + m.tier * 0.4)
			shake = maxf(shake, 0.4)
			sfx("boom")
		"boss":
			Fx.slam(self, _to3(m.pos), 4.2, Color(0.6, 0.9, 0.4))
			Fx.ring(self, _to3(m.pos), Color(0.6, 0.9, 0.4), 5.0)
			shake = maxf(shake, 0.6)
			sfx("boom")
		"dragon_red", "dragon_blue", "dragon_green":
			var dc: Color = Monster.BEAM_COL.get(m.kind, Color(1, 0.6, 0.3))
			Fx.slam(self, _to3(m.pos), 4.0, dc)
			Fx.ring(self, _to3(m.pos), dc, 5.0)
			shake = maxf(shake, 0.6)
			sfx("boom")
		"shroom":
			Fx.spores(self, _to3(m.pos), 1.8)
		_:
			Fx.impact(self, tp, Color(0.7, 1.0, 0.6), 0.8)
	if m.target_is_player:
		if m.pos.distance_to(player["pos"]) <= m.reach * 1.4:
			player["hurt_by"] = m.display_name
			hurt_player(m.dmg, m.pos)
	elif m.target_npc != null and npcs.has(m.target_npc) and not m.target_npc.inside:
		if m.pos.distance_to(m.target_npc.pos) <= m.reach * 1.4:
			hurt_npc(m.target_npc, m.dmg, m.pos)


## A ranged monster starts charging: show the warning strip on the ground.
func monster_charge(m: Monster) -> void:
	var col: Color = Monster.BEAM_COL.get(m.kind, Color(1, 0.8, 0.3))
	var a := _to3(m.pos)
	var dir := (m.aim - m.pos).normalized()
	var b := _to3(m.pos + dir * m.ranged)
	m.telegraph = Fx.telegraph(self, a, b, col, 0.6 if m.kind == "bat" else 1.2)
	var h0 := float(Monster.height_of(m.kind, cute)) * 0.55 + (0.9 if m.kind == "bat" else 0.0)
	Fx.charge_orb(m.telegraph, Vector3(0, h0, 0), col, m.windup)


## A beast crouches and shows where it is about to leap.
func monster_tell(m: Monster, from: Vector2, to: Vector2) -> void:
	var col := Color(1.0, 0.35, 0.25)
	m.telegraph = Fx.telegraph(self, _to3(from), _to3(to), col, 0.9, m.windup)
	m.view.lunge()
	sfx("hurt")
	if m.kind == "wolf" or m.kind == "bat":
		m.view.say("GRRR!" if m.kind == "wolf" else "SKREE!", 0.7, Color(1.0, 0.8, 0.75))


func monster_pounce(m: Monster) -> void:
	if is_instance_valid(m.telegraph):
		m.telegraph.queue_free()
	Fx.dash_trail(self, _to3(m.pos), _to3(m.pos + m.dash_dir * 200.0), Color(1.0, 0.6, 0.5))
	Fx.puff(self, _to3(m.pos), 0.8, Color(0.9, 0.85, 0.75))
	m.view.lunge()


func monster_beam(m: Monster) -> void:
	if is_instance_valid(m.telegraph):
		m.telegraph.queue_free()
	var col: Color = Monster.BEAM_COL.get(m.kind, Color(1, 0.8, 0.3))
	var dir := (m.aim - m.pos).normalized()
	var end := m.pos + dir * m.ranged
	var h0 := float(Monster.height_of(m.kind, cute)) * 0.55 + (0.9 if m.kind == "bat" else 0.0)
	Fx.beam(self, _to3(m.pos) + Vector3(0, h0, 0), _to3(end) + Vector3(0, 1.0, 0), col, 0.25 if m.kind == "bat" else 0.6)
	sfx("boom")
	m.view.lunge()
	var width := 40.0 if m.kind == "bat" else 62.0
	if _seg_dist(player["pos"], m.pos, end) < width:
		player["hurt_by"] = m.display_name
		hurt_player(m.dmg, m.pos)
	for n in npcs:
		if not n.inside and _seg_dist(n.pos, m.pos, end) < width:
			hurt_npc(n, m.dmg * 0.6, m.pos)


func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _damage_monster(m: Monster, dmg: float, killer: String, from: Vector2, step := 0, crit := false) -> void:
	m.hp -= dmg
	if m.raid:
		# the server decides when it dies; show the hit now, let the next sync correct it
		m.hp = maxf(m.hp, 1.0)
		if killer == "player":
			raid_dealt += dmg
			if net != null:
				net.raid_hit(dmg)
	m.killer_id = killer
	var away := (m.pos - from).normalized()
	m.knock = away * m.knock_power * (1.0 + step * 0.9)
	if killer == "player":
		# a hit can interrupt: heavier hits stagger longer, big beasts shrug it off
		var st := 0.16 + 0.17 * step
		if Monster.is_big(m.kind):
			st = 0.25 if step == 2 else 0.0
		elif m.tier >= 2:
			st *= 0.6
		if st > 0.0:
			m.stagger = maxf(m.stagger, st)
			m.windup = 0.0
			m.windup_kind = ""
			m.dash_t = 0.0
			if is_instance_valid(m.telegraph):
				m.telegraph.queue_free()
	m.view.flash()
	var at := _to3(m.pos) + Vector3(0, Monster.height_of(m.kind, cute) * m.size_mult() * 0.5, 0)
	var power := 1.0 + step * 0.5 + (0.4 if crit else 0.0)
	_pop_star(at)
	Fx.impact(self, at, Color(1, 0.92, 0.65) if not crit else Color(1.0, 0.8, 0.3), power)
	Fx.sparks(self, at, Color(1.0, 0.9, 0.6), 6 + step * 4, 4.0 + step)
	_pop_number(at, str(int(dmg)) + ("!" if crit else ""), Color(1.0, 0.86, 0.35) if not crit else Color(1.0, 0.55, 0.2))
	sfx("hit")
	if crit and killer == "player":
		hud.rip("crit", "CRITICAL!", "", Color(1.0, 0.55, 0.2))
	if killer == "player":
		shake = maxf(shake, 0.2 + 0.1 * step + (0.1 if crit else 0.0))
		fov_kick = maxf(fov_kick, 2.0 + 2.5 * step)
		_hitstop(0.04 + 0.025 * step + (0.03 if crit else 0.0))


func hurt_player(dmg: float, from: Vector2) -> void:
	if float(player["iframes"]) > 0.0 or float(player["grace"]) > 0.0:
		if float(player["iframes"]) > 0.0 and not player["perfected"]:
			_perfect_dodge()
		return
	dmg *= 1.0 - Gear.defence()
	player["grace"] = 0.55
	player["combo_hits"] = 0
	player["combo_t"] = 0.0
	fov_kick = maxf(fov_kick, 7.0)
	Fx.impact(self, _to3(player["pos"]) + Vector3(0, 1.0, 0), Color(1.0, 0.4, 0.35), 1.2)
	player["hp"] = float(player["hp"]) - dmg
	player["last_hurt"] = clock
	player["knock"] = (Vector2(player["pos"]) - from).normalized() * 320.0
	player_view.flash()
	_pop_number(_to3(player["pos"]) + Vector3(0, 1.4, 0), str(int(dmg)), Color(1.0, 0.35, 0.3))
	sfx("hurt")
	shake = maxf(shake, 0.55)
	_hitstop(0.07)
	if float(player["hp"]) <= 0.0:
		_knock_out()


## The "knocked out" scene: the screen tears, a card says what happened, what
## it cost and where you wake up. Nothing moves until you press Get up.
func _knock_out() -> void:
	if player.get("down", false):
		return
	player["down"] = true
	player["knock"] = Vector2.ZERO
	player["hp"] = 0.0
	var by := str(player.get("hurt_by", "something nasty"))
	var tn := _nearest_town_dict(player["pos"])
	var city: String = tn.get("id", "sunny")
	var lost := int(Economy.wallets["player"]["coins"]) / 2
	var tre := _guard_post_id(city)
	if lost <= 0 or tre == "player" or not Economy.pay("player", tre, lost):
		lost = 0
	var spawn: Vector2 = tn.get("start", start_pos)
	var info := {"by": by, "lost": lost, "town": String(Economy.city_def(city).get("name", "town"))}
	hud.rip("death", "KNOCKED OUT", "by %s" % by, Color(0.85, 0.3, 0.25))
	hud.show_death(info, func() -> void:
		hud.fade_through(func() -> void:
			player["pos"] = _free_spot_near(spawn)
			cam_focus = _to3(player["pos"])
			player["hp"] = player["max_hp"]
			player["stamina"] = player["max_stamina"]
			player["down"] = false
			player["grace"] = 2.0
			player["hurt_by"] = ""))
	Economy.message.emit("You were knocked out by %s. The guards of %s kept %d coins as a fee." % [by, info["town"], lost])


func _nearest_town_dict(p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for tn in towns:
		var d: float = p.distance_to(tn["start"])
		if d < bd:
			bd = d
			best = tn
	return best


func _perfect_dodge() -> void:
	player["perfected"] = true
	player["stamina"] = minf(float(player["max_stamina"]), float(player["stamina"]) + 25.0)
	player["ink"] = minf(float(player["max_ink"]), float(player["ink"]) + 30.0)
	var at := _to3(player["pos"])
	Fx.ring(self, at, Color(0.6, 0.9, 1.0), 2.4)
	Fx.sparks(self, at + Vector3(0, 1.0, 0), Color(0.7, 0.95, 1.0), 12, 5.0)
	_pop_number(at + Vector3(0, 1.8, 0), "Perfect!", Color(0.6, 0.95, 1.0))
	if shot_path == "":
		Engine.time_scale = 0.35
		get_tree().create_timer(0.35, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## A tiny freeze on solid hits so strikes feel heavy.
func _hitstop(secs: float) -> void:
	if shot_path != "":
		return
	Engine.time_scale = 0.06
	get_tree().create_timer(secs, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _guard_post_id(city := "sunny") -> String:
	if city == "":
		city = "sunny"
	for b in buildings:
		if b["kind"] == "guard" and b["city"] == city:
			return b["id"]
	return "player"


func hurt_npc(n: Npc, dmg: float, from: Vector2) -> void:
	n.hp -= dmg
	n.last_hurt_by = "attack"
	n.pos = try_move(n.pos, (n.pos - from).normalized() * 18.0, 8.0)
	n.view.flash()
	_pop_number(_to3(n.pos) + Vector3(0, 1.4, 0), str(int(dmg)), Color(1.0, 0.35, 0.3))
	if randf() < 0.5:
		n.say("Help!")


func _pop_number(at: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 72
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = col
	l.outline_size = 16
	l.outline_modulate = Color(0.15, 0.1, 0.05)
	at = Bend.at(at)
	l.position = at
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position", at + Vector3(randf_range(-0.3, 0.3), 1.0, 0), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.3)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.45).set_delay(0.3)
	tw.tween_callback(l.queue_free)


func _pop_star(at: Vector3) -> void:
	var s := Standee.make_sprite(_star_tex(), 0.006)
	s.offset = Vector2.ZERO
	s.shaded = false
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position = Bend.at(at)
	s.scale = Vector3.ONE * 0.3
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.18)
	tw.tween_callback(s.queue_free)


func player_trade(shop: String, good: String, buying: bool, qty: int = 1) -> int:
	var done := 0
	if career.refuses(self, shop):
		Economy.message.emit("The %s will not deal with you after what you did. Give it a day or two." % Economy.shops[shop]["name"])
		return 0
	for i in qty:
		var price: int = Economy.buy_price(shop, good) if buying else Economy.sell_price(shop, good)
		var ok: bool = Economy.buy(shop, good, "player") if buying else Economy.sell(shop, good, "player")
		if not ok:
			break
		career.on_trade(self, good, price, buying)
		done += 1
	var gname: String = Economy.GOODS[good]["name"]
	if done > 0:
		sfx("coin")
		Economy.message.emit(("Bought %d %s at the %s." if buying else "Sold %d %s to the %s.") % [done, gname, Economy.shops[shop]["name"]])
	elif buying:
		Economy.message.emit("Not enough coins for %s." % gname)
	else:
		Economy.message.emit("The %s cannot pay for %s right now." % [Economy.shops[shop]["name"], gname])
	return done


func sfx(sound: String, volume := 0.0) -> void:
	Sfx.play(sound, volume)


func quest_done(q: Dictionary) -> void:
	sfx("quest")
	sfx("coin")
	Fx.burst(self, _to3(player["pos"]) + Vector3(0, 2.0, 0), [Color(1, 0.85, 0.3), Color(0.95, 0.45, 0.55), Color(0.5, 0.8, 0.95), Color(1, 1, 1)], 40, 6.0)
	Fx.ring(self, _to3(player["pos"]), Color(1, 0.9, 0.4), 4.0)
	hud.banner("Quest complete", "%s   +%d coins" % [q["title"], int(q["reward"])])
	career.on_quest(self, q)
	quests.refresh(self)


# ---------------- loop ----------------

func _unhandled_input(ev: InputEvent) -> void:
	if not ready_done:
		return
	if dialog_npc != null and ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.keycode
		if k >= KEY_1 and k <= KEY_5:
			hud.pick_choice(k - KEY_0)
			get_viewport().set_input_as_handled()
			return
	if ev is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cam_yaw -= ev.relative.x * 0.008
		cam_pitch = clampf(cam_pitch + ev.relative.y * 0.004, 0.18, 1.15)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 0.8, 6.0, 90.0 if _arg_value("--cam=") != "" else 24.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 0.8, 6.0, 24.0)


func _process(delta: float) -> void:
	Sfx.listener = cam_focus
	if not ready_done:
		return
	if hud.paused:
		hud.refresh(self, 0.0)
		return
	clock += delta
	var prev_hour := hour
	hour = fposmod(6.0 + fposmod(clock, DAY_SECONDS) / DAY_SECONDS * 24.0, 24.0)
	if prev_hour < 17.0 and hour >= 17.0:
		_pay_wages()
		career.payday(self)
	if prev_hour < 7.0 and hour >= 7.0:
		_newcomer()
		_hire_guards()
		quests.refresh(self)
	if prev_hour < 5.0 and hour >= 5.0:
		career.new_day()
		for n in npcs:
			n.worked_today = false
			n.day_job = ""
	if prev_hour > hour:
		_roll_events()
		if Game.started and Chain.mode != "offline" and _arg_value("--report=") == "" and _arg_value("--demo=") == "" and DisplayServer.get_name() != "headless":
			# the player decides: settle the day on NEAR now, or let it roll over
			hud.menus.show_day_end(self, day_number() - 1)
		else:
			Chain.end_of_day(day_number() - 1)
		if _arg_value("--report=") != "":
			print("---- end of day %d ----" % (day_number() - 1))
			print(hud._ledger_text(self))
			for line in hud.log_lines.slice(maxi(0, hud.log_lines.size() - 12)):
				print("  log: ", line)

	if Game.started:
		_update_player(delta)
		career.update(self, delta)
	for m in monsters:
		m.update(delta, self)
	for n in npcs:
		if n != dialog_npc:
			n.update(delta, self)
	_separate(delta)
	_resolve_deaths()
	_update_gathers(delta)
	_update_coin_drops(delta)
	_update_trees(delta)
	_check_landmarks()
	_wake_towns()

	production_timer += delta
	if production_timer >= PRODUCE_EVERY:
		production_timer = 0.0
		Economy.produce()
		_restock()
	_update_quest_marks(delta)
	spawn_timer += delta
	if spawn_timer >= 5.0:
		spawn_timer = 0.0
		_cull_monsters()
		if monsters.size() < (MAX_MONSTERS * 6 / 10 if Game.low_end else MAX_MONSTERS):
			_spawn_monster_near()
	if boss_timer > 0.0:
		boss_timer -= delta
		if boss_timer <= 0.0:
			_spawn_boss()
	_chatter(delta)
	_update_allies(delta)
	_update_burning(delta)
	_met_t -= delta
	if _met_t <= 0.0:
		_met_t = 0.8
		for mm in monsters:
			if mm.pos.distance_to(player["pos"]) < 520.0:
				var e: Dictionary = bestiary.get(mm.kind, {"seen": 0, "kills": 0, "best_tier": 0})
				if int(e["seen"]) == 0:
					Economy.message.emit("Bestiary: new entry, %s. Press B." % Monster.name_of(mm.kind, cute))
				e["seen"] = int(e["seen"]) + 1
				e["best_tier"] = maxi(int(e["best_tier"]), mm.tier)
				bestiary[mm.kind] = e
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = 7.0
		_event_chatter()

	_find_nearby()
	_update_camera(delta)
	_sync_views(delta)
	_update_fades(delta)
	_update_marker(delta)
	_apply_daylight()
	for cl in clouds:
		cl.position.x += delta * 0.8
		if cl.position.x > 190.0:
			cl.position.x = -170.0
	hud.refresh(self, delta)

	if shot_path != "":
		frame += 1
		if frame == shot_frames - 6 and _arg_value("--demo=") == "rip":
			hud.rip("level", "LEVEL UP!", "Level 3", Color(1.0, 0.62, 0.15))
		if frame == shot_frames:
			print("memory: static %d MB, textures %d MB, buffers %d MB, video %d MB, objects %d, nodes %d" % [
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576,
				Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576,
				Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576,
				Performance.get_monitor(Performance.OBJECT_COUNT),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
			get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()


## What the prompt calls the use button.
func _use_key() -> String:
	return "Tap the bubble:" if Game.touch else "E"


func _cam_right() -> Vector2:
	return Vector2(cos(cam_yaw), -sin(cam_yaw))


func _cam_forward() -> Vector2:
	return Vector2(-sin(cam_yaw), -cos(cam_yaw))


func _update_player(delta: float) -> void:
	if player.get("down", false):
		player["moving"] = 0.0
		return
	var busy := hud.blocking() or (net != null and net.typing)
	var dir := Vector2.ZERO if busy else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move := _cam_right() * dir.x + _cam_forward() * (-dir.y)
	player["moving"] = 1.0 if move.length() > 0.05 else 0.0
	# Sprinting burns stamina; run dry and you stumble along at a walk until it
	# recovers, so you cannot simply outrun everything forever.
	var want_sprint := Input.is_action_pressed("sprint") and move.length() > 0.05
	var st := float(player["stamina"])
	if player["tired"] and st > 30.0:
		player["tired"] = false
	player["sprint"] = want_sprint and not player["tired"] and st > 0.0
	if player["sprint"]:
		st = maxf(0.0, st - delta * 24.0)
		if st <= 0.0:
			player["tired"] = true
			Fx.puff(self, _to3(player["pos"]), 0.7, Color(0.95, 0.9, 0.8))
	else:
		st = minf(float(player["max_stamina"]), st + delta * (10.0 if want_sprint else 20.0))
	player["stamina"] = st
	if move.length() > 0.05:
		player["heading"] = move.normalized()
	var spd := PLAYER_SPEED * (1.6 if player["sprint"] else 1.0) * (1.0 + 0.03 * (Game.stat("swift") - 1) + skills.bonus("speed"))
	var knock: Vector2 = player["knock"]
	player["move_dir"] = move.normalized() if move.length() > 0.05 else Vector2.ZERO
	if float(player["dash_t"]) > 0.0:
		player["dash_t"] = float(player["dash_t"]) - delta
		player["pos"] = try_move(player["pos"], Vector2(player["dash_dir"]) * 600.0 * delta, 9.0)
		player["moving"] = 1.0
	else:
		player["pos"] = try_move(player["pos"], (move.limit_length(1.0) * spd + knock) * delta, 9.0)
	player["knock"] = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	for k in ["iframes", "grace", "dodge_cd", "combo_show"]:
		player[k] = maxf(0.0, float(player[k]) - delta)
	if float(player["combo_t"]) > 0.0:
		player["combo_t"] = float(player["combo_t"]) - delta
		if float(player["combo_t"]) <= 0.0:
			player["combo_hits"] = 0
	if float(player["hit_t"]) > 0.0:
		player["hit_t"] = float(player["hit_t"]) - delta
		if float(player["hit_t"]) <= 0.0:
			_apply_player_hit(int(player["hit_step"]))
	_update_target_ring()
	player["cool"] = maxf(0.0, float(player["cool"]) - delta)
	player["beam_cool"] = maxf(0.0, float(player["beam_cool"]) - delta)
	player["dragon_cool"] = maxf(0.0, float(player.get("dragon_cool", 0.0)) - delta)
	player["ink"] = minf(float(player["max_ink"]), float(player["ink"]) + delta * (9.0 + 1.5 * (Game.stat("spirit") - 1) + skills.bonus("ink") * 0.08))
	skills.tick(delta)
	if clock - float(player["last_hurt"]) > 5.0:
		player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + delta * 1.5)
	var cam_turn := Input.get_axis("cam_right", "cam_left")
	cam_yaw += cam_turn * 1.8 * delta

	_update_jump(delta, busy)
	if Input.is_action_just_pressed("cancel"):
		var anything: bool = hud.blocking_overlay() or dialog_npc != null or hud.ledger_panel.visible
		hud.close_all()
		_close_dialog()
		if not anything:
			hud.toggle_pause()
	if dialog_npc != null:
		var dn := dialog_npc
		if not npcs.has(dn) or dn.inside or dn.pos.distance_to(player["pos"]) > 260.0 or not hud.dialog_panel.visible:
			_close_dialog()
	if Input.is_action_just_pressed("keys"):
		hud.toggle_keys()
	if Input.is_action_just_pressed("style"):
		Game.style = "real" if Game.cute() else "cute"
		get_tree().reload_current_scene()
		return
	if busy:
		return
	if Input.is_action_just_pressed("attack") and float(player["cool"]) <= 0.0:
		_player_attack()
	if Input.is_action_just_pressed("dodge"):
		_player_dodge()
	if Input.is_action_just_pressed("beam"):
		cast("greater_blast" if skills.has("greater_blast") else "blast")
	if Input.is_action_just_pressed("dragon"):
		cast("dragon")
	for i in 6:
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			var act: Array = skills.actives()
			if i < act.size():
				cast(String(act[i]))
	if Input.is_action_just_pressed("skills"):
		hud.toggle_skills()
	if Input.is_action_just_pressed("interact"):
		_interact()
	if Input.is_action_just_pressed("eat"):
		if Economy.use_item("player", "bread"):
			player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + 30.0)
			player_view.say("Bread.", 1.5)
	if Input.is_action_just_pressed("ledger"):
		hud.toggle_ledger()
	if Input.is_action_just_pressed("map"):
		hud.toggle_map()
	if Input.is_action_just_pressed("quests"):
		hud.toggle_quests()
	if Input.is_action_just_pressed("bestiary"):
		hud.toggle_bestiary()


## Space hops: stretch on take-off, squash and a ring of dust on landing.
func _update_jump(delta: float, busy: bool) -> void:
	var z: float = player["z"]
	var vz: float = player["vz"]
	if not busy and Input.is_action_just_pressed("jump") and z <= 0.0:
		vz = 7.8
		Sfx.play("jump")
		Sfx.play("cloth", -6.0)
		_squash(Vector3(0.72, 1.38, 1.0), 0.32)
		var c := _to3(player["pos"])
		for i in 3:
			var off := Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.2, 0.2))
			Fx.puff(self, c + off, randf_range(0.36, 0.5), Color(0.98, 0.95, 0.88))
	if z > 0.0 or vz > 0.0:
		vz -= 22.0 * delta
		z += vz * delta
		if z <= 0.0:
			z = 0.0
			if vz < -2.5:
				Sfx.play("land")
				Sfx.play("cloth", -3.0)
				_squash(Vector3(1.42, 0.58, 1.0), 0.44)
				shake = maxf(shake, 0.22)
				var c := _to3(player["pos"])
				for i in 8:
					var a := TAU * i / 8.0 + randf() * 0.4
					var r := randf_range(0.35, 0.7)
					Fx.puff(self, c + Vector3(cos(a), 0.0, sin(a)) * r, randf_range(0.38, 0.56), Color(0.98, 0.95, 0.88))
			vz = 0.0
	player["z"] = z
	player["vz"] = vz


## Springs the hero's cut-out from a squashed or stretched shape back to normal.
func _squash(to: Vector3, secs: float) -> void:
	var tw := player_view.create_tween()
	tw.tween_property(player_view, "scale", to, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_property(player_view, "scale", Vector3.ONE, secs).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _interact() -> void:
	if nearby_gather >= 0:
		_gather(nearby_gather)
	elif nearby_temple != "":
		_pray(nearby_temple)
	elif nearby_inn != "":
		_sleep_at(nearby_inn)
	elif nearby_shop != "":
		if quests.hand_in(self, nearby_shop):
			return
		if building(nearby_shop)["kind"] == "exchange":
			hud.open_prices(nearby_shop)
			return
		if career.refuses(self, nearby_shop):
			Economy.message.emit("The %s will not trade with you today." % building(nearby_shop)["name"])
			return
		hud.open_shop(nearby_shop)
	elif nearby_npc != null:
		_open_dialog(nearby_npc)
	elif near_board:
		quests.refresh(self)
		hud.open_board()


const TEMPLE_FEE := 6
const INN_FEE := 12


## The inn: pay for a bed, wake at dawn fully rested. The fee is the innkeeper's
## real income, so a travelling player feeds the town like anyone else.
func _sleep_at(inn: String) -> void:
	if hour < 19.0 and hour >= 5.0:
		Economy.message.emit("The innkeeper laughs. Beds are for after dark (from 7 in the evening).")
		return
	if not Economy.pay("player", inn, INN_FEE):
		Economy.message.emit("A bed costs %d coins. You do not have them." % INN_FEE)
		return
	Economy.message.emit("You pay %d coins and sleep until morning." % INN_FEE)
	hud.fade_through(func() -> void:
		player["hp"] = player["max_hp"]
		player["stamina"] = player["max_stamina"]
		player["ink"] = player["max_ink"]
		clock = (floorf(clock / DAY_SECONDS) + 1.0) * DAY_SECONDS
		Economy.message.emit("Morning. You feel rested."))


## The shrine heals for a small offering; the coins are the shrine's real income.
func _pray(temple: String) -> void:
	if float(player["hp"]) >= float(player["max_hp"]) - 1.0:
		Economy.message.emit("You are whole already. The shrine keeps its blessing for later.")
		return
	if not Economy.pay("player", temple, TEMPLE_FEE):
		Economy.message.emit("The shrine asks %d coins for a blessing. You do not have them." % TEMPLE_FEE)
		return
	player["hp"] = player["max_hp"]
	player["stamina"] = player["max_stamina"]
	player["ink"] = player["max_ink"]
	sfx("quest")
	Fx.ring(self, _to3(player["pos"]), Color(0.7, 1.0, 0.8), 3.0)
	Fx.sparks(self, _to3(player["pos"]) + Vector3(0, 1.0, 0), Color(0.8, 1.0, 0.85), 14, 4.0)
	_pop_number(_to3(player["pos"]) + Vector3(0, 2.0, 0), "Healed", Color(0.7, 1.0, 0.8))
	Economy.message.emit("The shrine heals you for %d coins." % TEMPLE_FEE)


func _gather(i: int) -> void:
	var g: Dictionary = gathers[i]
	if not g["ready"]:
		return
	g["ready"] = false
	g["t"] = 75.0
	Economy.add_item("player", g["good"])
	Sfx.play("pop")
	var s: Sprite3D = g["node"]
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3(1, 0.05, 1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	Fx.burst(self, s.position + Vector3(0, 0.5, 0), [Color(0.95, 0.85, 0.4), Color(0.6, 0.85, 0.4)], 12, 3.0)
	sfx("coin")
	player_view.lunge()
	Economy.message.emit("Gathered 1 %s." % Economy.GOODS[g["good"]]["name"])


func _update_gathers(delta: float) -> void:
	for g in gathers:
		if g["ready"]:
			if rng.randf() < delta * 0.7 and Vector2(g["pos"]).distance_to(player["pos"]) < 1100.0:
				var sp: Sprite3D = g["node"]
				Fx.glint(self, sp.position + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.4, 1.1), 0))
			continue
		g["t"] = float(g["t"]) - delta
		if float(g["t"]) <= 0.0:
			g["ready"] = true
			var s: Sprite3D = g["node"]
			s.create_tween().tween_property(s, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The strike is a three-hit combo: slash, back-slash, then a heavy overhead
## finisher with a lunge and a shockwave. Pressing again inside the window
## chains it; the swing steps toward the nearest enemy (aim assist) and the
## damage lands a few frames after the swing starts, so hits feel timed.
func _player_attack() -> void:
	var step := 0
	if float(player["combo_t"]) > 0.0:
		step = (int(player["combo"]) + 1) % 3
	player["combo"] = step
	player["combo_t"] = 1.0
	player["cool"] = [0.26, 0.26, 0.52][step]
	var p: Vector2 = player["pos"]
	var hd: Vector2 = player["heading"]
	var tgt := _aim_at(p, hd, 190.0)
	var lunge_ok := true
	if tgt != null:
		var toward := (tgt.pos - p).normalized()
		var md: Vector2 = player["move_dir"]
		# Backing away while swinging: keep facing where you are walking and do
		# not get yanked toward the target, or you moonwalk.
		if md != Vector2.ZERO and md.dot(toward) < 0.1:
			lunge_ok = false
		else:
			hd = toward
			player["heading"] = hd
	player["knock"] = hd * [170.0, 170.0, 360.0][step] if lunge_ok else Vector2.ZERO
	player["hit_t"] = [0.07, 0.07, 0.14][step]
	player["hit_step"] = step
	player_view.lunge()
	Sfx.play("swing")
	_squash([Vector3(1.12, 0.9, 1.0), Vector3(1.12, 0.9, 1.0), Vector3(0.9, 1.2, 1.0)][step], 0.25)
	var flip := hd.dot(_cam_right()) < 0.0
	var col := Color(1, 0.95, 0.75) if step < 2 else Color(1.0, 0.82, 0.45)
	Fx.slash(self, _to3(p + hd * 42.0) + Vector3(0, 1.0, 0), flip, col, step)


func _apply_player_hit(step: int) -> void:
	var has_blade: bool = int(Economy.wallets["player"]["items"].get("blade", 0)) > 0
	var base: float = (20.0 if has_blade else 12.0) * [1.0, 1.1, 1.9][step] * career.damage_mult()
	var p: Vector2 = player["pos"]
	var hd: Vector2 = player["heading"]
	var hit := false
	for m in monsters.duplicate():
		var d: Vector2 = m.pos - p
		var reach: float = [108.0, 112.0, 128.0][step] + (40.0 if Monster.is_big(m.kind) else 0.0) + 12.0 * m.size_mult()
		var arc_ok := d.length() < 38.0 or d.normalized().dot(hd) > (0.0 if step < 2 else -0.3)
		if d.length() < reach and arc_ok:
			var crit := rng.randf() < 0.12 + 0.02 * Game.stat("luck")
			_damage_monster(m, base * (1.6 if crit else 1.0), "player", p, step, crit)
			hit = true
	if hit:
		player["combo_hits"] = int(player["combo_hits"]) + 1
		player["combo_show"] = 2.5
	else:
		_chop_tree(p, hd, step)
	if step == 2:
		# the heavy third swing can catch a townsperson standing in front of you
		for n in npcs.duplicate():
			if not n.inside and n.pos.distance_to(p + hd * 70.0) < 52.0:
				hurt_npc(n, 6.0, p)
				career.on_assault(self, n)
				Economy.message.emit("You hit %s! Watch where you swing." % n.display_name)
		var at := _to3(p + hd * 70.0)
		Fx.slam(self, at, 1.7, Color(1.0, 0.85, 0.5))
		shake = maxf(shake, 0.35)
		fov_kick = maxf(fov_kick, 5.0)


## A quick sidestep roll with a short window of invulnerability. A dodge that
## lets a real attack pass through you is a perfect dodge: time slows for a
## moment and you get stamina and ink back.
func _player_dodge() -> void:
	if float(player["dodge_cd"]) > 0.0 or float(player["z"]) > 0.0:
		return
	if float(player["stamina"]) < 16.0:
		player_view.say("Too tired!", 0.8)
		return
	player["stamina"] = float(player["stamina"]) - 16.0
	var dir: Vector2 = player["move_dir"]
	if dir == Vector2.ZERO:
		dir = -Vector2(player["heading"])
	player["dash_dir"] = dir
	player["dash_t"] = 0.2
	player["iframes"] = 0.3
	player["dodge_cd"] = 0.6
	player["perfected"] = false
	var p: Vector2 = player["pos"]
	Fx.dash_trail(self, _to3(p), _to3(p + dir * 120.0), Color(0.95, 0.95, 1.0))
	Fx.puff(self, _to3(p), 0.6, Color(0.95, 0.9, 0.8))
	Sfx.play("jump", -4.0)
	_squash(Vector3(1.3, 0.7, 1.0), 0.25)


## Swinging at a tree chops it: it shakes, leaves fly, and after a few hits it
## topples and drops wood. It grows back after a while.
func _chop_tree(p: Vector2, hd: Vector2, step: int) -> void:
	var t := world.tree_near(p + hd * 30.0, 78.0, hd)
	if t.is_empty():
		return
	t["hp"] = int(t["hp"]) - (2 if step == 2 else 1)
	var o: Vector3 = t["o"]
	var mm: MultiMesh = t["mm"]
	var q: int = t["q"]
	var cd: Color = t["cd"]
	var tw := create_tween()
	tw.tween_method(func(v: float): mm.set_instance_custom_data(q, Color(cd.r, cd.g, cd.b, v)), 1.0, 0.0, 0.35)
	var top := Bend.at(o) + Vector3(0, float(t["h"]) * 0.6, 0)
	Fx.burst(self, top, [Color(0.55, 0.78, 0.35), Color(0.4, 0.65, 0.3), Color(0.7, 0.5, 0.3)], 8, 3.0)
	Fx.impact(self, Bend.at(o) + Vector3(0, 0.8, 0), Color(0.95, 0.8, 0.5), 0.7)
	sfx("hit")
	shake = maxf(shake, 0.12)
	if int(t["hp"]) > 0:
		return
	world.set_tree_standing(t, false)
	astar.set_point_solid(t["tile"], false)
	t["regrow"] = 110.0
	_topple_tree(t)
	var n := 2 + (1 if rng.randf() < 0.4 else 0)
	Economy.add_item("player", "wood", n)
	Economy.message.emit("Chopped a tree: +%d wood. The general store buys it." % n)
	_pop_number(Bend.at(o) + Vector3(0, 1.6, 0), "+%d wood" % n, Color(0.85, 0.65, 0.35))
	sfx("coin")


func _topple_tree(t: Dictionary) -> void:
	var o: Vector3 = Bend.at(t["o"])
	var pivot := Node3D.new()
	pivot.position = o
	add_child(pivot)
	var h: float = t["h"]
	var spr := Standee.make_sprite(world.props_atlas, h / 320.0, Rect2(256.0 * int(t["k"]), 0, 256, 320))
	spr.shaded = false
	pivot.add_child(spr)
	var dirn := 1.0 if (cam_yaw + float(t["i"])) > 0.0 and int(t["i"]) % 2 == 0 else -1.0
	var tw := create_tween()
	tw.tween_method(func(a: float): pivot.basis = Basis(Vector3.UP, cam_yaw) * Basis(Vector3(0, 0, 1), -a * dirn), 0.0, PI * 0.5, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		sfx("boom")
		shake = maxf(shake, 0.3)
		Fx.puff(self, o + Vector3(dirn * h * 0.5, 0.2, 0), 1.2, Color(0.8, 0.9, 0.7))
		Fx.burst(self, o + Vector3(dirn * h * 0.5, 0.5, 0), [Color(0.5, 0.75, 0.3), Color(0.4, 0.62, 0.28), Color(0.6, 0.4, 0.2)], 22, 4.0))
	tw.tween_interval(0.8)
	tw.tween_property(spr, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pivot.queue_free)


func _update_trees(delta: float) -> void:
	for t in world.trees:
		if not t["gone"]:
			continue
		t["regrow"] = float(t["regrow"]) - delta
		if float(t["regrow"]) <= 0.0:
			var tile: Vector2i = t["tile"]
			if Vector2(tile * int(TILE)).distance_to(player["pos"]) < 90.0 + TILE:
				t["regrow"] = 5.0   # not on top of the player
				continue
			world.set_tree_standing(t, true)
			t["hp"] = 3
			astar.set_point_solid(tile, true)


func _aim_at(p: Vector2, hd: Vector2, r: float) -> Monster:
	var best: Monster = null
	var bs := INF
	for m in monsters:
		var d: Vector2 = m.pos - p
		var dist := d.length()
		if dist > r or not m.view.visible:
			continue
		var dotv := d.normalized().dot(hd) if dist > 1.0 else 1.0
		if dotv < 0.3 and dist > 60.0:
			continue
		var score := dist * (1.4 - dotv * 0.5)
		if score < bs:
			bs = score
			best = m
	return best


func _update_target_ring() -> void:
	aim_target = _aim_at(player["pos"], player["heading"], 300.0) if Game.started else null
	if target_ring_node == null:
		target_ring_node = Fx.target_ring(self)
	target_ring_node.visible = aim_target != null
	if aim_target != null:
		target_ring_node.position = Bend.at(_to3(aim_target.pos))
		target_ring_node.scale = Vector3.ONE * (0.8 + aim_target.size_mult() * 0.5 + (0.9 if Monster.is_big(aim_target.kind) else 0.0))


## True (and the cost is paid) when a learned skill can be cast right now.
func _pay_skill(id: String) -> bool:
	var sk := skills.def(id)
	if sk.is_empty() or not skills.has(id):
		if id == "blast" or id == "greater_blast":
			player_view.say("I have not learned that yet. (T)", 1.4)
		return false
	if float(skills.cool.get(id, 0.0)) > 0.0:
		return false
	if sk.has("ink") and float(player["ink"]) < float(sk["ink"]):
		player_view.say("Out of ink.", 1.0)
		return false
	if sk.has("stamina") and float(player["stamina"]) < float(sk["stamina"]):
		player_view.say("Too tired.", 1.0)
		return false
	if sk.has("ink"):
		player["ink"] = float(player["ink"]) - float(sk["ink"])
	if sk.has("stamina"):
		player["stamina"] = float(player["stamina"]) - float(sk["stamina"])
	skills.cool[id] = float(sk.get("cool", 1.0))
	return true


func cast(id: String) -> void:
	if not Game.started or player.get("down", false) or hud.blocking():
		return
	match id:
		"blast", "greater_blast":
			_cast_blast(id)
		"flame":
			_cast_flame(id)
		"inferno":
			_cast_inferno(id)
		"whirl":
			_cast_whirl(id)
		"mend", "major_mend":
			_cast_mend(id)
		"summon", "major_summon":
			_cast_summon(id)
		"dragon":
			_player_dragon()


func _cast_blast(id: String) -> void:
	if not _pay_skill(id):
		return
	var sk := skills.def(id)
	Sfx.play("beam")
	player_view.lunge()
	var p: Vector2 = player["pos"]
	var hd: Vector2 = player["heading"]
	var end := p + hd * float(sk["range"])
	var col := Color(1.0, 0.55, 0.8) if cute else Color(0.55, 0.8, 1.0)
	var h0 := 1.0 if cute else 1.3
	var big := id == "greater_blast"
	Fx.beam(self, _to3(p) + Vector3(0, h0, 0) + Vector3(hd.x, 0, hd.y) * 0.5, _to3(end) + Vector3(0, h0, 0), col, 0.5 if big else 0.32)
	sfx("boom")
	shake = maxf(shake, 0.5 if big else 0.3)
	hud.rip("blast", "GREATER BLAST!" if big else "INK BLAST!", "", Color(1.0, 0.45, 0.7) if cute else Color(0.45, 0.7, 1.0))
	for m in monsters.duplicate():
		if _seg_dist(m.pos, p, end) < float(sk["width"]):
			_damage_monster(m, float(sk["dmg"]) * career.damage_mult(), "player", p, 1 if big else 0)


## The nearest monster roughly in front of the player, or null.
func _front_target(reach: float) -> Monster:
	var p: Vector2 = player["pos"]
	var hd: Vector2 = player["heading"]
	var best: Monster = null
	var bd := reach
	for m in monsters:
		var d: Vector2 = m.pos - p
		if d.length() < bd and (d.normalized().dot(hd) > 0.3 or d.length() < 90.0):
			bd = d.length()
			best = m
	return best


func _ignite(m: Monster, secs: float) -> void:
	if not is_instance_valid(m) or not is_instance_valid(m.view):
		return
	if burning.has(m):
		burning[m]["t"] = maxf(float(burning[m]["t"]), secs)
		return
	var fx := FireFx.burning(m.view, Vector3(0, Monster.height_of(m.kind, cute) * m.size_mult() * 0.45, 0), 1.0)
	burning[m] = {"t": secs, "tick": 0.0, "fx": fx}


func _update_burning(delta: float) -> void:
	for m in burning.keys():
		var b: Dictionary = burning[m]
		if not is_instance_valid(m) or not monsters.has(m) or float(m.hp) <= 0.0:
			if is_instance_valid(b["fx"]):
				b["fx"].queue_free()
			burning.erase(m)
			continue
		b["t"] = float(b["t"]) - delta
		b["tick"] = float(b["tick"]) + delta
		if float(b["tick"]) >= 0.6:
			b["tick"] = 0.0
			var dmg := 4.0 * career.damage_mult()
			m.hp -= dmg
			m.killer_id = "player"
			m.view.flash()
			_pop_number(_to3(m.pos) + Vector3(0, Monster.height_of(m.kind, cute) * m.size_mult() * 0.8, 0), str(int(dmg)), Color(1.0, 0.55, 0.2))
		if float(b["t"]) <= 0.0:
			if is_instance_valid(b["fx"]):
				b["fx"].queue_free()
			burning.erase(m)


func _cast_flame(id: String) -> void:
	if not _pay_skill(id):
		return
	var sk := skills.def(id)
	Sfx.play("fire")
	player_view.lunge()
	var p: Vector2 = player["pos"]
	var hd: Vector2 = player["heading"]
	var tgt := _front_target(float(sk["range"]))
	var end := tgt.pos if tgt != null else p + hd * 240.0
	var h0 := 1.0 if cute else 1.3
	var from := _to3(p) + Vector3(0, h0, 0) + Vector3(hd.x, 0, hd.y) * 0.6
	var to := _to3(end) + Vector3(0, 0.8, 0)
	var secs := clampf(from.distance_to(to) / 22.0, 0.12, 0.5)
	FireFx.bolt(self, from, to, secs, func() -> void:
		Sfx.play("fire_hit")
		shake = maxf(shake, 0.2)
		for m in monsters.duplicate():
			if is_instance_valid(m) and m.pos.distance_to(end) < 70.0:
				_damage_monster(m, float(sk["dmg"]) * career.damage_mult(), "player", p)
				_ignite(m, float(sk["burn"])))


func _cast_inferno(id: String) -> void:
	if not _pay_skill(id):
		return
	var sk := skills.def(id)
	Sfx.play("fire")
	Sfx.play("fire_hit")
	var p: Vector2 = player["pos"]
	player_view.lunge()
	FireFx.burst(self, _to3(p), 3.4, 44)
	Fx.ring(self, _to3(p), Color(1.0, 0.55, 0.2), 6.0)
	shake = maxf(shake, 0.55)
	hud.rip("blast", "INFERNO!", "", Color(1.0, 0.5, 0.15))
	for m in monsters.duplicate():
		if m.pos.distance_to(p) < float(sk["radius"]):
			_damage_monster(m, float(sk["dmg"]) * career.damage_mult(), "player", p, 1)
			_ignite(m, float(sk["burn"]))


func _cast_whirl(id: String) -> void:
	if not _pay_skill(id):
		return
	var sk := skills.def(id)
	Sfx.play("swing")
	Sfx.play("blade", -4.0)
	var p: Vector2 = player["pos"]
	player_view.lunge()
	Fx.slam(self, _to3(p), 2.6, Color(1.0, 0.9, 0.6))
	shake = maxf(shake, 0.35)
	for m in monsters.duplicate():
		if m.pos.distance_to(p) < float(sk["radius"]) + 12.0 * m.size_mult():
			_damage_monster(m, float(sk["dmg"]) * career.damage_mult(), "player", p, 1)


func _cast_mend(id: String) -> void:
	var sk := skills.def(id)
	if float(player["hp"]) >= float(player["max_hp"]) - 1.0:
		player_view.say("Already whole.", 1.0)
		return
	if not _pay_skill(id):
		return
	player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + float(sk["heal"]))
	Sfx.play("heal")
	Fx.heal(self, _to3(player["pos"]) + Vector3(0, 0.6, 0))
	_pop_number(_to3(player["pos"]) + Vector3(0, 2.2, 0), "+%d" % int(sk["heal"]), Color(0.6, 1.0, 0.7))


func _cast_summon(id: String) -> void:
	if not _pay_skill(id):
		return
	var sk := skills.def(id)
	Sfx.play("summon")
	var p: Vector2 = player["pos"]
	for k in int(sk["count"]):
		var look := {"skin": Color(0.96, 0.92, 0.84), "hair": Color(0.45, 0.35, 0.25), "cloth": Color(0.93, 0.88, 0.74), "pants": Color(0.80, 0.74, 0.60),
			"hat": "spiky", "weapon": "axe", "eyes": "tall", "brows": "dash", "chin": 0.22}
		var v := _make_standee(_bake_person(look, Vector2i(192, 240)), 1.35, "Paper Squire")
		v.show_hp = false
		v.base_tint = Color(0.96, 0.98, 1.0)
		var ang := TAU * float(k) / float(maxi(1, int(sk["count"]))) + 0.7
		var at := try_move(p, Vector2(cos(ang), sin(ang)) * 60.0, 9.0)
		allies.append({"pos": at, "ttl": float(sk["secs"]), "view": v, "cd": 0.3, "dmg": float(sk["dmg"]), "last": at, "slot": k})
		Fx.puff(self, _to3(at), 0.8, Color(1.0, 0.97, 0.9))
		Fx.sparks(self, _to3(at) + Vector3(0, 0.8, 0), Color(1.0, 0.95, 0.7), 10, 3.0)
	hud.rip("blast", "SQUIRES!" if int(sk["count"]) == 1 else "PAPER COMPANY!", "", Color(0.95, 0.9, 0.7))


func _update_allies(delta: float) -> void:
	var right := _cam_right()
	for a in allies.duplicate():
		a["ttl"] = float(a["ttl"]) - delta
		var v: Standee = a["view"]
		if float(a["ttl"]) <= 0.0 or not is_instance_valid(v):
			if is_instance_valid(v):
				Fx.puff(self, _to3(a["pos"]), 0.8, Color(1.0, 0.97, 0.9))
				Sfx.play("vanish")
				v.queue_free()
			allies.erase(a)
			continue
		var pos: Vector2 = a["pos"]
		var target: Monster = null
		var bd := 300.0
		for m in monsters:
			var d: float = m.pos.distance_to(pos)
			if d < bd and m.pos.distance_to(player["pos"]) < 420.0:
				bd = d
				target = m
		var goal: Vector2 = player["pos"] + Vector2(cos(float(a["slot"]) * 2.1 + 1.0), sin(float(a["slot"]) * 2.1 + 1.0)) * 70.0
		var moving := 0.0
		a["cd"] = maxf(0.0, float(a["cd"]) - delta)
		if target != null:
			if bd > 52.0:
				goal = target.pos
			else:
				goal = pos
				if float(a["cd"]) <= 0.0:
					a["cd"] = 0.8
					var dmg: float = float(a["dmg"]) * career.damage_mult()
					_damage_monster(target, dmg, "player", pos, 0)
					v.lunge()
		var to_goal := goal - pos
		if to_goal.length() > 26.0:
			a["pos"] = try_move(pos, to_goal.normalized() * 170.0 * delta, 9.0)
			moving = 1.0
			if absf(to_goal.dot(right)) > 4.0:
				v.facing = signf(to_goal.dot(right))
		if pos.distance_to(player["pos"]) > 700.0:
			a["pos"] = try_move(player["pos"], Vector2(40, 0), 9.0)
		v.position = Bend.at(_to3(a["pos"]))
		v.rotation.y = cam_yaw
		v.animate(delta, moving)


## Special attack: a dragon head swoops in from behind the player (off the
## top corner opposite the way they face) and breathes fire forward.
func _player_dragon() -> void:
	if hud.dragon_fx.busy():
		return
	if not _pay_skill("dragon"):
		return
	var hd: Vector2 = player["heading"]
	var side := signf(hd.dot(_cam_right()))
	if side == 0.0:
		side = float(player["facing"])
	var scr := camera.unproject_position(_to3(player["pos"]))
	player_view.lunge()
	hud.dragon_fx.play(side, scr)
	var p: Vector2 = player["pos"]
	hud.dragon_fx.bite.connect(func() -> void:
		shake = maxf(shake, 0.7)
		fov_kick = maxf(fov_kick, 6.0)
		var end := p + hd * 420.0
		hud.rip("blast", "DRAGON!", "", Color(1.0, 0.5, 0.1))
		for m in monsters.duplicate():
			if is_instance_valid(m) and _seg_dist(m.pos, p, end) < 120.0:
				_damage_monster(m, float(skills.def("dragon")["dmg"]) * career.damage_mult(), "player", p, 2, true)
				FireFx.burst(self, _to3(m.pos) + Vector3(0, 0.4, 0), 1.2, 24)
				_ignite(m, 4.0)
	, CONNECT_ONE_SHOT)


# ---------------- talk ----------------

func _open_dialog(n: Npc) -> void:
	dialog_npc = n
	n.view.talking = true
	Standee.quiet = true
	for o in npcs:
		if o != n and o.view != null and o.view.bubble != null:
			o.view.bubble.hide_bubble()
	for m in monsters:
		if m.view != null and m.view.bubble != null:
			m.view.bubble.hide_bubble()
	if player_view != null and player_view.bubble != null:
		player_view.bubble.hide_bubble()
	n.moving = 0.0
	var face := (Vector2(player["pos"]) - n.pos).normalized()
	n.facing = signf(face.dot(_cam_right())) if absf(face.dot(_cam_right())) > 0.05 else n.facing
	player["heading"] = -face
	hud.open_dialog(n, _talk_line(n), _talk_options(n))


func _close_dialog() -> void:
	Standee.quiet = false
	hud.close_dialog()
	if dialog_npc != null and is_instance_valid(dialog_npc) and is_instance_valid(dialog_npc.view):
		dialog_npc.view.talking = false
		if dialog_npc.view.bubble != null:
			dialog_npc.view.bubble.hide_bubble()
	dialog_npc = null


var _talk: Dictionary = {}


## One extra line of small talk, picked by who they are, where, the hour, their
## belly and what is happening in town. data/talk.json holds the pools.
func _small_talk(n: Npc) -> String:
	if _talk.is_empty():
		var f := FileAccess.open("res://data/talk.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_talk = parsed
		if _talk.is_empty():
			_talk = {"_": true}
	var pools: Array = []
	for e in Economy.active_events:
		if e["city"] == n.city and String(e["id"]) == "raiders":
			pools.append(_talk.get("raid", []))
	if n.hunger > 60.0:
		pools.append(_talk.get("hungry", []))
	elif n.hunger < 25.0:
		pools.append(_talk.get("fed", []))
	if n.is_hero():
		pools.append(_talk.get("hero", []))
	if n.job_title == "Mayor":
		pools.append(_talk.get("mayor", []))
	pools.append(_talk.get("night" if hour >= 19.0 or hour < 5.0 else "morning", []) if hour < 9.0 or hour >= 19.0 else [])
	var jobs: Dictionary = _talk.get("job", {})
	pools.append(jobs.get(n.job_kind, jobs.get("default", [])))
	pools.append(_talk.get("city", {}).get(n.city, []))
	var flat: Array = []
	for p in pools:
		flat.append_array(p)
	if flat.is_empty():
		return ""
	# a different line each visit, but stable within one conversation
	return String(flat[(absi(n.id.hash()) + day_number() * 7 + int(Time.get_ticks_msec() / 40000)) % flat.size()])


var _mark_t := 0.0


## A gold "!" over anyone who has a quest to give.
func _update_quest_marks(delta: float) -> void:
	_mark_t -= delta
	if _mark_t > 0.0:
		return
	_mark_t = 2.0
	var givers := {}
	for q in quests.offers:
		givers[q["giver"]] = true
	for n in npcs:
		if n is Merchant or not is_instance_valid(n.view):
			continue
		var gid: String = n.job_id if n.job_kind != "guard" else _guard_post_id(n.city)
		var want: bool = n.job_id != "" and givers.has(gid) and not n.inside
		var mk: Node = n.view.get_node_or_null("QuestMark")
		if want and mk == null:
			var l := Label3D.new()
			l.name = "QuestMark"
			l.text = "!"
			l.font_size = 120
			l.pixel_size = 0.006
			l.modulate = Color(1.0, 0.82, 0.2)
			l.outline_modulate = Color(0.25, 0.14, 0.05)
			l.outline_size = 16
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.fixed_size = false
			l.position = Vector3(0, Monster.height_of("wolf", cute) * 0 + 3.4, 0)
			n.view.add_child(l)
		elif not want and mk != null:
			mk.queue_free()


func _talk_line(n: Npc) -> String:
	var extra := _small_talk(n)
	extra = (" " + extra) if extra != "" else ""
	if n is Merchant:
		return "I am %s, a travelling merchant. Right now I am %s. I carry %d coins.%s" % [n.display_name, n.route_text(self), int(Economy.wallets[n.id]["coins"]), extra]
	var coins := int(Economy.wallets[n.id]["coins"])
	var mood := "I could eat." if n.hunger > 60.0 else "I ate well today."
	if n.hunger > 90.0:
		mood = "I am starving."
	if n.job_id != "":
		var place: String = building(n.job_id)["name"]
		var till := int(Economy.wallets[n.job_id]["coins"]) if Economy.wallets.has(n.job_id) else 0
		return "I am %s, %s at the %s. %s I have %d coin%s, the %s has %d in the till." % [n.display_name, n.job_title.to_lower(), place, mood, coins, "" if coins == 1 else "s", place, till] + extra
	if n.job_title == "Mayor":
		return "%s. I mind the town and the town minds its coins. %s" % [n.display_name, mood] + extra
	return "I am %s. No steady work for me. %s %d coins to my name." % [n.display_name, mood, coins] + extra


func _talk_options(n: Npc) -> Array:
	var opts: Array = []
	var giver := n.job_id if n.job_kind != "guard" else _guard_post_id()
	for q in quests.offers:
		if q["giver"] == giver:
			opts.append({"text": "Any odd jobs? (%s, %d coins)" % [q["title"], int(q["reward"])], "quest": q})
			break
	if n.job_id != "" and Economy.shops.has(n.job_id):
		opts.append({"text": "Let me see your goods.", "shop": n.job_id})
	if n is Merchant:
		opts.append({"text": "Show me your wares.", "shop": n.cart_id})
		opts.append({"text": "Where are you headed?", "route": true})
		opts.append({"text": "Any news?", "gossip": true})
		opts.append({"text": "Bye.", "bye": true})
		return opts
	if n.job_id != "" and n.city != "road":
		opts.append({"text": "Why are prices like this?", "why": true})
	opts.append_array(story.options(self, n))
	var jd := career.job_def(n.job_kind) if n.job_id != "" else {}
	if not jd.is_empty():
		if career.has_job() and career.job["place"] == n.job_id:
			opts.append({"text": "How is my job going?", "jobinfo": true})
			opts.append({"text": "I quit.", "quit": true})
		elif not career.has_job():
			opts.append({"text": "I want a job here.", "work": n.job_id})
	opts.append({"text": "Any news?", "gossip": true})
	opts.append({"text": "Bye.", "bye": true})
	return opts


## An NPC who was leading the player to their shop has reached the door.
func lead_arrived(n: Npc, shop: String) -> void:
	if Vector2(player["pos"]).distance_to(door_of(shop)) < 240.0 and not career.refuses(self, shop):
		hud.open_shop(shop)


func dialog_choice(opt: Dictionary) -> void:
	var n := dialog_npc
	if n == null or not is_instance_valid(n.view):
		# the speaker is gone: never leave the choices stuck on screen
		_close_dialog()
		return
	if opt.has("quest"):
		if quests.accept(self, opt["quest"]):
			hud.set_dialog_text("Thank you. The reward waits at the quest board. Come back when it is done.", [{"text": "Bye.", "bye": true}])
		else:
			hud.set_dialog_text("Sorry, we cannot afford help right now.", [{"text": "Bye.", "bye": true}])
	elif opt.has("story"):
		var said := story.choose(self, opt["story"])
		hud.set_dialog_text(said, _talk_options(n))
	elif opt.has("travel"):
		var tn := town_by_id(opt["travel"])
		_close_dialog()
		hud.fade_through(func() -> void:
			_teleport(_free_spot_near(tn["start"])))
		Economy.message.emit("The guards send you by cart to %s." % tn["name"])
	elif opt.has("route"):
		var r: String = n.route_text(self) if n is Merchant else ""
		hud.set_dialog_text("Bound for: %s. I will not tell you the price I paid. A merchant has to keep some secrets." % r, _talk_options(n))
	elif opt.has("why"):
		hud.set_dialog_text(_why_prices(n), _talk_options(n))
	elif opt.has("work"):
		var place: String = opt["work"]
		hud.set_dialog_text(career.offer_text(self, place), [{"text": "Take the job", "apply": place}, {"text": "Never mind.", "back": true}])
	elif opt.has("apply"):
		var why := career.apply(self, opt["apply"])
		if why == "":
			hud.set_dialog_text("Welcome aboard. Be here on shift, near the door, or you are out.", [{"text": "Bye.", "bye": true}])
		else:
			hud.set_dialog_text(why, [{"text": "Never mind.", "back": true}])
	elif opt.has("back"):
		hud.set_dialog_text(_talk_line(n), _talk_options(n))
	elif opt.has("jobinfo"):
		hud.set_dialog_text("%s\nRank %d. Wage %d a day. Shifts worked: %d." % [career.status_text(self), career.rank(), career.wage(), int(career.job["shifts"])], _talk_options(n))
	elif opt.has("quit"):
		career.quit(self)
		hud.set_dialog_text("Pity. The door is open if you change your mind.", [{"text": "Bye.", "bye": true}])
	elif opt.has("shop"):
		var sid: String = opt["shop"]
		_close_dialog()
		if career.refuses(self, sid):
			Economy.message.emit("They will not trade with you today.")
		elif n is Merchant or n.pos.distance_to(door_of(sid)) < 130.0:
			# the goods are on their back, or they are already at the counter
			n.say("Have a look.")
			hud.open_shop(sid)
		else:
			n.say("Alright, follow me.")
			n.lead_to = sid
			n.lead_t = 0.0
			n.state = "lead"
	elif opt.has("gossip"):
		hud.set_dialog_text(_gossip(n), _talk_options(n))
	else:
		_close_dialog()


## What this city's talk says about prices, in the city's own tone.
func _why_prices(n: Npc) -> String:
	var tone: String = String(town_by_id(n.city).get("tone", "cheery"))
	var cl: Dictionary = Economy.data["city_lines"].get(tone, {})
	var news := Economy.city_news(n.city, rng)
	var tail := ""
	for m in npcs:
		if m is Merchant and m.phase == "to_sell" and not m.trade.is_empty() and Economy.shops.has(m.trade["to"]) and Economy.shops[m.trade["to"]]["city"] == n.city:
			tail = " " + String(Economy.data["reasons"]["travel"]) % [m.display_name, String(Economy.GOODS[m.trade["good"]]["name"]).to_lower(), String(Economy.city_def(Economy.shops[m.trade["from"]]["city"]).get("name", "")), String(Economy.city_def(n.city).get("name", ""))]
			break
	return news + tail


func _gossip(n: Npc = null) -> String:
	var lines: Array = []
	var cty: String = n.city if n != null and n.city != "road" else "sunny"
	var tone: String = String(town_by_id(cty).get("tone", "cheery"))
	var cl: Dictionary = Economy.data["city_lines"].get(tone, {})
	if cl.has("joke"):
		lines.append(String(cl["joke"][rng.randi() % cl["joke"].size()]))
	lines.append(Economy.city_news(cty, rng))
	for e in Economy.active_events:
		if e["city"] == cty or e["city"] == "":
			lines.append(String(e["text"]) % String(Economy.city_def(cty).get("name", cty)))
	for e in Economy.active_events:
		lines.append(String(e.get("npc", "")))
	for m in npcs:
		if m is Merchant and m.phase != "rest":
			lines.append("Saw %s on the road: %s." % [m.display_name, m.route_text(self)])
			break
	if not career.grudges.is_empty():
		for sid in career.grudges:
			if career.is_banned(self, sid) and Economy.shops.has(sid):
				lines.append("The %s is still sore about what you did. Give it time." % Economy.shops[sid]["name"])
	if career.has_job():
		lines.append("They say you work at the %s now. Honest money, that." % building(career.job["place"])["name"])
	lines = lines.filter(func(l): return String(l) != "")
	var bakery := _shop_of_kind("bakery")
	if bakery != "":
		lines.append("Bread costs %d at the bakery right now. Prices follow the shelves." % Economy.buy_price(bakery, "bread"))
	var rich := richest_employer()
	if rich != "":
		lines.append("The %s is doing well. %d coins in the till." % [building(rich)["name"], int(Economy.wallets[rich]["coins"])])
	lines.append("They say a %s sits on a throne at Thorn Ruins." % monster_name("boss", false))
	lines.append("The treasury holds %d coins. It pays the guards and helps newcomers." % int(Economy.wallets[_guard_post_id()]["coins"]))
	lines.append("Every coin you see is accounted for. The ledger never lies.")
	return lines[rng.randi() % lines.size()]


# ---------------- travelling merchants ----------------

func _spawn_merchants() -> void:
	var md: Dictionary = Economy.data.get("merchants", {})
	var count := int(md.get("count", 0))
	if Game.low_end:
		count = int(ceil(count * 0.6))
	if towns.size() < 2:
		count = mini(count, 2)
	var names: Array = md.get("names", ["Trader"])
	var archs: Array = md.get("archetypes", ["merchant"])
	for i in count:
		var tn: Dictionary = towns[i % towns.size()]
		var m := Merchant.new()
		m.id = "merchant_%d" % i
		m.cart_id = "cart_%d" % i
		m.display_name = String(names[(i * 3 + int(rng.seed)) % names.size()])
		m.home_id = ""
		m.carry = int(md.get("carry", 6))
		m.min_profit = int(md.get("min_profit", 3))
		m.rest_secs = float(md.get("rest_secs", 14.0))
		m.hp = float(md.get("hp", 70.0))
		m.max_hp = m.hp
		m.rest_t = 3.0 + i * 4.0
		var door: Vector2 = tn["start"] + Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(10.0, 50.0))
		m.pos = _free_spot_near(door)
		m.wander_target = m.pos
		Economy.add_shop(m.cart_id, "%s's cart" % m.display_name, {}, {}, "*", 0, "", "")
		Economy.add_wallet(m.id, int(md.get("coins", 70)))
		var look: Dictionary = LOOKS[""].duplicate()
		look["skin"] = SKINS[rng.randi() % SKINS.size()]
		look["hair"] = HAIRS[rng.randi() % HAIRS.size()]
		look["cloth"] = Color.from_hsv(rng.randf(), 0.45, 0.85)
		look["pants"] = Color.from_hsv(rng.randf(), 0.25, 0.40)
		look["wide"] = rng.randf_range(0.9, 1.1)
		if cute:
			var arch := Archetypes.randomized(String(archs[i % archs.size()]), rng, SKINS, HAIRS)
			for k in ["skin", "hair", "wide"]:
				if not arch.has(k):
					arch[k] = look[k]
			look = arch
		m.view = _make_standee(_bake_person(look), rng.randf_range(1.55, 1.7) if cute else 2.2, m.display_name)
		m.set_meta("look", look)
		npcs.append(m)


## The closest city's start tile, where a frightened merchant runs to.
func nearest_town_pos(p: Vector2) -> Vector2:
	return _nearest_town_dict(p).get("start", start_pos)


## Where a resting merchant waits: the caravanserai door of the nearest city, or its gate.
func merchant_rest_spot(p: Vector2) -> Vector2:
	var tn := _nearest_town_dict(p)
	var cs := _shop_of_kind("caravanserai", tn.get("id", "sunny"))
	if cs != "":
		return door_of(cs) + Vector2(60, 40)
	return tn.get("start", start_pos) + Vector2(40, 30)


# ---------------- daily events ----------------

var _event_said := {}


## One roll a day (Economy.roll_events): fairs, blight, fish runs, collapses,
## caravans and raiders move prices, supply and danger. People react.
func _roll_events() -> void:
	var before := {}
	for e in Economy.active_events:
		before[str(e["id"]) + str(e["city"])] = true
	var ids: Array = []
	for tn in towns:
		ids.append(tn["id"])
	if career.level >= 5 and rng.randf() < (0.5 if _arg_value("--dragons") != "" else 0.14):
		_spawn_dragon()
	var lines: Array = Economy.roll_events(day_number(), ids, rng)
	for l in lines:
		Economy.message.emit(l)
	for e in Economy.active_events:
		if before.has(str(e["id"]) + str(e["city"])):
			continue
		hud.banner(String(e["name"]), String(Economy.city_def(e["city"]).get("name", e["city"])))
		_event_started(e)


func _event_started(e: Dictionary) -> void:
	var tn := town_by_id(e["city"])
	if tn.is_empty():
		return
	var c: Vector2 = tn["start"]
	match String(e["id"]):
		"festival":
			Fx.burst(self, _to3(c) + Vector3(0, 3.0, 0), [Color(1, 0.8, 0.3), Color(0.95, 0.45, 0.55), Color(0.5, 0.8, 0.95), Color(0.6, 0.9, 0.5)], 60, 7.0)
			for n in npcs:
				if n.city == e["city"] and not (n is Merchant):
					n.fun_cd = 0.0
					n.say("Hooray!")
		"raiders":
			# wolves come out of the hills to the road by the city; guards and the treasury respond
			for i in 4:
				var a := rng.randf() * TAU
				var q := _free_spot_near(c + Vector2(cos(a), sin(a)) * rng.randf_range(520.0, 760.0))
				_add_monster("wolf", q, 1)
			for n in npcs:
				if n.city == e["city"] and n.job_kind != "guard" and not (n is Merchant):
					n.state = "flee"
					n.scare = 5.0
					n.say("Raiders!")
		"wolf_moon":
			# a big night pack closes in on the walls
			for i in 6:
				var a2 := rng.randf() * TAU
				_add_monster("wolf" if i < 5 else "bat", _free_spot_near(c + Vector2(cos(a2), sin(a2)) * rng.randf_range(480.0, 700.0)), 2)
			for n in npcs:
				if n.city == e["city"] and n.job_kind != "guard" and not (n is Merchant) and not n.is_hero():
					n.state = "flee"
					n.scare = 6.0
					n.say("The pack!")
		"bog_surge":
			for i in 3:
				var a3 := rng.randf() * TAU
				_add_monster("slime", _free_spot_near(c + Vector2(cos(a3), sin(a3)) * rng.randf_range(520.0, 760.0)), 1)
			_add_monster("troll", _free_spot_near(c + Vector2.from_angle(rng.randf() * TAU) * 800.0), 1)
		"blight", "collapse":
			for n in npcs:
				if n.city == e["city"] and not (n is Merchant):
					n.say(String(e.get("npc", "Bad news.")))
					break


## People near the action mutter about whatever is going on.
func _event_chatter() -> void:
	for e in Economy.active_events:
		var line: String = String(e.get("npc", ""))
		if line == "":
			continue
		for n in npcs:
			if n.city != e["city"] or n is Merchant or n.inside:
				continue
			var key: String = str(e["id"]) + n.id + str(day_number())
			if _event_said.has(key) or n.speech != "":
				continue
			if n.pos.distance_to(player["pos"]) > 700.0:
				continue
			_event_said[key] = true
			n.say(line)
			return


func event_summary() -> String:
	var names: PackedStringArray = []
	for e in Economy.active_events:
		names.append(String(e["name"]))
	return " - ".join(names)


## Every coin that reaches or leaves the player floats up as a number.
func _on_gold(from_id: String, to_id: String, amount: int, _memo: String) -> void:
	if amount <= 0 or not Game.started:
		return
	var at := _to3(player["pos"])
	if to_id == "player":
		_pop_number(at + Vector3(-0.6, 2.4, 0), "+%d" % amount, Color(1.0, 0.85, 0.25))
	elif from_id == "player":
		_pop_number(at + Vector3(0.6, 2.0, 0), "-%d" % amount, Color(1.0, 0.4, 0.3))


## Treasuries hire more guards when beasts are about, up to three a town.
func _hire_guards() -> void:
	for tn in towns:
		if not tn.get("populated", false):
			continue
		var post := _guard_post_id(tn["id"])
		if post == "player":
			continue
		var guards := npcs.filter(func(n): return n.job_kind == "guard" and n.city == tn["id"]).size()
		var danger := Economy.road_danger()
		for m in monsters:
			if m.pos.distance_to(tn["start"]) < 1300.0:
				danger += 1
		var want := 1 + (1 if danger >= 2 else 0) + (1 if danger >= 4 else 0)
		if guards >= mini(want, 3) or int(Economy.wallets[post]["coins"]) < 150:
			continue
		var houses: Array = buildings.filter(func(b): return b["kind"] == "house" and b["city"] == tn["id"])
		_spawn_npc(building(post), houses, tn)
		var g: Npc = npcs[npcs.size() - 1]
		g.say("Reporting for duty.")
		Economy.message.emit("%s hired a new guard (%d on duty) as beasts gather." % [String(Economy.city_def(tn["id"]).get("name", tn["id"])), guards + 1])


func _chatter(delta: float) -> void:
	chatter_timer -= delta
	if chatter_timer > 0.0:
		return
	chatter_timer = rng.randf_range(5.0, 9.0)
	for a in npcs:
		if a.inside or a.speech != "" or a == dialog_npc:
			continue
		var b := nearest_npc(a.pos, 90.0)
		if b == null or b == a or b == dialog_npc:
			continue
		var pair: Array = CHATTER[rng.randi() % CHATTER.size()]
		var first: String = pair[0]
		if first.contains("%s"):
			match CHATTER.find(pair):
				1:
					var bk := _shop_of_kind("bakery")
					first = first % str(Economy.buy_price(bk, "bread") if bk != "" else 4)
				2:
					first = first % monster_name("wolf", false)
				3:
					var rich := richest_employer()
					first = first % (building(rich)["name"] if rich != "" else "market")
		a.say(first)
		var reply: String = pair[1]
		get_tree().create_timer(1.6).timeout.connect(_reply.bind(b, reply))
		return


func _reply(b: Npc, text: String) -> void:
	if is_instance_valid(b.view) and npcs.has(b):
		b.view.say(text, 2.5)


# ---------------- town routine ----------------

func _pay_wages() -> void:
	var taxed := 0
	for id in Economy.shops:
		var sh: Dictionary = Economy.shops[id]
		if sh["kind"] == "":
			continue
		var till := int(Economy.wallets[id]["coins"])
		var tax := int(maxf(0.0, till - 150.0) * 0.05)
		var tre := _guard_post_id(sh["city"])
		if tax > 0 and tre != "player" and Economy.pay(id, tre, tax):
			taxed += tax
	if taxed > 0:
		Economy.message.emit("Evening tax: %d coins collected for the town treasuries." % taxed)
	# shrines, lighthouses and the like earn nothing: the treasury keeps them going
	for b in buildings:
		var kd: Dictionary = KINDS[b["kind"]]
		if kd["job"] != "" and not kd["shop"] and b["kind"] != "guard" and Economy.wallets.has(b["id"]):
			var tre2 := _guard_post_id(b["city"])
			if tre2 != "player" and int(Economy.wallets[b["id"]]["coins"]) < WAGE * 2:
				Economy.pay(tre2, b["id"], mini(30, int(Economy.wallets[tre2]["coins"])))
	for n in npcs:
		if n.job_kind == "merchant":
			continue
		var place: String = n.job_id if n.job_id != "" else n.day_job
		if place == "" or not Economy.wallets.has(place):
			continue
		if n.job_id == "" and not n.worked_today:
			continue
		if Economy.pay(place, n.id, WAGE):
			n.say("Payday.")
		else:
			n.say("No wage again?")
			Economy.message.emit("The %s could not pay %s's wage." % [building(place)["name"], n.display_name])


## Other townsfolk standing within r of p (outside buildings), for steering.
func npc_neighbors(p: Vector2, r: float, except: Npc) -> Array:
	var out: Array = []
	for n in npcs:
		if n != except and not n.inside and n.pos.distance_to(p) < r:
			out.append(n)
	return out


func _separate(delta: float) -> void:
	var gap := 24.0
	for i in npcs.size():
		var a: Npc = npcs[i]
		if a.inside:
			continue
		for j in range(i + 1, npcs.size()):
			var b: Npc = npcs[j]
			if b.inside or (a.moving > 0.0 and b.moving > 0.0):
				continue
			var d := a.pos - b.pos
			var l := d.length()
			if l < gap:
				if l < 0.01:
					d = Vector2(1, 0)
					l = 1.0
				var push := d / l * (gap - l) * minf(1.0, delta * 6.0)
				a.pos = try_move(a.pos, push, 8.0)
				b.pos = try_move(b.pos, -push, 8.0)
		var dp: Vector2 = a.pos - Vector2(player["pos"])
		if a.moving == 0.0 and dp.length() < gap and dp.length() > 0.01:
			a.pos = try_move(a.pos, dp.normalized() * (gap - dp.length()) * minf(1.0, delta * 6.0), 8.0)


# ---------------- gold that monsters drop ----------------
# Real coins on the ground. They are paid out of the nearest town's treasury
# when you pick them up (a bounty), so no coin is ever made from nothing.

var coin_drops: Array = []
var _coin_mesh: CylinderMesh
var _coin_mat: StandardMaterial3D
var _coin_warned := 0.0


func _drop_gold(p: Vector2, total: int) -> void:
	if total <= 0:
		return
	if _coin_mesh == null:
		_coin_mesh = CylinderMesh.new()
		_coin_mesh.top_radius = 0.2
		_coin_mesh.bottom_radius = 0.2
		_coin_mesh.height = 0.05
		_coin_mat = StandardMaterial3D.new()
		_coin_mat.albedo_color = Color(1.0, 0.82, 0.25)
		_coin_mat.emission_enabled = true
		_coin_mat.emission = Color(0.6, 0.4, 0.05)
		_coin_mesh.material = _coin_mat
	var n := clampi(total / 4 + 1, 1, 6)
	var per := maxi(1, total / n)
	for i in n:
		var node := MeshInstance3D.new()
		node.mesh = _coin_mesh
		node.rotation.x = PI * 0.5
		add_child(node)
		var q := p + Vector2(rng.randf_range(-34, 34), rng.randf_range(-34, 34))
		node.position = Bend.at(_to3(q)) + Vector3(0, 0.3, 0)
		coin_drops.append({"pos": q, "amt": per, "node": node, "t": 0.0, "seed": rng.randf() * TAU})


func _update_coin_drops(delta: float) -> void:
	var pp: Vector2 = player["pos"]
	for c in coin_drops.duplicate():
		c["t"] = float(c["t"]) + delta
		var node: MeshInstance3D = c["node"]
		var pos: Vector2 = c["pos"]
		var d := pos.distance_to(pp)
		if d < 130.0 and float(c["t"]) > 0.5 and not player.get("down", false):
			pos += (pp - pos).normalized() * minf(d, (260.0 + (130.0 - d) * 4.0) * delta)
			c["pos"] = pos
		if is_instance_valid(node):
			node.position = Bend.at(_to3(pos)) + Vector3(0, 0.3 + sin(float(c["t"]) * 4.0 + float(c["seed"])) * 0.06, 0)
			node.rotation.y += delta * 4.0
		if d < 28.0 and float(c["t"]) > 0.5:
			_collect_coin(c)
		elif float(c["t"]) > 60.0:
			coin_drops.erase(c)
			if is_instance_valid(node):
				node.queue_free()


func _collect_coin(c: Dictionary) -> void:
	coin_drops.erase(c)
	var node: MeshInstance3D = c["node"]
	if is_instance_valid(node):
		node.queue_free()
	var amt := int(c["amt"])
	var tre := _guard_post_id(str(_nearest_town_dict(c["pos"]).get("id", "sunny")))
	if tre != "player" and Economy.pay(tre, "player", amt):
		sfx("coin")
		_pop_number(_to3(player["pos"]) + Vector3(0, 1.8, 0), "+%d" % amt, Color(1.0, 0.85, 0.25))
	elif clock - _coin_warned > 20.0:
		_coin_warned = clock
		Economy.message.emit("The treasury could not pay the bounty on that coin.")


func _resolve_deaths() -> void:
	for m in monsters.duplicate():
		if m.hp > 0.0:
			continue
		monsters.erase(m)
		if is_instance_valid(m.telegraph):
			m.telegraph.queue_free()
		m.view.fall()
		sfx("boom")
		sfx("shatter", -4.0)
		var at := _to3(m.pos) + Vector3(0, 1.0, 0)
		Fx.burst(self, at, [Color(1, 0.85, 0.3), Color(1, 1, 1), Color(0.95, 0.5, 0.6)], 28 if not Monster.is_big(m.kind) else 90, 5.0)
		Fx.puff(self, _to3(m.pos), 1.4)
		if Monster.is_big(m.kind):
			if m.killer_id == "player":
				hud.rip("boss", "BOSS DOWN!", m.display_name, Color(1.0, 0.8, 0.25))
			Fx.ring(self, _to3(m.pos), Color(1, 0.9, 0.4), 8.0)
			if m.kind == "boss":
				boss_timer = DAY_SECONDS * 2.0
				hud.banner("%s defeated" % m.display_name, "Thorn Ruins are quiet. For now.")
			else:
				hud.banner("%s slain" % m.display_name, "A dragon's hoard is yours.")
		if m.killer_id == "player":
			_drop_gold(m.pos, (60 if Monster.is_big(m.kind) else 2 + m.tier * 3 + int(m.max_hp / 40.0)))
			var drops: Dictionary = Monster.TYPES[m.kind]["drops"]
			var got: Array = []
			for good in drops:
				Economy.add_item("player", good, int(drops[good]))
				got.append("%d %s" % [int(drops[good]), Economy.GOODS[good]["name"]])
			Economy.message.emit("You beat the %s. Looted %s." % [m.display_name, ", ".join(PackedStringArray(got))])
			quests.on_kill(self, m.kind)
			career.on_kill(self, m)
			if bestiary.has(m.kind):
				bestiary[m.kind]["kills"] = int(bestiary[m.kind]["kills"]) + 1
			story.on_kill(self, m.kind)
		else:
			var guard := npc_by_id(m.killer_id)
			if guard != null and guard.job_id == "":
				var tre := _guard_post_id(guard.city)
				var pay := BOUNTY / 2
				if tre != "player" and Economy.pay(tre, guard.id, pay):
					guard.say("Got it! The treasury owes me %d." % pay)
					Economy.message.emit("%s stood against a %s and was paid %d coins from the treasury." % [guard.display_name, m.display_name, pay])
				else:
					guard.say("Got it!")
			elif guard != null and Economy.pay(guard.job_id, guard.id, BOUNTY):
				guard.say("Bounty earned.")
				Economy.message.emit("%s the guard felled a %s and took a %d coin bounty." % [guard.display_name, m.display_name, BOUNTY])
			elif guard != null:
				guard.say("The post cannot pay me.")
	for n in npcs.duplicate():
		if n.hp <= 0.0:
			npcs.erase(n)
			if n == dialog_npc:
				_close_dialog()
			n.view.fall()
			var cause := "starved" if n.last_hurt_by == "" else "was killed by a monster"
			var estate := int(Economy.wallets[n.id]["coins"])
			var heir_city: String = n.city if n.city != "road" else String(_nearest_town_dict(n.pos).get("id", "sunny"))
			Economy.pay(n.id, _guard_post_id(heir_city), estate)
			if n is Merchant:
				# the cart's goods and till are lost with it: coins go to the treasury too
				var cart := int(Economy.wallets[n.cart_id]["coins"])
				if cart > 0:
					Economy.pay(n.cart_id, _guard_post_id(heir_city), cart)
				Economy.shops.erase(n.cart_id)
			Economy.message.emit("%s %s. Their %d coins went to the town treasury." % [n.display_name, cause, estate])


func _cull_monsters() -> void:
	for m in monsters.duplicate():
		if Monster.is_big(m.kind):
			continue
		if m.pos.distance_to(player["pos"]) > 2700.0:
			monsters.erase(m)
			if is_instance_valid(m.telegraph):
				m.telegraph.queue_free()
			m.view.queue_free()


func player_in_town() -> bool:
	return town_at(player["pos"], 1.0) != ""


func _check_landmarks() -> void:
	var p: Vector2 = player["pos"]
	var now := ""
	for l in world.landmarks:
		if p.distance_to(l["pos"]) < float(l["r"]) * TILE * 1.1:
			now = l["id"]
	if now != inside_landmark:
		inside_landmark = now
		if now != "":
			var l := world.landmark(now)
			if not discovered.get(now, false):
				discovered[now] = true
				hud._reveal(l["pos"], int(l["r"]) + 10)
				if l.get("city", false):
					hud.banner(l["name"], "A town of %s. Fast travel unlocked (M)." % Economy.city_def(now).get("likes", "good company"))
				else:
					hud.banner(l["name"], "Discovered. Fast travel unlocked on the map (M).")
				sfx("coin")
			quests.on_visit(self, now)


func fast_travel(id: String) -> void:
	if not discovered.get(id, false):
		return
	var l := world.landmark(id)
	hud.close_all()
	hud.fade_through(_teleport.bind(_free_spot_near(l.get("spot", l["pos"] + Vector2(0, 160)))))


func _teleport(p: Vector2) -> void:
	player["pos"] = p
	cam_focus = _to3(p)
	for m in monsters:
		if m.pos.distance_to(p) < 300.0 and m.kind != "boss":
			m.pos += (m.pos - p).normalized() * 300.0


func _find_nearby() -> void:
	var p: Vector2 = player["pos"]
	nearby_shop = ""
	nearby_inn = ""
	nearby_temple = ""
	nearby_npc = null
	nearby_gather = -1
	near_board = p.distance_to(board_pos) < 70.0
	for i in gathers.size():
		if gathers[i]["ready"] and p.distance_to(gathers[i]["pos"]) < 60.0:
			nearby_gather = i
	for b in buildings:
		if b["shop"] and p.distance_to(b["door"]) < 60.0:
			nearby_shop = b["id"]
	for b in buildings:
		if b["kind"] == "temple" and p.distance_to(b["door"]) < 60.0:
			nearby_temple = b["id"]
		elif b["kind"] == "inn" and p.distance_to(b["door"]) < 60.0:
			nearby_inn = b["id"]
	if nearby_shop == "" and nearby_temple == "" and nearby_inn == "":
		nearby_npc = nearest_npc(p, 60.0)
	if hud.shop_id != "" and p.distance_to(door_of(hud.shop_id)) > 140.0 and dialog_npc == null:
		hud.close_shop()
	var parts: Array = []
	if nearby_gather >= 0:
		parts.append(_use_key() + "  gather %s" % Economy.GOODS[gathers[nearby_gather]["good"]]["name"])
	elif nearby_temple != "":
		parts.append(_use_key() + "  pray at the shrine (%d coins heals you)" % TEMPLE_FEE)
	elif nearby_inn != "":
		parts.append(_use_key() + "  sleep at the inn (%d coins, after dark)" % INN_FEE)
	elif nearby_shop != "":
		if building(nearby_shop)["kind"] == "exchange":
			parts.append(_use_key() + "  read the price board")
		else:
			parts.append(_use_key() + "  trade at %s" % building(nearby_shop)["name"])
	elif nearby_npc != null:
		parts.append(_use_key() + "  talk to %s" % nearby_npc.display_name)
	elif near_board:
		parts.append(_use_key() + "  read the quest board")
	prompt = "      ".join(PackedStringArray(parts))


func _sync_views(delta: float) -> void:
	if net != null:
		net.tick(delta, player["pos"], player["move_dir"])
	var right := _cam_right()
	var pp: Vector2 = player["pos"]
	player_view.position = Bend.at(_to3(pp)) + Vector3(0, float(player["z"]), 0)
	player_view.rotation.y = cam_yaw
	var hd: Vector2 = player["heading"]
	if absf(hd.dot(right)) > 0.2:
		player["facing"] = signf(hd.dot(right))
	player_view.facing = player["facing"]
	if float(player["moving"]) > 0.0:
		player_idle = 0.0
	else:
		player_idle += delta
	# If a shove or lunge carries you against the way you are walking, face the
	# way you actually travel instead of running backwards on the spot.
	var travelled: Vector2 = pp - _player_prev_pos
	_player_prev_pos = pp
	var view_dir := hd
	var view_moving := float(player["moving"]) > 0.0
	if view_moving and delta > 0.0 and travelled.length() > 60.0 * delta and travelled.normalized().dot(hd) < -0.3:
		view_dir = travelled.normalized()
		if absf(view_dir.dot(right)) > 0.2:
			player_view.facing = signf(view_dir.dot(right))
	_pick_view(player_view, view_dir, view_moving, false)
	player_view.animate(delta, float(player["moving"]) * (1.35 if player["sprint"] else 1.0))
	player_view.set_hp(float(player["hp"]) / float(player["max_hp"]))
	if float(player["moving"]) > 0.0:
		dust_timer -= delta
		if dust_timer <= 0.0:
			dust_timer = 0.14 if player["sprint"] else 0.26
			if float(player["z"]) <= 0.0:
				Sfx.play("step", 0.0, 0.12)
			Fx.puff(self, _to3(pp - hd * 14.0), 0.5 if player["sprint"] else 0.32, Color(0.98, 0.95, 0.88))
	for n in npcs:
		var vis: bool = not n.inside and n.pos.distance_to(pp) < 2200.0
		n.view.visible = vis
		if not vis:
			continue
		var prev: Vector2 = last_pos.get(n, n.pos)
		var mv: Vector2 = n.pos - prev
		last_pos[n] = n.pos
		if n == dialog_npc:
			var face: Vector2 = pp - n.pos
			if absf(face.dot(right)) > 2.0:
				n.view.facing = signf(face.dot(right))
		elif n.moving > 0.0 and mv.length() > 0.2 and absf(mv.dot(right)) > mv.length() * 0.2:
			n.view.facing = signf(mv.dot(right))
		_pick_view(n.view, mv, mv.length() > 0.2, n == dialog_npc or n.moving == 0.0)
		n.view.position = Bend.at(_to3(n.pos))
		n.view.rotation.y = cam_yaw
		n.view.busy = n.state == "work" and n.moving == 0.0
		n.view.animate(delta, n.moving)
		n.view.set_hp(n.hp / n.max_hp)
		if n.speech != "":
			n.view.say(n.speech)
			n.speech = ""
	for m in monsters:
		var vis2: bool = m.pos.distance_to(pp) < 2400.0
		m.view.visible = vis2
		if not vis2:
			continue
		var look: Vector2 = m.heading
		if m.windup > 0.0 and (m.windup_kind == "beam" or m.windup_kind == "pounce"):
			look = m.aim - m.pos
		if absf(look.dot(right)) > 0.1 * look.length():
			m.view.facing = signf(look.dot(right))
		m.view.position = Bend.at(_to3(m.pos))
		m.view.rotation.y = cam_yaw
		m.view.windup_target = 1.0 if m.windup > 0.0 else 0.0
		m.view.animate(delta, m.moving)
		m.view.set_hp(m.hp / m.max_hp)


func _update_camera(delta: float) -> void:
	var target := _to3(player["pos"])
	if not Game.started:
		cam_yaw += delta * 0.08
		target = _to3(Vector2(TownGen.COLS * 0.5, TownGen.ROWS * 0.5) * TILE)
	# Talking pulls the camera in and frames both speakers.
	talk_k = move_toward(talk_k, 1.0 if dialog_npc != null else 0.0, delta * 2.2)
	if dialog_npc != null:
		talk_focus = (target + _to3(dialog_npc.pos)) * 0.5
	if talk_k > 0.0:
		target = target.lerp(talk_focus + Vector3(0, 0.35, 0), smoothstep(0.0, 1.0, talk_k))
	var follow := 1.0 - exp(-delta * 5.0)
	cam_focus = cam_focus.lerp(target, follow)
	shake = maxf(0.0, shake - delta * 2.5)
	var dist := cam_dist if Game.started else 30.0
	var pitch := cam_pitch if Game.started else 0.5
	var tk := smoothstep(0.0, 1.0, talk_k)
	dist = lerpf(dist, minf(dist, 5.6), tk)
	pitch = lerpf(pitch, minf(pitch, 0.36), tk)
	var off := Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch)) * dist
	var focus := cam_focus + Vector3(0, 1.3, 0)
	var pos := focus + off
	var ground := world.height_at(Vector2(pos.x, pos.z) / K) + 1.2
	pos.y = maxf(pos.y, ground)
	var sh := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake * 0.25 * cam_shake
	camera.position = pos + sh
	camera.look_at(focus + sh * 0.5)
	fov_kick = move_toward(fov_kick, 0.0, delta * 22.0)
	camera.fov = cam_fov - fov_kick * 0.6 + float(player["dash_t"] > 0.0) * 3.0 - talk_k * 6.0
	Bend.update(cam_focus, -Vector2(off.x, off.z))
	world.props_material.set_shader_parameter("player_pos", target)
	world.props_material.set_shader_parameter("cam_pos", camera.position)


## Buildings between the camera and the player dither out.
func _update_fades(delta: float) -> void:
	var a := Vector2(camera.position.x, camera.position.z) / K
	var b: Vector2 = player["pos"]
	for f in fades:
		var r: Rect2 = f["rect"]
		var c := r.get_center()
		var ab := b - a
		var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
		var off := c.distance_to(a + ab * t)
		var hide := Game.started and t > 0.05 and t < 0.995 and off < r.size.length() * 0.55
		var goal := 0.4 if hide else 1.0
		var v := move_toward(float(f["fade"]), goal, delta * 1.5)
		if v != float(f["fade"]):
			f["fade"] = v
			for m in f["mats"]:
				m.set_shader_parameter("fade", v)


## The bobbing arrow over the tracked quest's target.
func _update_marker(_delta: float) -> void:
	var q := quests.current()
	if q.is_empty() or not Game.started:
		marker.visible = false
		return
	var tp := quests.target_of(self, q)
	marker.visible = tp.distance_to(player["pos"]) > 90.0
	var bob := sin(clock * 3.0) * 0.25
	var hgt := 3.2
	if q["kind"] == "hunt":
		hgt = Monster.height_of(q["monster"], cute) + 0.9
	marker.position = Bend.at(_to3(tp)) + Vector3(0, hgt + bob, 0)


func _weather(delta: float, d: float) -> float:
	if rain_left > 0.0:
		rain_left -= delta
		if rain_left <= 0.0:
			raining = false
			Economy.message.emit("The rain stops. The paper dries out.")
	elif Game.started and rng.randf() < delta / (DAY_SECONDS * 0.6):
		raining = true
		rain_left = DAY_SECONDS * rng.randf_range(0.08, 0.16)
		Economy.message.emit("A shower rolls in over the hills.")
	var focus := cam_focus
	amb["petals"].position = focus + Vector3(0, 12, 0)
	amb["flies"].position = focus + Vector3(0, 1.6, 0)
	amb["rain"].position = focus + Vector3(0, 14, 0)
	amb["petals"].emitting = d > 0.3 and not raining
	amb["flies"].emitting = d < 0.25 and not raining
	amb["rain"].emitting = raining
	var wet := float(env.get_meta("wet", 0.0))
	wet = move_toward(wet, 1.0 if raining else 0.0, delta * 0.3)
	env.set_meta("wet", wet)
	return wet


func _apply_daylight() -> void:
	var d := clampf(sin((hour - 5.0) / 16.0 * PI), 0.0, 1.0)
	var wet := _weather(get_process_delta_time(), d)
	var dusk := clampf(1.0 - absf(d - 0.25) * 6.0, 0.0, 1.0) * 0.6
	sun.light_energy = 0.15 + 0.7 * d
	sun.light_color = Color(1.0, 0.70, 0.50).lerp(Color(1.0, 0.97, 0.90), d)
	sun.rotation_degrees.y = lerpf(-70.0, 70.0, clampf((hour - 5.0) / 16.0, 0.0, 1.0))
	sun.rotation_degrees.x = lerpf(-12.0, -55.0, d)
	env.ambient_light_energy = 0.28 + 0.22 * d
	env.ambient_light_color = Color(0.45, 0.50, 0.80).lerp(Color(0.95, 0.92, 0.85), d)
	var top := Color(0.08, 0.10, 0.25).lerp(Color(0.36, 0.60, 0.92), d)
	var horizon := Color(0.20, 0.22, 0.40).lerp(Color(0.86, 0.92, 0.98), d).lerp(Color(0.98, 0.66, 0.50), dusk)
	top = top.lerp(Color(0.42, 0.46, 0.52), wet * d)
	horizon = horizon.lerp(Color(0.62, 0.66, 0.70), wet * d)
	sun.light_energy *= 1.0 - wet * 0.55
	env.fog_density = 0.0042 + wet * 0.012
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	env.fog_light_color = horizon
	var tint := Color(0.40, 0.45, 0.65).lerp(Color.WHITE, d)
	for cl in clouds:
		cl.modulate = tint
	world.props_material.set_shader_parameter("tint", 0.55 + 0.45 * d)
	var night := 1.0 - d
	for l in lamps:
		l.light_energy = night * 1.8


func _notification(what: int) -> void:
	# Alt-tabbing away can swallow key releases: never come back stuck.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Input.flush_buffered_events()
		for a in InputMap.get_actions():
			if not String(a).begins_with("ui_"):
				Input.action_release(a)
		if dialog_npc != null and (not is_instance_valid(dialog_npc) or not is_instance_valid(dialog_npc.view)):
			dialog_npc = null
			Standee.quiet = false
			hud.close_dialog()
