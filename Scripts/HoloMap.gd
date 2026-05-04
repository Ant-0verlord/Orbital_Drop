extends StaticBody3D
# =============================================================
# HoloMap.gd
# Attach to: StaticBody3D inside Holomap.tscn
#
# Scene structure required:
#   Node3D
#     MeshInstance3D      (the table model)
#     StaticBody3D        (this script)
#       CollisionShape3D
#       HoloMapPopup      (Control node, HoloMapPopup.gd attached)
#
# No SubViewport or HoloPlane needed.
# =============================================================

@onready var popup: Control = $HoloMapPopup
var player: Node = null

# { sector_name: { "state": "held"/"contested"/"lost", "squad": squad_name } }
var zone_states: Dictionary = {}


func _ready() -> void:
	popup.visible = false
	player = get_tree().get_first_node_in_group("player")
	popup.player = player
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	_init_zone_states()


func open_popup() -> void:
	_update_zone_states()
	popup.visible = true
	popup.refresh(zone_states)


func close_popup() -> void:
	popup.visible = false


func _on_turn_resolved() -> void:
	_update_zone_states()
	if popup.visible:
		popup.refresh(zone_states)


func _init_zone_states() -> void:
	zone_states.clear()
	for squad in SquadManager.get_squads_for_ui():
		zone_states[squad.sector] = {
			"state": _status_to_zone(squad.status),
			"squad": squad.name,
		}


func _update_zone_states() -> void:
	for squad in SquadManager.get_squads_for_ui():
		zone_states[squad.sector] = {
			"state": _status_to_zone(squad.status),
			"squad": squad.name if squad.status != SquadManager.Status.LOST else "",
		}


func _status_to_zone(status: int) -> String:
	match status:
		SquadManager.Status.ACTIVE:   return "held"
		SquadManager.Status.WOUNDED:  return "contested"
		SquadManager.Status.CRITICAL: return "contested"
		SquadManager.Status.LOST:     return "lost"
	return "unknown"
