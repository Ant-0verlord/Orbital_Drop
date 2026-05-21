extends Control
# =============================================================
# CommandThronePopup.gd
# No turn limit — shows turns elapsed instead.
# On mission end shows detailed mission report.
# =============================================================

var player: Node = null

var end_turn_btn: Button
var lock_status_lbl: Label
var turn_label: Label
var held_label: Label
var squad_summary: VBoxContainer
var debrief_label: Label
var report_open: bool = false


func _ready() -> void:
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.turn_ended.connect(_on_turn_ended)
	TurnManager.allocations_locked.connect(_on_allocations_locked)
	TurnManager.mission_complete.connect(_on_mission_complete)
	TurnManager.mission_failed.connect(_on_mission_failed)
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	_build_ui()


func _on_turn_started(_t: int) -> void:
	if visible: refresh()

func _on_turn_ended(_t: int) -> void:
	if visible: refresh()

func _on_allocations_locked() -> void:
	_update_lock_status()

func _on_turn_resolved() -> void:
	if visible: refresh()

func _on_mission_complete(report: Dictionary) -> void:
	refresh()
	_show_report(report)

func _on_mission_failed(reason: String) -> void:
	refresh()
	var report = {
		"won": false,
		"reason": reason,
		"turns_taken": TurnManager.current_turn,
		"held_hexes": EnemyManager.get_held_count(),
		"required_hexes": TurnManager.win_condition_hexes,
		"squads_alive": 0,
		"squads_lost": 0,
		"squad_details": [],
		"turn_log": TurnManager.turn_log,
	}
	for squad in SquadManager.get_squads_for_ui():
		if squad.status == SquadManager.Status.LOST:
			report.squads_lost += 1
		else:
			report.squads_alive += 1
	_show_report(report)


func refresh() -> void:
	if report_open:
		return
	_update_mission_info()
	_update_squad_summary()
	_update_lock_status()
	_update_debrief()


func _build_ui() -> void:
	custom_minimum_size = Vector2(520, 0)
	set_anchors_preset(Control.PRESET_CENTER)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "COMMAND THRONE"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(title)

	var mission_title := Label.new()
	mission_title.name = "MissionTitle"
	mission_title.add_theme_font_size_override("font_size", 14)
	mission_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	vbox.add_child(mission_title)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 24)
	vbox.add_child(info_row)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 13)
	turn_label.add_theme_color_override("font_color", Color(0.5, 0.75, 0.9))
	info_row.add_child(turn_label)

	held_label = Label.new()
	held_label.add_theme_font_size_override("font_size", 13)
	info_row.add_child(held_label)

	vbox.add_child(HSeparator.new())

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

	var squad_header := Label.new()
	squad_header.text = "SQUAD STATUS"
	squad_header.add_theme_font_size_override("font_size", 11)
	squad_header.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	vbox.add_child(squad_header)

	squad_summary = VBoxContainer.new()
	squad_summary.add_theme_constant_override("separation", 4)
	vbox.add_child(squad_summary)

	vbox.add_child(HSeparator.new())

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

	lock_status_lbl = Label.new()
	lock_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lock_status_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lock_status_lbl)

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
	var mt = get_node_or_null("PanelContainer/VBoxContainer/MissionTitle")
	var ol = get_node_or_null("PanelContainer/VBoxContainer/ObjectiveLabel")
	if mt: mt.text = data.get("title", "")
	if ol: ol.text = data.get("objective", "Hold %d sectors and survive the enemy counter-push." % TurnManager.win_condition_hexes)
	if turn_label: turn_label.text = "Turn %d" % TurnManager.current_turn
	if held_label:
		var held = EnemyManager.get_held_count()
		var req  = TurnManager.win_condition_hexes
		held_label.text = "Held: %d / %d required" % [held, req]
		held_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if held >= req else Color(0.9, 0.6, 0.2)
		)


func _update_squad_summary() -> void:
	for child in squad_summary.get_children(): child.queue_free()
	var active = 0; var wounded = 0; var critical = 0; var lost = 0
	for squad in SquadManager.get_squads_for_ui():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var nl := Label.new()
		nl.text = squad.name
		nl.custom_minimum_size.x = 120
		nl.add_theme_font_size_override("font_size", 13)
		row.add_child(nl)
		var sl := Label.new()
		sl.text = "%s — %s" % [SquadManager.STATUS_NAMES[squad.status], squad.sector]
		sl.add_theme_font_size_override("font_size", 13)
		sl.add_theme_color_override("font_color", _status_color(squad.status))
		row.add_child(sl)
		squad_summary.add_child(row)
		match squad.status:
			SquadManager.Status.ACTIVE:   active += 1
			SquadManager.Status.WOUNDED:  wounded += 1
			SquadManager.Status.CRITICAL: critical += 1
			SquadManager.Status.LOST:     lost += 1
	var parts = []
	if active > 0:   parts.append("%d operational" % active)
	if wounded > 0:  parts.append("%d wounded" % wounded)
	if critical > 0: parts.append("%d critical" % critical)
	if lost > 0:     parts.append("%d lost" % lost)
	var sl2 := Label.new()
	sl2.text = ", ".join(parts)
	sl2.add_theme_font_size_override("font_size", 11)
	sl2.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	squad_summary.add_child(sl2)


func _update_lock_status() -> void:
	if not lock_status_lbl or not end_turn_btn: return
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
	if not debrief_label: return
	if TurnManager.current_turn == 0:
		debrief_label.text = "No turns resolved yet. Issue your first allocations."
		return
	var active = 0; var wounded = 0
	for squad in SquadManager.get_squads_for_ui():
		match squad.status:
			SquadManager.Status.ACTIVE:  active += 1
			SquadManager.Status.WOUNDED: wounded += 1
	var lines = []
	if active > 0:  lines.append("%d squad%s operational." % [active, "s" if active > 1 else ""])
	if wounded > 0: lines.append("%d squad%s wounded." % [wounded, "s" if wounded > 1 else ""])
	lines.append("%d sector%s held." % [EnemyManager.get_held_count(), "s" if EnemyManager.get_held_count() != 1 else ""])
	debrief_label.text = "\n".join(lines)


# -------------------------------------------------------
# Mission Report — shown over the throne popup
# -------------------------------------------------------
func _show_report(report: Dictionary) -> void:
	report_open = true

	# Build report popup
	var overlay := ColorRect.new()
	overlay.name = "ReportOverlay"
	overlay.color = Color(0, 0, 0, 0.92)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var report_panel := PanelContainer.new()
	report_panel.custom_minimum_size = Vector2(600, 0)
	report_panel.set_anchors_preset(Control.PRESET_CENTER)
	overlay.add_child(report_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	report_panel.add_child(vbox)

	# Title
	var won: bool = report.get("won", false)
	var title_lbl := Label.new()
	title_lbl.text = "MISSION COMPLETE" if won else "MISSION FAILED"
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color",
		Color(0.4, 0.9, 0.4) if won else Color(0.9, 0.3, 0.3)
	)
	vbox.add_child(title_lbl)

	# Mission name
	var mission_lbl := Label.new()
	mission_lbl.text = GameManager.get_current_mission_data().get("title", "")
	mission_lbl.add_theme_font_size_override("font_size", 14)
	mission_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.65))
	vbox.add_child(mission_lbl)

	vbox.add_child(HSeparator.new())

	# Summary stats
	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(stats_vbox)

	_add_stat(stats_vbox, "Turns taken",       str(report.get("turns_taken", 0)))
	_add_stat(stats_vbox, "Sectors held",
		"%d / %d required" % [report.get("held_hexes", 0), report.get("required_hexes", 5)])
	_add_stat(stats_vbox, "Squads operational", str(report.get("squads_alive", 0)))
	_add_stat(stats_vbox, "Squads lost",        str(report.get("squads_lost",  0)))

	vbox.add_child(HSeparator.new())

	# Per-squad breakdown
	var squad_header := Label.new()
	squad_header.text = "SQUAD REPORT"
	squad_header.add_theme_font_size_override("font_size", 13)
	squad_header.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	vbox.add_child(squad_header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 180
	vbox.add_child(scroll)

	var squad_vbox := VBoxContainer.new()
	squad_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(squad_vbox)

	for detail in report.get("squad_details", []):
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.08, 0.12, 0.16)
		card_style.set_content_margin_all(8)
		card_style.corner_radius_top_left = 4; card_style.corner_radius_top_right = 4
		card_style.corner_radius_bottom_left = 4; card_style.corner_radius_bottom_right = 4
		card.add_theme_stylebox_override("panel", card_style)
		squad_vbox.add_child(card)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 3)
		card.add_child(cv)

		# Squad name + final status
		var header_row := HBoxContainer.new()
		header_row.add_theme_constant_override("separation", 8)
		cv.add_child(header_row)

		var name_lbl := Label.new()
		name_lbl.text = detail.get("name", "")
		name_lbl.add_theme_font_size_override("font_size", 14)
		header_row.add_child(name_lbl)

		var status_lbl := Label.new()
		var final_status = detail.get("final_status", "")
		status_lbl.text = "[%s]" % final_status
		status_lbl.add_theme_font_size_override("font_size", 12)
		var sc = Color(0.5, 0.5, 0.5)
		if final_status == "Active":   sc = Color(0.4, 0.9, 0.4)
		elif final_status == "Wounded": sc = Color(0.9, 0.7, 0.2)
		elif final_status == "Critical": sc = Color(0.9, 0.3, 0.3)
		status_lbl.add_theme_color_override("font_color", sc)
		header_row.add_child(status_lbl)

		var sector_lbl := Label.new()
		sector_lbl.text = "Final position: %s" % detail.get("final_sector", "—")
		sector_lbl.add_theme_font_size_override("font_size", 11)
		sector_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
		cv.add_child(sector_lbl)

		# Supply summary
		var arms  = detail.get("arms_turns",  0)
		var meds  = detail.get("meds_turns",  0)
		var fuel  = detail.get("fuel_turns",  0)
		var supply_lbl := Label.new()
		supply_lbl.text = "Supplies received — Armaments: %d turn%s  |  Medi-Packs: %d turn%s  |  Fuel Cells: %d turn%s" % [
			arms, "s" if arms != 1 else "",
			meds, "s" if meds != 1 else "",
			fuel, "s" if fuel != 1 else "",
		]
		supply_lbl.add_theme_font_size_override("font_size", 11)
		supply_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
		supply_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		cv.add_child(supply_lbl)

	vbox.add_child(HSeparator.new())

	# Acknowledge button
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var ack_btn := Button.new()
	ack_btn.text = "Acknowledge & Continue"
	ack_btn.pressed.connect(_on_report_acknowledged.bind(overlay))
	btn_row.add_child(ack_btn)


func _add_stat(container: Node, label: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 160
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	row.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 13)
	row.add_child(val)
	container.add_child(row)


func _on_report_acknowledged(overlay: Node) -> void:
	report_open = false
	overlay.queue_free()
	# TODO: advance to next mission
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()


func _on_end_turn_pressed() -> void:
	if not TurnManager.allocations_are_locked: return
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
