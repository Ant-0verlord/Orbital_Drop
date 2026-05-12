extends StaticBody3D
# =============================================================
# HoloMap.gd
# Attach to: StaticBody3D inside Holomap.tscn
# =============================================================

@onready var popup: Control = $HoloMapPopup
var player: Node = null
var zone_states: Dictionary = {}


func _ready() -> void:
	popup.visible = false
	player = get_tree().get_first_node_in_group("player")
	popup.player = player
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	EnemyManager.enemies_updated.connect(_on_enemies_updated)


func _on_turn_started(_turn: int) -> void:
	_build_zone_states()
	if popup.visible:
		popup.refresh(zone_states)


func open_popup() -> void:
	_build_zone_states()
	popup.visible = true
	popup.refresh(zone_states)


func close_popup() -> void:
	popup.visible = false


func _on_turn_resolved() -> void:
	_build_zone_states()
	if popup.visible:
		popup.refresh(zone_states)


func _on_enemies_updated() -> void:
	_build_zone_states()
	if popup.visible:
		popup.refresh(zone_states)


func _build_zone_states() -> void:
	zone_states.clear()
	var hex_control = EnemyManager.get_hex_control()

	for sector in EnemyManager.ALL_SECTORS_14:
		var control = hex_control.get(sector, "enemy")
		var squad_here = ""
		for squad in SquadManager.get_squads_for_ui():
			if squad.sector == sector and squad.status != SquadManager.Status.LOST:
				squad_here = squad.name
				break
		zone_states[sector] = {
			"state":        control,
			"squad":        squad_here,
			"enemy_count":  EnemyManager.get_enemy_count_at(sector),
		}
