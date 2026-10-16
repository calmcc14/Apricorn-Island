extends SceneTree

var random := RandomNumberGenerator.new()
var messages: Array[String] = []

func _init() -> void: call_deferred("run")

func mon(species: String, id: String = "") -> Dictionary:
	var pokemon := GameData.make_pokemon(species,random)
	pokemon.held_item = id
	return pokemon

func run() -> void:
	random.seed = 124
	var giratina := mon("giratina","item_griseous_orb")
	ItemProgression.form(giratina,false)
	assert(giratina.form == "giratina-origin")
	assert(is_equal_approx(ItemCatalog.move_power_multiplier(giratina,"dragon"),1.2))
	assert(ItemProgression.use_core("item_griseous_core",giratina))
	assert(is_equal_approx(ItemCatalog.move_power_multiplier(giratina,"ghost"),1.5))
	assert(is_equal_approx(ItemCatalog.move_power_multiplier(giratina,"fire"),1.0))
	var before := giratina.duplicate(true)
	ItemProgression.form(giratina,false)
	assert(giratina == before)
	assert(ItemProgression.use_core("item_griseous_core",giratina))
	assert(giratina.form == "giratina-origin")
	assert(is_equal_approx(ItemCatalog.move_power_multiplier(giratina,"ghost"),1.2))
	giratina.held_item = ""
	ItemProgression.form(giratina,false)
	assert(giratina.form == "giratina")
	for entry in [["dialga","item_adamant_crystal","item_adamant_daimond","steel"],["palkia","item_lustrous_globe","item_lustrous_pearl","water"]]:
		var p := mon(str(entry[0]),str(entry[2]))
		assert(is_equal_approx(ItemCatalog.move_power_multiplier(p,str(entry[3])),1.2))
		assert(ItemProgression.use_core(str(entry[1]),p))
		assert(is_equal_approx(ItemCatalog.move_power_multiplier(p,str(entry[3])),1.5))
		assert(ItemProgression.use_core(str(entry[1]),p))
		assert(is_equal_approx(ItemCatalog.move_power_multiplier(p,str(entry[3])),1.2))
	var bulba := mon("bulbasaur")
	ItemMechanics.grant_experience(bulba,ItemMechanics.experience_at(15,4)-int(bulba.experience))
	assert(bulba.level == 15)
	assert(ItemProgression.candy(bulba,true))
	assert(bulba.level == 16 and bulba.species == "ivysaur")
	bulba = mon("bulbasaur","item_everstone")
	bulba.level = 100
	assert(not ItemProgression.candy(bulba,true))
	bulba.held_item = ""
	assert(ItemProgression.candy(bulba,true) and bulba.level == 100 and bulba.species == "ivysaur")
	var source := {"inventory":{"item_red_orb":3},"party":[],"reserve":[],"chest_stores":{},"orb_boss_caught":{}}
	BossOrbs.initialize(source)
	assert(source.orb_instances.item_red_orb.size() == 3)
	assert(BossOrbs.attempt(source,"item_red_orb",0,random))
	BossOrbs.outcome(source,"item_red_orb",0,"loss")
	assert(BossOrbs.available(source,"item_red_orb",0))
	BossOrbs.outcome(source,"item_red_orb",0,"knockout")
	assert(not BossOrbs.available(source,"item_red_orb",0))
	BossOrbs.cleared_levels(source,4,random)
	assert(source.orb_instances.item_red_orb[0].cooldown == 1)
	BossOrbs.cleared_levels(source,1,random)
	assert(BossOrbs.available(source,"item_red_orb",0))
	BossOrbs.outcome(source,"item_red_orb",0,"capture")
	assert(not BossOrbs.available(source,"item_red_orb",0))
	var extra: Dictionary = source.orb_instances.item_red_orb[1]
	extra.meter = 0
	assert(not BossOrbs.attempt(source,"item_red_orb",1,random) and extra.meter == 0)
	assert(BossOrbs.label(extra) == "No power")
	extra.meter = 100
	assert(BossOrbs.attempt(source,"item_red_orb",1,random))
	BossOrbs.outcome(source,"item_red_orb",1,"loss")
	assert(extra.meter == 95 and not extra.held_only and extra.first_retry)
	extra.meter = 0
	assert(BossOrbs.attempt(source,"item_red_orb",1,random))
	BossOrbs.outcome(source,"item_red_orb",1,"knockout")
	assert(extra.cooldown == 5 and not extra.held_only)
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(source))
	var snapshot := loaded.duplicate(true)
	BossOrbs.initialize(loaded)
	assert(loaded == snapshot)
	var actor := mon("bulbasaur","item_grass_gem")
	var target := mon("squirtle")
	target.max_hp = 1000
	target.hp = 1000
	MoveEffects.resolve(actor,target,"vine_whip",{"enemies":[target]},{"party":[actor]},random,messages,1,true)
	assert(actor.held_item == "" and target.hp < 1000)
	actor.held_item = "item_grass_gem"
	target.protected = true
	MoveEffects.resolve(actor,target,"vine_whip",{"enemies":[target]},{"party":[actor]},random,messages,1,true)
	assert(actor.held_item == "item_grass_gem")
	target.erase("protected")
	actor = mon("bulbasaur","item_power_herb")
	MoveEffects.resolve(actor,target,"solar_beam",{"enemies":[target]},{"party":[actor]},random,messages,1,true)
	assert(actor.held_item == "" and not actor.has("charging_move"))
	actor = mon("bulbasaur")
	MoveEffects.resolve(actor,target,"solar_beam",{"enemies":[target]},{"party":[actor]},random,messages,1,true)
	assert(actor.charging_move == "solar_beam")
	assert(not PendingItems.move_allowed(actor,"tackle"))
	actor = mon("bulbasaur","item_safety_goggles")
	var hp := int(actor.hp)
	MoveEffects.end_turn(actor,{"weather":"sand"},random,messages)
	assert(actor.hp == hp)
	actor = mon("bulbasaur","item_heavy_duty_boots")
	hp = int(actor.hp)
	PendingItems.entry_hazards(actor,{"player_hazards":{"spikes":3,"stealth_rock":1,"toxic_spikes":2}},true,random)
	assert(actor.hp == hp and actor.status_condition == "")
	actor.held_item = ""
	PendingItems.entry_hazards(actor,{"player_hazards":{"spikes":3}},true,random)
	assert(actor.hp < hp)
	assert(PendingItems.flag(GameData.MOVES.tackle,"contact"))
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	game.start_endless("bulbasaur")
	game.state.inventory.item_red_orb = 2
	game.start_orb_boss("item_red_orb",0)
	assert(game.battle.has("orb_item"))
	var boss: Dictionary = game.battle.enemies[0]
	assert(boss.form == "groudon-primal")
	assert(boss.max_hp == int(floor(int(boss.boss_normal_hp)*1.5)))
	var normal_hp := int(boss.boss_normal_hp)
	game.state.inventory.item_master_ball = 1
	game.resolve_ball_action({"actor":0,"target":0,"ball":"item_master_ball"},messages)
	var caught: Dictionary = game.state.party[-1]
	assert(caught.species == "groudon" and caught.max_hp == normal_hp and caught.held_item == "")
	game.finish_victory()
	assert(game.state.orb_instances.item_red_orb[0].held_only)
	game.start_orb_boss("item_red_orb",0)
	assert(not game.battle.has("orb_item"))
	game.queue_free()
	print("Forms, evolution, Gems, charging, hazards, boss capture, per-copy meters, recharge, loss penalties and persistence passed.")
	quit()
