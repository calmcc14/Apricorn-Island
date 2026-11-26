extends RefCounted

const IMPACT := 0.5
const PALETTES := {
	"fire": [Color("#f56736"), Color("#fff0a5")],
	"water": [Color("#298ecf"), Color("#b3faff")],
	"grass": [Color("#3d9d51"), Color("#ddff9a")],
	"electric": [Color("#efad36"), Color("#fff9c7")],
	"ice": [Color("#5599df"), Color("#dcfbff")],
	"aura": [Color("#9163c4"), Color("#f3c7fc")],
	"hit": [Color("#eaa258"), Color("#fff6dc")],
}
const GOLD := Color("#ffd36a")
const LIGHT := Color("#fff6da")
const INK := Color("#273d48")

static func draw_move(canvas: CanvasItem, kind: String, start: Vector2, target: Vector2, time: float, missed: bool, caught: bool) -> void:
	if kind == "heal":
		draw_heal(canvas, target, time)
		return
	if kind == "capture":
		draw_capture(canvas, start, target, time, caught)
		return
	var palette: Array = PALETTES[kind]
	var color: Color = palette[0]
	var glow: Color = palette[1]
	var travel := clampf(time / IMPACT, 0.0, 1.0)
	var direction := start.direction_to(target)
	if missed: target += direction * 64.0 + Vector2(0, -22)
	if time >= IMPACT:
		if not missed: draw_impact(canvas, kind, target, (time - IMPACT) / (1.0 - IMPACT), color, glow)
		return
	if kind == "hit":
		if travel > 0.58:
			var center := target - direction * (1.0 - travel) * 62.0
			var slash := Vector2(24 * direction.x, -32) * (travel - 0.5) * 2.0
			canvas.draw_line(center - slash, center + slash, color, 9.0, true)
			canvas.draw_line(center - slash, center + slash, glow, 3.0, true)
		return
	var position := start.lerp(target, travel)
	var normal := direction.orthogonal()
	if kind == "electric":
		var bolt := PackedVector2Array([start])
		for i in range(1, 8):
			var offset := 8.0 + (i % 3) * 5.0
			bolt.append(start.lerp(position, i / 8.0) + normal * (offset if i % 2 == 0 else -offset))
		bolt.append(position)
		canvas.draw_polyline(bolt, color, 9.0, true)
		canvas.draw_polyline(bolt, glow, 3.0, true)
		if travel > 0.35:
			var fork := PackedVector2Array([bolt[4], bolt[4] + direction * 27.0 + normal * 18.0, bolt[4] + direction * 51.0 + normal * 12.0])
			canvas.draw_polyline(fork, color, 4.0, true)
			canvas.draw_polyline(fork, glow, 1.6, true)
		return
	for i in range(1, 8):
		var step := travel - i * 0.038
		if step <= 0.0: break
		var point := start.lerp(target, step) + normal * sin(step * 19.0 + i) * (14.0 - i)
		var radius := 12.0 - i
		if kind in ["grass", "ice"]:
			draw_glint(canvas, point, radius, glow.lerp(color, 0.5), step * 4.0)
		else:
			canvas.draw_circle(point, radius, Color(color, 0.85 - i * 0.085), true, -1.0, true)
	canvas.draw_circle(position, 10.0, color, true, -1.0, true)
	canvas.draw_circle(position - direction * 2.0, 5.0, glow, true, -1.0, true)

static func draw_impact(canvas: CanvasItem, kind: String, center: Vector2, time: float, color: Color, glow: Color) -> void:
	var fade := 1.0 - time
	var radius := lerpf(11.0, 52.0, ease(time, 0.45))
	canvas.draw_arc(center, radius, 0.0, TAU, 32, Color(color, fade * 0.7), 2.5, true)
	for i in 9:
		var direction := Vector2.from_angle(i * TAU / 9.0)
		var point := center + direction * radius * (0.8 + (i % 3) * 0.14)
		if kind in ["fire", "water", "aura"]:
			canvas.draw_circle(point, (4.0 + i % 3) * fade, Color(color.lerp(glow, (i % 3) * 0.4), fade), true, -1.0, true)
		else:
			draw_glint(canvas, point, (7.0 + i % 3 * 2.0) * fade, Color(color.lerp(glow, 0.32), fade), direction.angle())
	if time < 0.3:
		draw_glint(canvas, center, (1.0 - time / 0.3) * 23.0, glow, PI / 4.0)

static func draw_heal(canvas: CanvasItem, center: Vector2, time: float) -> void:
	var opacity := sin(time * PI)
	var color := Color(0.24, 0.78, 0.49, opacity)
	canvas.draw_arc(center, lerpf(18, 52, time), 0.0, TAU, 36, color, 3.0, true)
	for i in 5:
		var point := center + Vector2((i - 2) * 17 + sin(time * TAU + i) * 5, 28 - time * 88 + (i % 2) * 14)
		canvas.draw_line(point - Vector2(0, 7), point + Vector2(0, 7), color, 5.0, true)
		canvas.draw_line(point - Vector2(7, 0), point + Vector2(7, 0), color, 5.0, true)

static func draw_capture(canvas: CanvasItem, start: Vector2, target: Vector2, time: float, caught: bool) -> void:
	var center := target
	if time < IMPACT:
		var travel := time / IMPACT
		center = start.lerp(target, travel) - Vector2(0, sin(travel * PI) * 90.0)
	else:
		var settle := (time - IMPACT) / (1.0 - IMPACT)
		if caught:
			center.y += 38.0 * minf(1.0, settle * 2.8)
			center.x += sin(settle * TAU * 2.0) * sin(settle * PI) * 8.0
			if settle > 0.52: draw_shiny(canvas, center, (settle - 0.52) / 0.48, 0.55)
		else:
			draw_impact(canvas, "hit", center, settle, GOLD, LIGHT)
			if settle > 0.22: return
	canvas.draw_circle(center, 14, INK, true, -1.0, true)
	canvas.draw_circle(center, 11.5, Color("#fff3dc"), true, -1.0, true)
	canvas.draw_arc(center, 7.0, PI, TAU, 18, Color("#f26868"), 9.0, true)
	canvas.draw_line(center - Vector2(12, 0), center + Vector2(12, 0), INK, 2.5, true)
	canvas.draw_circle(center, 4.5, INK, true, -1.0, true)
	canvas.draw_circle(center, 2.5, LIGHT, true, -1.0, true)

static func draw_shiny(canvas: CanvasItem, center: Vector2, time: float, size := 1.0) -> void:
	if time <= 0.0 or time >= 1.0: return
	var extent := lerpf(18.0, 82.0, ease(time, 0.4)) * size
	var opacity := sin(time * PI)
	canvas.draw_arc(center, extent * 0.82, -PI * 0.62, PI * 1.16, 40, Color(GOLD, opacity * 0.74), 2.5 * size, true)
	for i in 7:
		var direction := Vector2.from_angle(i * TAU / 7.0 + time * 0.68)
		var point := center + direction * extent * Vector2(1.0, 0.74)
		var radius := (10.0 + i % 3 * 4.0) * opacity * size
		draw_glint(canvas, point, radius, Color(GOLD, opacity))
		draw_glint(canvas, point, radius * 0.63, Color(LIGHT, opacity))

static func draw_glint(canvas: CanvasItem, center: Vector2, radius: float, color: Color, angle := 0.0) -> void:
	if radius < 0.9: return
	var points := PackedVector2Array()
	for i in 8:
		var length := radius if i % 2 == 0 else radius * 0.29
		points.append(center + Vector2.from_angle(angle + i * PI / 4.0) * length)
	canvas.draw_colored_polygon(points, color)
