extends Control
# =============================================================
# HoloMapPopup.gd
# Attach to: Control node named "HoloMapPopup" inside
#            Holomap.tscn > StaticBody3D
#
# Draws a hex grid directly using _draw().
# Hex colours update each turn based on squad status.
# Contested hexes pulse.
# =============================================================

var player: Node = null
var zone_states: Dictionary = {}

# Pulse animation
var pulse_time: float = 0.0
const PULSE_SPEED: float = 2.5

# Hex layout
const HEX_RADIUS: float   = 48.0
const HEX_INNER: float    = 42.0
const GRID_CENTER: Vector2 = Vector2(280, 160) # Centre of hex grid within popup

# Hex position data — built in refresh()
var hex_entries: Array = []  # [{ "sector", "center" }]

# Colours
const COLOR_HELD:      Color = Color(0.1,  0.8,  0.3,  0.85)
const COLOR_CONTESTED: Color = Color(0.9,  0.7,  0.1,  0.85)
const COLOR_LOST:      Color = Color(0.8,  0.15, 0.1,  0.85)
const COLOR_UNKNOWN:   Color = Color(0.15, 0.25, 0.35, 0.7)
const COLOR_BORDER:    Color = Color(0.4,  0.9,  1.0,  0.9)
const COLOR_BG:        Color = Color(0.03, 0.06, 0.12, 1.0)
const COLOR_LABEL:     Color = Color(0.8,  1.0,  1.0,  1.0)

# UI references
var turn_label: Label
var sector_list: VBoxContainer


func _ready() -> void:
	_build_ui()
	SquadManager.turn_resolved.connect(_on_turn_resolved)


func refresh(new_zone_states: Dictionary) -> void:
	zone_states = new_zone_states
	_build_hex_layout()
	_rebuild_sector_list()
	if turn_label:
		turn_label.text = "Turn %d / %d" % [TurnManager.current_turn, TurnManager.max_turns]
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		pulse_time += delta * PULSE_SPEED
		queue_redraw()


func _on_turn_resolved() -> void:
	if visible:
		queue_redraw()


# -------------------------------------------------------
# Build UI shell — hex grid drawn via _draw(), list below
# -------------------------------------------------------
func _build_ui() -> void:
	custom_minimum_size = Vector2(580, 620)
	set_anchors_preset(Control.PRESET_CENTER)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "HOLO-MAP — PLANETARY THEATRE"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	vbox.add_child(title)

	# Turn label
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 12)
	turn_label.add_theme_color_override("font_color", Color(0.5, 0.75, 0.9))
	vbox.add_child(turn_label)

	# Legend
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 20)
	for pair in [["● Held", COLOR_HELD], ["● Contested", COLOR_CONTESTED], ["● Lost", COLOR_LOST], ["● Unknown", COLOR_UNKNOWN]]:
		var lbl := Label.new()
		lbl.text = pair[0]
		lbl.add_theme_color_override("font_color", pair[1])
		lbl.add_theme_font_size_override("font_size", 12)
		legend.add_child(lbl)
	vbox.add_child(legend)

	# Hex canvas — fixed size area where _draw() renders the hex grid
	var hex_canvas := Control.new()
	hex_canvas.custom_minimum_size = Vector2(560, 340)
	hex_canvas.name = "HexCanvas"
	# _draw() on this node is handled by drawing on self (HoloMapPopup)
	# We use a SubControl trick — draw on self but offset by the canvas position
	vbox.add_child(hex_canvas)

	vbox.add_child(HSeparator.new())

	# Sector list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 120
	vbox.add_child(scroll)

	sector_list = VBoxContainer.new()
	sector_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sector_list.add_theme_constant_override("separation", 4)
	scroll.add_child(sector_list)

	vbox.add_child(HSeparator.new())

	# Close button
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)


# -------------------------------------------------------
# Build hex center positions from zone_states keys
# -------------------------------------------------------
func _build_hex_layout() -> void:
	hex_entries.clear()
	var sectors = zone_states.keys()

	# Hex grid: centre + up to 6 around it + up to 12 in second ring
	var offsets: Array = [Vector2.ZERO]

	var directions = [
		Vector2(1, 0), Vector2(0.5, -0.866),
		Vector2(-0.5, -0.866), Vector2(-1, 0),
		Vector2(-0.5, 0.866), Vector2(0.5, 0.866)
	]
	for d in directions:
		offsets.append(d * HEX_RADIUS * 1.9)

	# Second ring if more than 7 sectors
	if sectors.size() > 7:
		var second = [
			Vector2(1.5, -0.866 * 1.73), Vector2(0, -0.866 * 2),
			Vector2(-1.5, -0.866 * 1.73), Vector2(-2, 0),
			Vector2(-1.5, 0.866 * 1.73), Vector2(0, 0.866 * 2),
			Vector2(1.5, 0.866 * 1.73), Vector2(2, 0),
		]
		for d in second:
			offsets.append(d * HEX_RADIUS * 0.97)

	# Find hex canvas offset in our coordinate space
	var canvas_offset = Vector2(10, 110)  # approximate top of hex canvas area

	for i in range(min(sectors.size(), offsets.size())):
		hex_entries.append({
			"sector": sectors[i],
			"center": canvas_offset + GRID_CENTER + offsets[i] * 0.95,
		})


# -------------------------------------------------------
# Draw hex grid
# -------------------------------------------------------
func _draw() -> void:
	if not visible:
		return

	# Background panel for hex area
	draw_rect(Rect2(Vector2(10, 100), Vector2(560, 340)), COLOR_BG, true)
	draw_rect(Rect2(Vector2(10, 100), Vector2(560, 340)), COLOR_BORDER * Color(1,1,1,0.3), false, 1.0)

	# Subtle grid lines
	for x in range(10, 570, 35):
		draw_line(Vector2(x, 100), Vector2(x, 440), Color(0.2, 0.4, 0.5, 0.15), 0.5)
	for y in range(100, 440, 35):
		draw_line(Vector2(10, y), Vector2(570, y), Color(0.2, 0.4, 0.5, 0.15), 0.5)

	for entry in hex_entries:
		var center: Vector2 = entry.center
		var sector: String  = entry.sector
		var data = zone_states.get(sector, {})
		var state: String   = data.get("state", "unknown")
		var squad: String   = data.get("squad", "")

		var fill = _state_color(state)

		# Pulse for contested
		if state == "contested":
			var pulse = sin(pulse_time) * 0.5 + 0.5
			fill.a = lerp(0.5, 0.95, pulse)
			fill = fill.lerp(Color(1.0, 0.95, 0.4, fill.a), pulse * 0.25)

		# Fill
		var pts = _hex_points(center, HEX_INNER)
		draw_colored_polygon(pts, fill)

		# Border
		var border = COLOR_BORDER
		if state == "contested":
			border = Color(1.0, 0.85, 0.2, 0.9 + sin(pulse_time) * 0.1)
		_draw_hex_border(center, HEX_RADIUS - 1.0, border, 1.5)

		# Sector label
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-len(sector) * 3.5, -6),
			sector, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_LABEL
		)

		# Squad label
		if squad != "":
			var short = squad.replace("Squad ", "")
			draw_string(
				ThemeDB.fallback_font,
				center + Vector2(-len(short) * 3.0, 8),
				short, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.7)
			)


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
	return COLOR_UNKNOWN


# -------------------------------------------------------
# Sector list below the hex grid
# -------------------------------------------------------
func _rebuild_sector_list() -> void:
	for child in sector_list.get_children():
		child.queue_free()

	for sector_name in zone_states:
		var data  = zone_states[sector_name]
		var state = data.get("state", "unknown")
		var squad = data.get("squad", "")

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color", _state_color(state))
		dot.add_theme_font_size_override("font_size", 13)
		dot.custom_minimum_size.x = 18
		row.add_child(dot)

		var sec_lbl := Label.new()
		sec_lbl.text = sector_name
		sec_lbl.custom_minimum_size.x = 100
		sec_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(sec_lbl)

		var state_lbl := Label.new()
		state_lbl.text = state.capitalize()
		state_lbl.custom_minimum_size.x = 90
		state_lbl.add_theme_color_override("font_color", _state_color(state))
		state_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(state_lbl)

		var squad_lbl := Label.new()
		squad_lbl.text = squad if squad != "" else "—"
		squad_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		squad_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(squad_lbl)

		sector_list.add_child(row)


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
