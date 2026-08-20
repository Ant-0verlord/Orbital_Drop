extends Control
# =============================================================
# HexCanvas.gd
# Self-contained hex grid renderer for the Holo-Map.
# Fixed size: 630 x 410 (set in editor)
# =============================================================

var zone_states: Dictionary = {}
var hex_entries: Array = []
var pulse_time: float = 0.0

# Enemy sensor "glitch" effect — occasional brief static bursts on enemy
# hexes, rather than a steady on/off flash. Most of the time an enemy
# marker just reads clean; every so often (rolled per-sector, weighted by
# interference) it drops into a short burst of randomised static/noise
# before returning to normal.
var glitch_states: Dictionary = {}   # sector -> bool, currently glitching
var glitch_timers: Dictionary = {}   # sector -> seconds left in current burst

# Reinforcement placement mode
var placement_mode: bool = false
var hovered_sector: String = ""
var placed_sector: String = ""

var pan_offset: Vector2 = Vector2.ZERO
var dragging: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_offset: Vector2 = Vector2.ZERO

var special_sectors: Dictionary = {}
# Format: { "sector_name": "priority" / "tower" / "tower_powered" / "extraction" }

signal hex_clicked(sector: String)

var glitch_check_timer: float = 0.0
const GLITCH_CHECK_INTERVAL: float  = 0.6   # how often we roll the dice for a new burst
const GLITCH_CHANCE_PER_CHECK: float = 0.12 # base odds per roll, scaled by interference
const GLITCH_DURATION_MIN: float = 0.12     # a burst is short — a flicker of static, not a hold
const GLITCH_DURATION_MAX: float = 0.4

const PULSE_SPEED: float = 2.5
const HEX_RADIUS: float  = 38.0
const HEX_INNER: float   = 38.0
const GRID_CENTER: Vector2 = Vector2(315, 205)
const SQUAD_LINE_HEIGHT: float = 10.0

const COLOR_HELD:         Color = Color(0.1,  0.8,  0.3,  0.85)
const COLOR_CONTESTED:    Color = Color(0.9,  0.7,  0.1,  0.85)
const COLOR_LOST:         Color = Color(0.4,  0.4,  0.4,  0.7)
const COLOR_ENEMY:        Color = Color(0.7,  0.1,  0.1,  0.85)
const COLOR_NEUTRAL:      Color = Color(0.12, 0.18, 0.25, 0.7)
const COLOR_BORDER:       Color = Color(0.4,  0.9,  1.0,  0.9)
const COLOR_ENEMY_BORDER: Color = Color(1.0,  0.3,  0.3,  1.0)
const COLOR_BG:           Color = Color(0.03, 0.06, 0.12, 1.0)
const COLOR_LABEL:        Color = Color(0.8,  1.0,  1.0,  1.0)
const COLOR_PLACEMENT:    Color = Color(0.2,  0.6,  1.0,  0.9)
const COLOR_PLACEMENT_HOVER: Color = Color(0.4, 0.85, 1.0, 1.0)
const COLOR_PLACED:       Color = Color(0.1,  1.0,  0.5,  0.95)
const COLOR_PRIORITY:     Color = Color(0.6,  0.1,  0.8,  0.9)   # purple
const COLOR_TOWER:        Color = Color(0.1,  0.8,  0.85, 0.9)   # teal/cyan
const COLOR_TOWER_ACTIVE: Color = Color(0.0,  1.0,  0.75, 0.95)  # bright powered teal
const COLOR_EXTRACTION:   Color = Color(0.95, 0.8,  0.1,  0.9)   # gold

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _clamp_pan_offset() -> void:
	if hex_entries.is_empty():
		return
	var min_x = INF; var max_x = -INF
	var min_y = INF; var max_y = -INF
	for entry in hex_entries:
		min_x = min(min_x, entry.center.x)
		max_x = max(max_x, entry.center.x)
		min_y = min(min_y, entry.center.y)
		max_y = max(max_y, entry.center.y)

	var margin = HEX_RADIUS * 2.0
	pan_offset.x = clamp(pan_offset.x, size.x - max_x - margin, -min_x + margin)
	pan_offset.y = clamp(pan_offset.y, size.y - max_y - margin, -min_y + margin)

func _process(delta: float) -> void:
	if not visible:
		return
	
	if dragging:
		var mouse_pos = get_local_mouse_position()
		pan_offset = drag_start_offset + (mouse_pos - drag_start_mouse)
		_clamp_pan_offset()
		queue_redraw()
	
	pulse_time += delta * PULSE_SPEED

	var interference = SquadManager.interference
	if interference > 0.2:
		# Occasionally roll a new static burst on an enemy hex that isn't
		# already glitching — rare and brief, not a steady rhythm.
		glitch_check_timer += delta
		if glitch_check_timer >= GLITCH_CHECK_INTERVAL:
			glitch_check_timer = 0.0
			for sector in zone_states:
				if zone_states[sector].get("enemy_count", 0) > 0 and not glitch_states.get(sector, false):
					if randf() < GLITCH_CHANCE_PER_CHECK * interference:
						glitch_states[sector] = true
						glitch_timers[sector] = randf_range(GLITCH_DURATION_MIN, GLITCH_DURATION_MAX)

		# Tick down any bursts already in progress and clear them when done.
		for sector in glitch_states.keys():
			if glitch_states[sector]:
				glitch_timers[sector] = glitch_timers.get(sector, 0.0) - delta
				if glitch_timers[sector] <= 0.0:
					glitch_states[sector] = false
	else:
		glitch_states.clear()
		glitch_timers.clear()

	queue_redraw()


func refresh(new_zone_states: Dictionary, axial_by_sector: Dictionary = {}, new_special_sectors: Dictionary = {}) -> void:
	zone_states = new_zone_states
	if not axial_by_sector.is_empty():
		current_axial_by_sector = axial_by_sector
	special_sectors = new_special_sectors
	_build_hex_layout()
	queue_redraw()

func enter_placement_mode() -> void:
	placement_mode = true
	hovered_sector = ""
	placed_sector  = ""
	queue_redraw()


func exit_placement_mode() -> void:
	placement_mode = false
	hovered_sector = ""
	queue_redraw()


# -------------------------------------------------------
# Mouse input — only active in placement mode
# -------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				dragging = true
				drag_start_mouse  = event.position
				drag_start_offset = pan_offset
			else:
				dragging = false

	if not placement_mode:
		return

	if event is InputEventMouseMotion:
		var sector = _sector_at(event.position)
		if sector != hovered_sector:
			hovered_sector = sector
			queue_redraw()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var sector = _sector_at(event.position)
			if sector != "":
				placed_sector = sector
				emit_signal("hex_clicked", sector)
				queue_redraw()


# -------------------------------------------------------
# Returns sector name at a given local pixel position
# -------------------------------------------------------
func _sector_at(pos: Vector2) -> String:
	for entry in hex_entries:
		if _point_in_hex(pos - pan_offset, entry.center, HEX_INNER):
			return entry.sector
	return ""


func _point_in_hex(point: Vector2, center: Vector2, radius: float) -> bool:
	var local = point - center
	# Pointy-top hex containment check
	var q = (2.0 / 3.0 * local.x) / radius
	var r = (-1.0 / 3.0 * local.x + sqrt(3.0) / 3.0 * local.y) / radius
	var s = -q - r
	var rq = round(q); var rr = round(r); var rs = round(s)
	var dq = abs(rq - q); var dr = abs(rr - r); var ds = abs(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return rq == 0 and rr == 0


# -------------------------------------------------------
# 14-hex layout — coordinates relative to this control
# -------------------------------------------------------
var current_axial_by_sector: Dictionary = {}

func _build_hex_layout() -> void:
	hex_entries.clear()
	for sector_name in zone_states.keys():
		if not current_axial_by_sector.has(sector_name):
			continue
		var pos: Vector2 = current_axial_by_sector[sector_name]
		var r   = HEX_RADIUS
		var sq3 = sqrt(3.0)
		var pixel = Vector2(
			r * (sq3 * pos.x + sq3 * 0.5 * pos.y),
			r * (1.5 * pos.y)
		)
		hex_entries.append({ "sector": sector_name, "center": GRID_CENTER + pixel })


func _draw() -> void:
	if not visible:
		return

	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER * Color(1, 1, 1, 0.2), false, 1.0)

	for x in range(0, int(size.x), 36):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.4, 0.5, 0.08), 0.5)
	for y in range(0, int(size.y), 36):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.4, 0.5, 0.08), 0.5)

	var interference = SquadManager.interference

	for entry in hex_entries:
		var center: Vector2  = entry.center + pan_offset
		var sector: String   = entry.sector
		var data             = zone_states.get(sector, {})
		var state: String    = data.get("state", "enemy")
		var squad_names: Array = data.get("squad", [])
		var enemy_count: int = data.get("enemy_count", 0)

		var enemy_glitching = false
		if enemy_count > 0 and interference > 0.2:
			enemy_glitching = glitch_states.get(sector, false)

		# -------------------------------------------------------
		# Placement mode overrides fill colour
		# -------------------------------------------------------
		var fill: Color
		if placement_mode:
			if sector == placed_sector:
				fill = COLOR_PLACED
			elif sector == hovered_sector:
				fill = COLOR_PLACEMENT_HOVER
			else:
				fill = _state_color(state).lerp(COLOR_PLACEMENT, 0.35)
				# An occupied hex should still read as dangerous even mid-
				# placement — hot-dropping onto an enemy is a deliberate,
				# valid move, and an orbital strike needs to be aimed
				# knowing exactly which hexes it'll actually hit. Tinted
				# rather than fully overridden so it doesn't fight with
				# the placement-mode colour language.
				if enemy_count > 0:
					fill = fill.lerp(COLOR_ENEMY, 0.45)
		else:
			fill = _state_color(state)
			if enemy_count > 0:
				if enemy_glitching:
					# Brief static burst — jittered noise tint, redrawn fresh
					# every frame for the burst's short lifetime so it reads
					# as flickering static rather than a clean colour swap.
					var noise = randf()
					fill = Color(noise, noise, noise, 1.0)
				else:
					fill = fill.lerp(COLOR_ENEMY, 0.55) if state in ["held", "contested"] else COLOR_ENEMY
			if state == "contested" and enemy_count == 0:
				var pulse = sin(pulse_time) * 0.5 + 0.5
				fill.a = lerp(0.5, 0.95, pulse)
				fill = fill.lerp(Color(1.0, 0.95, 0.4, fill.a), pulse * 0.25)
			if enemy_count > 0:
				if enemy_glitching:
					fill.a = randf_range(0.25, 0.9)
				else:
					var pulse = sin(pulse_time * 1.6) * 0.5 + 0.5
					fill.a = lerp(0.6, 1.0, pulse)

		draw_colored_polygon(_hex_points(center, HEX_INNER), fill)
		
		# Special sector colour override
		var special_type = special_sectors.get(sector, "")
		if not placement_mode and special_type != "":
			match special_type:
				"priority":
					fill = fill.lerp(COLOR_PRIORITY, 0.6)
				"tower":
					fill = fill.lerp(COLOR_TOWER, 0.65)
				"tower_powered":
					var pulse = sin(pulse_time * 2.0) * 0.5 + 0.5
					fill = fill.lerp(COLOR_TOWER_ACTIVE, 0.65 + pulse * 0.2)
				"extraction":
					var pulse = sin(pulse_time * 1.5) * 0.5 + 0.5
					fill = fill.lerp(COLOR_EXTRACTION, 0.6 + pulse * 0.2)

		# Border
		var border = COLOR_BORDER
		if placement_mode:
			if sector == placed_sector:
				border = COLOR_PLACED
			elif sector == hovered_sector:
				border = COLOR_PLACEMENT_HOVER
			elif enemy_count > 0:
				border = COLOR_ENEMY_BORDER
			else:
				border = COLOR_PLACEMENT * Color(1, 1, 1, 0.5)
		elif enemy_count > 0 and enemy_glitching:
			var noise = randf()
			border = Color(noise, noise, noise, randf_range(0.5, 1.0))
		elif enemy_count > 0:
			border = COLOR_ENEMY_BORDER.lerp(Color(1, 0.5, 0.5, 1), sin(pulse_time * 1.6) * 0.3)
		elif state == "contested":
			border = Color(1.0, 0.85, 0.2, 0.9)
		elif state in ["enemy", "neutral"]:
			border = Color(0.3, 0.4, 0.5, 0.5)
		_draw_hex_border(center, HEX_RADIUS - 1.0, border, 1.5)

		# Labels
		var lc = COLOR_LABEL if state not in ["enemy", "neutral"] else Color(0.55, 0.65, 0.7)
		draw_string(ThemeDB.fallback_font,
			center + Vector2(-len(sector) * 3.0, -7),
			sector, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, lc)

		# Squad name(s) — stacked one per line underneath the sector
		# label instead of a single cramped line, so a hex with more
		# than one squad on it (a trailing squad sharing a tile with
		# another, a reinforcement landing alongside the main force)
		# shows every name instead of just squeezing them onto one line.
		for i in range(squad_names.size()):
			var short = String(squad_names[i]).replace("Squad ", "")
			# Tag whichever squad is carrying the recovered data package —
			# previously invisible on the map entirely.
			if squad_names[i] == GameManager.data_carrier_squad:
				short += " 📦"
			draw_string(ThemeDB.fallback_font,
				center + Vector2(-len(short) * 2.8, 4 + i * SQUAD_LINE_HEIGHT),
				short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.85))

		# Enemy/placement markers below whatever squad names were just
		# drawn, so a busy (contested, multi-squad) hex doesn't overlap
		# its own labels.
		var below_names_y = 16 + max(0, squad_names.size() - 1) * SQUAD_LINE_HEIGHT

		if not placement_mode:
			if enemy_count > 0 and enemy_glitching:
				# Static burst — a couple of randomised noise glyphs standing
				# in for the marker while the sensor read is scrambled.
				const GLITCH_GLYPHS = ["▓", "▒", "░", "#", "%", "&", "¤"]
				var marker = ""
				for i in range(randi_range(1, 3)):
					marker += GLITCH_GLYPHS[randi() % GLITCH_GLYPHS.size()]
				draw_string(ThemeDB.fallback_font,
					center + Vector2(-len(marker) * 3.5, below_names_y),
					marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.6, randf_range(0.3, 0.9)))
			elif enemy_count > 0:
				var marker = "✕" if enemy_count == 1 else "✕×%d" % enemy_count
				draw_string(ThemeDB.fallback_font,
					center + Vector2(-len(marker) * 3.5, below_names_y),
					marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.4, 0.4, 0.95))
		else:
			# Placement mode — show the drop indicator on the hovered/
			# placed hex, but never let it hide whether an enemy is
			# actually standing there. A plain, non-pulsing marker (the
			# glitch/static variant is skipped here) keeps it readable
			# while you're aiming.
			var enemy_marker = ("✕" if enemy_count == 1 else "✕×%d" % enemy_count) if enemy_count > 0 else ""
			if sector == placed_sector:
				draw_string(ThemeDB.fallback_font,
					center + Vector2(-8, below_names_y),
					"▼ DROP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_PLACED)
				if enemy_marker != "":
					draw_string(ThemeDB.fallback_font,
						center + Vector2(-len(enemy_marker) * 3.5, below_names_y + 13),
						enemy_marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.4, 0.4, 0.95))
			elif sector == hovered_sector:
				draw_string(ThemeDB.fallback_font,
					center + Vector2(-8, below_names_y),
					"▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_PLACEMENT_HOVER)
				if enemy_marker != "":
					draw_string(ThemeDB.fallback_font,
						center + Vector2(-len(enemy_marker) * 3.5, below_names_y + 13),
						enemy_marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.4, 0.4, 0.95))
			elif enemy_marker != "":
				draw_string(ThemeDB.fallback_font,
					center + Vector2(-len(enemy_marker) * 3.5, below_names_y),
					enemy_marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.4, 0.4, 0.85))
		
		# Special sector symbols
		if not placement_mode and special_type != "":
			var symbol = ""
			var sym_color = Color.WHITE
			match special_type:
				"priority":
					symbol = "[!]"
					sym_color = Color(0.9, 0.6, 1.0, 0.95)
				"tower":
					symbol = "[T]"
					sym_color = Color(0.5, 0.95, 1.0, 0.9)
				"tower_powered":
					symbol = "[T]"
					sym_color = Color(0.0, 1.0, 0.8, 1.0)
				"extraction":
					symbol = "[EXT]"
					sym_color = Color(1.0, 0.9, 0.3, 1.0)
			if symbol != "":
				draw_string(ThemeDB.fallback_font,
					center + Vector2(-6, 26),
					symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, sym_color)


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
