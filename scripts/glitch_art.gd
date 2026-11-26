extends RefCounted

const LIGHT := Color("#eee0ff")
const LILAC := Color("#c298e8")
const PALE := Color("#b693d3")
const VOID := Color("#120c1e")
const PANEL := Color("#eadbf6")
const ASSET_DIR := "res://assets/glitch/"
const Signals = preload("res://scripts/glitch_signals.gd")
static var profile_sprites: Dictionary = {}
static var generated_sprites: Dictionary = {}
const SPRITE_SIZE := 32
const SPRITE_CACHE_LIMIT := 256
const SPRITE_PALETTES := [
	[Color("#563a7e"), Color("#a778d6"), Color("#ead1ff"), Color("#61ead6")],
	[Color("#285367"), Color("#4aa6b7"), Color("#bbeff0"), Color("#f1a3e0")],
	[Color("#732f51"), Color("#c85c87"), Color("#ffd0d9"), Color("#f5c478")],
	[Color("#384961"), Color("#728eb2"), Color("#d6e5ff"), Color("#df96f0")],
	[Color("#3d584b"), Color("#76a67a"), Color("#d3ebad"), Color("#f1a9db")],
	[Color("#644049"), Color("#c48768"), Color("#f7dbac"), Color("#88e3ce")],
]
const SILHOUETTES := [
	[[-8,-5],[-3,-5],[-3,-8],[3,-8],[3,-6],[8,-6],[8,4],[4,4],[4,8],[-4,8],[-4,4],[-8,4]],
	[[-11,-8],[-3,-4],[0,-7],[3,-4],[11,-8],[9,1],[5,2],[4,6],[-4,6],[-5,2],[-9,1]],
	[[-9,0],[-6,-1],[-5,-6],[-2,-4],[2,-4],[5,-6],[6,-1],[9,0],[8,6],[4,6],[3,4],[-3,4],[-4,6],[-8,6]],
	[[-5,8],[-8,2],[-8,-5],[-3,-9],[3,-9],[7,-5],[9,2],[5,2],[4,8],[0,5],[-2,9]],
	[[-10,0],[-6,-6],[3,-8],[9,-5],[11,-2],[4,-1],[1,2],[10,1],[8,6],[-4,8],[-8,5]],
	[[-10,8],[-8,1],[-6,1],[-4,-6],[1,-8],[6,-6],[6,-1],[9,2],[10,8],[5,6],[1,9],[-2,6],[-6,9]],
	[[-11,2],[-7,4],[-3,2],[-2,-6],[2,-8],[7,-7],[9,-2],[6,2],[2,3],[-1,7],[-7,8],[-11,6]],
	[[-9,7],[-4,0],[-8,-5],[-3,-4],[0,-9],[3,-5],[8,-7],[6,0],[9,7],[4,5],[0,8],[-4,5]],
	[[-8,-5],[8,-5],[8,4],[2,4],[2,7],[-4,7],[-4,4],[-8,4]],
	[[-9,6],[-8,1],[-5,1],[-4,-8],[-1,-4],[2,-9],[3,-3],[7,-5],[6,0],[9,2],[10,7],[4,6],[0,9],[-4,6]],
	[[-11,5],[-7,-2],[-3,-2],[-1,-7],[4,-7],[8,-2],[11,5],[6,7],[-6,7]],
	[[-5,-7],[2,-9],[7,-4],[10,1],[5,3],[6,7],[0,6],[-6,8],[-8,3],[-11,1],[-6,-1]],
	[[-11,-3],[-6,-3],[-5,-7],[5,-7],[6,-3],[11,-3],[11,4],[5,4],[5,8],[-5,8],[-5,4],[-11,4]],
	[[-10,5],[-7,0],[-8,-4],[-1,-2],[0,-8],[4,-9],[8,-7],[10,-3],[4,0],[8,2],[4,8],[-5,7]],
	[[-11,5],[-8,-2],[-8,-6],[-4,-5],[0,-8],[4,-5],[8,-6],[8,-2],[11,5],[6,8],[-6,8]],
	[[-12,4],[-9,-1],[-11,-8],[-4,-5],[0,-11],[4,-5],[11,-8],[9,-1],[12,4],[6,5],[3,9],[0,7],[-3,9],[-6,5]],
]

static func pokedollar_font() -> FontFile:
	var font := FontFile.new()
	font.fixed_size = 32
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	var pixels := Image.create_empty(22,24,false,Image.FORMAT_RGBA8)
	for y in range(2,23):
		for x in range(1,21):
			var bowl := Vector2(maxi(x - 10,0) / 8.0,(y - 7) / 5.0).length_squared()
			var inner := Vector2(maxi(x - 10,0) / 5.0,(y - 7) / 2.5).length_squared()
			var stem := x >= 5 and x <= 7
			var bar := x >= 2 and x <= 15 and (y in [14,15,18,19])
			if stem or bar or (x >= 5 and bowl <= 1.0 and inner >= 1.0):
				pixels.set_pixel(x,y,Color.WHITE)
	var cache_size := Vector2i(font.fixed_size,0)
	var glyph := Signals.POKEDOLLAR.unicode_at(0)
	font.set_cache_ascent(0,font.fixed_size,24)
	font.set_cache_descent(0,font.fixed_size,8)
	font.set_texture_image(0,cache_size,0,pixels)
	font.set_glyph_texture_idx(0,cache_size,glyph,0)
	font.set_glyph_uv_rect(0,cache_size,glyph,Rect2(0,0,22,24))
	font.set_glyph_size(0,cache_size,glyph,Vector2(22,24))
	font.set_glyph_offset(0,cache_size,glyph,Vector2(0,-23))
	font.set_glyph_advance(0,font.fixed_size,glyph,Vector2(20,0))
	return font

static func space(canvas: CanvasItem, extent: Vector2, level: int, time: float, battle_scene: bool) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, extent), VOID)
	var horizon := extent.y * (0.38 if battle_scene else 0.42)
	for band in 10:
		var tint := Color("#221231").lerp(Color("#412557"), float(band) / 10.0)
		canvas.draw_rect(Rect2(0, band * horizon / 10, extent.x, horizon / 10 + 1), tint)
	for shard in 24:
		var x := fposmod(float(shard * 121 + level * 71) + time * float(shard % 4 + 1), extent.x + 100) - 50
		var y := float((shard * 91 + level * 11) % int(horizon + 120))
		var width := float(13 + (shard * 37) % 95)
		canvas.draw_rect(Rect2(x, y, width, 1 + shard % 3), Color("#b597d3").lerp(VOID, 0.56 + (shard % 4) * 0.09))
	var focus := Vector2(extent.x * 0.51, horizon)
	for ray in range(-8, 9):
		canvas.draw_line(focus + Vector2(ray * 7, 0), Vector2(focus.x + ray * extent.x / 5, extent.y), Color("#442858"), 2)
	for row in 13:
		var y := horizon + (extent.y - horizon) * pow(float(row) / 12, 1.9)
		canvas.draw_line(Vector2(0,y), Vector2(extent.x,y), Color("#512a6a"), 2)
	for column in 5:
		var anchor := Vector2(extent.x * (0.09 + column * 0.2), horizon + (column % 3) * 62 + 20)
		var drift := sin(time * 0.8 + column) * 4.0
		island(canvas, anchor + Vector2(drift, drift), 47.0 + float((column * 11 + level * 3) % 48), column % 2 == 0)
	if not battle_scene:
		for strip in 6:
			var y := horizon + strip * 39 + float((level * 17) % 25)
			var x := extent.x / 2.0 + (strip - 3) * 38.0 + sin(time + strip) * 9.0
			canvas.draw_rect(Rect2(x,y,62 + strip * 9,3), Color("#ad75d49a"))

static func island(canvas: CanvasItem, anchor: Vector2, width: float, inverted: bool) -> void:
	var direction := -1.0 if inverted else 1.0
	var corners := PackedVector2Array([anchor + Vector2(-width,0), anchor + Vector2(-width * 0.35,-width * 0.2), anchor + Vector2(width,-width * 0.06), anchor + Vector2(width * 0.42,width * 0.25)])
	canvas.draw_colored_polygon(corners, Color("#8661a0"))
	canvas.draw_colored_polygon(PackedVector2Array([corners[0],corners[3],corners[2],anchor + Vector2(width * 0.18,width * 0.86 * direction)]), Color("#362049"))
	canvas.draw_line(corners[0], corners[1], Color("#c196df"), 2)
	canvas.draw_line(corners[1], corners[2], Color("#c196df"), 2)
	canvas.draw_line(corners[0], corners[3], Color("#593777"), 3)
	canvas.draw_rect(Rect2(anchor.x-width*0.3,anchor.y+width*0.3*direction,width*0.75,3), Color("#9674b1"))

static func rift(canvas: CanvasItem, origin: Vector2, time: float, door: bool) -> void:
	var glow := (sin(time * 1.7) + 1.0) * 0.5
	for i in range(4,0,-1):
		var box := Rect2(origin - Vector2(40 + i * 7, 71 + i * 6), Vector2(80 + i * 14, 142 + i * 12))
		canvas.draw_rect(box, Color(0.66,0.44,0.83,0.11 - i * 0.015 + glow * 0.02))
	if door:
		canvas.draw_rect(Rect2(origin - Vector2(38,67),Vector2(76,134)),LILAC)
		canvas.draw_rect(Rect2(origin - Vector2(31,60),Vector2(62,124)),LIGHT)
		canvas.draw_rect(Rect2(origin - Vector2(23,54),Vector2(46,116)),Color("#f9efff"))
		canvas.draw_circle(origin + Vector2(17,13),4,Color("#644782"))
		return
	var fault := PackedVector2Array([Vector2(-33,-59),Vector2(22,-71),Vector2(10,-28),Vector2(38,-20),Vector2(-1,17),Vector2(8,66),Vector2(-36,33),Vector2(-18,-4)])
	for i in fault.size(): fault[i] += origin
	canvas.draw_colored_polygon(fault,Color("#0b0611"))
	fault.append(fault[0])
	canvas.draw_polyline(fault,LILAC,3)
	for i in 8:
		var y := float(i * 16 - 54)
		var x := sin(i * 5.0 + time * 2.5) * 13
		canvas.draw_rect(Rect2(origin + Vector2(x-24,y),Vector2(22+(i*7)%43,2)), LIGHT if i % 3 == 0 else Color("#8353a5"))

static func encounter_sprite(shape: int, record: Dictionary) -> Texture2D:
	if record.has("profile") and record.profile.has("sprite"): return profile_sprite(record.profile)
	var key := "%d/%s" % [shape, record.get("id", "")]
	if not generated_sprites.has(key):
		if generated_sprites.size() >= SPRITE_CACHE_LIMIT:
			generated_sprites.erase(generated_sprites.keys()[0])
		generated_sprites[key] = generate_sprite(shape, key)
	return generated_sprites[key]

static func generate_sprite(shape: int, key: String) -> ImageTexture:
	var random := RandomNumberGenerator.new()
	random.seed = key.sha256_text().left(8).hex_to_int()
	var palette: Array = SPRITE_PALETTES[random.randi_range(0, SPRITE_PALETTES.size() - 1)]
	var outline := Color("#211730")
	var image := Image.create_empty(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	var points := PackedVector2Array()
	var mirror := -1 if random.randi_range(0, 1) == 0 else 1
	var stretch := random.randf_range(0.87, 1.05)
	for point in SILHOUETTES[shape]:
		points.append(Vector2(16 + point[0] * mirror, 16 + point[1] * stretch))
	var mask := Image.create_empty(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_L8)
	var tear_row := random.randi_range(17, 21)
	for y in range(1, SPRITE_SIZE - 1):
		var tear := mirror * 2 if y in [tear_row, tear_row + 1] else 0
		for x in range(1, SPRITE_SIZE - 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5 - tear, y + 0.5), points):
				mask.set_pixel(x, y, Color.WHITE)
	var facet := random.randi_range(15, 20)
	for y in range(1, SPRITE_SIZE - 1):
		for x in range(1, SPRITE_SIZE - 1):
			if mask.get_pixel(x, y).r == 0.0: continue
			var rim := mask.get_pixel(x, y - 1).r == 0.0 or mask.get_pixel(x - mirror, y).r == 0.0
			var shade := mask.get_pixel(x, y + 1).r == 0.0 or mask.get_pixel(x + mirror, y).r == 0.0
			var lit := (x - 16) * mirror + y < facet
			var color: Color = palette[1] if lit else palette[0]
			if rim: color = palette[2]
			elif shade: color = outline
			elif y == tear_row: color = palette[3]
			image.set_pixel(x, y, color)
	var eye_width := random.randi_range(2, 4)
	var eye_gap := random.randi_range(1, 3)
	for eye in [16 - eye_gap - eye_width, 16 + eye_gap]:
		for x in range(eye, eye + eye_width):
			if mask.get_pixel(x, 14).r > 0.0:
				image.set_pixel(x, 14, palette[2])
				image.set_pixel(x, 15, outline)
	for fragment in 6:
		var y := random.randi_range(7, 25)
		var x := random.randi_range(1, 4) if fragment % 2 == 0 else random.randi_range(26, 29)
		if mask.get_pixel(x, y).r == 0.0 and mask.get_pixel(x + 1, y).r == 0.0:
			image.fill_rect(Rect2i(x, y, random.randi_range(1, 2), 1), palette[3] if fragment % 3 == 0 else palette[1])
	return ImageTexture.create_from_image(image)

static func profile_sprite(profile: Dictionary) -> AtlasTexture:
	var id := str(profile.portrait)
	if not profile_sprites.has(id):
		var sprite := AtlasTexture.new()
		sprite.atlas = load(ASSET_DIR + str(profile.sprite)) as Texture2D
		var region: Array = profile.region
		sprite.region = Rect2(region[0],region[1],region[2],region[3])
		sprite.filter_clip = true
		profile_sprites[id] = sprite
	return profile_sprites[id]

static func draw_portrait(canvas: CanvasItem, center: Vector2, sprite: Texture2D, scale_factor: float, time := 0.0, opacity := 1.0, reacting := false) -> void:
	var tint := Color(1.0,1.0,1.0,opacity)
	var extent := sprite.get_size() * scale_factor
	var origin := (center - extent / 2.0).round()
	if not reacting:
		canvas.draw_texture_rect(sprite,Rect2(origin,extent),false,tint)
		return
	var band_height := 7 if sprite is AtlasTexture else 4
	for start in range(0,sprite.get_height(),band_height):
		var band := Rect2(0,start,sprite.get_width(),mini(band_height,sprite.get_height() - start))
		var shift := roundf(sin(time * 16.0 + start) * 12.0 / scale_factor) * scale_factor
		var target := Rect2(origin + Vector2(shift,start * scale_factor),band.size * scale_factor)
		canvas.draw_texture_rect_region(sprite,target,band,tint)

static func transition(canvas: CanvasItem, extent: Vector2, progress: float) -> void:
	var strength := smoothstep(0.0,0.7,progress)
	canvas.draw_rect(Rect2(Vector2.ZERO,extent),Color(VOID,0.32 + strength * 0.68))
	for i in 34:
		var y := float((i * 83) % int(extent.y))
		var x := sin(progress * 18.0 + i * 93.0) * extent.x * 0.5
		var height := float(3 + (i * 17) % 20)
		var color := Color("#49295f") if i % 4 else Color("#986aba")
		canvas.draw_rect(Rect2(x,y,extent.x * (0.45 + strength * 0.65),height),color)
	var font := ThemeDB.fallback_font
	var text := "SIGNAL LOST"
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,29).x
	var position := Vector2((extent.x-width)/2,extent.y/2)
	canvas.draw_string_outline(font,position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,29,9,VOID)
	canvas.draw_string(font,position,text,HORIZONTAL_ALIGNMENT_LEFT,-1,29,LIGHT)
