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
	_build_instructions_flash()

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
	# They've found it — stop mid-flash if one's playing and push the next
	# occasional flash further out, rather than nagging right after a click.
	_stop_instructions_flash()
	_schedule_instructions_flash()


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

	_build_logo_watermark()

	if bg:
		bg.color = Color(0.02, 0.03, 0.05, 0.5)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE


# -------------------------------------------------------
# Faint, oversized logo watermark sitting between the
# background art and the dark scrim (so the scrim dims it
# a little further, on top of its own low alpha) — big
# enough to read as a deliberate background flourish, not
# so bright it competes with the title/buttons on top.
# -------------------------------------------------------
func _build_logo_watermark() -> void:
	var texture = load("res://UI/MainMenu/orbital_drop_logo.png")
	if texture == null:
		return

	var logo_rect := TextureRect.new()
	logo_rect.name = "LogoWatermark"
	logo_rect.texture = texture
	logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Faint — the scrim (added right after this) dims it further still.
	logo_rect.modulate = Color(1.0, 1.0, 1.0, 0.24)

	# Large centred box — the logo image is 2048x1024 (2:1), so a
	# 1700x850 box keeps that aspect ratio while filling most of the
	# screen behind the title/buttons.
	logo_rect.set_anchors_preset(Control.PRESET_CENTER)
	logo_rect.offset_left = -850
	logo_rect.offset_right = 850
	logo_rect.offset_top = -425
	logo_rect.offset_bottom = 425

	add_child(logo_rect)
	move_child(logo_rect, 1)


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
#
# Icons are real textures (UI/Icons/), not emoji glyphs baked into the
# button text — the project's default font doesn't cover those emoji
# codepoints, and the web/itch.io export has no OS-level font fallback
# the way the desktop editor does, so ▶ ⚙ 📖 ✕ were rendering as "tofu"
# boxes with the raw codepoint printed inside instead of the glyph.
# -------------------------------------------------------
func _style_buttons() -> void:
	var vbox := play_btn.get_parent()
	if vbox:
		vbox.add_theme_constant_override("separation", 14)

	play_btn.text = "  PLAY"
	settings_btn.text = "  SETTINGS"
	instructions_btn.text = "  INSTRUCTIONS"
	exit_btn.text = "  EXIT"

	play_btn.icon         = load("res://UI/Icons/icon_play.png")
	settings_btn.icon     = load("res://UI/Icons/icon_settings.png")
	instructions_btn.icon = load("res://UI/Icons/icon_instructions.png")
	exit_btn.icon         = load("res://UI/Icons/icon_exit.png")

	for b in [play_btn, settings_btn, instructions_btn, exit_btn]:
		b.custom_minimum_size = Vector2(280, 0)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_constant_override("icon_max_width", 20)
		b.expand_icon = false

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
# Corner comms ticker — instead of a static credit line,
# a short line of in-universe mission-control chatter sits
# in the same spot and quietly fades to a different line
# every so often, like a live channel murmuring in the
# background of the command centre.
# -------------------------------------------------------
const _TICKER_LINES: Array[String] = [
	"Comms check... all consoles green.",
	"Command Throne standing by.",
	"Holo-Map uplink stable.",
	"Reinforcement pods fuelled and ready.",
	"Orbital net status: nominal.",
	"Awaiting your orders, Commander.",
	"Vox-Caster channel clear.",
	"Squad telemetry synced.",
	"Logistics pool nominal.",
	"Drop trajectory locked in.",
]

var _ticker_label: Label = null
var _ticker_timer: Timer = null
var _ticker_last_index: int = -1

func _build_footer() -> void:
	_ticker_label = Label.new()
	_ticker_label.text = _next_ticker_line()
	_ticker_label.add_theme_font_size_override("font_size", 12)
	_ticker_label.add_theme_color_override("font_color", Color(0.45, 0.52, 0.58))
	_ticker_label.anchor_left = 1.0
	_ticker_label.anchor_top = 1.0
	_ticker_label.anchor_right = 1.0
	_ticker_label.anchor_bottom = 1.0
	_ticker_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ticker_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ticker_label.offset_left = -420
	_ticker_label.offset_top = -28
	_ticker_label.offset_right = -16
	_ticker_label.offset_bottom = -8
	_ticker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ticker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ticker_label)

	_ticker_timer = Timer.new()
	_ticker_timer.wait_time = 7.0
	_ticker_timer.autostart = true
	_ticker_timer.timeout.connect(_on_ticker_timeout)
	add_child(_ticker_timer)


func _next_ticker_line() -> String:
	if _TICKER_LINES.size() <= 1:
		return _TICKER_LINES[0]
	var idx := randi() % _TICKER_LINES.size()
	while idx == _ticker_last_index:
		idx = randi() % _TICKER_LINES.size()
	_ticker_last_index = idx
	return _TICKER_LINES[idx]


func _on_ticker_timeout() -> void:
	if not _ticker_label:
		return
	var tween := create_tween()
	tween.tween_property(_ticker_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): _ticker_label.text = _next_ticker_line())
	tween.tween_property(_ticker_label, "modulate:a", 1.0, 0.6)


# -------------------------------------------------------
# Occasional Instructions-button flash — a first-time player has no reason
# to click "INSTRUCTIONS" before "PLAY", so every so often the button
# gives itself a quick amber pulse + scale bump to catch the eye without
# being an annoying constant animation. Timing is randomised per-cycle
# (rather than a fixed repeating Timer) so it reads as an occasional
# "notice me" nudge instead of a metronome. Reuses the same
# create_tween()-driven approach as the footer ticker fade above.
# -------------------------------------------------------
const _INSTRUCTIONS_FLASH_MIN_WAIT: float = 4.0
const _INSTRUCTIONS_FLASH_MAX_WAIT: float = 7.0

var _instructions_flash_timer: Timer = null
var _instructions_flash_tween: Tween = null

func _build_instructions_flash() -> void:
	if instructions_btn == null:
		return
	call_deferred("_update_instructions_pivot")

	_instructions_flash_timer = Timer.new()
	_instructions_flash_timer.one_shot = true
	_instructions_flash_timer.timeout.connect(_on_instructions_flash_timeout)
	add_child(_instructions_flash_timer)
	_schedule_instructions_flash()


func _update_instructions_pivot() -> void:
	if instructions_btn:
		instructions_btn.pivot_offset = instructions_btn.size / 2.0


func _schedule_instructions_flash() -> void:
	if _instructions_flash_timer == null:
		return
	_instructions_flash_timer.start(randf_range(_INSTRUCTIONS_FLASH_MIN_WAIT, _INSTRUCTIONS_FLASH_MAX_WAIT))


func _on_instructions_flash_timeout() -> void:
	_flash_instructions_btn()
	_schedule_instructions_flash()


func _stop_instructions_flash() -> void:
	if _instructions_flash_tween and _instructions_flash_tween.is_valid():
		_instructions_flash_tween.kill()
	if instructions_btn:
		instructions_btn.modulate = Color(1, 1, 1, 1)
		instructions_btn.scale = Vector2.ONE


func _flash_instructions_btn() -> void:
	if instructions_btn == null or not is_instance_valid(instructions_btn):
		return
	instructions_btn.pivot_offset = instructions_btn.size / 2.0

	if _instructions_flash_tween and _instructions_flash_tween.is_valid():
		_instructions_flash_tween.kill()

	var glow := Color(1.5, 1.3, 0.65, 1.0)
	var rest := Color(1, 1, 1, 1)

	_instructions_flash_tween = create_tween()
	_instructions_flash_tween.set_trans(Tween.TRANS_SINE)
	for i in range(2):
		_instructions_flash_tween.tween_property(instructions_btn, "modulate", glow, 0.18)
		_instructions_flash_tween.parallel().tween_property(instructions_btn, "scale", Vector2(1.06, 1.06), 0.18)
		_instructions_flash_tween.tween_property(instructions_btn, "modulate", rest, 0.24)
		_instructions_flash_tween.parallel().tween_property(instructions_btn, "scale", Vector2.ONE, 0.24)
