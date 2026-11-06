extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_new_game("bulbasaur")
	assert(game.state.pokedex.bulbasaur.caught)
	game.start_battle("meadow_1","meadow")
	assert(game.state.pokedex.caterpie.seen)
	assert(not game.state.pokedex.caterpie.caught)
	game.show_pokedex()
	var portraits = game.ui.find_child("PokedexGrid",true,false)
	assert(portraits.find_child("Dex_charmander",true,false).find_child("UnknownPortrait",true,false) != null)
	assert(portraits.find_child("Dex_charmander",true,false).find_child("PokemonPortrait",true,false) == null)
	assert(portraits.find_child("Dex_caterpie",true,false).find_child("PokemonPortrait",true,false).material != null)
	assert(portraits.find_child("Dex_bulbasaur",true,false).find_child("PokemonPortrait",true,false).material == null)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://build/pokedex-discovery.png")
	game.register_dex("caterpie",true)
	game.register_dex("caterpie",false)
	assert(game.state.pokedex.caterpie.caught)
	game.show_pokedex()
	var grid = game.ui.find_child("PokedexGrid",true,false)
	assert(grid.get_child(0).name == "Dex_bulbasaur")
	game.dex_filter = 3
	game.show_pokedex()
	game.dex_query = "bulba"
	game.dex_filter = 2
	game.show_pokedex()
	assert(game.save_game())
	game.state = {}
	assert(game.load_game())
	assert(game.state.pokedex.caterpie.caught)
	game.state.erase("pokedex")
	game.state.reserve.append(GameData.make_pokemon("eevee"))
	game.sync_pokedex()
	assert(game.state.pokedex.eevee.caught)
	game.start_endless("squirtle")
	assert(game.state.pokedex.squirtle.caught)
	assert(not game.state.pokedex.has("eevee"))
	game.show_pokedex()
	if "--capture" in OS.get_cmdline_user_args():
		game.dex_query = ""
		game.dex_filter = 0
		game.show_pokedex()
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://build/pokedex.png")
	print("Pokédex encounter, caught precedence, migration, UI, save and mode isolation passed.")
	quit()
