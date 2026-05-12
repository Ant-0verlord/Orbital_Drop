extends Control
# =============================================================
# CommandThronePopup.gd
# Attach to: Control node named "CommandThronePopup" inside
#            Command_Throne.tscn > StaticBody3D
#
# Shows mission status, squad summary, and the End Turn button.
# End Turn is only available once allocations are locked.
# =============================================================

var player: Node = null

var end_turn_btn: Button
var lock_status_lbl: Label
var turn_label: Label
var squad_summary: VBoxContainer
var debrief_label: Label
var progress_bar: ProgressBar


func _ready() -> void:
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.turn_ended.connect(_on_turn_ended)
	TurnManager.allocations_locked.connect(_on_allocations_locked)
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	_build_ui()


func _on_turn_started(_turn: int) -> void:
	if visible:
		refresh()


func _on_turn_ended(_turn: int) -> void:
	if visible:
		refresh()


func _on_allocations_locked() -> void:
	_update_lock_status()


func _on_turn_resolved() -> void:
	if visible:
		refresh()


func refresh() -> void:
	_update_mission_info()
	_update_squad_summary()
	_update_lock_status()
	_update_debrief()


func _build_ui() -> void:
	custom_minimum_size = Vector2(480, 0)
	set_anchors_preset(Control.PRESET_CENTER)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Mission title
	var mission_title := Label.new()
	mission_title.name = "MissionTitle"
	mission_title.add_theme_font_size_override("font_size", 18)
	mission_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(mission_title)

	# Turn label
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 13)
	turn_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
	vbox.add_child(turn_label)

	# Progress bar
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 12
	progress_bar.show_percentage = false
	vbox.add_child(progress_bar)

	vbox.add_child(HSeparator.new())

	# Objective
	var obj_header := Label.new()
	obj_header.text = "CURRENT OBJECTIVE"
	obj_header.add_theme_font_size_override("font_size", 11)
	obj_header.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	vbox.add_child(obj_header)

	var obj_label := Label.new()
	obj_label.name = "ObjectiveLabel"
	obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	obj_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(obj_label)

	vbox.add_child(HSeparator.new())

	# Squad summary
	var squad_header := Label.new()
	squad_header.text = "SQUAD STATUS"
	squad_header.add_theme_font_size_override("font_size", 11)
	squad_header.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	vbox.add_child(squad_header)

	squad_summary = VBoxContainer.new()
	squad_summary.add_theme_constant_override("separation", 4)
	vbox.add_child(squad_summary)

	vbox.add_child(HSeparator.new())

	# Last turn debrief
	var debrief_header := Label.new()
	debrief_header.text = "LAST TURN DEBRIEF"
	debrief_header.add_theme_font_size_override("font_size", 11)
	debrief_header.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	vbox.add_child(debrief_header)

	debrief_label = Label.new()
	debrief_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	debrief_label.add_theme_font_size_override("font_size", 12)
	debrief_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(debrief_label)

	vbox.add_child(HSeparator.new())

	# Lock status
	lock_status_lbl = Label.new()
	lock_status_lbl.add_theme_font_size_override("font_size", 12)
	lock_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(lock_status_lbl)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	end_turn_btn = Button.new()
	end_turn_btn.text = "ENGAGE TURN SEAL"
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	btn_row.add_child(end_turn_btn)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)


func _update_mission_info() -> void:
	var data = GameManager.get_current_mission_data()
	var mission_title = get_node_or_null("PanelContainer/VBoxContainer/MissionTitle")
	var obj_label = get_node_or_null("PanelContainer/VBoxContainer/ObjectiveLabel")

	if mission_title:
		mission_title.text = data.get("title", "Unknown Mission")
	if turn_label:
		turn_label.text = "Turn %d of %d" % [TurnManager.current_turn, TurnManager.max_turns]
	if progress_bar:
		progress_bar.max_value = TurnManager.max_turns
		progress_bar.value = TurnManager.current_turn
	if obj_label:
		var turns_left = TurnManager.max_turns - TurnManager.current_turn
		obj_label.text = data.get("objective",
			"Establish a foothold. Keep both squads alive for %d more turns." % turns_left
		)


func _update_squad_summary() -> void:
	for child in squad_summary.get_children():
		child.queue_free()

	var active = 0
	var wounded = 0
	var critical = 0
	var lost = 0

	for squad in SquadManager.get_squads_for_ui():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = squad.name
		name_lbl.custom_minimum_size.x = 120
		name_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(name_lbl)

		var status_lbl := Label.new()
		status_lbl.text = SquadManager.STATUS_NAMES[squad.status]
		status_lbl.add_theme_font_size_override("font_size", 12)
		status_lbl.add_theme_color_override("font_color", _status_color(squad.status))
		row.add_child(status_lbl)

		squad_summary.add_child(row)

		match squad.status:
			SquadManager.Status.ACTIVE:   active += 1
			SquadManager.Status.WOUNDED:  wounded += 1
			SquadManager.Status.CRITICAL: critical += 1
			SquadManager.Status.LOST:     lost += 1

	# Summary line
	var summary_lbl := Label.new()
	summary_lbl.add_theme_font_size_override("font_size", 11)
	summary_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	var parts = []
	if active > 0:   parts.append("%d operational" % active)
	if wounded > 0:  parts.append("%d wounded" % wounded)
	if critical > 0: parts.append("%d critical" % critical)
	if lost > 0:     parts.append("%d lost" % lost)
	summary_lbl.text = ", ".join(parts) if parts.size() > 0 else "No squads"
	squad_summary.add_child(summary_lbl)


func _update_lock_status() -> void:
	if not lock_status_lbl or not end_turn_btn:
		return
	if TurnManager.allocations_are_locked:
		lock_status_lbl.text = "✓ Allocations locked. Ready to engage turn seal."
		lock_status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		end_turn_btn.disabled = false
		end_turn_btn.modulate = Color(1, 1, 1)
	else:
		lock_status_lbl.text = "⚠ Allocations not locked. Visit Logistics Terminal first."
		lock_status_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		end_turn_btn.disabled = true
		end_turn_btn.modulate = Color(0.5, 0.5, 0.5)


func _update_debrief() -> void:
	if not debrief_label:
		return
	if TurnManager.current_turn == 0:
		debrief_label.text = "No turns resolved yet. Issue your first allocations."
		return
	var reports = SquadManager.get_reports()
	var active_count = 0
	var wounded_count = 0
	for squad in SquadManager.get_squads_for_ui():
		match squad.status:
			SquadManager.Status.ACTIVE:  active_count += 1
			SquadManager.Status.WOUNDED: wounded_count += 1
	var lines = []
	if active_count > 0: lines.append("%d squad%s operational." % [active_count, "s" if active_count > 1 else ""])
	if wounded_count > 0: lines.append("%d squad%s wounded." % [wounded_count, "s" if wounded_count > 1 else ""])
	debrief_label.text = "\n".join(lines) if lines.size() > 0 else "Turn resolved."


func _on_end_turn_pressed() -> void:
	if not TurnManager.allocations_are_locked:
		return
	TurnManager.end_turn()
	_on_close_pressed()


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()


func _status_color(status: int) -> Color:
	match status:
		SquadManager.Status.ACTIVE:   return Color(0.4, 0.9, 0.4)
		SquadManager.Status.WOUNDED:  return Color(0.9, 0.7, 0.2)
		SquadManager.Status.CRITICAL: return Color(0.9, 0.3, 0.3)
		SquadManager.Status.LOST:     return Color(0.5, 0.5, 0.5)
	return Color.WHITE
