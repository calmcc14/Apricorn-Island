extends Control

signal closed

const INK := Color("#244956")
const TEAL := Color("#159c9c")
const STATS := ItemMechanics.IV_STATS
const NAMES := ItemMechanics.IV_NAMES
var collection: Array = []
var pokemon_sprite: Callable
var index := 0
var tab := "Overview"
var body: VBoxContainer

class StatRadar extends Control:
	var values: Array = []
	var cap := 31.0
	func _draw() -> void:
		var center := size/2
		var radius := 102.0
		for ring in [0.25,0.5,0.75,1.0]:
			var points := PackedVector2Array()
			for i in 7: points.append(center+Vector2.from_angle(-PI/2+i*TAU/6)*radius*ring)
			draw_polyline(points,Color("#c3dddd"),1.0,true)
		var spread := PackedVector2Array()
		for i in 6:
			var direction := Vector2.from_angle(-PI/2+i*TAU/6)
			draw_line(center,center+direction*radius,Color("#c3dddd"),1.0,true)
			spread.append(center+direction*radius*maxf(0.025,float(values[i])/cap))
			var pos := center+direction*(radius+26)-Vector2(36,-5)
			draw_string(ThemeDB.fallback_font,pos,ItemMechanics.IV_NAMES[i],HORIZONTAL_ALIGNMENT_CENTER,72,15,Color("#244956"))
		draw_colored_polygon(spread,Color(0.08,0.65,0.64,0.32))
		var outline := spread.duplicate()
		outline.append(spread[0])
		draw_polyline(outline,Color("#159c9c"),3.0,true)
		for point in spread: draw_circle(point,4,Color("#159c9c"))

func label(parent: Node, text: String, font_size := 18, color := INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

func button(parent: Node, text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func panel(rect: Rect2) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.position = rect.position
	frame.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f9fdfc")
	style.border_color = Color("#c7e4df")
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	frame.add_theme_stylebox_override("panel",style)
	add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	frame.add_child(content)
	return content

func setup(pokemon: Array, resolve_sprite: Callable, selected: int) -> void:
	collection = pokemon
	pokemon_sprite = resolve_sprite
	index = clampi(selected,0,collection.size()-1)
	rebuild()

func browse(direction: int) -> void:
	index = posmod(index+direction,collection.size())
	rebuild()

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var pokemon: Dictionary = collection[index]
	ItemMechanics.initialize(pokemon)
	var species: Dictionary = GameData.SPECIES[pokemon.species]
	var header := panel(Rect2(16,16,448,266))
	var row := HBoxContainer.new()
	header.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(info,str(species.name),28)
	var details := "Lv.%d  •  %s" % [pokemon.level,str(pokemon.gender).capitalize()]
	if pokemon.get("shiny", false): details += "  •  ★ Shiny"
	label(info,details,18)
	var art := TextureRect.new()
	art.name = "PokemonPortrait"
	art.texture = pokemon_sprite.call(pokemon)
	art.custom_minimum_size = Vector2(124,132)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(art)
	row.add_child(info)
	var types: Array = ItemMechanics.species(pokemon).get("types",[species.type])
	label(info," / ".join(types).to_upper(),17,TEAL)
	label(info,"HP  %d / %d" % [pokemon.hp,pokemon.max_hp],20)
	var hp := ProgressBar.new()
	hp.max_value = pokemon.max_hp
	hp.value = pokemon.hp
	hp.show_percentage = false
	hp.custom_minimum_size.y = 12
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color("#53b990")
	hp_fill.set_corner_radius_all(6)
	hp.add_theme_stylebox_override("fill",hp_fill)
	info.add_child(hp)
	label(info,str(ItemMechanics.level_progress(pokemon).label),15)
	var navigation := HBoxContainer.new()
	header.add_child(navigation)
	button(navigation,"Back",func(): closed.emit())
	button(navigation,"←",browse.bind(-1)).disabled = collection.size() < 2
	label(navigation,"%d / %d" % [index+1,collection.size()],18).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(navigation,"→",browse.bind(1)).disabled = collection.size() < 2
	var details_panel := panel(Rect2(16,294,448,590))
	var tabs := HBoxContainer.new()
	details_panel.add_child(tabs)
	for title in ["Overview","Stats","IV Judge","Moves"]:
		var choice := button(tabs,title,func(): tab = title; rebuild())
		choice.add_theme_font_size_override("font_size",16)
		if title == tab: choice.modulate = Color("#a3e8dc")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_panel.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",16)
	scroll.add_child(body)
	match tab:
		"Overview": overview(pokemon)
		"Stats": stats(pokemon,false)
		"IV Judge": stats(pokemon,true)
		"Moves": moves(pokemon)

func overview(pokemon: Dictionary) -> void:
	label(body,"Meet your Pokémon",30)
	label(body,"Every Pokémon has its own six-stat IV spread. Check IV Judge to see its natural strengths.",20)
	var held := str(pokemon.get("held_item",""))
	var info := [
		["Nature",str(pokemon.nature).capitalize()],
		["Held item",str(GameData.ITEMS.get(held,{"name":held}).name) if held != "" else "None"],
		["Friendship","%d / 255" % int(pokemon.friendship)],
		["Condition","Fainted" if int(pokemon.hp) <= 0 else MoveEffects.status_label(pokemon) if str(pokemon.get("status_condition","")) != "" else "Healthy"],
		["Total EXP",str(pokemon.experience)],
		["Next level",str(ItemMechanics.level_progress(pokemon).label)]
	]
	for entry in info:
		var row := HBoxContainer.new()
		body.add_child(row)
		label(row,str(entry[0]),19,TEAL)
		label(row,str(entry[1]),19)

func stats(pokemon: Dictionary, judge: bool) -> void:
	label(body,"Individual values" if judge else "Battle stats",30)
	label(body,"IVs are fixed natural potential, from 0 to 31 per stat." if judge else "Current stats include level growth, IV bonuses and expedition upgrades.",18)
	var radar := StatRadar.new()
	radar.custom_minimum_size = Vector2(320,285)
	var values: Array = []
	for stat_name in STATS: values.append(int(pokemon.ivs[stat_name]) if judge else int(pokemon.get("max_hp" if stat_name == "hp" else stat_name,0)))
	radar.values = values
	if not judge: radar.cap = maxf(1,float(values.max()))
	body.add_child(radar)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",16)
	body.add_child(grid)
	for heading in (["Stat","IV","Judge"] if judge else ["Stat","Value","EV"]): label(grid,heading,17,TEAL)
	var total := 0
	for i in 6:
		var iv := int(pokemon.ivs[STATS[i]])
		total += iv
		label(grid,NAMES[i],18)
		label(grid,"%d / 31" % iv if judge else str(values[i]),18)
		label(grid,("Hyper trained (IV %d)" % iv if pokemon.get("hyper_trained",{}).get(STATS[i],false) else ItemMechanics.iv_judgment(iv)) if judge else str(pokemon.evs.get(STATS[i],0)),17,TEAL if iv == 31 else INK)
	if judge:
		var spread: Array[String] = []
		for stat_name in STATS: spread.append(str(int(pokemon.ivs[stat_name])))
		label(body,"IV spread  •  " + " / ".join(spread),21,TEAL)
		label(body,"HP / Atk / Def / Sp. Atk / Sp. Def / Speed   •   Total %d / 186" % total,16)
		label(body,"Higher IVs give larger stat bonuses as you level up. IVs stay with a Pokémon when you catch it, swap it, or save your game.",18)
	else:
		label(body,"EVs show training earned in battles. The chart compares this Pokémon’s current stats.",18)

func moves(pokemon: Dictionary) -> void:
	label(body,"Moves",30)
	for move_id in pokemon.moves:
		var move: Dictionary = GameData.MOVES[move_id]
		label(body,str(move.name),23,TEAL)
		var accuracy := float(move.get("accuracy",1.0))
		var accuracy_text := "%d%%" % int(round(accuracy*100)) if accuracy <= 1 else "%d%%" % int(accuracy)
		label(body,"%s  •  PP %d / %d  •  Power %s  •  Accuracy %s" % [str(move.get("type","normal")).capitalize(),int(pokemon.pp.get(move_id,move.get("pp",35))),int(move.get("pp",35)),str(move.get("power","—")),accuracy_text],18)
