extends StaticBody3D
# =============================================================
# HoloMap.gd
# Attach to: StaticBody3D inside Holomap.tscn
# =============================================================

@onready var popup: Control = $HoloMapPopup
var player: Node = null

# { sector_name: { "state": "held"/"contested"/"lost"/"unknown", "squad": name } }
var zone_states: Dictionary = {}

# Neutral sector names that fill out the map beyond squad sectors
# These increase per mission to expand the theatre
const NEUTRAL_SECTORS_BY_MISSION = [
	["Theta-3", "Iota-8", "Kappa-1", "Lambda-4", "Mu-6"],           # Mission 1: 5 neutrals
	["Theta-3", "Iota-8", "Kappa-1", "Lambda-4", "Mu-6", "Nu-2", "Xi-7"],  # Mission 2: 7 neutrals
	["Theta-3", "Iota-8", "Kappa-1", "Lambda-4", "Mu-6", "Nu-2", "Xi-7", "Omicron-5", "Pi-9"], # Mission 3+
]


func _ready() -> void:
	popup.visible = false
	player = get_tree().get_first_node_in_group("player")
	popup.player = player
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)


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


func _build_zone_states() -> void:
	zone_states.clear()

	# Add squad sectors
	for squad in SquadManager.get_squads_for_ui():
		zone_states[squad.sector] = {
			"state": _status_to_zone(squad.status),
			"squad": squad.name if squad.status != SquadManager.Status.LOST else "",
		}

	# Add neutral/unknown sectors to fill out the map
	var mission_idx = clamp(GameManager.current_mission, 0, NEUTRAL_SECTORS_BY_MISSION.size() - 1)
	var neutrals = NEUTRAL_SECTORS_BY_MISSION[mission_idx]
	for sector in neutrals:
		if not zone_states.has(sector):
			zone_states[sector] = { "state": "unknown", "squad": "" }


func _status_to_zone(status: int) -> String:
	match status:
		SquadManager.Status.ACTIVE:   return "held"
		SquadManager.Status.WOUNDED:  return "contested"
		SquadManager.Status.CRITICAL: return "contested"
		SquadManager.Status.LOST:     return "lost"
	return "unknown"
