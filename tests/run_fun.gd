extends SceneTree

const FunRules = preload("res://scripts/fun_rules.gd")

func _init() -> void:
	var state := {}
	FunRules.initialize(state)
	assert(state.fun_value >= 1 and state.fun_value <= 99)
	var original: int = state.fun_value
	FunRules.initialize(state)
	assert(state.fun_value == original)
	for value in range(1, 100):
		state = {"fun_value": value, "fun_seen": []}
		for event in FunRules.EVENTS:
			var node := {"id": event.node, "floor": event.floor}
			var found: Dictionary = FunRules.event_at(state, node)
			assert(not found.is_empty() == (value >= event.min and value <= event.max))
			state.mode = "endless"
			assert(FunRules.event_at(state, node).is_empty() if event.id == "visitor" else FunRules.event_at(state, node) == found)
			assert(FunRules.event_at(state, {"id": event.node, "floor": 0}).is_empty())
			state.erase("mode")
			if not found.is_empty():
				state.fun_seen.append(event.id)
				assert(FunRules.event_at(state, node).is_empty())
				state.fun_seen.clear()
	var restored: Dictionary = JSON.parse_string(JSON.stringify({"fun_value":66,"fun_seen":["visitor"]}))
	FunRules.initialize(restored)
	assert(restored.fun_value == 66)
	assert(FunRules.event_at(restored, {"id":"mystery"}).is_empty())
	var legacy := {"fun_value":100, "fun_seen":["echo"]}
	FunRules.initialize(legacy)
	assert(legacy.fun_value == 99 and legacy.fun_seen == ["echo"] )
	print("FUN range, persistence, event gating and one-time checks passed.")
	quit()
