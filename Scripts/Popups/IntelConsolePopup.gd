extends Control
# =============================================================
# IntelConsolePopup.gd
# UI built in scene, not in code.
#
# Shows what happened last turn and squad status.
# Squad NEEDS are NOT shown here — check the Vox-Caster.
# =============================================================

var player: Node = null
var reinforcement_warning_turn: int  = -1
var reinforcement_warning_count: int = 0
var landed_sectors: Array            = []
var landed_turn: int                 = -1
	
@onready var turn_label: Label              = $PanelContainer/VBoxContainer/TurnLabel
@onready var report_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/ReportContainer
@onready var close_btn: Button              = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.enemy_reinforcements_incoming.connect(_on_reinforcements_incoming)
	TurnManager.enemy_reinforcements_landed.connect(_on_reinforcements_landed)
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

	# Reinforcement alerts — shown above all squad reports
	if landed_sectors.size() > 0 and landed_turn == SquadManager.current_turn:
		_add_reinforcements_landed_card(landed_sectors)

	if reinforcement_warning_turn > SquadManager.current_turn:
		_add_reinforcements_warning_card(reinforcement_warning_count, reinforcement_warning_turn)

	# Critical squads always break through — priority distress first
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

func _on_reinforcements_incoming(turn: int, count: int) -> void:
	print("INTEL: incoming warning received — turn %d, count %d" % [turn, count])
	reinforcement_warning_turn  = turn
	reinforcement_warning_count = count
	if visible:
		refresh()

func _on_reinforcements_landed(sectors: Array) -> void:
	landed_sectors = sectors
	landed_turn    = SquadManager.current_turn
	if visible:
		refresh()

func _add_reinforcements_warning_card(count: int, turn: int) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _alert_style(Color(0.22, 0.15, 0.05), Color(0.9, 0.6, 0.1, 0.9)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "⚠ SENSOR WARNING — ENEMY BUILDUP DETECTED"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.95, 0.7, 0.2))
	vbox.add_child(header)

	var body := Label.new()
	var unit_word = "unit" if count == 1 else "units"
	body.text = "Long-range scans show %d enemy %s massing for a push. Expected to make contact by Turn %d." % [count, unit_word, turn]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
	vbox.add_child(body)

	report_container.add_child(card)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	report_container.add_child(spacer)


func _add_reinforcements_landed_card(sectors: Array) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _alert_style(Color(0.22, 0.06, 0.06), Color(0.9, 0.2, 0.2, 0.95)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "⚠ ENEMY REINFORCEMENTS HAVE LANDED"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(header)

	var sector_list_text = ", ".join(sectors)
	var body := Label.new()
	body.text = "New enemy contact confirmed at: %s." % sector_list_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.95, 0.7, 0.7))
	vbox.add_child(body)

	report_container.add_child(card)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	report_container.add_child(spacer)


func _alert_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.bg_color = bg
	style.border_color = border
	style.border_width_left   = 3
	style.border_width_top    = 1
	style.border_width_right  = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
	style.corner_radius_bottom_right = 3
	return style

func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
