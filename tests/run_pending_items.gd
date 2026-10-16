extends SceneTree

var messages: Array[String] = []
var random := RandomNumberGenerator.new()

func mon(name: String = "bulbasaur", held: String = "") -> Dictionary:
	var p := GameData.make_pokemon(name,random)
	p.held_item = held
	return p

func _init() -> void: call_deferred("run")

func run() -> void:
	random.seed = 888
	var p := mon()
	p.status_condition = "toxic"
	p.toxic_turns = 5
	assert(ItemCatalog.apply(GameData.ITEMS.item_antidote,p))
	assert(p.status_condition == "" and not p.has("toxic_turns"))
	assert(not ItemCatalog.apply(GameData.ITEMS.item_antidote,p))
	p.hp = 0
	assert(not ItemCatalog.apply(GameData.ITEMS.item_full_restore,p))
	assert(ItemCatalog.apply(GameData.ITEMS.item_revival_herb,p) and p.hp == p.max_hp)
	assert(p.friendship == 55)
	p.pp.tackle = 0
	assert(PendingItems.pp_use(GameData.ITEMS.item_ether,p,"tackle",true) and p.pp.tackle == 10)
	assert(PendingItems.pp_use(GameData.ITEMS.item_pp_up,p,"tackle",true))
	assert(PendingItems.max_pp(p,"tackle") == 42)
	assert(PendingItems.pp_use(GameData.ITEMS.item_pp_max,p,"tackle",true))
	assert(PendingItems.max_pp(p,"tackle") == 56)
	assert(not PendingItems.pp_use(GameData.ITEMS.item_pp_up,p,"tackle",true))
	p.held_item = "item_leppa_berry"
	p.pp.tackle = 0
	assert(ItemMechanics.activate_berry(p,GameData.ITEMS,messages))
	assert(p.pp.tackle == 10 and p.held_item == "")
	p.held_item = "item_lum_berry"
	p.status_condition = "burn"
	p.confusion_turns = 3
	assert(ItemMechanics.activate_berry(p,GameData.ITEMS,messages))
	assert(p.status_condition == "" and not p.has("confusion_turns"))
	p = mon("bulbasaur","item_choice_band")
	assert(ItemMechanics.stat(p,"attack") == int(p.attack*1.5))
	PendingItems.select_move(p,"tackle")
	assert(not PendingItems.move_allowed(p,"growl"))
	ItemMechanics.reset_battle(p)
	assert(PendingItems.move_allowed(p,"growl"))
	p.held_item = "item_assault_vest"
	assert(not PendingItems.move_allowed(p,"growl") and PendingItems.move_allowed(p,"tackle"))
	p = mon("bulbasaur","item_eviolite")
	assert(ItemMechanics.stat(p,"defense") == int(p.defense*1.5))
	p = mon("bulbasaur","item_focus_sash")
	var damage := PendingItems.survival(p,999,random)
	assert(damage == p.hp-1 and p.held_item == "")
	p.hp -= damage
	assert(PendingItems.survival(p,999,random) == 999)
	p = mon("bulbasaur","item_leftovers")
	p.hp = 1
	PendingItems.end_turn(p)
	assert(p.hp == 1+maxi(1,int(p.max_hp)/16))
	p.heal_block = 2
	var hp := int(p.hp)
	PendingItems.end_turn(p)
	assert(p.hp == hp)
	p = mon("bulbasaur","item_liechi_berry")
	p.hp = 1
	PendingItems.activate(p,{},random)
	assert(p.attack_stage == 1 and p.held_item == "")
	p = mon("bulbasaur","item_occa_berry")
	assert(PendingItems.reduce_hit(mon("charmander"),p,{"type":"fire"},20,2) == 10 and p.held_item == "")
	p = mon("bulbasaur","item_chilan_berry")
	assert(PendingItems.reduce_hit(p,p,{"type":"normal"},20,1,true) == 10)
	p = mon("bulbasaur","item_white_herb")
	p.attack_stage = -3
	p.defense_stage = 2
	PendingItems.activate(p,{},random)
	assert(p.attack_stage == 0 and p.defense_stage == 2 and p.held_item == "")
	p = mon("bulbasaur","item_cleanse_tag")
	assert(not MoveEffects.inflict(p,"burn",random))
	assert(ItemMechanics.raise_stat(p,"defense",-1,true))
	assert(ItemMechanics.raise_stat(p,"attack",2))
	p.held_item = "item_pure_incense"
	assert(not ItemMechanics.raise_stat(p,"defense",-1,true))
	assert(not ItemMechanics.raise_stat(p,"attack",1))
	p = mon()
	p.evs = {"attack":250,"defense":252,"speed":7}
	assert(PendingItems.ev_use(GameData.ITEMS.item_protein,p,true))
	assert(p.evs.attack == 251)
	assert(not PendingItems.ev_use(GameData.ITEMS.item_protein,p,true))
	assert(PendingItems.ev_use(GameData.ITEMS.item_kelpsy_berry,p,true) and p.evs.attack == 241)
	p.level = 49
	assert(not PendingItems.hyper_train(p,"attack",false,true))
	p.level = 50
	p.ivs.attack = 0
	assert(PendingItems.hyper_train(p,"attack",false,true))
	assert(p.ivs.attack == 0 and p.hyper_trained.attack)
	assert(not PendingItems.hyper_train(p,"attack",false,true))
	var party: Array = [mon(),mon("squirtle")]
	party[0].hp = 1
	party[0].pp.tackle = 0
	party[1].hp = 0
	assert(PendingItems.sacred_ash("item_sacred_ash_ketchum",party,true))
	assert(party[0].hp == 1 and party[0].pp.tackle == 0 and party[1].hp == party[1].max_hp)
	assert(not PendingItems.sacred_ash("item_sacred_ash",party,true))
	party[1].hp = 0
	assert(PendingItems.sacred_ash("item_sacred_ash",party,true))
	assert(party[0].hp == party[0].max_hp and party[0].pp.tackle == PendingItems.max_pp(party[0],"tackle"))
	assert(PendingItems.ability_patch(p,true) and p.ability_slot == "hidden")
	assert(PendingItems.ability_patch(p,true) and p.ability_slot == "1")
	var save := {"inventory":{"item_modern_exp_share":2,"item_exp_share":3},"party":[],"reserve":[]}
	ItemCatalog.migrate(save)
	assert(save.inventory.item_exp_share == 5 and not save.inventory.has("item_modern_exp_share"))
	var again := save.duplicate(true)
	ItemCatalog.migrate(save)
	assert(again == save)
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.start_new_game("bulbasaur")
	game.state.party = [mon("bulbasaur","item_lagging_tail")]
	game.battle = {"enemies":[mon("squirtle")],"trick_room":0}
	var action := {"actor":0,"kind":"move","move":"tackle"}
	assert(game.action_speed(action,true) < game.action_speed(action,false))
	game.battle.trick_room = 5
	assert(game.action_speed(action,true) < game.action_speed(action,false))
	game.queue_free()
	print("Pending item checks passed: cures, PP, berries, held stats, survival, EV limits, Hyper Training, Ash, ability slots, save migration and ordering.")
	quit()
