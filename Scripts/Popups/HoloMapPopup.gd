extends Control
# =============================================================
# HoloMapPopup.gd
# UI built in scene. Hex drawing delegated to HexCanvas.
# =============================================================

var player: Node = null
var zone_states: Dictionary = {}

const COLOR_HELD:      Color = Color(0.1,  0.8,  0.3,  0.85)
const COLOR_CONTESTED: Color = Color(0.9,  0.7,  0.1,  0.85)
const COLOR_LOST:      Color = Color(0.4,  0.4,  0.4,  0.7)
const COLOR_ENEMY:     Color = Color(0.7,  0.1,  0.1,  0.85)
const COLOR_NEUTRAL:   Color = Color(0.12, 0.18, 0.25, 0.7)

@onready var turn_label: Label        = $PanelContainer/VBoxContainer/InfoRow/TurnLabel
@onready var held_label: Label        = $PanelContainer/VBoxContainer/InfoRow/HeldLabel
@onready var hex_canvas: Control      = $PanelContainer/VBoxContainer/HexCanvas
@onready var sector_list: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/SectorList
@onready var close_btn: Button        = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	EnemyManager.enemies_updated.connect(_on_enemies_updated)
	close_btn.pressed.connect(_on_close_pressed)


func refresh(new_zone_states: Dictionary) -> void:
	zone_states = new_zone_states
	hex_canvas.refresh(zone_states)
	_rebuild_sector_list()

	if turn_label:
		turn_label.text = "Turn %d" % TurnManager.current_turn
	if held_label:
		var held = EnemyManager.get_held_count()
		var req  = TurnManager.win_condition_hexes
		held_label.text = "Held: %d / %d required" % [held, req]
		held_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if held >= req else Color(0.9, 0.6, 0.2))


func _on_turn_resolved() -> void:
	if visible:
		_refresh_from_game_state()


func _on_enemies_updated() -> void:
	if visible:
		_refresh_from_game_state()


# -------------------------------------------------------
# Build zone_states from current game state and refresh
# -------------------------------------------------------
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
