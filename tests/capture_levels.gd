extends SceneTree

func _init() -> void: call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+name+".png")

func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	root.size = Vector2i(1280,720)
	game.start_new_game("bulbasaur")
	game.state.party.append(GameData.make_pokemon("charmander"))
	game.state.party.append(GameData.make_pokemon("squirtle"))
	game.state.reserve.append(GameData.make_pokemon("pikachu"))
	ItemMechanics.grant_experience(game.state.party[0],30)
	game.show_party()
	await capture("levels_party")
	game.start_battle("meadow_1","meadow")
	await capture("levels_battle")
	game.show_box()
	await capture("levels_box")
	print("Level screens captured.")
	quit()
