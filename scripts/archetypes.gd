## Dragon Quest style character archetypes for the chibi painter
## (PaintCute.chibi / chibi_front). Each entry is a plain params Dictionary:
## anything present in an entry is authoritative. Anything left out (skin, hair,
## cloth, pants, eyes, brows, cheeks, glasses ...) may be randomised by the
## caller. Use get_look(id) to get a private copy.
##
## Extra keys: "title" is a display label, "randomize" lists the keys that the
## caller is welcome to randomise on top of the entry (everything else is fixed).
class_name Archetypes
extends RefCounted

const WOOD := Color(0.58, 0.40, 0.24)

const LOOKS := {
	# --- heroes and fighters
	"hero": {"title": "Hero", "hat": "spiky", "hair": Color(0.50, 0.30, 0.16), "cloth": Color(0.92, 0.88, 0.78), "vest": Color(0.46, 0.48, 0.54),
		"pants": Color(0.30, 0.27, 0.28), "weapon": "double_axe", "eyes": "tall", "brows": "dash", "chin": 0.22, "randomize": []},
	"knight": {"eyes": "oval", "title": "Knight", "armor": "plate", "helm": "plume", "plume": Color(0.84, 0.18, 0.20), "tabard": {"a": Color(0.82, 0.18, 0.20), "b": Color(0.97, 0.95, 0.90)},
		"cloth": Color(0.60, 0.62, 0.68), "pants": Color(0.34, 0.34, 0.40), "weapon": "broadsword", "shield": "kite", "shield_col": Color(0.82, 0.18, 0.20),
		"emblem": "cross", "emblem_col": Color(0.97, 0.95, 0.90), "randomize": ["skin"]},
	"royal_guard": {"eyes": "dot", "title": "Royal Guard", "armor": "plate", "helm": "kettle", "tabard": {"a": Color(0.22, 0.36, 0.72), "b": Color(0.96, 0.94, 0.88)},
		"cape": Color(0.20, 0.30, 0.64), "cloth": Color(0.55, 0.60, 0.72), "pants": Color(0.24, 0.28, 0.46), "weapon": "spear",
		"randomize": ["skin", "hair"]},
	"viking": {"eyes": "dot", "title": "Viking", "armor": "leather", "helm": "viking", "beard": "short", "hat": "long", "hair": Color(0.70, 0.40, 0.18), "cloth": Color(0.56, 0.30, 0.22),
		"pants": Color(0.34, 0.28, 0.22), "weapon": "sword", "shield": "round", "shield_col": Color(0.26, 0.40, 0.62), "emblem": "star", "emblem_col": Color(0.96, 0.84, 0.40),
		"randomize": ["skin"]},
	"valkyrie": {"eyes": "lash", "title": "Valkyrie", "armor": "gold", "helm": "winged", "hat": "wavy", "hair": Color(0.90, 0.74, 0.38), "cloth": Color(0.86, 0.90, 0.96),
		"pants": Color(0.50, 0.54, 0.68), "weapon": "sword", "shield": "kite", "shield_col": Color(0.90, 0.92, 0.96), "emblem": "star", "emblem_col": Color(0.96, 0.78, 0.30),
		"cape": Color(0.30, 0.42, 0.74), "randomize": ["skin"]},
	"gladiator": {"eyes": "small", "title": "Gladiator", "armor": "leather", "helm": "kettle", "hat_col": Color(0.82, 0.56, 0.28), "plume": Color(0.78, 0.16, 0.16), "cloth": Color(0.82, 0.58, 0.40),
		"pants": Color(0.62, 0.30, 0.20), "weapon": "sword", "shield": "round", "shield_col": Color(0.66, 0.50, 0.28), "emblem": "chevron", "emblem_col": Color(0.78, 0.16, 0.16),
		"armor_col": Color(0.56, 0.38, 0.24), "randomize": ["skin"]},
	"paladin": {"eyes": "tall", "title": "Paladin", "armor": "gold", "helm": "visor", "hat_col": Color(0.96, 0.92, 0.80), "tabard": Color(0.97, 0.96, 0.92), "cross": Color(0.90, 0.72, 0.26),
		"cape": Color(0.97, 0.96, 0.92), "cloth": Color(0.92, 0.90, 0.84), "pants": Color(0.62, 0.52, 0.30), "weapon": "mace", "shield": "kite",
		"shield_col": Color(0.97, 0.96, 0.92), "emblem": "star", "emblem_col": Color(0.90, 0.72, 0.26), "randomize": []},
	# --- royalty
	"princess": {"title": "Princess", "dress": true, "frill": true, "helm": "crown", "hat": "wavy", "hair": Color(0.96, 0.78, 0.30), "cloth": Color(0.62, 0.40, 0.82),
		"frill_col": Color(0.96, 0.88, 0.98), "sash": Color(0.96, 0.80, 0.34), "weapon": "wand", "eyes": "lash", "face": "kind", "cheeks": "blush", "randomize": ["skin"]},
	"queen": {"title": "Queen", "dress": true, "frill": true, "helm": "crown", "hat": "bun", "hair": Color(0.30, 0.18, 0.12), "cloth": Color(0.74, 0.20, 0.34),
		"frill_col": Color(0.96, 0.90, 0.80), "sash": Color(0.96, 0.80, 0.34), "cloak": Color(0.52, 0.12, 0.24), "weapon": "wand", "eyes": "lash", "randomize": ["skin"]},
	"king": {"eyes": "small", "title": "King", "helm": "crown", "cloak": Color(0.72, 0.14, 0.18), "cloth": Color(0.40, 0.26, 0.62), "pants": Color(0.30, 0.20, 0.44), "beard": "long",
		"hat": "slick", "hair": Color(0.88, 0.88, 0.90), "weapon": "mace", "belt": Color(0.90, 0.72, 0.28), "face": "kind", "randomize": ["skin"]},
	"noble": {"eyes": "narrow", "title": "Noble", "helm": "tophat", "hat_col": Color(0.18, 0.14, 0.22), "band_col": Color(0.60, 0.18, 0.40), "cloth": Color(0.46, 0.22, 0.52), "pants": Color(0.22, 0.18, 0.28),
		"hat": "slick", "vest": Color(0.86, 0.74, 0.34), "scarf": Color(0.95, 0.94, 0.90), "weapon": "crook", "mustache": true, "face": "sly", "randomize": ["skin", "hair"]},
	# --- magic and faith
	"wizard": {"eyes": "small", "title": "Wizard", "helm": "wizard", "robe": Color(0.30, 0.34, 0.74), "trim": Color(0.92, 0.80, 0.36), "beard": "long", "face": "old", "weapon": "staff",
		"orb": Color(0.50, 0.88, 0.98), "pants": Color(0.2, 0.2, 0.3), "randomize": ["skin"]},
	"witch": {"eyes": "lash", "title": "Witch", "helm": "witch", "robe": Color(0.30, 0.20, 0.42), "trim": Color(0.62, 0.84, 0.34), "hat": "wavy", "hair": Color(0.18, 0.12, 0.20),
		"weapon": "broom", "face": "sly", "nose": "small", "randomize": ["skin"]},
	"priest": {"eyes": "happy", "title": "Priest", "robe": Color(0.96, 0.94, 0.88), "trim": Color(0.90, 0.74, 0.32), "hat": "bald", "scarf": Color(0.90, 0.74, 0.32), "weapon": "book",
		"face": "kind", "randomize": ["skin"]},
	"monk": {"eyes": "happy", "title": "Monk", "robe": Color(0.80, 0.52, 0.22), "trim": Color(0.96, 0.90, 0.78), "hat": "monk", "hair": Color(0.32, 0.20, 0.12), "weapon": "crook",
		"face": "kind", "randomize": ["skin"]},
	"alchemist": {"eyes": "round", "title": "Alchemist", "cloth": Color(0.34, 0.58, 0.48), "apron": Color(0.58, 0.40, 0.28), "goggles": true, "hat": "messy", "hair": Color(0.88, 0.88, 0.80),
		"pants": Color(0.30, 0.26, 0.24), "weapon": "lantern", "offhand": "book", "randomize": ["skin"]},
	"bard": {"eyes": "dot", "title": "Bard", "hat": "sweep", "helm": "tricorn", "hat_col": Color(0.24, 0.52, 0.56), "cloth": Color(0.86, 0.40, 0.36), "pants": Color(0.30, 0.34, 0.44), "cloak": Color(0.30, 0.56, 0.60),
		"weapon": "lute", "face": "kind", "randomize": ["skin", "hair"]},
	# --- trade and travel
	"merchant": {"eyes": "dot", "title": "Merchant", "helm": "bowler", "hat_col": Color(0.46, 0.28, 0.20), "pack": "tower", "pack_col": Color(0.66, 0.46, 0.28), "pack2": Color(0.30, 0.52, 0.62),
		"cloth": Color(0.82, 0.58, 0.24), "pants": Color(0.36, 0.28, 0.22), "scarf": Color(0.84, 0.28, 0.26), "mustache": true, "weapon": "none", "randomize": ["skin", "hair"]},
	"peddler": {"eyes": "narrow", "title": "Peddler", "helm": "beanie", "hat_col": Color(0.36, 0.56, 0.38), "pack": "sack", "cloth": Color(0.52, 0.40, 0.58), "pants": Color(0.30, 0.28, 0.30),
		"weapon": "lantern", "face": "sly", "randomize": ["skin", "hair"]},
	"nomad_merchant": {"eyes": "dot", "title": "Caravan Trader", "helm": "turban", "hat_col": Color(0.92, 0.46, 0.30), "robe": Color(0.94, 0.86, 0.66), "trim": Color(0.76, 0.22, 0.20),
		"pack": "tower", "pack_col": Color(0.78, 0.36, 0.28), "pack2": Color(0.28, 0.52, 0.64), "mustache": true, "weapon": "none", "randomize": ["skin"]},
	"pilgrim": {"eyes": "sleepy", "title": "Pilgrim", "helm": "hood", "hat_col": Color(0.52, 0.42, 0.30), "cloth": Color(0.66, 0.56, 0.42), "pants": Color(0.38, 0.30, 0.24), "pack": "bedroll",
		"weapon": "crook", "scarf": Color(0.80, 0.70, 0.40), "randomize": ["skin"]},
	"ranger": {"eyes": "tall", "title": "Ranger", "helm": "hood", "hat_col": Color(0.28, 0.46, 0.30), "armor": "leather", "cloth": Color(0.34, 0.54, 0.34), "pants": Color(0.36, 0.30, 0.22),
		"cape": Color(0.24, 0.40, 0.28), "weapon": "bow", "randomize": ["skin"]},
	"rogue": {"eyes": "narrow", "title": "Rogue", "helm": "hood", "hat_col": Color(0.24, 0.22, 0.30), "armor": "leather", "armor_col": Color(0.30, 0.26, 0.32), "cloth": Color(0.28, 0.26, 0.34),
		"pants": Color(0.20, 0.18, 0.24), "scarf": Color(0.70, 0.18, 0.24), "cloak": Color(0.22, 0.20, 0.28), "weapon": "dagger", "face": "sly", "randomize": ["skin"]},
	"nomad": {"eyes": "tall", "title": "Desert Nomad", "helm": "turban", "hat_col": Color(0.96, 0.94, 0.88), "robe": Color(0.88, 0.74, 0.50), "trim": Color(0.62, 0.30, 0.22), "scarf": Color(0.62, 0.30, 0.22),
		"weapon": "crook", "beard": "goatee", "randomize": ["skin"]},
	"trapper": {"eyes": "dot", "title": "Snow Trapper", "helm": "fur", "hat_col": Color(0.74, 0.62, 0.50), "cloth": Color(0.36, 0.50, 0.70), "armor": "leather", "armor_col": Color(0.70, 0.58, 0.46),
		"scarf": Color(0.86, 0.26, 0.26), "pants": Color(0.30, 0.28, 0.34), "pack": "bedroll", "weapon": "spear", "beard": "short", "randomize": ["skin"]},
	# --- country and craft
	"farmer": {"eyes": "dot", "title": "Farmer", "hat": "messy", "helm": "straw", "hat_col": Color(0.94, 0.82, 0.46), "band": Color(0.78, 0.26, 0.24), "cloth": Color(0.86, 0.78, 0.52), "apron": Color(0.30, 0.46, 0.70),
		"pants": Color(0.30, 0.46, 0.70), "weapon": "pitchfork", "face": "kind", "randomize": ["skin", "hair"]},
	"harvester": {"eyes": "tall", "title": "Harvester", "hat": "curly", "helm": "straw", "hat_col": Color(0.92, 0.78, 0.42), "band": Color(0.34, 0.50, 0.30), "cloth": Color(0.80, 0.30, 0.28), "pants": Color(0.38, 0.30, 0.22),
		"weapon": "scythe", "pack": "basket", "randomize": ["skin", "hair"]},
	"miner": {"eyes": "small", "title": "Miner", "helm": "hardhat", "hat_col": Color(0.96, 0.78, 0.22), "cloth": Color(0.52, 0.48, 0.44), "pants": Color(0.36, 0.30, 0.26), "weapon": "pickaxe",
		"beard": "short", "face": "grumpy", "nose": "small", "randomize": ["skin", "hair"]},
	"blacksmith": {"title": "Blacksmith", "apron": Color(0.30, 0.24, 0.20), "goggles": true, "hat": "short", "hair": Color(0.18, 0.12, 0.08), "cloth": Color(0.66, 0.36, 0.26),
		"pants": Color(0.28, 0.24, 0.24), "weapon": "hammer", "beard": "short", "armor": "leather", "armor_col": Color(0.34, 0.26, 0.20), "face": "grumpy", "randomize": ["skin"]},
	"baker": {"eyes": "happy", "title": "Baker", "helm": "toque", "hat_col": Color(0.97, 0.96, 0.92), "apron": Color(0.97, 0.95, 0.90), "cloth": Color(0.92, 0.78, 0.68), "pants": Color(0.46, 0.38, 0.36),
		"weapon": "pin", "face": "kind", "cheeks": "blush", "randomize": ["skin", "hair"]},
	"fisher": {"eyes": "sleepy", "title": "Fisher", "hat": "sweep", "helm": "straw", "hat_col": Color(0.70, 0.78, 0.60), "band": Color(0.26, 0.42, 0.68), "cloth": Color(0.30, 0.50, 0.62), "vest": Color(0.84, 0.70, 0.36),
		"pants": Color(0.36, 0.34, 0.32), "weapon": "fishing_rod", "beard": "short", "randomize": ["skin", "hair"]},
	"sailor": {"eyes": "line", "title": "Sailor", "helm": "sailor", "cloth": Color(0.96, 0.96, 0.94), "stripes": Color(0.24, 0.34, 0.60), "pants": Color(0.24, 0.32, 0.54), "scarf": Color(0.84, 0.26, 0.26),
		"weapon": "none", "face": "sly", "randomize": ["skin", "hair"]},
	# --- city
	"office": {"eyes": "dot", "title": "Office Worker", "hat": "slick", "cloth": Color(0.28, 0.32, 0.42), "shirt": Color(0.97, 0.97, 0.96), "tie": Color(0.78, 0.18, 0.22), "pants": Color(0.24, 0.27, 0.36),
		"glasses": true, "weapon": "briefcase", "randomize": ["skin", "hair"]},
	"engineer": {"eyes": "round", "title": "Engineer", "helm": "hardhat", "hat_col": Color(0.97, 0.97, 0.95), "goggles": true, "cloth": Color(0.90, 0.52, 0.18), "vest": Color(0.96, 0.84, 0.24),
		"pants": Color(0.30, 0.34, 0.44), "weapon": "wrench", "randomize": ["skin", "hair"]},
	"scholar": {"eyes": "tall", "title": "Scholar", "glasses": true, "hat": "bowl", "cloth": Color(0.52, 0.24, 0.30), "pants": Color(0.26, 0.24, 0.30), "scarf": Color(0.88, 0.80, 0.52),
		"weapon": "book", "beard": "goatee", "face": "kind", "randomize": ["skin", "hair"]},
	"hermit": {"title": "Old Hermit", "face": "grumpy", "nose": "big", "beard": "long", "hat": "monk", "cloak": Color(0.46, 0.40, 0.28), "cloth": Color(0.58, 0.52, 0.36),
		"pants": Color(0.34, 0.30, 0.24), "weapon": "crook", "pack": "bedroll", "skin": Color(0.92, 0.74, 0.62), "randomize": []},
	"child": {"title": "Child", "face": "child", "hat": "twin", "cloth": Color(0.60, 0.80, 0.56), "pants": Color(0.40, 0.44, 0.60),
		"weapon": "none", "randomize": ["skin", "hair"]},

	# --- the original job looks, improved (keys match main.gd LOOKS)
	"job_bakery": {"title": "Baker", "helm": "toque", "hat_col": Color(0.97, 0.96, 0.92), "apron": Color(0.97, 0.95, 0.90), "weapon": "pin", "face": "kind", "randomize": ["skin", "hair", "cloth", "pants"]},
	"job_market": {"title": "Shopkeeper", "helm": "bowler", "hat_col": Color(0.30, 0.40, 0.70), "apron": Color(0.42, 0.62, 0.40), "scarf": Color(0.94, 0.86, 0.60), "weapon": "sack",
		"mustache": true, "randomize": ["skin", "hair", "cloth", "pants"]},
	"job_tavern": {"title": "Innkeeper", "hat": "short", "weapon": "mug", "beard": "short", "apron": Color(0.62, 0.52, 0.40), "vest": Color(0.52, 0.30, 0.24), "face": "kind",
		"randomize": ["skin", "hair", "cloth", "pants"]},
	"job_smithy": {"title": "Smith", "hat": "short", "weapon": "hammer", "apron": Color(0.30, 0.24, 0.20), "goggles": true, "beard": "short", "face": "grumpy", "armor": "leather",
		"armor_col": Color(0.34, 0.26, 0.20), "randomize": ["skin", "hair", "cloth", "pants"]},
	"job_lodge": {"title": "Hunter", "helm": "hood", "hat_col": Color(0.30, 0.48, 0.28), "armor": "leather", "weapon": "spear", "cloak": Color(0.26, 0.42, 0.26), "randomize": ["skin", "hair", "cloth", "pants"]},
	"job_guard": {"title": "Guard", "armor": "chain", "helm": "kettle", "hat_col": Color(0.74, 0.76, 0.80), "tabard": {"a": Color(0.70, 0.20, 0.18), "b": Color(0.94, 0.90, 0.82)},
		"weapon": "spear", "cape": Color(0.70, 0.20, 0.18), "randomize": ["skin", "hair"]},
}

## Archetype ids that fit each themed city.
const CITY_FOLK := {
	"home": ["farmer", "harvester", "baker", "child", "scholar", "bard", "peddler", "monk", "priest", "fisher", "noble"],
	"heights": ["office", "engineer", "noble", "scholar", "alchemist", "merchant", "bard", "child", "royal_guard", "priest"],
	"souk": ["nomad", "nomad_merchant", "merchant", "peddler", "bard", "rogue", "alchemist", "child", "witch", "gladiator"],
	"port": ["fisher", "sailor", "merchant", "peddler", "bard", "rogue", "ranger", "child", "pilgrim"],
	"copper": ["miner", "blacksmith", "engineer", "office", "merchant", "farmer", "child", "royal_guard"],
	"frost": ["trapper", "ranger", "monk", "pilgrim", "hermit", "child", "bard", "blacksmith", "viking"],
	"road": ["pilgrim", "peddler", "merchant", "nomad_merchant", "ranger", "bard", "rogue", "nomad", "knight", "paladin", "viking", "valkyrie",
		"gladiator", "wizard", "witch", "trapper", "hermit", "monk"],
}

## Gatekeepers per city (use for guards standing around).
const CITY_GUARD := {
	"home": "job_guard", "heights": "royal_guard", "souk": "gladiator", "port": "job_guard", "copper": "royal_guard", "frost": "viking",
}

## Travelling merchants.
const MERCHANT_IDS := ["merchant", "peddler", "nomad_merchant"]


static func get_look(id: String) -> Dictionary:
	if LOOKS.has(id):
		return (LOOKS[id] as Dictionary).duplicate(true)
	return {}


static func ids() -> Array:
	return LOOKS.keys()


## A random archetype id for a city theme ("home", "heights", ...).
static func pick_for_city(city: String, rng: RandomNumberGenerator) -> String:
	var list: Array = CITY_FOLK.get(city, CITY_FOLK["home"])
	return list[rng.randi() % list.size()]


## Fills the keys listed in the look's "randomize" array with random values
## (skin, hair, cloth, pants) so a crowd of one archetype does not look cloned.
## Keys that are not listed (or not present in "randomize") stay as authored.
static func randomized(id: String, rng: RandomNumberGenerator, skins: Array, hairs: Array) -> Dictionary:
	var look := get_look(id)
	var which: Array = look.get("randomize", [])
	if "skin" in which and not skins.is_empty():
		look["skin"] = skins[rng.randi() % skins.size()]
	if "hair" in which and not hairs.is_empty() and look.get("face", "") != "old":
		look["hair"] = hairs[rng.randi() % hairs.size()]
	if "cloth" in which:
		look["cloth"] = Color.from_hsv(rng.randf(), 0.45, 0.88)
	if "pants" in which:
		look["pants"] = Color.from_hsv(rng.randf(), 0.25, 0.40)
	return look
