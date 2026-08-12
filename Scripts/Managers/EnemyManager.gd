extends Node
# =============================================================
# EnemyManager.gd  —  AutoLoad singleton
# =============================================================

signal enemies_updated
signal reinforcement_landed(squad_name: String, sector: String, surprise: bool)
signal priority_target_eliminated(squad_name: String, sector: String)
signal data_destroyed_by_strike(sector: String)

var hex_control: Dictionary = {}
var enemy_units: Array = []
var all_sectors: Array = []
var adjacency: Dictionary = {}
var priority_target_home: String = ""

# Snapshot of hex_control taken before a turn's squads start moving. Squads
# resolve one at a time within the same turn, and each capture_tile() call
# mutates the live hex_control immediately — without this snapshot, a squad
# that moves later in the turn would see an ally's just-captured tile as
# "already ours" and skip past it as a move target, even when it was the
# obvious next step forward. Movement scoring reads from this frozen
# snapshot instead, so every squad picks its target as if nobody else had
# moved yet this turn.
var hex_control_turn_start: Dictionary = {}

func snapshot_hex_control() -> void:
	hex_control_turn_start = hex_control.duplicate()

# -------------------------------------------------------
# Init — now receives sectors and adjacency from mission data
# -------------------------------------------------------
func init_enemies(squad_sectors: Array, enemy_list: Array, mission_sectors: Array, mission_adjacency: Dictionary) -> void:
	all_sectors = mission_sectors.duplicate()
	_build_adjacency(mission_adjacency)

	hex_control.clear()
	for sector in all_sectors:
		hex_control[sector] = "enemy"
	for sector in squad_sectors:
		hex_control[sector] = "held"

	enemy_units.clear()
	priority_target_home = ""
	var id = 0
	for e in enemy_list:
		var unit = {
			"id":          id,
			"sector":      e.get("sector", all_sectors[all_sectors.size() - 1]),
			"hp":          1,
			"cooldown":    0,
			"is_priority": e.get("is_priority", false),
		}
		if unit.is_priority:
			priority_target_home = unit.sector
		enemy_units.append(unit)
		id += 1

	emit_signal("enemies_updated")


# -------------------------------------------------------
# Spawn enemy reinforcements at the sectors furthest
# from any squad — called by TurnManager on schedule
# -------------------------------------------------------
func spawn_reinforcements(count: int, squad_sectors: Array) -> Array:
	var spawned_sectors = []

	# Score every sector by BFS distance from nearest squad
	var candidates = []
	for sector in all_sectors:
		# Don't spawn on a squad tile or already enemy-occupied
		if sector in squad_sectors:
			continue
		var dist = _bfs_distance_to_nearest(sector, squad_sectors)
		candidates.append({ "sector": sector, "dist": dist })

	# Sort by distance descending — furthest first
	candidates.sort_custom(func(a, b): return a.dist > b.dist)

	var spawned = 0
	for candidate in candidates:
		if spawned >= count:
			break
		var sector = candidate.sector
		# Don't stack on existing enemy
		if _has_enemy_unit(sector):
			continue
		var new_id = _next_id()
		enemy_units.append({
			"id":       new_id,
			"sector":   sector,
			"hp":       1,
			"cooldown": 0,
		})
		spawned_sectors.append(sector)
		spawned += 1

	emit_signal("enemies_updated")
	return spawned_sectors


func _next_id() -> int:
	var max_id = -1
	for unit in enemy_units:
		if unit.id > max_id:
			max_id = unit.id
	return max_id + 1


# -------------------------------------------------------
# Armed fight — always kills enemy instantly
# -------------------------------------------------------
func fight_at(sector: String, squad_name: String) -> bool:
	var enemies_here = _get_enemies_at(sector)
	if enemies_here.is_empty():
		return false

	var priority_killed = false
	for unit in enemies_here.duplicate():
		if unit.get("is_priority", false):
			priority_killed = true
		enemy_units.erase(unit)

	hex_control[sector] = "held"

	if priority_killed:
		GameManager.priority_target_alive = false
		GameManager.data_carrier_squad = squad_name
		emit_signal("priority_target_eliminated", squad_name, sector)

	emit_signal("enemies_updated")
	return true


# -------------------------------------------------------
# Unarmed fight — 60/40 in squad's favour
# -------------------------------------------------------
func fight_at_unarmed(sector: String) -> Dictionary:
	var enemies_here = _get_enemies_at(sector)
	if enemies_here.is_empty():
		return { "squad_won": false, "enemies_present": false }

	var squad_won = randf() > 0.4

	if squad_won:
		for unit in enemies_here:
			var pushed = _push_enemy_back(unit, sector)
			if pushed != "":
				unit.sector = pushed
			unit.cooldown = 2
		hex_control[sector] = "held"

	emit_signal("enemies_updated")
	return { "squad_won": squad_won, "enemies_present": true }


func get_best_move_target(from_sector: String) -> String:
	var neighbors = adjacency.get(from_sector, [])
	if neighbors.is_empty():
		return ""

	# Prefer unclaimed enemy territory with no enemy unit actually
	# camped on it — genuine forward progress. Checked against the
	# turn-start snapshot (see hex_control_turn_start above), not the
	# live map, so a squad that moves later in this same turn isn't
	# steered away from a tile just because an ally captured it a
	# moment ago in this same turn's resolution.
	for n in neighbors:
		if not _has_enemy_unit(n) and hex_control_turn_start.get(n, "") == "enemy":
			return n

	# Any tile without an enemy unit standing on it — this deliberately
	# includes a hex already held by one of OUR OWN other squads.
	# Squads are allowed to share a tile (a trailing squad following
	# another through a single-file corridor, a reinforcement landing
	# alongside the main force, etc.), so a friendly-occupied hex must
	# never be treated as a dead end here — that was leaving a squad
	# with nowhere to go if the only way forward ran through an ally.
	for n in neighbors:
		if not _has_enemy_unit(n):
			return n

	# Genuinely boxed in by enemies on every side — still hand back a
	# hex rather than leaving the squad with no target at all; combat
	# resolution takes it from there.
	return neighbors[0]


func get_best_attack_target(from_sector: String) -> String:
	var neighbors = adjacency.get(from_sector, [])
	for n in neighbors:
		if _has_enemy_unit(n):
			return n
	return ""


func get_best_move_into_enemy(from_sector: String) -> String:
	var neighbors = adjacency.get(from_sector, [])
	for n in neighbors:
		if _has_enemy_unit(n):
			return n
	return ""


func capture_tile(sector: String) -> void:
	hex_control[sector] = "held"
	emit_signal("enemies_updated")


# -------------------------------------------------------
# Called by TurnManager after squad resolution
# -------------------------------------------------------
func advance_enemies(allocations: Dictionary) -> void:
	var squad_map: Dictionary = {}
	for squad in SquadManager.get_squads_for_ui():
		if squad.status != SquadManager.Status.LOST:
			squad_map[squad.sector] = squad.name

	var squad_sectors = squad_map.keys()

	if squad_sectors.is_empty():
		return

	# Tick down cooldowns
	for unit in enemy_units:
		if unit.cooldown > 0:
			unit.cooldown -= 1

	var units_copy = enemy_units.duplicate()
	units_copy.shuffle()

	for unit in units_copy:
		if not enemy_units.has(unit):
			continue

		var use_priority_scoring = unit.get("is_priority", false)
		var ai_mode = GameManager.enemy_ai_mode

		var best = unit.sector
		var best_score = _get_movement_score(unit.sector, squad_sectors, unit.id, use_priority_scoring, ai_mode)

		var candidates = adjacency.get(unit.sector, []).duplicate()
		candidates.shuffle()

		for n in candidates:
			if _has_enemy_unit_excluding(n, unit.id):
				continue
			if unit.cooldown > 0:
				var control = hex_control.get(n, "enemy")
				if control == "held" or control == "contested" or n in squad_sectors:
					continue
			var score = _get_movement_score(n, squad_sectors, unit.id, use_priority_scoring, ai_mode)
			if score > best_score:
				best_score = score
				best = n

		unit.sector = best

	# Post-movement: enemy on armed squad tile or surprise bonus tile
	for unit in enemy_units.duplicate():
		var landed_on = unit.sector
		if landed_on in squad_map:
			var squad_name = squad_map[landed_on]
			var squad_data = SquadManager.squads.get(squad_name, {})
			var alloc      = allocations.get(squad_name, {})
			var has_arms   = alloc.get("Armaments", 0) > 0
			var has_surprise = squad_data.get("surprise_bonus", false)
			if has_arms or has_surprise:
				enemy_units.erase(unit)
				hex_control[landed_on] = "held"

	# Process pending player reinforcement drop
	if GameManager.has_pending_reinforcement():
		var drop = GameManager.get_pending_reinforcement()
		var target_sector = drop.get("sector", "")
		var squad_name    = drop.get("squad_name", "")
		if target_sector != "" and squad_name != "":
			var surprise = _has_enemy_unit(target_sector)
			SquadManager.add_squad(squad_name, target_sector, surprise)
			if surprise:
				for unit in enemy_units.duplicate():
					if unit.sector == target_sector:
						enemy_units.erase(unit)
			hex_control[target_sector] = "held"
			emit_signal("reinforcement_landed", squad_name, target_sector, surprise)
		GameManager.clear_pending_reinforcement()
	
	
	
	_rebuild_hex_control(squad_sectors)
	emit_signal("enemies_updated")



# -------------------------------------------------------
# Movement scoring
# -------------------------------------------------------
func _movement_score(sector: String, squad_sectors: Array, unit_id: int) -> int:
	var score = 0

	var dist = _bfs_distance_to_nearest(sector, squad_sectors)
	score += (10 - min(dist, 10)) * 20

	var control = hex_control.get(sector, "enemy")
	if control == "held":
		score += 20
	elif control == "contested":
		score += 20

	var nearby_enemies = 0
	for n in adjacency.get(sector, []):
		for unit in enemy_units:
			if unit.id != unit_id and unit.sector == n:
				nearby_enemies += 1
	score -= nearby_enemies * 15

	var adj_squad_tiles = 0
	for n in adjacency.get(sector, []):
		if n in squad_sectors:
			adj_squad_tiles += 1
	score += adj_squad_tiles * 10

	return score

func _get_movement_score(sector: String, squad_sectors: Array, unit_id: int, is_priority: bool, ai_mode: String) -> int:
	if is_priority:
		return _priority_movement_score(sector, squad_sectors, unit_id)
	match ai_mode:
		"aggressive":
			return _movement_score(sector, squad_sectors, unit_id)
		"wave":
			return _wave_movement_score(sector, squad_sectors, unit_id)
		"defensive":
			return _defensive_movement_score(sector, squad_sectors, unit_id)
		"rush_extraction":
			return _rush_extraction_score(sector, squad_sectors, unit_id)
	return _movement_score(sector, squad_sectors, unit_id)

func _priority_movement_score(sector: String, squad_sectors: Array, unit_id: int) -> int:
	var score = 0

	# Strongly prefer staying near home sector
	if priority_target_home != "":
		var dist_from_home = _bfs_distance(sector, priority_target_home)
		score -= dist_from_home * 30  # heavy penalty for straying far

	# Mild preference for enemy-controlled territory
	var control = hex_control.get(sector, "enemy")
	if control == "enemy":
		score += 10
	elif control == "held" or control == "contested":
		score -= 20  # avoid player-held tiles unless cornered

	# Don't crowd other units
	var nearby_enemies = 0
	for n in adjacency.get(sector, []):
		for unit in enemy_units:
			if unit.id != unit_id and unit.sector == n:
				nearby_enemies += 1
	score -= nearby_enemies * 10

	# Slight awareness of squads — backs away rather than charging
	var dist_to_nearest_squad = _bfs_distance_to_nearest(sector, squad_sectors)
	score += min(dist_to_nearest_squad, 5) * 8  # prefers distance from squads

	return score


# -------------------------------------------------------
# Push helpers
# -------------------------------------------------------
func _push_enemy_deep(unit: Dictionary, away_from: String) -> String:
	var first_ring = []
	for n in adjacency.get(unit.sector, []):
		if n == away_from:
			continue
		if _has_enemy_unit_excluding(n, unit.id):
			continue
		first_ring.append(n)

	var best_deep = ""
	var best_dist = -1
	for mid in first_ring:
		for n2 in adjacency.get(mid, []):
			if n2 == away_from or n2 == unit.sector:
				continue
			if _has_enemy_unit_excluding(n2, unit.id):
				continue
			var d = _bfs_distance_to_nearest(n2, [away_from])
			if d > best_dist:
				best_dist = d
				best_deep = n2

	if best_deep != "":
		return best_deep
	return _push_enemy_back(unit, away_from)


func _push_enemy_back(unit: Dictionary, away_from: String) -> String:
	var best = ""
	var best_dist = -1
	for n in adjacency.get(unit.sector, []):
		if n == away_from:
			continue
		if _has_enemy_unit_excluding(n, unit.id):
			continue
		var d = _bfs_distance_to_nearest(n, [away_from])
		if d > best_dist:
			best_dist = d
			best = n
	return best


# -------------------------------------------------------
# Rebuild hex_control
# -------------------------------------------------------
func _rebuild_hex_control(squad_sectors: Array) -> void:
	var enemy_sectors = []
	for unit in enemy_units:
		if not enemy_sectors.has(unit.sector):
			enemy_sectors.append(unit.sector)

	for sector in all_sectors:
		var has_squad = sector in squad_sectors
		var has_enemy = sector in enemy_sectors
		var current   = hex_control.get(sector, "enemy")

		if has_squad and has_enemy:
			hex_control[sector] = "contested"
		elif has_squad:
			hex_control[sector] = "held"
		elif has_enemy:
			hex_control[sector] = "enemy"
		else:
			if current == "contested":
				hex_control[sector] = "enemy"


func get_hex_control() -> Dictionary:
	return hex_control


func get_held_count() -> int:
	var count = 0
	for sector in hex_control:
		if hex_control[sector] == "held":
			count += 1
	return count


func get_enemy_count_at(sector: String) -> int:
	var count = 0
	for unit in enemy_units:
		if unit.sector == sector:
			count += 1
	return count


func get_all_sectors() -> Array:
	return all_sectors


# -------------------------------------------------------
# Helpers
# -------------------------------------------------------
func _get_enemies_at(sector: String) -> Array:
	var result = []
	for unit in enemy_units:
		if unit.sector == sector:
			result.append(unit)
	return result


func _has_enemy_unit(sector: String) -> bool:
	for unit in enemy_units:
		if unit.sector == sector:
			return true
	return false


func _has_enemy_unit_excluding(sector: String, exclude_id: int) -> bool:
	for unit in enemy_units:
		if unit.sector == sector and unit.id != exclude_id:
			return true
	return false


func _bfs_distance_to_nearest(from: String, targets: Array) -> int:
	var min_dist = 999
	for target in targets:
		var d = _bfs_distance(from, target)
		if d < min_dist:
			min_dist = d
	return min_dist

# In EnemyManager.gd
func get_distance_between(from: String, to: String) -> int:
	return _bfs_distance(from, to)

func _bfs_distance(start: String, end_sector: String) -> int:
	if start == end_sector:
		return 0
	var visited = { start: true }
	var queue = [[start, 0]]
	while queue.size() > 0:
		var current = queue.pop_front()
		var node = current[0]
		var dist = current[1]
		for neighbor in adjacency.get(node, []):
			if neighbor == end_sector:
				return dist + 1
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append([neighbor, dist + 1])
	return 999

func resolve_bombardment(center: String) -> Dictionary:
	var affected = [center]
	for n in adjacency.get(center, []):
		affected.append(n)

	var killed = 0
	var priority_killed = false
	for sector in affected:
		var enemies_here = _get_enemies_at(sector)
		killed += enemies_here.size()
		for unit in enemies_here.duplicate():
			if unit.get("is_priority", false):
				priority_killed = true
			enemy_units.erase(unit)
		hex_control[sector] = "neutral"

	if priority_killed:
		GameManager.priority_target_alive = false
		# Deliberately no data_carrier_squad set — orbital strike destroys the data
		GameManager.data_destroyed = true
		emit_signal("priority_target_eliminated", "", center)
		emit_signal("data_destroyed_by_strike", center)

	emit_signal("enemies_updated")
	return {
		"affected":        affected,
		"enemies_killed":  killed,
		"priority_killed": priority_killed,
	}

func _build_adjacency(mission_adjacency: Dictionary) -> void:
	adjacency.clear()
	for idx in mission_adjacency:
		if idx < all_sectors.size():
			var sector = all_sectors[idx]
			var neighbors = []
			for n_idx in mission_adjacency[idx]:
				if n_idx < all_sectors.size():
					neighbors.append(all_sectors[n_idx])
			adjacency[sector] = neighbors

func get_priority_target_sector() -> String:
	for unit in enemy_units:
		if unit.get("is_priority", false):
			return unit.sector
	return ""

func is_priority_target_alive() -> bool:
	for unit in enemy_units:
		if unit.get("is_priority", false):
			return true
	return false

func is_any_enemy_alive() -> bool:
	return enemy_units.size() > 0

func get_total_enemy_count() -> int:
	return enemy_units.size()

func _defensive_movement_score(sector: String, squad_sectors: Array, unit_id: int) -> int:
	var score = 0

	# Strongly prefer staying near tower or priority target home
	var anchor = GameManager.tower_sector
	if anchor == "" and GameManager.priority_target_home != "":
		anchor = priority_target_home
	if anchor != "":
		var dist_from_anchor = _bfs_distance(sector, anchor)
		score -= dist_from_anchor * 25

	# Prefer enemy-controlled tiles
	var control = hex_control.get(sector, "enemy")
	if control == "enemy":
		score += 15
	elif control == "held":
		score -= 30
	elif control == "contested":
		score += 5

	# Avoid crowding
	var nearby_enemies = 0
	for n in adjacency.get(sector, []):
		for unit in enemy_units:
			if unit.id != unit_id and unit.sector == n:
				nearby_enemies += 1
	score -= nearby_enemies * 10

	# Keep some distance from squads — don't rush in
	var dist_to_squad = _bfs_distance_to_nearest(sector, squad_sectors)
	score += min(dist_to_squad, 3) * 5

	return score


func _wave_movement_score(sector: String, squad_sectors: Array, unit_id: int) -> int:
	var score = 0

	# Aggressively chase squads — even more than default
	var dist = _bfs_distance_to_nearest(sector, squad_sectors)
	score += (10 - min(dist, 10)) * 30

	# Strong preference for held tiles — push into player territory
	var control = hex_control.get(sector, "enemy")
	if control == "held":
		score += 40
	elif control == "contested":
		score += 25

	# Actively group up — waves feel like a mass push
	var nearby_enemies = 0
	for n in adjacency.get(sector, []):
		for unit in enemy_units:
			if unit.id != unit_id and unit.sector == n:
				nearby_enemies += 1
	score += nearby_enemies * 5  # positive — waves cluster together

	# Bonus for being adjacent to squads
	for n in adjacency.get(sector, []):
		if n in squad_sectors:
			score += 20

	return score


func _rush_extraction_score(sector: String, squad_sectors: Array, unit_id: int) -> int:
	var score = 0

	# Primary: hunt the data carrier specifically — highest priority
	var data_carrier = GameManager.data_carrier_squad
	if data_carrier != "" and not GameManager.data_destroyed:
		for squad in SquadManager.get_squads_for_ui():
			if squad.name == data_carrier and squad.status != SquadManager.Status.LOST:
				var dist_to_carrier = _bfs_distance(sector, squad.sector)
				score += (15 - min(dist_to_carrier, 15)) * 40  # heavily weighted
				break

	# Secondary: deny extraction zone
	var ez = GameManager.extraction_zone
	if ez != "":
		var dist_to_ez = _bfs_distance(sector, ez)
		score += (15 - min(dist_to_ez, 15)) * 20

	# Tertiary: general squad pressure
	var dist_to_squad = _bfs_distance_to_nearest(sector, squad_sectors)
	score += (10 - min(dist_to_squad, 10)) * 8

	# Prefer held tiles
	var control = hex_control.get(sector, "enemy")
	if control == "held":
		score += 15

	# If data is already destroyed — shift fully to denying extraction
	if GameManager.data_destroyed:
		if ez != "":
			var dist_to_ez2 = _bfs_distance(sector, ez)
			score += (15 - min(dist_to_ez2, 15)) * 35

	return score
