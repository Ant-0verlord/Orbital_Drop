extends CharacterBody3D

# --- Settings ---
@export var move_speed: float = 4.0
@export var mouse_sensitivity: float = 0.002
@export var interact_distance: float = 2.5

# --- Nodes ---
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var interact_label: Label = %InteractLabel  # small "Press E" hint in HUD

var current_console = null  # the console popup currently open (or null)
var popup_open: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interact_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look (only when no popup is open)
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
		close_popup()


func _physics_process(_delta: float) -> void:
	if popup_open:
		return  # Lock movement while popup is open

	# WASD movement
	var input_dir = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back")  - Input.get_action_strength("move_forward")
	)
	var direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y -= 9.8 * _delta  # Simple gravity

	move_and_slide()

	# "Press E" hint
	var can_interact = ray.is_colliding() and ray.get_collider() and ray.get_collider().has_method("open_popup")
	interact_label.visible = can_interact


func close_popup() -> void:
	if current_console and current_console.has_method("close_popup"):
		current_console.close_popup()
	popup_open = false
	current_console = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# Called by a popup's Close button directly
func on_popup_closed() -> void:
	close_popup()
