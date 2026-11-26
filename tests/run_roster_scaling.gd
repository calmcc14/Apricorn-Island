extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	assert(GameData.DEX_SPECIES.size() == 1025)
	var dex_numbers := {}
	for id in GameData.DEX_SPECIES:
		var pokemon := GameData.make_pokemon(id)
		var info := ItemMechanics.species(pokemon)
		var number := int(info.dex_id)
		assert(number >= 1 and number <= 1025 and not dex_numbers.has(number), id)
		dex_numbers[number] = true
		assert(not pokemon.moves.is_empty() and not info.types.is_empty(), id)
		for move in pokemon.moves: assert(GameData.MOVES.has(move), id)

	var available := {}
	for seed_value in range(1, 6501):
		var encounter := RogueRules.encounter(seed_value, 14)
		var floor_species := {}
		for enemy in encounter.enemies:
			assert(not floor_species.has(enemy.species))
			floor_species[enemy.species] = true
			available[enemy.species] = true
		if available.size() == 1025: break
	assert(available.size() == 1025, "Missing %d species from area 14" % (1025 - available.size()))
	assert(RogueRules.encounter(31, 14) == RogueRules.encounter(31, 14))

	var caught := {}
	for id in GameData.DEX_SPECIES:
		if id != "caterpie": caught[id] = {"caught": true}
	var previous := {}
	for depth in [8, 14, 50, 200, 1000]:
		var enemy: Dictionary = RogueRules.encounter(123, depth, caught).enemies[0]
		assert(enemy.species == "caterpie" and enemy.hp == enemy.max_hp)
		if not previous.is_empty():
			assert(enemy.level >= previous.level and enemy.max_hp > previous.max_hp)
			assert(enemy.attack > previous.attack and enemy.defense >= previous.defense)
		previous = enemy
	assert(previous.level == 100)

	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	if game.screen == game.Screen.CARTRIDGE:
		game.choose_first_cartridge(Cartridge.RED)
	game.start_new_game("bulbasaur")
	game.start_battle("meadow_1", "meadow")
	var early: Dictionary = game.battle.enemies[0]
	game.state.cleared = ["airstrip", "meadow", "brook", "mystery", "blue_chest", "forest"]
	game.start_battle("meadow_1", "meadow")
	var later: Dictionary = game.battle.enemies[0]
	assert(early.level == 5 and later.level == 8 and later.max_hp > early.max_hp)

	game.start_endless("squirtle")
	game.state.pokedex = {}
	var pecharunt_seed := 0
	for seed_value in range(1, 6501):
		if RogueRules.encounter(seed_value,14,{},game.cartridge).enemies.any(func(enemy): return enemy.species == "pecharunt"):
			pecharunt_seed = seed_value
			break
	assert(pecharunt_seed != 0)
	game.state.run.seed = pecharunt_seed
	game.state.run.depth = 13
	game.travel_to("run_14")
	game.enter_current_node(game.get_node_data("run_14"))
	assert(game.screen == game.Screen.BATTLE and game.state.pokedex.pecharunt.seen)
	var target := -1
	for i in game.battle.enemies.size():
		if game.battle.enemies[i].species == "pecharunt": target = i
	assert(target >= 0 and game.species_sprite("pecharunt") != null)
	game.debug_options.capture = true
	var messages: Array[String] = []
	game.resolve_ball_action({"target": target, "actor": 0, "ball": "apricorn_ball"}, messages)
	assert(game.state.party[1].species == "pecharunt" and game.state.pokedex.pecharunt.caught)
	assert(game.save_game())
	game.continue_endless()
	assert(game.state.party[1].species == "pecharunt" and game.state.pokedex.pecharunt.caught)
	game.start_endless("squirtle")
	assert(game.state.pokedex.pecharunt.caught and game.state.party.size() == 1)
	game.show_pokedex()
	var grid = game.ui.find_child("PokedexGrid", true, false)
	assert(grid.get_child_count() == game.DEX_PAGE_SIZE)
	game.dex_query = "#1025"
	game.show_pokedex()
	grid = game.ui.find_child("PokedexGrid", true, false)
	assert(grid.get_child_count() == 1 and grid.get_child(0).name == "Dex_pecharunt")
	print("Verified all 1,025 playable species, discovery and capture, saved Pokédex, and scaling in both modes.")
	quit()
