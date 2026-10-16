extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var hall = load("res://scripts/secret_hall.gd").new()
	hall.progress = {"room":"hall"}
	root.add_child(hall)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(440,280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Control.new()
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.material = hall.material
	viewport.add_child(canvas)
	var frames: Array = []
	for direction in ["left","right"]:
		hall.facing = direction
		hall.moving = true
		for i in 4:
			hall.walk_time = i / 6.0
			frames.append(hall.frisk_frame())
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(0,0,440,280),Color("#333333"))
		for i in 8:
			canvas.draw_texture_rect_region(hall.frisk_sheet,Rect2(10+(i%4)*105,10+floori(float(i)/4)*135,88,124),frames[i])
	)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://build/secret_side_frames.png")
	quit()
