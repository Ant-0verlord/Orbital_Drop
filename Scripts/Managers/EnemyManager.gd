extends Node
# =============================================================
# EnemyManager.gd  —  AutoLoad singleton
# =============================================================

signal enemies_updated

var hex_control: Dictionary = {}
var enemy_units: Array = []
var all_sectors: Array = []
var adjacency: Dictionary = {}

const ALL_SECTORS_14 = [
	"Alpha-7",   # 0
	"Beta-2",    # 1
	"Gamma-5",   # 2
	"Delta-9",   # 3
	"Epsilon-1", # 4
	"Zeta-3",    # 5
	"Eta-6",     # 6
	"Theta-3",   # 7
	"Iota-8",    # 8
	"Kappa-1",   # 9
	"Lambda-4",  # 10
	"Mu-6",      # 11
	"Nu-2",      # 12
	"Xi-7",      # 13
]


func init_enemies(squad_sectors: Array, enemy_list: Array) -> void:
	all_sectors = ALL_SECTORS_14.duplicate()
	_build_adjacency()

	hex_control.clear()
	for sector in all_sectors:
		hex_control[sector] = "enemy"
	for sector in squad_sectors:
		hex_control[sector] = "held"

	enemy_units.clear()
	var id = 0
	for e in enemy_list:
		enemy_units.append({
			"id":       id,
			"sector":   e.get("sector", "Iota-8"),
			"hp":       1,
			"cooldown": 0,
		})
		id += 1

	emit_signal("enemies_updated")


# -------------------------------------------------------
# Squad uses Fuel Cells — best adjacent tile to move to
# -------------------------------------------------------
func get_best_move_target(from_sector: String) -> String:
	var neighbors = adjacency.get(from_sector, [])
	for n in neighbors:
		if not _has_enemy_unit(n) and hex_control.get(n, "") == "enemy":
			return n
	for n in neighbors:
		if not _has_enemy_unit(n):
			return n
	return ""


# -------------------------------------------------------
# Armed fight — always kills enemy instantly
# -------------------------------------------------------
func fight_at(sector: String, _squad_name: String) -> bool:
	var enemies_here = _get_enemies_at(sector)
	if enemies_here.is_empty():
		return false

	for unit in enemies_here.duplicate():
		enemy_units.erase(unit)

	hex_control[sector] = "held"
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


# Squad uses Fuel + Arms — best adjacent enemy-occupied tile
func get_best_attack_target(from_sector: String) -> String:
	var neighbors = adjacency.get(from_sector, [])
	for n in neighbors:
		if _has_enemy_unit(n):
			return n
	return ""


# Squad uses Fuel only — best adjacent enemy tile to move into
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
# allocations: { squad_name: { "Armaments": int, ... } }
# After enemies move, any that land on an armed squad's
# tile are instantly eliminated
# -------------------------------------------------------
func advance_enemies(allocations: Dictionary) -> void:
	# Build squad map: sector -> squad name
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

		var best       = unit.sector
		var best_score = _movement_score(unit.sector, squad_sectors, unit.id)

		var candidates = adjacency.get(unit.sector, []).duplicate()
		candidates.shuffle()

		for n in candidates:
			if _has_enemy_unit_excluding(n, unit.id):
				continue
			if unit.cooldown > 0:
				var control = hex_control.get(n, "enemy")
				if control == "held" or control == "contested" or n in squad_sectors:
					continue
			var score = _movement_score(n, squad_sectors, unit.id)
			if score > best_score:
				best_score = score
				best = n

		unit.sector = best

	# -------------------------------------------------------
	# Post-movement: enemy walked onto an armed squad's tile
	# OR onto a reinforcement squad with surprise bonus
	# Both result in instant enemy elimination
	# -------------------------------------------------------
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

	# -------------------------------------------------------
	# Process pending reinforcement drop
	# Happens after enemy movement so surprise bonus applies
	# correctly to any enemies already on the target hex
	# -------------------------------------------------------
	if GameManager.has_pending_reinforcement():
		var drop = GameManager.get_pending_reinforcement()
		var target_sector = drop.get("sector", "")
		var squad_name    = drop.get("squad_name", "")

		if target_sector != "" and squad_name != "":
			# Check if landing on enemy — surprise bonus
			var surprise = _has_enemy_unit(target_sector)

			# Add squad to roster
			SquadManager.add_squad(squad_name, target_sector, surprise)

			if surprise:
				# Eliminate all enemies on the landing hex
				for unit in enemy_units.duplicate():
					if unit.sector == target_sector:
						enemy_units.erase(unit)
				hex_control[target_sector] = "held"
			else:
				hex_control[target_sector] = "held"

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


# -------------------------------------------------------
# Push back 2 tiles deep
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


func _bfs_distance_to_nearest(from: String, targets: Array) -> int:
	var min_dist = 999
	for target in targets:
		var d = _bfs_distance(from, target)
		if d < min_dist:
			min_dist = d
	return min_dist


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


func _build_adjacency() -> void:
	adjacency.clear()
	var adj_map = {
		0:  [1, 2, 3, 4, 5, 6],
		1:  [0, 2, 6, 8, 9],
		2:  [0, 1, 3, 7, 8],
		3:  [0, 2, 4, 7, 13],
		4:  [0, 3, 5, 12, 13],
		5:  [0, 4, 6, 11, 12],
		6:  [0, 1, 5, 9, 11],
		7:  [2, 3, 8, 13],
		8:  [1, 2, 7, 9],
		9:  [1, 6, 8, 10],
		10: [6, 9, 11],
		11: [5, 6, 10, 12],
		12: [4, 5, 11, 13],
		13: [3, 4, 7, 12],
	}
	for idx in adj_map:
		if idx < all_sectors.size():
			var sector = all_sectors[idx]
			var neighbors = []
			for n_idx in adj_map[idx]:
				if n_idx < all_sectors.size():
					neighbors.append(all_sectors[n_idx])
			adjacency[sector] = neighbors
