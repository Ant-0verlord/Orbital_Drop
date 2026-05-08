extends Control
# =============================================================
# VoxCasterPopup.gd
# Attach to: Control node named "VoxCasterPopup" inside
#            Vox-Caster_Array.tscn > StaticBody3D
#
# THE ONLY PLACE squad needs are shown.
# Normal transmissions are garbled by interference.
# Critical squads break through with priority distress calls.
# =============================================================

var player: Node = null

const STATIC_CHARS = ["—", "█", "░", "▒", "?", "#", "~", "×"]


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	_build_ui()


func _on_turn_started(_turn: int) -> void:
	if visible:
		refresh()


func _on_turn_resolved() -> void:
	if visible:
		refresh()


func refresh() -> void:
	if SquadManager.squads.is_empty():
		return
	_rebuild_transmissions()


func _build_ui() -> void:
	custom_minimum_size = Vector2(520, 0)
	set_anchors_preset(Control.PRESET_CENTER)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "VOX-CASTER ARRAY"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Incoming surface transmissions — signal quality varies"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	vbox.add_child(subtitle)

	var turn_lbl := Label.new()
	turn_lbl.name = "TurnLabel"
	turn_lbl.add_theme_font_size_override("font_size", 12)
	turn_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 0.9))
	vbox.add_child(turn_lbl)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.custom_minimum_size.y = 340
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var container := VBoxContainer.new()
	container.name = "TransmissionContainer"
	container.add_theme_constant_override("separation", 10)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(container)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)


func _rebuild_transmissions() -> void:
	var turn_lbl = get_node_or_null("PanelContainer/VBoxContainer/TurnLabel")
	var container = get_node_or_null("PanelContainer/VBoxContainer/ScrollContainer/TransmissionContainer")
	if container == null:
		return

	if turn_lbl:
		turn_lbl.text = (
			"Pre-mission — awaiting drop confirmation"
			if SquadManager.current_turn == 0
			else "Turn %d transmissions" % SquadManager.current_turn
		)

	for child in container.get_children():
		child.queue_free()

	# Critical squads get priority distress calls at the top
	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		if squad.status == SquadManager.Status.CRITICAL:
			_add_distress_call(container, squad)

	# All squads get a need transmission (garbled by interference)
	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		if squad.status == SquadManager.Status.CRITICAL:
			continue  # Already shown as distress call above
		_add_need_transmission(container, squad)


func _add_distress_call(container: Node, squad: Dictionary) -> void:
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

	# Priority header
	var priority_lbl := Label.new()
	priority_lbl.text = "⚠ PRIORITY DISTRESS — %s [%s]" % [squad.name, squad.sector]
	priority_lbl.add_theme_font_size_override("font_size", 13)
	priority_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(priority_lbl)

	# Distress message — mostly clear even at high interference
	var need_str = SquadManager.NEED_NAMES[squad.need]
	var msg = "%s — we are losing men. Send %s immediately or we will not hold." % [squad.name, need_str]
	var body_lbl := Label.new()
	body_lbl.text = msg
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.add_theme_font_size_override("font_size", 12)
	body_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	vbox.add_child(body_lbl)

	container.add_child(card)


func _add_need_transmission(container: Node, squad: Dictionary) -> void:
	if squad.status == SquadManager.Status.LOST:
		_add_lost_signal(container, squad)
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

	# Header
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

	# Need line — this is what the player needs to interpret
	var need_str = SquadManager.NEED_NAMES[squad.need]
	var raw_need_msg = "Requesting %s. Awaiting your order." % need_str
	var garbled_need = _garble_text(raw_need_msg, interference)

	var need_lbl := Label.new()
	need_lbl.text = garbled_need
	need_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	need_lbl.add_theme_font_size_override("font_size", 13)
	need_lbl.add_theme_color_override("font_color",
		Color(0.9, 0.8, 0.4) if interference < 0.5 else Color(0.6, 0.6, 0.5)
	)
	vbox.add_child(need_lbl)

	# Status context line — also garbled
	var status_msg = _status_context(squad)
	var garbled_status = _garble_text(status_msg, interference * 0.6)
	var status_lbl := Label.new()
	status_lbl.text = garbled_status
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	vbox.add_child(status_lbl)

	container.add_child(card)


func _add_lost_signal(container: Node, squad: Dictionary) -> void:
	var lbl := Label.new()
	lbl.text = ">>> %s [%s] — CARRIER LOST — NO SIGNAL" % [squad.name, squad.sector]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	container.add_child(lbl)


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
