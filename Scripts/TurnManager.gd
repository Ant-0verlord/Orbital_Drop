extends Node
# =============================================================
# TurnManager.gd  —  AutoLoad singleton
# AutoLoad order: SquadManager, TurnManager, GameManager, EnemyManager
# =============================================================

signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal allocations_locked
signal mission_complete
signal mission_failed(reason: String)

var current_turn: int = 0
var max_turns: int = 0
var allocations_are_locked: bool = false
var pending_allocations: Dictionary = {}
var pending_enemy_list: Array = []


func start_mission(mission_data: Dictionary) -> void:
	current_turn = 0
	max_turns = mission_data.get("turns", 3)
	allocations_are_locked = false
	pending_allocations = {}

	var squad_list   = mission_data.get("squads", [])
	var interference = mission_data.get("interference", 0.0)
	pending_enemy_list = mission_data.get("enemies", [])

	SquadManager.init_squads(squad_list, interference)

	if not SquadManager.squad_lost.is_connected(_on_squad_lost):
		SquadManager.squad_lost.connect(_on_squad_lost)

	emit_signal("turn_started", current_turn)


func lock_allocations(allocations: Dictionary) -> void:
	pending_allocations = allocations.duplicate(true)
	allocations_are_locked = true
	emit_signal("allocations_locked")


func end_turn() -> void:
	if not allocations_are_locked:
		push_warning("TurnManager: end_turn called but allocations not locked!")
		return

	current_turn += 1
	SquadManager.resolve_turn(pending_allocations)
	EnemyManager.advance_enemies()

	allocations_are_locked = false
	pending_allocations = {}
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

	# Check final turn — evaluate win condition
	if max_turns > 0 and current_turn >= max_turns:
		_check_win_condition()
		return

	emit_signal("turn_started", current_turn)


func _check_win_condition() -> void:
	# Ask HoloMap for current zone states via the scene tree
	var holo = get_tree().get_first_node_in_group("holomap")
	var zone_states = {}
	if holo and holo.has_method("get_zone_states"):
		zone_states = holo.get_zone_states()

	var held = GameManager.count_held_hexes(zone_states)
	var needed = GameManager.get_win_hex_count()

	if held >= needed:
		emit_signal("mission_complete")
	else:
		emit_signal("mission_failed",
			"Mission failed. Held %d sectors — needed %d." % [held, needed]
		)


func _on_squad_lost(squad_name: String) -> void:
	print("TurnManager: %s has been lost." % squad_name)
