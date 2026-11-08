extends Node
## Player options (autoload "Settings"), stored in user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

var first_person := false
var invert_pitch := false
var music_volume := 0.7
var sfx_volume := 0.9
var dev_mode := false


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		first_person = cf.get_value("view", "first_person", false)
		invert_pitch = cf.get_value("controls", "invert_pitch", false)
		music_volume = cf.get_value("audio", "music", 0.7)
		sfx_volume = cf.get_value("audio", "sfx", 0.9)
		dev_mode = cf.get_value("dev", "enabled", false)


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("view", "first_person", first_person)
	cf.set_value("controls", "invert_pitch", invert_pitch)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("dev", "enabled", dev_mode)
	cf.save(PATH)
	changed.emit()


func set_value(key: String, v) -> void:
	set(key, v)
	save()
