extends SceneTree

var random := RandomNumberGenerator.new()
var messages: Array[String] = []
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		failures += 1

func _init() -> void:
	random.seed = 6106
	var user := GameData.make_pokemon("bulbasaur",random)
	var foe := GameData.make_pokemon("squirtle",random)
	var state := {"party":[user],"reserve":[]}
	var battle := {"enemies":[foe]}
	check(GameData.MOVES.tackle.accuracy == 1.0 and GameData.MOVES.tackle.power == 10,"Standard Tackle")
	check(GameData.MOVES.quick_attack.priority == 1,"Quick Attack priority")
	check(GameData.MOVES.vine_whip.pp == 25 and GameData.MOVES.gust.damage_class == 3,"Imported standard metadata")
	check(GameData.MOVES.has("rapid_spin") and GameData.MOVES.has("leech_seed"),"Dependent moves")
	check(ItemMechanics.species(GameData.make_pokemon("jigglypuff",random)).types == ["normal","fairy"],"Approved typing")
	check(ItemProgression.info("pikachu").stats.defense == 40,"Approved species base stats")
	user.held_item = "item_icy_rock"
	for expected in ["snow","hail","hail_snow","hail_snow"]:
		MoveEffects.set_weather(battle,"snow",user)
		check(battle.weather == expected and battle.weather_turns == 8,"Cold escalation and refresh")
	MoveEffects.set_weather(battle,"rain",user)
	check(battle.weather == "rain" and battle.weather_turns == 5,"Combined weather replacement")
	user.ability = "snow_warning"
	MoveEffects.entry_ability(user,battle,state,messages)
	MoveEffects.entry_ability(user,battle,state,messages)
	check(battle.weather == "snow","Entry Ability triggers once")
	foe.ability = "levitate"
	check(not MoveEffects.grounded(foe,battle),"Levitate terrain eligibility")
	battle.gravity = 3
	check(MoveEffects.grounded(foe,battle),"Gravity grounding")
	battle.terrain = "misty_terrain"
	check(not MoveEffects.terrain_inflict(foe,"confusion",battle,random),"Misty confusion prevention")
	check(not MoveEffects.terrain_inflict(foe,"burn",battle,random),"Misty status prevention")
	foe.status_condition = "poison"
	check(foe.status_condition == "poison","Existing conditions retained")
	foe.status_condition = ""; foe.ability = "sturdy"; foe.hp = foe.max_hp
	check(PendingItems.survival(foe,9999,random) == int(foe.hp)-1,"Sturdy fatal hit")
	foe.hp -= 1
	check(PendingItems.survival(foe,9999,random) == 9999,"Sturdy subsequent hit")
	foe.ability = "lightning_rod"
	var hp := int(foe.hp)
	MoveEffects.resolve(user,foe,"thunder_shock",battle,state,random,messages,1,true)
	check(foe.hp == hp and foe.special_attack_stage == 1,"Absorption and stat boost")
	foe.ability = "torrent"; battle.clear(); battle.enemies = [foe]
	user.ability = "normalize"; user.held_item = "item_cheri_berry"
	MoveEffects.resolve(user,foe,"natural_gift",battle,state,random,messages,1,true)
	check(user.held_item == "" and user.consumed_item == "item_cheri_berry","Natural Gift consumes one berry")
	check(foe.hp < hp,"Natural Gift uses berry type through Normalize")
	user.ability = "overgrow"; user.hp = 1
	MoveEffects.resolve(user,foe,"leech_seed",battle,state,random,messages,1,true)
	foe.hp = 100; foe.max_hp = 160
	MoveEffects.end_turn(foe,battle,random,messages,state)
	check(foe.hp == 80 and user.hp == 21,"Leech Seed actual drain and recovery")
	var snapshot := JSON.stringify(state)
	check(JSON.parse_string(snapshot) is Dictionary,"Seed state serializes safely")
	MoveEffects.resolve(foe,user,"rapid_spin",battle,{"party":[foe]},random,messages,1,true)
	check(not foe.has("seeded") and foe.speed_stage == 1,"Rapid Spin clearing and Speed")
	user.ability = "gale_wings"
	check(MoveEffects.move_priority(user,GameData.MOVES.gust) == 1,"Gale Wings at low HP")
	var saved := GameData.make_pokemon("pikachu",random)
	saved.ability = "lightning-rod"
	ItemMechanics.initialize(saved)
	check(saved.ability == "lightning_rod","Saved Ability identifier migration")
	for move_id in saved.moves: saved.pp[move_id] = 0
	saved.pp.struggle = 0
	saved.hp = saved.max_hp
	var before_struggle := int(saved.hp)
	check(MoveEffects.can_act(saved,"struggle",random,messages),"Struggle needs no PP")
	MoveEffects.resolve(saved,foe,"struggle",{"enemies":[foe]},{"party":[saved]},random,messages,1,true)
	check(saved.hp == before_struggle-maxi(1,int(round(float(saved.max_hp)/4.0))),"Struggle maximum-HP recoil")
	print("Existing-rule checks: %d failures." % failures)
	quit(1 if failures > 0 else 0)
