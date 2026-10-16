extends SceneTree

func _init() -> void: call_deferred("run")

func run() -> void:
	var game: Control = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_endless()
	var seed_value: int = game.state.run.seed
	assert(game.is_endless())
	assert(game.map_nodes().size() == 12)
	assert(game.can_travel_to("run_1"))
	assert(not game.can_travel_to("run_2"))
	for depth in [1,12,100,1000,10000]:
		game.state.run.depth = depth
		game.state.current_node = "run_%d" % depth
		game.focus_current_stop()
		assert(game.map_nodes().size() == 12)
		assert(game.node_unlocked(game.get_node_data("run_%d" % (depth+1))))
		assert(not game.node_unlocked(game.get_node_data("run_%d" % (depth+2))))
		var sample := RogueRules.encounter(seed_value,depth)
		assert(sample == RogueRules.encounter(seed_value,depth))
		assert(sample.enemies.size() <= 3)
	assert(RogueRules.encounter(17,23) != RogueRules.encounter(18,23))
	assert(RogueRules.node(17,5).kind == "battle")
	assert(RogueRules.node(17,10).kind == "battle")
	for route_seed in [17,123,9999]:
		for level in range(1,101):
			assert(RogueRules.node(route_seed,level).kind == "battle")
	game.start_endless()
	for depth in [0,9,11,19,21,29,31]:
		game.state.run.depth = depth
		assert(not game.milestone_chest_pending())
	for depth in [10,20,30]:
		game.state.run.depth = depth
		game.state.current_node = "run_%d" % depth
		game.show_map()
		assert(game.screen == game.Screen.CHEST)
		game.save_game()
		game.continue_endless()
		assert(game.screen == game.Screen.CHEST)
		var potions: int = game.state.inventory.potion
		game.collect_milestone_chest()
		assert(game.state.run.depth == depth)
		assert(int(game.state.inventory.get("potion",0))+int(game.state.get("chest_storage",{}).get("potion",0)) == potions+2)
		game.collect_milestone_chest()
		assert(int(game.state.inventory.get("potion",0))+int(game.state.get("chest_storage",{}).get("potion",0)) == potions+2)
		game.continue_endless()
		assert(game.screen == game.Screen.MAP)
	game.start_endless()
	game.travel_to("run_1")
	game.enter_current_node(game.get_node_data("run_1"))
	assert(game.screen == game.Screen.BATTLE)
	assert(game.battle.enemies.size() == 1)
	game.state.party[0].hp = 20
	game.save_game()
	var enemy_hp: int = game.battle.enemies[0].hp
	game.state = {}
	game.continue_endless()
	assert(game.screen == game.Screen.BATTLE)
	assert(game.state.party[0].hp == 20)
	assert(game.battle.enemies[0].hp == enemy_hp)
	# Win a real round and retain damage rather than healing automatically.
	game.battle.enemies[0].hp = 1
	game.rng.seed = 4
	game.battle.actions = [{"actor":0,"kind":"move","move":"tackle","target":0},{"actor":1,"kind":"move","move":"scratch","target":0},{"actor":2,"kind":"move","move":"tackle","target":0}]
	game.resolve_round()
	assert(game.battle_finished)
	game.finish_victory()
	assert(game.state.run.depth == 1)
	assert(game.state.party[0].hp == 20)
	assert(game.state.run.pending_upgrade)
	game.continue_endless()
	assert(game.screen == game.Screen.UPGRADE)
	var attack: int = game.state.party[0].attack
	game.apply_upgrade("power")
	assert(game.state.party[0].attack == attack+2)
	game.apply_upgrade("power")
	assert(game.state.party[0].attack == attack+2)
	# Former rest stops require combat and do not heal on entry.
	game.state.run.depth = 4
	game.state.party[0].hp = 10
	game.travel_to("run_5")
	game.enter_current_node(game.get_node_data("run_5"))
	assert(game.screen == game.Screen.BATTLE)
	assert(game.state.run.depth == 4)
	assert(game.state.party[0].hp == 10)
	game.finish_victory()
	game.apply_upgrade("power")
	assert(game.state.run.depth == 5)
	game.state.party[0].hp = 10
	game.enter_current_node(game.get_node_data("run_5"))
	assert(game.state.party[0].hp == 10)
	assert(game.state.current_node == "run_6")
	# Flee and resume cannot recover HP or keep an abandoned checkpoint.
	game.start_battle("procedural","run_6")
	game.flee_battle()
	game.continue_endless()
	assert(game.screen == game.Screen.MAP)
	assert(game.state.current_node == "run_5")
	assert(game.state.party[0].hp == 10)
	# Wipe persists as a finished run; fresh run changes seed and keeps best depth.
	var old_seed: int = game.state.run.seed
	for pokemon in game.state.party: pokemon.hp = 0
	game.handle_defeat()
	game.continue_endless()
	assert(game.screen == game.Screen.RUN_END)
	assert(game.state.run.ended)
	game.start_endless()
	assert(game.state.run.seed != old_seed)
	assert(game.state.run.depth == 0 and game.state.run.best >= 5)
	# Every original generated sound has real, non-clipping PCM data.
	for name in game.sfx.clips:
		var clip: AudioStreamWAV = game.sfx.clips[name]
		assert(clip.data.size() > 1000)
		var peak := 0
		for i in range(0,clip.data.size(),2): peak = maxi(peak,absi(clip.data.decode_s16(i)))
		assert(peak > 1000 and peak < 32767)
	game.sfx.clips.victory.save_to_wav("res://build/victory_preview.wav")
	# Exercise the asynchronous presentation path with real timers.
	game.animation_enabled = true
	game.travel_to("run_1")
	game.start_battle("procedural","run_1")
	game.battle.actions = [{"actor":0,"kind":"move","move":"vine_whip","target":0}]
	game.resolve_round()
	assert(game.battle_busy)
	assert(not game.active_effect.is_empty())
	assert(game.visual_party.size() == 3)
	await create_timer(3.0).timeout
	assert(not game.battle_busy)
	assert(game.screen == game.Screen.BATTLE)
	print("Endless generation, persistence, upgrades, audio PCM, and animated rounds passed.")
	game.queue_free()
	await process_frame
	quit()

