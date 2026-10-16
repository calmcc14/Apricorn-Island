extends SceneTree

var game: Control

func _init() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png("res://build/" + label + ".png")

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await capture("title")
	game.start_new_game()
	await capture("intro")
	game.intro_page = 1
	game.show_intro()
	await capture("intro_team")
	game.show_map()
	await capture("map_start")
	root.size = Vector2i(390,844)
	await capture("map_phone_tall")
	root.size = Vector2i(480,854)
	for node in GameData.NODES: game.mark_cleared(str(node.id))
	game.show_map()
	await capture("map")
	game.state.current_node = "summit"
	game.focus_current_stop()
	game.show_map("Choose an activity below to explore this place.")
	await capture("map_summit")
	game.start_battle("summit_3", "summit")
	await capture("battle")
	game.battle_menu = "fight"
	game.show_battle()
	await capture("moves")
	game.open_settings(game.Screen.MAP)
	await capture("settings")
	game.show_party()
	await capture("party")
	game.show_inventory()
	await capture("inventory")
	game.intro_page = 2
	game.show_intro()
	await capture("intro_final")
	print("Visual captures saved.")
	quit()
