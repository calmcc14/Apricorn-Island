class_name GameRules
extends RefCounted

const TYPE_CHART := {
	"fire": {"grass": 2.0, "water": 0.5, "fire": 0.5},
	"water": {"fire": 2.0, "grass": 0.5, "water": 0.5, "rock": 2.0},
	"grass": {"water": 2.0, "fire": 0.5, "grass": 0.5, "rock": 2.0},
	"electric": {"water": 2.0, "grass": 0.5, "electric": 0.5},
	"rock": {"fire": 2.0},
	"normal": {}
}

static func capture_chance(ball_bonus: float, current_hp: int, max_hp: int) -> float:
	var ratio: float = clamp(float(current_hp) / float(max(1, max_hp)), 0.0, 1.0)
	return clamp(ball_bonus + (1.0 - ratio) * 0.65, 0.05, 0.95)

static func effectiveness(move_type: String, target_type: String) -> float:
	return float(TYPE_CHART.get(move_type, {}).get(target_type, 1.0))

static func calculate_damage(power: float, attack: int, defense: int, effectiveness_value: float, variance: float = 1.0) -> int:
	var base: float = float(power) * float(max(1, attack)) / float(max(1, defense))
	return max(1, int(round(base * effectiveness_value * clamp(variance, 0.85, 1.15))))

static func revive_hp(max_hp: int) -> int:
	return max(1, int(ceil(float(max_hp) / 5.0)))
