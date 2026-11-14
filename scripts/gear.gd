## Things the player can wear and carry: hats, armour, clothes and weapons.
## Bought with coins at the armoury (smithy, foundry) and the hatter (weaver,
## market). The coins go into that shop's till, so none are made or lost.
## What you own and wear lives in Game.hero["owned"] and Game.hero["equip"].
class_name Gear
extends Object

## Hairstyles for the character creator: [label, paint style].
const HAIR := [
	["Spiky", "spiky"], ["Short", "short"], ["Messy", "messy"], ["Sweep", "sweep"], ["Slick", "slick"],
	["Bowl", "bowl"], ["Curly", "curly"], ["Tuft", "ahoge"], ["Long", "long"], ["Wavy", "wavy"],
	["Bob", "bob"], ["Ponytail", "pony"], ["Pigtails", "twin"], ["Bun", "bun"], ["Twin buns", "twinbun"],
	["Braid", "braid"], ["Shaved", "bald"],
]

const SLOT_NAMES := {"hat": "Hats", "armor": "Armour", "clothes": "Clothes", "weapon": "Weapons"}
const SLOT_ORDER := ["hat", "armor", "clothes", "weapon"]

## id -> {name, slot, price, shop ("armoury" | "hatter"), look (merged into the
## paint dictionary), def (damage taken is cut by this share), atk (damage is
## multiplied by 1 + this)}
const ITEMS := {
	# hats: for show, from the hatter
	"straw": {"name": "Straw hat", "slot": "hat", "price": 12, "shop": "hatter", "look": {"helm": "straw", "hat_col": Color(0.93, 0.80, 0.45), "band": Color(0.78, 0.26, 0.24)}},
	"beanie": {"name": "Beanie", "slot": "hat", "price": 8, "shop": "hatter", "look": {"helm": "beanie"}},
	"cap": {"name": "Flat cap", "slot": "hat", "price": 10, "shop": "hatter", "look": {"helm": "cap", "hat_col": Color(0.30, 0.40, 0.70)}},
	"hood": {"name": "Green hood", "slot": "hat", "price": 10, "shop": "hatter", "look": {"helm": "hood"}},
	"sailor": {"name": "Sailor cap", "slot": "hat", "price": 14, "shop": "hatter", "look": {"helm": "sailor"}},
	"toque": {"name": "Chef's toque", "slot": "hat", "price": 12, "shop": "hatter", "look": {"helm": "toque", "hat_col": Color(0.97, 0.96, 0.92)}},
	"turban": {"name": "Turban", "slot": "hat", "price": 20, "shop": "hatter", "look": {"helm": "turban"}},
	"bowler": {"name": "Bowler hat", "slot": "hat", "price": 22, "shop": "hatter", "look": {"helm": "bowler"}},
	"fur": {"name": "Fur hat", "slot": "hat", "price": 26, "shop": "hatter", "look": {"helm": "fur"}},
	"tricorn": {"name": "Tricorn", "slot": "hat", "price": 28, "shop": "hatter", "look": {"helm": "tricorn"}},
	"tophat": {"name": "Top hat", "slot": "hat", "price": 30, "shop": "hatter", "look": {"helm": "tophat"}},
	"witch": {"name": "Witch hat", "slot": "hat", "price": 36, "shop": "hatter", "look": {"helm": "witch"}},
	"wizard": {"name": "Wizard hat", "slot": "hat", "price": 40, "shop": "hatter", "look": {"helm": "wizard"}},
	"crown": {"name": "Gold crown", "slot": "hat", "price": 400, "shop": "hatter", "look": {"helm": "crown"}},
	# helmets: protect, from the armoury
	"hardhat": {"name": "Hard hat", "slot": "hat", "price": 25, "shop": "armoury", "def": 0.03, "look": {"helm": "hardhat"}},
	"helmet": {"name": "Iron helmet", "slot": "hat", "price": 40, "shop": "armoury", "def": 0.05, "look": {"helm": "helmet"}},
	"kettle": {"name": "Kettle helm", "slot": "hat", "price": 55, "shop": "armoury", "def": 0.07, "look": {"helm": "kettle"}},
	"visor": {"name": "Knight's visor", "slot": "hat", "price": 90, "shop": "armoury", "def": 0.10, "look": {"helm": "visor"}},
	"plume": {"name": "Plumed knight helm", "slot": "hat", "price": 120, "shop": "armoury", "def": 0.11, "look": {"helm": "plume"}},
	"viking": {"name": "Horned helm", "slot": "hat", "price": 110, "shop": "armoury", "def": 0.10, "look": {"helm": "viking"}},
	"winged": {"name": "Winged helm", "slot": "hat", "price": 170, "shop": "armoury", "def": 0.12, "look": {"helm": "winged"}},
	# body armour
	"leather": {"name": "Leather armour", "slot": "armor", "price": 45, "shop": "armoury", "def": 0.08, "look": {"armor": "leather"}},
	"chain": {"name": "Chain mail", "slot": "armor", "price": 130, "shop": "armoury", "def": 0.15, "look": {"armor": "chain"}},
	"steel": {"name": "Steel plate", "slot": "armor", "price": 240, "shop": "armoury", "def": 0.22, "look": {"armor": "steel"}},
	"gold": {"name": "Gilded plate", "slot": "armor", "price": 650, "shop": "armoury", "def": 0.28, "look": {"armor": "gold"}},
	# clothes: for show, from the hatter
	"cape_red": {"name": "Red cape", "slot": "clothes", "price": 30, "shop": "hatter", "look": {"cape": Color(0.70, 0.20, 0.18)}},
	"cape_blue": {"name": "Blue cloak", "slot": "clothes", "price": 30, "shop": "hatter", "look": {"cloak": Color(0.28, 0.40, 0.68)}},
	"scarf": {"name": "Warm scarf", "slot": "clothes", "price": 14, "shop": "hatter", "look": {"scarf": Color(0.84, 0.28, 0.26)}},
	"robe_blue": {"name": "Blue robe", "slot": "clothes", "price": 48, "shop": "hatter", "look": {"robe": Color(0.30, 0.38, 0.70), "trim": Color(0.92, 0.80, 0.40)}},
	"robe_plum": {"name": "Plum robe", "slot": "clothes", "price": 48, "shop": "hatter", "look": {"robe": Color(0.50, 0.28, 0.52), "trim": Color(0.92, 0.80, 0.40)}},
	"dress_rose": {"name": "Rose dress", "slot": "clothes", "price": 55, "shop": "hatter", "look": {"dress": true, "frill": true, "cloth": Color(0.86, 0.42, 0.56)}},
	"dress_sky": {"name": "Sky dress", "slot": "clothes", "price": 55, "shop": "hatter", "look": {"dress": true, "frill": true, "cloth": Color(0.42, 0.62, 0.86)}},
	"apron": {"name": "Work apron", "slot": "clothes", "price": 12, "shop": "hatter", "look": {"apron": Color(0.58, 0.40, 0.28)}},
	# weapons
	"dagger": {"name": "Dagger", "slot": "weapon", "price": 18, "shop": "armoury", "atk": 0.03, "look": {"weapon": "dagger"}},
	"sword": {"name": "Short sword", "slot": "weapon", "price": 40, "shop": "armoury", "atk": 0.08, "look": {"weapon": "sword"}},
	"spear": {"name": "Spear", "slot": "weapon", "price": 55, "shop": "armoury", "atk": 0.10, "look": {"weapon": "spear"}},
	"mace": {"name": "Mace", "slot": "weapon", "price": 70, "shop": "armoury", "atk": 0.13, "look": {"weapon": "mace"}},
	"broadsword": {"name": "Broadsword", "slot": "weapon", "price": 150, "shop": "armoury", "atk": 0.22, "look": {"weapon": "broadsword"}},
	"double_axe": {"name": "Battle axe", "slot": "weapon", "price": 210, "shop": "armoury", "atk": 0.30, "look": {"weapon": "double_axe"}},
}


## Which gear shop a town building is (or "" if it sells none).
static func shop_type(kind: String) -> String:
	if kind in ["smithy", "foundry"]:
		return "armoury"
	if kind in ["weaver", "market"]:
		return "hatter"
	return ""


static func shop_title(t: String) -> String:
	return "Weapons and armour" if t == "armoury" else "Hats and clothes"


static func items_for(t: String, slot: String) -> Array:
	var out: Array = []
	for id in ITEMS:
		if ITEMS[id]["shop"] == t and ITEMS[id]["slot"] == slot:
			out.append(id)
	out.sort_custom(func(a, b): return int(ITEMS[a]["price"]) < int(ITEMS[b]["price"]))
	return out


static func ensure() -> void:
	if not Game.hero.has("owned"):
		Game.hero["owned"] = []
	if not Game.hero.has("equip"):
		Game.hero["equip"] = {}
	if not Game.hero.has("style"):
		Game.hero["style"] = 0


static func owns(id: String) -> bool:
	ensure()
	return id in (Game.hero["owned"] as Array)


static func worn(id: String) -> bool:
	ensure()
	return str((Game.hero["equip"] as Dictionary).get(str(ITEMS[id]["slot"]), "")) == id


## Buy `id` from the till `shop_id`: the price moves from the player to the shop.
static func buy(id: String, shop_id: String) -> bool:
	ensure()
	if owns(id) or not ITEMS.has(id):
		return false
	if not Economy.pay("player", shop_id, int(ITEMS[id]["price"])):
		return false
	(Game.hero["owned"] as Array).append(id)
	return true


## Wears the item, or takes it off if it is already worn.
static func toggle(id: String) -> void:
	ensure()
	var slot := str(ITEMS[id]["slot"])
	var eq: Dictionary = Game.hero["equip"]
	if str(eq.get(slot, "")) == id:
		eq.erase(slot)
	else:
		eq[slot] = id
		# a dress and a robe are both a whole outfit: wear one at a time
		if slot == "clothes":
			pass


## Look keys for what the player wears, ready to merge into the paint dictionary.
static func look(equip: Dictionary) -> Dictionary:
	var out := {}
	for slot in SLOT_ORDER:
		var id := str(equip.get(slot, ""))
		if ITEMS.has(id):
			out.merge(ITEMS[id]["look"], true)
	return out


static func _sum(key: String) -> float:
	ensure()
	var t := 0.0
	for slot in (Game.hero["equip"] as Dictionary):
		var id := str((Game.hero["equip"] as Dictionary)[slot])
		if ITEMS.has(id):
			t += float(ITEMS[id].get(key, 0.0))
	return t


## Share of damage taken that armour and helmets turn away (capped).
static func defence() -> float:
	return minf(_sum("def"), 0.6)


## Damage multiplier from the wielded weapon.
static func attack() -> float:
	return 1.0 + _sum("atk")


static func effect_text(id: String) -> String:
	var it: Dictionary = ITEMS[id]
	if it.has("def"):
		return "-%d%% damage taken" % int(round(float(it["def"]) * 100.0))
	if it.has("atk"):
		return "+%d%% damage" % int(round(float(it["atk"]) * 100.0))
	return "for looks"
