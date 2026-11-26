class_name RogueRules
extends RefCounted

static var ranked_species: Array = []
static var cartridge_rosters: Dictionary = {}

static func encounter_species(version := "") -> Array:
	if ranked_species.is_empty():
		var strength := {}
		ranked_species = GameData.DEX_SPECIES.duplicate()
		for id in ranked_species:
			var total := 0
			for stat in ItemProgression.info(id).stats.values(): total += int(stat)
			strength[id] = total
		# Break ties by National Dex number so the full ordering is repeatable.
		ranked_species.sort_custom(func(a, b):
			if strength[a] == strength[b]: return ItemProgression.info(a).dex_id < ItemProgression.info(b).dex_id
			return strength[a] < strength[b]
		)
	if version == "": return ranked_species
	if not cartridge_rosters.has(version):
		var available := ranked_species.filter(func(id): return Cartridge.has_species(version, id))
		# This is the only additional regional form with independent battle data.
		if Cartridge.has_species(version, "farfetchd-galar"): available.append("farfetchd-galar")
		cartridge_rosters[version] = available
	return cartridge_rosters[version]

static func node(seed_value: int, floor_number: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + floor_number * 7919
	var kind := "battle"
	if floor_number == 0: kind = "start"
	# Preserve the seeded place-name sequence used by existing runs.
	elif floor_number > 1 and floor_number % 5 != 0: random.randf()
	var places := ["Petal Trail", "Moonlit Grove", "Coral Shore", "Amber Ridge", "Mossy Ruins", "Starlight Marsh", "Windy Pass", "Crystal Brook"]
	var title: String = places[random.randi_range(0, places.size()-1)]
	if kind == "boss": title = "Guardian Challenge"
	elif kind == "chest": title = "Lost Supply Cache"
	elif kind == "start": title = "A New Expedition"
	return {"id":"run_%d" % floor_number,"floor":floor_number,"name":title,"kind":kind,"pos":Vector2(floor_number,0),"prereq":[],"encounter":"procedural","cave":kind == "battle" and floor_number % 7 == 0,"reward":{"potion":2,"apricorn_ball":3}}

static func encounter(seed_value: int, floor_number: int, pokedex: Dictionary = {}, version := "") -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + floor_number * 104729
	var metadata_rng := RandomNumberGenerator.new()
	metadata_rng.seed = seed_value + floor_number * 130363
	var legacy := GameData.LEGACY_SPECIES.keys().filter(func(id): return Cartridge.has_species(version, id))
	var species := encounter_species(version)
	var pool_size := species.size() if floor_number >= 14 else mini(species.size(), 210 + maxi(0, floor_number - 3) * 75)
	var count := 1 if floor_number < 3 else (2 if floor_number < 8 else 3)
	var pressure := 24.0 * (sqrt(1.0 + maxf(0, floor_number) / 12.0) - 1.0)
	var enemies: Array = []
	var picked := {}
	for i in count:
		var use_legacy := i == 0 and floor_number < 6
		var pool := legacy if use_legacy else species
		var limit := legacy.size() if use_legacy else pool_size
		var index := random.randi_range(0, limit - 1)
		while picked.has(pool[index]): index = (index + 1) % limit
		# Give the collection one fresh opportunity while keeping the other slots open to repeats.
		if not use_legacy and i == (1 if floor_number < 6 else 0) and not pokedex.is_empty():
			for offset in limit:
				var candidate := (index + offset) % limit
				if not picked.has(pool[candidate]) and not pokedex.get(pool[candidate], {}).get("caught", false):
					index = candidate
					break
		var id: String = pool[index]
		picked[id] = true
		var pokemon := GameData.make_pokemon(id, metadata_rng)
		GameData.scale_wild(pokemon, 5 + int(floor_number / 2.0),
			0.75 + pressure * 0.035, 0.8 + pressure * 0.025, 0.9 + pressure * 0.015)
		enemies.append(pokemon)
	return {"enemies":enemies,"rewards":{"apricorn_ball":2,"potion":1}}
