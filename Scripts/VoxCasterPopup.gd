extends Control
# =============================================================
# VoxCasterPopup.gd
# Attach to: Control node named "VoxCasterPopup" inside
#            Vox-Caster_Array.tscn > StaticBody3D
#
# Shows incoming surface transmissions from squads.
# Transmissions are partially garbled based on interference.
# =============================================================

var player: Node = null

# Interference characters used to corrupt transmissions
const STATIC_CHARS = ["—", "█", "░", "▒", "?", "#", "~"]


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


# -------------------------------------------------------
# Build UI
# -------------------------------------------------------
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

	# Title
	var title := Label.new()
	title.text = "VOX-CASTER ARRAY"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Incoming surface transmissions — signal quality varies"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	vbox.add_child(subtitle)

	# Turn label
	var turn_lbl := Label.new()
	turn_lbl.name = "TurnLabel"
	turn_lbl.add_theme_font_size_override("font_size", 12)
	turn_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 0.9))
	vbox.add_child(turn_lbl)

	vbox.add_child(HSeparator.new())

	# Transmission list
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.custom_minimum_size.y = 320
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var transmission_container := VBoxContainer.new()
	transmission_container.name = "TransmissionContainer"
	transmission_container.add_theme_constant_override("separation", 10)
	transmission_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(transmission_container)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)


# -------------------------------------------------------
# Rebuild transmissions
# -------------------------------------------------------
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

	var reports: Dictionary = (
		SquadManager.get_briefings()
		if SquadManager.current_turn == 0
		else SquadManager.get_reports()
	)

	if reports.is_empty():
		var lbl := Label.new()
		lbl.text = "No transmissions received."
		container.add_child(lbl)
		return

	for squad_name in reports:
		var squad_data = SquadManager.squads.get(squad_name, {})
		var raw_text = reports[squad_name]
		_add_transmission(container, squad_name, raw_text, squad_data)


func _add_transmission(container: Node, squad_name: String, text: String, squad_data: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

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

	# Header: signal source
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var source_lbl := Label.new()
	source_lbl.text = ">>> %s" % squad_name
	source_lbl.add_theme_font_size_override("font_size", 13)
	source_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	header.add_child(source_lbl)

	if squad_data.has("sector"):
		var sector_lbl := Label.new()
		sector_lbl.text = "[%s]" % squad_data.sector
		sector_lbl.add_theme_font_size_override("font_size", 11)
		sector_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		header.add_child(sector_lbl)

	# Signal quality indicator
	var interference = SquadManager.interference
	var quality_lbl := Label.new()
	var quality_text: String
	var quality_color: Color
	if interference < 0.2:
		quality_text = "SIGNAL: CLEAR"
		quality_color = Color(0.3, 0.9, 0.3)
	elif interference < 0.5:
		quality_text = "SIGNAL: DEGRADED"
		quality_color = Color(0.9, 0.7, 0.2)
	elif interference < 0.8:
		quality_text = "SIGNAL: POOR"
		quality_color = Color(0.9, 0.4, 0.1)
	else:
		quality_text = "SIGNAL: CRITICAL"
		quality_color = Color(0.9, 0.2, 0.2)
	quality_lbl.text = quality_text
	quality_lbl.add_theme_font_size_override("font_size", 10)
	quality_lbl.add_theme_color_override("font_color", quality_color)
	header.add_child(quality_lbl)

	# Transmission body — apply vox garbling
	var garbled = _garble_text(text, interference)
	var body_lbl := Label.new()
	body_lbl.text = garbled
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.add_theme_font_size_override("font_size", 12)
	body_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vbox.add_child(body_lbl)

	container.add_child(card)


func _garble_text(text: String, interference: float) -> String:
	if interference <= 0.1:
		return text

	var words = text.split(" ")
	var result = []

	for word in words:
		# At high interference, randomly replace words with static
		if randf() < interference * 0.4:
			var static_char = STATIC_CHARS[randi() % STATIC_CHARS.size()]
			result.append(static_char.repeat(randi() % 4 + 1))
		# At medium+ interference, corrupt individual characters
		elif randf() < interference * 0.3 and word.length() > 2:
			var chars = word.split("")
			for i in range(chars.size()):
				if randf() < interference * 0.2:
					chars[i] = STATIC_CHARS[randi() % STATIC_CHARS.size()]
			result.append("".join(chars))
		else:
			result.append(word)

	return " ".join(result)


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
