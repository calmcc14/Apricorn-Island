extends SceneTree

class Simulation extends "res://scripts/main.gd":
	var defeated := false
	func save_game() -> bool: return true
	func show_battle() -> void: pass
	func show_map(_message := "") -> void: pass
	func show_upgrade() -> void: pass
	func handle_defeat() -> void: defeated = true

func _init() -> void: call_deferred("run")

func run() -> void:
	var game := Simulation.new()
	root.add_child(game)
	var reached_camp := 0
	var reached_guardian := 0
	var longest := 0
	for run_seed in 30:
		game.start_endless()
		game.state.run.seed = run_seed+1
		game.rng.seed = run_seed+1
		game.defeated = false
		for floor_number in range(1,51):
			var node := RogueRules.node(run_seed+1,floor_number)
			game.state.current_node = node.id
			if node.kind in ["camp","chest"]:
				game.enter_current_node(node)
			else:
				game.start_battle("procedural",node.id)
				for turn in 100:
					if game.battle_finished or game.defeated: break
					for actor_index in game.living_party_indices():
						var actor: Dictionary = game.state.party[actor_index]
						if actor.hp < actor.max_hp*0.4 and int(game.state.inventory.get("super_potion",0)) > 0:
							game.battle.actions.append({"actor":actor_index,"kind":"heal_item","item":"super_potion"})
							continue
						if actor.hp < actor.max_hp*0.5 and int(game.state.inventory.get("potion",0)) > 0:
							game.battle.actions.append({"actor":actor_index,"kind":"heal_item","item":"potion"})
							continue
						var target_index: int = game.living_enemy_indices()[0]
						var best := "tackle"
						var score := -1.0
						for move_id in GameData.SPECIES[actor.species].moves:
							var move: Dictionary = GameData.MOVES[move_id]
							if move.kind != "damage": continue
							var value: float = move.power*move.accuracy*GameRules.effectiveness(move.type,GameData.SPECIES[game.battle.enemies[target_index].species].type)
							if value > score: score = value; best = move_id
						game.battle.actions.append({"actor":actor_index,"kind":"move","move":best,"target":target_index})
					game.resolve_round()
				if game.defeated: break
				assert(game.battle_finished,"Fight stalled beyond 100 rounds")
				game.finish_victory()
				var ratio := 0.0
				for pokemon in game.state.party: ratio += float(pokemon.hp)/pokemon.max_hp
				game.apply_upgrade("vitality" if ratio < 2.3 or floor_number%3 == 0 else "power")
			longest = maxi(longest,floor_number)
			if floor_number == 5: reached_camp += 1
			if floor_number == 10: reached_guardian += 1
	print("Endless simulations: %d/30 reached camp, %d/30 beat first guardian; longest tested run %d." % [reached_camp,reached_guardian,longest])
	assert(reached_camp >= 24,"Opening is too punishing")
	assert(reached_guardian >= 15,"First guardian is too punishing")
	game.queue_free()
	await process_frame
	quit()
