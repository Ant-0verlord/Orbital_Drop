extends Control
# =============================================================
# CommandThronePopup.gd
# Attach to: Control node named "CommandThronePopup" inside
#            Command_Throne.tscn > StaticBody3D
#
# Shows: mission title, current objective, turns remaining,
#        last turn debrief, and the Turn Seal (end turn button).
# Ending the turn is handled here — player must physically
# walk to the Command Throne to lock in decisions.
# =============================================================

var player: Node = null

# UI refs
var mission_label:  Label
var turn_label:     Label
var objective_label: Label
var debrief_label:  Label
var seal_button:    Button
var warning_label:  Label


func _ready() -> void:
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.turn_ended.connect(_on_turn_ended)
	TurnManager.mission_complete.connect(_on_mission_complete)
	TurnManager.mission_failed.connect(_on_mission_failed)
	_build_ui()


func refresh() -> void:
	_update_display()


# -------------------------------------------------------
# Build UI
# -------------------------------------------------------
func _build_ui() -> void:
	custom_minimum_size = Vector2(520, 0)
	set_anchors_preset(Control.PRESET_CENTER)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Mission title
	mission_label = Label.new()
	mission_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(mission_label)

	# Turn counter
	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 14)
	turn_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(turn_label)

	vbox.add_child(HSeparator.new())

	# Objective
	var obj_header := Label.new()
	obj_header.text = "CURRENT OBJECTIVE"
	obj_header.add_theme_font_size_override("font_size", 12)
	obj_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(obj_header)

	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	objective_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(objective_label)

	vbox.add_child(HSeparator.new())

	# Last turn debrief
	var debrief_header := Label.new()
	debrief_header.text = "LAST TURN DEBRIEF"
	debrief_header.add_theme_font_size_override("font_size", 12)
	debrief_header.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(debrief_header)

	debrief_label = Label.new()
	debrief_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	debrief_label.add_theme_font_size_override("font_size", 13)
	debrief_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(debrief_label)

	vbox.add_child(HSeparator.new())

	# Warning
	warning_label = Label.new()
	warning_label.text = ""
	warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(warning_label)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)

	seal_button = Button.new()
	seal_button.text = "ENGAGE TURN SEAL"
	seal_button.pressed.connect(_on_seal_pressed)
	btn_row.add_child(seal_button)


# -------------------------------------------------------
# Display update
# -------------------------------------------------------
func _update_display() -> void:
	var mission_data = GameManager.get_current_mission_data()
	mission_label.text  = mission_data.get("title", "ORBITAL DROP")
	var max_turns       = mission_data.get("turns", 0)
	var current         = TurnManager.current_turn
	turn_label.text     = "Turn %d of %d" % [current, max_turns]
	objective_label.text = _get_objective(mission_data, current)

	if current == 0:
		debrief_label.text = "No turns resolved yet. Issue your first allocations."
	else:
		debrief_label.text = _build_debrief()

	# Disable seal if no squads are alive
	var any_alive = false
	for squad_name in SquadManager.squads:
		if SquadManager.squads[squad_name].status != SquadManager.Status.LOST:
			any_alive = true
			break
	seal_button.disabled = not any_alive
	warning_label.text = "" if any_alive else "All squads lost. Mission failed."


func _get_objective(mission_data: Dictionary, current_turn: int) -> String:
	var _title = mission_data.get("title", "")
	var turns = mission_data.get("turns", 0)
	var remaining = max(0, turns - current_turn)

	match GameManager.current_mission:
		0: return "Establish a foothold. Keep both squads alive for %d more turn%s." % [remaining, "s" if remaining != 1 else ""]
		1: return "Push the advance. Maintain all three squads for %d more turn%s." % [remaining, "s" if remaining != 1 else ""]
		2: return "Hold the salient. Prevent sector collapse for %d more turn%s." % [remaining, "s" if remaining != 1 else ""]
		3: return "Contest the Hive Spire. Prioritise critical squads. %d turn%s remaining." % [remaining, "s" if remaining != 1 else ""]
		4: return "Final assault. All five squads must survive. %d turn%s remaining." % [remaining, "s" if remaining != 1 else ""]
	return "%d turn%s remaining." % [remaining, "s" if remaining != 1 else ""]


func _build_debrief() -> String:
	# Summarise what happened last turn across all squads
	var active   = 0
	var wounded  = 0
	var critical = 0
	var lost     = 0

	for squad_name in SquadManager.squads:
		match SquadManager.squads[squad_name].status:
			SquadManager.Status.ACTIVE:   active   += 1
			SquadManager.Status.WOUNDED:  wounded  += 1
			SquadManager.Status.CRITICAL: critical += 1
			SquadManager.Status.LOST:     lost     += 1

	var lines: Array = []
	if active   > 0: lines.append("%d squad%s operational." % [active,   "s" if active   != 1 else ""])
	if wounded  > 0: lines.append("%d squad%s wounded." %     [wounded,  "s" if wounded  != 1 else ""])
	if critical > 0: lines.append("%d squad%s CRITICAL — act immediately." % [critical, "s" if critical != 1 else ""])
	if lost     > 0: lines.append("%d squad%s lost. No further contact." % [lost,     "s" if lost     != 1 else ""])

	return "\n".join(lines) if lines.size() > 0 else "No status reports received."


# -------------------------------------------------------
# Turn Seal
# -------------------------------------------------------
func _on_seal_pressed() -> void:
	# The Turn Seal locks in decisions — but allocations are
	# confirmed at the Logistics Terminal. Here we just
	# verify and close. If the player hasn't confirmed
	# allocations yet, warn them.
	if TurnManager.current_turn == SquadManager.current_turn:
		# Turn already resolved this cycle — player is reviewing
		warning_label.text = "Allocations already confirmed this turn. Check Intel Console for results."
		return

	warning_label.text = ""
	_on_close_pressed()


# -------------------------------------------------------
# Signal handlers
# -------------------------------------------------------
func _on_turn_started(_turn: int) -> void:
	if visible:
		_update_display()


func _on_turn_ended(_turn: int) -> void:
	if visible:
		_update_display()


func _on_mission_complete() -> void:
	if visible:
		objective_label.text = "MISSION COMPLETE. Stand by for campaign debrief."
		seal_button.disabled = true


func _on_mission_failed(reason: String) -> void:
	if visible:
		objective_label.text = "MISSION FAILED — %s" % reason
		objective_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		seal_button.disabled = true


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
