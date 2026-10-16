extends StyleBox

var fill := Color("#8b8b8b")
var inset := true

func _init() -> void:
	content_margin_left = 6
	content_margin_right = 6
	content_margin_top = 6
	content_margin_bottom = 6

func _draw(canvas: RID, rect: Rect2) -> void:
	var light := Color("#ffffff")
	var dark := Color("#373737")
	var top := dark if inset else light
	var bottom := light if inset else dark
	RenderingServer.canvas_item_add_rect(canvas,rect,fill)
	RenderingServer.canvas_item_add_rect(canvas,Rect2(rect.position,Vector2(rect.size.x,4)),top)
	RenderingServer.canvas_item_add_rect(canvas,Rect2(rect.position,Vector2(4,rect.size.y)),top)
	RenderingServer.canvas_item_add_rect(canvas,Rect2(rect.position + Vector2(0,rect.size.y-4),Vector2(rect.size.x,4)),bottom)
	RenderingServer.canvas_item_add_rect(canvas,Rect2(rect.position + Vector2(rect.size.x-4,0),Vector2(4,rect.size.y)),bottom)
