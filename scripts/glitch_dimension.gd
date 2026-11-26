extends RefCounted

const FLOOR_COUNT := 50
const BREAK_CHANCE := 2368
const PREFIX := "glitch_"
const Signals = preload("res://scripts/glitch_signals.gd")
const ROSTER := [
	["Staticling", "electric", "thunder_shock", 43, 10, 10],
	["Nullwing", "flying", "gust", 41, 11, 9],
	["Cachemite", "bug", "fury_cutter", 46, 12, 12],
	["Echo Husk", "normal", "quick_attack", 51, 10, 11],
	["Rasterjaw", "dark", "bite", 52, 13, 10],
	["Inksplice", "poison", "poison_sting", 47, 11, 12],
	["Buffer Eel", "water", "water_gun", 49, 12, 11],
	["Pixel Briar", "grass", "vine_whip", 50, 11, 14],
	["Dead Channel", "psychic", "confusion", 44, 13, 10],
	["Thermal Leak", "fire", "ember", 48, 13, 11],
	["Bitcrag", "rock", "rock_throw", 54, 12, 14],
	["Cold Reboot", "ice", "powder_snow", 50, 12, 12],
	["Ferrobyte", "steel", "metal_claw", 54, 13, 14],
	["Checksum", "dragon", "twister", 52, 14, 13],
	["Frame Eater", "ground", "mud_slap", 55, 13, 12],
	["Kernel Void", "dark", "snarl", 69, 15, 14],
]
const ITEM_STATS := {
	"heal_scrambled":["potion", "Scrambled Potion", 11, "common"],
	"heal_burst":["potion", "Burst Potion", 38, "uncommon"],
	"heal_leak":["super_potion", "Leaking Super Potion", 30, "common"],
	"heal_overflow":["super_potion", "Overflow Super Potion", 78, "rare"],
	"heal_zero":["potion", "Zero-Fill Potion", 55, "epic"],
	"heal_rollover":["potion", "Rollover Potion", 120, "legendary"],
	"revive_fragment":["item_revive", "Fragmented Revive", 0.25, "uncommon"],
	"revive_mirror":["item_revive", "Mirrored Revive", 0.75, "rare"],
	"revive_snapshot":["item_revive", "Snapshot Revive", 1.0, "legendary"],
	"pp_desync":["item_ether", "Desynced Ether", 4, "common"],
	"pp_overclock":["item_ether", "Overclocked Ether", 16, "epic"],
	"ball_frayed":["apricorn_ball", "Frayed Apricorn Ball", 0.08, "common"],
	"ball_phase":["great_apricorn_ball", "Phase Apricorn Ball", 0.58, "epic"],
	"ball_impossible":["great_apricorn_ball", "Impossible Apricorn Ball", 0.80, "legendary"],
}
const CACHE_ODDS := [
	[10, 12, 18, 42, 18],
	[45, 3, 7, 10, 35],
	[4, 46, 30, 5, 15],
	[20, 5, 5, 15, 55],
	[2, 33, 40, 20, 5],
]

static func species_id(index: int) -> String:
	return "anomaly_%02d" % index

static func signal_shape(signal_id: String) -> int:
	return posmod(hash(signal_id), ROSTER.size() - 1)

static func add_species(species: Dictionary) -> Dictionary:
	for index in ROSTER.size():
		var row: Array = ROSTER[index]
		species[species_id(index)] = {
			"name":row[0], "type":row[1], "moves":["tackle", row[2]],
			"max_hp":row[3], "attack":row[4], "defense":row[5],
			"color":"#c184ef", "accent":"#4c2566", "glitch_shape":index,
		}
	return species

static func build_items(items: Dictionary) -> Dictionary:
	var variants := {}
	for key in ITEM_STATS:
		var row: Array = ITEM_STATS[key]
		var id := PREFIX + str(key)
		var item: Dictionary = items[row[0]].duplicate()
		item.merge({"id":id, "name":row[1], "rarity":row[3], "category":"Glitch Dimension", "glitched":true, "reusable":true}, true)
		match str(item.kind):
			"heal":
				item.amount = row[2]
				item.description = "Restores %d HP. The original restores %d HP." % [row[2], items[row[0]].amount]
			"revive":
				item.fraction = row[2]
				item.description = "Revives with %d%% HP. The original restores 50%%." % roundi(float(row[2]) * 100.0)
			"pp_medicine":
				item.pp_amount = row[2]
				item.description = "Restores %d PP to one move. The original restores 10 PP." % row[2]
			"ball":
				item.bonus = row[2]
				item.description = "Base catch bonus %d%%. The original grants %d%%." % [roundi(float(row[2]) * 100), roundi(float(items[row[0]].bonus) * 100)]
		item.description += " 23.68% chance to break on each use."
		variants[id] = item
	return variants

static func breaks_on_use(random: RandomNumberGenerator) -> bool:
	return random.randi_range(0, 9999) < BREAK_CHANCE

static func cache_odds(floor_number: int) -> Array:
	return CACHE_ODDS[(int(floor_number / 5.0) - 1) % CACHE_ODDS.size()]

static func cache_loot(seed_value: int, floor_number: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + floor_number * 8191
	var pools := {}
	for tier in ItemCatalog.TIERS:
		pools[tier] = []
	for id in ITEM_STATS:
		pools[ITEM_STATS[id][3]].append(PREFIX + str(id))
	var rewards := {}
	var odds := cache_odds(floor_number)
	for roll in 3:
		var value := random.randi_range(0, 99)
		for index in odds.size():
			value -= int(odds[index])
			if value < 0:
				var pool: Array = pools[ItemCatalog.TIERS[index]]
				var id: String = pool[random.randi_range(0, pool.size() - 1)]
				rewards[id] = int(rewards.get(id, 0)) + 1
				break
	return rewards

static func encounter(dimension: Dictionary, party: Array) -> Array:
	var floor_number := int(dimension.floor)
	var random := RandomNumberGenerator.new()
	random.seed = int(dimension.seed) + floor_number * 104729
	var shift := int(dimension.seed) % (ROSTER.size() - 1)
	var count := mini(party.size(), 1 if floor_number < 9 else (2 if floor_number < 31 else 3))
	var highest_level := 5
	for pokemon in party:
		highest_level = maxi(highest_level, int(pokemon.level))
	var pressure := float(floor_number - 1) / (FLOOR_COUNT - 1)
	var level := highest_level + roundi(pressure * 6.0) - 2
	var enemies: Array = []
	for slot in count:
		var index := (floor_number - 1 + shift + slot * 5) % (ROSTER.size() - 1)
		var guardian := floor_number == FLOOR_COUNT and slot == 0
		var signal_id := ""
		if guardian: index = ROSTER.size() - 1
		elif slot == 0 and not Signals.get_entry(str(dimension.get("signal",""))).is_empty():
			signal_id = str(dimension["signal"])
		elif floor_number % 2 == 0 or slot > 0:
			signal_id = Signals.for_floor(floor_number, slot, random)
		if not signal_id.is_empty(): index = signal_shape(signal_id)
		var pokemon := GameData.make_pokemon(species_id(index), random)
		var growth := maxf(0.0, float(highest_level - 5))
		GameData.scale_wild(pokemon, level + (3 if guardian else 0),
			0.75 + pressure * 0.45 + growth * 0.025 + (0.16 if guardian else 0.0),
			0.80 + pressure * 0.32 + growth * 0.022,
			0.88 + pressure * 0.30 + growth * 0.02)
		pokemon.glitch_shape = index
		if not signal_id.is_empty(): pokemon.glitch_signal = signal_id
		pokemon.glitch_impact = 0
		pokemon.speed = int(pokemon.speed) + floor_number / 3
		enemies.append(pokemon)
	return enemies
