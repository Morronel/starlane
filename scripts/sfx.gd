class_name Sfx
extends Node
## Plays the pre-rendered sound design (assets/audio, made by tools/make_audio.py)
## and crossfades between flight and station music.

const DIR := "res://assets/audio/"

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _engine: AudioStreamPlayer
var _lane: AudioStreamPlayer
var _music := {}          # name -> player
var _music_target := ""
var _lane_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Music")
	AudioServer.add_bus(2)
	AudioServer.set_bus_name(2, "SFX")
	# light compressor on SFX so explosions don't crush everything else
	var comp := AudioEffectCompressor.new()
	comp.threshold = -10.0
	comp.ratio = 3.0
	comp.attack_us = 2000.0
	comp.release_ms = 150.0
	AudioServer.add_bus_effect(2, comp)

	for f in ["laser_player", "laser_enemy", "explosion", "explosion_big", "hit_shield", "hit_hull",
			"engine_loop", "lane_loop", "lane_enter", "lane_exit", "boost", "jump", "ui_click", "ui_tab",
			"ui_buy", "ui_upgrade", "ui_error", "ui_open", "dock_clamp", "launch", "alarm",
			"mission_complete", "target_lock", "autofire_on", "autofire_off", "missile_launch", "loot_pickup",
			"autopilot_on", "autopilot_off", "craft", "equip", "lane_merge", "music_flight", "music_station", "music_combat",
			"radio_tune", "photo", "event_ping", "scan", "cruise_on", "kaching", "dice", "cheers",
			"music_radio_lofi", "music_radio_synth", "music_bar"]:
		var s = load(DIR + f + ".ogg")
		if s:
			if s is AudioStreamOggVorbis and (f.ends_with("_loop") or f.begins_with("music_")):
				s.loop = true
			_streams[f] = s

	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

	_engine = _looper("engine_loop", -40.0)
	_lane = _looper("lane_loop", -60.0)
	for m in ["music_flight", "music_station", "music_combat", "music_radio_lofi", "music_radio_synth", "music_bar"]:
		var p := AudioStreamPlayer.new()
		p.stream = _streams.get(m)
		p.bus = "Music"
		p.volume_db = -60.0
		add_child(p)
		_music[m] = p
	apply_volumes()
	Settings.changed.connect(apply_volumes)


func _looper(name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _streams.get(name)
	p.volume_db = db
	p.bus = "SFX"
	add_child(p)
	p.play()
	return p


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(1, linear_to_db(maxf(Settings.music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(2, linear_to_db(maxf(Settings.sfx_volume, 0.0001)))


func play(name: String, db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = _streams[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## 0.12 radio: what plays while you fly. Ambient gets a per-system key.
const RADIO := [
	{"name": "Starlane Ambient", "track": "music_flight", "dj": ["...and now, the sound of a very large, very quiet universe.", "Ambient hour. Breathe in. Breathe out. Mind the exits.", "This one goes out to everyone hauling ice tonight."]},
	{"name": "Lane FM", "track": "music_radio_lofi", "dj": ["Lane FM: lofi beats to haul cargo to.", "You're on Lane FM. Traffic on the loop is smooth, so's this.", "Lane FM. Tip your bartender, check your fuel, stay cozy."]},
	{"name": "Neon Drift", "track": "music_radio_synth", "dj": ["NEON DRIFT! Sunglasses on, shields up.", "Neon Drift, all synth, all night, all the way round the loop.", "This is Neon Drift. If you can read this, you're cruising."]},
	{"name": "Radio off", "track": "", "dj": ["Static... and the hum of your own engines."]},
]
var flight_pitch := 1.0


func music(name: String) -> void:
	if name == "flight":
		var ch: Dictionary = RADIO[clampi(Settings.radio, 0, RADIO.size() - 1)]
		_music_target = ch["track"]
	else:
		_music_target = "music_" + name
	var p: AudioStreamPlayer = _music.get(_music_target)
	if p and not p.playing:
		p.pitch_scale = flight_pitch if _music_target == "music_flight" else 1.0
		p.play()


## Next radio channel; returns its DJ line.
func next_radio() -> String:
	Settings.set_value("radio", (Settings.radio + 1) % RADIO.size())
	play("radio_tune", -6.0)
	var ch: Dictionary = RADIO[Settings.radio]
	var lines: Array = ch["dj"]
	return "%s  ·  %s" % [ch["name"].to_upper(), lines[randi() % lines.size()]]


func _process(delta: float) -> void:
	for k in _music:
		var p: AudioStreamPlayer = _music[k]
		var on_db := -9.5 if k == "music_combat" else (-8.0 if k.begins_with("music_radio") else -6.0)
		var target := on_db if k == _music_target else -60.0
		# combat kicks in fast, everything else drifts
		var up_rate := 40.0 if k == "music_combat" else 14.0
		p.volume_db = move_toward(p.volume_db, target, delta * (up_rate if target > p.volume_db else 16.0))
		if p.volume_db <= -59.0 and p.playing and k != _music_target:
			p.stop()
	_lane.volume_db = move_toward(_lane.volume_db, -8.0 if _lane_active else -60.0, delta * 40.0)


# --- game events ---------------------------------------------------------------

func laser(team: int, dist: float) -> void:
	var name := "laser_player" if team == 0 else "laser_enemy"
	play(name, (-7.0 if team == 0 else -6.0) - clampf(dist / 90.0, 0.0, 24.0), randf_range(0.94, 1.06))


func boom(dist: float, big := false) -> void:
	play("explosion_big" if big else "explosion", -1.0 - clampf(dist / 160.0, 0.0, 22.0), randf_range(0.9, 1.08))


func hit(on_shield: bool) -> void:
	play("hit_shield" if on_shield else "hit_hull", -4.0, randf_range(0.95, 1.05))


func ui(kind := "click") -> void:
	play("ui_" + kind, -6.0 if kind == "click" else -3.0)


func lane(on: bool) -> void:
	_lane_active = on
	play("lane_enter" if on else "lane_exit", -2.0)


func engine(ratio: float, active: bool) -> void:
	var target_db := -16.0 + clampf(ratio, 0.0, 3.0) * 3.5 if active else -50.0
	_engine.volume_db = lerpf(_engine.volume_db, target_db, 0.06)
	_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.75 + clampf(ratio, 0.0, 4.0) * 0.22, 0.05)
