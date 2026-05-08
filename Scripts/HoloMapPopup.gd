extends Control
# =============================================================
# HoloMapPopup.gd
# Attach to: Control node named "HoloMapPopup" inside
#            Holomap.tscn > StaticBody3D
# =============================================================

var player: Node = null
var zone_states: Dictionary = {}

var pulse_time: float = 0.0
const PULSE_SPEED: float = 2.5

const HEX_RADIUS: float  = 44.0
const HEX_INNER: float   = 38.0
const GRID_CENTER: Vector2 = Vector2(285, 160)

var hex_entries: Array = []

const COLOR_HELD:      Color = Color(0.1,  0.8,  0.3,  0.85)
const COLOR_CONTESTED: Color = Color(0.9,  0.7,  0.1,  0.85)
const COLOR_LOST:      Color = Color(0.8,  0.15, 0.1,  0.85)
const COLOR_UNKNOWN:   Color = Color(0.12, 0.18, 0.25, 0.7)
const COLOR_BORDER:    Color = Color(0.4,  0.9,  1.0,  0.9)
const COLOR_BG:        Color = Color(0.03, 0.06, 0.12, 1.0)
const COLOR_LABEL:     Color = Color(0.8,  1.0,  1.0,  1.0)

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


func _build_ui() -> void:
	custom_minimum_size = Vector2(620, 660)
	set_anchors_preset(Control.PRESET_CENTER)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "HOLO-MAP — PLANETARY THEATRE"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.6, 0.95, 1.0))
	vbox.add_child(title)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 12)
	turn_label.add_theme_color_override("font_color", Color(0.5, 0.75, 0.9))
	vbox.add_child(turn_label)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	for pair in [["● Held", COLOR_HELD], ["● Contested", COLOR_CONTESTED], ["● Lost", COLOR_LOST], ["● Unknown", COLOR_UNKNOWN]]:
		var lbl := Label.new()
		lbl.text = pair[0]
		lbl.add_theme_color_override("font_color", pair[1])
		lbl.add_theme_font_size_override("font_size", 12)
		legend.add_child(lbl)
	vbox.add_child(legend)

	# Hex canvas area
	var hex_canvas := Control.new()
	hex_canvas.custom_minimum_size = Vector2(600, 370)
	hex_canvas.name = "HexCanvas"
	vbox.add_child(hex_canvas)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 110
	vbox.add_child(scroll)

	sector_list = VBoxContainer.new()
	sector_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sector_list.add_theme_constant_override("separation", 3)
	scroll.add_child(sector_list)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)


func _build_hex_layout() -> void:
	hex_entries.clear()
	var sectors = zone_states.keys()

	# Hex grid positions: centre + ring 1 (6) + ring 2 (partial)
	# Arranged to fill a 7-hex map nicely, expanding outward
	var offsets: Array = [Vector2.ZERO]

	var ring1 = [
		Vector2(1, 0), Vector2(0.5, -0.866),
		Vector2(-0.5, -0.866), Vector2(-1, 0),
		Vector2(-0.5, 0.866), Vector2(0.5, 0.866)
	]
	for d in ring1:
		offsets.append(d * HEX_RADIUS * 1.95)

	# Second ring for larger maps
	if sectors.size() > 7:
		var ring2 = [
			Vector2(1.5, -0.866 * 1.73), Vector2(0, -0.866 * 2.0),
			Vector2(-1.5, -0.866 * 1.73), Vector2(-2.0, 0),
			Vector2(-1.5, 0.866 * 1.73), Vector2(0, 0.866 * 2.0),
			Vector2(1.5, 0.866 * 1.73), Vector2(2.0, 0),
		]
		for d in ring2:
			offsets.append(d * HEX_RADIUS * 0.98)

	var canvas_offset = Vector2(10, 108)

	for i in range(min(sectors.size(), offsets.size())):
		hex_entries.append({
			"sector": sectors[i],
			"center": canvas_offset + GRID_CENTER + offsets[i],
		})


func _draw() -> void:
	if not visible:
		return

	# Background
	draw_rect(Rect2(Vector2(10, 100), Vector2(600, 370)), COLOR_BG, true)
	draw_rect(Rect2(Vector2(10, 100), Vector2(600, 370)), COLOR_BORDER * Color(1,1,1,0.25), false, 1.0)

	# Grid lines
	for x in range(10, 610, 38):
		draw_line(Vector2(x, 100), Vector2(x, 470), Color(0.2, 0.4, 0.5, 0.12), 0.5)
	for y in range(100, 470, 38):
		draw_line(Vector2(10, y), Vector2(610, y), Color(0.2, 0.4, 0.5, 0.12), 0.5)

	for entry in hex_entries:
		var center: Vector2 = entry.center
		var sector: String  = entry.sector
		var data = zone_states.get(sector, {})
		var state: String   = data.get("state", "unknown")
		var squad: String   = data.get("squad", "")

		var fill = _state_color(state)

		if state == "contested":
			var pulse = sin(pulse_time) * 0.5 + 0.5
			fill.a = lerp(0.5, 0.95, pulse)
			fill = fill.lerp(Color(1.0, 0.95, 0.4, fill.a), pulse * 0.25)

		var pts = _hex_points(center, HEX_INNER)
		draw_colored_polygon(pts, fill)

		var border = COLOR_BORDER if state != "unknown" else Color(0.3, 0.5, 0.6, 0.5)
		if state == "contested":
			border = Color(1.0, 0.85, 0.2, 0.9 + sin(pulse_time) * 0.1)
		_draw_hex_border(center, HEX_RADIUS - 1.0, border, 1.5)

		# Sector label
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-len(sector) * 3.2, -6),
			sector, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			COLOR_LABEL if state != "unknown" else Color(0.5, 0.6, 0.65)
		)

		# Squad label
		if squad != "":
			var short = squad.replace("Squad ", "")
			draw_string(
				ThemeDB.fallback_font,
				center + Vector2(-len(short) * 2.8, 7),
				short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.65)
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
		dot.add_theme_font_size_override("font_size", 12)
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
