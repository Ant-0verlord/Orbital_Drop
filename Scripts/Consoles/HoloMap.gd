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
	EnemyManager.priority_target_eliminated.connect(_on_priority_eliminated)

func _on_priority_eliminated(_squad: String, _sector: String) -> void:
	if not GameManager.has_seen_attention("holomap_priority_eliminated"):
		popup.set_help_attention(true)

func _build_axial_map() -> Dictionary:
	var data = GameManager.get_current_mission_data()
	var sectors = data.get("sectors", [])
	var axial   = data.get("axial", [])
	var map: Dictionary = {}
	for i in range(min(sectors.size(), axial.size())):
		map[sectors[i]] = axial[i]
	return map

func _on_turn_started(_turn: int) -> void:
	_build_zone_states()
	if popup.visible:
		popup.refresh(zone_states)


func open_popup() -> void:
	_build_zone_states()
	popup.visible = true
	popup.refresh(zone_states, _build_axial_map())
	GuideManager.on_console_opened("holomap")


func close_popup() -> void:
	popup.visible = false



func _on_turn_resolved() -> void:
	_build_zone_states()
	var has_pending = not GameManager.get_pending_reinforcement().is_empty() or not GameManager.get_pending_bombardment().is_empty()
	if has_pending and not GameManager.has_seen_attention("holomap_placement_%d" % SquadManager.current_turn):
		popup.set_help_attention(true)
	if popup.visible:
		popup.refresh(zone_states)


func _on_enemies_updated() -> void:
	_build_zone_states()
	if popup.visible:
		popup.refresh(zone_states)



func _build_zone_states() -> void:
	zone_states.clear()
	var hex_control = EnemyManager.get_hex_control()

	for sector in EnemyManager.get_all_sectors():
		var control = hex_control.get(sector, "enemy")
		# Array, not a single overwrite — more than one squad can share a
		# hex, and every one of them needs to show up here, not just
		# whichever was found first.
		var squads_here: Array = []
		for squad in SquadManager.get_squads_for_ui():
			if squad.sector == sector and squad.status != SquadManager.Status.LOST:
				squads_here.append(squad.name)
		zone_states[sector] = {
			"state":        control,
			"squad":        squads_here,
			"enemy_count":  EnemyManager.get_enemy_count_at(sector),
		}
