extends Control
# =============================================================
# TutorialOverlay.gd
# Reusable step-by-step UI tutorial: arrow + text box pointing
# at specific nodes within whatever popup is currently open.
# =============================================================

@onready var dim: ColorRect          = $Dim
@onready var arrow: Control          = $Arrow
@onready var text_panel: PanelContainer = $TextPanel
@onready var step_label: Label       = $TextPanel/VBoxContainer/StepLabel
@onready var back_btn: Button        = $TextPanel/VBoxContainer/ButtonRow/BackBtn
@onready var next_btn: Button        = $TextPanel/VBoxContainer/ButtonRow/NextBtn
@onready var skip_btn: Button        = $TextPanel/VBoxContainer/ButtonRow/SkipBtn

var steps: Array[TutorialStep] = []
var current_index: int = 0
var host_popup: Control = null  # the popup these steps' target_paths are relative to

signal tutorial_finished


func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	skip_btn.pressed.connect(_on_skip_pressed)
	visible = false


func start(tutorial_steps: Array[TutorialStep], popup: Control) -> void:
	steps = tutorial_steps
	host_popup = popup
	current_index = 0
	visible = true
	_show_step()


func _show_step() -> void:
	if steps.is_empty():
		_finish()
		return

	var step: TutorialStep = steps[current_index]
	step_label.text = step.text
	back_btn.disabled = current_index == 0
	next_btn.text = "Next" if current_index < steps.size() - 1 else "Done"

	_position_arrow_and_panel(step)


func _position_arrow_and_panel(step: TutorialStep) -> void:
	if host_popup == null or step.target_path.is_empty():
		arrow.clear_arrow()
		text_panel.position = (size - text_panel.size) / 2.0
		return

	var target = host_popup.get_node_or_null(step.target_path)
	if target == null:
		arrow.clear_arrow()
		text_panel.position = (size - text_panel.size) / 2.0
		return

	var target_rect: Rect2 = target.get_global_rect()
	var target_center: Vector2 = target_rect.get_center() + step.arrow_offset

	# Position the panel just below the target if there's room, else above it.
	var panel_size = text_panel.size
	var panel_pos = Vector2(
		target_center.x - panel_size.x / 2.0,
		target_rect.position.y + target_rect.size.y + 16
	)

	# If it would run off the bottom, place it above the target instead.
	if panel_pos.y + panel_size.y > size.y - 10:
		panel_pos.y = target_rect.position.y - panel_size.y - 16

	panel_pos.x = clamp(panel_pos.x, 10, size.x - panel_size.x - 10)
	panel_pos.y = clamp(panel_pos.y, 10, size.y - panel_size.y - 10)
	text_panel.position = panel_pos

	# Arrow runs from the panel's nearest edge (top or bottom centre) to the target centre.
	var panel_rect = Rect2(panel_pos, panel_size)
	var origin: Vector2
	if panel_rect.position.y < target_rect.position.y:
		origin = Vector2(panel_rect.position.x + panel_rect.size.x / 2.0, panel_rect.position.y + panel_rect.size.y)
	else:
		origin = Vector2(panel_rect.position.x + panel_rect.size.x / 2.0, panel_rect.position.y)

	arrow.set_points(origin, target_center)


func _on_back_pressed() -> void:
	if current_index > 0:
		current_index -= 1
		_show_step()

func _on_next_pressed() -> void:
	if current_index < steps.size() - 1:
		current_index += 1
		_show_step()
	else:
		_finish()

func _on_skip_pressed() -> void:
	_finish()

func _finish() -> void:
	visible = false
	emit_signal("tutorial_finished")
