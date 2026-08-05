extends Control
# =============================================================
# BriefingHexPreview.gd
# Static non-interactive hex map preview for mission briefing.
# =============================================================

var zone_states: Dictionary = {}
var axial_map:   Dictionary = {}

const HEX_R     = 18.0
const GRID_CENTRE = Vector2(300, 100)

func setup(states: Dictionary, axial: Dictionary) -> void:
	zone_states = states
	axial_map   = axial
	custom_minimum_size = Vector2(600, 200)
	queue_redraw()

func _draw() -> void:
	if zone_states.is_empty():
		return

	var sq3 = sqrt(3.0)
	var r   = HEX_R

	# Auto-centre: find pixel bounds and recentre
	var positions: Array[Vector2] = []
	for sector in zone_states:
		if axial_map.has(sector):
			var ax = axial_map[sector]
			positions.append(Vector2(
				r * (sq3 * ax.x + sq3 * 0.5 * ax.y),
				r * 1.5 * ax.y
			))
	if positions.is_empty():
		return

	var min_p = positions[0]; var max_p = positions[0]
	for p in positions:
		min_p = Vector2(min(min_p.x, p.x), min(min_p.y, p.y))
		max_p = Vector2(max(max_p.x, p.x), max(max_p.y, p.y))
	var offset = (size / 2.0) - ((min_p + max_p) / 2.0)

	for sector in zone_states:
		if not axial_map.has(sector):
			continue
		var ax = axial_map[sector]
		var pixel = Vector2(
			r * (sq3 * ax.x + sq3 * 0.5 * ax.y),
			r * 1.5 * ax.y
		) + offset

		var state = zone_states[sector].get("state", "enemy")
		var squad = zone_states[sector].get("squad", "")

		var fill: Color
		match state:
			"held":      fill = Color(0.2, 0.6, 0.25, 0.9)
			"enemy":     fill = Color(0.7, 0.15, 0.15, 0.9)
			"contested": fill = Color(0.7, 0.55, 0.1, 0.9)
			_:           fill = Color(0.2, 0.25, 0.35, 0.8)

		var pts = _hex_points(pixel, r - 1.5)
		draw_colored_polygon(pts, fill)
		var outline = PackedVector2Array(pts)
		outline.append(pts[0])
		draw_polyline(outline, Color(0.15, 0.2, 0.3, 0.6), 1.0)

		if squad != "":
			draw_string(ThemeDB.fallback_font,
				pixel + Vector2(-4, 4),
				"●", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _hex_points(centre: Vector2, r: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * i - 30.0)
		pts.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return pts
