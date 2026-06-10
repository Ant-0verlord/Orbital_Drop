extends Control
# =============================================================
# CommandThronePopup.gd — fullscreen popup
# =============================================================

var player: Node = null

var end_turn_btn: Button
var lock_status_lbl: Label
var turn_label: Label
var held_label: Label
var squad_summary: VBoxContainer
var debrief_label: Label
var progress_bar: ProgressBar
var report_panel: PanelContainer


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

func _on_mission_failed(_reason: String) -> void:
	# mission_complete is always emitted alongside mission_failed
	# so _show_report is handled there — nothing extra needed
	pass


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

	# -------------------------------------------------------
	# Mission report panel — replaces main content on end
	# -------------------------------------------------------
	report_panel = PanelContainer.new()
	report_panel.name = "ReportPanel"
	report_panel.custom_minimum_size = Vector2(560, 0)
	report_panel.set_anchors_preset(Control.PRESET_CENTER)
	report_panel.visible = false
	add_child(report_panel)

	var rv := VBoxContainer.new()
	rv.name = "ReportVBox"
	rv.add_theme_constant_override("separation", 14)
	report_panel.add_child(rv)

	var rt := Label.new()
	rt.name = "ReportTitle"
	rt.add_theme_font_size_override("font_size", 28)
	rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(rt)

	var rating_lbl := Label.new()
	rating_lbl.name = "RatingLabel"
	rating_lbl.add_theme_font_size_override("font_size", 48)
	rating_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(rating_lbl)

	rv.add_child(HSeparator.new())

	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 24)
	rv.add_child(score_row)

	for col_name in ["TILE SCORE", "TURN BONUS", "SUPPLY BONUS", "TOTAL"]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		var col_header := Label.new()
		col_header.text = col_name
		col_header.add_theme_font_size_override("font_size", 10)
		col_header.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		col_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(col_header)
		var col_val := Label.new()
		col_val.name = col_name.replace(" ", "") + "Val"
		col_val.add_theme_font_size_override("font_size", 20)
		col_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(col_val)
		score_row.add_child(col)

	rv.add_child(HSeparator.new())

	var rb := Label.new()
	rb.name = "ReportBody"
	rb.autowrap_mode = TextServer.AUTOWRAP_WORD
	rb.add_theme_font_size_override("font_size", 13)
	rb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(rb)

	var r_btn_row := HBoxContainer.new()
	r_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	r_btn_row.add_theme_constant_override("separation", 12)
	rv.add_child(r_btn_row)

	var r_close := Button.new()
	r_close.text = "Close"
	r_close.pressed.connect(_on_close_pressed)
	r_btn_row.add_child(r_close)


func _update_mission_info() -> void:
	var data = GameManager.get_current_mission_data()
	var mt = get_node_or_null("PanelContainer/VBoxContainer/MissionTitle")
	var ol = get_node_or_null("PanelContainer/VBoxContainer/ObjectiveLabel")
	if mt: mt.text = data.get("title", "")
	if ol:
		var turns_left = TurnManager.max_turns - TurnManager.current_turn
		ol.text = data.get("objective",
			"Hold %d sectors for %d more turns." % [TurnManager.win_condition_hexes, turns_left])
	if turn_label:
		turn_label.text = "Turn %d / %d" % [TurnManager.current_turn, TurnManager.max_turns]
	if held_label:
		var held = EnemyManager.get_held_count()
		var req  = TurnManager.win_condition_hexes
		held_label.text = "Held: %d / %d" % [held, req]
		held_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if held >= req else Color(0.9, 0.6, 0.2))
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

	# Block all input if mission is over
	if TurnManager.mission_over:
		lock_status_lbl.text = "Mission concluded. No further orders can be issued."
		lock_status_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		end_turn_btn.disabled = true
		end_turn_btn.text = "—"
		end_turn_btn.modulate = Color(0.4, 0.4, 0.4)
		return

	if TurnManager.allocations_are_locked:
		lock_status_lbl.text = "✓ Allocations locked. Ready to engage turn seal."
		lock_status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		end_turn_btn.disabled = false
		end_turn_btn.text = "ENGAGE TURN SEAL"
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
	var held = EnemyManager.get_held_count()
	lines.append("%d sector%s held." % [held, "s" if held != 1 else ""])

	# Supply pool summary in debrief
	var pool = GameManager.get_supply_pool()
	lines.append("Pool remaining — Arms: %d  Meds: %d  Fuel: %d" % [
		pool.get("Armaments", 0),
		pool.get("Medi-Packs", 0),
		pool.get("Fuel Cells", 0),
	])

	debrief_label.text = "\n".join(lines)


func _show_report(report: Dictionary) -> void:
	# Hide main panel, show report
	var main_panel = get_node_or_null("PanelContainer")
	if main_panel: main_panel.visible = false
	report_panel.visible = true

	var won     = report.get("won", false)
	var held    = report.get("held_hexes", 0)
	var req     = report.get("required_hexes", 0)
	var alive   = report.get("squads_alive", 0)
	var lost_c  = report.get("squads_lost", 0)
	var turns   = report.get("turns", 0)
	var rating  = report.get("rating", "—")
	var score   = report.get("score", 0)
	var t_score = report.get("tile_score", 0)
	var t_bonus = report.get("turn_bonus", 0)
	var s_bonus = report.get("supply_bonus", 0)

	var rt = report_panel.get_node_or_null("ReportVBox/ReportTitle")
	var rl = report_panel.get_node_or_null("ReportVBox/RatingLabel")
	var rb = report_panel.get_node_or_null("ReportVBox/ReportBody")

	# Score columns
	var tile_val   = report_panel.get_node_or_null("ReportVBox/HBoxContainer/TILESCOREVal")
	var turn_val   = report_panel.get_node_or_null("ReportVBox/HBoxContainer/TURNBONUSVal")
	var supply_val = report_panel.get_node_or_null("ReportVBox/HBoxContainer/SUPPLYBONUSVal")
	var total_val  = report_panel.get_node_or_null("ReportVBox/HBoxContainer/TOTALVal")

	if rt:
		rt.text = "MISSION COMPLETE" if won else "MISSION FAILED"
		rt.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if won else Color(0.9, 0.3, 0.3))

	if rl:
		rl.text = rating
		rl.add_theme_color_override("font_color", _rating_color(rating))

	if tile_val:   tile_val.text   = str(t_score)
	if turn_val:   turn_val.text   = str(t_bonus)
	if supply_val: supply_val.text = str(s_bonus)
	if total_val:
		total_val.text = str(score)
		total_val.add_theme_color_override("font_color", _rating_color(rating))

	if rb:
		if won:
			rb.text = (
				"Sectors held: %d / %d\nSquads operational: %d   Squads lost: %d\nTurns taken: %d\n\nThe foothold is secured."
				% [held, req, alive, lost_c, turns]
			)
		else:
			var reason = report.get("reason", "Mission objectives not met.")
			rb.text = (
				"%s\n\nSectors held: %d / %d required\nSquads lost: %d   Turns: %d"
				% [reason, held, req, lost_c, turns]
			)


func _rating_color(rating: String) -> Color:
	match rating:
		"S": return Color(1.0, 0.9, 0.2)
		"A": return Color(0.4, 0.9, 0.4)
		"B": return Color(0.4, 0.7, 1.0)
		"C": return Color(0.9, 0.6, 0.2)
		_:   return Color(0.6, 0.2, 0.2)


func _on_end_turn_pressed() -> void:
	if TurnManager.mission_over: return
	if not TurnManager.allocations_are_locked: return
	TurnManager.end_turn()
	_on_close_pressed()


func _on_close_pressed() -> void:
	visible = false
	# Restore main panel visibility for next open (unless mission over showing report)
	if not TurnManager.mission_over:
		var main_panel = get_node_or_null("PanelContainer")
		if main_panel: main_panel.visible = true
		report_panel.visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()


func _status_color(status: int) -> Color:
	match status:
		SquadManager.Status.ACTIVE:   return Color(0.4, 0.9, 0.4)
		SquadManager.Status.WOUNDED:  return Color(0.9, 0.7, 0.2)
		SquadManager.Status.CRITICAL: return Color(0.9, 0.3, 0.3)
		SquadManager.Status.LOST:     return Color(0.5, 0.5, 0.5)
	return Color.WHITE
