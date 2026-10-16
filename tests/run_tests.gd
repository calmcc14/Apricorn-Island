extends SceneTree

func _init() -> void:
	# Capture rates: full health, weakened targets, stronger ball, and cap.
	assert(is_equal_approx(GameRules.capture_chance(0.20, 100, 100), 0.20))
	assert(is_equal_approx(GameRules.capture_chance(0.40, 100, 100), 0.40))
	assert(is_equal_approx(GameRules.capture_chance(0.20, 0, 100), 0.85))
	assert(is_equal_approx(GameRules.capture_chance(0.40, 0, 100), 0.95))
	assert(GameRules.capture_chance(0.20, 5, 50) > GameRules.capture_chance(0.20, 45, 50))
	assert(GameRules.capture_chance(0.40, 25, 50) > GameRules.capture_chance(0.20, 25, 50))

	# Type matchups, defeat recovery, and deterministic damage.
	assert(GameRules.effectiveness("water", "fire") == 2.0)
	assert(GameRules.effectiveness("fire", "water") == 0.5)
	assert(GameRules.effectiveness("normal", "water") == 1.0)
	assert(GameRules.revive_hp(64) == 13)
	assert(GameRules.revive_hp(5) == 1)
	assert(GameRules.calculate_damage(10, 10, 10, 1.0, 1.0) == 10)
	assert(GameRules.calculate_damage(10, 10, 10, 2.0, 1.0) == 20)

	# Content integrity: unique nodes, valid links, encounters, species, and rewards.
	assert(GameData.NODES.size() == 12)
	var node_ids: Array[String] = []
	for node in GameData.NODES:
		assert(str(node.id) not in node_ids)
		node_ids.append(str(node.id))
		if node.has("encounter"):
			assert(GameData.ENCOUNTERS.has(str(node.encounter)))
	for node in GameData.NODES:
		for linked_id in node.links:
			assert(str(linked_id) in node_ids)
	for encounter in GameData.ENCOUNTERS.values():
		assert(encounter.enemies.size() >= 1 and encounter.enemies.size() <= 3)
		for species_id in encounter.enemies:
			assert(GameData.SPECIES.has(str(species_id)))
		for reward_id in encounter.rewards:
			assert(GameData.ITEMS.has(str(reward_id)))

	# New Pokémon state is independent and begins healthy.
	var starter := GameData.make_pokemon("bulbasaur")
	assert(starter.hp == starter.max_hp)
	starter.hp = 1
	assert(GameData.make_pokemon("bulbasaur").hp == 64)
	print("All Apricorn Island rules tests passed.")
	quit()
