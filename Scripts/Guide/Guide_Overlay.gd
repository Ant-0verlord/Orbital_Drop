extends CanvasLayer
# =============================================================
# GuideOverlay.gd
# Handles the bottom prompt bar and 2D billboard arrows
# pointing at consoles in 3D space.
# =============================================================

@onready var prompt_bar:   PanelContainer = $PromptBar
@onready var prompt_label: Label         = $PromptBar/HBoxContainer/PromptLabel
@onready var dismiss_btn:  Button        = $PromptBar/HBoxContainer/DismissBtn
@onready var arrow_canvas: Control       = $ArrowCanvas

var camera: Camera3D = null
var target_console: String = ""
var arrow_pulse: float = 0.0

func _ready() -> void:
	dismiss_btn.pressed.connect(_on_dismiss_pressed)
	GuideManager.step_changed.connect(_on_step_changed)
	GuideManager.guide_dismissed.connect(_on_guide_dismissed)
	prompt_bar.visible = false
	arrow_canvas.queue_redraw()

func set_camera(cam: Camera3D) -> void:
	camera = cam

func _process(delta: float) -> void:
	if not GuideManager.guide_active:
		return
	arrow_pulse += delta * 3.0
	arrow_canvas.queue_redraw()
	prompt_label.text = GuideManager.get_prompt_text()
	prompt_bar.visible = GuideManager.get_prompt_text() != ""

func _on_step_changed(console: String) -> void:
	target_console = console
	arrow_canvas.queue_redraw()

func _on_dismiss_pressed() -> void:
	GuideManager.dismiss()
	prompt_bar.visible = false
	arrow_canvas.queue_redraw()

func _on_guide_dismissed() -> void:
	prompt_bar.visible = false
	arrow_canvas.queue_redraw()

func _draw_arrows() -> void:
	# Called from ArrowCanvas._draw()
	if camera == null or not GuideManager.guide_active:
		return
	if GuideManager.popup_open:
		return
	if target_console == "":
		return

	var world_pos = GuideManager.CONSOLE_POSITIONS.get(target_console, Vector3.ZERO)
	if world_pos == Vector3.ZERO:
		return

	var screen_pos = camera.unproject_position(world_pos)

	# Don't draw if behind camera
	if camera.is_position_behind(world_pos):
		return

	var t = (sin(arrow_pulse) + 1.0) * 0.5
	var alpha = lerp(0.6, 1.0, t)
	var bounce = sin(arrow_pulse * 1.5) * 8.0

	# Draw a downward-pointing chevron arrow
	var tip   = screen_pos + Vector2(0, bounce)
	var left  = tip + Vector2(-18, -28)
	var right = tip + Vector2( 18, -28)
	var mid_l = tip + Vector2( -9, -14)
	var mid_r = tip + Vector2(  9, -14)
	var top_l = tip + Vector2(-18, -42)
	var top_r = tip + Vector2( 18, -42)

	var col_outer = Color(1.0, 0.85, 0.2, alpha)
	var col_inner = Color(1.0, 0.95, 0.5, alpha * 0.7)

	# Outer chevron
	arrow_canvas.draw_colored_polygon(
		PackedVector2Array([top_l, top_r, mid_r, right, tip, left, mid_l]),
		col_outer
	)
	# Inner highlight
	var shrink = 3.0
	arrow_canvas.draw_colored_polygon(
		PackedVector2Array([
			top_l + Vector2(shrink, shrink),
			top_r + Vector2(-shrink, shrink),
			mid_r + Vector2(-shrink, 0),
			right + Vector2(-shrink, -shrink),
			tip   + Vector2(0, -shrink),
			left  + Vector2(shrink, -shrink),
			mid_l + Vector2(shrink, 0),
		]),
		col_inner
	)

	# Console name label below arrow
	var font = ThemeDB.fallback_font
	var label_text = target_console.to_upper().replace("_", " ")
	var label_pos  = screen_pos + Vector2(-40, bounce + 12)
	arrow_canvas.draw_string(font, label_pos, label_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col_outer)
