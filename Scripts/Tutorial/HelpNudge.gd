extends Control
# =============================================================
# HelpNudge.gd
# Attach to: Control (full-rect, mouse_filter = IGNORE)
#
# A small, self-dismissing arrow + label that briefly points at a
# target Control — used to nudge a first-time player toward a console's
# Help button the moment they open it. Purely a hint: unlike
# TutorialOverlay it never blocks input or waits on a click, it just
# fades in, holds for a couple of seconds, then fades itself out.
# =============================================================

@onready var arrow: Control = $Arrow
@onready var label: Label   = $NudgeLabel

const HOLD_TIME: float     = 2.5
const FADE_IN_TIME: float  = 0.25
const FADE_OUT_TIME: float = 0.6

var _target: Control = null
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	set_process(false)


# Call right after the console popup becomes visible. `text` defaults to
# a generic nudge but can be overridden per-console if useful later.
func point_at(target: Control, text: String = "First time here — try Help") -> void:
	if not is_instance_valid(target):
		return

	_target = target
	label.text = text
	_update_positions()

	if _tween and _tween.is_valid():
		_tween.kill()

	modulate.a = 0.0
	set_process(true)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_TIME)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_TIME)
	_tween.tween_callback(_on_faded_out)


func _on_faded_out() -> void:
	set_process(false)
	arrow.clear_arrow()
	_target = null


func _process(_delta: float) -> void:
	_update_positions()


const SCREEN_MARGIN: float = 14.0

func _update_positions() -> void:
	if not is_instance_valid(_target):
		return

	# Clamp against the popup's own panel, not the full window. Some
	# popups (Command Throne in particular) don't actually cover the
	# whole viewport — clamping to the viewport size let the nudge
	# drift past the edge of the dark panel and render over the 3D
	# scene behind it (e.g. the throne floor) instead of staying on
	# the UI. HelpNudge is always instanced as a direct child of the
	# popup's own root Control, so that parent's rect is exactly the
	# visible panel bounds to stay inside.
	var bounds: Rect2 = get_viewport_rect()
	var parent_ctrl := get_parent() as Control
	if parent_ctrl:
		bounds = parent_ctrl.get_global_rect()

	var target_rect: Rect2 = _target.get_global_rect()

	# The arrow tip always sits right at the button — only the tail (and
	# the label anchored to it) get pulled in from the edges below, so
	# the arrow keeps pointing at the right place even when the target
	# button is close to a panel edge.
	var tip:  Vector2 = Vector2(target_rect.get_center().x, target_rect.position.y - 8.0)
	var tail: Vector2 = tip + Vector2(-50.0, 80.0)
	tail.x = clamp(tail.x, bounds.position.x + SCREEN_MARGIN, bounds.position.x + bounds.size.x - SCREEN_MARGIN)
	tail.y = clamp(tail.y, bounds.position.y + SCREEN_MARGIN, bounds.position.y + bounds.size.y - SCREEN_MARGIN)
	arrow.set_points(tail, tip)

	# Keep the label fully within the panel too — clamp its rect (with a
	# margin) so it never runs off the side or bleeds past the bottom of
	# the popup's own panel when the target is near an edge.
	var label_size: Vector2 = label.size
	var label_pos: Vector2 = tail + Vector2(-label_size.x * 0.5, 6.0)
	label_pos.x = clamp(label_pos.x, bounds.position.x + SCREEN_MARGIN, bounds.position.x + bounds.size.x - label_size.x - SCREEN_MARGIN)
	label_pos.y = clamp(label_pos.y, bounds.position.y + SCREEN_MARGIN, bounds.position.y + bounds.size.y - label_size.y - SCREEN_MARGIN)
	label.position = label_pos
