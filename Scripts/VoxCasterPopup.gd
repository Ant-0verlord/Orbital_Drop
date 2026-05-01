extends Control
# =============================================================
# VoxCasterPopup.gd
# Attach to: Control node named "VoxCasterPopup" inside
#            Vox-Caster_Array.tscn > StaticBody3D
#
# Shows incoming squad transmissions — partially garbled
# based on interference level. Gives hints about squad
# needs without being as direct as the Intel Console.
# Updates each turn with new transmissions.
# =============================================================

var player: Node = null

# Transmission history — shown in the log
var transmission_log: Array = []
const MAX_LOG_ENTRIES: int = 12

# Raw transmission templates per need/status
const TRANSMISSIONS: Dictionary = {
	"Armaments_ACTIVE": [
		"—{squad}— here, pushing {sector}— need arms— can you— —static— —send ordnance—",
		"{squad}, sector {sector}— engaging— ammunition running— —request— —arms drop—",
		"—static— {squad} to command— we can take {sector}— just— —send the guns—",
	],
	"Armaments_WOUNDED": [
		"—{squad}— wounded but holding— —need arms— or we— —static— —can't push—",
		"—static— {squad}— {sector}— taking fire— send— —armaments— please—",
	],
	"Medi-Packs_WOUNDED": [
		"{squad} to command— casualties— —static— —we need med— {sector}— —send medi—",
		"—static— {squad}— men down— —sector {sector}— —medical— urgent— —static—",
		"—{squad}— {sector}— wounded— can you— —static— —medi-packs— now—",
	],
	"Medi-Packs_CRITICAL": [
		"—{squad}— CRITICAL— {sector}— —static— —MED NOW— losing— —static— —please—",
		"—static— —{squad}— men dying— {sector}— send— —MEDI— —static— —hurry—",
	],
	"Fuel Cells_ACTIVE": [
		"—{squad}— vehicles dead— {sector}— —need fuel— —static— —can't move—",
		"{squad} to command— stalled at {sector}— —fuel cells— —static— —send them—",
	],
	"Fuel Cells_WOUNDED": [
		"—static— {squad}— wounded— stranded— {sector}— —fuel— —need fuel— —static—",
	],
	"LOST": [
		"—{squad}— —static— ———— —static— ———————————",
		"—static— ——————— —no signal— ——————— —static—",
		"—————————— —static— ————— ——————————————————",
	],
	"UNSUPPLIED": [
		"—{squad}— where is— —static— —supply drop— {sector}— —nothing arrived—",
		"—static— {squad}— no supplies— {sector}— —we're— —static— —alone out here—",
	],
}


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	_build_ui()


func refresh() -> void:
	_sync_transmissions()
	_rebuild_log()


# -------------------------------------------------------
# Generate transmissions from current squad state
# -------------------------------------------------------
func _sync_transmissions() -> void:
	if SquadManager.current_turn == 0:
		_generate_briefing_transmissions()
	# After turn 1+ transmissions are added in _on_turn_resolved


func _generate_briefing_transmissions() -> void:
	transmission_log.clear()
	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		var need_str = SquadManager.NEED_NAMES[squad.need]
		var key = "%s_%s" % [need_str, SquadManager.STATUS_NAMES[squad.status]]
		var raw = _pick_transmission(key, squad_name, squad.sector)
		transmission_log.append({
			"turn":    0,
			"squad":   squad_name,
			"text":    _apply_interference(raw),
			"status":  squad.status,
		})


func _generate_turn_transmissions() -> void:
	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		var text: String

		if squad.status == SquadManager.Status.LOST:
			text = _pick_transmission("LOST", squad_name, squad.sector)
		elif squad.turns_unsupplied > 0:
			text = _pick_transmission("UNSUPPLIED", squad_name, squad.sector)
		else:
			var need_str = SquadManager.NEED_NAMES[squad.need]
			var status_str = SquadManager.STATUS_NAMES[squad.status]
			var key = "%s_%s" % [need_str, status_str]
			text = _pick_transmission(key, squad_name, squad.sector)

		transmission_log.append({
			"turn":   SquadManager.current_turn,
			"squad":  squad_name,
			"text":   _apply_interference(text),
			"status": squad.status,
		})

	# Trim log to max entries
	while transmission_log.size() > MAX_LOG_ENTRIES:
		transmission_log.pop_front()


func _pick_transmission(key: String, squad_name: String, sector: String) -> String:
	var options: Array = TRANSMISSIONS.get(key, TRANSMISSIONS["UNSUPPLIED"])
	var raw: String = options[randi() % options.size()]
	return raw.replace("{squad}", squad_name).replace("{sector}", sector)


func _apply_interference(text: String) -> String:
	var interference = SquadManager.interference
	if interference <= 0.0:
		return text

	# Higher interference = more static/gaps
	var words = text.split(" ")
	for i in range(words.size()):
		if words[i] != "—static—" and words[i] != "————" and randf() < interference * 0.3:
			words[i] = "—static—"
	return " ".join(words)


# -------------------------------------------------------
# Build UI
# -------------------------------------------------------
func _build_ui() -> void:
	custom_minimum_size = Vector2(560, 0)
	set_anchors_preset(Control.PRESET_CENTER)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "VOX-CASTER ARRAY"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Incoming surface transmissions — signal quality varies"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 340
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var log_container := VBoxContainer.new()
	log_container.name = "LogContainer"
	log_container.add_theme_constant_override("separation", 6)
	log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_container)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)


func _rebuild_log() -> void:
	var container = get_node_or_null("PanelContainer/VBoxContainer/ScrollContainer/LogContainer")
	if container == null:
		return

	for child in container.get_children():
		child.queue_free()

	if transmission_log.is_empty():
		var lbl := Label.new()
		lbl.text = "No transmissions received."
		container.add_child(lbl)
		return

	# Show newest first
	var reversed_log = transmission_log.duplicate()
	reversed_log.reverse()

	for entry in reversed_log:
		container.add_child(_make_transmission_entry(entry))


func _make_transmission_entry(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(8)
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
	style.corner_radius_bottom_right = 3

	match entry.status:
		SquadManager.Status.ACTIVE:   style.bg_color = Color(0.10, 0.15, 0.10)
		SquadManager.Status.WOUNDED:  style.bg_color = Color(0.16, 0.13, 0.05)
		SquadManager.Status.CRITICAL: style.bg_color = Color(0.18, 0.06, 0.06)
		SquadManager.Status.LOST:     style.bg_color = Color(0.08, 0.08, 0.08)
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# Header: turn + squad name
	var header := Label.new()
	header.text = "Turn %d  |  %s" % [entry.turn, entry.squad]
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(header)

	# Transmission text
	var text_lbl := Label.new()
	text_lbl.text = entry.text
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_lbl.add_theme_font_size_override("font_size", 13)
	text_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	vbox.add_child(text_lbl)

	return card


func _on_turn_resolved() -> void:
	_generate_turn_transmissions()
	if visible:
		_rebuild_log()


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
