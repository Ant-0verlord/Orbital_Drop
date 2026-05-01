extends Control
# =============================================================
# HoloMapPopup.gd
# Attach to: Control node named "HoloMapPopup" inside
#            Holomap.tscn > StaticBody3D
#
# Shows a grid of sector cards, colour-coded by status.
# Each sector shows which squad operates there and their
# last known status — subject to interference corruption.
# Updates automatically when a turn resolves.
# =============================================================

var player: Node = null

# Sector definitions — in a full game these would come from ZoneManager
# Each sector: { name, squad (squad name or ""), status }
# Status: "held", "contested", "lost", "unknown"
var sectors: Array = []


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	_build_ui()


func refresh() -> void:
	_sync_sectors()
	_rebuild_map()


# -------------------------------------------------------
# Sync sector data from SquadManager
# -------------------------------------------------------
func _sync_sectors() -> void:
	sectors.clear()
	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		var sector_status: String

		match squad.status:
			SquadManager.Status.ACTIVE:
				sector_status = "held"
			SquadManager.Status.WOUNDED:
				sector_status = "contested"
			SquadManager.Status.CRITICAL:
				sector_status = "contested"
			SquadManager.Status.LOST:
				sector_status = "lost"
			_:
				sector_status = "unknown"

		sectors.append({
			"name":   squad.sector,
			"squad":  squad_name,
			"status": sector_status,
			"squad_status": squad.status,
		})


# -------------------------------------------------------
# Build base UI
# -------------------------------------------------------
func _build_ui() -> void:
	custom_minimum_size = Vector2(580, 0)
	set_anchors_preset(Control.PRESET_CENTER)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "HOLO-MAP — PLANETARY THEATRE"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Interference warning
	var interference_lbl := Label.new()
	interference_lbl.name = "InterferenceLabel"
	interference_lbl.add_theme_font_size_override("font_size", 12)
	interference_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 0.2))
	vbox.add_child(interference_lbl)

	vbox.add_child(HSeparator.new())

	# Legend
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	vbox.add_child(legend)
	for pair in [["● HELD", Color(0.3, 0.7, 0.3)], ["● CONTESTED", Color(0.8, 0.6, 0.1)], ["● LOST", Color(0.7, 0.2, 0.2)], ["● UNKNOWN", Color(0.4, 0.4, 0.4)]]:
		var lbl := Label.new()
		lbl.text = pair[0]
		lbl.add_theme_color_override("font_color", pair[1])
		lbl.add_theme_font_size_override("font_size", 12)
		legend.add_child(lbl)

	vbox.add_child(HSeparator.new())

	# Sector grid
	var grid := GridContainer.new()
	grid.name = "SectorGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)

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
# Rebuild sector cards
# -------------------------------------------------------
func _rebuild_map() -> void:
	var grid = get_node_or_null("PanelContainer/VBoxContainer/SectorGrid")
	var interference_lbl = get_node_or_null("PanelContainer/VBoxContainer/InterferenceLabel")
	if grid == null:
		return

	for child in grid.get_children():
		child.queue_free()

	# Interference label
	var interference = SquadManager.interference
	if interference_lbl:
		if interference <= 0.0:
			interference_lbl.text = "Sensor array nominal — full resolution active."
		elif interference < 0.5:
			interference_lbl.text = "Minor sensor interference detected — some data may be imprecise."
		elif interference < 0.75:
			interference_lbl.text = "Significant interference — squad positions are approximate."
		else:
			interference_lbl.text = "SEVERE INTERFERENCE — map data is unreliable. Trust nothing."

	if sectors.is_empty():
		var lbl := Label.new()
		lbl.text = "No sector data available."
		grid.add_child(lbl)
		return

	for sector in sectors:
		grid.add_child(_make_sector_card(sector))


func _make_sector_card(sector: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _sector_style(sector.status))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(160, 100)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Sector name — may be corrupted at high interference
	var sector_name = sector.name
	if SquadManager.interference >= 0.75 and randf() < 0.4:
		sector_name = "[SECTOR UNKNOWN]"

	var name_lbl := Label.new()
	name_lbl.text = sector_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_lbl)

	# Status
	var status_lbl := Label.new()
	status_lbl.text = sector.status.to_upper()
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", _sector_text_color(sector.status))
	vbox.add_child(status_lbl)

	# Squad name — may be hidden by interference
	var squad_lbl := Label.new()
	if SquadManager.interference >= 0.5 and randf() < SquadManager.interference * 0.5:
		squad_lbl.text = "Unit: [SIGNAL LOST]"
		squad_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	else:
		squad_lbl.text = "Unit: %s" % sector.squad
	squad_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(squad_lbl)

	# Squad status
	if sector.has("squad_status") and sector.squad_status != SquadManager.Status.LOST:
		var sq_status_lbl := Label.new()
		sq_status_lbl.text = SquadManager.STATUS_NAMES[sector.squad_status]
		sq_status_lbl.add_theme_font_size_override("font_size", 11)
		sq_status_lbl.add_theme_color_override("font_color", _squad_status_color(sector.squad_status))
		vbox.add_child(sq_status_lbl)

	return card


# -------------------------------------------------------
# Styling
# -------------------------------------------------------
func _sector_style(status: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.border_width_bottom = 3
	style.border_width_top    = 0
	style.border_width_left   = 0
	style.border_width_right  = 0

	match status:
		"held":
			style.bg_color     = Color(0.10, 0.18, 0.10)
			style.border_color = Color(0.3, 0.7, 0.3)
		"contested":
			style.bg_color     = Color(0.18, 0.15, 0.05)
			style.border_color = Color(0.8, 0.6, 0.1)
		"lost":
			style.bg_color     = Color(0.18, 0.07, 0.07)
			style.border_color = Color(0.7, 0.2, 0.2)
		_:
			style.bg_color     = Color(0.12, 0.12, 0.12)
			style.border_color = Color(0.35, 0.35, 0.35)

	return style


func _sector_text_color(status: String) -> Color:
	match status:
		"held":      return Color(0.3, 0.8, 0.3)
		"contested": return Color(0.85, 0.65, 0.1)
		"lost":      return Color(0.8, 0.25, 0.25)
	return Color(0.5, 0.5, 0.5)


func _squad_status_color(status: int) -> Color:
	match status:
		SquadManager.Status.ACTIVE:   return Color(0.4, 0.9, 0.4)
		SquadManager.Status.WOUNDED:  return Color(0.9, 0.7, 0.2)
		SquadManager.Status.CRITICAL: return Color(0.9, 0.3, 0.3)
	return Color.WHITE


func _on_turn_resolved() -> void:
	if visible:
		refresh()


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
