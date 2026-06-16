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
var mission_over: bool = false


func start_mission(mission_data: Dictionary) -> void:
	current_turn = 0
	max_turns = mission_data.get("turns", 5)
	win_condition_hexes = mission_data.get("win_hexes", 5)
	allocations_are_locked = false
	pending_allocations = {}
	mission_over = false

	var squad_list   = mission_data.get("squads", [])
	var interference = mission_data.get("interference", 0.0)
	var enemy_list   = mission_data.get("enemies", [])

	SquadManager.init_squads(squad_list, interference)

	if not SquadManager.squad_lost.is_connected(_on_squad_lost):
		SquadManager.squad_lost.connect(_on_squad_lost)

	var squad_sectors = []
	for s in squad_list:
		squad_sectors.append(s.sector)

	EnemyManager.init_enemies(squad_sectors, enemy_list)
	emit_signal("turn_started", current_turn)


func lock_allocations(allocations: Dictionary) -> void:
	if mission_over:
		return
	pending_allocations = allocations.duplicate(true)
	allocations_are_locked = true
	emit_signal("allocations_locked")


func end_turn() -> void:
	if mission_over:
		return
	if not allocations_are_locked:
		push_warning("TurnManager: end_turn called but allocations not locked!")
		return

	current_turn += 1

	SquadManager.resolve_turn(pending_allocations)
	EnemyManager.advance_enemies(pending_allocations)  # ← pass allocations

	allocations_are_locked = false
	pending_allocations = {}

	emit_signal("turn_ended", current_turn)

	var all_lost = true
	for squad_name in SquadManager.squads:
		if SquadManager.squads[squad_name].status != SquadManager.Status.LOST:
			all_lost = false
			break

	if all_lost:
		_end_mission(false, "All squads have been lost. No signal from the surface.")
		return

	if max_turns > 0 and current_turn >= max_turns:
		_check_win_condition()
		return

	emit_signal("turn_started", current_turn)


# -------------------------------------------------------
# Called when turn limit is reached
# -------------------------------------------------------
func _check_win_condition() -> void:
	var held = EnemyManager.get_held_count()
	var won  = held >= win_condition_hexes

	if won:
		_end_mission(true, "")
	else:
		_end_mission(false,
			"Insufficient territory held. Required %d sectors, held %d." % [win_condition_hexes, held]
		)


# -------------------------------------------------------
# Single point of mission resolution
# -------------------------------------------------------
func _end_mission(won: bool, reason: String) -> void:
	mission_over = true

	var held         = EnemyManager.get_held_count()
	var squads_alive = 0
	var squads_lost  = 0
	for squad_name in SquadManager.squads:
		var s = SquadManager.squads[squad_name]
		if s.status == SquadManager.Status.LOST:
			squads_lost += 1
		else:
			squads_alive += 1

	var score = GameManager.calculate_score(held, current_turn, win_condition_hexes)

	var report = {
		"won":             won,
		"reason":          reason,
		"held_hexes":      held,
		"required_hexes":  win_condition_hexes,
		"squads_alive":    squads_alive,
		"squads_lost":     squads_lost,
		"turns":           current_turn,
		"score":           score.total,
		"rating":          score.rating,
		"tile_score":      score.tile_score,
		"turn_bonus":      score.turn_bonus,
		"supply_bonus":    score.supply_bonus,
	}

	GameManager.campaign_record.append("win" if won else "loss")

	if won:
		emit_signal("mission_complete", report)
	else:
		emit_signal("mission_failed", reason)
		# Also emit mission_complete so UI can show the full scored report
		# even on a loss — popups decide how to display it
		emit_signal("mission_complete", report)


func _on_squad_lost(squad_name: String) -> void:
	print("TurnManager: %s has been lost." % squad_name)
