extends Control
# =============================================================
# BriefingHexPreview.gd
# Static non-interactive hex map preview for mission briefing.
# =============================================================

var zone_states: Dictionary = {}
var axial_map:   Dictionary = {}

const HEX_R       = 18.0
const GRID_CENTRE = Vector2(300, 100)
const MIN_SIZE    = Vector2(300, 150)
# Extra room around the hex bounds so the outermost hexes aren't
# clipped right at the control's edge.
const PADDING     = HEX_R * 2.0

var _bounds_min: Vector2 = Vector2.ZERO
var _bounds_max: Vector2 = Vector2.ZERO

func setup(states: Dictionary, axial: Dictionary) -> void:
	zone_states = states
	axial_map   = axial
	_compute_bounds()
	# Missions vary hugely in map size (Mission 1's handful of sectors vs.
	# Mission 3/4/5's 100+ sector maps) — a fixed box was fine for the
	# small maps but too short for the big ones, so the hexes overflowed
	# upward into the objective text above. Size the control to whatever
	# this specific mission's map actually needs instead.
	custom_minimum_size = Vector2(
		max(_bounds_max.x - _bounds_min.x + PADDING * 2.0, MIN_SIZE.x),
		max(_bounds_max.y - _bounds_min.y + PADDING * 2.0, MIN_SIZE.y)
	)
	queue_redraw()

func _compute_bounds() -> void:
	var sq3 = sqrt(3.0)
	var r   = HEX_R
	var positions: Array[Vector2] = []
	for sector in zone_states:
		if axial_map.has(sector):
			var ax = axial_map[sector]
			positions.append(Vector2(
				r * (sq3 * ax.x + sq3 * 0.5 * ax.y),
				r * 1.5 * ax.y
			))
	if positions.is_empty():
		_bounds_min = Vector2.ZERO
		_bounds_max = Vector2.ZERO
		return
	_bounds_min = positions[0]
	_bounds_max = positions[0]
	for p in positions:
		_bounds_min = Vector2(min(_bounds_min.x, p.x), min(_bounds_min.y, p.y))
		_bounds_max = Vector2(max(_bounds_max.x, p.x), max(_bounds_max.y, p.y))

func _draw() -> void:
	if zone_states.is_empty():
		return

	var sq3 = sqrt(3.0)
	var r   = HEX_R
	var offset = (size / 2.0) - ((_bounds_min + _bounds_max) / 2.0)

	for sector in zone_states:
		if not axial_map.has(sector):
			continue
		var ax = axial_map[sector]
		var pixel = Vector2(
			r * (sq3 * ax.x + sq3 * 0.5 * ax.y),
			r * 1.5 * ax.y
		) + offset

		var state = zone_states[sector].get("state", "enemy")
		var squad_names: Array = zone_states[sector].get("squad", [])

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

		if squad_names.size() > 0:
			# ASCII "o" rather than a Unicode bullet (●) — the project's
			# default font doesn't cover that codepoint, and the web/itch.io
			# export has no OS-level font fallback the way the desktop
			# editor does, so it was rendering as a "tofu" box instead.
			draw_string(ThemeDB.fallback_font,
				pixel + Vector2(-4, 4),
				"o", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

			# Name(s) underneath the hex — comma-joined on one small line
			# since this preview's hexes are too small for one line each,
			# but every squad occupying the tile still shows, not just
			# whichever happened to be listed last.
			var label = ""
			for i in range(squad_names.size()):
				if i > 0:
					label += ", "
				label += String(squad_names[i]).replace("Squad ", "")
			draw_string(ThemeDB.fallback_font,
				pixel + Vector2(-label.length() * 2.2, r + 8),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.9))

		# Priority target / tower / extraction-zone callouts — lets the
		# player scope out the objective before committing to the
		# mission instead of finding out where everything is mid-fight.
		var marker = zone_states[sector].get("marker", "")
		if marker != "":
			var marker_color: Color
			var marker_glyph: String
			var marker_label: String
			# Glyphs are plain ASCII, not Unicode symbols (★ ▲ ⇑) — those
			# codepoints aren't in the project's default font, and the
			# web/itch.io export has no OS font fallback, so they were
			# rendering as "tofu" boxes instead of the intended marker.
			match marker:
				"priority":
					marker_color = Color(1.0, 0.55, 0.15)
					marker_glyph = "!"
					var override_label = String(zone_states[sector].get("marker_label", ""))
					marker_label = override_label if override_label != "" else "TARGET"
				"tower":
					marker_color = Color(0.3, 0.75, 1.0)
					marker_glyph = "T"
					marker_label = "TOWER"
				"extract":
					marker_color = Color(0.4, 0.9, 0.6)
					marker_glyph = "^"
					marker_label = "EXTRACT"
				_:
					marker_color = Color.WHITE
					marker_glyph = ""
					marker_label = ""

			if marker_glyph != "":
				# Highlighted outline so the hex stands out from the rest
				# of the map at a glance, on top of the glyph itself.
				draw_polyline(outline, marker_color, 2.5)
				draw_string(ThemeDB.fallback_font,
					pixel + Vector2(-5, 4),
					marker_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, marker_color)
				# Only label if the hex isn't already carrying a squad
				# name in that same spot — these marker hexes shouldn't
				# normally have a squad on them at briefing time, but
				# this keeps it safe if one ever does.
				if squad_names.is_empty():
					draw_string(ThemeDB.fallback_font,
						pixel + Vector2(-marker_label.length() * 2.2, r + 8),
						marker_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, marker_color)

func _hex_points(centre: Vector2, r: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * i - 30.0)
		pts.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return pts
