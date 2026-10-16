class_name GameData
extends RefCounted

const LEGACY_MOVES := {
	"tackle": {"name":"Tackle", "type":"normal", "power":10, "accuracy":0.95, "kind":"damage"},
	"vine_whip": {"name":"Vine Whip", "type":"grass", "power":14, "accuracy":0.95, "kind":"damage"},
	"razor_leaf": {"name":"Razor Leaf", "type":"grass", "power":18, "accuracy":0.85, "kind":"damage"},
	"growl": {"name":"Growl", "type":"normal", "power":0, "accuracy":1.0, "kind":"debuff"},
	"scratch": {"name":"Scratch", "type":"normal", "power":11, "accuracy":0.95, "kind":"damage"},
	"ember": {"name":"Ember", "type":"fire", "power":14, "accuracy":0.95, "kind":"damage"},
	"flame_tail": {"name":"Flame Tail", "type":"fire", "power":19, "accuracy":0.82, "kind":"damage"},
	"focus": {"name":"Focus", "type":"normal", "power":0, "accuracy":1.0, "kind":"buff"},
	"water_gun": {"name":"Water Gun", "type":"water", "power":14, "accuracy":0.95, "kind":"damage"},
	"bubble": {"name":"Bubble", "type":"water", "power":17, "accuracy":0.88, "kind":"damage"},
	"shell_rest": {"name":"Shell Rest", "type":"water", "power":14, "accuracy":1.0, "kind":"heal"},
	"quick_attack": {"name":"Quick Attack", "type":"normal", "power":12, "accuracy":1.0, "kind":"damage"},
	"gust": {"name":"Gust", "type":"normal", "power":13, "accuracy":0.92, "kind":"damage"},
	"bite": {"name":"Bite", "type":"normal", "power":15, "accuracy":0.90, "kind":"damage"},
	"absorb": {"name":"Absorb", "type":"grass", "power":12, "accuracy":0.95, "kind":"damage"},
	"rock_throw": {"name":"Rock Throw", "type":"rock", "power":18, "accuracy":0.82, "kind":"damage"},
	"thunder_shock": {"name":"Thunder Shock", "type":"electric", "power":15, "accuracy":0.92, "kind":"damage"}
}

static var MOVES: Dictionary = build_moves()

static func build_moves() -> Dictionary:
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/machine_moves.json"))
	for move in result.values(): move.power = float(move.power)/4.0
	for id in LEGACY_MOVES:
		var entry: Dictionary = result.get(id,{}).duplicate(true)
		entry.merge(LEGACY_MOVES[id],true)
		entry.merge({"pp":35,"target":7 if entry.kind in ["heal","buff"] else 10,"priority":0},false)
		result[id] = entry
	for id in LEGACY_MOVES:
		if result[id].kind == "damage": result[id].effect_id = int(result[id].get("effect_id",1))
	result.ember.merge({"meta_ailment_id":4,"ailment_chance":10},true)
	result.thunder_shock.merge({"meta_ailment_id":1,"ailment_chance":10},true)
	result.bite.flinch_chance = 30
	result.absorb.drain = 50
	# Original custom moves share the same damage and secondary-effect resolver.
	result.flame_tail.merge({"effect_id":5,"meta_ailment_id":4,"ailment_chance":10},true)
	result.gust.type = "flying"
	result.bite.type = "dark"
	for id in LEGACY_MOVES:
		result[id].move_index = int(PendingItems.data().get("move_ids",{}).get(id,0))
		result[id].damage_class = 3 if id in ["ember","flame_tail","water_gun","bubble","absorb","thunder_shock"] else 2
	return result

const LEGACY_SPECIES := {
	"bulbasaur": {"name":"Bulbasaur", "type":"grass", "max_hp":64, "attack":13, "defense":13, "color":"#72c987", "accent":"#2f8d63", "moves":["tackle","vine_whip","razor_leaf","growl"]},
	"charmander": {"name":"Charmander", "type":"fire", "max_hp":58, "attack":15, "defense":10, "color":"#f49a55", "accent":"#f45b45", "moves":["scratch","ember","flame_tail","focus"]},
	"squirtle": {"name":"Squirtle", "type":"water", "max_hp":68, "attack":12, "defense":15, "color":"#71c8d4", "accent":"#476fb3", "moves":["tackle","water_gun","bubble","shell_rest"]},
	"caterpie": {"name":"Caterpie", "type":"grass", "max_hp":34, "attack":8, "defense":8, "color":"#8fd15d", "accent":"#e9685a", "moves":["tackle","absorb"]},
	"pidgey": {"name":"Pidgey", "type":"normal", "max_hp":38, "attack":10, "defense":9, "color":"#c9a56c", "accent":"#f1e1ad", "moves":["tackle","gust"]},
	"rattata": {"name":"Rattata", "type":"normal", "max_hp":40, "attack":11, "defense":8, "color":"#9c79bd", "accent":"#f0c1d0", "moves":["tackle","quick_attack"]},
	"oddish": {"name":"Oddish", "type":"grass", "max_hp":43, "attack":10, "defense":10, "color":"#617bc2", "accent":"#6cc36b", "moves":["absorb","tackle","growl"]},
	"growlithe": {"name":"Growlithe", "type":"fire", "max_hp":48, "attack":13, "defense":10, "color":"#ef8c45", "accent":"#f5dfb5", "moves":["bite","ember"]},
	"psyduck": {"name":"Psyduck", "type":"water", "max_hp":51, "attack":12, "defense":11, "color":"#e8c84f", "accent":"#f4e69f", "moves":["scratch","water_gun"]},
	"sandshrew": {"name":"Sandshrew", "type":"rock", "max_hp":52, "attack":13, "defense":14, "color":"#d8ad63", "accent":"#9b7749", "moves":["scratch","rock_throw"]},
	"magnemite": {"name":"Magnemite", "type":"electric", "max_hp":46, "attack":14, "defense":13, "color":"#bac7cf", "accent":"#5b81ac", "moves":["tackle","thunder_shock"]},
	"jigglypuff": {"name":"Jigglypuff", "type":"normal", "max_hp":60, "attack":10, "defense":9, "color":"#eea8c8", "accent":"#8ac0d9", "moves":["tackle","focus","quick_attack"]},
	"meowth": {"name":"Meowth", "type":"normal", "max_hp":50, "attack":14, "defense":9, "color":"#ead9a6", "accent":"#c59454", "moves":["scratch","bite","growl"]},
	"onix": {"name":"Onix", "type":"rock", "max_hp":76, "attack":15, "defense":18, "color":"#8f969d", "accent":"#5e6870", "moves":["tackle","rock_throw","growl"]},
	"pikachu": {"name":"Pikachu", "type":"electric", "max_hp":50, "attack":15, "defense":9, "color":"#f5d84d", "accent":"#a96b42", "moves":["quick_attack","thunder_shock","growl"]},
	"eevee": {"name":"Eevee", "type":"normal", "max_hp":54, "attack":13, "defense":11, "color":"#b98558", "accent":"#f0d5aa", "moves":["tackle","quick_attack","bite"]}
}

static var SPECIES: Dictionary = ItemProgression.extend_species(LEGACY_SPECIES)

const ENCOUNTERS := {
	"meadow_1": {"enemies":["caterpie"], "rewards":{"potion":1,"apricorn_ball":2}},
	"brook_2": {"enemies":["pidgey","oddish"], "rewards":{"berry":2,"apricorn_ball":1}},
	"forest_2": {"enemies":["rattata","growlithe"], "rewards":{"potion":1,"great_apricorn_ball":1}},
	"ridge_3": {"enemies":["sandshrew","magnemite","psyduck"], "rewards":{"super_potion":1,"great_apricorn_ball":2}},
	"falls_2": {"enemies":["psyduck","jigglypuff"], "rewards":{"potion":2,"apricorn_ball":2}},
	"summit_3": {"enemies":["onix","growlithe","pikachu"], "rewards":{"super_potion":2,"great_apricorn_ball":3,"star_berry":1}}
}

const LEGACY_ITEMS := {
	"potion": {"name":"Potion", "description":"Restores 25 HP.", "kind":"heal", "amount":25},
	"super_potion": {"name":"Super Potion", "description":"Restores 50 HP.", "kind":"heal", "amount":50},
	"berry": {"name":"Sweet Berry", "description":"Restores 12 HP.", "kind":"heal", "amount":12},
	"star_berry": {"name":"Star Berry", "description":"A sparkling island keepsake.", "kind":"treasure", "amount":0},
	"apricorn_ball": {"name":"Apricorn Ball", "description":"Green ball; standard catch chance.", "kind":"ball", "bonus":0.20},
	"great_apricorn_ball": {"name":"Great Apricorn Ball", "description":"Blue ball; improved catch chance.", "kind":"ball", "bonus":0.40}
}

static var ITEMS: Dictionary = ItemCatalog.build(LEGACY_ITEMS)
static var DLC_ITEMS: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/spinoff_dlc_items.json")).items

const NODES := [
	{"id":"airstrip","name":"Sunny Airstrip","kind":"start","pos":Vector2(70,590),"links":["meadow"],"prereq":[]},
	{"id":"meadow","name":"Petal Meadow","kind":"battle","encounter":"meadow_1","pos":Vector2(168,590),"links":["airstrip","green_chest","brook"],"prereq":["airstrip"]},
	{"id":"green_chest","name":"Palm Trail","kind":"battle","encounter":"meadow_1","pos":Vector2(266,590),"links":["meadow","forest"],"prereq":["meadow"],"reward":{"potion":2,"apricorn_ball":3}},
	{"id":"brook","name":"Sparkle Brook","kind":"battle","encounter":"brook_2","pos":Vector2(364,590),"links":["meadow","camp","mystery"],"prereq":["meadow"]},
	{"id":"forest","name":"Whisper Forest","kind":"battle","encounter":"forest_2","pos":Vector2(462,590),"links":["green_chest","camp","falls"],"prereq":["green_chest"]},
	{"id":"camp","name":"Berry Grove","kind":"battle","encounter":"forest_2","pos":Vector2(560,590),"links":["brook","forest","ridge"],"prereq":["brook"]},
	{"id":"mystery","name":"Misty Hollow","kind":"mystery","pos":Vector2(658,590),"links":["brook","blue_chest"],"prereq":["brook"]},
	{"id":"falls","name":"Rainbow Falls","kind":"battle","encounter":"falls_2","pos":Vector2(756,590),"links":["forest","ridge"],"prereq":["forest"]},
	{"id":"ridge","name":"Copper Ridge","kind":"battle","encounter":"ridge_3","pos":Vector2(854,590),"links":["camp","falls","blue_chest","summit"],"prereq":["camp"]},
	{"id":"blue_chest","name":"Cliffside Chest","kind":"chest","pos":Vector2(952,590),"links":["mystery","ridge","summit"],"prereq":["mystery"],"reward":{"super_potion":2,"great_apricorn_ball":2}},
	{"id":"summit","name":"Volcano Summit","kind":"boss","encounter":"summit_3","pos":Vector2(1050,590),"links":["ridge","blue_chest","lookout"],"prereq":["ridge"]},
	{"id":"lookout","name":"Champion Lookout","kind":"finish","pos":Vector2(1148,590),"links":["summit"],"prereq":["summit"]}
]

static func make_pokemon(species_id: String, metadata_rng: RandomNumberGenerator = null) -> Dictionary:
	var data: Dictionary = SPECIES[species_id]
	var pokemon := {"species":species_id,"hp":int(data.max_hp),"max_hp":int(data.max_hp),"attack":int(data.attack),"defense":int(data.defense),"attack_stage":0,"defense_stage":0}
	var rate := int(ItemMechanics.species(pokemon).get("gender_rate",-1))
	var gender_roll := metadata_rng.randi_range(0,7) if metadata_rng != null else randi_range(0,7)
	pokemon.gender = "genderless" if rate < 0 else ("female" if gender_roll < rate else "male")
	var iv_random := RandomNumberGenerator.new()
	if metadata_rng != null: iv_random.seed = hash("ivs:%d:%d" % [metadata_rng.seed,metadata_rng.state])
	else: iv_random.randomize()
	pokemon.ivs = ItemMechanics.roll_ivs(iv_random)
	ItemMechanics.initialize(pokemon)
	var nature_roll := metadata_rng.randi_range(0,ItemMechanics.data().natures.size()-1) if metadata_rng != null else randi_range(0,ItemMechanics.data().natures.size()-1)
	pokemon.nature = str(ItemMechanics.data().natures[nature_roll].identifier)
	return pokemon

