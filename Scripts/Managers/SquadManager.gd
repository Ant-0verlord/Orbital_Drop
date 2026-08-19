extends Node
# =============================================================
# SquadManager.gd  —  AutoLoad singleton
# =============================================================

signal turn_resolved
signal squad_lost(squad_name: String)
signal data_passed(from_squad: String, to_squad: String)
signal data_destroyed_by_enemy(squad_name: String)

enum Status { ACTIVE, WOUNDED, CRITICAL, LOST }
enum Need   { ARMAMENTS, MEDI_PACKS, FUEL_CELLS }
enum Goal {
	ADVANCE,          # default — move toward enemies/uncaptured tiles
	ATTACK_PRIORITY,  # moving toward priority target
	POWER_TOWER,      # stationary at tower, needs Fuel Cells
	HOLD_TOWER,       # tower powered, holding position
	DEFEND_TOWER,     # near the tower but not needed to power/hold it —
					  # digs in and fights off attackers instead of advancing
	EXTRACT,          # moving toward extraction zone
	DEFEND_CARRIER,
	SECURE_ZONE,      # pushing to hold the extraction zone pre-emptively,
					  # before the shuttle is actually inbound (M5)
	FALLBACK,         # abandoned tower goal, reverting to advance
}

const GOAL_NAMES: Dictionary = {
	Goal.ADVANCE:          "Advancing",
	Goal.ATTACK_PRIORITY:  "Targeting priority contact",
	Goal.POWER_TOWER:      "Powering comms tower",
	Goal.HOLD_TOWER:       "Holding comms tower",
	Goal.DEFEND_TOWER:     "Defending tower perimeter",
	Goal.EXTRACT:          "Moving to extract",
	Goal.DEFEND_CARRIER:   "Defending data carrier",
	Goal.SECURE_ZONE:      "Securing extraction zone",
	Goal.FALLBACK:         "Falling back",
}

# How close (in hexes) a squad needs to be to the tower to be put on
# perimeter-defence duty instead of wandering off to advance elsewhere.
const DEFEND_TOWER_RADIUS: int = 2

# How close a SECURE_ZONE squad needs to stay to the extraction zone once
# it's dug in there — mirrors DEFEND_TOWER_RADIUS's "anchor but allow local
# mop-up" behaviour.
const SECURE_ZONE_RADIUS: int = 2

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
# Chance a squad moving without fuel gets bogged down by rough terrain and
# held in place for the turn. Was 0.2 (1 in 5 every unfueled move) — with
# fuel already scarce, that was tripping squads up too often. Lowered to
# make it a real but less frequent risk.
const NO_FUEL_OBSTACLE_CHANCE: float = 0.1
const BANK_CAP: int = 3

var squads: Dictionary = {}
var current_turn: int = 0
var interference: float = 0.0


func init_squads(squad_list: Array, mission_interference: float, rally_candidates: Array = []) -> void:
	var mission_squad_names: Array = []
	for s in squad_list:
		mission_squad_names.append(s.name)

	for key in squads:
		# A squad lost in a previous mission stays lost — it doesn't get
		# quietly revived just because a new mission started.
		if squads[key].status == Status.LOST:
			continue
		squads[key].status = Status.ACTIVE
		squads[key].turns_unsupplied = 0
		squads[key].report = ""
		squads[key]["first_turn_bonus"] = false
		squads[key]["surprise_bonus"] = false
		squads[key]["goal"] = Goal.ADVANCE
		squads[key]["tower_fuel_turns"] = 0
		squads[key]["tower_fuel_turns_waited"] = 0
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

		# Normally the data carrier is set mid-Mission-4 when the priority
		# target is eliminated, and the squad already has has_data=true by
		# the time it carries into this mission. Debug-jumping straight
		# here skips that entirely though, so GameManager may hand the
		# carrier flag to a squad that doesn't have it yet — pick that up
		# here rather than requiring Mission 4 to have actually been played.
		if GameManager.data_carrier_squad == s.name and not squads[s.name].get("has_data", false):
			squads[s.name]["has_data"] = true

	# Squads called in as reinforcements during a previous mission aren't
	# part of this mission's scripted roster, so they never get a sector
	# on this mission's map — they'd be left standing on a sector name
	# that doesn't exist here. Bring each one in already-there, on its
	# own hex near the main force's landing point (TurnManager works out
	# the candidate hexes ahead of time) rather than stacking every
	# carried squad onto the same tile.
	var fallback_sector = ""
	if squad_list.size() > 0:
		fallback_sector = squad_list[0].sector
	var next_rally_idx = 0
	for key in squads:
		if key in mission_squad_names:
			continue
		if squads[key].status == Status.LOST:
			continue
		if next_rally_idx < rally_candidates.size():
			squads[key].sector = rally_candidates[next_rally_idx]
			next_rally_idx += 1
		elif fallback_sector != "":
			squads[key].sector = fallback_sector

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

# Called by GameManager when the enemy retakes the tower sector — clears
# every squad's fuel-powering progress so it has to be earned again from
# scratch, and drops anyone still holding onto HOLD_TOWER back to a
# normal goal (the next _assign_goals() pass will reassign whoever is
# closest to POWER_TOWER since tower_powered is now false).
func reset_tower_progress() -> void:
	for squad_name in squads:
		var squad = squads[squad_name]
		squad.tower_fuel_turns = 0
		squad.tower_fuel_turns_waited = 0
		if squad.goal == Goal.HOLD_TOWER:
			squad.goal = Goal.ADVANCE

func _on_priority_target_eliminated(squad_name: String, sector: String) -> void:
	# Fires for every way the priority target can go down — normal combat,
	# a reinforcement hot-drop, or an orbital strike — so this is the one
	# place to alert on it rather than three separate call sites.
	AudioManager.play_alarm()
	if squad_name == "":
		return  # orbital strike kill — data destroyed, no carrier
	if squads.has(squad_name):
		squads[squad_name]["has_data"] = true
		print("DATA SECURED: %s acquired the objective data at %s" % [squad_name, sector])



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

	# Freeze what each hex's control state looked like before any squad
	# moves this turn — see hex_control_turn_start in EnemyManager for why.
	EnemyManager.snapshot_hex_control()

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
		var anchored_at_tower = false

		if at_tower and not GameManager.tower_powered and squad.goal == Goal.POWER_TOWER:
			anchored_at_tower = true
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
			# Either way, this squad stays put — the movement block below
			# is skipped entirely (anchored_at_tower gates it off).
			# Jump straight to medi-pack and banking sections below
		elif at_tower and squad.goal == Goal.HOLD_TOWER:
			# Once the tower is powered, the squad holding it needs to
			# actually stay there. Nothing previously anchored a HOLD_TOWER
			# squad in place — the goal-directed movement override further
			# below only redirects a squad TOWARD the tower when it isn't
			# already standing on it, so a squad already there fell through
			# to the default attack/advance targeting and would happily
			# wander off to fight or capture some other sector, abandoning
			# the tower it was meant to be holding. That surfaced at
			# mission end as a false "tower lost — enemy forces recaptured"
			# failure even though the enemy never actually retook it.
			anchored_at_tower = true
			action = "holding_tower"

		# -------------------------------------------------------
		# Obstacle check — only risk this when relying on the
		# baseline move (no fuel at all)
		# -------------------------------------------------------
		var can_attempt_move = not anchored_at_tower
		if can_attempt_move and not effective_fuel and randf() < NO_FUEL_OBSTACLE_CHANCE:
			can_attempt_move = false
			obstacle = true

		var fought_this_turn = false

		var fleeing_with_data = false
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
						step_target = _default_advance_target(squad, current_sector)
				else:
					step_target = EnemyManager.get_best_move_into_enemy(current_sector)
					if step_target != "":
						engaging_enemy = true
					else:
						step_target = _default_advance_target(squad, current_sector)

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

				elif squad.goal == Goal.DEFEND_TOWER:
					# Anchored near the tower. If we've already found a fight
					# this step (engaging_enemy true from the default
					# targeting above), let it stand — that's exactly the
					# "fight enemies that come to attack it" behaviour.
					# Otherwise, only redirect back if we've drifted outside
					# the defence radius; inside it, default targeting is
					# free to mop up/capture nearby tiles.
					var tower_d = GameManager.tower_sector
					if tower_d != "" and not engaging_enemy:
						var dist_to_tower = EnemyManager.get_distance_between(current_sector, tower_d)
						if dist_to_tower > DEFEND_TOWER_RADIUS:
							if tower_d in EnemyManager.adjacency.get(current_sector, []):
								step_target = tower_d
							else:
								step_target = _path_toward(current_sector, tower_d)

				elif squad.goal == Goal.SECURE_ZONE:
					# Push toward the extraction zone ahead of the shuttle
					# call, the same way DEFEND_TOWER pushes toward the
					# tower — once within range, stop closing the distance
					# and let default targeting fight/capture locally so
					# the squad actually holds the ground instead of just
					# passing through it.
					var ez_s = GameManager.extraction_zone
					if ez_s != "" and not engaging_enemy:
						var dist_to_ez = EnemyManager.get_distance_between(current_sector, ez_s)
						if dist_to_ez > SECURE_ZONE_RADIUS:
							if ez_s in EnemyManager.adjacency.get(current_sector, []):
								step_target = ez_s
							else:
								step_target = _path_toward(current_sector, ez_s)

				elif squad.goal == Goal.EXTRACT:
					var ez = GameManager.extraction_zone
					if ez != "" and ez != current_sector:
						if ez in EnemyManager.adjacency.get(current_sector, []):
							step_target = ez
						else:
							step_target = _path_toward(current_sector, ez)
					elif ez == "":
						# No fixed extraction zone (eliminate_priority — M4)
						# — this squad is carrying the data with nowhere
						# scripted to run to, so instead of sitting idle it
						# actively seeks out the nearest sector that clears
						# TurnManager's carrier-safe-distance requirement
						# and heads straight there, no matter what it was
						# about to do otherwise (attack, advance, etc.).
						# Enemies can still catch it en route — this only
						# picks the destination, not a guaranteed-safe path.
						var safe_sector = EnemyManager.find_nearest_safe_sector(
							current_sector, TurnManager.DATA_CARRIER_SAFE_DISTANCE)
						if safe_sector != "" and safe_sector != current_sector:
							fleeing_with_data = true
							if safe_sector in EnemyManager.adjacency.get(current_sector, []):
								step_target = safe_sector
							else:
								step_target = _path_toward(current_sector, safe_sector)

				elif squad.goal == Goal.DEFEND_CARRIER:
					var carrier_name = GameManager.data_carrier_squad
					var carrier_sector = squads.get(carrier_name, {}).get("sector", "")
					if carrier_sector == "":
						break
					# If enemy is adjacent to carrier — path to intercept
					var enemies_near_carrier = false
					for n in EnemyManager.adjacency.get(carrier_sector, []):
						if EnemyManager.get_enemy_count_at(n) > 0:
							enemies_near_carrier = true
							if n in EnemyManager.adjacency.get(current_sector, []):
								step_target = n
								engaging_enemy = true
							break

					# No immediate threat to intercept — head for the
					# extraction zone directly instead of chasing the
					# carrier's live position. The carrier is heading there
					# too, so this keeps escorts making real progress toward
					# the objective every turn rather than perpetually
					# trailing a moving target, which produced a wandering,
					# indirect route to extraction for the whole group.
					if step_target == "":
						var ez = GameManager.extraction_zone
						var escort_dest = ez if ez != "" else carrier_sector
						if escort_dest != current_sector:
							if escort_dest in EnemyManager.adjacency.get(current_sector, []):
								step_target = escort_dest
							else:
								step_target = _path_toward(current_sector, escort_dest)

				# A goal override above may have swapped step_target to a
				# different tile than the one engaging_enemy was set for
				# (e.g. POWER_TOWER redirecting away from a found fight to
				# path toward the tower instead). Recompute against the
				# tile we're actually about to occupy so combat below only
				# triggers when there really is an enemy there.
				engaging_enemy = EnemyManager.get_enemy_count_at(step_target) > 0

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
					action = "retreating_with_data" if fleeing_with_data else "moved"
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
		Status.CRITICAL:
			squad.status = Status.LOST
			if squad.get("has_data", false):
				squad["has_data"] = false
				GameManager.data_destroyed = true
				GameManager.data_carrier_squad = ""
				AudioManager.play_alarm()
				emit_signal("data_destroyed_by_enemy", squad.name)


func _next_need(squad: Dictionary, last_action: String) -> int:
	if squad.status == Status.CRITICAL: return Need.MEDI_PACKS
	if squad.status == Status.WOUNDED:
		return Need.MEDI_PACKS if randf() > 0.4 else Need.ARMAMENTS
	match last_action:
		"moved":                         return Need.ARMAMENTS
		"retreating_with_data":          return Need.FUEL_CELLS  # fuel = 2-hex moves, covers ground faster
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
		"retreating_with_data":
			return prefix + "%s is falling back through %s with the data package, breaking contact with enemy forces." % [n, s]
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
		"holding_tower":
			return prefix + "%s is holding the comms tower at %s. Tower remains operational." % [n, s]
		"defend_carrier":
			return prefix + "%s is moving to protect the data carrier." % n
	return "%s — no report." % n

func _assign_goals() -> void:
	var tower_sector  = GameManager.tower_sector
	var mission_type  = GameManager.mission_type
	var tower_powered = GameManager.tower_powered
	var has_tower     = tower_sector != ""

	# ---- M5 EXTRACTION LOGIC ----
	if mission_type == "extract":
		var carrier_name   = GameManager.data_carrier_squad
		var carrier_sector = ""
		if squads.has(carrier_name):
			carrier_sector = squads[carrier_name].sector

		# Data hand-off between squads is disabled — whichever squad is
		# carrying stays the carrier for the rest of the mission, even if
		# wounded/critical. (Previously _try_pass_data() would hand the data
		# to the healthiest adjacent squad once the carrier was hurt.)

		var turns_left     = TurnManager.max_turns - TurnManager.current_turn
		var shuttle_inbound = turns_left <= TurnManager.SHUTTLE_ARRIVAL_WINDOW

		if not shuttle_inbound:
			# The extraction shuttle isn't down yet, so most of the squad
			# still fights the theatre normally — advancing, engaging
			# enemies, capturing ground. But the extraction zone itself
			# shouldn't be left to chance: the nearest squad(s) push to
			# reach it and dig in early, holding it clear for when the
			# shuttle does call in, rather than everyone only converging
			# on it in the last couple of turns. Mirrors the tower-mission
			# pattern of committing a couple of squads to the objective by
			# distance while the rest keep fighting.
			var ez_pre = GameManager.extraction_zone
			var zone_candidates: Array = []

			for squad_name in squads:
				var squad = squads[squad_name]
				if squad.status == Status.LOST:
					continue
				if squad_name == carrier_name:
					# Carrier stays flexible/fighting until the shuttle is
					# actually inbound — no point sitting it at the zone
					# early and advertising exactly where the data is.
					squad.goal = Goal.ADVANCE
					continue
				if ez_pre == "":
					squad.goal = Goal.ADVANCE
					continue
				zone_candidates.append({
					"name": squad_name,
					"dist": EnemyManager.get_distance_between(squad.sector, ez_pre),
				})

			if not zone_candidates.is_empty():
				zone_candidates.sort_custom(func(a, b): return a.dist < b.dist)
				var zone_slots = 2  # up to 2 squads pre-emptively secure the zone
				for i in range(zone_candidates.size()):
					var entry = zone_candidates[i]
					squads[entry.name].goal = Goal.SECURE_ZONE if i < zone_slots else Goal.ADVANCE

			return

		# Shuttle inbound — break off whatever fight is underway and
		# converge on the extraction zone with the remaining turns.

		# Check if carrier is under immediate threat
		var carrier_under_threat = false
		if carrier_sector != "":
			carrier_under_threat = EnemyManager.get_enemy_count_at(carrier_sector) > 0

		for squad_name in squads:
			var squad = squads[squad_name]
			if squad.status == Status.LOST:
				continue

			# Carrier always extracts
			if squad_name == carrier_name:
				squad.goal = Goal.EXTRACT
				continue

			# Check proximity to carrier
			var dist_to_carrier = 999
			if carrier_sector != "":
				dist_to_carrier = EnemyManager._bfs_distance(squad.sector, carrier_sector)

			# If carrier is threatened, nearest squad defends regardless of distance
			if carrier_under_threat and dist_to_carrier <= 3:
				squad.goal = Goal.DEFEND_CARRIER
				continue

			# Within 2 hexes of carrier — defend
			if dist_to_carrier <= 2:
				squad.goal = Goal.DEFEND_CARRIER
				continue

			# Everyone else heads to extraction
			squad.goal = Goal.EXTRACT

		return

	# ---- M4 CARRIER PROTECTION (post-Vreth) ----
	# The moment Vreth goes down, the mission stops being "hunt the
	# target" and becomes "get the carrier clear" — every enemy left
	# standing now knows exactly who's carrying the data and converges
	# on them. Nearby squads need to actively escort/shield the carrier
	# instead of falling back to tower duty, which stopped mattering the
	# instant the target fell. Mirrors the M5 DEFEND_CARRIER logic.
	if mission_type == "eliminate_priority" and not GameManager.priority_target_alive:
		var carrier_name   = GameManager.data_carrier_squad
		var carrier_sector = ""
		if squads.has(carrier_name):
			carrier_sector = squads[carrier_name].sector

		var carrier_under_threat = false
		if carrier_sector != "":
			carrier_under_threat = EnemyManager.get_enemy_count_at(carrier_sector) > 0

		for squad_name in squads:
			var squad = squads[squad_name]
			if squad.status == Status.LOST:
				continue

			# Carrier flees to the nearest sector clear of every enemy —
			# handled by the existing Goal.EXTRACT / ez=="" branch in
			# resolve_turn().
			if squad_name == carrier_name:
				squad.goal = Goal.EXTRACT
				continue

			var dist_to_carrier = 999
			if carrier_sector != "":
				dist_to_carrier = EnemyManager._bfs_distance(squad.sector, carrier_sector)

			# Carrier under direct attack — nearby squads break off
			# whatever else they were doing and come intercept.
			if carrier_under_threat and dist_to_carrier <= 3:
				squad.goal = Goal.DEFEND_CARRIER
				continue

			# Close enough to matter as an escort even without an
			# immediate threat — stick with the carrier.
			if dist_to_carrier <= 2:
				squad.goal = Goal.DEFEND_CARRIER
				continue

			# Too far to escort directly — keep fighting. Killing or
			# pushing back enemies anywhere on the map still helps clear
			# the distance the carrier needs from every remaining hostile.
			squad.goal = Goal.ADVANCE

		return

	# ---- ALL OTHER MISSIONS ----
	# Squads still needing a tower-relevant goal are collected here first,
	# then assigned in a second pass by DISTANCE TO THE TOWER — recomputed
	# fresh every turn. This means a reinforcement that drops in closer
	# than an already-assigned squad takes over tower duty from it (the
	# old version just kept whichever squad claimed it first, forever,
	# so close reinforcements would ignore the tower and wander off).
	var tower_missions = ["hold_tower", "eliminate_priority", "extract"]
	var tower_candidates: Array = []

	# Mission 4 has BOTH a priority target and a tower on the map. Without
	# this, a squad dropped near the tower could get swept into tower duty
	# purely by the distance sort below, with nobody ever actually sent
	# after the priority target. Guarantee the closest living, non-carrier
	# squad hunts the target first, every turn — only once that's
	# happening (a squad is confirmed near/targeting it) does the tower
	# even become an option for anyone else.
	var priority_hunter = ""
	if mission_type == "eliminate_priority" and GameManager.priority_target_alive:
		var pt_sector = EnemyManager.get_priority_target_sector()
		if pt_sector != "":
			var best_dist = 999999
			for squad_name in squads:
				var s = squads[squad_name]
				if s.status == Status.LOST or s.get("has_data", false):
					continue
				var d = EnemyManager.get_distance_between(s.sector, pt_sector)
				if d < best_dist:
					best_dist = d
					priority_hunter = squad_name
			if priority_hunter != "":
				squads[priority_hunter].goal = Goal.ATTACK_PRIORITY

	# True only if the target still needs a hunter and none could be
	# found (e.g. every squad is lost or carrying data) — blocks tower
	# duty in that edge case too, same rule either way.
	var target_needs_attention = (mission_type == "eliminate_priority"
		and GameManager.priority_target_alive and priority_hunter == "")

	for squad_name in squads:
		var squad = squads[squad_name]
		if squad.status == Status.LOST:
			continue

		if squad_name == priority_hunter:
			continue  # already committed to the priority target above

		if squad.get("has_data", false) and mission_type in ["eliminate_priority", "extract"]:
			squad.goal = Goal.EXTRACT
			continue

		if has_tower and mission_type in tower_missions and not target_needs_attention:
			tower_candidates.append({
				"name": squad_name,
				"dist": EnemyManager.get_distance_between(squad.sector, tower_sector),
			})
			continue

		# No tower relevant to this mission (or the target still needs a
		# hunter) — default advance / priority hunt
		squad.goal = Goal.ATTACK_PRIORITY if (mission_type == "eliminate_priority" and GameManager.priority_target_alive) else Goal.ADVANCE

	if tower_candidates.is_empty():
		return

	tower_candidates.sort_custom(func(a, b): return a.dist < b.dist)

	var tower_slots = 2  # up to 2 squads actively push for / hold the tower
	for i in range(tower_candidates.size()):
		var entry = tower_candidates[i]
		var squad = squads[entry.name]

		if i < tower_slots:
			if squad.sector == tower_sector:
				squad.goal = Goal.HOLD_TOWER if tower_powered else Goal.POWER_TOWER
			else:
				squad.goal = Goal.POWER_TOWER
		elif entry.dist <= DEFEND_TOWER_RADIUS:
			# Close enough to the tower to matter, but not needed to
			# power/hold it — dig in and fight off anything that
			# comes for it instead of wandering off to advance.
			squad.goal = Goal.DEFEND_TOWER
		else:
			squad.goal = Goal.ATTACK_PRIORITY if (mission_type == "eliminate_priority" and GameManager.priority_target_alive) else Goal.ADVANCE

# -------------------------------------------------------
# Default movement target when a squad has no adjacent enemy to
# fight/chase. Plain ADVANCE used to just grab whatever neighbour
# get_best_move_target() found first (fixed adjacency-list order,
# unrelated to the objective) — on tower missions this made squads
# wander far off course instead of converging on the fight. Now,
# on tower missions, an ADVANCE squad with nothing to fight heads
# generally toward the tower instead, while still stopping to fight
# anything it runs into on the way (that check happens before this
# is ever called). Squads already on tower duty (POWER_TOWER /
# HOLD_TOWER / DEFEND_TOWER) don't use this — their own goal-directed
# targeting further down takes over.
# -------------------------------------------------------
func _default_advance_target(squad: Dictionary, current_sector: String) -> String:
	var tower = GameManager.tower_sector
	if squad.goal == Goal.ADVANCE and tower != "" and tower != current_sector \
			and GameManager.mission_type in ["hold_tower", "eliminate_priority", "extract"]:
		var toward_tower = _route_target_toward_tower(current_sector, tower)
		if toward_tower != "":
			return toward_tower

	# Steer away from hexes a living ally already occupies (checked live,
	# so a squad resolving later this same turn sees where earlier squads
	# already moved) — spreads the group out instead of letting them
	# pile onto the same tile, which only captures one hex instead of
	# several. get_best_move_target() still allows stacking as a last
	# resort if there's genuinely nowhere else to go.
	var ally_sectors: Array = []
	for other_name in squads:
		if other_name == squad.name:
			continue
		var other = squads[other_name]
		if other.status != Status.LOST:
			ally_sectors.append(other.sector)

	return EnemyManager.get_best_move_target(current_sector, ally_sectors)

# -------------------------------------------------------
# Picks the next hex on the way to the tower. Raw shortest-path BFS
# sends squads on whatever route is fewest hexes for THEIR starting
# position, which can scatter them across totally different paths
# depending on which side of the map they land on (seen on Mission 3 —
# squads starting further north took a completely different route than
# the ones starting near the tower). A mission can set "route_waypoint"
# to a chokepoint sector; any squad still "behind" it gets routed
# through that hex first, so everyone funnels through the same
# corridor instead of free-roaming their own shortest path.
# -------------------------------------------------------
func _route_target_toward_tower(current_sector: String, tower: String) -> String:
	var waypoint = GameManager.get_current_mission_data().get("route_waypoint", "")
	if waypoint != "" and waypoint != current_sector and waypoint != tower:
		var dist_direct   = EnemyManager.get_distance_between(current_sector, tower)
		var dist_waypoint = EnemyManager.get_distance_between(waypoint, tower)
		# Still further from the tower than the waypoint is — route
		# through it first. Once a squad is at-or-inside that distance
		# (i.e. it has effectively passed the waypoint), fall through
		# to heading straight for the tower instead.
		if dist_direct > dist_waypoint:
			if waypoint in EnemyManager.adjacency.get(current_sector, []):
				return waypoint
			return _path_toward(current_sector, waypoint)

	if tower in EnemyManager.adjacency.get(current_sector, []):
		return tower
	return _path_toward(current_sector, tower)

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
