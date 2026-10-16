extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var game: Control = packed.instantiate()
	root.add_child(game)
	await process_frame

	game.start_new_game()
	assert(game.state.party.size() == 3)
	assert(game.state.reserve.is_empty())
	assert(game.state.current_node == "airstrip")
	assert(game.node_unlocked(game.get_node_data("meadow")))

	game.show_map()
	await process_frame
	await process_frame
	var meadow_position: Vector2 = game.world_to_screen(game.get_node_data("meadow").pos)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = meadow_position
	click.global_position = meadow_position
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	assert(game.state.current_node == "meadow")
	game.start_battle("meadow_1", "meadow")
	assert(game.battle.enemies.size() == 1)
	assert(game.battle.enemies[0].species == "caterpie")

	var balls_before: int = int(game.state.inventory.apricorn_ball)
	game.battle.enemies[0].hp = 1
	game.rng.seed = 1
	var capture_messages: Array[String] = []
	game.resolve_ball_action({"actor":0,"kind":"ball","ball":"apricorn_ball","target":0}, capture_messages)
	assert(game.state.inventory.apricorn_ball == balls_before - 1)

	for pokemon in game.state.party:
		pokemon.hp = 0
	game.handle_defeat()
	for pokemon in game.state.party:
		assert(pokemon.hp == pokemon.max_hp)
	assert(game.state.current_node == "meadow")

	game.save_game()
	var saved_party_count: int = game.state.party.size()
	game.state = {}
	assert(game.load_game())
	assert(game.state.party.size() == saved_party_count)
	assert(game.sprites.size() == 32)
	assert(game.route_background != null)
	assert(game.trainer_texture != null)
	# A distant unlocked destination is clickable; the still-locked lookout is not.
	game.mark_cleared("ridge")
	game.show_map()
	game.scroll_route(-1100)
	await process_frame
	await process_frame
	var summit_position: Vector2 = game.world_to_screen(game.get_node_data("summit").pos)
	click.position = summit_position
	click.global_position = summit_position
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	assert(game.state.current_node == "summit")
	assert(not game.can_travel_to("lookout"))
	for pokemon in game.state.party: pokemon.hp = 1
	game.start_battle("summit_3", "summit")
	for pokemon in game.state.party: assert(pokemon.hp == pokemon.max_hp)
	await process_frame
	await process_frame
	# Exercise the actual battle menu buttons.
	for button in game.ui.find_children("*", "Button", true, false):
		if button.text == "FIGHT":
			click.position = button.get_global_rect().get_center()
			click.global_position = click.position
			click.pressed = true
			root.push_input(click, true)
			click = click.duplicate()
			click.pressed = false
			root.push_input(click, true)
			break
	assert(game.battle_menu == "fight")
	game.choose_move(0, "vine_whip")
	assert(not game.pending_action.is_empty())
	game.confirm_target(0)
	assert(game.battle.actions.size() == 1)
	assert(game.battle_menu == "main")
	game.state.party[1].hp = 10
	game.state.inventory.potion = 1
	game.choose_battle_heal(1, "potion")
	game.choose_move(2, "water_gun")
	game.confirm_target(0)
	assert(game.state.inventory.potion == 0)
	assert("Charmander recovered with Potion." in game.battle_log)
	game.finish_victory()
	for pokemon in game.state.party: assert(pokemon.hp == pokemon.max_hp)
	assert(game.can_travel_to("airstrip"))
	game.state.settings.difficulty = "easy"
	game.start_new_game()
	assert(game.state.settings.difficulty == "easy")
	game.open_settings(game.Screen.MAP)
	var difficulty: OptionButton = game.ui.find_children("*", "OptionButton", true, false)[0]
	assert(difficulty.item_count == 3)
	difficulty.select(2)
	difficulty.item_selected.emit(2)
	assert(game.state.settings.difficulty == "hard")
	game.battle = {"node_id":"meadow"}
	assert(is_equal_approx(game.enemy_damage_scale(), 1.0))
	game.battle.node_id = "summit"
	assert(is_equal_approx(game.enemy_damage_scale(), 0.9))
	game.start_new_game()
	assert(game.state.settings.difficulty == "hard")
	game.open_settings(game.Screen.MAP)
	difficulty = game.ui.find_children("*", "OptionButton", true, false)[0]
	assert(difficulty.selected == 2)
	game.show_map()
	game.scroll_route(-10000)
	var last_position: Vector2 = game.world_to_screen(GameData.NODES.back().pos)
	assert(last_position.x > 0 and last_position.x < 480)
	game.scroll_route(10000)
	var first_position: Vector2 = game.world_to_screen(GameData.NODES.front().pos)
	var next_position: Vector2 = game.world_to_screen(GameData.NODES[1].pos)
	assert(is_equal_approx(first_position.y,next_position.y))
	assert(next_position.x-first_position.x >= 130)
	assert(is_equal_approx(first_position.x,84))

	print("All Apricorn Island integration tests passed.")
	game.queue_free()
	quit()
