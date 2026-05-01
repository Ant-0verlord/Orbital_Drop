extends Node
# =============================================================
# TurnManager.gd  —  AutoLoad singleton
# Register in: Project > Project Settings > AutoLoad
# Name: TurnManager
# AutoLoad order: SquadManager, TurnManager, GameManager
# =============================================================

signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal mission_complete
signal mission_failed(reason: String)

var current_turn: int = 0
var max_turns: int = 0


func start_mission(mission_data: Dictionary) -> void:
	current_turn = 0
	max_turns = mission_data.get("turns", 3)

	var squad_list = mission_data.get("squads", [])
	var interference = mission_data.get("interference", 0.0)
	SquadManager.init_squads(squad_list, interference)

	if not SquadManager.squad_lost.is_connected(_on_squad_lost):
		SquadManager.squad_lost.connect(_on_squad_lost)

	emit_signal("turn_started", current_turn)


func end_turn(allocations: Dictionary) -> void:
	current_turn += 1
	SquadManager.resolve_turn(allocations)
	emit_signal("turn_ended", current_turn)

	# Check all squads lost
	var all_lost: bool = true
	for squad_name in SquadManager.squads:
		if SquadManager.squads[squad_name].status != SquadManager.Status.LOST:
			all_lost = false
			break
	if all_lost:
		emit_signal("mission_failed", "All squads have been lost.")
		return

	# Check turn limit reached
	if max_turns > 0 and current_turn >= max_turns:
		emit_signal("mission_complete")
		return

	emit_signal("turn_started", current_turn)


func _on_squad_lost(squad_name: String) -> void:
	print("TurnManager: %s has been lost." % squad_name)
