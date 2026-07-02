extends Control
# Draws a line + arrowhead from the text panel toward a target point.

var target_point: Vector2 = Vector2.ZERO
var origin_point: Vector2 = Vector2.ZERO

func set_points(from: Vector2, to: Vector2) -> void:
	origin_point = from
	target_point = to
	queue_redraw()

func clear_arrow() -> void:
	origin_point = Vector2.ZERO
	target_point = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if origin_point == target_point:
		return
	draw_line(origin_point, target_point, Color(1.0, 0.85, 0.2, 0.95), 3.0)
	var dir = (target_point - origin_point).normalized()
	var perp = Vector2(-dir.y, dir.x)
	var tip = target_point
	var back1 = tip - dir * 14 + perp * 7
	var back2 = tip - dir * 14 - perp * 7
	draw_colored_polygon(PackedVector2Array([tip, back1, back2]), Color(1.0, 0.85, 0.2, 0.95))
