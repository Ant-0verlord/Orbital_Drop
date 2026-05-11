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

# Hex sizing — slightly smaller to fit 14 hexes comfortably
const HEX_RADIUS: float  = 38.0
const HEX_INNER: float   = 32.0

# Grid centre — centred in the 620px wide canvas
const GRID_CENTER: Vector2 = Vector2(310, 200)
const CANVAS_TOP: float    = 95.0
const CANVAS_H: float      = 390.0

var hex_entries: Array = []
var flicker_states: Dictionary = {}

const COLOR_HELD:         Color = Color(0.1,  0.8,  0.3,  0.85)
const COLOR_CONTESTED:    Color = Color(0.9,  0.7,  0.1,  0.85)
const COLOR_LOST:         Color = Color(0.35, 0.35, 0.35, 0.7)
const COLOR_UNKNOWN:      Color = Color(0.10, 0.15, 0.22, 0.7)
const COLOR_ENEMY:        Color = Color(0.75, 0.1,  0.1,  0.85)
const COLOR_BORDER:       Color = Color(0.4,  0.9,  1.0,  0.9)
const COLOR_ENEMY_BORDER: Color = Color(1.0,  0.25, 0.25, 1.0)
const COLOR_BG:           Color = Color(0.03, 0.06, 0.12, 1.0)
const COLOR_LABEL:        Color = Color(0.8,  1.0,  1.0,  1.0)

var turn_label: Label
var win_label: Label
var sector_list: VBoxContainer


func _ready() -> void:
	_build_ui()
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	EnemyManager.enemies_updated.connect(_on_enemies_updated)


func refresh(new_zone_states: Dictionary) -> void:
	zone_states = new_zone_states
	_build_hex_layout()
	_rebuild_sector_list()
	if turn_label:
		turn_label.text = "Turn %d / %d" % [TurnManager.current_turn, TurnManager.max_turns]
	if win_label:
		var held = GameManager.count_held_hexes(zone_states)
		var needed = GameManager.get_win_hex_count()
		win_label.text = "Held: %d / %d needed to win" % [held, needed]
		win_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if held >= needed else Color(0.9, 0.5, 0.2)
		)
	queue_redraw()


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


func _on_turn_resolved() -> void:
	if visible:
		queue_redraw()


func _on_enemies_updated() -> void:
	if visible:
		queue_redraw()


func _build_ui() -> void:
	custom_minimum_size = Vector2(640, 700)
	set_anchors_preset(Control.PRESET_CENTER)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 6)
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

	win_label = Label.new()
	win_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(win_label)

	# Legend
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	for pair in [
		["● Held", COLOR_HELD], ["● Contested", COLOR_CONTESTED],
		["● Enemy", COLOR_ENEMY], ["● Lost", COLOR_LOST], ["● Unknown", COLOR_UNKNOWN],
	]:
		var lbl := Label.new()
		lbl.text = pair[0]
		lbl.add_theme_color_override("font_color", pair[1])
		lbl.add_theme_font_size_override("font_size", 11)
		legend.add_child(lbl)
	vbox.add_child(legend)

	# Hex canvas
	var hex_canvas := Control.new()
	hex_canvas.custom_minimum_size = Vector2(620, CANVAS_H)
	hex_canvas.name = "HexCanvas"
	vbox.add_child(hex_canvas)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 130
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


# -------------------------------------------------------
# 14-hex layout — precise flat-top hex positions
# Centre + ring 1 (6 hexes) + ring 2 (7 hexes)
# -------------------------------------------------------
func _build_hex_layout() -> void:
	hex_entries.clear()
	var sectors = zone_states.keys()
	if sectors.is_empty():
		return

	# Flat-top hex: horizontal spacing = HEX_RADIUS * 2 * 0.866 ... actually:
	# For flat-top: col spacing = HEX_RADIUS * sqrt(3), row spacing = HEX_RADIUS * 1.5
	# But we use axial coordinates mapped to pixel positions

	var S = HEX_RADIUS * 1.85  # spacing multiplier

	# Ring 0: centre
	var positions: Array = [Vector2.ZERO]

	# Ring 1: 6 hexes around centre
	var ring1 = [
		Vector2(S, 0),
		Vector2(S * 0.5, -S * 0.866),
		Vector2(-S * 0.5, -S * 0.866),
		Vector2(-S, 0),
		Vector2(-S * 0.5, S * 0.866),
		Vector2(S * 0.5, S * 0.866),
	]
	for p in ring1:
		positions.append(p)

	# Ring 2: 7 hexes — outer arc, skipping bottom-right to keep map roughly circular
	var ring2 = [
		Vector2(S * 1.0, -S * 1.732),   # top-right
		Vector2(0,        -S * 1.732),   # top
		Vector2(-S * 1.0, -S * 1.732),  # top-left
		Vector2(-S * 2.0, 0),            # left
		Vector2(-S * 1.0, S * 1.732),   # bottom-left
		Vector2(0,         S * 1.732),   # bottom
		Vector2(S * 1.0,  S * 1.732),   # bottom-right
	]
	for p in ring2:
		positions.append(p)

	var canvas_offset = Vector2(10, CANVAS_TOP)

	for i in range(min(sectors.size(), positions.size())):
		hex_entries.append({
			"sector": sectors[i],
			"center": canvas_offset + GRID_CENTER + positions[i],
		})


# -------------------------------------------------------
# Draw
# -------------------------------------------------------
func _draw() -> void:
	if not visible:
		return

	draw_rect(Rect2(Vector2(10, CANVAS_TOP), Vector2(620, CANVAS_H)), COLOR_BG, true)
	draw_rect(Rect2(Vector2(10, CANVAS_TOP), Vector2(620, CANVAS_H)), COLOR_BORDER * Color(1,1,1,0.2), false, 1.0)

	for x in range(10, 630, 36):
		draw_line(Vector2(x, CANVAS_TOP), Vector2(x, CANVAS_TOP + CANVAS_H), Color(0.2, 0.4, 0.5, 0.08), 0.5)
	for y in range(int(CANVAS_TOP), int(CANVAS_TOP + CANVAS_H), 36):
		draw_line(Vector2(10, y), Vector2(630, y), Color(0.2, 0.4, 0.5, 0.08), 0.5)

	var interference = SquadManager.interference

	for entry in hex_entries:
		var center: Vector2 = entry.center
		var sector: String  = entry.sector
		var data = zone_states.get(sector, {})
		var state: String    = data.get("state", "unknown")
		var squad: String    = data.get("squad", "")
		var enemy_count: int = data.get("enemy_count", 0)

		var enemy_visible = true
		if enemy_count > 0 and interference > 0.2:
			enemy_visible = flicker_states.get(sector, true)

		var fill = _state_color(state)

		if enemy_count > 0 and enemy_visible:
			if state in ["held", "contested"]:
				fill = fill.lerp(COLOR_ENEMY, 0.55)
			else:
				fill = COLOR_ENEMY

		if state == "contested" and enemy_count == 0:
			var pulse = sin(pulse_time) * 0.5 + 0.5
			fill.a = lerp(0.5, 0.95, pulse)
			fill = fill.lerp(Color(1.0, 0.95, 0.4, fill.a), pulse * 0.25)

		if enemy_count > 0 and enemy_visible:
			var pulse = sin(pulse_time * 1.8) * 0.5 + 0.5
			fill.a = lerp(0.65, 1.0, pulse)

		draw_colored_polygon(_hex_points(center, HEX_INNER), fill)

		var border = COLOR_BORDER
		if enemy_count > 0 and enemy_visible:
			border = COLOR_ENEMY_BORDER.lerp(Color(1,1,1,1), sin(pulse_time * 1.8) * 0.25)
		elif state == "contested":
			border = Color(1.0, 0.85, 0.2, 0.9)
		elif state == "unknown":
			border = Color(0.25, 0.4, 0.5, 0.35)
		_draw_hex_border(center, HEX_RADIUS - 1.0, border, 1.5)

		var label_color = COLOR_LABEL if state != "unknown" else Color(0.4, 0.5, 0.58)
		draw_string(ThemeDB.fallback_font,
			center + Vector2(-len(sector) * 3.0, -7),
			sector, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, label_color)

		if squad != "":
			var short = squad.replace("Squad ", "")
			draw_string(ThemeDB.fallback_font,
				center + Vector2(-len(short) * 2.8, 4),
				short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1,1,1,0.7))

		if enemy_count > 0 and enemy_visible:
			var marker = "✕" if enemy_count == 1 else "✕×%d" % enemy_count
			draw_string(ThemeDB.fallback_font,
				center + Vector2(-len(marker) * 3.2, 15),
				marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.4, 0.4, 0.95))
		elif enemy_count > 0 and not enemy_visible:
			draw_string(ThemeDB.fallback_font,
				center + Vector2(-6, 15),
				"░░", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.3, 0.3, 0.4))


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
	return COLOR_UNKNOWN


func _rebuild_sector_list() -> void:
	for child in sector_list.get_children():
		child.queue_free()

	for sector_name in zone_states:
		var data        = zone_states[sector_name]
		var state       = data.get("state", "unknown")
		var squad       = data.get("squad", "")
		var enemy_count = data.get("enemy_count", 0)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color",
			COLOR_ENEMY if enemy_count > 0 else _state_color(state))
		dot.add_theme_font_size_override("font_size", 11)
		dot.custom_minimum_size.x = 16
		row.add_child(dot)

		var sec_lbl := Label.new()
		sec_lbl.text = sector_name
		sec_lbl.custom_minimum_size.x = 95
		sec_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(sec_lbl)

		var state_text = "Enemy (%d)" % enemy_count if enemy_count > 0 else state.capitalize()
		var state_lbl := Label.new()
		state_lbl.text = state_text
		state_lbl.custom_minimum_size.x = 95
		state_lbl.add_theme_color_override("font_color",
			COLOR_ENEMY if enemy_count > 0 else _state_color(state))
		state_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(state_lbl)

		var squad_lbl := Label.new()
		squad_lbl.text = squad if squad != "" else "—"
		squad_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		squad_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(squad_lbl)

		sector_list.add_child(row)


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
