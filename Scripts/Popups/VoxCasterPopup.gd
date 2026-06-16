extends Control
# =============================================================
# VoxCasterPopup.gd
# UI built in scene, not in code.
# =============================================================

var player: Node = null

const STATIC_CHARS = ["—", "█", "░", "▒", "?", "#", "~", "×"]

@onready var turn_label: Label                    = $PanelContainer/VBoxContainer/TurnLabel
@onready var transmission_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/TransmissionContainer
@onready var close_btn: Button                    = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.mission_complete.connect(_on_mission_complete)
	close_btn.pressed.connect(_on_close_pressed)


func _on_turn_started(_turn: int) -> void:
	if visible: refresh()

func _on_turn_resolved() -> void:
	if visible: refresh()

func _on_mission_complete(_report: Dictionary) -> void:
	if visible: refresh()


func refresh() -> void:
	if SquadManager.squads.is_empty():
		return
	_rebuild_transmissions()


func _rebuild_transmissions() -> void:
	if turn_label:
		turn_label.text = (
			"Pre-mission — awaiting drop confirmation"
			if SquadManager.current_turn == 0
			else "Turn %d transmissions" % SquadManager.current_turn
		)

	for child in transmission_container.get_children():
		child.queue_free()

	# Critical squads — priority distress at top
	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		if squad.status == SquadManager.Status.CRITICAL:
			_add_distress_call(squad)

	# All other squads
	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		if squad.status != SquadManager.Status.CRITICAL:
			_add_need_transmission(squad)


func _add_distress_call(squad: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.bg_color = Color(0.25, 0.05, 0.05)
	style.border_color = Color(1.0, 0.2, 0.2, 0.9)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var priority_lbl := Label.new()
	priority_lbl.text = "⚠ PRIORITY DISTRESS — %s [%s]" % [squad.name, squad.sector]
	priority_lbl.add_theme_font_size_override("font_size", 13)
	priority_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(priority_lbl)

	var need_str = SquadManager.NEED_NAMES[squad.need]
	var body_lbl := Label.new()
	body_lbl.text = "%s — we are losing men. Send %s immediately or we will not hold." % [squad.name, need_str]
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.add_theme_font_size_override("font_size", 12)
	body_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	vbox.add_child(body_lbl)

	# Mission over — show freeze notice
	if TurnManager.mission_over:
		_add_mission_over_banner(vbox)

	transmission_container.add_child(card)


func _add_need_transmission(squad: Dictionary) -> void:
	if squad.status == SquadManager.Status.LOST:
		_add_lost_signal(squad)
		return

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var interference = SquadManager.interference
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.bg_color = Color(0.05, 0.08, 0.12)
	style.border_color = Color(0.3, 0.5, 0.7, 0.6)
	style.border_width_left = 2
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var source_lbl := Label.new()
	source_lbl.text = ">>> %s  [%s]" % [squad.name, squad.sector]
	source_lbl.add_theme_font_size_override("font_size", 13)
	source_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	header.add_child(source_lbl)

	var quality_lbl := Label.new()
	quality_lbl.text = _signal_quality_text(interference)
	quality_lbl.add_theme_font_size_override("font_size", 10)
	quality_lbl.add_theme_color_override("font_color", _signal_quality_color(interference))
	header.add_child(quality_lbl)

	var need_str = SquadManager.NEED_NAMES[squad.need]
	var raw_need_msg = "Requesting %s. Awaiting your order." % need_str
	var need_lbl := Label.new()
	need_lbl.text = _garble_text(raw_need_msg, interference)
	need_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	need_lbl.add_theme_font_size_override("font_size", 13)
	need_lbl.add_theme_color_override("font_color",
		Color(0.9, 0.8, 0.4) if interference < 0.5 else Color(0.6, 0.6, 0.5))
	vbox.add_child(need_lbl)

	var status_lbl := Label.new()
	status_lbl.text = _garble_text(_status_context(squad), interference * 0.6)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	vbox.add_child(status_lbl)

	# Mission over — show freeze notice
	if TurnManager.mission_over:
		_add_mission_over_banner(vbox)

	transmission_container.add_child(card)


func _add_lost_signal(squad: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text = ">>> %s [%s] — CARRIER LOST — NO SIGNAL" % [squad.name, squad.sector]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	transmission_container.add_child(lbl)


func _add_mission_over_banner(parent: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = "— CHANNEL CLOSED — MISSION CONCLUDED —"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)


func _status_context(squad: Dictionary) -> String:
	match squad.status:
		SquadManager.Status.ACTIVE:
			return "Unit is operational and holding position."
		SquadManager.Status.WOUNDED:
			return "Casualties reported. Unit is holding but needs support."
		SquadManager.Status.CRITICAL:
			return "Critical losses. Unit cannot advance without immediate aid."
	return ""


func _garble_text(text: String, interference: float) -> String:
	if interference <= 0.1:
		return text
	var words = text.split(" ")
	var result = []
	for word in words:
		if randf() < interference * 0.45:
			result.append(STATIC_CHARS[randi() % STATIC_CHARS.size()].repeat(randi() % 3 + 1))
		elif randf() < interference * 0.25 and word.length() > 2:
			var chars = word.split("")
			for i in range(chars.size()):
				if randf() < interference * 0.2:
					chars[i] = STATIC_CHARS[randi() % STATIC_CHARS.size()]
			result.append("".join(chars))
		else:
			result.append(word)
	return " ".join(result)


func _signal_quality_text(interference: float) -> String:
	if interference < 0.2:   return "SIGNAL: CLEAR"
	elif interference < 0.5: return "SIGNAL: DEGRADED"
	elif interference < 0.8: return "SIGNAL: POOR"
	else:                    return "SIGNAL: CRITICAL"


func _signal_quality_color(interference: float) -> Color:
	if interference < 0.2:   return Color(0.3, 0.9, 0.3)
	elif interference < 0.5: return Color(0.9, 0.7, 0.2)
	elif interference < 0.8: return Color(0.9, 0.4, 0.1)
	else:                    return Color(0.9, 0.2, 0.2)


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
