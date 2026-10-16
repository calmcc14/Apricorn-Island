class_name MoveEffects
extends RefCounted

const AILMENTS := {1:"paralysis",2:"sleep",3:"freeze",4:"burn",5:"poison",6:"confusion"}

static func accuracy(actor: Dictionary, target: Dictionary, move: Dictionary) -> float:
	var stage := clampi(int(actor.get("accuracy_stage",0))-int(target.get("evasion_stage",0)),-6,6)
	var multiplier := 1.0
	if PendingItems.held(actor) == "item_wide_lens": multiplier *= 1.1
	if PendingItems.held(actor) == "item_zoom_lens" and target.get("acted_this_turn",false): multiplier *= 1.2
	if PendingItems.held(target) in ["item_bright_powder","item_lax_incense"]: multiplier *= 0.9
	return minf(1.0,float(move.accuracy)*ItemMechanics.stage_multiplier(stage,true)*multiplier)

static func can_act(actor: Dictionary, move_id: String, random: RandomNumberGenerator, messages: Array[String]) -> bool:
	var name := str(GameData.SPECIES[actor.species].name)
	if int(actor.hp) <= 0: return false
	if not PendingItems.move_allowed(actor,move_id):
		messages.append(name+" cannot select that move with its held item.")
		return false
	PendingItems.select_move(actor,move_id)
	actor.erase("custap_ready")
	if actor.has("pp") and int(actor.pp.get(move_id,35)) <= 0 and actor.get("charging_move","") != move_id:
		messages.append(name+" has no PP left for that move.")
		return false
	if actor.get("flinched",false):
		messages.append(name+" flinched!")
		return false
	if actor.get("recharging",false):
		actor.erase("recharging")
		messages.append(name+" must recharge.")
		return false
	var status := str(actor.get("status_condition",""))
	if status == "sleep":
		actor.sleep_turns = maxi(0,int(actor.get("sleep_turns",2))-1)
		if int(actor.sleep_turns) == 0: actor.status_condition = ""
		elif move_id not in ["sleep_talk","snore"]:
			messages.append(name+" is asleep.")
			return false
	if status == "freeze":
		if random.randf() < 0.2: actor.status_condition = ""
		else:
			messages.append(name+" is frozen.")
			return false
	if status == "paralysis" and random.randf() < 0.25:
		messages.append(name+" is fully paralyzed.")
		return false
	if int(actor.get("confusion_turns",0)) > 0:
		actor.confusion_turns = int(actor.confusion_turns)-1
		if random.randf() < 1.0/3.0:
			var damage := GameRules.calculate_damage(10,ItemMechanics.stat(actor,"attack"),ItemMechanics.stat(actor,"defense"),1)
			if PendingItems.held(actor) == "item_silk_scarf": damage = int(damage*1.2)
			damage = PendingItems.reduce_hit(actor,actor,{"type":"normal"},damage,1.0,true)
			damage = PendingItems.survival(actor,damage,random,false,true)
			actor.hp = maxi(0,int(actor.hp)-damage)
			actor.erase("band_active")
			messages.append(name+" hurt itself in confusion!")
			return false
	if actor.get("disabled_move","") == move_id or (actor.get("encore_move","") != "" and actor.encore_move != move_id):
		messages.append(name+" cannot use that move right now.")
		return false
	if actor.get("tormented",false) and actor.get("last_move","") == move_id:
		messages.append(name+" cannot repeat its last move.")
		return false
	if int(actor.get("attracted",0)) > 0 and random.randf() < 0.5:
		messages.append(name+" is immobilized by love.")
		return false
	return true

static func effectiveness(move_type: String, target: Dictionary) -> float:
	var value := 1.0
	for type in ItemMechanics.species(target).get("types",[GameData.SPECIES[target.species].type]): value *= float(ItemMechanics.data().type_chart.get(move_type,{}).get(str(type),1.0))
	return value

static func stab(actor: Dictionary, move_type: String) -> float:
	return 1.5 if move_type in ItemMechanics.species(actor).get("types",[GameData.SPECIES[actor.species].type]) else 1.0

static func status_label(pokemon: Dictionary) -> String:
	var label := str(pokemon.get("status_condition","")).capitalize()
	if int(pokemon.get("confusion_turns",0)) > 0: label += (" / " if label != "" else "")+"Confused"
	return label

static func inflict(target: Dictionary, ailment: String, random: RandomNumberGenerator) -> bool:
	if int(target.hp) <= 0: return false
	if PendingItems.held(target) in ["item_pure_incense","item_cleanse_tag"]: return false
	if ailment == "confusion":
		if int(target.get("confusion_turns",0)) > 0: return false
		target.confusion_turns = random.randi_range(2,5)
		return true
	if target.get("status_condition","") != "": return false
	var types: Array = ItemMechanics.species(target).get("types",[])
	if ailment in ["poison","toxic"] and ("poison" in types or "steel" in types): return false
	if ailment == "burn" and "fire" in types: return false
	if ailment == "freeze" and "ice" in types: return false
	if ailment == "paralysis" and "electric" in types: return false
	target.status_condition = ailment
	if ailment == "sleep": target.sleep_turns = random.randi_range(2,4)
	return true

static func resolve(actor: Dictionary, target: Dictionary, move_id: String, battle: Dictionary, state: Dictionary, random: RandomNumberGenerator, messages: Array[String], damage_scale: float = 1.0, perfect: bool = false, one_hit: bool = false, invincible: bool = false, recursion: int = 0) -> void:
	var move: Dictionary = GameData.MOVES[move_id]
	var name := str(GameData.SPECIES[actor.species].name)
	if move.kind in ["heal","buff","debuff"]:
		if move.kind == "heal": PendingItems.heal(actor,int(move.power))
		elif move.kind == "buff": ItemMechanics.raise_stat(actor,"attack",1)
		else: ItemMechanics.raise_stat(target,"attack",-1,true)
		messages.append(name+" used "+str(move.name)+".")
		return
	if recursion > 1:
		messages.append(name+"'s called move failed.")
		return
	var metronome_previous := int(actor.get("metronome_count",0)) if actor.get("metronome_move","") == move_id else 0
	actor.metronome_count = 0
	actor.last_move = move_id
	var self_target := is_same(actor,target)
	var types: Array = ItemMechanics.species(target).get("types",[])
	var ohko := move_id in ["fissure","horn_drill","guillotine","sheer_cold"]
	var charging := move_id in ["dig","fly","dive","bounce","solar_beam","solar_blade","razor_wind","sky_attack","meteor_beam","electro_shot","skull_bash","freeze_shock","ice_burn","geomancy"]
	var weather_now := str(battle.get("weather",""))
	if move_id in ["solar_beam","solar_blade"] and weather_now == "sun": charging = false
	if move_id == "electro_shot" and weather_now == "rain": charging = false
	if charging:
		if actor.get("charging_move","") != move_id:
			if move_id in ["meteor_beam","electro_shot"]: ItemMechanics.raise_stat(actor,"special_attack",1)
			if move_id == "skull_bash": ItemMechanics.raise_stat(actor,"defense",1)
			if PendingItems.held(actor) == "item_power_herb": PendingItems.consume(actor)
			else:
				actor.charging_move = move_id
				actor.semi_invulnerable = 1 if move_id in ["dig","fly","dive","bounce"] else 0
				messages.append(name+" is preparing "+str(move.name)+".")
				return
		actor.erase("charging_move")
		actor.erase("semi_invulnerable")
	# Accuracy bypass is checked only after independent failure and immunity rules.
	if not self_target and (target.get("protected",false) or int(target.get("semi_invulnerable",0)) > 0):
		messages.append(name+" used %s, but the target was protected." % move.name)
		return
	if ohko and (int(actor.get("level",5)) < int(target.get("level",5)) or target.get("ability","") == "sturdy" or (move_id == "sheer_cold" and "ice" in types) or effectiveness(str(move.type),target) == 0):
		messages.append(name+"'s one-hit knockout move failed.")
		return
	if move_id == "snore" and actor.get("status_condition","") != "sleep":
		messages.append("Snore failed: the user is awake.")
		return
	if move.kind == "status" and int(actor.get("taunted",0)) > 0:
		messages.append(name+" cannot use a status move while taunted.")
		return
	for opponent in (battle.enemies if actor in state.party else state.party):
		if int(opponent.hp) > 0 and opponent.get("imprison",false) and move_id in opponent.get("moves",[]):
			messages.append("The move was sealed by Imprison.")
			return
	if PendingItems.flag(move,"powder") and PendingItems.held(target) == "item_safety_goggles":
		messages.append("Safety Goggles blocked the powder move.")
		return
	if move.kind == "damage" and move.type == "ground" and PendingItems.held(target) == "item_air_balloon" and int(battle.get("gravity",0)) <= 0:
		messages.append("Air Balloon kept the target above the Ground move.")
		return
	var hit_chance := accuracy(actor,target,move)
	if ohko: hit_chance = clampf((30.0+int(actor.get("level",5))-int(target.get("level",5)))/100.0,0,1)
	if actor.get("micle_ready",false):
		hit_chance *= 1.2
		actor.erase("micle_ready")
	if not self_target and PendingItems.held(target) == "item_dark_powder" and random.randi_range(0,255) < 20:
		messages.append("Dark Powder made the move miss!")
		actor.metronome_count = 0
		return
	if not self_target and not move.get("always_hit",false) and not actor.get("accuracy_bypass",false) and not perfect and random.randf() > hit_chance:
		actor.metronome_count = 0
		messages.append(name+" used %s, but missed!" % move.name)
		return
	if move.kind == "status":
		if not self_target and int(target.get("substitute_hp",0)) > 0:
			messages.append("The substitute blocked "+str(move.name)+".")
			return
		if self_target:
			for opponent in (battle.enemies if actor in state.party else state.party):
				if int(opponent.hp) > 0 and opponent.get("snatch",false):
					opponent.erase("snatch")
					status_move(opponent,opponent,move_id,battle,state,random,messages,recursion)
					return
		status_move(actor,target,move_id,battle,state,random,messages,recursion)
		PendingItems.activate(actor,battle,random)
		PendingItems.activate(target,battle,random)
		return
	var effect := effectiveness(str(move.type),target)
	if effect == 0:
		messages.append("%s has no effect on %s." % [move.name,GameData.SPECIES[target.species].name])
		return
	var special := int(move.get("damage_class",2)) == 3
	var attack_stat := "special_attack" if special else "attack"
	var defense_stat := "special_defense" if special else "defense"
	var power := float(move.power)
	if move_id in ["return","frustration"]: power = maxf(0.25,float(int(actor.get("friendship",70)) if move_id == "return" else 255-int(actor.get("friendship",70)))/10.0)
	if move_id in ["flail","reversal"]:
		var ratio := float(actor.hp)/float(actor.max_hp)
		power = 50.0 if ratio < 0.04 else (37.5 if ratio < 0.1 else (25.0 if ratio < 0.2 else (20.0 if ratio < 0.35 else (10.0 if ratio < 0.7 else 5.0))))
	if move_id in ["water_spout","eruption","dragon_energy"]: power = 37.5*float(actor.hp)/float(actor.max_hp)
	if move_id in ["electro_ball","gyro_ball"]:
		var ratio := float(ItemMechanics.stat(actor,"speed"))/ItemMechanics.stat(target,"speed")
		power = minf(37.5,6.25/ratio+0.25) if move_id == "gyro_ball" else (37.5 if ratio >= 4 else (30.0 if ratio >= 3 else (20.0 if ratio >= 2 else (15.0 if ratio >= 1 else 10.0))))
	if move_id == "facade" and actor.get("status_condition","") != "": power *= 2
	if move_id in ["hex","infernal_parade"] and target.get("status_condition","") != "": power *= 2
	if move_id in ["venoshock","barb_barrage"] and target.get("status_condition","") in ["poison","toxic"]: power *= 2
	if move_id in ["brine"] and int(target.hp)*2 <= int(target.max_hp): power *= 2
	if move_id == "stored_power" or move_id == "power_trip":
		power = 5.0
		for stat in ["attack","defense","special_attack","special_defense","speed","accuracy","evasion"]: power += 5.0*maxi(0,int(actor.get(stat+"_stage",0)))
	if move_id in ["low_kick","grass_knot"]:
		var weight := float(ItemMechanics.species(target).get("weight",10))
		power = 5.0 if weight < 10 else (10.0 if weight < 25 else (15.0 if weight < 50 else (20.0 if weight < 100 else (25.0 if weight < 200 else 30.0))))
	if move_id in ["heavy_slam","heat_crash"]:
		var ratio := float(ItemMechanics.species(actor).get("weight",10))/maxf(0.1,float(ItemMechanics.species(target).get("weight",10)))
		power = 30.0 if ratio >= 5 else (25.0 if ratio >= 4 else (20.0 if ratio >= 3 else (15.0 if ratio >= 2 else 10.0)))
	if move_id == "foul_play": attack_stat = "attack"
	var attack := ItemMechanics.stat(target if move_id == "foul_play" else actor,attack_stat)
	if move_id == "body_press": attack = ItemMechanics.stat(actor,"defense")
	if move_id in ["psyshock","psystrike","secret_sword"]: defense_stat = "defense"
	var weather := str(battle.get("weather",""))
	if actor.get("charged",false) and move.type == "electric": power *= 2; actor.erase("charged")
	if actor.get("helping_hand",false): power *= 1.5; actor.erase("helping_hand")
	if int(target.get("reflect" if not special else "light_screen",0)) > 0 or int(target.get("aurora_veil",0)) > 0: power *= 2.0/3.0
	if battle.get("terrain","") == str(move.type)+"_terrain" and "flying" not in ItemMechanics.species(actor).get("types",[]): power *= 1.3
	var critical_stage := int(actor.get("critical_stage",0))+int(move.get("crit_rate",0))+PendingItems.critical_stages(actor)
	var critical_chance: float = [1.0/24.0,1.0/8.0,0.5,1.0][clampi(critical_stage,0,3)]
	var critical := random.randf() < critical_chance
	if critical:
		power *= 1.5
		if int(actor.get(attack_stat+"_stage",0)) < 0:
			var neutral_actor := actor.duplicate()
			neutral_actor[attack_stat+"_stage"] = 0
			attack = ItemMechanics.stat(neutral_actor,attack_stat)
	if str(move.type) in ["fire","water"]:
		if weather == "rain": power *= 1.5 if move.type == "water" else 0.5
		if weather == "sun": power *= 1.5 if move.type == "fire" else 0.5
	if actor.get("status_condition","") == "burn" and not special and move_id != "facade": power *= 0.5
	var secondary_boost := PendingItems.boosted_secondary(actor,move)
	var eligible_damage := power > 0 and not ohko
	var gem: Dictionary = GameData.ITEMS.get(PendingItems.held(actor),{})
	if eligible_damage:
		if secondary_boost: power *= 1.3
		if PendingItems.held(actor) == "item_life_orb": power *= 1.3
		if gem.get("gem_type","") == str(move.type): power *= 1.5
		if PendingItems.held(actor) == "item_soul_dew" and actor.species in ["latios","latias"] and move.type in ["dragon","psychic"]: power *= 1.2
		if PendingItems.held(actor) == "item_metronome":
			if actor.get("metronome_move","") != move_id: actor.metronome_count = 0
			power *= 1.0+0.1*mini(10,metronome_previous)
	var defense := ItemMechanics.stat(target,defense_stat)
	if critical and int(target.get(defense_stat+"_stage",0)) > 0:
		var neutral_target := target.duplicate()
		neutral_target[defense_stat+"_stage"] = 0
		defense = ItemMechanics.stat(neutral_target,defense_stat)
	var damage := GameRules.calculate_damage(power*stab(actor,str(move.type))*ItemCatalog.move_power_multiplier(actor,str(move.type))*PendingItems.power(actor,special,effect),attack,defense,effect,random.randf_range(0.9,1.1))
	if power <= 0 and not ohko:
		match move_id:
			"seismic_toss","night_shade": damage = int(actor.get("level",5))
			"dragon_rage": damage = 40
			"sonic_boom": damage = 20
			"super_fang","nature_s_madness","ruination": damage = maxi(1,int(target.hp)/2)
			"endeavor": damage = maxi(0,int(target.hp)-int(actor.hp))
			"final_gambit": damage = int(actor.hp)
			_: damage = 0
	if ohko: damage = int(target.hp)
	if move_id == "dream_eater" and target.get("status_condition","") != "sleep": damage = 0
	if move_id in ["counter","mirror_coat","metal_burst"]:
		damage = int(actor.get("last_damage",0))*(2 if move_id != "metal_burst" else 1.5)
	if move_id == "present":
		var roll := random.randf()
		if roll < 0.2:
			target.hp = mini(int(target.max_hp),int(target.hp)+maxi(1,int(target.max_hp)/4))
			damage = 0
	var hits := 1
	if int(move.get("max_hits",0)) > 1: hits = random.randi_range(int(move.min_hits),int(move.max_hits))
	damage = maxi(0,int(round(damage*damage_scale)))
	if invincible: damage = 0
	if one_hit: damage = int(target.hp)
	if target.get("endure",false) or move_id in ["false_swipe","hold_back"]: damage = mini(damage,maxi(0,int(target.hp)-1))
	var dealt := 0
	var hp_dealt := 0
	target.erase("band_active")
	var contact := PendingItems.flag(move,"contact")
	for hit in hits:
		if int(target.hp) <= 0 or int(actor.hp) <= 0: break
		var hit_damage := damage
		if int(target.get("substitute_hp",0)) > 0:
			dealt += mini(int(target.substitute_hp),hit_damage)
			target.substitute_hp = maxi(0,int(target.substitute_hp)-hit_damage)
		else:
			hit_damage = PendingItems.reduce_hit(actor,target,move,hit_damage,effect)
			if target.get("endure",false) or move_id in ["false_swipe","hold_back"]: hit_damage = mini(hit_damage,maxi(0,int(target.hp)-1))
			hit_damage = PendingItems.survival(target,hit_damage,random,target.get("band_active",false))
			var actual := mini(int(target.hp),hit_damage)
			target.hp = maxi(0,int(target.hp)-hit_damage)
			dealt += actual
			hp_dealt += actual
			if actual > 0: PendingItems.after_hit(actor,target,move,effect,random,secondary_boost,contact)
			target.last_damage = hit_damage
		PendingItems.activate(target,battle,random)
		ItemMechanics.activate_berry(target,GameData.ITEMS,messages)
	target.erase("band_active")
	if dealt > 0 and eligible_damage and gem.get("gem_type","") == str(move.type): PendingItems.consume(actor)
	if dealt > 0 and PendingItems.held(actor) == "item_life_orb" and not secondary_boost: PendingItems.indirect_damage(actor,int(actor.max_hp)/10)
	if PendingItems.held(actor) == "item_metronome":
		actor.metronome_move = move_id
		actor.metronome_count = mini(10,metronome_previous+1) if dealt > 0 else 0
	if PendingItems.flag(move,"sound") and PendingItems.held(actor) == "item_throat_spray":
		if ItemMechanics.raise_stat(actor,"special_attack",1): PendingItems.consume(actor)
	var drain := int(move.get("drain",0))
	if drain > 0:
		var recovery := maxi(1,int(hp_dealt*drain/100.0))
		if PendingItems.held(actor) == "item_big_root": recovery = int(recovery*1.3)
		PendingItems.heal(actor,recovery)
	elif drain < 0 and dealt > 0: actor.hp = maxi(0,int(actor.hp)-maxi(1,int(dealt*abs(drain)/100.0)))
	if dealt > 0 and PendingItems.held(actor) == "item_shell_bell" and not secondary_boost:
		PendingItems.heal(actor,maxi(1,dealt/8))
	if move_id in ["explosion","self_destruct","final_gambit"]: actor.hp = 0
	if move_id in ["hyper_beam","giga_impact","blast_burn","frenzy_plant","hydro_cannon","rock_wrecker","roar_of_time","meteor_assault"] and dealt > 0: actor.recharging = true
	var ailment: String = str(AILMENTS.get(int(move.get("meta_ailment_id",0)),""))
	var blocked_secondary := secondary_boost or PendingItems.held(target) == "item_covert_cloak" or int(target.get("substitute_hp",0)) > 0
	var inflicted := not blocked_secondary and ailment != "" and hp_dealt > 0 and random.randf()*100 < float(move.get("ailment_chance",0)) and inflict(target,ailment,random)
	if not blocked_secondary and hp_dealt > 0 and not target.get("acted_this_turn",false) and PendingItems.held(target) not in ["item_pure_incense","item_cleanse_tag"] and target.get("ability","") != "inner_focus" and random.randf()*100 < float(move.get("flinch_chance",0)): target.flinched = true
	if not blocked_secondary and hp_dealt > 0 and random.randf()*100 < float(move.get("stat_chance",100)):
		for change in move.get("stat_changes",[]): ItemMechanics.raise_stat(actor if int(move.get("meta_category_id",0)) == 7 else target,str(change.stat),int(change.change),not is_same(actor,target))
	messages.append("%s used %s for %d damage%s." % [name,move.name,dealt," (%d hits)" % hits if hits > 1 else ""])
	if hp_dealt > 0 and PendingItems.held(target) not in ["item_cleanse_tag","item_pure_incense"] and move_id in ["bind","wrap","fire_spin","whirlpool","clamp","sand_tomb","magma_storm","infestation","snap_trap","thunder_cage"]:
		target.trapped_turns = 7 if PendingItems.held(actor) == "item_grip_claw" else random.randi_range(4,5)
		target.binding_damage = maxi(1,int(target.max_hp)/(6 if PendingItems.held(actor) == "item_binding_band" else 8))
	if effect > 1: messages.append("It's super effective!")
	elif effect < 1: messages.append("It's not very effective.")
	if inflicted: messages.append("%s is now %s!" % [GameData.SPECIES[target.species].name,ailment])
	if int(target.hp) <= 0: messages.append(str(GameData.SPECIES[target.species].name)+" fainted!")

static func status_move(actor: Dictionary, target: Dictionary, id: String, battle: Dictionary, state: Dictionary, random: RandomNumberGenerator, messages: Array[String], recursion: int) -> void:
	var move: Dictionary = GameData.MOVES[id]
	var pure := PendingItems.held(target) == "item_pure_incense"
	if PendingItems.held(target) == "item_cleanse_tag" and id in ["taunt","encore","torment","attract","embargo","heal_block","telekinesis","nightmare","curse","disable","leech_seed","yawn"]:
		messages.append("Cleanse Tag prevented the harmful status effect.")
		return
	if pure and int(move.get("healing",0)) == 0 and id not in ["rest","pain_split","rain_dance","sunny_day","sandstorm","hail","snowscape","electric_terrain","grassy_terrain","misty_terrain","psychic_terrain","trick_room","wonder_room","magic_room","gravity","spikes","toxic_spikes","stealth_rock","trick","teleport","roar","whirlwind","metronome","nature_power","sleep_talk","defog","recycle","spite"]:
		messages.append("Pure Incense prevented the temporary effect.")
		return
	var success := false
	var allies: Array = state.party if actor in state.party else battle.enemies
	var foes: Array = battle.enemies if actor in state.party else state.party
	match id:
		"rest":
			if int(actor.hp) < int(actor.max_hp) or actor.get("status_condition","") != "":
				actor.hp = int(actor.max_hp)
				if PendingItems.held(actor) != "item_pure_incense":
					actor.status_condition = "sleep"
					actor.sleep_turns = 3
				success = true
		"protect","detect":
			success = random.randf() < pow(1.0/3.0,int(actor.get("protect_streak",0)))
			actor.protected = success
			actor.protect_streak = int(actor.get("protect_streak",0))+1 if success else 0
		"endure": actor.endure = true; success = true
		"substitute":
			var cost := maxi(1,int(actor.max_hp)/4)
			if int(actor.hp) > cost and int(actor.get("substitute_hp",0)) == 0:
				actor.hp = int(actor.hp)-cost
				actor.substitute_hp = cost
				success = true
		"haze":
			for pokemon in allies+foes:
				if PendingItems.held(pokemon) != "item_pure_incense":
					for stat in ["attack","defense","special_attack","special_defense","speed","accuracy","evasion"]: pokemon[stat+"_stage"] = 0
			success = true
		"psych_up":
			for stat in ["attack","defense","special_attack","special_defense","speed","accuracy","evasion"]: actor[stat+"_stage"] = int(target.get(stat+"_stage",0))
			success = true
		"toxic": success = inflict(target,"toxic",random)
		"will_o_wisp": success = inflict(target,"burn",random)
		"confuse_ray": success = inflict(target,"confusion",random)
		"sing": success = inflict(target,"sleep",random)
		"thunder_wave": success = effectiveness("electric",target) > 0 and inflict(target,"paralysis",random)
		"swagger":
			ItemMechanics.raise_stat(target,"attack",2)
			success = inflict(target,"confusion",random)
		"pain_split":
			var hp := int((int(actor.hp)+int(target.hp))/2.0)
			actor.hp = mini(int(actor.max_hp),hp)
			target.hp = mini(int(target.max_hp),hp)
			success = true
		"rain_dance","sunny_day","sandstorm","hail","snowscape":
			battle.weather = {"rain_dance":"rain","sunny_day":"sun","sandstorm":"sand","hail":"hail","snowscape":"snow"}[id]
			battle.weather_turns = 5
			success = true
		"electric_terrain","grassy_terrain","misty_terrain","psychic_terrain": battle.terrain = id; battle.terrain_turns = 5; success = true
		"trick_room","wonder_room","magic_room","gravity": battle[id] = 5 if int(battle.get(id,0)) == 0 else 0; success = true
		"light_screen","reflect","safeguard","tailwind","aurora_veil":
			if id != "aurora_veil" or battle.get("weather","") in ["hail","snow"]:
				for pokemon in allies: pokemon[id] = 5 if id != "tailwind" else 4
				success = true
		"spikes","toxic_spikes","stealth_rock":
			var key := "player_hazards" if actor in battle.enemies else "enemy_hazards"
			if not battle.has(key): battle[key] = {}
			var maximum := 3 if id == "spikes" else (2 if id == "toxic_spikes" else 1)
			battle[key][id] = mini(maximum,int(battle[key].get(id,0))+1)
			success = true
		"taunt","encore","torment","attract","embargo","heal_block","telekinesis","nightmare":
			if id == "encore": target.encore_move = str(target.get("last_move","")); target.encore_turns = 3; success = target.encore_move != ""
			elif id == "torment": target.tormented = true; success = true
			elif id == "attract":
				success = actor.get("gender","") in ["male","female"] and target.get("gender","") in ["male","female"] and actor.gender != target.gender
				if success:
					target.attracted = 1
					if PendingItems.held(target) == "item_destiny_knot" and PendingItems.held(actor) not in ["item_cleanse_tag","item_pure_incense"]: actor.attracted = 1
			elif id == "nightmare": target.nightmare = target.get("status_condition","") == "sleep"; success = target.nightmare
			else: target[{"taunt":"taunted"}.get(id,id)] = 3; success = true
		"trick":
			var locked := {"item_red_orb":"groudon","item_blue_orb":"kyogre","item_griseous_orb":"giratina"}
			if locked.get(str(actor.get("held_item","")),"") == actor.species or locked.get(str(target.get("held_item","")),"") == target.species:
				messages.append("The form item cannot be exchanged during battle.")
				return
			var held := str(actor.get("held_item",""))
			actor.held_item = str(target.get("held_item",""))
			target.held_item = held
			success = true
		"skill_swap":
			if PendingItems.held(actor) == "item_ability_shield" or PendingItems.held(target) == "item_ability_shield":
				messages.append("Ability Shield prevented Skill Swap.")
				return
			var ability := str(actor.get("ability",""))
			if not actor.has("original_ability"): actor.original_ability = ability
			if not target.has("original_ability"): target.original_ability = str(target.get("ability",""))
			actor.ability = str(target.get("ability",""))
			target.ability = ability
			success = true
		"gastro_acid","worry_seed","simple_beam","entrainment","role_play":
			var recipient: Dictionary = actor if id == "role_play" else target
			var ability := str(recipient.get("ability",""))
			if PendingItems.held(recipient) != "item_ability_shield" and ability not in ["multitype","stance_change","schooling","comatose","shields_down","disguise","rks_system","battle_bond","power_construct","ice_face","gulp_missile","as_one","zero_to_hero"]:
				if not recipient.has("original_ability"): recipient.original_ability = ability
				recipient.ability = str(target.get("ability","")) if id == "role_play" else (str(actor.get("ability","")) if id == "entrainment" else {"gastro_acid":"","worry_seed":"insomnia","simple_beam":"simple"}[id])
				success = true
		"transform":
			if not actor.has("transform_original") and not target.has("transform_original") and int(target.get("substitute_hp",0)) <= 0:
				var original := {}
				for key in ["species","moves","pp","attack","defense","special_attack","special_defense","speed","ability","form"]: original[key] = actor.get(key,"")
				actor.transform_original = original.duplicate(true)
				actor.original_species = str(actor.species)
				for key in ["species","attack","defense","special_attack","special_defense","speed","form"]: actor[key] = target.get(key,target.species)
				if PendingItems.held(actor) != "item_ability_shield": actor.ability = str(target.get("ability",""))
				actor.moves = target.moves.duplicate()
				actor.pp = {}
				for move_id in actor.moves: actor.pp[move_id] = 5
				for stat in PendingItems.STATS: actor[stat+"_stage"] = int(target.get(stat+"_stage",0))
				success = true
		"power_swap","guard_swap","speed_swap":
			var stats := ["speed"] if id == "speed_swap" else (["attack_stage","special_attack_stage"] if id == "power_swap" else ["defense_stage","special_defense_stage"])
			for stat in stats:
				var value := int(actor.get(stat,0))
				actor[stat] = int(target.get(stat,0))
				target[stat] = value
			success = true
		"focus_energy","dragon_cheer": actor.critical_stage = 2; success = true
		"charge": ItemMechanics.raise_stat(actor,"special_defense",1); actor.charged = true; success = true
		"captivate":
			if actor.get("gender","") in ["male","female"] and target.get("gender","") in ["male","female"] and actor.gender != target.gender: success = ItemMechanics.raise_stat(target,"special_attack",-2)
		"venom_drench":
			if target.get("status_condition","") in ["poison","toxic"]:
				for stat in ["attack","special_attack","speed"]: success = ItemMechanics.raise_stat(target,stat,-1) or success
		"helping_hand":
			for pokemon in allies:
				if not is_same(actor,pokemon): pokemon.helping_hand = true; success = true
		"coaching":
			for pokemon in allies:
				if not is_same(actor,pokemon): ItemMechanics.raise_stat(pokemon,"attack",1); ItemMechanics.raise_stat(pokemon,"defense",1); success = true
		"curse":
			if "ghost" in ItemMechanics.species(actor).get("types",[]): actor.hp = maxi(0,int(actor.hp)-int(actor.max_hp)/2); target.cursed = true
			else: ItemMechanics.raise_stat(actor,"attack",1); ItemMechanics.raise_stat(actor,"defense",1); ItemMechanics.raise_stat(actor,"speed",-1)
			success = true
		"mimic":
			var called := str(target.get("last_move",""))
			if GameData.MOVES.has(called) and called != id:
				actor.original_moves = actor.moves.duplicate()
				actor.moves[actor.moves.find(id)] = called
				success = true
		"metronome","sleep_talk","nature_power":
			var called := "thunderbolt" if id == "nature_power" else ""
			var choices: Array = actor.moves.duplicate() if id == "sleep_talk" else GameData.MOVES.keys()
			if id == "sleep_talk" and actor.get("status_condition","") != "sleep": choices = []
			choices.erase(id)
			if called == "" and not choices.is_empty(): called = str(choices[random.randi_range(0,choices.size()-1)])
			if called != "" and GameData.MOVES.has(called): resolve(actor,target,called,battle,state,random,messages,1,false,false,false,recursion+1); success = true
		"teleport":
			if actor in state.party: battle.escaped = true
			else: actor.hp = 0; actor.fled = true
			success = true
		"ally_switch":
			var index := allies.find(actor)
			if allies.size() > 1:
				var other := (index+1)%allies.size()
				var temp: Dictionary = allies[index]
				allies[index] = allies[other]
				allies[other] = temp
				success = true
		"baton_pass":
			if actor in state.party and not state.get("reserve",[]).is_empty():
				var next: Dictionary = state.reserve.pop_front()
				var previous := actor.duplicate(true)
				ItemMechanics.reset_battle(next)
				if id == "baton_pass":
					for stat in ["attack","defense","special_attack","special_defense","speed","accuracy","evasion"]: next[stat+"_stage"] = int(actor.get(stat+"_stage",0))
				actor.clear()
				actor.merge(next)
				state.reserve.append(previous)
				actor.erase("choice_move")
				PendingItems.entry_hazards(actor,battle,true,random)
				success = true
		"roar","whirlwind": target.hp = 0; target.fled = true; success = true
		"defog":
			ItemMechanics.raise_stat(target,"evasion",-1)
			battle.erase("player_hazards")
			battle.erase("enemy_hazards")
			battle.erase("terrain")
			for pokemon in allies+foes:
				for key in ["reflect","light_screen","aurora_veil","safeguard"]: pokemon.erase(key)
			success = true
		"recycle":
			if actor.get("consumed_item","") != "" and actor.get("held_item","") == "": actor.held_item = actor.consumed_item; actor.erase("consumed_item"); success = true
		"spite":
			var last := str(target.get("last_move",""))
			if last != "" and target.has("pp"): target.pp[last] = maxi(0,int(target.pp.get(last,0))-4); success = true
		"imprison": actor.imprison = true; success = true
		"snatch": actor.snatch = true; success = true
		"quash": target.quashed = true; success = true
		_:
			var healing := int(move.get("healing",0))
			if healing > 0 and int(actor.get("heal_block",0)) == 0:
				var before := int(actor.hp)
				actor.hp = mini(int(actor.max_hp),before+maxi(1,int(float(actor.max_hp)*healing/100.0)))
				success = int(actor.hp) > before
			for change in move.get("stat_changes",[]): success = ItemMechanics.raise_stat(target,str(change.stat),int(change.change),not is_same(actor,target)) or success
			var ailment := str(AILMENTS.get(int(move.get("meta_ailment_id",0)),""))
			if ailment != "": success = inflict(target,ailment,random) or success
	if success and PendingItems.flag(move,"sound") and PendingItems.held(actor) == "item_throat_spray":
		if ItemMechanics.raise_stat(actor,"special_attack",1): PendingItems.consume(actor)
	messages.append("%s used %s%s." % [GameData.SPECIES[actor.species].name,move.name,"" if success else ", but it failed"])

static func end_turn(pokemon: Dictionary, battle: Dictionary, random: RandomNumberGenerator, messages: Array[String]) -> void:
	if int(pokemon.hp) <= 0: return
	var damage := 0
	if int(pokemon.get("trapped_turns",0)) > 0:
		damage += int(pokemon.get("binding_damage",maxi(1,int(pokemon.max_hp)/8)))
		pokemon.trapped_turns = int(pokemon.trapped_turns)-1
	match str(pokemon.get("status_condition","")):
		"poison": damage += maxi(1,int(pokemon.max_hp)/8)
		"burn": damage += maxi(1,int(pokemon.max_hp)/16)
		"toxic":
			pokemon.toxic_turns = int(pokemon.get("toxic_turns",0))+1
			damage += maxi(1,int(pokemon.max_hp)*int(pokemon.toxic_turns)/16)
	if pokemon.get("nightmare",false) and pokemon.get("status_condition","") == "sleep": damage += maxi(1,int(pokemon.max_hp)/4)
	if pokemon.get("cursed",false): damage += maxi(1,int(pokemon.max_hp)/4)
	var types: Array = ItemMechanics.species(pokemon).get("types",[])
	if PendingItems.held(pokemon) != "item_safety_goggles" and battle.get("weather","") == "sand" and not ("rock" in types or "ground" in types or "steel" in types): damage += maxi(1,int(pokemon.max_hp)/16)
	if PendingItems.held(pokemon) != "item_safety_goggles" and battle.get("weather","") == "hail" and "ice" not in types: damage += maxi(1,int(pokemon.max_hp)/16)
	if pokemon.get("ability","") == "magic_guard": damage = 0
	if damage > 0:
		pokemon.hp = maxi(0,int(pokemon.hp)-damage)
		messages.append("%s lost %d HP to ongoing effects." % [GameData.SPECIES[pokemon.species].name,damage])
	if int(pokemon.hp) > 0 and battle.get("terrain","") == "grassy_terrain" and "flying" not in types: pokemon.hp = mini(int(pokemon.max_hp),int(pokemon.hp)+maxi(1,int(pokemon.max_hp)/16))
	PendingItems.end_turn(pokemon)
	for key in ["taunted","embargo","heal_block","telekinesis","reflect","light_screen","safeguard","tailwind","aurora_veil"]:
		if int(pokemon.get(key,0)) > 0: pokemon[key] = int(pokemon[key])-1
	if int(pokemon.get("encore_turns",0)) > 0:
		pokemon.encore_turns = int(pokemon.encore_turns)-1
		if pokemon.encore_turns == 0: pokemon.erase("encore_move")
	pokemon.erase("endure")
	pokemon.erase("quashed")
	if pokemon.get("last_move","") not in ["protect","detect"]: pokemon.protect_streak = 0
