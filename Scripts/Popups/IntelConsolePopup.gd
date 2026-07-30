extends Control
# =============================================================
# IntelConsolePopup.gd
# UI built in scene, not in code.
#
# Shows what happened last turn and squad status.
# Squad NEEDS are NOT shown here — check the Vox-Caster.
# =============================================================

var player_reinforcement_info: Dictionary = {}
var bombardment_report: Dictionary = {}
var player: Node = null
var reinforcement_warning_turn: int  = -1
var reinforcement_warning_count: int = 0
var landed_sectors: Array            = []
var landed_turn: int                 = -1
var data_destroyed_sector: String = ""
var data_destroyed_turn: int = -1

@onready var help_btn: Button = $PanelContainer/VBoxContainer/ButtonRow/HelpBtn
@onready var turn_label: Label              = $PanelContainer/VBoxContainer/TurnLabel
@onready var report_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/ReportContainer
@onready var close_btn: Button              = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn
@onready var tutorial_overlay: Control = $TutorialOverlay



func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.enemy_reinforcements_incoming.connect(_on_reinforcements_incoming)
	TurnManager.enemy_reinforcements_landed.connect(_on_reinforcements_landed)
	EnemyManager.reinforcement_landed.connect(_on_player_reinforcement_landed)
	TurnManager.orbital_strike_resolved.connect(_on_orbital_strike_resolved)
	EnemyManager.data_destroyed_by_strike.connect(_on_data_destroyed)
	close_btn.pressed.connect(_on_close_pressed)
	help_btn.pressed.connect(_on_help_pressed)

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
	
	if not player_reinforcement_info.is_empty() and player_reinforcement_info.get("turn") == SquadManager.current_turn:
		_add_player_reinforcement_card(player_reinforcement_info)

	if not bombardment_report.is_empty() and bombardment_report.get("turn") == SquadManager.current_turn:
		_add_bombardment_report_card(bombardment_report)
	
	# Reinforcement alerts — shown above all squad reports
	if landed_sectors.size() > 0 and landed_turn == SquadManager.current_turn:
		_add_reinforcements_landed_card(landed_sectors)

	if reinforcement_warning_turn > SquadManager.current_turn:
		_add_reinforcements_warning_card(reinforcement_warning_count, reinforcement_warning_turn)

	if GameManager.mission_type == "extract" and SquadManager.current_turn == 0:
		_add_extraction_zone_card()

	if data_destroyed_sector != "" and data_destroyed_turn == SquadManager.current_turn:
		_add_data_destroyed_card(data_destroyed_sector)

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

func _on_help_pressed() -> void:
	set_help_attention(false)
	GameManager.mark_attention_seen("intel_reinf_warning_%d" % reinforcement_warning_turn)
	GameManager.mark_attention_seen("intel_reinf_landed_%d" % landed_turn)
	GameManager.mark_attention_seen("intel_strike_%d" % SquadManager.current_turn)
	GameManager.mark_attention_seen("intel_data_destroyed")
	GameManager.mark_attention_seen("intel_player_reinf_%s" % player_reinforcement_info.get("squad_name", ""))

	var steps: Array[TutorialStep] = [
		_step(
			"INTEL REPORTS — Each card shows what a squad did last turn, their current status, and their next objective. Read these every turn to understand what your squads are doing and what they need.",
			^"PanelContainer/VBoxContainer/ScrollContainer/ReportContainer"
		),
		_step(
			"ALERT CARDS — Amber cards warn of incoming enemy reinforcements. Red cards report critical events: enemy landings, orbital strike results, data secured or destroyed. Check these first each turn.",
			^"PanelContainer/VBoxContainer/ScrollContainer/ReportContainer"
		),
		_step(
			"SQUAD OBJECTIVES — Under each report you will see the squad's current goal and what supply they are requesting next turn. Use this to plan your Logistics allocations.",
			^"PanelContainer/VBoxContainer/ScrollContainer/ReportContainer"
		),
	]
	tutorial_overlay.start(steps, self)



func _step(text: String, path: NodePath) -> TutorialStep:
	var s := TutorialStep.new()
	s.text = text
	s.target_path = path
	return s

func _on_orbital_strike_resolved(report: Dictionary) -> void:
	bombardment_report = report
	if not GameManager.has_seen_attention("intel_strike_%d" % SquadManager.current_turn):
		set_help_attention(true)
	if visible: refresh()

func _on_data_destroyed(sector: String) -> void:
	data_destroyed_sector = sector
	data_destroyed_turn   = SquadManager.current_turn
	if not GameManager.has_seen_attention("intel_data_destroyed"):
		set_help_attention(true)
	if visible: refresh()

func _on_player_reinforcement_landed(squad_name: String, sector: String, surprise: bool) -> void:
	player_reinforcement_info = { "squad_name": squad_name, "sector": sector, "surprise": surprise, "turn": SquadManager.current_turn }
	if not GameManager.has_seen_attention("intel_player_reinf_%s" % squad_name):
		set_help_attention(true)
	if visible: refresh()

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

	if squad_data.has("goal") and squad_data.status != SquadManager.Status.LOST:
		var goal_text = _get_goal_text(squad_name, squad_data)
		if goal_text != "":
			var goal_lbl := Label.new()
			goal_lbl.text = goal_text
			goal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			goal_lbl.add_theme_font_size_override("font_size", 11)
			goal_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.9))
			vbox.add_child(goal_lbl)

	report_container.add_child(card)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	report_container.add_child(spacer)

func _get_goal_text(squad_name: String, squad_data: Dictionary) -> String:
	var interference = SquadManager.interference
	if randf() < interference * 0.4:
		return "OBJECTIVE: [INTERFERENCE]"

	var goal = squad_data.get("goal", SquadManager.Goal.ADVANCE)
	var goal_name = SquadManager.GOAL_NAMES.get(goal, "Unknown")

	var need_hint = ""
	match goal:
		SquadManager.Goal.POWER_TOWER:
			var turns_left = 2 - squad_data.get("tower_fuel_turns", 0)
			need_hint = " — requesting Fuel Cells (%d turn(s) to activate)" % turns_left
		SquadManager.Goal.HOLD_TOWER:
			need_hint = " — holding position, requesting Armaments"
		SquadManager.Goal.ATTACK_PRIORITY:
			var pt = GameManager.priority_target_name
			need_hint = " — en route to eliminate %s" % pt if pt != "" else ""
		SquadManager.Goal.EXTRACT:
			need_hint = " — moving to extraction, requesting Fuel Cells"
		SquadManager.Goal.FALLBACK:
			need_hint = " — falling back, no fuel received in time"

	return "OBJECTIVE: %s%s" % [goal_name, need_hint]

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
	reinforcement_warning_turn  = turn
	reinforcement_warning_count = count
	if not GameManager.has_seen_attention("intel_reinf_warning_%d" % turn):
		set_help_attention(true)
	if visible: refresh()

func _on_reinforcements_landed(sectors: Array) -> void:
	landed_sectors = sectors
	landed_turn    = SquadManager.current_turn
	if not GameManager.has_seen_attention("intel_reinf_landed_%d" % SquadManager.current_turn):
		set_help_attention(true)
	if visible: refresh()

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

func _add_player_reinforcement_card(info: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _alert_style(Color(0.05, 0.18, 0.1), Color(0.3, 0.85, 0.4, 0.95)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "✓ REINFORCEMENT DEPLOYED"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	vbox.add_child(header)

	var body := Label.new()
	var surprise_text = " — caught enemy forces by surprise on landing" if info.get("surprise", false) else ""
	body.text = "%s has dropped into %s%s." % [info.get("squad_name", ""), info.get("sector", ""), surprise_text]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.7, 0.9, 0.75))
	vbox.add_child(body)

	report_container.add_child(card)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	report_container.add_child(spacer)


func _add_bombardment_report_card(report: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _alert_style(Color(0.2, 0.1, 0.02), Color(1.0, 0.55, 0.1, 0.95)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "☄ ORBITAL STRIKE — IMPACT CONFIRMED"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	vbox.add_child(header)

	var killed = report.get("enemies_killed", 0)
	var center = report.get("center", "")
	var unit_word = "unit" if killed == 1 else "units"
	var body := Label.new()
	body.text = "Strike centred on %s eliminated %d enemy %s across the blast radius." % [center, killed, unit_word]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.95, 0.8, 0.6))
	vbox.add_child(body)

	var squads_hit = report.get("squads_hit", [])
	if squads_hit.size() > 0:
		var ff_lbl := Label.new()
		ff_lbl.text = "⚠ Friendly fire: %s caught in the blast radius." % ", ".join(squads_hit)
		ff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		ff_lbl.add_theme_font_size_override("font_size", 12)
		ff_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		vbox.add_child(ff_lbl)

	report_container.add_child(card)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	report_container.add_child(spacer)

func _add_extraction_zone_card() -> void:
	var ez = GameManager.extraction_zone
	if ez == "":
		return

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _alert_style(Color(0.15, 0.12, 0.02), Color(0.95, 0.8, 0.1, 0.95)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "▲ EXTRACTION ZONE CONFIRMED"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
	vbox.add_child(header)

	var body := Label.new()
	body.text = "Shuttle inbound to %s. All surviving squads must reach this sector by end of final turn. Enemy forces are converging on the zone — protect the data carrier at all costs." % ez
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vbox.add_child(body)

	report_container.add_child(card)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	report_container.add_child(spacer)

func _add_data_destroyed_card(sector: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _alert_style(Color(0.2, 0.05, 0.05), Color(1.0, 0.2, 0.2, 0.95)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = "⚠ CRITICAL — PRIORITY TARGET DATA DESTROYED"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(header)

	var body := Label.new()
	body.text = "Orbital strike at %s eliminated %s but destroyed the objective data in the blast. Extraction will proceed but mission outcome is degraded — the campaign objective is compromised." % [sector, GameManager.priority_target_name]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.95, 0.6, 0.6))
	vbox.add_child(body)

	report_container.add_child(card)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	report_container.add_child(spacer)
