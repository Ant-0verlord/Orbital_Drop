extends Node
# =============================================================
# SettingsManager.gd — AutoLoad singleton
# Handles audio bus volumes and persistence to disk.
# =============================================================

const SETTINGS_PATH := "user://settings.cfg"

var master_volume: float = 1.0
var music_volume:  float = 1.0
var sfx_volume:    float = 1.0

func _ready() -> void:
	load_settings()
	_apply_all()

func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_bus("Master", master_volume)
	save_settings()

func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_apply_bus("Music", music_volume)
	save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_bus("SFX", sfx_volume)
	save_settings()

func _apply_all() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)

func _apply_bus(bus_name: String, linear_value: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return  # bus doesn't exist — skip silently
	var db = linear_to_db(max(linear_value, 0.0001))
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, linear_value <= 0.0)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(SETTINGS_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	if err != OK:
		return  # no save file yet — keep defaults
	master_volume = config.get_value("audio", "master", 1.0)
	music_volume  = config.get_value("audio", "music", 1.0)
	sfx_volume    = config.get_value("audio", "sfx", 1.0)
