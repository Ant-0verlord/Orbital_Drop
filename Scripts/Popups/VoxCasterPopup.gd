extends Control
# =============================================================
# VoxCasterPopup.gd
# UI built in scene, not in code.
# Mission 2+ adds transmission degradation:
#   - Dead channel (no signal)
#   - Echo/ghost signal (error, unreadable)
#   - Delayed burst (patchy, partially readable)
#   - Normal (existing garble system)
# =============================================================

var player: Node = null
var cached_turn: int = -1
var cached_quality: Dictionary = {}      # squad_name -> "normal"/"delayed"/"ghost"/"dead"
var cached_need_text: Dictionary = {}    # squad_name -> garbled need string
var cached_status_text: Dictionary = {}  # squad_name -> garbled status string
var cached_flavour: Dictionary = {}      # squad_name -> chosen flavour line (dead/ghost/delayed labels)

const STATIC_CHARS = ["—", "█", "░", "▒", "?", "#", "~", "×"]

# Dead channel flavour lines
const DEAD_CHANNEL = [
	"CARRIER LOST — SIGNAL ABSENT",
	"DEAD CHANNEL — NO RETURN",
	"VOX SILENT — UNKNOWN STATUS",
	"BLACKOUT — SURFACE CONTACT LOST",
]

# Error/ghost flavour lines
const GHOST_SIGNAL = [
	"ENCRYPTION FAULT — CONTENT UNRELIABLE",
	"SOLAR INTERFERENCE — VERIFY BEFORE ACTION",
	"GHOST SIGNAL — AUTHENTICITY UNCONFIRMED",
	"CHANNEL CORRUPTION — ASSUME WORST",
]

# Delayed/patchy flavour lines
const DELAYED_BURST = [
	"SIGNAL DEGRADED — TRANSMISSION FRAGMENTARY",
	"DELAYED BURST — DATA MAY BE STALE",
	"INTERFERENCE DETECTED — PARTIAL ONLY",
	"ECHO SIGNAL — ORIGIN UNCERTAIN",
]

@onready var turn_label: Label                     = $PanelContainer/VBoxContainer/TurnLabel
@onready var transmission_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/TransmissionContainer
@onready var close_btn: Button                     = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn
@onready var tutorial_overlay: Control = $TutorialOverlay
@onready var help_btn: Button = $PanelContainer/VBoxContainer/ButtonRow/HelpBtn


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.mission_complete.connect(_on_mission_complete)
	close_btn.pressed.connect(_on_close_pressed)
	help_btn.pressed.connect(_on_help_pressed)


func _on_turn_started(_turn: int) -> void:
	cached_turn = -1
	if not GameManager.has_seen_attention("vox_turn_%d" % _turn):
		set_help_attention(true)
	if visible: refresh()

func _on_turn_resolved() -> void:
	if visible: refresh()

func _on_mission_complete(_report: Dictionary) -> void:
	if visible: refresh()


func refresh() -> void:
	if SquadManager.squads.is_empty():
		return
	_ensure_cache_for_turn()
	_rebuild_transmissions()

func _ensure_cache_for_turn() -> void:
	if cached_turn == SquadManager.current_turn:
		return  # already built for this turn

	cached_turn = SquadManager.current_turn
	cached_quality.clear()
	cached_need_text.clear()
	cached_status_text.clear()
	cached_flavour.clear()

	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		if squad.status == SquadManager.Status.CRITICAL:
			continue  # distress calls always render fresh, no caching needed

		var quality = _transmission_quality(squad)
		cached_quality[squad_name] = quality

		match quality:
			"dead":
				cached_flavour[squad_name] = DEAD_CHANNEL[randi() % DEAD_CHANNEL.size()]
			"ghost":
				cached_flavour[squad_name] = GHOST_SIGNAL[randi() % GHOST_SIGNAL.size()]
				var need_str = SquadManager.NEED_NAMES[squad.need]
				var raw = "Requesting %s. Awaiting your order." % need_str
				cached_need_text[squad_name] = _garble_text(raw, 0.95)
			"delayed":
				cached_flavour[squad_name] = DELAYED_BURST[randi() % DELAYED_BURST.size()]
				var need_str = SquadManager.NEED_NAMES[squad.need]
				var raw = "Requesting %s. Awaiting your order." % need_str
				cached_need_text[squad_name] = _garble_text(raw, 0.5)
				cached_status_text[squad_name] = _garble_text(_status_context(squad), 0.3)
			"normal":
				if squad.status != SquadManager.Status.LOST:
					var interference = SquadManager.interference
					var need_str = SquadManager.NEED_NAMES[squad.need]
					var raw_need_msg = "Requesting %s. Awaiting your order." % need_str
					cached_need_text[squad_name] = _garble_text(raw_need_msg, interference)
					cached_status_text[squad_name] = _garble_text(_status_context(squad), interference * 0.6)
					
func _rebuild_transmissions() -> void:
	if turn_label:
		turn_label.text = (
			"Pre-mission — awaiting drop confirmation"
			if SquadManager.current_turn == 0
			else "Turn %d transmissions" % SquadManager.current_turn
		)

	for child in transmission_container.get_children():
		child.queue_free()

	# Critical squads always break through — priority distress first
	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		if squad.status == SquadManager.Status.CRITICAL:
			_add_distress_call(squad)

	# All other squads — subject to transmission degradation
	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		if squad.status != SquadManager.Status.CRITICAL:
			_add_transmission(squad)

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

func _on_help_pressed() -> void:
	set_help_attention(false)
	GameManager.mark_attention_seen("vox_turn_%d" % SquadManager.current_turn)
	var steps: Array[TutorialStep] = [
		_step(
			"TRANSMISSIONS — Live feed from all squads. Each card shows their callsign, location, and what supplies they are requesting. The text may be garbled depending on signal quality.",
			^"PanelContainer/VBoxContainer/ScrollContainer/TransmissionContainer"
		),
		_step(
			"SIGNAL QUALITY — CLEAR means full reliable intel. DEGRADED means some corruption. POOR means heavy interference — some words may be wrong. CRITICAL means you can barely hear them at all.",
			^"PanelContainer/VBoxContainer/TurnLabel"
		),
		_step(
			"INTERFERENCE — Higher missions have worse signal corruption. One transmission may always be false on Mission 3+. Powering the comms tower on M3/M4 reduces interference for nearby squads.",
			^"PanelContainer/VBoxContainer/ScrollContainer/TransmissionContainer"
		),
		_step(
			"SQUAD OBJECTIVES — Under each transmission you can see what the squad is trying to do next turn. Cross-check this with the Intel Desk reports for the clearest picture.",
			^"PanelContainer/VBoxContainer/ScrollContainer/TransmissionContainer"
		),
	]
	tutorial_overlay.start(steps, self)

func _step(text: String, path: NodePath) -> TutorialStep:
	var s := TutorialStep.new()
	s.text = text
	s.target_path = path
	return s

# -------------------------------------------------------
# Determines transmission quality for this squad this turn
# Returns: "normal", "delayed", "ghost", "dead"
# Critical squads always return "normal" (handled separately)
# -------------------------------------------------------
func _transmission_quality(squad: Dictionary) -> String:
	var interference = SquadManager.interference

	# Tower powered — check if this squad is within radius
	if GameManager.tower_powered and GameManager.tower_sector != "":
		var dist = EnemyManager._bfs_distance(squad.sector, GameManager.tower_sector)
		if dist <= 3:  # within 3 hex radius of tower
			interference = max(0.0, interference - 0.4)  # significant reduction

	if interference <= 0.0:
		return "normal"
	if squad.status == SquadManager.Status.LOST:
		return "dead"

	var roll = randf()
	if roll < interference * 0.15:
		return "dead"
	elif roll < interference * 0.35:
		return "ghost"
	elif roll < interference * 0.55:
		return "delayed"
	else:
		return "normal"


func _add_distress_call(squad: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.bg_color = Color(0.25, 0.05, 0.05)
	style.border_color = Color(1.0, 0.2, 0.2, 0.9)
	style.border_width_left   = 3
	style.border_width_top    = 1
	style.border_width_right  = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
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

	if TurnManager.mission_over:
		_add_mission_over_banner(vbox)

	transmission_container.add_child(card)


# -------------------------------------------------------
# Main transmission builder — routes by quality
# -------------------------------------------------------
func _add_transmission(squad: Dictionary) -> void:
	var quality = cached_quality.get(squad.name, "normal")
	match quality:
		"dead":    _add_dead_channel(squad)
		"ghost":   _add_ghost_signal(squad)
		"delayed": _add_delayed_burst(squad)
		"normal":  _add_need_transmission(squad)


func _add_dead_channel(squad: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.bg_color = Color(0.06, 0.06, 0.08)
	style.border_color = Color(0.25, 0.25, 0.3, 0.5)
	style.border_width_left = 2
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
	style.corner_radius_bottom_right = 3
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var header := Label.new()
	header.text = ">>> %s  [%s]" % [squad.name, squad.sector]
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	vbox.add_child(header)

	var status_lbl := Label.new()
	status_lbl.text = cached_flavour.get(squad.name, DEAD_CHANNEL[0])
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	vbox.add_child(status_lbl)

	var noise := Label.new()
	noise.text = _generate_static(40)
	noise.add_theme_font_size_override("font_size", 11)
	noise.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
	vbox.add_child(noise)

	transmission_container.add_child(card)


func _add_ghost_signal(squad: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.bg_color = Color(0.07, 0.05, 0.10)
	style.border_color = Color(0.45, 0.2, 0.6, 0.6)
	style.border_width_left = 2
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
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
	source_lbl.add_theme_color_override("font_color", Color(0.5, 0.3, 0.7))
	header.add_child(source_lbl)

	var quality_lbl := Label.new()
	quality_lbl.text = cached_flavour.get(squad.name, GHOST_SIGNAL[0])
	quality_lbl.add_theme_font_size_override("font_size", 10)
	quality_lbl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.8))
	header.add_child(quality_lbl)

	var garbled_lbl := Label.new()
	garbled_lbl.text = cached_need_text.get(squad.name, "")
	garbled_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	garbled_lbl.add_theme_font_size_override("font_size", 13)
	garbled_lbl.add_theme_color_override("font_color", Color(0.4, 0.25, 0.5))
	vbox.add_child(garbled_lbl)

	transmission_container.add_child(card)


func _add_delayed_burst(squad: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.bg_color = Color(0.07, 0.09, 0.13)
	style.border_color = Color(0.5, 0.45, 0.2, 0.7)
	style.border_width_left = 2
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
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
	source_lbl.add_theme_color_override("font_color", Color(0.65, 0.6, 0.3))
	header.add_child(source_lbl)

	var quality_lbl := Label.new()
	quality_lbl.text = cached_flavour.get(squad.name, DELAYED_BURST[0])
	quality_lbl.add_theme_font_size_override("font_size", 10)
	quality_lbl.add_theme_color_override("font_color", Color(0.8, 0.65, 0.2))
	header.add_child(quality_lbl)

	var need_lbl := Label.new()
	need_lbl.text = cached_need_text.get(squad.name, "")
	need_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	need_lbl.add_theme_font_size_override("font_size", 13)
	need_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.4))
	vbox.add_child(need_lbl)

	var status_lbl := Label.new()
	status_lbl.text = cached_status_text.get(squad.name, "")
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.35))
	vbox.add_child(status_lbl)

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
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
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

	var need_lbl := Label.new()
	need_lbl.text = cached_need_text.get(squad.name, "")
	need_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	need_lbl.add_theme_font_size_override("font_size", 13)
	need_lbl.add_theme_color_override("font_color",
		Color(0.9, 0.8, 0.4) if interference < 0.5 else Color(0.6, 0.6, 0.5))
	vbox.add_child(need_lbl)

	var status_lbl := Label.new()
	status_lbl.text = cached_status_text.get(squad.name, "")
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	vbox.add_child(status_lbl)

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


# -------------------------------------------------------
# Generates a string of random static characters
# -------------------------------------------------------
func _generate_static(length: int) -> String:
	var result = ""
	for i in range(length):
		result += STATIC_CHARS[randi() % STATIC_CHARS.size()]
	return result


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
