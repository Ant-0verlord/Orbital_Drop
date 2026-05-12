extends Control
# =============================================================
# HoloMapPopup.gd
# =============================================================

var player: Node = null
var zone_states: Dictionary = {}
var pulse_time: float = 0.0
const PULSE_SPEED: float = 2.5

# Hex geometry
const HEX_RADIUS: float  = 38.0
const HEX_INNER: float   = 32.0
const GRID_CENTER: Vector2 = Vector2(310, 200)

var hex_entries: Array = []
var flicker_states: Dictionary = {}

const COLOR_HELD:         Color = Color(0.1,  0.8,  0.3,  0.85)
const COLOR_CONTESTED:    Color = Color(0.9,  0.7,  0.1,  0.85)
const COLOR_LOST:         Color = Color(0.4,  0.4,  0.4,  0.7)
const COLOR_ENEMY:        Color = Color(0.7,  0.1,  0.1,  0.85)
const COLOR_NEUTRAL:      Color = Color(0.12, 0.18, 0.25, 0.7)
const COLOR_BORDER:       Color = Color(0.4,  0.9,  1.0,  0.9)
const COLOR_ENEMY_BORDER: Color = Color(1.0,  0.3,  0.3,  1.0)
const COLOR_BG:           Color = Color(0.03, 0.06, 0.12, 1.0)
const COLOR_LABEL:        Color = Color(0.8,  1.0,  1.0,  1.0)

var turn_label: Label
var held_label: Label
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
	if held_label:
		var held = EnemyManager.get_held_count()
		var required = TurnManager.win_condition_hexes
		held_label.text = "Held: %d / %d required" % [held, required]
		held_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if held >= required else Color(0.9, 0.6, 0.2)
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
	custom_minimum_size = Vector2(650, 700)
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

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 20)
	vbox.add_child(info_row)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 12)
	turn_label.add_theme_color_override("font_color", Color(0.5, 0.75, 0.9))
	info_row.add_child(turn_label)

	held_label = Label.new()
	held_label.add_theme_font_size_override("font_size", 12)
	info_row.add_child(held_label)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	for pair in [["● Held", COLOR_HELD], ["● Contested", COLOR_CONTESTED], ["● Enemy", COLOR_ENEMY], ["● Neutral", COLOR_NEUTRAL]]:
		var lbl := Label.new()
		lbl.text = pair[0]
		lbl.add_theme_color_override("font_color", pair[1])
		lbl.add_theme_font_size_override("font_size", 11)
		legend.add_child(lbl)
	vbox.add_child(legend)

	var hex_canvas := Control.new()
	hex_canvas.custom_minimum_size = Vector2(630, 410)
	hex_canvas.name = "HexCanvas"
	vbox.add_child(hex_canvas)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 130
	vbox.add_child(scroll)

	sector_list = VBoxContainer.new()
	sector_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sector_list.add_theme_constant_override("separation", 2)
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
# Build 14-hex layout with correct flat-top spacing
# Centre + Ring 1 (6) + Ring 2 (7)
# -------------------------------------------------------
func _build_hex_layout() -> void:
	hex_entries.clear()
	var sectors = zone_states.keys()
	if sectors.is_empty():
		return

	# Flat-top hex spacing
	var w = HEX_RADIUS * 2.0          # hex width
	var h = HEX_RADIUS * sqrt(3.0)    # hex height
	var col_step = w * 0.75            # horizontal step
	var row_step = h                   # vertical step

	# 14 positions in axial-style flat-top layout
	# Using cube coordinates converted to pixel
	var hex_coords = [
		Vector2(0,   0),    # 0 centre
		Vector2(1,  -0.5),  # 1
		Vector2(1,   0.5),  # 2  ring 1 — clockwise from top-right
		Vector2(0,   1),    # 3
		Vector2(-1,  0.5),  # 4
		Vector2(-1, -0.5),  # 5
		Vector2(0,  -1),    # 6
		Vector2(2,   0),    # 7  ring 2
		Vector2(2,   1),    # 8
		Vector2(1,   1.5),  # 9
		Vector2(0,   2),    # 10
		Vector2(-1,  1.5),  # 11
		Vector2(-2,  1),    # 12
		Vector2(-2,  0),    # 13
	]

	var canvas_offset = Vector2(10, 105)

	for i in range(min(sectors.size(), hex_coords.size())):
		var coord = hex_coords[i]
		var pixel = Vector2(
			coord.x * col_step,
			coord.y * row_step
		)
		hex_entries.append({
			"sector": sectors[i],
			"center": canvas_offset + GRID_CENTER + pixel,
		})


func _draw() -> void:
	if not visible:
		return

	draw_rect(Rect2(Vector2(10, 100), Vector2(630, 410)), COLOR_BG, true)
	draw_rect(Rect2(Vector2(10, 100), Vector2(630, 410)), COLOR_BORDER * Color(1,1,1,0.2), false, 1.0)

	for x in range(10, 640, 36):
		draw_line(Vector2(x, 100), Vector2(x, 510), Color(0.2, 0.4, 0.5, 0.08), 0.5)
	for y in range(100, 510, 36):
		draw_line(Vector2(10, y), Vector2(640, y), Color(0.2, 0.4, 0.5, 0.08), 0.5)

	var interference = SquadManager.interference

	for entry in hex_entries:
		var center: Vector2 = entry.center
		var sector: String  = entry.sector
		var data = zone_states.get(sector, {})
		var state: String   = data.get("state", "enemy")
		var squad: String   = data.get("squad", "")
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
			var pulse = sin(pulse_time * 1.6) * 0.5 + 0.5
			fill.a = lerp(0.6, 1.0, pulse)

		draw_colored_polygon(_hex_points(center, HEX_INNER), fill)

		var border = COLOR_BORDER
		if enemy_count > 0 and enemy_visible:
			border = COLOR_ENEMY_BORDER.lerp(Color(1,0.5,0.5,1), sin(pulse_time * 1.6) * 0.3)
		elif state == "contested":
			border = Color(1.0, 0.85, 0.2, 0.9)
		elif state in ["enemy", "neutral"]:
			border = Color(0.3, 0.4, 0.5, 0.5)
		_draw_hex_border(center, HEX_RADIUS - 1.0, border, 1.5)

		# Sector label
		var lc = COLOR_LABEL if state not in ["enemy", "neutral"] else Color(0.55, 0.65, 0.7)
		draw_string(ThemeDB.fallback_font, center + Vector2(-len(sector)*3.0, -7),
			sector, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, lc)

		# Squad label
		if squad != "":
			var short = squad.replace("Squad ", "")
			draw_string(ThemeDB.fallback_font, center + Vector2(-len(short)*2.8, 4),
				short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1,1,1,0.7))

		# Enemy marker
		if enemy_count > 0 and enemy_visible:
			var marker = "✕" if enemy_count == 1 else "✕×%d" % enemy_count
			draw_string(ThemeDB.fallback_font, center + Vector2(-len(marker)*3.5, 16),
				marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.4, 0.4, 0.95))
		elif enemy_count > 0 and not enemy_visible:
			draw_string(ThemeDB.fallback_font, center + Vector2(-6, 16),
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
		draw_line(pts[i], pts[(i+1)%6], color, width)


func _state_color(state: String) -> Color:
	match state:
		"held":      return COLOR_HELD
		"contested": return COLOR_CONTESTED
		"lost":      return COLOR_LOST
		"enemy":     return COLOR_ENEMY
		"neutral":   return COLOR_NEUTRAL
	return COLOR_NEUTRAL


func _rebuild_sector_list() -> void:
	for child in sector_list.get_children():
		child.queue_free()

	for sector_name in zone_states:
		var data        = zone_states[sector_name]
		var state       = data.get("state", "enemy")
		var squad       = data.get("squad", "")
		var enemy_count = data.get("enemy_count", 0)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color", COLOR_ENEMY if enemy_count > 0 else _state_color(state))
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
		state_lbl.custom_minimum_size.x = 90
		state_lbl.add_theme_color_override("font_color", COLOR_ENEMY if enemy_count > 0 else _state_color(state))
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
