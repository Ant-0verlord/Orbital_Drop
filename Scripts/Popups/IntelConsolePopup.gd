extends Control
# =============================================================
# IntelConsolePopup.gd
# UI built in scene, not in code.
#
# Shows what happened last turn and squad status.
# Squad NEEDS are NOT shown here — check the Vox-Caster.
# =============================================================

var player: Node = null

@onready var turn_label: Label              = $PanelContainer/VBoxContainer/TurnLabel
@onready var report_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/ReportContainer
@onready var close_btn: Button              = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	close_btn.pressed.connect(_on_close_pressed)


func _on_turn_started(_turn: int) -> void:
	if visible:
		refresh()


func _on_turn_resolved() -> void:
	if visible:
		_rebuild_reports()


func refresh() -> void:
	_rebuild_reports()


func _rebuild_reports() -> void:
	if SquadManager.squads.is_empty():
		return

	if turn_label:
		turn_label.text = (
			"Pre-mission briefing — awaiting deployment"
			if SquadManager.current_turn == 0
			else "Surface intel — Turn %d" % SquadManager.current_turn
		)

	for child in report_container.get_children():
		child.queue_free()

	var reports: Dictionary = (
		SquadManager.get_briefings()
		if SquadManager.current_turn == 0
		else SquadManager.get_reports()
	)

	if reports.is_empty():
		var lbl := Label.new()
		lbl.text = "No intel available."
		report_container.add_child(lbl)
		return

	for squad_name in reports:
		var squad_data = SquadManager.squads.get(squad_name, {})
		_add_report_card(squad_name, reports[squad_name], squad_data)


func _add_report_card(squad_name: String, report_text: String, squad_data: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(squad_data))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

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

	if squad_data.has("sector"):
		var sector_lbl := Label.new()
		sector_lbl.text = squad_data.sector
		sector_lbl.add_theme_font_size_override("font_size", 11)
		sector_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		header.add_child(sector_lbl)

	var report_lbl := Label.new()
	report_lbl.text = report_text
	report_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	report_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(report_lbl)

	report_container.add_child(card)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	report_container.add_child(spacer)


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


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
