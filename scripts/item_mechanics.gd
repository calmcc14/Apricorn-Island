class_name ItemMechanics
extends RefCounted

static var reference: Dictionary = {}
const IV_STATS := ["hp","attack","defense","special_attack","special_defense","speed"]
const IV_NAMES := ["HP","Attack","Defense","Sp. Atk","Sp. Def","Speed"]

static func roll_ivs(random: RandomNumberGenerator) -> Dictionary:
	var spread := {}
	for stat_name in IV_STATS: spread[stat_name] = random.randi_range(0,31)
	return spread

static func iv_judgment(value: int) -> String:
	if value == 31: return "Best"
	if value == 30: return "Fantastic"
	if value >= 26: return "Very good"
	if value >= 16: return "Pretty good"
	if value >= 1: return "Decent"
	return "No good"

static func apply_iv_bonuses(pokemon: Dictionary) -> void:
	if not pokemon.has("iv_stat_bonuses"): pokemon.iv_stat_bonuses = {}
	for stat_name in IV_STATS:
		var stat_key: String = "max_hp" if stat_name == "hp" else str(stat_name)
		var iv := 31 if pokemon.get("hyper_trained",{}).get(stat_name,false) else int(pokemon.ivs[stat_name])
		var bonus := int(iv*clampi(int(pokemon.level),1,100)/100.0)
		var change := bonus-int(pokemon.iv_stat_bonuses.get(stat_name,0))
		pokemon[stat_key] = maxi(1,int(pokemon.get(stat_key,10))+change)
		if stat_name == "hp" and int(pokemon.hp) > 0: pokemon.hp = clampi(int(pokemon.hp)+change,1,int(pokemon.max_hp))
		pokemon.iv_stat_bonuses[stat_name] = bonus

static func data() -> Dictionary:
	if reference.is_empty():
		reference = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_reference.json"))
		for info in reference.species.values(): info.compatible_moves = info.compatible_moves.map(func(value): return int(value))
	return reference

static func species(pokemon: Dictionary) -> Dictionary:
	var name := str(pokemon.get("form",pokemon.get("species","")))
	var original: Dictionary = ItemProgression.info(name).duplicate(true)
	if name == str(pokemon.get("species","")): original.merge(data().species.get(name,{}),true)
	return original

static func initialize(pokemon: Dictionary) -> void:
	var info := species(pokemon)
	if not pokemon.has("ability_slot"): pokemon.ability_slot = "1"
	if not pokemon.has("ability"): pokemon.ability = str(info.get("abilities",{}).get(str(pokemon.ability_slot),""))
	var defaults := {"held_item":"", "status_condition":"", "confusion_turns":0, "nature":"hardy", "friendship":int(info.get("base_friendship",70)), "level":5, "experience":0, "evs":{}, "stat_experience":{}, "special_attack":int(pokemon.get("attack",10)), "special_defense":int(pokemon.get("defense",10)), "speed":int(info.get("base_speed",50)), "gender":"genderless"}
	if not pokemon.has("gender"):
		var rate := int(info.get("gender_rate",-1))
		defaults.gender = "genderless" if rate < 0 else ("female" if randi_range(0,7) < rate else "male")
	for key in defaults:
		if not pokemon.has(key): pokemon[key] = defaults[key]
	if not pokemon.has("moves"): pokemon.moves = GameData.SPECIES.get(str(pokemon.get("species","")),{"moves":[]}).moves.duplicate()
	if not pokemon.has("pp"): pokemon.pp = {}
	for move_id in pokemon.moves:
		if not pokemon.pp.has(move_id): pokemon.pp[move_id] = int(GameData.MOVES[move_id].get("pp",35))
	if not pokemon.has("experience") or int(pokemon.experience) == 0: pokemon.experience = experience_at(int(pokemon.level),int(info.get("growth_rate",2)))
	if not pokemon.has("base_progression"):
		pokemon.base_progression = {}
		for stat in ["max_hp","attack","defense","special_attack","special_defense"]: pokemon.base_progression[stat] = int(pokemon.get(stat,10))
		pokemon.base_progression.level = int(pokemon.level)
	# Old saves receive a repeatable spread without consuming combat randomness.
	var iv_random := RandomNumberGenerator.new()
	iv_random.seed = hash("%s:%s:%s:%s" % [pokemon.get("species",""),pokemon.get("nature","hardy"),pokemon.get("gender","genderless"),JSON.stringify(pokemon.base_progression)])
	var fallback := roll_ivs(iv_random)
	if not pokemon.has("ivs") or not pokemon.ivs is Dictionary: pokemon.ivs = {}
	for stat_name in IV_STATS: pokemon.ivs[stat_name] = clampi(int(pokemon.ivs.get(stat_name,fallback[stat_name])),0,31)
	apply_iv_bonuses(pokemon)
	PendingItems.apply_ev_bonuses(pokemon)

static func reset_battle(pokemon: Dictionary) -> void:
	if pokemon.has("transform_original"):
		pokemon.merge(pokemon.transform_original,true)
		pokemon.erase("transform_original")
		pokemon.erase("original_species")
	if pokemon.has("original_ability"):
		pokemon.ability = pokemon.original_ability
		pokemon.erase("original_ability")
	initialize(pokemon)
	if pokemon.has("original_moves"):
		pokemon.moves = pokemon.original_moves
		pokemon.erase("original_moves")
	for stat in ["attack","defense","special_attack","special_defense","speed","accuracy","evasion"]: pokemon[stat+"_stage"] = 0
	for key in ["accuracy_bypass","protected","flinched","recharging","substitute_hp","confusion_turns","seeded","taunted","disabled_move","encore_move","encore_turns","trapped_turns","charging_move","semi_invulnerable","protect_streak","cursed","nightmare","tormented","attracted","embargo","heal_block","telekinesis","reflect","light_screen","safeguard","tailwind","aurora_veil","endure","last_damage","last_move","critical_stage","charged","helping_hand","imprison","snatch","quashed","consumed_item","toxic_turns"]: pokemon.erase(key)
	pokemon.erase("held_suppressed")
	ItemProgression.form(pokemon,false)
	for key in ["choice_move","custap_ready","micle_ready","quick_first","band_active","metronome_move","metronome_count","acted_this_turn","binding_damage"]: pokemon.erase(key)

static func held_kind(item: Dictionary) -> bool:
	return (item.get("kind","") in ["held_power","held_berry","held_exp","cure_berry","held_effect","boss_orb"] or item.get("id","") == "item_leppa_berry") and item.get("status","") == "implemented"

static func stage_multiplier(stage: int, accuracy: bool = false) -> float:
	var base := 3.0 if accuracy else 2.0
	var value := clampi(stage,-6,6)
	return (base+value)/base if value >= 0 else base/(base-value)

static func stat(pokemon: Dictionary, name: String) -> int:
	var multiplier := 1.0
	if pokemon.get("original_species",pokemon.get("species","")) == "ditto":
		if PendingItems.held(pokemon) == "item_metal_powder" and name == "defense": multiplier = 2.0
		if PendingItems.held(pokemon) == "item_quick_powder" and name == "speed": multiplier = 2.0
	return maxi(1,int(float(pokemon.get(name,10)) * stage_multiplier(int(pokemon.get(name+"_stage",0))) * multiplier * PendingItems.stat_multiplier(pokemon,name)))

static func raise_stat(pokemon: Dictionary, name: String, amount: int, external: bool = false) -> bool:
	if PendingItems.held(pokemon) == "item_pure_incense": return false
	if external and amount < 0 and PendingItems.held(pokemon) == "item_clear_amulet": return false
	var key := name+"_stage"
	var old := int(pokemon.get(key,0))
	pokemon[key] = clampi(old+amount,-6,6)
	return int(pokemon[key]) != old

static func can_boost(item: Dictionary, pokemon: Dictionary) -> bool:
	if int(pokemon.hp) <= 0: return false
	if item.get("bypass",false): return not pokemon.get("accuracy_bypass",false)
	return int(pokemon.get(str(item.stat)+"_stage",0)) < 6

static func boost(item: Dictionary, pokemon: Dictionary) -> bool:
	if not can_boost(item,pokemon): return false
	if item.get("bypass",false): pokemon.accuracy_bypass = true
	else: raise_stat(pokemon,str(item.stat),int(item.stages))
	return true

static func activate_berry(pokemon: Dictionary, items: Dictionary, messages: Array[String]) -> bool:
	if PendingItems.held_cure(pokemon,messages): return true
	var item: Dictionary = items.get(str(pokemon.get("held_item","")),{})
	if int(pokemon.get("embargo",0)) > 0 or int(pokemon.get("heal_block",0)) > 0 or pokemon.get("held_suppressed",false): return false
	if item.get("kind","") != "held_berry" or int(pokemon.hp) <= 0: return false
	if float(pokemon.hp) > float(pokemon.max_hp)*float(item.threshold) or int(pokemon.hp) >= int(pokemon.max_hp): return false
	var amount := int(item.amount) if int(item.amount) > 0 else maxi(1,int(float(pokemon.max_hp)*float(item.fraction)))
	var before := int(pokemon.hp)
	pokemon.hp = mini(int(pokemon.max_hp),before+amount)
	pokemon.consumed_item = str(pokemon.held_item)
	pokemon.held_item = ""
	var flavor := str(item.get("flavor",""))
	for nature in data().natures:
		if nature.identifier == pokemon.get("nature","hardy") and nature.decreased_stat_id != nature.increased_stat_id:
			var flavors := {"1":"spicy","2":"dry","3":"sweet","4":"bitter","5":"sour"}
			if flavor != "" and flavor == flavors.get(str(nature.hates_flavor_id),""): pokemon.confusion_turns = randi_range(2,5)
	messages.append("%s ate %s and recovered %d HP." % [GameData.SPECIES[pokemon.species].name,item.name,int(pokemon.hp)-before])
	if int(pokemon.get("confusion_turns",0)) > 0: messages.append("The disliked flavor caused confusion!")
	return true

static func ball_multiplier(id: String, target: Dictionary, actor: Dictionary, context: Dictionary, caught: Array, item: Dictionary) -> float:
	var info := species(target)
	var types: Array = info.get("types",[])
	match id:
		"item_quick_ball": return 5.0 if int(context.get("turn",1)) == 1 else 1.0
		"item_dusk_ball": return 3.0 if context.get("night",false) or context.get("cave",false) else 1.0
		"item_timer_ball": return minf(4.0,1.0+0.3*maxi(0,int(context.get("turn",1))-1))
		"item_net_ball": return 3.0 if "water" in types or "bug" in types else 1.0
		"item_repeat_ball": return 3.0 if str(target.species) in caught else 1.0
		"item_dream_ball": return 4.0 if target.get("status_condition","") == "sleep" else 1.0
		"item_dive_ball": return 3.5 if context.get("water",false) or "water" in types else 1.0
		"item_fest_ball": return 4.0 if str(target.species) in ["magnemite","grimer","tangela"] else 1.0
		"item_fast_ball": return 4.0 if int(info.get("base_speed",0)) >= 100 else 1.0
		"item_love_ball":
			var gender := str(actor.get("gender","genderless"))
			var other := str(target.get("gender","genderless"))
			return 8.0 if actor.species == target.species and gender in ["male","female"] and other in ["male","female"] and gender != other else 1.0
		"item_moon_ball": return 4.0 if info.get("moon_family",false) else 1.0
	if item.has("fishing_multiplier"):
		if context.get("fishing",false): return float(item.fishing_multiplier)
		if context.get("water",false): return float(item.water_multiplier)
	return 1.0

static func capture_chance(multiplier: float, target: Dictionary) -> float:
	var status_bonus := 2.5 if target.get("status_condition","") in ["sleep","freeze"] else (1.5 if target.get("status_condition","") != "" else 1.0)
	var rate := float(species(target).get("capture_rate",45))
	var value := (3.0*float(target.max_hp)-2.0*float(target.hp))/(3.0*maxf(1.0,float(target.max_hp))) * rate * multiplier * status_bonus
	return clampf(value/255.0,0.0,1.0)

static func experience_at(level: int, growth: int) -> int:
	var n := float(clampi(level,1,100))
	var cube := n*n*n
	match growth:
		1: return int(1.25*cube)
		3: return int(0.8*cube)
		4: return maxi(0,int(1.2*cube-15*n*n+100*n-140))
		5:
			if n <= 50: return int(cube*(100-n)/50)
			if n <= 68: return int(cube*(150-n)/100)
			if n <= 98: return int(cube*floor((1911-10*n)/3)/500)
			return int(cube*(160-n)/100)
		6:
			if n <= 15: return int(cube*(floor((n+1)/3)+24)/50)
			if n <= 36: return int(cube*(n+14)/50)
			return int(cube*(floor(n/2)+32)/50)
	return int(cube)

static func level_progress(pokemon: Dictionary) -> Dictionary:
	initialize(pokemon)
	var level := clampi(int(pokemon.level),1,100)
	if level == 100: return {"current":0,"required":0,"remaining":0,"ratio":1.0,"label":"MAX LEVEL"}
	var growth := int(species(pokemon).get("growth_rate",2))
	var floor_exp := experience_at(level,growth)
	var required := maxi(1,experience_at(level+1,growth)-floor_exp)
	var current := clampi(int(pokemon.experience)-floor_exp,0,required)
	return {"current":current,"required":required,"remaining":required-current,"ratio":float(current)/required,"label":"EXP %d/%d · %d to Lv.%d" % [current,required,required-current,level+1]}

static func grant_experience(pokemon: Dictionary, amount: int) -> int:
	initialize(pokemon)
	var old_level := int(pokemon.level)
	var growth := int(species(pokemon).get("growth_rate",2))
	pokemon.experience = mini(experience_at(100,growth),int(pokemon.experience)+maxi(0,amount))
	while int(pokemon.level) < 100 and int(pokemon.experience) >= experience_at(int(pokemon.level)+1,growth): pokemon.level = int(pokemon.level)+1
	var delta := int(pokemon.level)-old_level
	var before_hp := int(pokemon.max_hp)
	pokemon.max_hp = before_hp+2*delta
	if int(pokemon.hp) > 0: pokemon.hp = int(pokemon.hp)+int(pokemon.max_hp)-before_hp
	for name in ["attack","defense","special_attack","special_defense","speed"]: pokemon[name] = int(pokemon.get(name,10))+delta
	apply_iv_bonuses(pokemon)
	PendingItems.apply_ev_bonuses(pokemon)
	if delta > 0:
		ItemProgression.level_moves(pokemon,old_level,int(pokemon.level))
		pokemon.pending_evolution = ItemProgression.evolution(pokemon)
		for step in delta: PendingItems.friendship(pokemon,5 if int(pokemon.friendship) < 100 else (3 if int(pokemon.friendship) < 200 else 2))
	return int(pokemon.level)-old_level

static func experience_shares(party: Array, participants: Array, total: int, mode: String) -> Array:
	participants = participants.map(func(value): return int(value))
	var shares: Array = []
	shares.resize(party.size())
	shares.fill(0)
	var active: Array = []
	var holders: Array = []
	for i in party.size():
		if int(party[i].hp) <= 0: continue
		if i in participants: active.append(i)
		if party[i].get("held_item","") == "item_exp_share": holders.append(i)
	if active.is_empty(): return shares
	for i in party.size():
		if int(party[i].hp) <= 0: continue
		if mode == "modern": shares[i] = total if i in active else int(total/2.0)
		elif mode == "all": shares[i] = (int(total/2.0/active.size()) if i in active else 0)+int(total/2.0/active.size()/party.size())
		elif not holders.is_empty(): shares[i] = (int(total/2.0/active.size()) if i in active else 0)+(int(total/2.0/holders.size()) if i in holders else 0)
		elif i in active: shares[i] = int(float(total)/active.size())
	return shares

static func can_teach(item: Dictionary, pokemon: Dictionary) -> bool:
	if item.get("kind","") != "machine": return false
	var moves: Array = pokemon.get("moves",GameData.SPECIES[pokemon.species].moves)
	for learned in moves:
		if GameData.MOVES[learned].name == GameData.MOVES[str(item.move_id)].name: return false
	return int(item.move_index) in species(pokemon).get("compatible_moves",[]) and str(item.move_id) not in moves and GameData.MOVES.has(str(item.move_id))

static func teach(item: Dictionary, pokemon: Dictionary, replace: int = -1) -> bool:
	initialize(pokemon)
	if not can_teach(item,pokemon): return false
	if pokemon.moves.size() >= 4:
		if replace < 0 or replace >= pokemon.moves.size(): return false
		pokemon.moves[replace] = str(item.move_id)
	else:
		if replace != -1: return false
		pokemon.moves.append(str(item.move_id))
	pokemon.pp[str(item.move_id)] = int(GameData.MOVES[str(item.move_id)].get("pp",35))
	return true
