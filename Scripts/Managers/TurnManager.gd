extends Node
# =============================================================
# TurnManager.gd  —  AutoLoad singleton
# No turn limit. Win condition: hold X tiles after enemy push.
# Loss condition: all squads lost.
# =============================================================

signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal allocations_locked
signal mission_complete(report: Dictionary)
signal mission_failed(reason: String)

var current_turn: int = 0
var win_condition_hexes: int = 5
var allocations_are_locked: bool = false
var pending_allocations: Dictionary = {}
var pending_enemy_list: Array = []

# Supply history for mission report
# { squad_name: [ { "turn": int, "armaments": bool, "medi_packs": bool, "fuel_cells": bool } ] }
var supply_history: Dictionary = {}

# Track what happened each turn for the report
var turn_log: Array = []  # [ { "turn": int, "actions": { squad: action }, "held_after": int } ]


func start_mission(mission_data: Dictionary) -> void:
	current_turn = 0
	win_condition_hexes = mission_data.get("win_hexes", 5)
	allocations_are_locked = false
	pending_allocations = {}
	supply_history = {}
	turn_log = []

	var squad_list   = mission_data.get("squads", [])
	var interference = mission_data.get("interference", 0.0)
	var enemy_list   = mission_data.get("enemies", [])

	SquadManager.init_squads(squad_list, interference)

	if not SquadManager.squad_lost.is_connected(_on_squad_lost):
		SquadManager.squad_lost.connect(_on_squad_lost)

	var squad_sectors = []
	for s in squad_list:
		squad_sectors.append(s.sector)
		supply_history[s.name] = []

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

	# Record supply history for this turn
	for squad_name in pending_allocations:
		var alloc = pending_allocations[squad_name]
		if supply_history.has(squad_name):
			supply_history[squad_name].append({
				"turn":       current_turn,
				"armaments":  alloc.get("Armaments",  0) > 0,
				"medi_packs": alloc.get("Medi-Packs", 0) > 0,
				"fuel_cells": alloc.get("Fuel Cells",  0) > 0,
			})

	# Squads act
	var action_results = SquadManager.resolve_turn(pending_allocations)

	# Enemies advance
	EnemyManager.advance_enemies()

	# Record turn log
	var held_after = EnemyManager.get_held_count()
	turn_log.append({
		"turn":       current_turn,
		"actions":    action_results,
		"held_after": held_after,
	})

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

	# Check win condition — after enemy push
	if held_after >= win_condition_hexes:
		emit_signal("mission_complete", _build_report(true))
		return

	emit_signal("turn_started", current_turn)


func _build_report(won: bool) -> Dictionary:
	var squads_alive = 0
	var squads_lost  = 0
	var squad_details = []

	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		var is_lost = squad.status == SquadManager.Status.LOST
		if is_lost: squads_lost += 1
		else: squads_alive += 1

		# Build supply summary
		var arms_turns = 0; var meds_turns = 0; var fuel_turns = 0
		var history = supply_history.get(squad_name, [])
		for entry in history:
			if entry.get("armaments",  false): arms_turns += 1
			if entry.get("medi_packs", false): meds_turns += 1
			if entry.get("fuel_cells", false): fuel_turns += 1

		squad_details.append({
			"name":        squad_name,
			"final_status": SquadManager.STATUS_NAMES[squad.status],
			"final_sector": squad.sector,
			"lost":         is_lost,
			"arms_turns":   arms_turns,
			"meds_turns":   meds_turns,
			"fuel_turns":   fuel_turns,
		})

	return {
		"won":             won,
		"turns_taken":     current_turn,
		"held_hexes":      EnemyManager.get_held_count(),
		"required_hexes":  win_condition_hexes,
		"squads_alive":    squads_alive,
		"squads_lost":     squads_lost,
		"squad_details":   squad_details,
		"turn_log":        turn_log,
	}


func _on_squad_lost(squad_name: String) -> void:
	print("TurnManager: %s has been lost." % squad_name)	
