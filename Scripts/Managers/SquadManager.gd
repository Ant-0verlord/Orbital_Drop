extends Node
# =============================================================
# SquadManager.gd  —  AutoLoad singleton
# =============================================================

signal turn_resolved
signal squad_lost(squad_name: String)

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
			"need":             s.get("need", Need.ARMAMENTS),
			"report":           "",
			"turns_unsupplied": 0,
		}
	_generate_briefings()


func get_squads_for_ui() -> Array:
	var result: Array = []
	for key in squads:
		result.append(squads[key])
	return result


func get_squad_names() -> Array:
	return squads.keys()


func resolve_turn(allocations: Dictionary) -> Dictionary:
	current_turn += 1
	var action_results: Dictionary = {}

	for squad_name in squads:
		var squad = squads[squad_name]

		if squad.status == Status.LOST:
			squad.report = _lost_line(squad)
			action_results[squad_name] = { "action": "lost", "moved_to": "" }
			continue

		var alloc     = allocations.get(squad_name, {})
		var got_arms  = alloc.get("Armaments",  0) > 0
		var got_meds  = alloc.get("Medi-Packs", 0) > 0
		var got_fuel  = alloc.get("Fuel Cells", 0) > 0
		var action    = "none"
		var moved_to  = ""

		# FUEL + ARMS = move then fight
		if got_fuel and got_arms:
			var target = EnemyManager.get_best_attack_target(squad.sector)
			if target != "":
				squad.sector = target
				moved_to = target
				EnemyManager.fight_at(squad.sector, squad_name)
				EnemyManager.capture_tile(squad.sector)
				action = "moved_and_fought"
				squad.turns_unsupplied = 0
			else:
				# No enemies adjacent — just move
				target = EnemyManager.get_best_move_target(squad.sector)
				if target != "":
					squad.sector = target
					moved_to = target
					EnemyManager.capture_tile(squad.sector)
					action = "moved"
					squad.turns_unsupplied = 0

		# FUEL CELLS only = move and capture
		elif got_fuel:
			var target = EnemyManager.get_best_move_target(squad.sector)
			if target != "":
				squad.sector = target
				moved_to = target
				EnemyManager.capture_tile(squad.sector)
				action = "moved"
				squad.turns_unsupplied = 0

		# ARMAMENTS only = fight at current tile
		elif got_arms:
			var fought = EnemyManager.fight_at(squad.sector, squad_name)
			if fought:
				action = "fought"
				squad.turns_unsupplied = 0
			else:
				# No enemies here — still hold the tile
				action = "held"
				squad.turns_unsupplied = 0

		# MEDI-PACKS = heal
		if got_meds:
			_heal(squad)
			if action == "none":
				action = "healed"
			squad.turns_unsupplied = 0

		# Nothing sent
		if not got_arms and not got_meds and not got_fuel:
			squad.turns_unsupplied += 1
			if squad.turns_unsupplied >= 2:
				_worsen_status(squad)

		squad.report = _generate_report(squad, action, moved_to)
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
		result[squad_name] = _apply_interference(squad.report) if squad.status != Status.LOST else squad.report
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
	if squad.status == Status.WOUNDED:  return Need.MEDI_PACKS if randf() > 0.4 else Need.ARMAMENTS
	match last_action:
		"moved":            return Need.ARMAMENTS
		"fought":           return Need.MEDI_PACKS
		"moved_and_fought": return Need.MEDI_PACKS
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


func _generate_report(squad: Dictionary, action: String, moved_to: String) -> String:
	var n = squad.name
	var s = squad.sector
	match action:
		"moved":
			return "%s advanced to %s using fuel cells. Sector secured." % [n, s]
		"fought":
			return "%s engaged enemy forces at %s. Armaments expended — sector held." % [n, s]
		"moved_and_fought":
			return "%s pushed into %s and engaged enemy contact. Sector taken." % [n, moved_to if moved_to != "" else s]
		"healed":
			return "%s received medical supplies at %s. Casualties stabilising." % [n, s]
		"held":
			return "%s is holding position at %s." % [n, s]
		"none":
			match squad.status:
				Status.ACTIVE:   return "%s holding at %s. No supplies this turn." % [n, s]
				Status.WOUNDED:  return "%s taking losses at %s. Needs support." % [n, s]
				Status.CRITICAL: return "%s critical at %s. Without aid they will be lost." % [n, s]
	return "%s — no report." % n
