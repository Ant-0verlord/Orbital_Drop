extends Control
# =============================================================
# CommandThronePopup.gd — fullscreen popup
# Shows mission status. End Turn only available when locked.
# On mission end shows a full report before closing.
# =============================================================

var player: Node = null

var end_turn_btn: Button
var lock_status_lbl: Label
var turn_label: Label
var held_label: Label
var squad_summary: VBoxContainer
var debrief_label: Label
var progress_bar: ProgressBar
var report_panel: PanelContainer  # shown on mission end


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
	_show_report(report, true)

func _on_mission_failed(reason: String) -> void:
	refresh()
	_show_report({ "won": false, "reason": reason,
		"held_hexes": EnemyManager.get_held_count(),
		"required_hexes": TurnManager.win_condition_hexes,
		"squads_alive": 0, "squads_lost": 0, "turns": TurnManager.current_turn }, false)


func refresh() -> void:
	_update_mission_info()
	_update_squad_summary()
	_update_lock_status()
	_update_debrief()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	panel.custom_minimum_size = Vector2(560, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "COMMAND THRONE"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(title)

	var mission_title := Label.new()
	mission_title.name = "MissionTitle"
	mission_title.add_theme_font_size_override("font_size", 15)
	mission_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7))
	vbox.add_child(mission_title)

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 20)
	vbox.add_child(info_row)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 13)
	turn_label.add_theme_color_override("font_color", Color(0.5, 0.75, 0.9))
	info_row.add_child(turn_label)

	held_label = Label.new()
	held_label.add_theme_font_size_override("font_size", 13)
	info_row.add_child(held_label)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 14
	progress_bar.show_percentage = false
	vbox.add_child(progress_bar)

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

	# Mission report panel (hidden until mission ends)
	report_panel = PanelContainer.new()
	report_panel.name = "ReportPanel"
	report_panel.custom_minimum_size = Vector2(520, 0)
	report_panel.set_anchors_preset(Control.PRESET_CENTER)
	report_panel.visible = false
	add_child(report_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 14)
	report_panel.add_child(rv)

	var rt := Label.new()
	rt.name = "ReportTitle"
	rt.add_theme_font_size_override("font_size", 24)
	rv.add_child(rt)

	var rb := Label.new()
	rb.name = "ReportBody"
	rb.autowrap_mode = TextServer.AUTOWRAP_WORD
	rb.add_theme_font_size_override("font_size", 14)
	rv.add_child(rb)

	var r_btn := Button.new()
	r_btn.text = "Acknowledge"
	r_btn.pressed.connect(_on_report_acknowledged)
	rv.add_child(r_btn)


func _update_mission_info() -> void:
	var data = GameManager.get_current_mission_data()
	var mt = get_node_or_null("PanelContainer/VBoxContainer/MissionTitle")
	var ol = get_node_or_null("PanelContainer/VBoxContainer/ObjectiveLabel")
	if mt: mt.text = data.get("title", "")
	if ol:
		var turns_left = TurnManager.max_turns - TurnManager.current_turn
		ol.text = data.get("objective", "Hold %d sectors for %d more turns." % [TurnManager.win_condition_hexes, turns_left])
	if turn_label: turn_label.text = "Turn %d / %d" % [TurnManager.current_turn, TurnManager.max_turns]
	if held_label:
		var held = EnemyManager.get_held_count()
		var req  = TurnManager.win_condition_hexes
		held_label.text = "Held: %d / %d" % [held, req]
		held_label.add_theme_color_override("font_color", Color(0.4,0.9,0.4) if held >= req else Color(0.9,0.6,0.2))
	if progress_bar:
		progress_bar.max_value = TurnManager.max_turns
		progress_bar.value = TurnManager.current_turn


func _update_squad_summary() -> void:
	for child in squad_summary.get_children(): child.queue_free()
	var active = 0; var wounded = 0; var critical = 0; var lost = 0
	for squad in SquadManager.get_squads_for_ui():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var nl := Label.new(); nl.text = squad.name; nl.custom_minimum_size.x = 120
		nl.add_theme_font_size_override("font_size", 13); row.add_child(nl)
		var sl := Label.new(); sl.text = "%s — %s" % [SquadManager.STATUS_NAMES[squad.status], squad.sector]
		sl.add_theme_font_size_override("font_size", 13)
		sl.add_theme_color_override("font_color", _status_color(squad.status)); row.add_child(sl)
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
	if active > 0:   lines.append("%d squad%s operational." % [active, "s" if active > 1 else ""])
	if wounded > 0:  lines.append("%d squad%s wounded." % [wounded, "s" if wounded > 1 else ""])
	var held = EnemyManager.get_held_count()
	lines.append("%d sector%s held." % [held, "s" if held != 1 else ""])
	debrief_label.text = "\n".join(lines)


func _show_report(report: Dictionary, won: bool) -> void:
	# Hide main content, show report panel
	get_node_or_null("PanelContainer").visible = false
	report_panel.visible = true

	var rt = report_panel.get_node_or_null("VBoxContainer/ReportTitle")
	var rb = report_panel.get_node_or_null("VBoxContainer/ReportBody")

	if rt:
		rt.text = "MISSION COMPLETE" if won else "MISSION FAILED"
		rt.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if won else Color(0.9, 0.3, 0.3))

	if rb:
		var held     = report.get("held_hexes", 0)
		var required = report.get("required_hexes", 5)
		var alive    = report.get("squads_alive", 0)
		var lost_c   = report.get("squads_lost", 0)
		var turns    = report.get("turns", 0)
		if won:
			rb.text = "Sectors held: %d / %d\nSquads operational: %d\nSquads lost: %d\nTurns taken: %d\n\nThe foothold is secured. Stand by for campaign debrief." % [held, required, alive, lost_c, turns]
		else:
			var reason = report.get("reason", "Mission objectives not met.")
			rb.text = "%s\n\nSectors held: %d / %d required.\nSquads lost: %d" % [reason, held, required, lost_c]


func _on_report_acknowledged() -> void:
	# TODO: trigger next mission
	visible = false
	get_node_or_null("PanelContainer").visible = true
	report_panel.visible = false
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
