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
	var spread := [31,0,16,30,26,8]
	for i in 6: game.state.party[0].ivs[ItemMechanics.IV_STATS[i]] = spread[i]
	ItemMechanics.apply_iv_bonuses(game.state.party[0])
	game.show_party()
	await capture("ivs_party")
	game.show_pokemon_summary(0)
	var summary = game.ui.get_child(0)
	for title in ["Overview","Stats","IV Judge","Moves"]:
		summary.tab = title
		summary.rebuild()
		await capture("ivs_"+title.to_lower().replace(" ","_"))
	game.close_pokemon_summary()
	game.show_box()
	game.box_inspect = true
	game.show_box()
	await capture("ivs_box")
	print("IV details screenshots captured.")
	quit()
