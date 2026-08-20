extends Control
# =============================================================
# MainMenu.gd
# =============================================================

@onready var bg: ColorRect          = $BG
@onready var title_label: Label     = $VBoxContainer/TitleLabel
@onready var play_btn: Button       = $VBoxContainer/PlayBtn
@onready var settings_btn: Button   = $VBoxContainer/SettingsBtn
@onready var instructions_btn: Button = $VBoxContainer/InstructionsBtn
@onready var exit_btn: Button       = $VBoxContainer/ExitBtn

@onready var settings_panel: PanelContainer = $SettingsOverlay/SettingsPanel
@onready var master_slider: HSlider = $SettingsOverlay/SettingsPanel/VBoxContainer/MasterRow/MasterSlider
@onready var music_slider: HSlider  = $SettingsOverlay/SettingsPanel/VBoxContainer/MusicRow/MusicSlider
@onready var sfx_slider: HSlider    = $SettingsOverlay/SettingsPanel/VBoxContainer/SFXRow/SFXSlider
@onready var settings_close_btn: Button = $SettingsOverlay/SettingsPanel/VBoxContainer/SettingsCloseBtn
@onready var settings_overlay: ColorRect = $SettingsOverlay

# Board-game-style field manual — reachable before a campaign is even
# started, unlike the Help/Guide systems which only exist in-mission.
@onready var instructions_popup: Control = $InstructionsOverlay


func _ready() -> void:
	_build_background()
	_style_title()
	_style_buttons()
	_build_footer()

	play_btn.pressed.connect(_on_play_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	instructions_btn.pressed.connect(_on_instructions_pressed)
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


func _on_instructions_pressed() -> void:
	instructions_popup.open()


func _on_exit_pressed() -> void:
	get_tree().quit()


# -------------------------------------------------------
# Animated backdrop — the generated orbital-approach image
# (stars, planet horizon, hex-grid battlefield, drop-pod
# trail) with a shader on top for the twinkle/glow/wave
# animation. The old plain BG ColorRect becomes a soft dark
# scrim over it so menu text stays legible.
# -------------------------------------------------------
func _build_background() -> void:
	var texture = load("res://UI/MainMenu/menu_bg.png")
	if texture == null:
		return

	var bg_rect := TextureRect.new()
	bg_rect.texture = texture
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.anchor_right = 1.0
	bg_rect.anchor_bottom = 1.0
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = load("res://Shaders/MenuBackground.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		bg_rect.material = mat

	add_child(bg_rect)
	move_child(bg_rect, 0)

	if bg:
		bg.color = Color(0.02, 0.03, 0.05, 0.5)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE


# -------------------------------------------------------
# Big glowing title + tagline, matching the amber/dark
# palette used everywhere else. Godot's font outline is
# reused here as a cheap glow halo around the title text.
# -------------------------------------------------------
func _style_title() -> void:
	if not title_label:
		return
	title_label.text = "ORBITAL DROP"
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	title_label.add_theme_color_override("font_outline_color", Color(1.0, 0.851, 0.2, 0.55))
	title_label.add_theme_constant_override("outline_size", 10)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var parent := title_label.get_parent()

	var tagline := Label.new()
	tagline.text = "Command five consoles. Hold the line. Bring them home."
	tagline.add_theme_font_size_override("font_size", 15)
	tagline.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(tagline)
	parent.move_child(tagline, title_label.get_index() + 1)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 26
	parent.add_child(spacer)
	parent.move_child(spacer, tagline.get_index() + 1)


# -------------------------------------------------------
# Icon-prefixed, evenly-sized menu buttons, with Play given
# the same filled amber "primary CTA" treatment used across
# the console popups.
# -------------------------------------------------------
func _style_buttons() -> void:
	var vbox := play_btn.get_parent()
	if vbox:
		vbox.add_theme_constant_override("separation", 14)

	play_btn.text = "▶  PLAY"
	settings_btn.text = "⚙  SETTINGS"
	instructions_btn.text = "📖  INSTRUCTIONS"
	exit_btn.text = "✕  EXIT"

	for b in [play_btn, settings_btn, instructions_btn, exit_btn]:
		b.custom_minimum_size = Vector2(280, 0)
		b.add_theme_font_size_override("font_size", 16)

	_style_primary_button(play_btn)


func _style_primary_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.275, 0.216, 0.039, 1.0)
	normal.border_color = Color(1.0, 0.851, 0.2, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10

	var hover := normal.duplicate()
	hover.bg_color = Color(0.35, 0.275, 0.05, 1.0)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.22, 0.17, 0.03, 1.0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(1.0, 0.851, 0.2))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))


# -------------------------------------------------------
# Small corner credit line — a tasteful, non-intrusive
# detail for an assessment build.
# -------------------------------------------------------
func _build_footer() -> void:
	var footer := Label.new()
	footer.text = "Year 12 Digital Technology — Assessment Build"
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.42, 0.45, 0.5))
	footer.anchor_left = 1.0
	footer.anchor_top = 1.0
	footer.anchor_right = 1.0
	footer.anchor_bottom = 1.0
	footer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.offset_left = -420
	footer.offset_top = -28
	footer.offset_right = -16
	footer.offset_bottom = -8
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
