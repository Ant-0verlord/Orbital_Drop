extends Control
# =============================================================
# IntelConsolePopup.gd
# Attach to: Control node named "IntelConsolePopup" inside
#            Intel_Desk.tscn > StaticBody3D
# =============================================================

var player: Node = null


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	_build_ui()


func refresh() -> void:
	_rebuild_reports()


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

	var title := Label.new()
	title.text = "INTEL CONSOLE"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var turn_lbl := Label.new()
	turn_lbl.name = "TurnLabel"
	turn_lbl.add_theme_font_size_override("font_size", 13)
	turn_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(turn_lbl)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 340
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var report_container := VBoxContainer.new()
	report_container.name = "ReportContainer"
	report_container.add_theme_constant_override("separation", 8)
	report_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(report_container)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)


# -------------------------------------------------------
# Rebuild report cards each time popup opens or turn resolves
# -------------------------------------------------------
func _rebuild_reports() -> void:
	var turn_lbl = get_node_or_null("PanelContainer/VBoxContainer/TurnLabel")
	var container = get_node_or_null("PanelContainer/VBoxContainer/ScrollContainer/ReportContainer")
	if turn_lbl == null or container == null:
		return

	turn_lbl.text = (
		"Pre-mission briefing — awaiting deployment"
		if SquadManager.current_turn == 0
		else "Surface intel — Turn %d" % SquadManager.current_turn
	)

	for child in container.get_children():
		child.queue_free()

	var reports: Dictionary = (
		SquadManager.get_briefings()
		if SquadManager.current_turn == 0
		else SquadManager.get_reports()
	)

	if reports.is_empty():
		var lbl := Label.new()
		lbl.text = "No intel available."
		container.add_child(lbl)
		return

	for squad_name in reports:
		var squad_data = SquadManager.squads.get(squad_name, {})
		_add_report_card(container, squad_name, reports[squad_name], squad_data)


func _add_report_card(container: Node, squad_name: String, report_text: String, squad_data: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(squad_data))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Header: name + status
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = squad_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	header.add_child(name_lbl)

	if squad_data.has("status"):
		var status_lbl := Label.new()
		status_lbl.text = "[%s]" % SquadManager.STATUS_NAMES[squad_data.status]
		status_lbl.add_theme_font_size_override("font_size", 12)
		status_lbl.add_theme_color_override("font_color", _status_color(squad_data.status))
		header.add_child(status_lbl)

	# Need — may be corrupted
	if squad_data.has("need") and squad_data.has("status") and squad_data.status != SquadManager.Status.LOST:
		var need_str = SquadManager.get_need_display(squad_name)
		var need_lbl := Label.new()
		need_lbl.text = "Requesting: %s" % need_str
		need_lbl.add_theme_font_size_override("font_size", 12)
		need_lbl.add_theme_color_override("font_color",
			Color(0.45, 0.45, 0.45) if need_str == "[INTERFERENCE]" else Color(0.9, 0.75, 0.3)
		)
		vbox.add_child(need_lbl)

	# Report body
	var report_lbl := Label.new()
	report_lbl.text = report_text
	report_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	report_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(report_lbl)

	container.add_child(card)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	container.add_child(spacer)


# -------------------------------------------------------
# Styling
# -------------------------------------------------------
func _card_style(squad_data: Dictionary) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.corner_radius_top_left    = 4
	style.corner_radius_top_right   = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.border_width_left   = 3
	style.border_width_top    = 0
	style.border_width_right  = 0
	style.border_width_bottom = 0

	if squad_data.has("status"):
		match squad_data.status:
			SquadManager.Status.ACTIVE:
				style.bg_color     = Color(0.13, 0.20, 0.13)
				style.border_color = Color(0.3, 0.65, 0.3)
			SquadManager.Status.WOUNDED:
				style.bg_color     = Color(0.20, 0.17, 0.08)
				style.border_color = Color(0.85, 0.6, 0.15)
			SquadManager.Status.CRITICAL:
				style.bg_color     = Color(0.22, 0.08, 0.08)
				style.border_color = Color(0.9, 0.2, 0.2)
			SquadManager.Status.LOST:
				style.bg_color     = Color(0.10, 0.10, 0.10)
				style.border_color = Color(0.35, 0.35, 0.35)
	else:
		style.bg_color     = Color(0.13, 0.13, 0.18)
		style.border_color = Color(0.4, 0.4, 0.55)

	return style


func _status_color(status: int) -> Color:
	match status:
		SquadManager.Status.ACTIVE:   return Color(0.4, 0.9, 0.4)
		SquadManager.Status.WOUNDED:  return Color(0.9, 0.7, 0.2)
		SquadManager.Status.CRITICAL: return Color(0.9, 0.3, 0.3)
		SquadManager.Status.LOST:     return Color(0.5, 0.5, 0.5)
	return Color.WHITE


func _on_turn_resolved() -> void:
	if visible:
		_rebuild_reports()


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
