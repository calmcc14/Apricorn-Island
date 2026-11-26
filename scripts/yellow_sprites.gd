extends RefCounted

const INK := Color("#34243c")
const SHADE := Color("#9c542c")
const AMBER := Color("#e99830")
const GOLD := Color("#f7cf55")
const LIGHT := Color("#fff4b0")
const PALETTE := [INK, SHADE, AMBER, GOLD, LIGHT]
const DITHER := [0, 2, 3, 1]
const TYPE_COLORS := {
	"normal":"#e5c197", "fighting":"#ee7953", "flying":"#b8ceff", "poison":"#dca3ff",
	"ground":"#e8a762", "rock":"#d1b36d", "bug":"#bcdb65", "ghost":"#b798e9",
	"steel":"#b9d3d3", "fire":"#ff9760", "water":"#82dce9", "grass":"#aee37c",
	"electric":"#ffe07a", "psychic":"#ff9ec3", "ice":"#a7eef1", "dragon":"#beadff",
	"dark":"#caaa9e", "fairy":"#ffbcd6",
}

static func from_art(source: Image) -> ImageTexture:
	var image := source.duplicate() as Image
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a == 0.0: continue
			var dither := (float(DITHER[(y % 2) * 2 + x % 2]) - 1.5) * 0.15
			var shade := clampi(roundi(pixel.get_luminance() * 4.4 + dither), 0, PALETTE.size() - 1)
			var toned: Color = PALETTE[shade]
			toned.a = pixel.a
			image.set_pixel(x, y, toned)
	return ImageTexture.create_from_image(image)

static func field_portrait(species: Dictionary, back: bool) -> ImageTexture:
	# Fallback for a missing or unreadable sprite file.
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	var number := int(species.get("dex_id", 0))
	var stats: Dictionary = species.get("stats", {})
	var types: Array = species.get("types", ["normal"])
	var tint := Color(TYPE_COLORS.get(types[0], "#ffde79"))
	var accent := Color(TYPE_COLORS.get(types.back(), "#ffde79"))
	var body_width := clampi(9 + int(stats.get("hp", 40)) / 16, 11, 19)
	var slope := 2 + number % 4
	for y in range(3, 23):
		var half_width := body_width / 2 - maxi(0, absi(y - 12) - 4) / 2
		var center := 16 + (1 if back else -1) * (y - 12) / slope
		for x in range(center - half_width, center + half_width):
			var edge := x == center - half_width or x == center + half_width - 1 or y in [3, 22]
			var fill := tint if y < 14 else tint.darkened(0.35)
			if (y + x + number) % 5 == 0: fill = fill.lerp(accent, 0.45)
			image.set_pixel(x, y, INK if edge else fill)
	if back:
		image.fill_rect(Rect2i(15, 7, 2, 12), tint.darkened(0.35))
	else:
		image.fill_rect(Rect2i(12, 9, 4, 4), INK)
		image.fill_rect(Rect2i(13, 10, 2, 2), LIGHT)
	return ImageTexture.create_from_image(image.get_region(image.get_used_rect()))
