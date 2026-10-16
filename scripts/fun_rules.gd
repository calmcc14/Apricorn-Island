extends RefCounted

# Independent randomness keeps FUN from changing battle or chest rolls.
const EVENTS := [
	{"id":"wrong_number", "min":2, "max":9, "node":"brook", "floor":3, "hint":"A ringing sound drifts across the water...", "title":"Wrong Number", "text":"A shell beside the brook rings.\n\nHello? Is this the moon?\n\nYou explain that this is an island. The caller thanks you and hangs up. The shell is silent again."},
	{"id":"echo", "min":41, "max":45, "node":"forest", "floor":7, "hint":"Someone whispers from an empty path...", "title":"An Early Echo", "text":"You hear your footsteps before you take them.\n\nA voice whispers: See you yesterday.\n\nFor a moment, every leaf stands perfectly still. Then the forest carries on."},
	{"id":"visitor", "min":66, "max":66, "node":"mystery", "floor":66, "hint":"A pale doorway flickers between the trees...", "title":"The Unlisted Visitor", "text":"Beyond the doorway sits a traveler with an empty map.\n\nSome islands only exist when someone remembers them.\n\nYou blink. The traveler and doorway are gone. Your team seems to remember nothing."},
	{"id":"stars", "min":90, "max":95, "node":"lookout", "floor":25, "hint":"One star is moving against the wind...", "title":"A Star Out of Place", "text":"A tiny light pauses above your team.\n\nYou made it all this way. I just wanted to see.\n\nIt rises into the sky, leaving a warm shimmer on your empty hands."}
]

static func initialize(state: Dictionary) -> void:
	# Preserve old saves at the former upper boundary.
	if state.get("fun_value", 0) == 100: state.fun_value = 99
	if not state.has("fun_value") or typeof(state.fun_value) not in [TYPE_INT, TYPE_FLOAT] or float(state.fun_value) != int(state.fun_value) or int(state.fun_value) < 1 or int(state.fun_value) > 99:
		var random := RandomNumberGenerator.new()
		random.randomize()
		state.fun_value = random.randi_range(1, 99)
	if not state.get("fun_seen", null) is Array:
		state.fun_seen = []

static func event_at(state: Dictionary, node: Dictionary) -> Dictionary:
	var value := int(state.get("fun_value", 0))
	for event in EVENTS:
		if value < int(event.min) or value > int(event.max) or event.id in state.get("fun_seen", []): continue
		if state.get("mode", "island") == "endless":
			if event.id == "visitor": continue # Replaced by the playable level-66 hallway.
			if int(node.get("floor", -1)) != int(event.floor): continue
		elif str(node.id) != str(event.node): continue
		return event.duplicate(true)
	return {}
