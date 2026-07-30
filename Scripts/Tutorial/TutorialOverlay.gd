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
	step_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	back_btn.disabled = current_index == 0
	next_btn.text = "Next" if current_index < steps.size() - 1 else "Done"
	_position_arrow_and_panel(step)


func _position_arrow_and_panel(step: TutorialStep) -> void:
	# Force panel to a sensible width based on screen size
	# Use 35% of overlay width, clamped between 280px and 480px
	var panel_width = clamp(size.x * 0.35, 280.0, 480.0)
	step_label.custom_minimum_size = Vector2(panel_width - 24, 0)
	text_panel.custom_minimum_size = Vector2(panel_width, 0)

	# Wait two frames — one for label to wrap, one for panel to measure
	await get_tree().process_frame
	await get_tree().process_frame

	var panel_size: Vector2 = Vector2(panel_width, text_panel.size.y)

	if host_popup == null or step.target_path.is_empty():
		arrow.clear_arrow()
		text_panel.position = (size - panel_size) / 2.0
		return

	var target = host_popup.get_node_or_null(step.target_path)
	if target == null:
		arrow.clear_arrow()
		text_panel.position = (size - panel_size) / 2.0
		return

	var target_rect: Rect2  = target.get_global_rect()
	var target_center: Vector2 = target_rect.get_center() + step.arrow_offset
	var margin = 20.0
	var panel_pos: Vector2

	var below_y = target_rect.position.y + target_rect.size.y + margin
	var above_y = target_rect.position.y - panel_size.y - margin

	if below_y + panel_size.y <= size.y - 10:
		panel_pos = Vector2(target_center.x - panel_size.x / 2.0, below_y)
	elif above_y >= 10:
		panel_pos = Vector2(target_center.x - panel_size.x / 2.0, above_y)
	else:
		# Neither fits cleanly — centre on screen
		panel_pos = (size - panel_size) / 2.0

	panel_pos.x = clamp(panel_pos.x, 10.0, size.x - panel_size.x - 10.0)
	panel_pos.y = clamp(panel_pos.y, 10.0, size.y - panel_size.y - 10.0)
	text_panel.position = panel_pos

	# Arrow from nearest panel edge to target
	var panel_rect = Rect2(panel_pos, panel_size)
	var origin: Vector2
	if panel_rect.position.y > target_rect.position.y:
		origin = Vector2(panel_rect.position.x + panel_rect.size.x / 2.0, panel_rect.position.y)
	else:
		origin = Vector2(panel_rect.position.x + panel_rect.size.x / 2.0, panel_rect.position.y + panel_rect.size.y)

	arrow.origin_point = origin
	arrow.target_point = target_center
	arrow.queue_redraw()


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
