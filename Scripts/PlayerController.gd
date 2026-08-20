extends CharacterBody3D
# =============================================================
# PlayerController.gd
# Attach to: CharacterBody3D (root of Player.tscn)
#
# Scene structure required:
#   CharacterBody3D  (this script)
#     CollisionShape3D
#     MeshInstance3D   (optional player body mesh)
#     Head             (Node3D, at Y = 1.7)
#       Camera3D
#         RayCast3D    (Target Position: Vector3(0, 0, -2.5), Enabled: true)
#     CanvasLayer
#       InteractLabel  (Label, text: "Press E to interact")
#
# Input Map actions required (Project > Project Settings > Input Map):
#   move_forward  — W
#   move_back     — S
#   move_left     — A
#   move_right    — D
#   interact      — E
# =============================================================

@export var move_speed: float       = 4.0
@export var mouse_sensitivity: float = 0.002
@export var interact_distance: float = 2.5

@onready var head:           Node3D   = $Head
@onready var camera:         Camera3D = $Head/Camera3D
@onready var ray:            RayCast3D = $Head/Camera3D/RayCast3D
@onready var interact_label: Label    = $CanvasLayer/InteractLabel

# Tab-menu (pause menu) — Settings + Exit, reachable mid-mission.
@onready var pause_menu:               Control = $CanvasLayer/PauseMenu
@onready var pause_resume_btn:         Button  = $CanvasLayer/PauseMenu/CenterPanel/VBoxContainer/ResumeBtn
@onready var pause_settings_btn:       Button  = $CanvasLayer/PauseMenu/CenterPanel/VBoxContainer/SettingsBtn
@onready var pause_instructions_btn:   Button  = $CanvasLayer/PauseMenu/CenterPanel/VBoxContainer/InstructionsBtn
@onready var pause_exit_btn:           Button  = $CanvasLayer/PauseMenu/CenterPanel/VBoxContainer/ExitBtn
@onready var pause_settings_overlay:   Control = $CanvasLayer/PauseMenu/SettingsOverlay
@onready var pause_settings_close_btn: Button  = $CanvasLayer/PauseMenu/SettingsOverlay/SettingsPanel/VBoxContainer/SettingsCloseBtn
@onready var pause_master_slider:      HSlider = $CanvasLayer/PauseMenu/SettingsOverlay/SettingsPanel/VBoxContainer/MasterRow/MasterSlider
@onready var pause_music_slider:       HSlider = $CanvasLayer/PauseMenu/SettingsOverlay/SettingsPanel/VBoxContainer/MusicRow/MusicSlider
@onready var pause_sfx_slider:         HSlider = $CanvasLayer/PauseMenu/SettingsOverlay/SettingsPanel/VBoxContainer/SFXRow/SFXSlider

# Board-game-style field manual — reachable mid-mission via the pause
# menu, alongside Settings. Same reusable popup the main menu shows too.
@onready var pause_instructions: Control = $CanvasLayer/PauseMenu/InstructionsOverlay

var popup_open: bool = false
var current_console     = null  # The console node currently open

var pause_menu_open: bool = false
var pause_settings_open: bool = false  # settings sub-panel within the pause menu
var pause_instructions_open: bool = false  # instructions sub-panel within the pause menu


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interact_label.visible = false

	pause_menu.visible = false
	pause_settings_overlay.visible = false

	pause_resume_btn.pressed.connect(_close_pause_menu)
	pause_settings_btn.pressed.connect(_open_pause_settings)
	pause_settings_close_btn.pressed.connect(_close_pause_settings)
	pause_instructions_btn.pressed.connect(_open_pause_instructions)
	pause_instructions.closed.connect(_on_pause_instructions_closed)
	pause_exit_btn.pressed.connect(_on_pause_exit_pressed)

	pause_master_slider.value_changed.connect(SettingsManager.set_master_volume)
	pause_music_slider.value_changed.connect(SettingsManager.set_music_volume)
	pause_sfx_slider.value_changed.connect(SettingsManager.set_sfx_volume)

	pause_master_slider.value = SettingsManager.master_volume
	pause_music_slider.value  = SettingsManager.music_volume
	pause_sfx_slider.value    = SettingsManager.sfx_volume


# Tab is handled in _input() rather than _unhandled_input(). Every popup
# in the game (Intel Console, Vox Caster, Logistics, Command Throne,
# Holo Map) is built from normal Buttons, and Godot Buttons grab keyboard
# focus by default the moment they're clicked. Tab is also the engine's
# built-in "move to next focusable Control" key — so once any button in
# an open popup has focus, a plain _unhandled_input Tab handler would
# never see the key at all; the Control focus system would eat it first
# to shift focus between buttons instead. Handling it in _input() and
# marking it handled runs before that focus-traversal step, so Tab
# reliably backs out of whatever's open no matter what has focus.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		# Tab is the one "back / menu" key for the whole game — deliberately
		# never Esc. On an itch.io (browser/iframe) build, Escape doubles as
		# the browser's "exit fullscreen" shortcut, so using it to close a
		# console popup was also kicking players out of fullscreen every
		# time. Tab has no such conflict. Steps back one level at a time:
		# console popup > pause-menu settings > pause menu > (open pause menu).
		if popup_open:
			_close_popup()
		elif pause_instructions_open:
			_close_pause_instructions()
		elif pause_settings_open:
			_close_pause_settings()
		elif pause_menu_open:
			_close_pause_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look — only when nothing (console popup or the pause menu) has
	# taken over input
	if not popup_open and not pause_menu_open and event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Open console popup
	if event.is_action_pressed("interact") and not popup_open and not pause_menu_open:
		if ray.is_colliding():
			var hit = ray.get_collider()
			if hit and hit.has_method("open_popup"):
				AudioManager.play_button_bottom()
				hit.open_popup()
				popup_open = true
				current_console = hit
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				GuideManager.set_popup_open(true)
				# _physics_process() is what normally keeps this label's
				# visibility in sync with the raycast, but it bails out
				# immediately while a popup is open (movement is locked
				# too), so it never got a chance to turn this back off.
				# It was staying visible — frozen "on" from the moment
				# right before opening the console — and rendering on
				# top of every popup's UI for as long as it stayed open,
				# including the mission debrief report screen.
				interact_label.visible = false

	# TEMPORARY DEBUG — jump to mission by number key (remove before release)
	if event is InputEventKey and event.pressed and not popup_open and not pause_menu_open:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			var mission_index = event.keycode - KEY_1
			GameManager.debug_jump_to_mission(mission_index)


func _physics_process(delta: float) -> void:
	if popup_open or pause_menu_open:
		return  # Lock movement while a popup or the pause menu is open

	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	# WASD movement relative to facing direction
	var input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back")  - Input.get_action_strength("move_forward")
	)
	var direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	move_and_slide()

	# Show/hide "Press E" label based on what the ray is hitting
	var can_interact = (
		ray.is_colliding()
		and ray.get_collider() != null
		and ray.get_collider().has_method("open_popup")
	)
	interact_label.visible = can_interact


# Called by a popup's Close button
func on_popup_closed() -> void:
	_close_popup()



func _close_popup() -> void:
	AudioManager.play_button_bottom()
	if current_console and current_console.has_method("close_popup"):
		current_console.close_popup()
	popup_open = false
	current_console = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GuideManager.set_popup_open(false)


func _open_pause_menu() -> void:
	AudioManager.play_button_bottom()
	pause_menu_open = true
	pause_menu.visible = true
	interact_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GuideManager.set_popup_open(true)


func _close_pause_menu() -> void:
	AudioManager.play_button_bottom()
	pause_menu_open = false
	pause_settings_open = false
	pause_instructions_open = false
	pause_menu.visible = false
	pause_settings_overlay.visible = false
	pause_instructions.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GuideManager.set_popup_open(false)


func _open_pause_settings() -> void:
	AudioManager.play_button_bottom()
	pause_settings_open = true
	pause_settings_overlay.visible = true


func _close_pause_settings() -> void:
	AudioManager.play_button_bottom()
	pause_settings_open = false
	pause_settings_overlay.visible = false


func _open_pause_instructions() -> void:
	AudioManager.play_button_bottom()
	pause_instructions_open = true
	pause_instructions.open()


func _close_pause_instructions() -> void:
	pause_instructions_open = false
	pause_instructions.close()  # no-op if already closed, e.g. via its own Back button


# Fired by the popup's own Back button — keeps our bookkeeping in sync
# even when it closes itself rather than being closed via Tab.
func _on_pause_instructions_closed() -> void:
	pause_instructions_open = false


func _on_pause_exit_pressed() -> void:
	AudioManager.play_button_other()
	get_tree().quit()
