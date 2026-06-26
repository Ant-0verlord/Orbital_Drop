extends Control
# =============================================================
# MainMenu.gd
# =============================================================

@onready var play_btn: Button       = $VBoxContainer/PlayBtn
@onready var settings_btn: Button   = $VBoxContainer/SettingsBtn
@onready var exit_btn: Button       = $VBoxContainer/ExitBtn

@onready var settings_panel: PanelContainer = $SettingsOverlay/SettingsPanel
@onready var master_slider: HSlider = $SettingsOverlay/SettingsPanel/VBoxContainer/MasterRow/MasterSlider
@onready var music_slider: HSlider  = $SettingsOverlay/SettingsPanel/VBoxContainer/MusicRow/MusicSlider
@onready var sfx_slider: HSlider    = $SettingsOverlay/SettingsPanel/VBoxContainer/SFXRow/SFXSlider
@onready var settings_close_btn: Button = $SettingsOverlay/SettingsPanel/VBoxContainer/SettingsCloseBtn
@onready var settings_overlay: ColorRect = $SettingsOverlay


func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	settings_close_btn.pressed.connect(_on_settings_close_pressed)

	master_slider.value_changed.connect(SettingsManager.set_master_volume)
	music_slider.value_changed.connect(SettingsManager.set_music_volume)
	sfx_slider.value_changed.connect(SettingsManager.set_sfx_volume)

	master_slider.value = SettingsManager.master_volume
	music_slider.value  = SettingsManager.music_volume
	sfx_slider.value    = SettingsManager.sfx_volume

	settings_overlay.visible = false


func _on_play_pressed() -> void:
	GameManager.start_campaign()
	get_tree().change_scene_to_file("res://Scenes/Command_Centre.tscn")


func _on_settings_pressed() -> void:
	settings_overlay.visible = true

func _on_settings_close_pressed() -> void:
	settings_overlay.visible = false


func _on_exit_pressed() -> void:
	get_tree().quit()
