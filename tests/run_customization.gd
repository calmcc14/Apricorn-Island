extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.open_settings(game.Screen.TITLE)
	var before = game.trainer_style.profile.duplicate(true)
	game.show_character_customization()
	await process_frame
	var picks: Array[Node] = []
	collect(game.ui, picks)
	assert(picks.size() == 4)
	for picker in picks:
		picker.selected = 2
		picker.item_selected.emit(2)
	var original = game.trainer_texture.get_image()
	var changed = picks[0].get_parent().get_parent().get_child(0).texture.get_image()
	assert(original.get_data() != changed.get_data())
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/customization.png")
	game.open_settings(game.Screen.TITLE)
	assert(game.trainer_style.profile == before)
	var style = game.TrainerStyle.new()
	style.profile = {"name":"Test", "skin":4,"cap":3,"jacket":2,"trousers":1}
	assert(style.save_profile() == OK)
	var restored = game.TrainerStyle.new()
	restored.load_profile()
	assert(restored.profile == style.profile)
	game.trainer_style.profile = before
	game.trainer_style.save_profile()
	print("Trainer preview, four palettes, cancellation and profile persistence passed.")
	quit()
func collect(node: Node, found: Array[Node]) -> void:
	if node is OptionButton: found.append(node)
	for child in node.get_children(): collect(child, found)
