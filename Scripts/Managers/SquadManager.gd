extends Node
# =============================================================
# SquadManager.gd  —  AutoLoad singleton
# =============================================================

signal turn_resolved
signal squad_lost(squad_name: String)

enum Status { ACTIVE, WOUNDED, CRITICAL, LOST }
enum Need   { ARMAMENTS, MEDI_PACKS, FUEL_CELLS }
enum Goal {
	ADVANCE,          # default — move toward enemies/uncaptured tiles
	ATTACK_PRIORITY,  # moving toward priority target
	POWER_TOWER,      # stationary at tower, needs Fuel Cells
	HOLD_TOWER,       # tower powered, holding position
	EXTRACT,          # moving toward extraction zone
	FALLBACK,         # abandoned tower goal, reverting to advance
}

const GOAL_NAMES: Dictionary = {
	Goal.ADVANCE:          "Advancing",
	Goal.ATTACK_PRIORITY:  "Targeting priority contact",
	Goal.POWER_TOWER:      "Powering comms tower",
	Goal.HOLD_TOWER:       "Holding comms tower",
	Goal.EXTRACT:          "Moving to extract",
	Goal.FALLBACK:         "Falling back",
}

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

const ARM_CASUALTY_CHANCE: float = 0.25
const NO_FUEL_OBSTACLE_CHANCE: float = 0.2
const BANK_CAP: int = 3

var squads: Dictionary = {}
var current_turn: int = 0
var interference: float = 0.0


func init_squads(squad_list: Array, mission_interference: float) -> void:
	for key in squads:
		squads[key].status = Status.ACTIVE
		squads[key].turns_unsupplied = 0
		squads[key].report = ""
		squads[key]["first_turn_bonus"] = false
		squads[key]["surprise_bonus"] = false
		squads[key]["goal"] = Goal.ADVANCE
		squads[key]["tower_fuel_turns"] = 0
		# has_data intentionally NOT reset — carries over between missions

	current_turn = 0
	interference = mission_interference

	# Add mission-defined squads — skip if already in roster (carry-over)
	for s in squad_list:
		if not squads.has(s.name):
			squads[s.name] = _make_squad(s)
		else:
			# Update sector to mission starting position
			squads[s.name].sector = s.sector

	_generate_briefings()


func _make_squad(s: Dictionary) -> Dictionary:
	return {
		"name":              s.name,
		"sector":            s.sector,
		"status":            s.get("status", Status.ACTIVE),
		"need":              s.get("need", Need.ARMAMENTS),
		"report":            "",
		"turns_unsupplied":  0,
		"bank":              { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 },
		"first_turn_bonus":  false,
		"surprise_bonus":    false,
		"goal":              Goal.ADVANCE,
		"has_data":          false,
		"tower_fuel_turns":  0,
		"tower_fuel_turns_waited": 0,
	}

func add_squad(squad_name: String, sector: String, surprise: bool) -> void:
	squads[squad_name] = {
		"name":              squad_name,
		"sector":            sector,
		"status":            Status.ACTIVE,
		"need":              Need.ARMAMENTS,
		"report":            "",
		"turns_unsupplied":  0,
		"bank":              { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 },
		"first_turn_bonus":  true,
		"surprise_bonus":    surprise,
		"goal":              Goal.ADVANCE,
		"has_data":          false,
		"tower_fuel_turns":  0,
		"tower_fuel_turns_waited": 0,
	}
	GameManager.register_reinforcement_name(squad_name)


func get_squads_for_ui() -> Array:
	var result: Array = []
	for key in squads:
		result.append(squads[key])
	return result


func get_squad_names() -> Array:
	return squads.keys()


func resolve_turn(allocations: Dictionary) -> Dictionary:
	current_turn += 1

	GameManager.consume_supplies(allocations)

	_assign_goals()

	var action_results: Dictionary = {}

	for squad_name in squads:
		var squad = squads[squad_name]

		if squad.status == Status.LOST:
			squad.report = _lost_line(squad)
			action_results[squad_name] = { "action": "lost", "moved_to": "" }
			continue

		var alloc    = allocations.get(squad_name, {})
		var fresh_arms = alloc.get("Armaments",  0) > 0
		var fresh_meds = alloc.get("Medi-Packs", 0) > 0
		var fresh_fuel = alloc.get("Fuel Cells", 0) > 0

		var used_banked_arms = false
		var used_banked_fuel = false
		var used_banked_meds = false

		var effective_arms = fresh_arms or squad.get("first_turn_bonus", false)
		if not effective_arms and _consume_bank(squad, "Armaments"):
			effective_arms = true
			used_banked_arms = true

		var effective_fuel = fresh_fuel
		if not effective_fuel and _consume_bank(squad, "Fuel Cells"):
			effective_fuel = true
			used_banked_fuel = true

		var needs_heal = squad.status == Status.WOUNDED or squad.status == Status.CRITICAL
		var effective_meds = fresh_meds
		if not effective_meds and needs_heal and _consume_bank(squad, "Medi-Packs"):
			effective_meds = true
			used_banked_meds = true

		var action     = "none"
		var moved_to   = ""
		var obstacle   = false
		var casualty_from_kill = false
		var move_range = 2 if effective_fuel else 1

		# -------------------------------------------------------
		# TOWER POWERING — squad at tower with fuel stays put
		# -------------------------------------------------------
		var at_tower = (GameManager.tower_sector != "" and squad.sector == GameManager.tower_sector)

		if at_tower and not GameManager.tower_powered and squad.goal == Goal.POWER_TOWER:
			if effective_fuel:
				squad.tower_fuel_turns += 1
				squad.tower_fuel_turns_waited = 0
				squad.turns_unsupplied = 0
				if squad.tower_fuel_turns >= 2:
					GameManager.activate_tower()
					squad.goal = Goal.HOLD_TOWER
					action = "powered_tower"
				else:
					action = "powering_tower"
			else:
				squad.tower_fuel_turns_waited += 1
				squad.tower_fuel_turns = 0  # fuel supply interrupted — reset progress
				if squad.tower_fuel_turns_waited >= 2:
					squad.goal = Goal.FALLBACK
					action = "abandoned_tower"
				else:
					action = "waiting_at_tower"
			# Either way, skip the rest of the normal movement block
			# Jump straight to medi-pack and banking sections below

		# -------------------------------------------------------
		# Obstacle check — only risk this when relying on the
		# baseline move (no fuel at all)
		# -------------------------------------------------------
		var can_attempt_move = true
		if not effective_fuel and randf() < NO_FUEL_OBSTACLE_CHANCE:
			can_attempt_move = false
			obstacle = true

		var fought_this_turn = false

		if can_attempt_move:
			var steps_taken = 0
			while steps_taken < move_range and not fought_this_turn:
				var current_sector = squad.sector
				var step_target = ""
				var engaging_enemy = false

				if effective_arms:
					step_target = EnemyManager.get_best_attack_target(current_sector)
					if step_target != "":
						engaging_enemy = true
					else:
						step_target = EnemyManager.get_best_move_target(current_sector)
				else:
					step_target = EnemyManager.get_best_move_into_enemy(current_sector)
					if step_target != "":
						engaging_enemy = true
					else:
						step_target = EnemyManager.get_best_move_target(current_sector)

				if step_target == "":
					break  # nowhere left to go

				# Goal-directed targeting overrides default movement
				if squad.goal == Goal.ATTACK_PRIORITY and GameManager.priority_target_alive:
					var pt_sector = EnemyManager.get_priority_target_sector()
					if pt_sector != "":
						if pt_sector in EnemyManager.adjacency.get(current_sector, []):
							step_target = pt_sector
							engaging_enemy = true
						else:
							step_target = _path_toward(current_sector, pt_sector)

				elif squad.goal == Goal.POWER_TOWER or squad.goal == Goal.HOLD_TOWER:
					var tower = GameManager.tower_sector
					if tower != "" and tower != current_sector:
						if tower in EnemyManager.adjacency.get(current_sector, []):
							step_target = tower
						else:
							step_target = _path_toward(current_sector, tower)

				elif squad.goal == Goal.EXTRACT:
					var ez = GameManager.extraction_zone
					if ez != "" and ez != current_sector:
						if ez in EnemyManager.adjacency.get(current_sector, []):
							step_target = ez
						else:
							step_target = _path_toward(current_sector, ez)

				squad.sector = step_target
				moved_to = step_target
				steps_taken += 1

				

				if engaging_enemy:
					if effective_arms:
						EnemyManager.fight_at(squad.sector, squad_name)
						EnemyManager.capture_tile(squad.sector)
						if randf() < ARM_CASUALTY_CHANCE:
							casualty_from_kill = true
						action = "moved_and_fought_armed" if steps_taken > 0 else "fought_armed"
					else:
						var result = EnemyManager.fight_at_unarmed(squad.sector)
						if result.squad_won:
							EnemyManager.capture_tile(squad.sector)
							action = "moved_and_fought_unarmed_won"
						else:
							var retreat = EnemyManager.get_best_move_target(squad.sector)
							if retreat != "":
								squad.sector = retreat
								moved_to = retreat
							_worsen_status(squad)
							action = "moved_and_fought_unarmed_lost"
					fought_this_turn = true
					squad.turns_unsupplied = 0
				else:
					EnemyManager.capture_tile(squad.sector)
					action = "moved"
					squad.turns_unsupplied = 0

		# -------------------------------------------------------
		# Stationary fallback — no movement happened this turn
		# -------------------------------------------------------
		if action == "none":
			if effective_arms:
				var fought = EnemyManager.fight_at(squad.sector, squad_name)
				if fought:
					action = "fought_armed"
					if randf() < ARM_CASUALTY_CHANCE:
						casualty_from_kill = true
					squad.turns_unsupplied = 0
				else:
					action = "held"
					squad.turns_unsupplied = 0
			else:
				var enemies_here = EnemyManager.get_enemy_count_at(squad.sector) > 0
				if enemies_here:
					var result = EnemyManager.fight_at_unarmed(squad.sector)
					if result.squad_won:
						EnemyManager.capture_tile(squad.sector)
						action = "fought_unarmed_won"
					else:
						_worsen_status(squad)
						action = "fought_unarmed_lost"
				else:
					action = "held_no_supply" if not obstacle else "held_obstacle"
				squad.turns_unsupplied += 1
				if squad.turns_unsupplied >= 2:
					_worsen_status(squad)

		if casualty_from_kill and squad.status != Status.LOST:
			_worsen_status(squad)

		# -------------------------------------------------------
		# MEDI-PACKS — heal if available (fresh or banked)
		# -------------------------------------------------------
		if effective_meds:
			_heal(squad)
			if action == "none":
				action = "healed"
			squad.turns_unsupplied = 0

		# -------------------------------------------------------
		# Bank unused fresh supplies
		# -------------------------------------------------------
		if fresh_arms and not used_banked_arms and action in ["held", "held_no_supply", "held_obstacle"]:
			_credit_bank(squad, "Armaments")
		if fresh_fuel and not used_banked_fuel and moved_to == "":
			_credit_bank(squad, "Fuel Cells")
		if fresh_meds and not used_banked_meds and not needs_heal:
			_credit_bank(squad, "Medi-Packs")

		# Clear bonuses after first turn
		squad["first_turn_bonus"] = false
		squad["surprise_bonus"]   = false

		squad.report = _generate_report(squad, action, moved_to, used_banked_arms, used_banked_fuel, used_banked_meds, obstacle, casualty_from_kill)
		squad.need   = _next_need(squad, action)
		action_results[squad_name] = { "action": action, "moved_to": moved_to }

		if squad.status == Status.LOST:
			emit_signal("squad_lost", squad_name)

	emit_signal("turn_resolved")
	return action_results


func get_reports() -> Dictionary:
	var result: Dictionary = {}
	for squad_name in squads:
		var squad = squads[squad_name]
		result[squad_name] = (
			_apply_interference(squad.report)
			if squad.status != Status.LOST
			else squad.report
		)
	return result

# In SquadManager.gd
func apply_bombardment_casualty(squad_name: String) -> void:
	if not squads.has(squad_name):
		return
	var squad = squads[squad_name]
	if squad.status == Status.LOST:
		return
	_worsen_status(squad)
	if squad.status == Status.LOST:
		emit_signal("squad_lost", squad_name)

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


# -------------------------------------------------------
# Helpers
# -------------------------------------------------------
func _heal(squad: Dictionary) -> void:
	match squad.status:
		Status.CRITICAL: squad.status = Status.WOUNDED
		Status.WOUNDED:  squad.status = Status.ACTIVE


func _worsen_status(squad: Dictionary) -> void:
	match squad.status:
		Status.ACTIVE:   squad.status = Status.WOUNDED
		Status.WOUNDED:  squad.status = Status.CRITICAL
		Status.CRITICAL: squad.status = Status.LOST


func _next_need(squad: Dictionary, last_action: String) -> int:
	if squad.status == Status.CRITICAL: return Need.MEDI_PACKS
	if squad.status == Status.WOUNDED:
		return Need.MEDI_PACKS if randf() > 0.4 else Need.ARMAMENTS
	match last_action:
		"moved":                         return Need.ARMAMENTS
		"fought_armed":                  return Need.MEDI_PACKS
		"moved_and_fought_armed":        return Need.MEDI_PACKS
		"moved_and_fought_unarmed_won":  return Need.ARMAMENTS
		"moved_and_fought_unarmed_lost": return Need.MEDI_PACKS
		"fought_unarmed_won":            return Need.ARMAMENTS
		"fought_unarmed_lost":           return Need.MEDI_PACKS
	return Need.FUEL_CELLS if randf() > 0.5 else Need.ARMAMENTS

func _apply_interference(text: String) -> String:
	if interference <= 0.0:
		return text
	if randf() < interference * 0.5:
		var words = text.split(" ")
		for i in range(words.size()):
			if randf() < interference * 0.2:
				words[i] = "—"
		return " ".join(words)
	return text


func _generate_briefings() -> void:
	for key in squads:
		var squad = squads[key]
		var need_str = NEED_NAMES[squad.need]
		match squad.status:
			Status.ACTIVE:
				squad.report = "%s reports in from %s. Combat-ready and requesting %s for the coming push." % [squad.name, squad.sector, need_str]
			Status.WOUNDED:
				squad.report = "%s holding at %s with casualties. Need %s before they can advance." % [squad.name, squad.sector, need_str]
			Status.CRITICAL:
				squad.report = "%s critical at %s. Without %s immediately, we may lose them." % [squad.name, squad.sector, need_str]


func _lost_line(squad: Dictionary) -> String:
	return "%s — no signal from %s. They are gone." % [squad.name, squad.sector]

func _bank_total(squad: Dictionary) -> int:
	var total = 0
	for s in squad.bank:
		total += squad.bank[s]
	return total

func _credit_bank(squad: Dictionary, supply: String) -> void:
	if _bank_total(squad) >= BANK_CAP:
		return  # full — excess trashed
	squad.bank[supply] += 1

func _consume_bank(squad: Dictionary, supply: String) -> bool:
	if squad.bank.get(supply, 0) > 0:
		squad.bank[supply] -= 1
		return true
	return false

func _generate_report(squad: Dictionary, action: String, moved_to: String, used_banked_arms: bool = false, used_banked_fuel: bool = false, used_banked_meds: bool = false, obstacle: bool = false, casualty: bool = false) -> String:
	var n = squad.name
	var s = squad.sector
	var m = moved_to if moved_to != "" else s

	if action == "held_obstacle":
		return "%s attempted to advance from %s but was bogged down by rough terrain — no fuel cells to push through. Held in place." % [n, s]

	var prefix = ""
	if used_banked_arms:
		prefix += "%s drew on stockpiled armaments. " % n
	if used_banked_fuel:
		prefix += "%s drew on reserve fuel cells. " % n
	if used_banked_meds:
		prefix += "%s used a stockpiled medi-pack. " % n

	var casualty_suffix = " Casualties taken in the engagement." if casualty else ""

	match action:
		"moved":
			return prefix + "%s advanced to %s. Sector secured." % [n, s]
		"fought_armed":
			return prefix + "%s engaged and eliminated enemy forces at %s. Sector held.%s" % [n, s, casualty_suffix]
		"moved_and_fought_armed":
			return prefix + "%s pushed into %s and neutralised enemy contact. Sector taken.%s" % [n, m, casualty_suffix]
		"moved_and_fought_unarmed_won":
			return prefix + "%s moved into %s without armaments and held their ground. Lucky." % [n, m]
		"moved_and_fought_unarmed_lost":
			return prefix + "%s engaged at %s without armaments and were pushed back. Casualties taken." % [n, m]
		"fought_unarmed_won":
			return prefix + "%s repelled enemy contact at %s without armaments. Barely held." % [n, s]
		"fought_unarmed_lost":
			return prefix + "%s overrun at %s — no armaments, no support. Casualties critical." % [n, s]
		"healed":
			return prefix + "%s received medical supplies at %s. Casualties stabilising." % [n, s]
		"held":
			return prefix + "%s is holding position at %s." % [n, s]
		"held_no_supply":
			match squad.status:
				Status.ACTIVE:   return "%s holding at %s. No supplies this turn." % [n, s]
				Status.WOUNDED:  return "%s taking losses at %s. Needs support." % [n, s]
				Status.CRITICAL: return "%s critical at %s. Without aid they will be lost." % [n, s]
		"powering_tower":
			return prefix + "%s is powering the comms tower at %s. Fuel Cells required next turn to complete." % [n, s]
		"powered_tower":
			return prefix + "%s has activated the comms tower at %s. Tower is now operational." % [n, s]
		"waiting_at_tower":
			return prefix + "%s is at the tower in %s awaiting fuel supply. Will abandon in %d turn(s)." % [n, s, 2 - squad.tower_fuel_turns_waited]
		"abandoned_tower":
			return prefix + "%s has abandoned the comms tower at %s — no fuel received. Falling back." % [n, s]
	return "%s — no report." % n

func _assign_goals() -> void:
	var tower_sector = GameManager.tower_sector
	var mission_type = GameManager.mission_type
	var has_tower = tower_sector != ""
	var tower_powered = GameManager.tower_powered

	# Count how many squads are already heading to or at the tower
	var squads_assigned_to_tower = 0
	for squad_name in squads:
		var squad = squads[squad_name]
		if squad.goal == Goal.POWER_TOWER or squad.goal == Goal.HOLD_TOWER:
			squads_assigned_to_tower += 1

	for squad_name in squads:
		var squad = squads[squad_name]
		if squad.status == Status.LOST:
			continue

		# Data carrier in M4/M5 tries to extract
		if squad.get("has_data", false) and mission_type in ["eliminate_priority", "extract"]:
			squad.goal = Goal.EXTRACT
			continue

		# Tower missions — assign 1-2 squads to tower if not yet powered
		if has_tower and not tower_powered and mission_type in ["hold_tower", "eliminate_priority", "extract"]:
			if squad.sector == tower_sector:
				# Already at tower — keep powering/holding
				squad.goal = Goal.POWER_TOWER if not tower_powered else Goal.HOLD_TOWER
				continue
			if squads_assigned_to_tower < 2:
				# Assign this squad to go for the tower
				squad.goal = Goal.POWER_TOWER
				squads_assigned_to_tower += 1
				continue

		# Tower is powered — one squad holds it
		if has_tower and tower_powered and squad.sector == tower_sector:
			squad.goal = Goal.HOLD_TOWER
			continue

		# Default — advance toward enemies
		if squad.goal not in [Goal.POWER_TOWER, Goal.HOLD_TOWER, Goal.EXTRACT]:
			squad.goal = Goal.ADVANCE

		# Priority target missions — reassign non-tower squads to hunt the target
		if mission_type == "eliminate_priority" and GameManager.priority_target_alive:
			if squad.goal == Goal.ADVANCE:
				squad.goal = Goal.ATTACK_PRIORITY

func _path_toward(from_sector: String, to_sector: String) -> String:
	if from_sector == to_sector:
		return ""
	var visited = { from_sector: true }
	var queue = [[from_sector, []]]
	while queue.size() > 0:
		var current = queue.pop_front()
		var node = current[0]
		var path = current[1]
		for neighbor in EnemyManager.adjacency.get(node, []):
			if neighbor == to_sector:
				return path[0] if path.size() > 0 else neighbor
			if not visited.has(neighbor):
				visited[neighbor] = true
				var new_path = path.duplicate()
				new_path.append(neighbor)
				queue.append([neighbor, new_path])
	return ""
