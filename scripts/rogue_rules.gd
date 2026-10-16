class_name RogueRules
extends RefCounted

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

static func encounter(seed_value: int, floor_number: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + floor_number * 104729
	var metadata_rng := RandomNumberGenerator.new()
	metadata_rng.seed = seed_value + floor_number * 130363
	var species: Array = GameData.LEGACY_SPECIES.keys()
	var count := 1 if floor_number < 3 else (2 if floor_number < 8 else 3)
	var enemies: Array = []
	for i in count:
		var pokemon := GameData.make_pokemon(str(species[random.randi_range(0,species.size()-1)]),metadata_rng)
		var elite := 1.0
		pokemon.max_hp = int(round(pokemon.max_hp * (0.75 + floor_number * 0.035) * elite))
		pokemon.hp = pokemon.max_hp
		pokemon.attack = int(round(pokemon.attack * (0.8 + floor_number * 0.025) * elite))
		pokemon.defense = int(round(pokemon.defense * (0.9 + floor_number * 0.015)))
		pokemon.special_attack = int(round(pokemon.special_attack * (0.8 + floor_number * 0.025) * elite))
		pokemon.special_defense = int(round(pokemon.special_defense * (0.9 + floor_number * 0.015)))
		pokemon.level = mini(100,5+int(floor_number/2.0))
		pokemon.experience = ItemMechanics.experience_at(int(pokemon.level),int(ItemMechanics.species(pokemon).get("growth_rate",2)))
		ItemMechanics.apply_iv_bonuses(pokemon)
		enemies.append(pokemon)
	return {"enemies":enemies,"rewards":{"apricorn_ball":2,"potion":1}}
