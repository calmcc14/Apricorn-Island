extends SceneTree

func _init() -> void: call_deferred("run")

func run() -> void:
	# Run with a fresh APPDATA directory so this fixture uses an isolated save profile.
	assert(not FileAccess.file_exists(Cartridge.PROFILE_PATH))
	assert(not FileAccess.file_exists(Cartridge.ISLAND_PATH))
	var legacy_starter := GameData.make_pokemon("pikachu")
	legacy_starter.erase("shiny")
	assert(Cartridge.write_dictionary(Cartridge.ISLAND_PATH, {
		"party":[legacy_starter], "reserve":[], "inventory":{"potion":37},
		"current_node":"airstrip", "cleared":["airstrip"], "opened_chests":[], "settings":{},
	}))
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	assert(game.screen == game.Screen.CARTRIDGE)
	assert(not FileAccess.file_exists(Cartridge.PROFILE_PATH))
	button(game.ui,"Red Version")
	assert(not has_button(game.ui,"Yellow Version"))
	game.choose_first_cartridge(Cartridge.YELLOW)
	assert(not game.cartridge_profile.has("active"))
	button(game.ui,"Blue Version").pressed.emit()
	assert(game.screen == game.Screen.TITLE and game.cartridge == Cartridge.BLUE)
	assert(Cartridge.read_dictionary(Cartridge.PROFILE_PATH).active == Cartridge.BLUE)
	var original: String = game.cartridge
	assert(game.cartridge_save_path(false) == Cartridge.ISLAND_PATH)
	assert(game.load_game() and game.state.inventory.potion == 37)
	assert(game.state.party[0].species == "pikachu")
	assert(not game.state.party[0].get("shiny",false))
	game.show_title()
	game.show_cartridge_menu()
	assert(game.screen == game.Screen.TITLE)
	game.open_debug()
	button(game.ui,"Swap cartridge").pressed.emit()
	assert(not has_button(game.ui,"Insert Yellow"))
	await game.swap_cartridge(Cartridge.YELLOW)
	assert(game.cartridge == Cartridge.BLUE)
	game.close_cartridge_menu()
	game.close_debug()

	Cartridge.load_exclusives()
	for id in Cartridge.species_sides: assert(GameData.SPECIES.has(id), id)
	for id in Cartridge.item_sides: assert(GameData.ITEMS.has(id), id)
	var red := RogueRules.encounter_species(Cartridge.RED)
	var blue := RogueRules.encounter_species(Cartridge.BLUE)
	var yellow := RogueRules.encounter_species(Cartridge.YELLOW)
	assert(yellow.size() == 1026)
	assert(red.size() < yellow.size() and blue.size() < yellow.size())
	for id in GameData.DEX_SPECIES:
		assert(id in yellow and (id in red or id in blue), id)
	for id in ["oddish","teddiursa","groudon","dialga","reshiram","zacian","koraidon"]:
		assert(id in red and id not in blue, id)
	for id in ["bellsprout","phanpy","kyogre","palkia","zekrom","zamazenta","miraidon"]:
		assert(id in blue and id not in red, id)
	for version in Cartridge.VERSIONS:
		for encounter in GameData.ENCOUNTERS.values():
			var species := Cartridge.story_species(version, encounter.enemies)
			assert(species.size() == encounter.enemies.size())
			for id in species: assert(Cartridge.has_species(version,id))
		for floor_number in [1,3,8,14,100]:
			for seed_value in range(40):
				for enemy in RogueRules.encounter(seed_value,floor_number,{},version).enemies:
					assert(Cartridge.has_species(version,enemy.species))
		for id in Cartridge.item_sides:
			assert((ItemCatalog.item_probability(id,14,version) > 0.0) == Cartridge.has_item(version,id), id)
		for seed_value in range(100):
			for id in ItemCatalog.chest_rewards(seed_value,"milestone",14,{},version):
				assert(Cartridge.has_item(version,id), id)
	for id in GameData.ITEMS:
		if id in GameData.LEGACY_ITEMS: continue
		assert(ItemCatalog.item_probability(id,14,Cartridge.YELLOW) > 0.0, id)
	assert(ItemCatalog.item_probability("item_dreamy_ball",14,Cartridge.YELLOW) > 0.0)
	assert(ItemCatalog.item_probability("item_dreamy_ball",14,Cartridge.RED) == 0.0)

	game.continue_game()
	game.travel_to("meadow")
	game.start_battle("meadow_1", "meadow")
	game.battle.enemies[0].hp = 2
	game.battle.enemies[0].shiny = true
	var first_enemy: String = game.battle.enemies[0].species
	var other: String = Cartridge.RED if original != Cartridge.RED else Cartridge.BLUE
	await swap(game, other)
	assert(game.screen == game.Screen.TITLE and not game.state.has("party"))
	assert(not FileAccess.file_exists(game.cartridge_save_path(false)))
	game.start_endless("eevee")
	game.state.inventory.potion = 8
	assert(game.save_game())
	await swap(game, original)
	assert(game.screen == game.Screen.BATTLE and game.state.inventory.potion == 37)
	assert(game.battle.enemies[0].species == first_enemy and game.battle.enemies[0].hp == 2)
	assert(game.battle.enemies[0].shiny)
	game.state.inventory.item_master_ball = 1
	var messages: Array[String] = []
	game.resolve_ball_action({"actor":0,"target":0,"ball":"item_master_ball"},messages)
	var caught: Dictionary = game.state.party.back()
	assert(caught.shiny and caught.species == first_enemy)
	assert(ItemProgression.evolve(caught, "metapod") and caught.shiny)
	for back in [false, true]:
		var shiny: Texture2D = game.pokemon_sprite(caught, back)
		var regular: Texture2D = game.species_sprite("metapod", back)
		var original_art: Image = game.load_sprite_image("shiny/metapod_" + ("back" if back else "front"))
		assert(original_art != null and shiny.get_image().get_data() == original_art.get_data())
		assert(shiny.get_image().get_data() != regular.get_image().get_data())
	game.flee_battle()
	assert(not game.state.has("battle_checkpoint"))
	assert(game.load_game() and game.state.party.back().shiny)
	game.state.cleared.append("summit")
	game.travel_to("lookout")
	game.enter_current_node(game.get_node_data("lookout"))
	assert(game.state.finished and game.screen == game.Screen.ENDING)
	assert(Cartridge.read_dictionary(Cartridge.PROFILE_PATH).yellow_unlocked)
	button(game.ui,"Swap cartridge").pressed.emit()
	assert(has_button(game.ui,"Insert Yellow"))
	await game.swap_cartridge(other)
	assert(game.is_endless() and game.state.inventory.potion == 8 and game.state.party[0].species == "eevee")
	await swap(game, original)
	assert(game.screen == game.Screen.MAP and game.state.finished and game.state.current_node == "lookout")
	button(game.ui,"Survey for wild Pokémon").pressed.emit()
	assert(game.screen == game.Screen.BATTLE and game.battle.encounter_id == "survey")
	game.open_debug()
	button(game.ui,"Win current battle").pressed.emit()
	assert(int(game.state.survey_count) == 1 and game.state.inventory.potion == 38)

	var third: String = Cartridge.VERSIONS.filter(func(version): return version not in [original, other])[0]
	await swap(game, third)
	assert(game.screen == game.Screen.TITLE and not game.state.has("party"))
	assert(Cartridge.read_dictionary(Cartridge.PROFILE_PATH).active == third)
	var reloaded = load("res://scenes/Main.tscn").instantiate()
	root.add_child(reloaded)
	assert(reloaded.cartridge == third and reloaded.cartridge_save_path(false, original) == Cartridge.ISLAND_PATH)
	for species_id in GameData.DEX_SPECIES:
		var art_id: String = "giratina-altered" if species_id == "giratina" else species_id
		for side in ["front", "back"]:
			assert(ResourceLoader.exists("res://assets/sprites/%s_%s.png" % [art_id, side]), art_id)
	for version in Cartridge.VERSIONS:
		if reloaded.cartridge != version: await swap(reloaded, version)
		for species_id in GameData.DEX_SPECIES:
			var entry := {"species": species_id}
			assert(reloaded.pokemon_sprite(entry) != null and reloaded.pokemon_sprite(entry, true) != null, species_id)
		var pecharunt: Texture2D = reloaded.sprites.pecharunt_front
		assert(pecharunt.get_image().get_data() != reloaded.sprites.pecharunt_back.get_image().get_data())
		assert(pecharunt.get_image().get_data() != reloaded.sprites.terapagos_front.get_image().get_data())
		assert(reloaded.pokemon_sprite({"species": "giratina", "form": "giratina-origin"}) == reloaded.species_sprite("giratina-origin"))
		assert(reloaded.pokemon_sprite({"species": "giratina"}, true) == reloaded.species_sprite("giratina-altered", true))
		assert(reloaded.pokemon_sprite({"species": "ivysaur", "form": "bulbasaur"}) == reloaded.sprites.ivysaur_front)
		assert(reloaded.pokemon_sprite({"species": "ditto", "form": ""}, true) == reloaded.sprites.ditto_back)
		for back in [false, true]:
			var original_art: Image = reloaded.load_sprite_image("shiny/giratina-origin_" + ("back" if back else "front"))
			var shiny: Texture2D = reloaded.pokemon_sprite({"species":"giratina","form":"giratina-origin","shiny":true}, back)
			assert(original_art != null and shiny.get_image().get_data() == original_art.get_data())
	if reloaded.cartridge != Cartridge.YELLOW: await swap(reloaded, Cartridge.YELLOW)
	for key in ["pikachu_front", "pecharunt_front", "pecharunt_back", "terapagos_back"]:
		var regular: Texture2D = reloaded.standard_sprites[key]
		var amber: Texture2D = reloaded.sprites[key]
		var original_art: Image = load("res://assets/sprites/%s.png" % key).get_image()
		assert(regular.get_image().get_data() == original_art.get_region(original_art.get_used_rect()).get_data(), key)
		assert(regular.get_size() == amber.get_size(), key)
		assert(regular.get_image().get_data() != amber.get_image().get_data(), key)
	var rolls := RandomNumberGenerator.new()
	var repeated := RandomNumberGenerator.new()
	rolls.seed = 137
	repeated.seed = 137
	var shinies := 0
	for i in 2048:
		var shiny: bool = GameData.make_pokemon("pikachu", rolls).shiny
		assert(shiny == GameData.make_pokemon("pikachu", repeated).shiny)
		if shiny: shinies += 1
	assert(shinies > 0 and shinies < 20)
	print("Cartridges passed: first choice, Yellow unlock, legacy saves, swapping, content pools, and shiny capture, evolution and reload.")
	quit()

func swap(game: Control, version: String) -> void:
	game.open_debug()
	button(game.ui,"Swap cartridge").pressed.emit()
	assert(game.screen == game.Screen.CARTRIDGE)
	button(game.ui,"Insert " + version.capitalize()).pressed.emit()
	var confirmation := game.get_child(-1) as ConfirmationDialog
	assert(confirmation != null)
	await process_frame
	confirmation.get_ok_button().pressed.emit()
	while game.swapping_cartridge: await process_frame

func button(parent: Node, label: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if node.text == label: return node
	assert(false, "Missing button " + label)
	return null

func has_button(parent: Node, label: String) -> bool:
	for node in parent.find_children("*", "Button", true, false):
		if node.text == label: return true
	return false
