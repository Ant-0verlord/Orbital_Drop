extends Control
# =============================================================
# HoloMapPopup.gd
# UI built in scene. Hex drawing delegated to HexCanvas.
# Handles reinforcement drop placement mode.
# =============================================================

var current_action_mode: String = ""  # "", "reinforcement", or "bombardment"
var player: Node = null
var zone_states: Dictionary = {}
var _help_attention: bool = false
var _attention_pulse: float = 0.0

const COLOR_HELD:      Color = Color(0.1,  0.8,  0.3,  0.85)
const COLOR_CONTESTED: Color = Color(0.9,  0.7,  0.1,  0.85)
const COLOR_LOST:      Color = Color(0.4,  0.4,  0.4,  0.7)
const COLOR_ENEMY:     Color = Color(0.7,  0.1,  0.1,  0.85)
const COLOR_NEUTRAL:   Color = Color(0.12, 0.18, 0.25, 0.7)

@onready var title_label: Label         = $PanelContainer/VBoxContainer/Title
@onready var turn_label: Label          = $PanelContainer/VBoxContainer/InfoRow/TurnLabel
@onready var held_label: Label          = $PanelContainer/VBoxContainer/InfoRow/HeldLabel
@onready var hex_canvas: Control        = $PanelContainer/VBoxContainer/HexCanvas
@onready var sector_list: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/SectorList
@onready var close_btn: Button          = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn
@onready var help_btn: Button           =$PanelContainer/VBoxContainer/ButtonRow/HelpBtn

# Placement mode UI — add these nodes to the scene
# under VBoxContainer, above ButtonRow
@onready var placement_banner: PanelContainer = $PanelContainer/VBoxContainer/PlacementBanner
@onready var placement_label: Label           = $PanelContainer/VBoxContainer/PlacementBanner/PlacementVBox/PlacementLabel
@onready var placement_confirm_btn: Button    = $PanelContainer/VBoxContainer/PlacementBanner/PlacementVBox/HBoxContainer/PlacementConfirmBtn
@onready var placement_cancel_btn: Button     = $PanelContainer/VBoxContainer/PlacementBanner/PlacementVBox/HBoxContainer/PlacementCancelBtn
@onready var tutorial_overlay: Control = $TutorialOverlay
@onready var help_nudge: Control = $HelpNudge


func _ready() -> void:
	_style_header("HOLO-MAP", "Full battlefield view — sector control, squad & enemy positions, placement targeting")
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	EnemyManager.enemies_updated.connect(_on_enemies_updated)
	TurnManager.allocations_locked.connect(_on_allocations_locked)

	close_btn.pressed.connect(_on_close_pressed)
	hex_canvas.hex_clicked.connect(_on_hex_clicked)
	placement_confirm_btn.pressed.connect(_on_placement_confirmed)
	placement_cancel_btn.pressed.connect(_on_placement_cancelled)

	help_btn.pressed.connect(_on_help_pressed)
	visibility_changed.connect(_on_visibility_changed)

	placement_banner.visible = false
	_style_primary_button(placement_confirm_btn)

	# Inside a ScrollContainer, a child only stretches to the full
	# available width if explicitly told to expand — otherwise it
	# shrinks to its content's natural width.
	sector_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_visibility_changed() -> void:
	if not visible:
		return
	if GameManager.has_seen_attention("help_nudge_seen_holomap"):
		return
	GameManager.mark_attention_seen("help_nudge_seen_holomap")
	help_nudge.point_at(help_btn)


func refresh(new_zone_states: Dictionary, axial_by_sector: Dictionary = {}) -> void:
	zone_states = new_zone_states
	hex_canvas.refresh(zone_states, axial_by_sector, _build_special_sectors())
	_rebuild_sector_list()
	_update_labels()
	_check_placement_mode()


func _on_turn_resolved() -> void:
	if visible: _refresh_from_game_state()

func _on_enemies_updated() -> void:
	if visible: _refresh_from_game_state()

func _on_allocations_locked() -> void:
	# When allocations are locked, check if reinforcement needs placing
	_check_placement_mode()

func _check_bombardment_mode() -> void:
	var pending = GameManager.get_pending_bombardment()
	if not pending.is_empty() and not pending.get("placed", false):
		_enter_bombardment_mode()
	else:
		_exit_bombardment_mode()

func _enter_bombardment_mode() -> void:
	hex_canvas.enter_placement_mode()
	placement_banner.visible = true
	if placement_label:
		placement_label.text = "SELECT ORBITAL STRIKE TARGET — Click a hex to fire (hits centre + 6 surrounding hexes)"
		placement_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	placement_confirm_btn.disabled = true
	close_btn.disabled = true

func _on_bombardment_confirmed() -> void:
	var sector = hex_canvas.placed_sector
	if sector == "":
		return
	var affected = EnemyManager.resolve_bombardment(sector)
	for squad in SquadManager.get_squads_for_ui():
		if squad.sector in affected and squad.status != SquadManager.Status.LOST:
			SquadManager.apply_bombardment_casualty(squad.name)
	GameManager.clear_pending_bombardment()
	_exit_bombardment_mode()
	_refresh_from_game_state()


func _exit_bombardment_mode() -> void:
	hex_canvas.exit_placement_mode()

func _refresh_from_game_state() -> void:
	var hex_control = EnemyManager.get_hex_control()
	# sector -> Array of squad names — more than one squad can end up
	# sharing a hex (e.g. a carried-over reinforcement squad landing
	# alongside the main force), and all of them should show up rather
	# than one silently overwriting another.
	var squad_sectors: Dictionary = {}
	for squad in SquadManager.get_squads_for_ui():
		if squad.status != SquadManager.Status.LOST:
			if not squad_sectors.has(squad.sector):
				squad_sectors[squad.sector] = []
			squad_sectors[squad.sector].append(squad.name)

	var states: Dictionary = {}
	for sector in hex_control:
		# "squad" is the raw Array of names sharing this hex — HexCanvas
		# draws each on its own line, and _rebuild_sector_list() below
		# joins them for the single-line sector list row.
		states[sector] = {
			"state":       hex_control[sector],
			"squad":       squad_sectors.get(sector, []),
			"enemy_count": EnemyManager.get_enemy_count_at(sector),
		}

	refresh(states, GameManager.get_current_axial_map())


func _update_labels() -> void:
	if turn_label:
		turn_label.text = "Turn %d" % TurnManager.current_turn
	if held_label:
		_update_held_label()


# "Held: X / Y required" only actually means something on a "capture"
# mission — it was showing on every mission type before, including ones
# where win_hexes is legitimately 0 (eliminate_priority, hold_tower,
# extract), which read as "0 required" — a capture objective that doesn't
# exist. Mirrors CommandThronePopup's per-mission-type status readout so
# every screen agrees on what "progress" means for this mission.
func _update_held_label() -> void:
	var mission_type = GameManager.mission_type
	match mission_type:
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
		_:
			var held = EnemyManager.get_held_count()
			var req  = TurnManager.win_condition_hexes
			held_label.text = "Held: %d / %d required" % [held, req]
			held_label.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.4) if held >= req else Color(0.9, 0.6, 0.2))


# -------------------------------------------------------
# Placement mode — enter when pending reinforcement exists
# -------------------------------------------------------
func _check_placement_mode() -> void:
	var pending_r = GameManager.get_pending_reinforcement()
	var pending_b = GameManager.get_pending_bombardment()

	if not pending_r.is_empty() and not pending_r.get("placed", false):
		current_action_mode = "reinforcement"
		_enter_placement_mode(pending_r.get("squad_name", ""))
	elif not pending_b.is_empty() and not pending_b.get("placed", false):
		current_action_mode = "bombardment"
		_enter_bombardment_mode()
	else:
		current_action_mode = ""
		_exit_placement_mode()

func _process(delta: float) -> void:
	if not _help_attention or help_btn == null:
		return
	_attention_pulse += delta * 3.0
	var t = (sin(_attention_pulse) + 1.0) * 0.5
	help_btn.modulate = Color(1.0, lerp(0.6, 1.0, t), lerp(0.0, 0.3, t), 1.0)

func _enter_placement_mode(squad_name: String) -> void:
	hex_canvas.enter_placement_mode()
	placement_banner.visible = true
	if placement_label:
		placement_label.text = "SELECT DROP ZONE — %s  |  Click a hex to place  |  Hot drop onto enemy = surprise elimination" % squad_name
		placement_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	placement_confirm_btn.disabled = true  # Enabled once hex is clicked
	close_btn.disabled = true  # Can't close until placed or cancelled


func _exit_placement_mode() -> void:
	hex_canvas.exit_placement_mode()
	placement_banner.visible = false
	close_btn.disabled = false


func _on_hex_clicked(sector: String) -> void:
	if current_action_mode == "bombardment":
		if placement_label:
			placement_label.text = "STRIKE TARGET: %s — Confirm to fire, or pick another hex" % sector
			placement_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		placement_confirm_btn.disabled = false
		return

	if placement_label:
		var pending = GameManager.get_pending_reinforcement()
		var squad_name = pending.get("squad_name", "")
		var hex_control = EnemyManager.get_hex_control()
		var state = hex_control.get(sector, "")
		var hot_drop_text = "  ⚠ HOT DROP — surprise elimination on landing" if state == "enemy" else ""
		placement_label.text = "DROP ZONE: %s%s  |  Confirm or pick another hex" % [sector, hot_drop_text]
	placement_confirm_btn.disabled = false

func set_help_attention(on: bool) -> void:
	_help_attention = on
	_attention_pulse = 0.0
	if not on and help_btn != null:
		help_btn.modulate = Color.WHITE

func _on_help_pressed() -> void:
	AudioManager.play_button_bottom()
	set_help_attention(false)
	GameManager.mark_attention_seen("holomap_placement_%d" % SquadManager.current_turn)
	GameManager.mark_attention_seen("holomap_priority_eliminated")
	var steps: Array[TutorialStep] = [
		_step(
			"THE MAP — Shows every sector and who controls it. Green = your squads holding it. Red = enemy controlled. Dark blue/grey = neutral (unclaimed). Squad names and enemy ✕ markers show current positions.",
			^"HexCanvas"
		),
		_step(
			"PANNING — Middle-click and drag to move around larger maps. On Mission 3 and beyond the map will not fit on screen without scrolling.",
			^"HexCanvas"
		),
		_step(
			"SPECIAL MARKERS — ⚡ Comms Tower (power it with Fuel Cells). ✦ Priority Target (eliminate in M4 to secure data). ▲ Extraction Zone (all squads must reach this in M5).",
			^"HexCanvas"
		),
		_step(
			"SECTOR LIST — Every sector listed here with its current state and which squad occupies it. Scroll down to see the full list on larger maps.",
			^"SectorList"
		),
	]

	# Placement mode hint — only show if something is armed
	if not GameManager.get_pending_reinforcement().is_empty() or not GameManager.get_pending_bombardment().is_empty():
		steps.append(_step(
			"PLACEMENT MODE — A reinforcement drop or orbital strike is armed. Click a hex on the map to select your target, then confirm. The map will highlight valid positions.",
			^"PlacementBanner"
		))

	tutorial_overlay.start(steps, self)

func _step(text: String, path: NodePath) -> TutorialStep:
	var s := TutorialStep.new()
	s.text = text
	s.target_path = path
	return s

func _on_placement_confirmed() -> void:
	var sector = hex_canvas.placed_sector
	if sector == "":
		return

	AudioManager.play_button_other()
	if current_action_mode == "bombardment":
		GameManager.place_bombardment(sector)
		current_action_mode = ""
		_exit_placement_mode()
		_refresh_from_game_state()
		return

	GameManager.place_reinforcement(sector)
	_exit_placement_mode()
	_refresh_from_game_state()


func _on_placement_cancelled() -> void:
	AudioManager.play_button_other()
	if current_action_mode == "bombardment":
		GameManager.clear_pending_bombardment()
		GameManager.orbital_strikes_pool += 1
		current_action_mode = ""
		hex_canvas.exit_placement_mode()
		_exit_placement_mode()
		return

	GameManager.clear_pending_reinforcement()
	GameManager.reinforcement_pool += 1
	current_action_mode = ""
	hex_canvas.exit_placement_mode()
	_exit_placement_mode()

func _build_special_sectors() -> Dictionary:
	var specials: Dictionary = {}

	# Priority target location
	var pt_sector = EnemyManager.get_priority_target_sector()
	if pt_sector != "":
		specials[pt_sector] = "priority"

	# Radio tower
	var tower = GameManager.tower_sector
	if tower != "":
		if GameManager.tower_powered:
			specials[tower] = "tower_powered"
		else:
			specials[tower] = "tower"

	# Extraction zone
	var extraction = GameManager.extraction_zone
	if extraction != "":
		specials[extraction] = "extraction"

	return specials

func _rebuild_sector_list() -> void:
	for child in sector_list.get_children():
		child.queue_free()

	for sector_name in zone_states:
		var data        = zone_states[sector_name]
		var state       = data.get("state", "enemy")
		var squad_names: Array = data.get("squad", [])
		var enemy_count = data.get("enemy_count", 0)
		var row_color   = COLOR_ENEMY if enemy_count > 0 else _state_color(state)

		var strip := PanelContainer.new()
		strip.add_theme_stylebox_override("panel", _sector_strip_style(row_color))
		strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		strip.add_child(row)

		var sec_lbl := Label.new()
		sec_lbl.text = sector_name
		sec_lbl.custom_minimum_size.x = 95
		sec_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(sec_lbl)

		var state_text = "ENEMY (%d)" % enemy_count if enemy_count > 0 else state.to_upper()
		row.add_child(_sector_pill(state_text, row_color))

		var squad_text = ""
		for i in range(squad_names.size()):
			if i > 0:
				squad_text += ", "
			squad_text += squad_names[i]

		var squad_lbl := Label.new()
		squad_lbl.text = squad_text if squad_text != "" else "—"
		squad_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		squad_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(squad_lbl)

		sector_list.add_child(strip)

		var special_type = _build_special_sectors().get(sector_name, "")
		if special_type != "":
			var tag_lbl := Label.new()
			var tag_text = ""
			match special_type:
				"priority":    tag_text = "✦ PRIORITY TARGET"
				"tower":       tag_text = "⚡ COMMS TOWER"
				"tower_powered": tag_text = "⚡ TOWER ACTIVE"
				"extraction":  tag_text = "▲ EXTRACTION"
			tag_lbl.text = tag_text
			tag_lbl.add_theme_font_size_override("font_size", 10)
			tag_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
			row.add_child(tag_lbl)

		var spacer := Control.new()
		spacer.custom_minimum_size.y = 2
		sector_list.add_child(spacer)


func _state_color(state: String) -> Color:
	match state:
		"held":      return COLOR_HELD
		"contested": return COLOR_CONTESTED
		"lost":      return COLOR_LOST
		"enemy":     return COLOR_ENEMY
		"neutral":   return COLOR_NEUTRAL
	return COLOR_NEUTRAL


# -------------------------------------------------------
# Compact rounded strip + status "chip" for the sector
# list — a lighter-weight version of the card/pill style
# used elsewhere, sized to stay dense across many sectors.
# -------------------------------------------------------
func _sector_strip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.12 + 0.035, color.g * 0.12 + 0.035, color.b * 0.12 + 0.035, 1.0)
	style.border_color = Color(color.r, color.g, color.b, 0.5)
	style.border_width_left   = 3
	style.border_width_top    = 1
	style.border_width_right  = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left     = 7
	style.corner_radius_top_right    = 7
	style.corner_radius_bottom_left  = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 4
	style.content_margin_bottom = 4
	return style


func _sector_pill(label_text: String, color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.22 + 0.03, color.g * 0.22 + 0.03, color.b * 0.22 + 0.03, 1.0)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left   = 6
	style.content_margin_right  = 6
	style.content_margin_top    = 1
	style.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", style)
	pill.custom_minimum_size.x = 78

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(lbl)
	return pill


# -------------------------------------------------------
# Console header — big bold title + small grey subtitle,
# matching the Field Manual mockup layouts. The scene has
# no Subtitle node, so it's built here at runtime and
# inserted right under Title.
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
# Amber-filled "primary" CTA button style — matches the
# other consoles' confirm/seal buttons and the Field
# Manual mockup layouts.
# -------------------------------------------------------
func _style_primary_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.275, 0.216, 0.039, 1.0)
	normal.border_color = Color(1.0, 0.851, 0.2, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate()
	hover.bg_color = Color(0.35, 0.275, 0.05, 1.0)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.22, 0.17, 0.03, 1.0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(1.0, 0.851, 0.2))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
