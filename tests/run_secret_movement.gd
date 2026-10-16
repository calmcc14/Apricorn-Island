extends SceneTree
func _init() -> void: call_deferred("run")
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.open_debug()
	game.debug_gaster()
	var hall = game.secret_hall
	hall.set_process(false)
	for code in [KEY_LEFT, KEY_RIGHT]:
		hall.player = Vector2(320,300)
		hall.walk_time = 0
		key(code,true)
		hall._process(0.02)
		assert(hall.facing == ("left" if code == KEY_LEFT else "right"))
		assert(hall.player.x < 320 if code == KEY_LEFT else hall.player.x > 320)
		var first: Rect2 = hall.frisk_frame()
		hall._process(0.17)
		var second: Rect2 = hall.frisk_frame()
		assert(first != second)
		assert(first.position.x < 47 and second.position.x < 47 if code == KEY_LEFT else first.position.x >= 47 and second.position.x >= 47)
		key(code,false)
		hall._process(0.02)
		assert(not hall.moving)
	hall.player = Vector2(320,300)
	key(KEY_UP,true)
	for i in 25: hall._process(1.0/60.0)
	key(KEY_UP,false)
	assert(hall.progress.room == "room")
	assert(hall.idle.resource_path == "res://assets/gaster_idle.webp")
	# Walls slide without teleporting the player into the narrow stem.
	hall.player = Vector2(250, 250)
	hall.move_player(Vector2(0, 100))
	assert(hall.player == Vector2(250, 254))
	hall.move_player(Vector2(70, 0))
	hall.move_player(Vector2(0, 80))
	assert(hall.player == Vector2(320, 334))
	# A large movement cannot tunnel through Gaster's footprint.
	hall.player = Vector2(320, 260)
	hall.move_player(Vector2(0, -120))
	assert(hall.player.y >= 227 and hall.player.y <= 229)
	# The player can walk around and behind him, with the same wall footprint.
	hall.move_player(Vector2(-50, 0))
	hall.move_player(Vector2(0, -80))
	assert(hall.player.y >= 144 and hall.player.y < 160)
	assert(not hall.can_stand(Vector2(320, 202)))
	assert(not hall.can_stand(Vector2(320, 193)))
	assert(hall.can_stand(Vector2(320, 187)))
	assert(not hall.can_stand(Vector2(205, 180)))
	assert(not hall.can_stand(Vector2(295, 300)))
	assert(hall.can_stand(Vector2(300, 300)))
	hall.progress.vanished = true
	assert(hall.can_stand(Vector2(320, 216)))
	# Interaction works beside every face of the hitbox, regardless of facing.
	for position in [Vector2(320, 187), Vector2(320, 228), Vector2(295, 207), Vector2(345, 207)]:
		for direction in ["up", "down", "left", "right"]:
			hall.progress.vanished = false
			hall.player = position
			hall.facing = direction
			hall.interact()
			assert(hall.progress.vanished)
	for position in [Vector2(250, 207), Vector2(390, 207), Vector2(320, 145), Vector2(320, 300)]:
		hall.progress.vanished = false
		hall.player = position
		hall.interact()
		assert(not hall.progress.vanished)
	# Sprite backgrounds are transparent without a material on the whole room.
	assert(hall.material == null)
	assert(hall.frisk_sheet.get_image().get_pixel(646, 436).a == 0)
	game.exit_secret_hall()
	print("Physical left/right input, animated frames, release, walk-in door and resting sprite passed.")
	quit()
