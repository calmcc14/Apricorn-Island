extends RefCounted

const PATH := "user://apricorn_trainer.cfg"
const OPTIONS := {
	"skin": ["Original", "Light", "Warm", "Brown", "Deep"],
	"cap": ["Original red", "Ocean blue", "Leaf green", "Plum", "Gold"],
	"jacket": ["Original teal", "Coral", "Forest", "Violet", "Cobalt"],
	"trousers": ["Original navy", "Charcoal", "Earth", "Plum", "Forest"]
}
const COLORS := {
	"skin": [Color("ffb877"), Color("ffd5ac"), Color("d99658"), Color("a96538"), Color("704129")],
	"cap": [Color("ef3d30"), Color("397ddd"), Color("44a85d"), Color("a354ba"), Color("e9b934")],
	"jacket": [Color("07818c"), Color("cf6152"), Color("42855a"), Color("8855b4"), Color("3868b9")],
	"trousers": [Color("293e71"), Color("454952"), Color("705239"), Color("604069"), Color("365947")]
}
var profile := {"name":"Trainer", "skin":0, "cap":0, "jacket":0, "trousers":0}

func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK: return
	profile.name = str(config.get_value("trainer", "name", "Trainer")).strip_edges().left(20)
	if profile.name.is_empty(): profile.name = "Trainer"
	for key in OPTIONS:
		var value = config.get_value("trainer", key, 0)
		profile[key] = clampi(int(value), 0, OPTIONS[key].size()-1) if value is int or value is float else 0

func save_profile() -> Error:
	var config := ConfigFile.new()
	for key in profile: config.set_value("trainer", key, profile[key])
	return config.save(PATH)

func make_texture() -> Texture2D:
	var original: Texture2D = load("res://assets/trainer_player.png")
	var picture := original.get_image()
	picture.resize(128,192,Image.INTERPOLATE_NEAREST)
	for y in range(picture.get_height()):
		for x in range(picture.get_width()):
			var pixel := picture.get_pixel(x,y)
			if pixel.a < 0.5 or pixel.v < 0.23 or pixel.s < 0.28: continue
			var part := ""
			if y < 43 and pixel.h < 0.055 and pixel.s > 0.6: part = "cap"
			elif y >= 68 and y < 123 and pixel.h > 0.44 and pixel.h < 0.56: part = "jacket"
			elif y >= 119 and y < 157 and pixel.h > 0.56 and pixel.h < 0.72: part = "trousers"
			elif y >= 36 and y < 112 and pixel.h > 0.035 and pixel.h < 0.115 and pixel.v > 0.52: part = "skin"
			if part.is_empty() or int(profile[part]) == 0: continue
			var base: Color = COLORS[part][0]
			var target: Color = COLORS[part][int(profile[part])]
			picture.set_pixel(x,y,Color.from_hsv(target.h, clampf(pixel.s * target.s / base.s,0,1),clampf(pixel.v * target.v / base.v,0,1),pixel.a))
	return ImageTexture.create_from_image(picture)
