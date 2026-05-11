extends StaticBody3D
# =============================================================
# HoloMap.gd
# Attach to: StaticBody3D inside Holomap.tscn
# Add this node to group "holomap" (Node tab > Groups)
# =============================================================

@onready var popup: Control = $HoloMapPopup
var player: Node = null

var zone_states: Dictionary = {}

# Fixed 14-hex sector layout — index order matches EnemyManager adjacency
const ALL_SECTORS: Array = [
	"Alpha-7",   # 0  centre
	"Beta-2",    # 1  ring 1
	"Gamma-5",   # 2
	"Delta-9",   # 3
	"Epsilon-1", # 4
	"Zeta-3",    # 5
	"Eta-6",     # 6
	"Theta-3",   # 7  ring 2
	"Iota-8",    # 8
	"Kappa-1",   # 9
	"Lambda-4",  # 10
	"Mu-6",      # 11
	"Nu-2",      # 12
	"Xi-7",      # 13
]


func _ready() -> void:
	popup.visible = false
	player = get_tree().get_first_node_in_group("player")
	popup.player = player
	add_to_group("holomap")
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	EnemyManager.enemies_updated.connect(_on_enemies_updated)


func _on_turn_started(_turn: int) -> void:
	if _turn == 0:
		EnemyManager.init_enemies(TurnManager.pending_enemy_list, ALL_SECTORS)
	_build_zone_states()
	if popup.visible:
		popup.refresh(zone_states)


func open_popup() -> void:
	_build_zone_states()
	popup.visible = true
	popup.refresh(zone_states)


func close_popup() -> void:
	popup.visible = false


func get_zone_states() -> Dictionary:
	_build_zone_states()
	return zone_states


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
	for sector in ALL_SECTORS:
		zone_states[sector] = { "state": "unknown", "squad": "", "enemy_count": 0 }

	# Apply squad states
	for squad in SquadManager.get_squads_for_ui():
		if zone_states.has(squad.sector):
			zone_states[squad.sector]["state"] = _status_to_zone(squad.status)
			zone_states[squad.sector]["squad"]  = squad.name if squad.status != SquadManager.Status.LOST else ""

	# Apply enemy counts
	for sector in ALL_SECTORS:
		var enemy_count = EnemyManager.get_enemy_count_at(sector)
		if enemy_count > 0:
			zone_states[sector]["enemy_count"] = enemy_count
			if zone_states[sector]["state"] == "unknown":
				zone_states[sector]["state"] = "enemy"


func _status_to_zone(status: int) -> String:
	match status:
		SquadManager.Status.ACTIVE:   return "held"
		SquadManager.Status.WOUNDED:  return "contested"
		SquadManager.Status.CRITICAL: return "contested"
		SquadManager.Status.LOST:     return "lost"
	return "unknown"
