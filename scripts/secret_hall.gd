extends Control

signal checkpoint
signal exited

const PLAYER_PROFILE := {"name":"CHARA", "lv":1, "hp":20, "max_hp":20, "gold":69, "weapon":"Ballet Shoes", "armor":"Old Tutu", "items":[]}

var progress: Dictionary
var profile: Dictionary = PLAYER_PROFILE.duplicate(true)
var frisk_sheet: Texture2D = preload("res://assets/frisk_sheet.png")
var hallway_reference: Texture2D = preload("res://assets/secret_hall_reference.jpg")
var room_reference: Texture2D = preload("res://assets/secret_room_reference.png")
var idle: Texture2D = preload("res://assets/gaster_idle.webp")
var reaction: Texture2D = preload("res://assets/gaster_react.webp")
var menu := ""
var selection := 0
var message := ""
var vanish_time := 0.0
var walk_time := 0.0
var facing := "down"
var moving := false
var player := Vector2(80, 300)
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Key only the sprite sheet; room textures and UI retain their own alpha.
	var pixels := frisk_sheet.get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	var background := pixels.get_pixel(646, 436)
	var tile_background := Color("#c386ff")
	for y in pixels.get_height():
		for x in pixels.get_width():
			var color := pixels.get_pixel(x, y)
			if color.is_equal_approx(background) or color.is_equal_approx(tile_background):
				pixels.set_pixel(x, y, Color.TRANSPARENT)
	frisk_sheet = ImageTexture.create_from_image(pixels)
	player = Vector2(float(progress.get("x", 80)), float(progress.get("y", 300)))

func remember() -> void:
	progress.x = player.x
	progress.y = player.y
	checkpoint.emit()

func handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo: return
	var key := event.physical_keycode if event.physical_keycode else event.keycode
	if not message.is_empty():
		if key in [KEY_Z, KEY_ENTER, KEY_X, KEY_SHIFT]: message = ""
	elif not menu.is_empty():
		if key in [KEY_X, KEY_SHIFT, KEY_C, KEY_CTRL]:
			menu = "" if menu == "main" else "main"
			selection = 0
		elif key in [KEY_UP, KEY_DOWN]:
			var count: int = 3 if menu == "main" else (profile.get("items", []).size() if menu == "items" else 1)
			selection = posmod(selection + (-1 if key == KEY_UP else 1), maxi(1, count))
		elif key in [KEY_Z, KEY_ENTER]:
			if menu == "main":
				menu = ["items", "stat", "cell"][selection]
				selection = 0
			elif menu == "cell": message = "* There is no signal here."
			elif menu == "items" and not profile.get("items", []).is_empty():
				message = "* %s" % str(profile.items[selection])
	elif key in [KEY_C, KEY_CTRL]:
		menu = "main"
		selection = 0
	elif key in [KEY_Z, KEY_ENTER]:
		interact()
	queue_redraw()

func interact() -> void:
	if progress.room == "hall":
		if not progress.get("door_gone", false) and absf(player.x - 320) < 25 and player.y <= 282:
			progress.room = "room"
			player = Vector2(320, 390)
			remember()
	elif not progress.get("vanished", false) and GASTER_FEET.grow_individual(34, 28, 34, 53).has_point(player):
		progress.vanished = true
		vanish_time = 0.8
		remember()

func _process(delta: float) -> void:
	vanish_time = maxf(0, vanish_time - delta)
	if menu.is_empty() and message.is_empty() and vanish_time <= 0:
		var direction := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
		moving = direction != Vector2.ZERO
		if moving:
			walk_time += delta
			if direction.y < 0: facing = "up"
			elif direction.y > 0: facing = "down"
			elif direction.x < 0: facing = "left"
			else: facing = "right"
			move_player(direction.normalized() * 120 * delta)
	else: moving = false
	queue_redraw()

# Player position is the feet, with a small footprint rather than the full body.
const FOOT_HALF := Vector2(10, 5)
const GASTER_RECT := Rect2(303, 146, 34, 76)
const GASTER_FEET := Rect2(307, 193, 26, 29)

func can_stand(at: Vector2) -> bool:
	var feet := Rect2(at - FOOT_HALF, FOOT_HALF * 2)
	if progress.room == "hall":
		return at.y >= 267 and at.y <= 337
	# Every footprint corner must fit inside the union of the two floor regions.
	for corner in [feet.position, Vector2(feet.end.x, feet.position.y), feet.end, Vector2(feet.position.x, feet.end.y)]:
		var in_top: bool = corner.x >= 200 and corner.x <= 440 and corner.y >= 139 and corner.y <= 259
		var in_stem: bool = corner.x >= 290 and corner.x <= 350 and corner.y >= 139 and corner.y <= 437
		if not in_top and not in_stem: return false
	return progress.get("vanished", false) or not feet.intersects(GASTER_FEET)

func move_player(offset: Vector2) -> void:
	# Small steps prevent tunneling through Gaster or skipping a doorway.
	var steps := maxi(1, ceili(offset.length() / 2.0))
	var step := offset / steps
	for i in steps:
		var next_x := player + Vector2(step.x, 0)
		if can_stand(next_x): player = next_x
		var next_y := player + Vector2(0, step.y)
		if can_stand(next_y): player = next_y
		if progress.room == "hall":
			if player.x < 0 or player.x > 640:
				remember()
				exited.emit()
				return
			if not progress.get("door_gone", false) and absf(player.x - 320) < 19 and step.y < 0 and player.y <= 269:
				progress.room = "room"
				player = Vector2(320, 390)
				remember()
				return
		elif player.y > 419 and absf(player.x - 320) < 28:
			progress.room = "hall"
			progress.door_gone = true
			player = Vector2(320, 286)
			remember()
			return

func draw_gaster() -> void:
	var texture := idle if not progress.get("vanished", false) else reaction
	var sprite_size := texture.get_size() * (76.0 / idle.get_height())
	var rect := Rect2(Vector2(320 - sprite_size.x / 2, 222 - sprite_size.y), sprite_size)
	var opacity := 1.0 if not progress.get("vanished", false) else minf(1, vanish_time * 2)
	draw_texture_rect(texture, rect, false, Color(1, 1, 1, opacity))

func text_at(at: Vector2, value: String, size := 20, color := Color.WHITE) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func border(rect: Rect2) -> void:
	draw_rect(rect, Color.BLACK)
	draw_rect(rect, Color.WHITE, false, 3)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 480), Color.BLACK)
	if progress.room == "hall":
		# Texture regions avoid the baked-in player and leave the door removable.
		draw_texture_rect_region(hallway_reference, Rect2(0, 125, 320, 134), Rect2(0, 30, 310, 154))
		draw_texture_rect_region(hallway_reference, Rect2(320, 125, 320, 134), Rect2(394, 30, 344, 154))
		draw_texture_rect_region(hallway_reference, Rect2(0, 259, 640, 93), Rect2(70, 191, 668, 100))
		if not progress.get("door_gone", false):
			draw_texture_rect_region(hallway_reference, Rect2(284, 164, 72, 99), Rect2(311, 74, 83, 114))
	else:
		draw_rect(Rect2(200, 139, 240, 120), Color("#a3a3a3"))
		draw_rect(Rect2(290, 259, 60, 173), Color("#a3a3a3"))
		# Sort by feet so walking behind Gaster draws the player behind him.
		if player.y < GASTER_RECT.end.y:
			draw_frisk()
			if not progress.get("vanished", false) or vanish_time > 0: draw_gaster()
		else:
			if not progress.get("vanished", false) or vanish_time > 0: draw_gaster()
			draw_frisk()
	if progress.room == "hall": draw_frisk()
	if not menu.is_empty(): draw_menu()
	if not message.is_empty():
		border(Rect2(30, 340, 580, 112))
		text_at(Vector2(50, 383), message, 20)

func frisk_frame() -> Rect2:
	var frame := int(walk_time * 6) % 4 if moving else 0
	# Side movement uses two frames each: left then right in the second row.
	var origin := Vector2(1, 2)
	match facing:
		"left":
			origin = Vector2(1, 35)
			frame %= 2
		"right":
			origin = Vector2(47, 35)
			frame %= 2
		"up": origin = Vector2(1, 68)
	return Rect2(origin + Vector2(frame * 23, 0), Vector2(22, 31))

func draw_frisk() -> void:
	draw_texture_rect_region(frisk_sheet, Rect2(player.round() - Vector2(16, 46), Vector2(33, 46.5)), frisk_frame())

func draw_menu() -> void:
	border(Rect2(28, 28, 180, 120))
	text_at(Vector2(44, 58), str(profile.get("name", "Frisk")))
	text_at(Vector2(44, 88), "LV %d   HP %d/%d" % [profile.get("lv", 1), profile.get("hp", 20), profile.get("max_hp", 20)], 17)
	text_at(Vector2(44, 120), "G %d" % profile.get("gold", 0), 17)
	border(Rect2(28, 161, 180, 142))
	for i in 3:
		text_at(Vector2(66, 194 + i * 38), ["ITEM", "STAT", "CELL"][i])
		if menu == "main" and selection == i: text_at(Vector2(42, 194 + i * 38), "♥", 20, Color.RED)
	if menu != "main":
		border(Rect2(226, 28, 384, 287))
		if menu == "stat":
			var lines := [str(profile.get("name", "Frisk")), "LV %d" % profile.get("lv", 1), "HP %d / %d" % [profile.get("hp", 20), profile.get("max_hp", 20)], "AT %d   DF %d" % [profile.get("attack", 0), profile.get("defense", 0)], "EXP %d    NEXT %d" % [profile.get("exp", 0), profile.get("next", 10)], "WEAPON: " + str(profile.get("weapon", "Stick")), "ARMOR: " + str(profile.get("armor", "Bandage")), "GOLD: %d" % profile.get("gold", 0)]
			for i in lines.size(): text_at(Vector2(244, 57 + i * 31), lines[i], 18)
		elif menu == "items":
			var items: Array = profile.get("items", [])
			if items.is_empty(): text_at(Vector2(250, 65), "* Empty", 20)
			for i in mini(8, items.size()):
				text_at(Vector2(264, 59 + i * 30), str(items[i]), 18)
				if selection == i: text_at(Vector2(240, 59 + i * 30), "♥", 18, Color.RED)
		else: text_at(Vector2(250, 65), "* Call", 20)
