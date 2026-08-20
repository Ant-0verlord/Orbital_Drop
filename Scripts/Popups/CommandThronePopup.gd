extends Control
# =============================================================
# CommandThronePopup.gd
# UI built in scene, not in code.
# =============================================================

var player: Node = null

@onready var title_label: Label           = $PanelContainer/VBoxContainer/Title
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
@onready var help_btn: Button = $PanelContainer/VBoxContainer/ButtonRow/HelpBtn
@onready var tutorial_overlay: Control = $TutorialOverlay  # add TutorialOverlay.tscn as a child
@onready var help_nudge: Control = $HelpNudge


func _ready() -> void:
	_style_header("COMMAND THRONE", "Mission briefing & turn-ending station")
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.turn_ended.connect(_on_turn_ended)
	TurnManager.allocations_locked.connect(_on_allocations_locked)
	TurnManager.mission_complete.connect(_on_mission_complete)
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	GameManager.tower_activated.connect(_on_tower_activated)
	EnemyManager.priority_target_eliminated.connect(_on_priority_eliminated)

	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	report_close.pressed.connect(_on_close_pressed)
	next_mission_btn.pressed.connect(_on_next_mission_pressed)
	help_btn.pressed.connect(_on_help_pressed)
	visibility_changed.connect(_on_visibility_changed)

	report_panel.visible = false
	next_mission_btn.visible = false

	_style_primary_button(end_turn_btn)
	_style_primary_button(next_mission_btn)

	# Inside a ScrollContainer, a child only stretches to the full
	# available width if explicitly told to expand — otherwise it
	# shrinks to its content's natural width, which made every squad
	# card render far narrower than the console frame around it.
	squad_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_visibility_changed() -> void:
	if not visible:
		return
	if GameManager.has_seen_attention("help_nudge_seen_throne"):
		return
	GameManager.mark_attention_seen("help_nudge_seen_throne")
	help_nudge.point_at(help_btn)


func _on_tower_activated() -> void:
	if not GameManager.has_seen_attention("throne_tower_activated"):
		set_help_attention(true)

func _on_priority_eliminated(_squad: String, _sector: String) -> void:
	if not GameManager.has_seen_attention("throne_priority_eliminated"):
		set_help_attention(true)

var _help_attention: bool = false
var _attention_pulse: float = 0.0

func _process(delta: float) -> void:
	if not _help_attention or help_btn == null:
		return
	_attention_pulse += delta * 3.0
	var t = (sin(_attention_pulse) + 1.0) * 0.5
	help_btn.modulate = Color(1.0, lerp(0.6, 1.0, t), lerp(0.0, 0.3, t), 1.0)

func set_help_attention(on: bool) -> void:
	_help_attention = on
	_attention_pulse = 0.0
	if not on and help_btn != null:
		help_btn.modulate = Color.WHITE

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
				return "Data secured. Break contact — get the carrier at least %d tiles from every remaining enemy before extraction is authorised." % TurnManager.DATA_CARRIER_SAFE_DISTANCE
		"extract":
			var ez = GameManager.extraction_zone
			return "Hold the theatre around the extraction zone (%s) — engage freely. Once the shuttle is inbound (%d turns before mission end), break off and converge to board. Data carrier must extract." % [ez, TurnManager.SHUTTLE_ARRIVAL_WINDOW]
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
			if alive:
				held_label.text = "Target: AT LARGE ✦"
				held_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			else:
				# Target's dead, but the mission isn't won until the data
				# carrier has actually put real distance between itself
				# and every enemy still standing — show that progress
				# instead of just a flat "eliminated" flag.
				var carrier_name = GameManager.data_carrier_squad
				var carrier_ok = carrier_name != "" and SquadManager.squads.has(carrier_name) \
					and SquadManager.squads[carrier_name].status != SquadManager.Status.LOST
				if not carrier_ok:
					held_label.text = "Data carrier lost ✗"
					held_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
				else:
					var dist = EnemyManager.get_distance_to_nearest_enemy(SquadManager.squads[carrier_name].sector)
					var safe = dist >= TurnManager.DATA_CARRIER_SAFE_DISTANCE
					held_label.text = "Carrier clear: %d / %d tiles" % [min(dist, TurnManager.DATA_CARRIER_SAFE_DISTANCE), TurnManager.DATA_CARRIER_SAFE_DISTANCE]
					held_label.add_theme_color_override("font_color",
						Color(0.4, 0.9, 0.4) if safe else Color(0.9, 0.6, 0.2))
		"extract":
			var ez = GameManager.extraction_zone
			var at_ez = 0
			for squad in SquadManager.get_squads_for_ui():
				if squad.sector == ez and squad.status != SquadManager.Status.LOST:
					at_ez += 1
			var turns_left = TurnManager.max_turns - TurnManager.current_turn
			if turns_left > TurnManager.SHUTTLE_ARRIVAL_WINDOW:
				held_label.text = "Holding theatre — shuttle in %d turns" % (turns_left - TurnManager.SHUTTLE_ARRIVAL_WINDOW)
				held_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
			else:
				held_label.text = "SHUTTLE INBOUND — At extraction: %d squad(s)" % at_ez
				held_label.add_theme_color_override("font_color",
					Color(0.4, 0.9, 0.4) if at_ez > 0 else Color(0.9, 0.6, 0.2))

func _update_squad_summary() -> void:
	for child in squad_summary.get_children():
		child.queue_free()
	var active = 0; var wounded = 0; var critical = 0; var lost = 0
	for squad in SquadManager.get_squads_for_ui():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _card_style(squad.status))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)

		var nl := Label.new()
		nl.text = squad.name
		nl.custom_minimum_size.x = 120
		nl.add_theme_font_size_override("font_size", 13)
		row.add_child(nl)

		var sector_lbl := Label.new()
		sector_lbl.text = squad.sector
		sector_lbl.add_theme_font_size_override("font_size", 12)
		sector_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		sector_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sector_lbl)

		row.add_child(_status_pill(squad.status))

		squad_summary.add_child(card)
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 4
		squad_summary.add_child(spacer)
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

	# Data package status — only relevant on missions with a priority
	# target/data carrier at all (eliminate_priority, extract).
	var data_text = ""
	match report.get("data_status", ""):
		"secured":
			data_text = "\n\nData package: SECURED — carried by %s." % report.get("data_carrier", "")
		"destroyed":
			data_text = "\n\nData package: DESTROYED — did not survive."
		"at_large":
			data_text = "\n\nData package: NOT RECOVERED — priority target still at large."
		"unaccounted":
			data_text = "\n\nData package: STATUS UNKNOWN — recovery not confirmed."

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
				"Sectors held: %d / %d\nSquads operational: %d   Squads lost: %d\nTurns taken: %d%s%s"
				% [held, req, alive, lost_c, turns, data_text, carry_text]
			)
		else:
			var reason = report.get("reason", "Mission objectives not met.")
			report_body.text = (
				"%s\n\nSectors held: %d / %d required\nSquads lost: %d   Turns: %d%s%s"
				% [reason, held, req, lost_c, turns, data_text, carry_text]
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
	AudioManager.play_button_other()
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

func _on_help_pressed() -> void:
	AudioManager.play_button_bottom()
	set_help_attention(false)
	GameManager.mark_attention_seen("throne_tower_activated")
	GameManager.mark_attention_seen("throne_priority_eliminated")
	var steps: Array[TutorialStep] = [
		_step(
			"CURRENT OBJECTIVE — Shows what you need to achieve to win this mission and your current progress toward it. Changes as mission events unfold.",
			^"PanelContainer/VBoxContainer/ObjectiveLabel"
		),
		_step(
			"SQUAD STATUS — A quick overview of all squads, their status, and their current position. Active is healthy. Wounded means taking casualties. Critical means one more hit and they are lost.",
			^"PanelContainer/VBoxContainer/SquadSummary"
		),
		_step(
			"LAST TURN DEBRIEF — A summary of what happened last turn across all squads. Read this alongside the Intel Desk for the full picture.",
			^"PanelContainer/VBoxContainer/DebriefLabel"
		),
		_step(
			"ENGAGE TURN SEAL — Ends the current turn and resolves all squad actions. You must lock allocations at the Logistics Terminal first. Once sealed you cannot undo it.",
			^"PanelContainer/VBoxContainer/TurnSealBtn"
		),
	]
	tutorial_overlay.start(steps, self)

func _step(text: String, path: NodePath) -> TutorialStep:
	var s := TutorialStep.new()
	s.text = text
	s.target_path = path
	return s	

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


# -------------------------------------------------------
# Rounded card + status "chip" — matches the card/pill
# style used at the Intel Console, Vox-Caster, and the
# Field Manual mockup layouts.
# -------------------------------------------------------
func _card_style(status: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left   = 4
	style.border_width_top    = 1
	style.border_width_right  = 1
	style.border_width_bottom = 1
	match status:
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
		_:
			style.bg_color     = Color(0.13, 0.13, 0.18)
			style.border_color = Color(0.4, 0.4, 0.55)
	return style


# -------------------------------------------------------
# Console header — big bold title + small grey subtitle,
# matching the Field Manual mockup layouts. The scene has
# no Subtitle node (unlike Intel/Vox-Caster), so it's
# built here at runtime and inserted right under Title.
# -------------------------------------------------------
func _style_header(title_text: String, subtitle_text: String) -> void:
	if title_label:
		title_label.text = title_text
		title_label.add_theme_font_size_override("font_size", 24)
		title_label.add_theme_color_override("font_color", Color(0.91, 0.91, 0.91))

		var subtitle_label := Label.new()
		subtitle_label.text = subtitle_text
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		subtitle_label.add_theme_font_size_override("font_size", 13)
		subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.73))
		var parent := title_label.get_parent()
		parent.add_child(subtitle_label)
		parent.move_child(subtitle_label, title_label.get_index() + 1)


# -------------------------------------------------------
# Amber-filled "primary" CTA button style — used for the
# turn-ending / mission-advancing buttons, matching the
# filled ENGAGE TURN SEAL button in the Field Manual mockup.
# -------------------------------------------------------
func _style_primary_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.275, 0.216, 0.039, 1.0)
	normal.border_color = Color(1.0, 0.851, 0.2, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10

	var hover := normal.duplicate()
	hover.bg_color = Color(0.35, 0.275, 0.05, 1.0)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.22, 0.17, 0.03, 1.0)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.055, 0.063, 0.078, 1.0)
	disabled.border_color = Color(0.157, 0.173, 0.204, 1.0)
	disabled.set_border_width_all(2)
	disabled.set_corner_radius_all(10)
	disabled.content_margin_left = 20
	disabled.content_margin_right = 20
	disabled.content_margin_top = 10
	disabled.content_margin_bottom = 10

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(1.0, 0.851, 0.2))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))
	btn.add_theme_font_size_override("font_size", 16)


func _status_pill(status: int) -> PanelContainer:
	var color := _status_color(status)
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.22 + 0.03, color.g * 0.22 + 0.03, color.b * 0.22 + 0.03, 1.0)
	style.border_color = color
	style.border_width_left   = 2
	style.border_width_top    = 2
	style.border_width_right  = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 9
	style.corner_radius_top_right    = 9
	style.corner_radius_bottom_left  = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 2
	style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = SquadManager.STATUS_NAMES[status].to_upper()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	pill.add_child(lbl)
	return pill
