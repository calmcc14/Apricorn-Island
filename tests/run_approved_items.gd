extends SceneTree

class TestGame extends "res://scripts/main.gd":
	var fail_save := false
	func save_game() -> bool:
		ItemCatalog.migrate(state)
		return not fail_save
	func show_inventory() -> void: pass
	func show_battle() -> void: pass
	func show_map(_message := "") -> void: pass

func _init() -> void: call_deferred("run")

func multiplier(id: String, target: Dictionary, actor: Dictionary, context: Dictionary = {}, caught: Array = []) -> float:
	return ItemMechanics.ball_multiplier(id,target,actor,context,caught,GameData.ITEMS[id])

func run() -> void:
	var target := GameData.make_pokemon("squirtle")
	var actor := GameData.make_pokemon("squirtle")
	assert(multiplier("item_quick_ball",target,actor,{"turn":1}) == 5)
	assert(multiplier("item_quick_ball",target,actor,{"turn":2}) == 1)
	assert(multiplier("item_dusk_ball",target,actor,{"night":true,"cave":true}) == 3)
	assert(multiplier("item_dusk_ball",target,actor) == 1)
	assert(multiplier("item_timer_ball",target,actor,{"turn":1}) == 1)
	assert(is_equal_approx(multiplier("item_timer_ball",target,actor,{"turn":10}),3.7))
	assert(multiplier("item_timer_ball",target,actor,{"turn":11}) == 4)
	assert(multiplier("item_timer_ball",target,actor,{"turn":100}) == 4)
	assert(multiplier("item_net_ball",target,actor) == 3)
	assert(multiplier("item_net_ball",GameData.make_pokemon("caterpie"),actor) == 3)
	assert(multiplier("item_repeat_ball",target,actor,{},["squirtle"]) == 3)
	assert(multiplier("item_repeat_ball",target,actor) == 1)
	target.status_condition = "sleep"
	assert(multiplier("item_dream_ball",target,actor) == 4)
	target.status_condition = ""
	assert(multiplier("item_dream_ball",target,actor) == 1)
	assert(multiplier("item_dive_ball",target,actor,{"water":true}) == 3.5)
	for entry in [["clean",5.0,4.0],["worn",4.0,3.5],["dirty",3.0,3.5]]:
		var id := "item_%s_lure_ball" % entry[0]
		assert(multiplier(id,target,actor,{"fishing":true,"water":true}) == entry[1])
		assert(multiplier(id,target,actor,{"water":true}) == entry[2])
		assert(multiplier(id,target,actor) == 1)
	assert(multiplier("item_fest_ball",GameData.make_pokemon("magnemite"),actor) == 4)
	assert(multiplier("item_fest_ball",target,actor) == 1)
	assert(multiplier("item_fast_ball",GameData.make_pokemon("pikachu"),actor) == 1)
	var fast_reference: Dictionary = ItemMechanics.data().species.pikachu
	var saved_speed := int(fast_reference.base_speed)
	fast_reference.base_speed = 100
	assert(multiplier("item_fast_ball",GameData.make_pokemon("pikachu"),actor) == 4)
	fast_reference.base_speed = saved_speed
	actor.gender = "male"
	target.gender = "female"
	assert(multiplier("item_love_ball",target,actor) == 8)
	target.gender = "genderless"
	assert(multiplier("item_love_ball",target,actor) == 1)
	assert(multiplier("item_moon_ball",GameData.make_pokemon("jigglypuff"),actor) == 4)
	assert(multiplier("item_moon_ball",target,actor) == 1)
	var full_chance := ItemMechanics.capture_chance(1,target)
	target.hp = 1
	assert(ItemMechanics.capture_chance(1,target) > full_chance)
	target.status_condition = "sleep"
	assert(ItemMechanics.capture_chance(1,target) > full_chance)
	var messages: Array[String] = []
	for berry in ["sitrus","figy","wiki","mago","aguav","iapapa"]:
		for prefix in ["expired_","","ripe_"]:
			var id: String = "item_"+str(prefix)+str(berry)+"_berry"
			var item: Dictionary = GameData.ITEMS[id]
			var holder := GameData.make_pokemon("bulbasaur")
			holder.max_hp = 120
			holder.hp = int(120*float(item.threshold))+1
			holder.held_item = id
			holder.nature = "hardy"
			assert(not ItemMechanics.activate_berry(holder,GameData.ITEMS,messages))
			holder.hp -= 1
			var before := int(holder.hp)
			assert(ItemMechanics.activate_berry(holder,GameData.ITEMS,messages))
			assert(holder.held_item == "")
			assert(holder.hp == before+(int(item.amount) if int(item.amount) > 0 else int(120*float(item.fraction))))
			assert(not ItemMechanics.activate_berry(holder,GameData.ITEMS,messages))
	var dislike := GameData.make_pokemon("bulbasaur")
	dislike.hp = 1
	dislike.nature = "bold"
	dislike.held_item = "item_figy_berry"
	assert(ItemMechanics.activate_berry(dislike,GameData.ITEMS,messages))
	assert(dislike.confusion_turns > 0)
	dislike.hp = 0
	dislike.held_item = "item_ripe_sitrus_berry"
	assert(not ItemMechanics.activate_berry(dislike,GameData.ITEMS,messages))
	for stat_id in ["attack","defense","sp_atk","sp_def","speed","accuracy"]:
		var item: Dictionary = GameData.ITEMS["item_x_"+stat_id]
		var pokemon := GameData.make_pokemon("charmander")
		assert(ItemCatalog.apply(item,pokemon))
		assert(pokemon[str(item.stat)+"_stage"] == 2)
		assert(ItemCatalog.apply(GameData.ITEMS["item_y_"+stat_id],pokemon))
		assert(pokemon[str(item.stat)+"_stage"] == 3)
		ItemMechanics.raise_stat(pokemon,str(item.stat),100)
		assert(pokemon[str(item.stat)+"_stage"] == 6)
		assert(not ItemCatalog.apply(item,pokemon))
		ItemMechanics.reset_battle(pokemon)
		assert(pokemon[str(item.stat)+"_stage"] == 0)
	var pokemon := GameData.make_pokemon("charmander")
	assert(ItemCatalog.apply(GameData.ITEMS.item_z_accuracy,pokemon))
	assert(not ItemCatalog.apply(GameData.ITEMS.item_z_accuracy,pokemon))
	var random := RandomNumberGenerator.new()
	random.seed = 9
	var immune := GameData.make_pokemon("pidgey")
	var battle := {"enemies":[immune]}
	var state := {"party":[pokemon],"reserve":[]}
	MoveEffects.resolve(pokemon,immune,"fissure",battle,state,random,messages)
	assert(immune.hp == immune.max_hp)
	immune = GameData.make_pokemon("onix")
	immune.level = 100
	battle.enemies = [immune]
	MoveEffects.resolve(pokemon,immune,"fissure",battle,state,random,messages)
	assert(immune.hp == immune.max_hp)
	var party := [GameData.make_pokemon("bulbasaur"),GameData.make_pokemon("charmander"),GameData.make_pokemon("squirtle")]
	party[1].held_item = "item_exp_share"
	assert(ItemMechanics.experience_shares(party,[0],120,"classic") == [60,60,0])
	assert(ItemMechanics.experience_shares(party,[0.0],120,"classic") == [60,60,0])
	assert(ItemMechanics.experience_shares(party,[0],120,"modern") == [120,60,60])
	assert(ItemMechanics.experience_shares(party,[0,1],120,"all") == [40,40,10])
	party[2].hp = 0
	assert(ItemMechanics.experience_shares(party,[0],120,"all") == [80,20,0])
	assert(ItemMechanics.grant_experience(party[0],1000000) > 0)
	assert(party[0].level <= 100)
	var migrated := {"inventory":{"item_tm01":2,"item_tm001":3,"item_lure_ball":7,"item_tr00":4},"party":[GameData.make_pokemon("pikachu")],"reserve":[],"inventory_slots":[{"id":"item_lure_ball","count":7}],"chest_stores":{"old":{"item_lure_ball":2}}}
	ItemCatalog.migrate(migrated)
	assert(migrated.inventory.item_tm001 == 5)
	assert(migrated.inventory.item_dirty_lure_ball == 7)
	assert(migrated.inventory_slots[0].id == "item_dirty_lure_ball")
	assert(migrated.chest_stores.old.item_dirty_lure_ball == 2)
	var migrated_twice := migrated.duplicate(true)
	ItemCatalog.migrate(migrated)
	assert(migrated == migrated_twice)
	assert(ItemCatalog.data().tm_count == 348 and ItemCatalog.data().hm_count == 11 and ItemCatalog.data().tr_count == 100)
	var game := TestGame.new()
	root.add_child(game)
	game.start_new_game("bulbasaur")
	game.state.party.append(GameData.make_pokemon("charmander"))
	game.state.party.append(GameData.make_pokemon("squirtle"))
	var machine := ""
	for item in ItemCatalog.data().items:
		if item.kind == "machine" and item.machine_family == "tm" and ItemMechanics.can_teach(item,game.state.party[0]): machine = str(item.id); break
	assert(machine != "")
	game.state.inventory[machine] = 2
	var before_moves: Array = game.state.party[0].moves.duplicate()
	assert(not game.teach_machine(machine,0))
	assert(game.state.inventory[machine] == 2 and game.state.party[0].moves == before_moves)
	game.fail_save = true
	assert(not game.teach_machine(machine,0,0))
	assert(game.state.inventory[machine] == 2 and game.state.party[0].moves == before_moves)
	game.fail_save = false
	assert(game.teach_machine(machine,0,0))
	assert(game.state.inventory[machine] == 1)
	assert(not game.teach_machine(machine,0,1))
	assert(game.state.inventory[machine] == 1)
	var hm := "item_hm001"
	game.state.inventory[hm] = 1
	assert(game.teach_machine(hm,0,1))
	assert(game.state.inventory[hm] == 1)
	game.state.inventory.item_friend_ball = 1
	game.start_battle("meadow_1","meadow")
	game.debug_options.capture = true
	game.resolve_ball_action({"ball":"item_friend_ball","actor":0,"target":0},messages)
	assert(game.state.reserve[-1].friendship == 200)
	assert("caterpie" in game.state.caught_species)
	assert(game.state.inventory.item_friend_ball == 0)
	assert(not GameData.ITEMS.has("item_dreamy_ball"))
	assert(ItemCatalog.item_probability("item_dreamy_ball",100) == 0)
	assert(not game.battle_items().has("item_dreamy_ball"))
	game.state.enabled_dlc = "spinoff"
	game.state.inventory.item_dreamy_ball = 1
	game.start_battle("meadow_1","meadow")
	game.battle.context.entree_forest = true
	game.debug_options.capture = false
	game.resolve_ball_action({"ball":"item_dreamy_ball","actor":0,"target":0},messages)
	assert(game.battle.enemies[0].hp == 0)
	game.state.inventory.item_dreamy_ball = 1
	var inventory_ui = load("res://scripts/block_inventory.gd").new()
	inventory_ui.game = game
	game.ui.add_child(inventory_ui)
	await process_frame
	assert(inventory_ui.bags.inventory.any(func(stack): return not stack.is_empty() and stack.id == "item_dreamy_ball"))
	game.show_item_details("item_dreamy_ball",inventory_ui.detail)
	# Execute every imported definition to catch runtime errors in rare move paths.
	for move_id in GameData.MOVES:
		if not GameData.MOVES[move_id].has("effect_id"): continue
		var user := GameData.make_pokemon("bulbasaur")
		user.moves = [move_id]
		var foe := GameData.make_pokemon("squirtle")
		var test_state := {"party":[user],"reserve":[GameData.make_pokemon("pikachu")]}
		var test_battle := {"enemies":[foe]}
		var move: Dictionary = GameData.MOVES[move_id]
		MoveEffects.resolve(user,user if int(move.target) in [4,5,7,12,13,14] else foe,move_id,test_battle,test_state,random,messages)
		assert(not messages.is_empty())
	game.queue_free()
	await process_frame
	print("Approved item checks passed: balls, berries, boosts, XP, machines, migration, DLC isolation and every machine move runtime path.")
	quit()

