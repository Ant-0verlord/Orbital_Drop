extends Control
# =============================================================
# HexCanvas.gd
# Self-contained hex grid renderer for the Holo-Map.
# Fixed size: 630 x 410 (set in editor)
# =============================================================

var zone_states: Dictionary = {}
var hex_entries: Array = []
var flicker_states: Dictionary = {}
var pulse_time: float = 0.0

const PULSE_SPEED: float = 2.5
const HEX_RADIUS: float  = 38.0
const HEX_INNER: float   = 38.0
const GRID_CENTER: Vector2 = Vector2(315, 205)

const COLOR_HELD:         Color = Color(0.1,  0.8,  0.3,  0.85)
const COLOR_CONTESTED:    Color = Color(0.9,  0.7,  0.1,  0.85)
const COLOR_LOST:         Color = Color(0.4,  0.4,  0.4,  0.7)
const COLOR_ENEMY:        Color = Color(0.7,  0.1,  0.1,  0.85)
const COLOR_NEUTRAL:      Color = Color(0.12, 0.18, 0.25, 0.7)
const COLOR_BORDER:       Color = Color(0.4,  0.9,  1.0,  0.9)
const COLOR_ENEMY_BORDER: Color = Color(1.0,  0.3,  0.3,  1.0)
const COLOR_BG:           Color = Color(0.03, 0.06, 0.12, 1.0)
const COLOR_LABEL:        Color = Color(0.8,  1.0,  1.0,  1.0)


func _process(delta: float) -> void:
	if not visible:
		return
	pulse_time += delta * PULSE_SPEED
	var interference = SquadManager.interference
	if interference > 0.2:
		for sector in zone_states:
			if zone_states[sector].get("enemy_count", 0) > 0:
				flicker_states[sector] = randf() > interference * 0.35
	queue_redraw()


func refresh(new_zone_states: Dictionary) -> void:
	zone_states = new_zone_states
	_build_hex_layout()
	queue_redraw()


# -------------------------------------------------------
# 14-hex flat-top layout using axial coordinates
# Centre + Ring 1 (6) + Ring 2 (7)
# Coordinates are relative to THIS control's top-left (0,0)
# -------------------------------------------------------
func _build_hex_layout() -> void:
	hex_entries.clear()
	var sectors = zone_states.keys()
	if sectors.is_empty():
		return

	var r = HEX_RADIUS
	var sq3 = sqrt(3.0)

	var axial = [
		Vector2( 0,  0),
		Vector2( 1, -1),
		Vector2( 1,  0),
		Vector2( 0,  1),
		Vector2(-1,  1),
		Vector2(-1,  0),
		Vector2( 0, -1),
		Vector2( 2, -2),
		Vector2( 2, -1),
		Vector2( 2,  0),
		Vector2( 1,  1),
		Vector2( 0,  2),
		Vector2(-1,  2),
		Vector2(-2,  1),
	]

	for i in range(min(sectors.size(), axial.size())):
		var q = axial[i].x
		var s = axial[i].y
		var pixel = Vector2(
			r * (sq3 * q + sq3 * 0.5 * s),
			r * (1.5 * s)
		)
		hex_entries.append({
			"sector": sectors[i],
			"center": GRID_CENTER + pixel,
		})


func _draw() -> void:
	if not visible:
		return

	# Fill the whole canvas
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER * Color(1, 1, 1, 0.2), false, 1.0)

	# Grid lines
	for x in range(0, int(size.x), 36):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.4, 0.5, 0.08), 0.5)
	for y in range(0, int(size.y), 36):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.4, 0.5, 0.08), 0.5)

	var interference = SquadManager.interference

	for entry in hex_entries:
		var center: Vector2  = entry.center
		var sector: String   = entry.sector
		var data             = zone_states.get(sector, {})
		var state: String    = data.get("state", "enemy")
		var squad: String    = data.get("squad", "")
		var enemy_count: int = data.get("enemy_count", 0)

		var enemy_visible = true
		if enemy_count > 0 and interference > 0.2:
			enemy_visible = flicker_states.get(sector, true)

		var fill = _state_color(state)

		if enemy_count > 0 and enemy_visible:
			fill = fill.lerp(COLOR_ENEMY, 0.55) if state in ["held", "contested"] else COLOR_ENEMY

		if state == "contested" and enemy_count == 0:
			var pulse = sin(pulse_time) * 0.5 + 0.5
			fill.a = lerp(0.5, 0.95, pulse)
			fill = fill.lerp(Color(1.0, 0.95, 0.4, fill.a), pulse * 0.25)

		if enemy_count > 0 and enemy_visible:
			var pulse = sin(pulse_time * 1.6) * 0.5 + 0.5
			fill.a = lerp(0.6, 1.0, pulse)

		draw_colored_polygon(_hex_points(center, HEX_INNER), fill)

		var border = COLOR_BORDER
		if enemy_count > 0 and enemy_visible:
			border = COLOR_ENEMY_BORDER.lerp(Color(1, 0.5, 0.5, 1), sin(pulse_time * 1.6) * 0.3)
		elif state == "contested":
			border = Color(1.0, 0.85, 0.2, 0.9)
		elif state in ["enemy", "neutral"]:
			border = Color(0.3, 0.4, 0.5, 0.5)
		_draw_hex_border(center, HEX_RADIUS - 1.0, border, 1.5)

		var lc = COLOR_LABEL if state not in ["enemy", "neutral"] else Color(0.55, 0.65, 0.7)
		draw_string(ThemeDB.fallback_font,
			center + Vector2(-len(sector) * 3.0, -7),
			sector, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, lc)

		if squad != "":
			var short = squad.replace("Squad ", "")
			draw_string(ThemeDB.fallback_font,
				center + Vector2(-len(short) * 2.8, 4),
				short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.7))

		if enemy_count > 0 and enemy_visible:
			var marker = "✕" if enemy_count == 1 else "✕×%d" % enemy_count
			draw_string(ThemeDB.fallback_font,
				center + Vector2(-len(marker) * 3.5, 16),
				marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.4, 0.4, 0.95))
		elif enemy_count > 0 and not enemy_visible:
			draw_string(ThemeDB.fallback_font,
				center + Vector2(-6, 16),
				"░░", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.3, 0.3, 0.35))


func _hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _draw_hex_border(center: Vector2, radius: float, color: Color, width: float) -> void:
	var pts = _hex_points(center, radius)
	for i in range(6):
		draw_line(pts[i], pts[(i + 1) % 6], color, width)


func _state_color(state: String) -> Color:
	match state:
		"held":      return COLOR_HELD
		"contested": return COLOR_CONTESTED
		"lost":      return COLOR_LOST
		"enemy":     return COLOR_ENEMY
		"neutral":   return COLOR_NEUTRAL
	return COLOR_NEUTRAL
