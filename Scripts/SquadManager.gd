extends Node
# =============================================================
# SquadManager.gd  —  AutoLoad singleton
# Register in: Project > Project Settings > AutoLoad
# Name: SquadManager
# IMPORTANT: List this FIRST in AutoLoad order so its enums
#            are available to GameManager and TurnManager.
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
			"need":             s.get("need",   Need.ARMAMENTS),
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


func resolve_turn(allocations: Dictionary) -> void:
	current_turn += 1
	for squad_name in squads:
		var squad = squads[squad_name]
		if squad.status == Status.LOST:
			squad.report = _lost_line(squad)
			continue
		var supplied: String = _get_primary_supply(squad_name, allocations)
		var needed: String   = NEED_NAMES[squad.need]
		if supplied == needed:
			squad.report = _report_success(squad, supplied)
			_improve_status(squad)
			squad.turns_unsupplied = 0
		elif supplied != "":
			squad.report = _report_wrong(squad, supplied, needed)
			squad.turns_unsupplied += 1
			if squad.turns_unsupplied >= 2:
				_worsen_status(squad)
		else:
			squad.report = _report_unsupplied(squad, needed)
			squad.turns_unsupplied += 1
			_worsen_status(squad)
		squad.need = _next_need(squad)
		if squad.status == Status.LOST:
			emit_signal("squad_lost", squad_name)
	emit_signal("turn_resolved")


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


# -------------------------------------------------------
# Internal
# -------------------------------------------------------
func _get_primary_supply(squad_name: String, allocations: Dictionary) -> String:
	if not allocations.has(squad_name):
		return ""
	var alloc = allocations[squad_name]
	for supply in ["Armaments", "Medi-Packs", "Fuel Cells"]:
		if alloc.get(supply, 0) > 0:
			return supply
	return ""


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
	if squad.status == Status.CRITICAL:
		return Need.MEDI_PACKS
	if squad.status == Status.WOUNDED and randf() > 0.4:
		return Need.MEDI_PACKS
	return randi() % 3


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


func _generate_briefings() -> void:
	for key in squads:
		var squad = squads[key]
		var need_str = NEED_NAMES[squad.need]
		match squad.status:
			Status.ACTIVE:
				squad.report = "%s reports in from %s. Unit is combat-ready and requesting %s for the coming push." % [squad.name, squad.sector, need_str]
			Status.WOUNDED:
				squad.report = "%s is holding position at %s with casualties. They need %s before they can advance." % [squad.name, squad.sector, need_str]
			Status.CRITICAL:
				squad.report = "%s is in critical condition at %s. Without %s immediately, we may lose them." % [squad.name, squad.sector, need_str]


func _lost_line(squad: Dictionary) -> String:
	return "%s — no signal from %s. They are gone." % [squad.name, squad.sector]


func _report_success(squad: Dictionary, supply: String) -> String:
	var n = squad.name; var s = squad.sector
	match supply:
		"Armaments":
			return [
				"%s received your arms drop and pushed forward into %s. Enemy contact reported — they are holding." % [n, s],
				"Your ordnance reached %s in time. They have taken ground in %s and are calling it a victory — for now." % [n, s],
				"%s used the arms well. The advance at %s is holding, but they will need resupply soon." % [n, s],
			][randi() % 3]
		"Medi-Packs":
			return [
				"The medi-packs reached %s. Casualties stabilised — the unit is recovering at %s." % [n, s],
				"%s reports the wounded are being treated. Morale is up. They will be ready to move on your word." % n,
				"Your medical drop saved lives in %s. %s can fight again." % [s, n],
			][randi() % 3]
		"Fuel Cells":
			return [
				"%s got your fuel cells. Vehicles are moving again in %s — they can reposition on your order." % [n, s],
				"Fuel delivery confirmed at %s. %s is mobile once more." % [s, n],
				"%s reports full mobility restored. %s is no longer a sitting target." % [n, s],
			][randi() % 3]
	return "%s received supplies and reports positive." % n


func _report_wrong(squad: Dictionary, sent: String, needed: String) -> String:
	var n = squad.name
	return [
		"%s acknowledges receipt of %s, but what they needed was %s. The situation is not improving." % [n, sent, needed],
		"Your %s drop reached %s, but it was not what they asked for. They are requesting %s." % [sent, n, needed],
		"%s has your %s but cannot use it — they are desperate for %s." % [n, sent, needed],
	][randi() % 3]


func _report_unsupplied(squad: Dictionary, needed: String) -> String:
	var n = squad.name; var s = squad.sector
	match squad.status:
		Status.ACTIVE:
			return [
				"%s received nothing this turn. They are holding at %s, but the men are asking questions." % [n, s],
				"No supply drop for %s. They are rationing what is left. %s is tense." % [n, s],
			][randi() % 2]
		Status.WOUNDED:
			return [
				"%s got nothing. The wounded are not being treated. They need %s now." % [n, needed],
				"Another turn without support for %s. Their condition is worsening. Send %s." % [n, needed],
			][randi() % 2]
		Status.CRITICAL:
			return "%s — CRITICAL. No supply received. Requesting immediate %s. If we do not act next turn, we will lose them." % [n, needed]
	return "%s — no signal." % n
