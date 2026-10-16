class_name BossOrbs
extends RefCounted

const SPECIES := {"item_red_orb":"groudon","item_blue_orb":"kyogre"}

static func initialize(state: Dictionary) -> void:
	if not state.has("orb_instances"): state.orb_instances = {}
	if not state.has("orb_boss_caught"): state.orb_boss_caught = {}
	for id in SPECIES:
		var count := int(state.get("inventory",{}).get(id,0))
		for p in state.get("party",[])+state.get("reserve",[]):
			if p.get("held_item","") == id: count += 1
		for store in state.get("chest_stores",{}).values(): count += int(store.get(id,0))
		if not state.get("chest_stores",{}).has(str(state.get("active_chest",""))): count += int(state.get("chest_storage",{}).get(id,0))
		if not state.orb_instances.has(id): state.orb_instances[id] = []
		var copies: Array = state.orb_instances[id]
		while copies.size() < count:
			copies.append({"uid":"%s_%d" % [id,copies.size()],"additional":copies.size() > 0,"meter":10,"cooldown":0,"unused_levels":0,"held_only":false})

static func available(state: Dictionary, id: String, index: int) -> bool:
	initialize(state)
	if int(state.inventory.get(id,0)) <= 0 or index < 0 or index >= state.orb_instances.get(id,[]).size(): return false
	var orb: Dictionary = state.orb_instances[id][index]
	var bag_index := 0
	for candidate in state.orb_instances[id]:
		var held_copy := false
		for p in state.get("party",[])+state.get("reserve",[]):
			if p.get("held_orb_uid","") == candidate.uid: held_copy = true
		if held_copy: continue
		if candidate.uid == orb.uid: break
		bag_index += 1
	if bag_index >= int(state.inventory.get(id,0)): return false
	for p in state.get("party",[])+state.get("reserve",[]):
		if p.get("held_orb_uid","") == orb.uid: return false
	return not orb.held_only and int(orb.cooldown) == 0

static func attempt(state: Dictionary, id: String, index: int, random: RandomNumberGenerator) -> bool:
	if not available(state,id,index): return false
	var orb: Dictionary = state.orb_instances[id][index]
	orb.unused_levels = 0
	var additional: bool = bool(orb.additional) and state.orb_boss_caught.get(id,false)
	var meter := int(orb.meter)
	if additional and not orb.get("first_retry",false) and (meter <= 0 or random.randf()*100 >= meter):
		orb.meter = maxi(0,meter-1)
		return false
	orb.summoned_meter = meter
	return true

static func outcome(state: Dictionary, id: String, index: int, result: String) -> void:
	var orb: Dictionary = state.orb_instances[id][index]
	if result == "capture":
		orb.held_only = true
		state.orb_boss_caught[id] = true
		for other in state.orb_instances[id]:
			if other.uid != orb.uid: other.additional = true
	elif result == "knockout": orb.cooldown = 5
	elif result == "loss" and orb.additional and state.orb_boss_caught.get(id,false):
		orb.meter = maxi(0,int(orb.meter)-5)
		if int(orb.get("summoned_meter",0)) >= 100: orb.first_retry = true
	orb.erase("summoned_meter")

static func cleared_levels(state: Dictionary, count: int, random: RandomNumberGenerator) -> void:
	initialize(state)
	for copies in state.orb_instances.values():
		for orb in copies:
			if orb.held_only: continue
			orb.cooldown = maxi(0,int(orb.cooldown)-count)
			if not orb.additional: continue
			orb.meter = mini(100,int(orb.meter)+count)
			orb.unused_levels = int(orb.unused_levels)+count
			while int(orb.unused_levels) >= 5:
				orb.unused_levels = int(orb.unused_levels)-5
				if random.randf() < 0.45: orb.meter = mini(100,int(orb.meter)+10)

static func label(orb: Dictionary, boss_caught: bool = true) -> String:
	if orb.held_only: return "Held use only"
	if int(orb.cooldown) > 0: return "%d island levels to recharge" % int(orb.cooldown)
	if int(orb.meter) <= 0: return "No power"
	return "%d%% summon power" % int(orb.meter) if orb.additional and boss_caught else "Ready to summon"
