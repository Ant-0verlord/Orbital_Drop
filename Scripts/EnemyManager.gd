extends Node
# =============================================================
# EnemyManager.gd  —  AutoLoad singleton
# AutoLoad order: SquadManager, TurnManager, GameManager, EnemyManager
#
# Enemies advance toward squad hexes each turn.
# If a squad has Armaments allocated, they push enemies back.
# Enemies also contest neutral hexes to prevent capture.
# =============================================================

signal enemies_updated

# enemy_units: Array of { "id": int, "sector": String }
var enemy_units: Array = []
var all_sectors: Array = []

# Full 14-hex adjacency map
var adjacency: Dictionary = {}


func init_enemies(enemy_list: Array, sector_names: Array) -> void:
	enemy_units.clear()
	all_sectors = sector_names.duplicate()
	_build_adjacency()
	var id = 0
	for e in enemy_list:
		enemy_units.append({ "id": id, "sector": e.get("sector", "") })
		id += 1
	emit_signal("enemies_updated")


func get_enemy_sectors() -> Array:
	var sectors = []
	for unit in enemy_units:
		if not sectors.has(unit.sector):
			sectors.append(unit.sector)
	return sectors


func get_enemy_count_at(sector: String) -> int:
	var count = 0
	for unit in enemy_units:
		if unit.sector == sector:
			count += 1
	return count


# Called by SquadManager when Armaments are allocated to a squad in this sector
func push_back_enemy(sector: String) -> void:
	for unit in enemy_units:
		if unit.sector == sector:
			# Move enemy away from sector to best adjacent hex (away from squads)
			var neighbors = adjacency.get(sector, [])
			var best = ""
			var best_dist = -1
			for neighbor in neighbors:
				# Prefer hex furthest from any squad
				var min_dist = _min_dist_to_squads(neighbor)
				if min_dist > best_dist:
					best_dist = min_dist
					best = neighbor
			if best != "":
				unit.sector = best
				print("EnemyManager: Enemy pushed back from %s to %s" % [sector, best])
			emit_signal("enemies_updated")
			return


# Called by TurnManager after squad resolution
func advance_enemies() -> void:
	var squad_sectors = SquadManager.get_squad_sectors()

	for unit in enemy_units:
		var current = unit.sector
		var neighbors = adjacency.get(current, [])
		if neighbors.is_empty():
			continue

		# Target: closest squad sector, or closest neutral hex if no squads nearby
		var best_sector = current
		var best_dist = 9999

		for neighbor in neighbors:
			# Don't stack more than 2 enemies per hex
			var count_there = get_enemy_count_at(neighbor)
			if count_there >= 2:
				continue

			var dist = _min_dist_to_squads(neighbor)
			# Prefer hexes closer to squads (lower dist = better)
			if dist < best_dist:
				best_dist = dist
				best_sector = neighbor

		if best_sector != current:
			unit.sector = best_sector

	# After moving, apply pressure to squads that didn't fight
	for unit in enemy_units:
		for squad in SquadManager.get_squads_for_ui():
			if unit.sector == squad.sector and squad.status != SquadManager.Status.LOST:
				if not squad.fought_this_turn:
					_apply_pressure(squad.name)

	emit_signal("enemies_updated")


func _apply_pressure(squad_name: String) -> void:
	if not SquadManager.squads.has(squad_name):
		return
	var squad = SquadManager.squads[squad_name]
	match squad.status:
		SquadManager.Status.ACTIVE:
			squad.status = SquadManager.Status.WOUNDED
			print("EnemyManager: %s is now Wounded from enemy pressure." % squad_name)
		SquadManager.Status.WOUNDED:
			squad.status = SquadManager.Status.CRITICAL
			print("EnemyManager: %s is now Critical from enemy pressure." % squad_name)
		SquadManager.Status.CRITICAL:
			squad.status = SquadManager.Status.LOST
			SquadManager.emit_signal("squad_lost", squad_name)
			print("EnemyManager: %s is Lost from enemy pressure." % squad_name)


func _min_dist_to_squads(sector: String) -> int:
	var squad_sectors = SquadManager.get_squad_sectors()
	var min_dist = 9999
	for sq in squad_sectors:
		var d = _sector_distance(sector, sq)
		if d < min_dist:
			min_dist = d
	return min_dist


func _sector_distance(a: String, b: String) -> int:
	if a == b:
		return 0
	# BFS through adjacency for accurate hop count
	var visited = { a: true }
	var queue = [{ "sector": a, "dist": 0 }]
	while queue.size() > 0:
		var current = queue.pop_front()
		if current.sector == b:
			return current.dist
		for neighbor in adjacency.get(current.sector, []):
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append({ "sector": neighbor, "dist": current.dist + 1 })
	return 999


# -------------------------------------------------------
# 14-hex adjacency — flat-top hex grid
# Index order matches HoloMap.ALL_SECTORS_M1:
# 0=Alpha-7, 1=Beta-2, 2=Gamma-5, 3=Delta-9, 4=Epsilon-1,
# 5=Zeta-3, 6=Eta-6, 7=Theta-3, 8=Iota-8, 9=Kappa-1,
# 10=Lambda-4, 11=Mu-6, 12=Nu-2, 13=Xi-7
# -------------------------------------------------------
func _build_adjacency() -> void:
	adjacency.clear()
	if all_sectors.size() < 14:
		return

	var adj_indices: Dictionary = {
		0:  [1, 2, 3, 4, 5, 6],       # centre — adjacent to all ring 1
		1:  [0, 2, 6, 7, 8],           # Beta-2
		2:  [0, 1, 3, 8, 9],           # Gamma-5
		3:  [0, 2, 4, 9, 10],          # Delta-9
		4:  [0, 3, 5, 10, 11],         # Epsilon-1
		5:  [0, 4, 6, 11, 12],         # Zeta-3
		6:  [0, 1, 5, 12, 13],         # Eta-6
		7:  [1, 8, 13],                # Theta-3
		8:  [1, 2, 7, 9],              # Iota-8
		9:  [2, 3, 8, 10],             # Kappa-1
		10: [3, 4, 9, 11],             # Lambda-4
		11: [4, 5, 10, 12],            # Mu-6
		12: [5, 6, 11, 13],            # Nu-2
		13: [6, 7, 12],                # Xi-7
	}

	for idx in adj_indices:
		if idx < all_sectors.size():
			var sector = all_sectors[idx]
			var neighbors = []
			for neighbor_idx in adj_indices[idx]:
				if neighbor_idx < all_sectors.size():
					neighbors.append(all_sectors[neighbor_idx])
			adjacency[sector] = neighbors
