extends Control
# =============================================================
# CommandThronePopup.gd
# UI built in scene, not in code.
# =============================================================

var player: Node = null

@onready var turn_label: Label            = $PanelContainer/VBoxContainer/InfoRow/TurnLabel
@onready var held_label: Label            = $PanelContainer/VBoxContainer/InfoRow/HeldLabel
@onready var progress_bar: ProgressBar    = $PanelContainer/VBoxContainer/ProgressBar
@onready var mission_title: Label         = $PanelContainer/VBoxContainer/MissionTitle
@onready var objective_label: Label       = $PanelContainer/VBoxContainer/ObjectiveLabel
@onready var squad_summary: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/SquadSummary
@onready var debrief_label: Label         = $PanelContainer/VBoxContainer/DebriefLabel
@onready var lock_status_lbl: Label       = $PanelContainer/VBoxContainer/LockStatusLabel
@onready var end_turn_btn: Button         = $PanelContainer/VBoxContainer/ButtonRow/EndTurnBtn
@onready var close_btn: Button            = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn
@onready var report_panel: PanelContainer = $ReportPanel
@onready var report_title: Label          = $ReportPanel/ReportVBox/ReportTitle
@onready var rating_label: Label          = $ReportPanel/ReportVBox/RatingLabel
@onready var report_body: Label           = $ReportPanel/ReportVBox/ReportBody
@onready var report_close: Button         = $ReportPanel/ReportVBox/ReportClose
@onready var tile_val: Label              = $ReportPanel/ReportVBox/ScoreRow/TileCol/TileVal
@onready var turn_val: Label              = $ReportPanel/ReportVBox/ScoreRow/TurnCol/TurnVal
@onready var supply_val: Label            = $ReportPanel/ReportVBox/ScoreRow/SupplyCol/SupplyVal
@onready var total_val: Label             = $ReportPanel/ReportVBox/ScoreRow/TotalCol/TotalVal

# Add this button to ReportVBox in the scene, below ReportClose
@onready var next_mission_btn: Button     = $ReportPanel/ReportVBox/NextMissionBtn


func _ready() -> void:
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.turn_ended.connect(_on_turn_ended)
	TurnManager.allocations_locked.connect(_on_allocations_locked)
	TurnManager.mission_complete.connect(_on_mission_complete)
	SquadManager.turn_resolved.connect(_on_turn_resolved)

	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	report_close.pressed.connect(_on_close_pressed)
	next_mission_btn.pressed.connect(_on_next_mission_pressed)

	report_panel.visible = false
	next_mission_btn.visible = false


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


func refresh() -> void:
	_update_mission_info()
	_update_squad_summary()
	_update_lock_status()
	_update_debrief()


func _update_mission_info() -> void:
	var data = GameManager.get_current_mission_data()
	if mission_title:
		mission_title.text = data.get("title", "")
	if objective_label:
		objective_label.text = _get_objective_text(data)
	if turn_label:
		turn_label.text = "Turn %d / %d" % [TurnManager.current_turn, TurnManager.max_turns]
	if held_label:
		_update_held_label()
	if progress_bar:
		progress_bar.max_value = TurnManager.max_turns
		progress_bar.value = TurnManager.current_turn

func _get_objective_text(data: Dictionary) -> String:
	var mission_type = data.get("mission_type", "capture")
	var turns_left = TurnManager.max_turns - TurnManager.current_turn
	match mission_type:
		"capture":
			return "Hold %d sectors by end of Turn %d." % [TurnManager.win_condition_hexes, TurnManager.max_turns]
		"eliminate":
			var remaining = EnemyManager.get_total_enemy_count()
			return "Eliminate all enemy forces. %d units remaining." % remaining
		"hold_tower":
			if GameManager.tower_powered:
				return "Tower active — hold it until mission end. %d turns remaining." % turns_left
			else:
				return "Capture and power the comms tower. Power requires 2 turns of Fuel Cells."
		"eliminate_priority":
			if GameManager.priority_target_alive:
				return "Eliminate %s. Optional: power the comms tower." % GameManager.priority_target_name
			else:
				return "Priority target eliminated. Data secured — extract if possible."
		"extract":
			var ez = GameManager.extraction_zone
			return "Reach extraction zone (%s) by end of final turn. Data carrier must extract." % ez
	return data.get("objective", "")

func _update_held_label() -> void:
	if not held_label:
		return
	var mission_type = GameManager.mission_type
	match mission_type:
		"capture":
			var held = EnemyManager.get_held_count()
			var req  = TurnManager.win_condition_hexes
			held_label.text = "Held: %d / %d" % [held, req]
			held_label.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.4) if held >= req else Color(0.9, 0.6, 0.2))
		"eliminate":
			var remaining = EnemyManager.get_total_enemy_count()
			held_label.text = "Enemies: %d remaining" % remaining
			held_label.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.4) if remaining == 0 else Color(0.9, 0.6, 0.2))
		"hold_tower":
			var powered = GameManager.tower_powered
			held_label.text = "Tower: %s" % ("ACTIVE ⚡" if powered else "UNPOWERED")
			held_label.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.4) if powered else Color(0.9, 0.6, 0.2))
		"eliminate_priority":
			var alive = GameManager.priority_target_alive
			held_label.text = "Target: %s" % ("ELIMINATED ✓" if not alive else "AT LARGE ✦")
			held_label.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.4) if not alive else Color(0.9, 0.3, 0.3))
		"extract":
			var ez = GameManager.extraction_zone
			var at_ez = 0
			for squad in SquadManager.get_squads_for_ui():
				if squad.sector == ez and squad.status != SquadManager.Status.LOST:
					at_ez += 1
			held_label.text = "At extraction: %d squad(s)" % at_ez
			held_label.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.4) if at_ez > 0 else Color(0.9, 0.6, 0.2))

func _update_squad_summary() -> void:
	for child in squad_summary.get_children():
		child.queue_free()
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
	var summary := Label.new()
	summary.text = ", ".join(parts)
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	squad_summary.add_child(summary)


func _update_lock_status() -> void:
	if not lock_status_lbl or not end_turn_btn: return

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
	var lines = []
	var active = 0; var wounded = 0
	for squad in SquadManager.get_squads_for_ui():
		match squad.status:
			SquadManager.Status.ACTIVE:  active += 1
			SquadManager.Status.WOUNDED: wounded += 1
	if active > 0:  lines.append("%d squad%s operational." % [active, "s" if active > 1 else ""])
	if wounded > 0: lines.append("%d squad%s wounded." % [wounded, "s" if wounded > 1 else ""])
	var held = EnemyManager.get_held_count()
	lines.append("%d sector%s held." % [held, "s" if held != 1 else ""])
	var pool = GameManager.get_supply_pool()
	lines.append("Pool — Arms: %d  Meds: %d  Fuel: %d" % [
		pool.get("Armaments", 0),
		pool.get("Medi-Packs", 0),
		pool.get("Fuel Cells", 0),
	])
	debrief_label.text = "\n".join(lines)


func _show_report(report: Dictionary) -> void:
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

	# Carry-over summary
	var carry_pool  = report.get("supply_pool", {})
	var carry_reinf = report.get("reinforcements", 0)
	var carry_text  = ""
	if not carry_pool.is_empty():
		carry_text = "\n\nCarrying forward:\nArms %d  ·  Meds %d  ·  Fuel %d  ·  Reinf %d" % [
			carry_pool.get("Armaments", 0),
			carry_pool.get("Medi-Packs", 0),
			carry_pool.get("Fuel Cells", 0),
			carry_reinf,
		]

	if report_title:
		report_title.text = "MISSION COMPLETE" if won else "MISSION FAILED"
		report_title.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if won else Color(0.9, 0.3, 0.3))
		report_title.add_theme_font_size_override("font_size", 28)

	if rating_label:
		rating_label.text = rating
		rating_label.add_theme_color_override("font_color", _rating_color(rating))
		rating_label.add_theme_font_size_override("font_size", 48)
		rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if tile_val:   tile_val.text   = str(t_score)
	if turn_val:   turn_val.text   = str(t_bonus)
	if supply_val:
		supply_val.text = str(s_bonus)
		# Colour supply bonus — reward for conservation
		supply_val.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if s_bonus > 150 else
			Color(0.9, 0.7, 0.2) if s_bonus > 50 else
			Color(0.9, 0.3, 0.3))
	if total_val:
		total_val.text = str(score)
		total_val.add_theme_color_override("font_color", _rating_color(rating))

	if report_body:
		if won:
			report_body.text = (
				"Sectors held: %d / %d\nSquads operational: %d   Squads lost: %d\nTurns taken: %d%s"
				% [held, req, alive, lost_c, turns, carry_text]
			)
		else:
			var reason = report.get("reason", "Mission objectives not met.")
			report_body.text = (
				"%s\n\nSectors held: %d / %d required\nSquads lost: %d   Turns: %d%s"
				% [reason, held, req, lost_c, turns, carry_text]
			)
		report_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		report_body.autowrap_mode = TextServer.AUTOWRAP_WORD

	# Next mission button — only on win and if missions remain
	var more_missions = GameManager.current_mission + 1 < GameManager.missions.size()
	next_mission_btn.visible = won and more_missions
	next_mission_btn.text = "Advance to %s  →" % _next_mission_title()


func _next_mission_title() -> String:
	var next_idx = GameManager.current_mission + 1
	if next_idx < GameManager.missions.size():
		return GameManager.missions[next_idx].get("title", "Next Mission")
	return "Next Mission"


func _on_next_mission_pressed() -> void:
	# Hide report, reset popup state
	report_panel.visible = false
	next_mission_btn.visible = false
	var main_panel = get_node_or_null("PanelContainer")
	if main_panel: main_panel.visible = true

	# Close popup first so player returns to the room
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()

	# Advance campaign
	GameManager.advance_to_next_mission()


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
