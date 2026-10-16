class_name RetroAudio
extends Node

# Original synthesized effects: pulse, triangle, and noise, with no sampled game audio.
const RATE := 22050
var clips: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var cursor := 0
var music_player := AudioStreamPlayer.new()
var music_tracks: Array[AudioStreamWAV] = []
var battle_theme := -1

func set_battle_music(active: bool, boss: bool = false) -> void:
	if not active:
		music_player.stop()
		battle_theme = -1
		return
	if battle_theme >= 0: return
	battle_theme = 2 if boss else randi_range(0, 1)
	if DisplayServer.get_name() != "headless":
		music_player.stream = music_tracks[battle_theme]
		music_player.play()

func _ready() -> void:
	music_player.volume_db = -17
	add_child(music_player)
	for track in ["wild", "rival", "guardian"]:
		var stream := load("res://assets/music/" + track + ".wav") as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2
		music_tracks.append(stream)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -12
		add_child(player)
		players.append(player)
	for name in ["select","travel","hit","fire","water","grass","electric","heal","capture","victory","defeat"]:
		clips[name] = synthesize(name)

func play_effect(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if players.is_empty() or not clips.has(name): return
	var player := players[cursor % players.size()]
	cursor += 1
	player.stream = clips[name]
	player.play()

func _exit_tree() -> void:
	music_player.stop()
	music_player.stream = null
	music_tracks.clear()
	for player in players:
		player.stop()
		player.stream = null
	clips.clear()

func synthesize(name: String) -> AudioStreamWAV:
	var notes: Array = [660.0,880.0]
	var duration := 0.12
	var noise_mix := 0.0
	match name:
		"travel": notes = [392.0,523.25,659.25]; duration = 0.24
		"hit": notes = [180.0,100.0,60.0]; duration = 0.22; noise_mix = 0.7
		"fire": notes = [240.0,180.0,90.0]; duration = 0.4; noise_mix = 0.65
		"water": notes = [330.0,494.0,392.0,587.0]; duration = 0.4; noise_mix = 0.18
		"grass": notes = [784.0,659.0,988.0]; duration = 0.32; noise_mix = 0.2
		"electric": notes = [988.0,220.0,1318.0,330.0]; duration = 0.34; noise_mix = 0.3
		"heal": notes = [523.25,659.25,783.99,1046.5]; duration = 0.65
		"capture": notes = [392.0,392.0,523.25,783.99]; duration = 0.7
		"victory": notes = [523.25,659.25,783.99,1046.5,783.99,1046.5]; duration = 1.0
		"defeat": notes = [392.0,349.23,293.66,196.0]; duration = 0.9
	var data := PackedByteArray()
	var count := int(RATE * duration)
	data.resize(count*2)
	var random := RandomNumberGenerator.new()
	random.seed = 17
	var phase := 0.0
	for i in count:
		var t := float(i)/RATE
		var note_index := mini(int(t/duration*notes.size()),notes.size()-1)
		phase = fmod(phase + float(notes[note_index])/RATE,1.0)
		var triangle: float = 1.0-4.0*absf(phase-0.5)
		var pulse := 0.6 if phase < 0.25 else -0.2
		var signal_value: float = lerp(triangle*0.5+pulse*0.5,random.randf_range(-1,1),noise_mix)
		var envelope := minf(1.0,t/0.008) * minf(1.0,(duration-t)/0.035)
		data.encode_s16(i*2,int(clamp(signal_value*envelope*24000,-32767,32767)))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = RATE
	result.data = data
	return result
