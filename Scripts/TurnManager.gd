extends Node
# =============================================================
# TurnManager.gd  —  AutoLoad singleton
# =============================================================

signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal allocations_locked
signal mission_complete(report: Dictionary)
signal mission_failed(reason: String)

var current_turn: int = 0
var max_turns: int = 0
var win_condition_hexes: int = 5
var allocations_are_locked: bool = false
var pending_allocations: Dictionary = {}
var pending_enemy_list: Array = []
var last_action_results: Dictionary = {}


func start_mission(mission_data: Dictionary) -> void:
	current_turn = 0
	max_turns = mission_data.get("turns", 5)
	win_condition_hexes = mission_data.get("win_hexes", 5)
	allocations_are_locked = false
	pending_allocations = {}
	last_action_results = {}

	var squad_list   = mission_data.get("squads", [])
	var interference = mission_data.get("interference", 0.0)
	var enemy_list   = mission_data.get("enemies", [])

	SquadManager.init_squads(squad_list, interference)

	if not SquadManager.squad_lost.is_connected(_on_squad_lost):
		SquadManager.squad_lost.connect(_on_squad_lost)

	# Get squad starting sectors for EnemyManager
	var squad_sectors = []
	for s in squad_list:
		squad_sectors.append(s.sector)

	EnemyManager.init_enemies(squad_sectors, enemy_list)
	pending_enemy_list = enemy_list

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

	# Resolve squad actions (movement, combat, healing)
	last_action_results = SquadManager.resolve_turn(pending_allocations)

	# Enemies advance after squads act
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

	# Check turn limit
	if max_turns > 0 and current_turn >= max_turns:
		_check_win_condition()
		return

	emit_signal("turn_started", current_turn)


func _check_win_condition() -> void:
	var held = EnemyManager.get_held_count()
	var squads_alive = 0
	var squads_lost = 0
	for squad_name in SquadManager.squads:
		var s = SquadManager.squads[squad_name]
		if s.status == SquadManager.Status.LOST:
			squads_lost += 1
		else:
			squads_alive += 1

	var won = held >= win_condition_hexes
	var report = {
		"won":           won,
		"held_hexes":    held,
		"required_hexes": win_condition_hexes,
		"squads_alive":  squads_alive,
		"squads_lost":   squads_lost,
		"turns":         current_turn,
	}

	if won:
		emit_signal("mission_complete", report)
	else:
		emit_signal("mission_failed", "Insufficient territory held at mission end. Required %d hexes, held %d." % [win_condition_hexes, held])


func _on_squad_lost(squad_name: String) -> void:
	print("TurnManager: %s has been lost." % squad_name)
