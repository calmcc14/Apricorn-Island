class_name PendingItems
extends RefCounted

static var runtime: Dictionary = {}
const STATS := ["attack","defense","special_attack","special_defense","speed","accuracy","evasion"]
const POWER_STATS := {"item_power_weight":"hp","item_power_bracer":"attack","item_power_belt":"defense","item_power_lens":"special_attack","item_power_band":"special_defense","item_power_anklet":"speed"}

static func data() -> Dictionary:
	if runtime.is_empty(): runtime = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_runtime_reference.json"))
	return runtime

static func flag(move: Dictionary, flag_name: String) -> bool:
	return flag_name in data().move_flags.get(str(int(move.get("index",move.get("move_index",0)))),[]) or move.get(flag_name,false)

static func consume(pokemon: Dictionary) -> void:
	pokemon.consumed_item = str(pokemon.get("held_item",""))
	pokemon.held_item = ""

static func indirect_damage(pokemon: Dictionary, amount: int) -> void:
	if pokemon.get("ability","") != "magic_guard": pokemon.hp = maxi(0,int(pokemon.hp)-maxi(1,amount))

static func stat_multiplier(pokemon: Dictionary, stat: String) -> float:
	var id := held(pokemon)
	var name := str(pokemon.get("species",""))
	var value := 1.0
	if (id == "item_choice_band" and stat == "attack") or (id == "item_choice_specs" and stat == "special_attack") or (id == "item_choice_scarf" and stat == "speed") or (id == "item_assault_vest" and stat == "special_defense"): value *= 1.5
	if id == "item_eviolite" and stat in ["defense","special_defense"] and ItemProgression.info(name).get("can_evolve",false): value *= 1.5
	if id == "item_soul_dew" and name in ["latios","latias"] and stat in ["special_attack","special_defense"]: value *= 1.5
	if id == "item_light_ball" and name == "pikachu":
		if stat == "attack": value *= 2
		if stat == "special_attack": value *= 4
	if id in POWER_STATS and stat == "speed": value *= 0.5
	return value

static func move_allowed(pokemon: Dictionary, move_id: String) -> bool:
	if pokemon.get("charging_move",move_id) != move_id: return false
	var id := held(pokemon)
	if id == "item_assault_vest" and GameData.MOVES[move_id].kind != "damage": return false
	return not (id in ["item_choice_band","item_choice_specs","item_choice_scarf"] and pokemon.get("choice_move",move_id) != move_id)

static func select_move(pokemon: Dictionary, move_id: String) -> void:
	if held(pokemon) in ["item_choice_band","item_choice_specs","item_choice_scarf"] and not pokemon.has("choice_move"): pokemon.choice_move = move_id

static func boosted_secondary(actor: Dictionary, move: Dictionary) -> bool:
	return actor.get("ability","") == "sheer_force" and (int(move.get("ailment_chance",0)) > 0 or int(move.get("flinch_chance",0)) > 0 or (not move.get("stat_changes",[]).is_empty() and int(move.get("stat_chance",0)) > 0))

static func before_action(pokemon: Dictionary, random: RandomNumberGenerator) -> void:
	pokemon.quick_first = held(pokemon) == "item_quick_claw" and random.randf() < 0.2
	if pokemon.get("custap_ready",false): pokemon.quick_first = true

static func survival(target: Dictionary, damage: int, random: RandomNumberGenerator, band_active: bool = false, confusion: bool = false) -> int:
	if damage < int(target.hp) or int(target.hp) <= 0: return damage
	if band_active: return maxi(0,int(target.hp)-1)
	if held(target) == "item_focus_sash" and not confusion and int(target.hp) == int(target.max_hp):
		consume(target)
		return maxi(0,int(target.hp)-1)
	if held(target) == "item_focus_band" and random.randi_range(0,255) < 30:
		target.band_active = true
		return maxi(0,int(target.hp)-1)
	return damage

static func reduce_hit(actor: Dictionary, target: Dictionary, move: Dictionary, damage: int, effectiveness: float, confusion: bool = false) -> int:
	var item: Dictionary = GameData.ITEMS.get(held(target),{})
	if damage > 0 and item.get("resist_type","") == str(move.type) and (effectiveness > 1 or item.id == "item_chilan_berry") and (actor.get("ability","") != "unnerve" or confusion):
		consume(target)
		return maxi(1,int(damage/2.0))
	return damage

static func after_hit(actor: Dictionary, target: Dictionary, move: Dictionary, effectiveness: float, random: RandomNumberGenerator, secondary: bool, contact: bool) -> void:
	var target_id := held(target)
	var special := int(move.get("damage_class",2)) == 3
	if target_id == "item_air_balloon": consume(target)
	if contact and held(actor) != "item_protective_pads" and target_id == "item_rocky_helmet": indirect_damage(actor,int(actor.max_hp)/6)
	if actor.get("ability","") == "unnerve": return
	if target_id == "item_jaboca_berry" and not special or target_id == "item_rowap_berry" and special:
		consume(target)
		indirect_damage(actor,int(actor.max_hp)/8)
	if int(target.hp) <= 0: return
	if target_id == "item_weakness_policy" and effectiveness > 1:
		var raised := ItemMechanics.raise_stat(target,"attack",2)
		raised = ItemMechanics.raise_stat(target,"special_attack",2) or raised
		if raised: consume(target)
	if target_id == "item_enigma_berry" and effectiveness > 1 and int(target.get("heal_block",0)) <= 0 and int(target.hp) < int(target.max_hp):
		consume(target)
		heal(target,int(target.max_hp)/4)
	if not secondary and ((target_id == "item_kee_berry" and not special) or (target_id == "item_maranga_berry" and special)):
		if ItemMechanics.raise_stat(target,"special_defense" if special else "defense",1): consume(target)
	if held(actor) in ["item_king_s_rock","item_razor_fang"] and int(move.get("flinch_chance",0)) == 0 and not secondary and not target.get("acted_this_turn",false) and held(target) not in ["item_covert_cloak","item_cleanse_tag","item_pure_incense"] and target.get("ability","") != "inner_focus":
		var chance := 0.2 if actor.get("ability","") == "serene_grace" else 0.1
		if random.randf() < chance: target.flinched = true

static func activate(pokemon: Dictionary, battle: Dictionary, random: RandomNumberGenerator) -> void:
	if int(pokemon.hp) <= 0: return
	var id := held(pokemon)
	if id == "item_white_herb":
		var changed := false
		for stat in STATS:
			if int(pokemon.get(stat+"_stage",0)) < 0:
				pokemon[stat+"_stage"] = 0
				changed = true
		if changed: consume(pokemon)
	if id == "item_mental_herb":
		var changed := false
		for key in ["attracted","taunted","encore_move","tormented","disabled_move","heal_block"]:
			if pokemon.get(key,0) not in [0,false,""]:
				pokemon.erase(key)
				changed = true
		if changed: pokemon.erase("encore_turns"); consume(pokemon)
	if id == "item_room_service" and int(battle.get("trick_room",0)) > 0:
		if ItemMechanics.raise_stat(pokemon,"speed",-1): consume(pokemon)
	var item: Dictionary = GameData.ITEMS.get(held(pokemon),{})
	if item.has("low_stat") and int(pokemon.hp) <= int(pokemon.max_hp)*(0.5 if pokemon.get("ability","") == "gluttony" else 0.25):
		var stat := str(item.low_stat)
		var changed := false
		if stat in STATS: changed = ItemMechanics.raise_stat(pokemon,stat,1)
		elif stat == "critical" and int(pokemon.get("critical_stage",0)) < 2: pokemon.critical_stage = 2; changed = true
		elif stat == "accuracy_next" and not pokemon.get("micle_ready",false): pokemon.micle_ready = true; changed = true
		elif stat == "priority_next" and not pokemon.get("custap_ready",false): pokemon.custap_ready = true; changed = true
		elif stat == "random":
			var eligible: Array = []
			for key in ["attack","defense","special_attack","special_defense","speed"]:
				if int(pokemon.get(key+"_stage",0)) < 6: eligible.append(key)
			if not eligible.is_empty(): changed = ItemMechanics.raise_stat(pokemon,str(eligible[random.randi_range(0,eligible.size()-1)]),2)
		if changed: consume(pokemon)

static func friendship(pokemon: Dictionary, amount: int) -> void:
	if amount > 0:
		if pokemon.get("capture_ball","") == "item_luxury_ball": amount += 1
		if pokemon.get("at_met_location",false): amount += 1
	if amount > 0 and held(pokemon) == "item_soothe_bell": amount = int(amount*1.5)
	pokemon.friendship = clampi(int(pokemon.get("friendship",70))+amount,0,255)

static func entry_hazards(pokemon: Dictionary, battle: Dictionary, player_side: bool, random: RandomNumberGenerator) -> void:
	if held(pokemon) == "item_heavy_duty_boots": return
	var hazards: Dictionary = battle.get("player_hazards" if player_side else "enemy_hazards",{})
	var types: Array = ItemMechanics.species(pokemon).get("types",[])
	var grounded: bool = "flying" not in types and pokemon.get("ability","") != "levitate" and held(pokemon) != "item_air_balloon"
	if int(battle.get("gravity",0)) > 0: grounded = true
	if int(hazards.get("stealth_rock",0)) > 0: indirect_damage(pokemon,int(float(pokemon.max_hp)*MoveEffects.effectiveness("rock",pokemon)/8.0))
	var layers := int(hazards.get("spikes",0))
	if grounded and layers > 0: indirect_damage(pokemon,int(pokemon.max_hp)/(8 if layers == 1 else (6 if layers == 2 else 4)))
	if grounded and "poison" in types: hazards.erase("toxic_spikes")
	elif grounded and int(hazards.get("toxic_spikes",0)) > 0: MoveEffects.inflict(pokemon,"toxic" if int(hazards.toxic_spikes) >= 2 else "poison",random)

static func ev_use(item: Dictionary, pokemon: Dictionary, apply_effect: bool) -> bool:
	var stat := str(item.ev_stat)
	var value := int(pokemon.get("evs",{}).get(stat,0))
	var total := 0
	for v in pokemon.get("evs",{}).values(): total += int(v)
	var gain := mini(10,mini(252-value,510-total)) if int(item.ev_amount) > 0 else -mini(10,value)
	var friends := int(pokemon.get("friendship",70))
	if gain == 0 and (int(item.ev_amount) > 0 or friends >= 255): return false
	if apply_effect:
		if not pokemon.has("evs"): pokemon.evs = {}
		pokemon.evs[stat] = value+gain
		friendship(pokemon,5 if friends < 100 else (3 if friends < 200 else 2))
		apply_ev_bonuses(pokemon)
	return true

static func apply_ev_bonuses(pokemon: Dictionary) -> void:
	if not pokemon.has("ev_stat_bonuses"): pokemon.ev_stat_bonuses = {}
	for stat in ItemMechanics.IV_STATS:
		var key: String = "max_hp" if stat == "hp" else str(stat)
		var value := int(int(pokemon.get("evs",{}).get(stat,0))/4.0*int(pokemon.get("level",5))/100.0)
		var delta := value-int(pokemon.ev_stat_bonuses.get(stat,0))
		pokemon[key] = maxi(1,int(pokemon.get(key,10))+delta)
		if stat == "hp" and int(pokemon.hp) > 0: pokemon.hp = clampi(int(pokemon.hp)+delta,1,int(pokemon.max_hp))
		pokemon.ev_stat_bonuses[stat] = value

static func hyper_train(pokemon: Dictionary, stat: String, all_stats: bool, apply_effect: bool) -> bool:
	if int(pokemon.get("level",5)) < 50: return false
	var changed := false
	for key in ItemMechanics.IV_STATS:
		if not all_stats and key != stat: continue
		if int(pokemon.ivs[key]) < 31 and not pokemon.get("hyper_trained",{}).get(key,false):
			changed = true
			if apply_effect:
				if not pokemon.has("hyper_trained"): pokemon.hyper_trained = {}
				pokemon.hyper_trained[key] = true
	if changed and apply_effect: ItemMechanics.apply_iv_bonuses(pokemon)
	return changed

static func sacred_ash(item_id: String, party: Array, apply_effect: bool) -> bool:
	var fainted := false
	for pokemon in party:
		if int(pokemon.hp) <= 0: fainted = true
	if not fainted: return false
	if apply_effect:
		for pokemon in party:
			if item_id == "item_sacred_ash" or int(pokemon.hp) <= 0:
				pokemon.hp = int(pokemon.max_hp)
				pokemon.status_condition = ""
				pokemon.erase("confusion_turns")
				if item_id == "item_sacred_ash":
					for move in pokemon.moves: pokemon.pp[move] = max_pp(pokemon,move)
	return true

static func held(pokemon: Dictionary) -> String:
	if int(pokemon.get("embargo",0)) > 0 or pokemon.get("held_suppressed",false): return ""
	return str(pokemon.get("held_item",""))

static func ability_patch(pokemon: Dictionary, apply_effect: bool) -> bool:
	var abilities: Dictionary = ItemProgression.info(str(pokemon.species)).get("abilities",{})
	if not abilities.has("hidden") or not abilities.has("1"): return false
	if abilities.hidden == abilities["1"]: return false
	var current := str(pokemon.get("ability_slot","1"))
	if current not in ["1","2","hidden"]: return false
	if apply_effect:
		pokemon.ability_slot = "1" if current == "hidden" else "hidden"
		pokemon.ability = abilities[pokemon.ability_slot]
	return true

static func heal(pokemon: Dictionary, amount: int) -> void:
	if int(pokemon.hp) > 0 and int(pokemon.get("heal_block",0)) <= 0:
		pokemon.hp = mini(int(pokemon.max_hp),int(pokemon.hp)+maxi(1,amount))

static func critical_stages(pokemon: Dictionary) -> int:
	var id := held(pokemon)
	if id in ["item_scope_lens","item_razor_claw"]: return 1
	if id == "item_lucky_punch" and pokemon.species == "chansey": return 2
	if id == "item_leek" and pokemon.species in ["farfetchd","farfetchd-galar","farfetchd_galar","sirfetchd"]: return 2
	return 0

static func power(pokemon: Dictionary, special: bool, effectiveness: float) -> float:
	var id := held(pokemon)
	var multiplier := 1.0
	if id == "item_expert_belt" and effectiveness > 1: multiplier *= 1.2
	if id == "item_muscle_band" and not special: multiplier *= 1.1
	if id == "item_wise_glasses" and special: multiplier *= 1.1
	if id == "item_light_ball" and pokemon.get("species","") == "pikachu": multiplier *= 2
	return multiplier

static func end_turn(pokemon: Dictionary) -> void:
	if int(pokemon.hp) <= 0: return
	var id := held(pokemon)
	if id == "item_leftovers": heal(pokemon,maxi(1,int(pokemon.max_hp)/16))
	if id == "item_black_sludge":
		if "poison" in ItemMechanics.species(pokemon).get("types",[]): heal(pokemon,maxi(1,int(pokemon.max_hp)/16))
		elif pokemon.get("ability","") != "magic_guard": pokemon.hp = maxi(0,int(pokemon.hp)-maxi(1,int(pokemon.max_hp)/8))

static func max_pp(pokemon: Dictionary, move_id: String) -> int:
	var base := int(GameData.MOVES[move_id].get("pp",35))
	return base + int(base * 0.2 * clampi(int(pokemon.get("pp_upgrades",{}).get(move_id,0)),0,3))

static func cure(item: Dictionary, pokemon: Dictionary, apply_effect: bool) -> bool:
	if int(pokemon.hp) <= 0: return false
	var conditions: Array = item.get("cures",[])
	var status := str(pokemon.get("status_condition",""))
	var all_status := "all" in conditions
	var changed := false
	if status != "" and (all_status or status in conditions):
		changed = true
		if apply_effect:
			pokemon.status_condition = ""
			pokemon.erase("sleep_turns")
			pokemon.erase("toxic_turns")
	for key in ["confusion_turns","attracted"]:
		var condition: String = "confusion" if key == "confusion_turns" else str(key)
		if (condition in conditions or (all_status and key == "confusion_turns")) and int(pokemon.get(key,0)) > 0:
			changed = true
			if apply_effect: pokemon.erase(key)
	if item.get("full_hp",false) and int(pokemon.hp) < int(pokemon.max_hp):
		changed = true
		if apply_effect: pokemon.hp = int(pokemon.max_hp)
	return changed

static func pp_use(item: Dictionary, pokemon: Dictionary, move_id: String, apply_effect: bool) -> bool:
	if int(pokemon.hp) <= 0: return false
	var changed := false
	for move in pokemon.get("moves",[]):
		if not item.get("all_moves",false) and move != move_id: continue
		var maximum := max_pp(pokemon,move)
		var current := int(pokemon.get("pp",{}).get(move,maximum))
		if item.get("pp_upgrade",false):
			var base := int(GameData.MOVES[move].get("pp",35))
			var old := int(pokemon.get("pp_upgrades",{}).get(move,0))
			if base < 5 or move == "sketch" or old >= 3: continue
			changed = true
			if apply_effect:
				if not pokemon.has("pp_upgrades"): pokemon.pp_upgrades = {}
				pokemon.pp_upgrades[move] = 3 if int(item.pp_amount) == 3 else old+1
				pokemon.pp[move] = current+max_pp(pokemon,move)-maximum
		elif current < maximum:
			changed = true
			if apply_effect: pokemon.pp[move] = maximum if int(item.pp_amount) < 0 else mini(maximum,current+int(item.pp_amount))
	return changed

static func friendship_loss(item: Dictionary, pokemon: Dictionary) -> void:
	if item.has("friendship_loss"):
		var value := int(pokemon.get("friendship",70))
		pokemon.friendship = maxi(0,value-int(item.friendship_loss[0 if value < 200 else 1]))

static func held_cure(pokemon: Dictionary, messages: Array[String]) -> bool:
	if int(pokemon.get("embargo",0)) > 0 or pokemon.get("held_suppressed",false): return false
	var id := str(pokemon.get("held_item",""))
	var item: Dictionary = GameData.ITEMS.get(id,{})
	var used := false
	if item.get("kind","") == "cure_berry": used = cure(item,pokemon,true)
	if id == "item_leppa_berry":
		for move in pokemon.get("moves",[]):
			if int(pokemon.pp.get(move,1)) == 0:
				used = pp_use(item,pokemon,move,true)
				break
	if used:
		pokemon.consumed_item = id
		pokemon.held_item = ""
		messages.append("%s activated." % item.name)
	return used
