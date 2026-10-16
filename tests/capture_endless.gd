extends SceneTree
var game: Control

func _init() -> void: call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+label+".png")

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await capture("endless_title")
	game.start_endless()
	game.state.run.seed = 12345
	game.state.run.depth = 127
	game.state.run.best = 127
	game.state.current_node = "run_127"
	game.focus_current_stop()
	game.show_map("A new encounter lies ahead.")
	await capture("endless_map")
	game.state.run.pending_upgrade = true
	game.show_upgrade()
	await capture("endless_upgrade")
	game.apply_upgrade("vitality")
	game.state.run.depth = 0
	game.state.current_node = "run_1"
	game.start_battle("procedural","run_1")
	game.battle.actions = [{"actor":1,"kind":"move","move":"ember","target":0}]
	game.rng.seed = 4
	game.resolve_round()
	await create_timer(0.35).timeout
	await capture("endless_animation")
	await create_timer(2.5).timeout
	for pokemon in game.state.party: pokemon.hp = 0
	game.handle_defeat()
	await capture("endless_over")
	print("Endless visual capture complete.")
	game.queue_free()
	await process_frame
	quit()
