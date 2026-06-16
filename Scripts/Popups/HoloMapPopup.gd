extends Control
# =============================================================
# HoloMapPopup.gd
# UI built in scene. Hex drawing delegated to HexCanvas.
# Handles reinforcement drop placement mode.
# =============================================================

var player: Node = null
var zone_states: Dictionary = {}

const COLOR_HELD:      Color = Color(0.1,  0.8,  0.3,  0.85)
const COLOR_CONTESTED: Color = Color(0.9,  0.7,  0.1,  0.85)
const COLOR_LOST:      Color = Color(0.4,  0.4,  0.4,  0.7)
const COLOR_ENEMY:     Color = Color(0.7,  0.1,  0.1,  0.85)
const COLOR_NEUTRAL:   Color = Color(0.12, 0.18, 0.25, 0.7)

@onready var turn_label: Label          = $PanelContainer/VBoxContainer/InfoRow/TurnLabel
@onready var held_label: Label          = $PanelContainer/VBoxContainer/InfoRow/HeldLabel
@onready var hex_canvas: Control        = $PanelContainer/VBoxContainer/HexCanvas
@onready var sector_list: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/SectorList
@onready var close_btn: Button          = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn

# Placement mode UI — add these nodes to the scene
# under VBoxContainer, above ButtonRow
@onready var placement_banner: PanelContainer = $PanelContainer/VBoxContainer/PlacementBanner
@onready var placement_label: Label           = $PanelContainer/VBoxContainer/PlacementBanner/PlacementLabel
@onready var placement_confirm_btn: Button    = $PanelContainer/VBoxContainer/PlacementBanner/PlacementConfirmBtn
@onready var placement_cancel_btn: Button     = $PanelContainer/VBoxContainer/PlacementBanner/PlacementCancelBtn


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	EnemyManager.enemies_updated.connect(_on_enemies_updated)
	TurnManager.allocations_locked.connect(_on_allocations_locked)

	close_btn.pressed.connect(_on_close_pressed)
	hex_canvas.hex_clicked.connect(_on_hex_clicked)
	placement_confirm_btn.pressed.connect(_on_placement_confirmed)
	placement_cancel_btn.pressed.connect(_on_placement_cancelled)

	placement_banner.visible = false


func refresh(new_zone_states: Dictionary) -> void:
	zone_states = new_zone_states
	hex_canvas.refresh(zone_states)
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


func _refresh_from_game_state() -> void:
	var hex_control = EnemyManager.get_hex_control()
	var squad_sectors: Dictionary = {}
	for squad in SquadManager.get_squads_for_ui():
		if squad.status != SquadManager.Status.LOST:
			squad_sectors[squad.sector] = squad.name

	var states: Dictionary = {}
	for sector in hex_control:
		states[sector] = {
			"state":       hex_control[sector],
			"squad":       squad_sectors.get(sector, ""),
			"enemy_count": EnemyManager.get_enemy_count_at(sector),
		}
	refresh(states)


func _update_labels() -> void:
	if turn_label:
		turn_label.text = "Turn %d" % TurnManager.current_turn
	if held_label:
		var held = EnemyManager.get_held_count()
		var req  = TurnManager.win_condition_hexes
		held_label.text = "Held: %d / %d required" % [held, req]
		held_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if held >= req else Color(0.9, 0.6, 0.2))


# -------------------------------------------------------
# Placement mode — enter when pending reinforcement exists
# -------------------------------------------------------
func _check_placement_mode() -> void:
	var pending = GameManager.get_pending_reinforcement()
	if not pending.is_empty() and not pending.get("placed", false):
		_enter_placement_mode(pending.get("squad_name", ""))
	else:
		_exit_placement_mode()


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
	if placement_label:
		var pending = GameManager.get_pending_reinforcement()
		var squad_name = pending.get("squad_name", "")
		var hex_control = EnemyManager.get_hex_control()
		var state = hex_control.get(sector, "")
		var hot_drop_text = "  ⚠ HOT DROP — surprise elimination on landing" if state == "enemy" else ""
		placement_label.text = "DROP ZONE: %s%s  |  Confirm or pick another hex" % [sector, hot_drop_text]
	placement_confirm_btn.disabled = false


func _on_placement_confirmed() -> void:
	var sector = hex_canvas.placed_sector
	if sector == "":
		return
	GameManager.place_reinforcement(sector)
	_exit_placement_mode()
	_refresh_from_game_state()


func _on_placement_cancelled() -> void:
	# Cancel clears the pending reinforcement and refunds the pool
	GameManager.clear_pending_reinforcement()
	GameManager.reinforcement_pool += 1
	hex_canvas.exit_placement_mode()
	_exit_placement_mode()


func _rebuild_sector_list() -> void:
	for child in sector_list.get_children():
		child.queue_free()

	for sector_name in zone_states:
		var data        = zone_states[sector_name]
		var state       = data.get("state", "enemy")
		var squad       = data.get("squad", "")
		var enemy_count = data.get("enemy_count", 0)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color",
			COLOR_ENEMY if enemy_count > 0 else _state_color(state))
		dot.add_theme_font_size_override("font_size", 11)
		dot.custom_minimum_size.x = 16
		row.add_child(dot)

		var sec_lbl := Label.new()
		sec_lbl.text = sector_name
		sec_lbl.custom_minimum_size.x = 95
		sec_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(sec_lbl)

		var state_text = "Enemy (%d)" % enemy_count if enemy_count > 0 else state.capitalize()
		var state_lbl := Label.new()
		state_lbl.text = state_text
		state_lbl.custom_minimum_size.x = 90
		state_lbl.add_theme_color_override("font_color",
			COLOR_ENEMY if enemy_count > 0 else _state_color(state))
		state_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(state_lbl)

		var squad_lbl := Label.new()
		squad_lbl.text = squad if squad != "" else "—"
		squad_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		squad_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(squad_lbl)

		sector_list.add_child(row)


func _state_color(state: String) -> Color:
	match state:
		"held":      return COLOR_HELD
		"contested": return COLOR_CONTESTED
		"lost":      return COLOR_LOST
		"enemy":     return COLOR_ENEMY
		"neutral":   return COLOR_NEUTRAL
	return COLOR_NEUTRAL


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()
