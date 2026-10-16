extends SceneTree

class Trial extends "res://scripts/main.gd":
	var legacy_order := false
	var lost := false
	func save_game() -> bool: return true
	func show_battle() -> void: pass
	func show_map(_message := "") -> void: pass
	func handle_defeat() -> void: lost = true
	func action_speed(action: Dictionary, player: bool) -> float:
		return super.action_speed(action,player)+(10000000 if player and legacy_order else 0)

func _init() -> void: call_deferred("run")
func run() -> void:
	var game := Trial.new()
	root.add_child(game)
	for old in [true,false]:
		var wins := 0
		for seed_value in 100:
			game.state = {"party":[GameData.make_pokemon("bulbasaur"),GameData.make_pokemon("charmander"),GameData.make_pokemon("squirtle")],"settings":{"difficulty":"normal"},"current_node":"airstrip"}
			game.rng.seed = seed_value
			game.legacy_order = old
			game.lost = false
			game.start_battle("summit_3","summit")
			for turn in 30:
				if game.battle_finished or game.lost: break
				for i in game.living_party_indices():
					game.battle.actions.append({"actor":i,"kind":"move","move":GameData.SPECIES[game.state.party[i].species].moves[0],"target":game.living_enemy_indices()[0]})
				game.resolve_round()
			if game.battle_finished: wins += 1
		print("Legacy ordering: %s; basic-attack summit wins: %d/100" % [old,wins])
	game.queue_free()
	quit()
