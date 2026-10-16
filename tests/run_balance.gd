extends SceneTree

class Simulation extends "res://scripts/main.gd":
	var defeated := false
	func save_game() -> bool: return true
	func show_battle() -> void: pass
	func show_map(_message := "") -> void: pass
	func handle_defeat() -> void: defeated = true

func _init() -> void: call_deferred("run")

func run() -> void:
	var game := Simulation.new()
	root.add_child(game)
	for difficulty in ["easy", "normal", "hard"]:
		for encounter_id in GameData.ENCOUNTERS:
			var wins := 0
			var rounds_total := 0
			for seed_value in 100:
				game.state = {"party":[GameData.make_pokemon("bulbasaur"),GameData.make_pokemon("charmander"),GameData.make_pokemon("squirtle")],"settings":{"difficulty":difficulty},"current_node":"airstrip"}
				game.defeated = false
				game.rng.seed = seed_value
				game.start_battle(encounter_id, "summit" if encounter_id == "summit_3" else "meadow")
				var rounds := 0
				while not game.battle_finished and not game.defeated and rounds < 30:
					for actor_index in game.living_party_indices():
						var actor: Dictionary = game.state.party[actor_index]
						var target_index: int = game.living_enemy_indices()[0]
						var target: Dictionary = game.battle.enemies[target_index]
						var best_move := "tackle"
						var best_power := -1.0
						for move_id in GameData.SPECIES[actor.species].moves:
							var move: Dictionary = GameData.MOVES[move_id]
							var value: float = move.power * move.accuracy * GameRules.effectiveness(move.type,GameData.SPECIES[target.species].type) if move.kind == "damage" else 0.0
							if value > best_power:
								best_move = move_id
								best_power = value
						game.battle.actions.append({"actor":actor_index,"kind":"move","move":best_move,"target":target_index})
					game.resolve_round()
					rounds += 1
				if game.battle_finished: wins += 1
				rounds_total += rounds
			print("%s %s: %d/100 wins, %.1f rounds" % [difficulty,encounter_id,wins,rounds_total/100.0])
			assert(wins >= 85, "Encounter too punishing for a fresh starter team")
	# Novice strategy: always use the first basic attack, with no type matching or items.
	for encounter_id in GameData.ENCOUNTERS:
		var wins := 0
		for seed_value in 100:
			game.state = {"party":[GameData.make_pokemon("bulbasaur"),GameData.make_pokemon("charmander"),GameData.make_pokemon("squirtle")],"settings":{"difficulty":"normal"},"current_node":"airstrip"}
			game.defeated = false
			game.rng.seed = seed_value
			game.start_battle(encounter_id,"summit" if encounter_id == "summit_3" else "meadow")
			for turn in 40:
				if game.battle_finished or game.defeated: break
				for actor_index in game.living_party_indices():
					game.battle.actions.append({"actor":actor_index,"kind":"move","move":GameData.SPECIES[game.state.party[actor_index].species].moves[0],"target":game.living_enemy_indices()[0]})
				game.resolve_round()
			if game.battle_finished: wins += 1
		print("Novice normal %s: %d/100 wins" % [encounter_id,wins])
		assert(wins >= 70, "Basic attacks should still give novice players a fair chance")
	print("Balance simulations passed.")
	quit()
