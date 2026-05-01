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

var popup_open: bool = false
var current_console     = null  # The console node currently open


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interact_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look — only when no popup is open
	if not popup_open and event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Open console popup
	if event.is_action_pressed("interact") and not popup_open:
		if ray.is_colliding():
			var hit = ray.get_collider()
			if hit and hit.has_method("open_popup"):
				hit.open_popup()
				popup_open = true
				current_console = hit
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Close popup with Esc
	if event.is_action_pressed("ui_cancel") and popup_open:
		_close_popup()


func _physics_process(delta: float) -> void:
	if popup_open:
		return  # Lock movement while popup is open

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
	if current_console and current_console.has_method("close_popup"):
		current_console.close_popup()
	popup_open = false
	current_console = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
