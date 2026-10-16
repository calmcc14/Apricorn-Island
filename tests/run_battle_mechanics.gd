extends SceneTree

func _init() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 42
	var fire := GameData.make_pokemon("charmander",random)
	var grass := GameData.make_pokemon("bulbasaur",random)
	var rock := GameData.make_pokemon("onix",random)
	assert(MoveEffects.stab(fire,"fire") == 1.5)
	assert(MoveEffects.stab(fire,"normal") == 1)
	assert(MoveEffects.effectiveness("water",rock) == 4)
	assert(MoveEffects.effectiveness("electric",rock) == 0)
	assert(GameData.MOVES.ember.has("effect_id"))
	var messages: Array[String] = []
	var state := {"party":[fire]}
	var battle := {"enemies":[grass]}
	grass.hp = 1000; grass.max_hp = 1000
	GameData.MOVES.ember.ailment_chance = 100
	MoveEffects.resolve(fire,grass,"ember",battle,state,random,messages,1,true)
	assert(grass.status_condition == "burn")
	assert(messages.has("It's super effective!"))
	var hp := int(grass.hp)
	MoveEffects.end_turn(grass,battle,random,messages)
	assert(grass.hp < hp)
	assert(not MoveEffects.inflict(fire,"burn",random))
	assert(not MoveEffects.inflict(grass,"sleep",random))
	var sleeper := GameData.make_pokemon("squirtle",random)
	assert(MoveEffects.inflict(sleeper,"sleep",random))
	sleeper.sleep_turns = 2
	assert(not MoveEffects.can_act(sleeper,"tackle",random,messages))
	assert(MoveEffects.inflict(sleeper,"confusion",random))
	assert(MoveEffects.status_label(sleeper) == "Sleep / Confused")
	var immune_hp := int(rock.hp)
	MoveEffects.resolve(fire,rock,"thunder_shock",{"enemies":[rock]},state,random,messages,1,true)
	assert(rock.hp == immune_hp)
	print("Battle mechanics passed: STAB, dual types, immunity, original move effects, status damage and action blocking.")
	quit()
