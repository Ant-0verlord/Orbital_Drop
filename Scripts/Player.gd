extends CharacterBody3D

const SPEED = 7.5
const SENSITIVITY = 0.005

@onready var camera = $Camera3D

# Default to true since we capture the mouse in _ready()
var capMouse = true 
var look_dir: Vector2

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Only capture mouse motion if the mouse is actually captured
	if capMouse and event is InputEventMouseMotion:
		look_dir = event.relative

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle Pause/Toggle
	# Note: Ensure you have an action named "pause" in Input Map
	if Input.is_action_just_pressed("Pause"):
		capMouse = !capMouse
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capMouse else Input.MOUSE_MODE_VISIBLE

	# Handle Movement (only if mouse is captured)
	if capMouse:
		var input_dir := Input.get_vector("Walk_Left", "Walk_Right", "Walk_Front", "Walk_Back")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			
		_rotate_camera()

	move_and_slide()

func _rotate_camera() -> void:
	rotate_y(-look_dir.x * SENSITIVITY)
	camera.rotation.x = clamp(camera.rotation.x - look_dir.y * SENSITIVITY, -1.5, 1.5)
	look_dir = Vector2.ZERO
