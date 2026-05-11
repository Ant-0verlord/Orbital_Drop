extends Node
# =============================================================
# SquadManager.gd  —  AutoLoad singleton
# AutoLoad order: SquadManager, TurnManager, GameManager, EnemyManager
#
# Supply roles:
#   Fuel Cells  — squad moves to an adjacent hex
#   Armaments   — squad fights (pushes back enemies in current hex)
#   Medi-Packs  — squad heals (Critical→Wounded, Wounded→Active)
# =============================================================

signal turn_resolved
signal squad_lost(squad_name: String)
signal squad_moved(squad_name: String, from_sector: String, to_sector: String)

enum Status { ACTIVE, WOUNDED, CRITICAL, LOST }
enum Need   { ARMAMENTS, MEDI_PACKS, FUEL_CELLS }

const STATUS_NAMES: Dictionary = {
	Status.ACTIVE:   "Active",
	Status.WOUNDED:  "Wounded",
	Status.CRITICAL: "Critical",
	Status.LOST:     "Lost — no signal",
}

const NEED_NAMES: Dictionary = {
	Need.ARMAMENTS:  "Armaments",
	Need.MEDI_PACKS: "Medi-Packs",
	Need.FUEL_CELLS: "Fuel Cells",
}

# squads: { squad_name: squad_dict }
# squad_dict keys: name, sector, status, need, report, turns_unsupplied,
#                  fought_this_turn, moved_this_turn
var squads: Dictionary = {}
var current_turn: int = 0
var interference: float = 0.0


func init_squads(squad_list: Array, mission_interference: float) -> void:
	squads.clear()
	current_turn = 0
	interference = mission_interference
	for s in squad_list:
		squads[s.name] = {
			"name":             s.name,
			"sector":           s.sector,
			"status":           s.get("status", Status.ACTIVE),
			"need":             s.get("need",   Need.ARMAMENTS),
			"report":           "",
			"turns_unsupplied": 0,
			"fought_this_turn": false,
			"moved_this_turn":  false,
		}
	_generate_briefings()


func get_squads_for_ui() -> Array:
	var result: Array = []
	for key in squads:
		result.append(squads[key])
	return result


func get_squad_names() -> Array:
	return squads.keys()


func get_squad_sectors() -> Array:
	var sectors = []
	for key in squads:
		if squads[key].status != Status.LOST:
			sectors.append(squads[key].sector)
	return sectors


# -------------------------------------------------------
# Main turn resolution
# allocations: { squad_name: { "Armaments": int, "Medi-Packs": int, "Fuel Cells": int } }
# -------------------------------------------------------
func resolve_turn(allocations: Dictionary) -> void:
	current_turn += 1

	for squad_name in squads:
		var squad = squads[squad_name]
		squad.fought_this_turn = false
		squad.moved_this_turn  = false

		if squad.status == Status.LOST:
			squad.report = _lost_line(squad)
			continue

		var alloc = allocations.get(squad_name, {})
		var got_fuel     = alloc.get("Fuel Cells",  0) > 0
		var got_arms     = alloc.get("Armaments",   0) > 0
		var got_meds     = alloc.get("Medi-Packs",  0) > 0
		var got_anything = got_fuel or got_arms or got_meds

		var report_parts = []

		# --- MEDI-PACKS: heal first ---
		if got_meds:
			var healed = _heal(squad)
			if healed:
				report_parts.append(_report_healed(squad))
			else:
				report_parts.append("%s received medi-packs but has no wounds to treat." % squad.name)

		# --- FUEL CELLS: move to adjacent hex ---
		if got_fuel:
			var moved = _try_move(squad)
			if moved:
				report_parts.append(_report_moved(squad))
				squad.moved_this_turn = true
			else:
				report_parts.append("%s received fuel cells but had no viable hex to advance into." % squad.name)

		# --- ARMAMENTS: fight enemies in current hex ---
		if got_arms:
			var fought = _fight(squad)
			squad.fought_this_turn = fought
			if fought:
				report_parts.append(_report_fought(squad))
			else:
				report_parts.append("%s received armaments but there are no enemies in their sector." % squad.name)

		# --- Nothing sent ---
		if not got_anything:
			squad.turns_unsupplied += 1
			_worsen_status(squad)
			report_parts.append(_report_unsupplied(squad))
		else:
			squad.turns_unsupplied = 0

		squad.need   = _next_need(squad)
		squad.report = "\n".join(report_parts) if report_parts.size() > 0 else "%s holds position." % squad.name

		if squad.status == Status.LOST:
			emit_signal("squad_lost", squad_name)

	emit_signal("turn_resolved")


# -------------------------------------------------------
# Supply actions
# -------------------------------------------------------
func _heal(squad: Dictionary) -> bool:
	match squad.status:
		Status.CRITICAL:
			squad.status = Status.WOUNDED
			return true
		Status.WOUNDED:
			squad.status = Status.ACTIVE
			return true
	return false


func _try_move(squad: Dictionary) -> bool:
	# Ask EnemyManager/HoloMap for adjacency — use EnemyManager.adjacency
	var neighbors = EnemyManager.adjacency.get(squad.sector, [])
	if neighbors.is_empty():
		return false

	# Find best adjacent hex — prefer uncontested neutral, then enemy-free
	var best = ""
	for neighbor in neighbors:
		var enemy_count = EnemyManager.get_enemy_count_at(neighbor)
		var squad_there = _squad_at(neighbor)
		if squad_there == "" and enemy_count == 0:
			best = neighbor
			break

	# If no clean hex, try one with enemies (contested push)
	if best == "":
		for neighbor in neighbors:
			var squad_there = _squad_at(neighbor)
			if squad_there == "":
				best = neighbor
				break

	if best == "":
		return false

	var old_sector = squad.sector
	squad.sector = best
	emit_signal("squad_moved", squad.name, old_sector, best)
	return true


func _fight(squad: Dictionary) -> bool:
	var enemy_count = EnemyManager.get_enemy_count_at(squad.sector)
	if enemy_count == 0:
		return false
	# Push back one enemy unit from this sector
	EnemyManager.push_back_enemy(squad.sector)
	return true


func _squad_at(sector: String) -> String:
	for key in squads:
		if squads[key].sector == sector and squads[key].status != Status.LOST:
			return key
	return ""


# -------------------------------------------------------
# Status changes
# -------------------------------------------------------
func _improve_status(squad: Dictionary) -> void:
	match squad.status:
		Status.CRITICAL: squad.status = Status.WOUNDED
		Status.WOUNDED:  squad.status = Status.ACTIVE


func _worsen_status(squad: Dictionary) -> void:
	match squad.status:
		Status.ACTIVE:   squad.status = Status.WOUNDED
		Status.WOUNDED:  squad.status = Status.CRITICAL
		Status.CRITICAL: squad.status = Status.LOST


func _next_need(squad: Dictionary) -> int:
	# Critical squads always need medi-packs
	if squad.status == Status.CRITICAL:
		return Need.MEDI_PACKS
	# Wounded squads usually need medi-packs
	if squad.status == Status.WOUNDED and randf() > 0.35:
		return Need.MEDI_PACKS
	# Otherwise rotate between armaments and fuel cells
	return [Need.ARMAMENTS, Need.FUEL_CELLS][randi() % 2]


# -------------------------------------------------------
# Intel / interference
# -------------------------------------------------------
func get_reports() -> Dictionary:
	var result: Dictionary = {}
	for squad_name in squads:
		var squad = squads[squad_name]
		if squad.status == Status.LOST:
			result[squad_name] = squad.report
		else:
			result[squad_name] = _apply_interference(squad.report, squad.need)
	return result


func get_briefings() -> Dictionary:
	var result: Dictionary = {}
	for squad_name in squads:
		result[squad_name] = squads[squad_name].report
	return result


func get_need_display(squad_name: String) -> String:
	if not squads.has(squad_name):
		return "Unknown"
	var squad = squads[squad_name]
	if squad.status == Status.LOST:
		return "—"
	if randf() < interference * 0.8:
		return "[INTERFERENCE]"
	return NEED_NAMES[squad.need]


func _apply_interference(text: String, need: int) -> String:
	if interference <= 0.0:
		return text
	var corrupted = text
	if randf() < interference * 0.7:
		corrupted = corrupted.replace(NEED_NAMES[need], "[SIGNAL LOST]")
	if interference >= 0.75 and randf() < 0.5:
		var words = corrupted.split(" ")
		for i in range(words.size()):
			if randf() < 0.25:
				words[i] = "—"
		corrupted = " ".join(words)
	return corrupted


# -------------------------------------------------------
# Report generation
# -------------------------------------------------------
func _generate_briefings() -> void:
	for key in squads:
		var squad = squads[key]
		var need_str = NEED_NAMES[squad.need]
		match squad.status:
			Status.ACTIVE:
				squad.report = "%s reports in from %s. Unit is combat-ready and requesting %s." % [squad.name, squad.sector, need_str]
			Status.WOUNDED:
				squad.report = "%s is holding position at %s with casualties. They need %s." % [squad.name, squad.sector, need_str]
			Status.CRITICAL:
				squad.report = "%s is in critical condition at %s. Without %s immediately, we may lose them." % [squad.name, squad.sector, need_str]


func _lost_line(squad: Dictionary) -> String:
	return "%s — no signal from %s. They are gone." % [squad.name, squad.sector]


func _report_healed(squad: Dictionary) -> String:
	match squad.status:
		Status.ACTIVE:
			return [
				"The medi-packs reached %s. Casualties stabilised — the unit is back to full strength." % squad.name,
				"%s reports the wounded are treated. They are ready to advance." % squad.name,
			][randi() % 2]
		Status.WOUNDED:
			return [
				"%s has been stabilised by your medical drop. They are wounded but holding." % squad.name,
				"Your medi-packs kept %s in the fight. Still wounded, but no longer critical." % squad.name,
			][randi() % 2]
	return "%s received medi-packs." % squad.name


func _report_moved(squad: Dictionary) -> String:
	return [
		"%s used the fuel cells to push forward into %s. Sector is now under their control." % [squad.name, squad.sector],
		"Fuel confirmed — %s has advanced to %s and is establishing a position." % [squad.name, squad.sector],
		"%s is moving. New position: %s." % [squad.name, squad.sector],
	][randi() % 3]


func _report_fought(squad: Dictionary) -> String:
	return [
		"%s engaged enemy forces in %s with your armament drop. One enemy unit pushed back." % [squad.name, squad.sector],
		"Your ordnance reached %s in time. They held the line at %s and pushed the enemy back." % [squad.name, squad.sector],
		"%s used the arms well — enemy driven back from %s." % [squad.name, squad.sector],
	][randi() % 3]


func _report_unsupplied(squad: Dictionary) -> String:
	var n = squad.name
	var s = squad.sector
	match squad.status:
		Status.ACTIVE:
			return [
				"%s received nothing this turn. They are holding at %s but supplies are running low." % [n, s],
				"No drop for %s. They are rationing what is left. %s is tense." % [n, s],
			][randi() % 2]
		Status.WOUNDED:
			return [
				"%s got nothing. The wounded are not being treated. Their condition is worsening." % n,
				"Another turn without support for %s. They need supplies urgently." % n,
			][randi() % 2]
		Status.CRITICAL:
			return "%s — CRITICAL. No supply received. They will not survive another turn without aid." % n
	return "%s — no signal." % n
