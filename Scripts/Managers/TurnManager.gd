extends Node
# =============================================================
# TurnManager.gd  —  AutoLoad singleton
# =============================================================

signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal allocations_locked
signal mission_complete(report: Dictionary)
signal mission_failed(reason: String)
signal enemy_reinforcements_incoming(turn: int, count: int)
signal enemy_reinforcements_landed(sectors: Array)
signal orbital_strike_resolved(report: Dictionary)

var current_turn: int = 0
var max_turns: int = 0
var win_condition_hexes: int = 5
var allocations_are_locked: bool = false
var pending_allocations: Dictionary = {}
var mission_over: bool = false
var reinforcement_schedule: Dictionary = {}

# Mission 5 ("extract"): the extraction shuttle isn't sitting on the ground
# waiting from turn 1 — squads fight the theatre normally around the
# extraction zone until the shuttle actually arrives. Once this many turns
# remain before the mission's turn limit runs out, the shuttle is inbound
# and every squad breaks off to converge on the extraction zone and board.
const SHUTTLE_ARRIVAL_WINDOW: int = 2

func _ready() -> void:
	EnemyManager.priority_target_eliminated.connect(SquadManager._on_priority_target_eliminated)


func start_mission(mission_data: Dictionary) -> void:
	current_turn = 0
	max_turns = mission_data.get("turns", 5)
	win_condition_hexes = mission_data.get("win_hexes", 5)
	allocations_are_locked = false
	pending_allocations = {}
	mission_over = false
	reinforcement_schedule = mission_data.get("reinforcement_schedule", {})

	var squad_list   = mission_data.get("squads", [])
	var interference = mission_data.get("interference", 0.0)
	var enemy_list   = mission_data.get("enemies", [])
	var sectors      = mission_data.get("sectors", [])
	var adj          = mission_data.get("adjacency", {})

	var rally_candidates = find_rally_candidates(squad_list, enemy_list, sectors, adj)
	SquadManager.init_squads(squad_list, interference, rally_candidates)

	if not SquadManager.squad_lost.is_connected(_on_squad_lost):
		SquadManager.squad_lost.connect(_on_squad_lost)

	# Build squad starting sectors including carry-over squads
	var squad_sectors = []
	for squad in SquadManager.get_squads_for_ui():
		if not squad_sectors.has(squad.sector):
			squad_sectors.append(squad.sector)

	EnemyManager.init_enemies(squad_sectors, enemy_list, sectors, adj)

	if mission_data.get("mission_type", "") == "extract":
		_assign_extraction_zone()

	# Warn about first reinforcement wave if scheduled
	_check_reinforcement_warning(0)

	emit_signal("turn_started", current_turn)


# -------------------------------------------------------
# Finds distinct hexes near the squad landing zone where carried-over
# reinforcement squads (called in during a previous mission) can start
# this mission — one hex each, rather than all stacking onto the main
# force's tile. Works from the mission's raw index-based adjacency
# since EnemyManager hasn't built its name-based copy yet at this point
# in mission setup (init_enemies runs after this, once squad_sectors —
# which depends on squad placement — is known).
#
# Public (not just used internally): CommandCentre's mission briefing
# calls this too, to preview where carried-over reinforcement squads will
# land before the mission actually starts and assigns them for real.
# -------------------------------------------------------
func find_rally_candidates(squad_list: Array, enemy_list: Array, sectors: Array, adj: Dictionary) -> Array:
	if squad_list.is_empty() or sectors.is_empty():
		return []

	var name_to_idx: Dictionary = {}
	for i in range(sectors.size()):
		name_to_idx[sectors[i]] = i

	var occupied: Dictionary = {}
	for s in squad_list:
		occupied[s.sector] = true
	for e in enemy_list:
		occupied[e.get("sector", "")] = true

	var start_name = squad_list[0].sector
	if not name_to_idx.has(start_name):
		return []
	var start_idx = name_to_idx[start_name]

	var visited: Dictionary = { start_idx: true }
	var to_visit: Array = [start_idx]
	var candidates: Array = []
	var max_needed = GameManager.REINFORCEMENT_NAMES.size()

	while not to_visit.is_empty() and candidates.size() < max_needed:
		var cur = to_visit.pop_front()
		for n_idx in adj.get(cur, []):
			if visited.has(n_idx):
				continue
			visited[n_idx] = true
			to_visit.append(n_idx)
			if n_idx < sectors.size():
				var n_name = sectors[n_idx]
				if not occupied.has(n_name):
					candidates.append(n_name)

	return candidates

func _assign_extraction_zone() -> void:
	var mission_data = GameManager.get_current_mission_data()
	var fixed = mission_data.get("extraction_sector", "")
	if fixed != "":
		GameManager.extraction_zone = fixed
		print("Extraction zone fixed: %s" % fixed)
		return

	# Fallback dynamic assignment for future missions
	var squad_sectors = []
	for squad in SquadManager.get_squads_for_ui():
		squad_sectors.append(squad.sector)
	var enemy_sectors = []
	for sector in EnemyManager.get_hex_control():
		if EnemyManager.get_hex_control()[sector] == "enemy":
			enemy_sectors.append(sector)
	var best_sector = ""
	var best_score = -1
	for sector in EnemyManager.get_all_sectors():
		if sector in squad_sectors:
			continue
		var dist = EnemyManager._bfs_distance_to_nearest(sector, enemy_sectors)
		if dist > best_score:
			best_score = dist
			best_sector = sector
	GameManager.extraction_zone = best_sector
	print("Extraction zone dynamic: %s" % best_sector)

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

	# Snapshot who's carrying the data before combat resolves this turn.
	# _check_carrier_overrun below needs to know whether THIS turn's
	# combat actually killed them — but a kill clears
	# GameManager.data_carrier_squad as part of resolving the casualty
	# (see SquadManager._worsen_status), so by the time combat is done
	# the name would already be gone if we read it fresh.
	var carrier_before = GameManager.data_carrier_squad

	# Squads act
	SquadManager.resolve_turn(pending_allocations)

	# Spawn enemy reinforcements for this turn if scheduled
	var spawned_sectors = _process_reinforcement_schedule()

	# Enemies advance
	EnemyManager.advance_enemies(pending_allocations)

	# If the enemy has retaken the tower sector this turn, it loses power
	# immediately — being powered was permanent before, with nothing
	# checking who actually controls the tile afterward.
	GameManager.check_tower_still_held()

	# If the data carrier was actually killed this turn, the package
	# doesn't survive contact — this is an immediate, hard mission failure
	# rather than the tile just quietly flipping to enemy control like any
	# other sector. This used to fire the moment an enemy merely reached
	# the carrier's tile, even if the carrier was armed and won the fight
	# (or unarmed and fled) — now it only fires on an actual kill, same as
	# any other squad: armed squads fight back, unarmed squads run, and
	# only being worn all the way down to "Lost" counts.
	_check_carrier_overrun(carrier_before)
	if mission_over:
		return


	# Mid-turn win check for eliminate-type missions
	var mission_type = GameManager.mission_type
	if mission_type == "eliminate" and not EnemyManager.is_any_enemy_alive():
		_end_mission(true, "")
		return
	if mission_type == "eliminate_priority" and not GameManager.priority_target_alive and _tower_secured():
		_end_mission(true, "")
		return

	# Resolve any armed orbital strike
	var bombardment_report = _process_bombardment()
	if not bombardment_report.is_empty():
		AudioManager.play_cannon_fire()
		emit_signal("orbital_strike_resolved", bombardment_report)

	# Notify Intel Console of where reinforcements landed
	if spawned_sectors.size() > 0:
		AudioManager.play_alarm()
		emit_signal("enemy_reinforcements_landed", spawned_sectors)
	

	allocations_are_locked = false
	pending_allocations = {}
	
	emit_signal("turn_ended", current_turn)

	# Loss check: all squads lost
	var all_lost = true
	for squad_name in SquadManager.squads:
		if SquadManager.squads[squad_name].status != SquadManager.Status.LOST:
			all_lost = false
			break

	if all_lost:
		_end_mission(false, "All squads have been lost. No signal from the surface.")
		return

	# Turn limit reached
	if max_turns > 0 and current_turn >= max_turns:
		_check_win_condition()
		return

	# Warn about upcoming reinforcements next turn
	_check_reinforcement_warning(current_turn)

	emit_signal("turn_started", current_turn)


# -------------------------------------------------------
# Spawn reinforcements scheduled for current_turn
# Returns list of sectors where enemies spawned
# -------------------------------------------------------
func _process_reinforcement_schedule() -> Array:
	if not reinforcement_schedule.has(current_turn):
		return []

	var count = reinforcement_schedule[current_turn]
	if count <= 0:
		return []

	var squad_sectors = []
	for squad in SquadManager.get_squads_for_ui():
		if squad.status != SquadManager.Status.LOST:
			squad_sectors.append(squad.sector)

	return EnemyManager.spawn_reinforcements(count, squad_sectors)


# -------------------------------------------------------
# Check if next turn has a reinforcement wave
# and emit a warning signal for Intel Console
# -------------------------------------------------------
func _check_reinforcement_warning(after_turn: int) -> void:
	var next_turn = after_turn + 1
	if reinforcement_schedule.has(next_turn):
		var count = reinforcement_schedule[next_turn]
		AudioManager.play_alarm()
		emit_signal("enemy_reinforcements_incoming", next_turn, count)


func _check_win_condition() -> void:
	var mission_type = GameManager.mission_type

	match mission_type:
		"capture":
			_check_capture_win()
		"eliminate":
			_check_eliminate_win()
		"hold_tower":
			_check_hold_tower_win()
		"eliminate_priority":
			_check_eliminate_priority_win()
		"extract":
			_check_extract_win()
		_:
			_check_capture_win()  # fallback


func _check_capture_win() -> void:
	var held = EnemyManager.get_held_count()
	var won  = held >= win_condition_hexes
	if won:
		_end_mission(true, "")
	else:
		_end_mission(false,
			"Insufficient territory held. Required %d sectors, held %d." % [win_condition_hexes, held])


func _check_eliminate_win() -> void:
	var enemies_remain = EnemyManager.is_any_enemy_alive()
	if not enemies_remain:
		_end_mission(true, "")
	else:
		var count = EnemyManager.get_total_enemy_count()
		_end_mission(false,
			"Enemy forces not fully eliminated. %d units remain in the field." % count)


func _check_hold_tower_win() -> void:
	var tower = GameManager.tower_sector
	if tower == "":
		_end_mission(false, "Comms tower location unknown — mission failed.")
		return

	var tower_powered = GameManager.tower_powered
	var squad_holds_tower = false
	for squad in SquadManager.get_squads_for_ui():
		if squad.sector == tower and squad.status != SquadManager.Status.LOST:
			squad_holds_tower = true
			break

	if tower_powered and squad_holds_tower:
		_end_mission(true, "")
	elif not tower_powered:
		_end_mission(false,
			"Comms tower was never activated. Fuel Cells required to power it.")
	else:
		_end_mission(false,
			"Comms tower lost — enemy forces recaptured the position.")


func _check_eliminate_priority_win() -> void:
	if GameManager.priority_target_alive:
		_end_mission(false,
			"Priority target '%s' was not eliminated. Mission failed." % GameManager.priority_target_name)
	elif _tower_secured():
		_end_mission(true, "")
	elif GameManager.data_destroyed:
		_end_mission(false,
			"%s was eliminated, but the data carrier was lost in the field. The intel did not survive." % GameManager.priority_target_name)
	else:
		_end_mission(false,
			"%s was eliminated, but the relay tower was never taken and powered. Command couldn't pinpoint an extraction zone." % GameManager.priority_target_name)


# Instant fail: the data carrier was actually killed this turn — not
# merely standing on a tile an enemy reached. Squads take real hits
# before going down (see SquadManager._worsen_status), and an unarmed
# squad now tries to flee rather than just standing there when an enemy
# lands on its tile (see EnemyManager.advance_enemies), so this only
# fires on a genuine kill. `carrier_name` is who was carrying the data
# BEFORE this turn's combat ran (see end_turn) — a kill clears
# GameManager.data_carrier_squad, so checking the live value here would
# always read back empty and this would never fire. This only applies to
# missions where a data carrier can exist at all (eliminate_priority,
# extract) — everything else no-ops.
func _check_carrier_overrun(carrier_name: String) -> void:
	if GameManager.mission_type not in ["eliminate_priority", "extract"]:
		return
	if carrier_name == "" or not SquadManager.squads.has(carrier_name):
		return
	var carrier = SquadManager.squads[carrier_name]
	if carrier.status != SquadManager.Status.LOST:
		return
	_end_mission(false,
		"%s was overrun at %s — enemy forces were too much and the carrier was lost. The intel did not survive contact." % [carrier_name, carrier.sector])


# True once the comms tower is both powered AND currently held by a living
# squad — the same requirement Mission 3's hold_tower win uses. Mission 4
# now reuses this too: taking and powering the tower is what lets Command
# pinpoint the extraction zone for the campaign to continue into Mission 5,
# replacing the old "get the carrier clear of every enemy" requirement.
func _tower_secured() -> bool:
	var tower = GameManager.tower_sector
	if tower == "" or not GameManager.tower_powered:
		return false
	for squad in SquadManager.get_squads_for_ui():
		if squad.sector == tower and squad.status != SquadManager.Status.LOST:
			return true
	return false


func _check_extract_win() -> void:
	# Count squads at extraction zone
	var ez = GameManager.extraction_zone
	var extracted = 0
	var data_extracted = false

	for squad in SquadManager.get_squads_for_ui():
		if squad.status == SquadManager.Status.LOST:
			continue
		if squad.sector == ez:
			extracted += 1
			if squad.get("has_data", false):
				data_extracted = true

	if extracted == 0:
		_end_mission(false, "No squads reached the extraction zone in time.")
		return

	if not data_extracted:
		# Still wins but with a note — data squad didn't make it
		_end_mission(true, "")  # won but score will reflect missing data
	else:
		_end_mission(true, "")


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

	var extraction_bonus = 0
	var extracted_count = 0
	var data_extracted = false
	if GameManager.mission_type == "extract":
		var eb = GameManager.calculate_extraction_bonus()
		extraction_bonus = eb.bonus
		extracted_count  = eb.extracted_count
		data_extracted   = eb.data_extracted

	var score = GameManager.calculate_score(held, current_turn, win_condition_hexes, won)
	var final_score = score.total + extraction_bonus

	# Surface what actually happened to the data package at the end of any
	# mission where recovering it mattered — this used to be invisible
	# outside of a one-off in-mission notification, which made it easy to
	# miss that the intel was lost (e.g. destroyed by an orbital strike,
	# or previously: silently dropped if the priority target was killed by
	# a reinforcement hot-drop instead of a normal squad kill).
	var data_status = ""
	if GameManager.mission_type in ["eliminate_priority", "extract"]:
		if GameManager.data_destroyed:
			data_status = "destroyed"
		elif GameManager.data_carrier_squad != "" and SquadManager.squads.has(GameManager.data_carrier_squad) \
				and SquadManager.squads[GameManager.data_carrier_squad].get("has_data", false):
			data_status = "secured"
		elif GameManager.priority_target_alive:
			data_status = "at_large"
		else:
			data_status = "unaccounted"

	var report = {
		"won":            won,
		"reason":         reason,
		"held_hexes":     held,
		"required_hexes": win_condition_hexes,
		"squads_alive":   squads_alive,
		"squads_lost":    squads_lost,
		"turns":          current_turn,
		"score":          score.total,
		"rating":         score.rating,
		"tile_score":     score.tile_score,
		"turn_bonus":     score.turn_bonus,
		"supply_bonus":   score.supply_bonus,
		"supply_pool":    GameManager.get_supply_pool().duplicate(),
		"reinforcements": GameManager.get_reinforcement_pool(),
		"extraction_bonus":  extraction_bonus,
		"extracted_count":   extracted_count,
		"data_extracted":    data_extracted,
		"data_status":       data_status,
		"data_carrier":      GameManager.data_carrier_squad,
	}

	GameManager.campaign_record.append({
		"mission": GameManager.current_mission,
		"won":     won,
		"score":   score.total,
		"rating":  score.rating,
	})

	if won:
		emit_signal("mission_complete", report)
	else:
		emit_signal("mission_failed", reason)
	emit_signal("mission_complete", report)


func _on_squad_lost(squad_name: String) -> void:
	print("TurnManager: %s has been lost." % squad_name)

func _process_bombardment() -> Dictionary:
	if not GameManager.has_armed_bombardment():
		return {}

	var drop   = GameManager.get_pending_bombardment()
	var sector = drop.get("sector", "")
	GameManager.clear_pending_bombardment()
	if sector == "":
		return {}

	var result      = EnemyManager.resolve_bombardment(sector)
	var affected    = result.get("affected", [])
	var killed      = result.get("enemies_killed", 0)
	var squads_hit  = []

	for squad in SquadManager.get_squads_for_ui():
		if squad.sector in affected and squad.status != SquadManager.Status.LOST:
			SquadManager.apply_bombardment_casualty(squad.name)
			squads_hit.append(squad.name)

	return {
		"center":         sector,
		"affected":       affected,
		"enemies_killed": killed,
		"squads_hit":     squads_hit,
		"turn":           current_turn,
	}
