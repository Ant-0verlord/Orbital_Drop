extends Node
# =============================================================
# EnemyManager.gd  —  AutoLoad singleton
# =============================================================

signal enemies_updated

# hex_control: { sector: "enemy"/"held"/"contested"/"neutral" }
# "held" persists even when squad leaves — only enemy can take it back
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

	# ALL tiles start enemy-controlled
	hex_control.clear()
	for sector in all_sectors:
		hex_control[sector] = "enemy"

	# Squad starting tiles are held from turn 0
	for sector in squad_sectors:
		hex_control[sector] = "held"

	# Place enemy units
	enemy_units.clear()
	var id = 0
	for e in enemy_list:
		enemy_units.append({ "id": id, "sector": e.get("sector", "Iota-8") })
		id += 1

	emit_signal("enemies_updated")


# -------------------------------------------------------
# Squad uses Fuel Cells — returns best adjacent tile to move to
# Prefers held tiles (already ours) or neutral, avoids enemy units
# -------------------------------------------------------
func get_best_move_target(from_sector: String) -> String:
	var neighbors = adjacency.get(from_sector, [])
	# First try: move to enemy tile with no enemy unit (capture it)
	for n in neighbors:
		if not _has_enemy_unit(n) and hex_control.get(n, "") == "enemy":
			return n
	# Second try: any adjacent tile with no enemy unit
	for n in neighbors:
		if not _has_enemy_unit(n):
			return n
	return ""


# Squad uses Armaments — fight at current sector
# Returns true if enemies were present
func fight_at(sector: String, _squad_name: String) -> bool:
	var enemies_here = []
	for unit in enemy_units:
		if unit.sector == sector:
			enemies_here.append(unit)

	if enemies_here.is_empty():
		return false

	# Push enemies back
	for unit in enemies_here:
		var pushed = _push_enemy_back(unit, sector)
		if pushed != "":
			unit.sector = pushed

	hex_control[sector] = "held"
	emit_signal("enemies_updated")
	return true


# Squad uses Fuel + Arms — best adjacent enemy-occupied tile to attack
func get_best_attack_target(from_sector: String) -> String:
	var neighbors = adjacency.get(from_sector, [])
	for n in neighbors:
		if _has_enemy_unit(n):
			return n
	return ""


# -------------------------------------------------------
# Squad captures a tile by moving onto it
# -------------------------------------------------------
func capture_tile(sector: String) -> void:
	hex_control[sector] = "held"
	emit_signal("enemies_updated")


# -------------------------------------------------------
# Called by TurnManager after squad resolution
# -------------------------------------------------------
func advance_enemies() -> void:
	var squad_sectors = []
	for squad in SquadManager.get_squads_for_ui():
		if squad.status != SquadManager.Status.LOST:
			squad_sectors.append(squad.sector)

	if squad_sectors.is_empty():
		return

	for unit in enemy_units:
		var best = unit.sector
		var best_dist = _bfs_distance_to_nearest(unit.sector, squad_sectors)

		for n in adjacency.get(unit.sector, []):
			if _has_enemy_unit_excluding(n, unit.id):
				continue
			var dist = _bfs_distance_to_nearest(n, squad_sectors)
			if dist < best_dist:
				best_dist = dist
				best = n

		unit.sector = best

	_rebuild_hex_control(squad_sectors)
	emit_signal("enemies_updated")


# -------------------------------------------------------
# Rebuild hex_control
# KEY RULE: "held" tiles only revert to "enemy" if an enemy
# unit is physically on them. Otherwise they stay "held".
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
			# Enemy on tile — override regardless of previous state
			hex_control[sector] = "enemy"
		else:
			# No squad, no enemy — keep existing state
			# "held" stays held (squad captured it and left)
			# "enemy" stays enemy (never captured)
			# "contested" reverts to enemy (squad left during contest)
			if current == "contested":
				hex_control[sector] = "enemy"
			# Otherwise leave as-is


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
