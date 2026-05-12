extends Node
# =============================================================
# EnemyManager.gd  —  AutoLoad singleton
# AutoLoad order: SquadManager, TurnManager, GameManager, EnemyManager
#
# All 14 tiles start enemy-controlled.
# 2 enemy units advance 1 tile per turn toward nearest squad.
# Squads use Fuel Cells to move into unoccupied tiles (capture).
# Squads use Armaments to fight enemies on tiles.
# =============================================================

signal enemies_updated

# hex_control: { sector_name: "enemy" / "held" / "contested" / "neutral" }
var hex_control: Dictionary = {}

# enemy_units: Array of { "id": int, "sector": String }
var enemy_units: Array = []

# Full 14-sector list — set on init
var all_sectors: Array = []

# Adjacency map — built from fixed layout
var adjacency: Dictionary = {}

const ALL_SECTORS_14 = [
	"Alpha-7",   # 0  centre
	"Beta-2",    # 1  ring 1 right
	"Gamma-5",   # 2  ring 1 top-right
	"Delta-9",   # 3  ring 1 top-left
	"Epsilon-1", # 4  ring 1 left
	"Zeta-3",    # 5  ring 1 bottom-left
	"Eta-6",     # 6  ring 1 bottom-right
	"Theta-3",   # 7  ring 2 top-right
	"Iota-8",    # 8  ring 2 right
	"Kappa-1",   # 9  ring 2 bottom-right
	"Lambda-4",  # 10 ring 2 bottom-left
	"Mu-6",      # 11 ring 2 left
	"Nu-2",      # 12 ring 2 top-left
	"Xi-7",      # 13 ring 2 top
]


func init_enemies(squad_sectors: Array, enemy_list: Array) -> void:
	all_sectors = ALL_SECTORS_14.duplicate()
	_build_adjacency()

	# All tiles start enemy-controlled
	hex_control.clear()
	for sector in all_sectors:
		hex_control[sector] = "enemy"

	# Squad starting tiles are held
	for sector in squad_sectors:
		hex_control[sector] = "held"

	# Place enemy units
	enemy_units.clear()
	var id = 0
	for e in enemy_list:
		enemy_units.append({
			"id":     id,
			"sector": e.get("sector", "Iota-8"),
		})
		id += 1

	emit_signal("enemies_updated")


# -------------------------------------------------------
# Called by SquadManager when a squad uses Fuel Cells
# Returns the best adjacent unoccupied tile to move to
# -------------------------------------------------------
func get_best_move_target(from_sector: String) -> String:
	var neighbors = adjacency.get(from_sector, [])
	# Prefer enemy tiles (capture them), avoid tiles with enemy units
	var best = ""
	for n in neighbors:
		var has_enemy_unit = false
		for unit in enemy_units:
			if unit.sector == n:
				has_enemy_unit = true
				break
		if not has_enemy_unit:
			best = n
			break
	return best


# Called by SquadManager when a squad uses Armaments — fights at their sector
# Returns true if enemies were present and pushed back
func fight_at(sector: String, squad_name: String) -> bool:
	var enemies_here = []
	for unit in enemy_units:
		if unit.sector == sector:
			enemies_here.append(unit)

	if enemies_here.is_empty():
		# No enemies at current tile — check adjacent for attack
		return false

	# Push enemies back one tile away from squad
	for unit in enemies_here:
		var pushed = _push_enemy_back(unit, sector)
		if pushed != "":
			unit.sector = pushed
			print("EnemyManager: Enemy %d pushed back to %s" % [unit.id, pushed])

	hex_control[sector] = "held"
	emit_signal("enemies_updated")
	return true


# Called by SquadManager for Fuel+Arms combo — best adjacent enemy tile to attack
func get_best_attack_target(from_sector: String) -> String:
	var neighbors = adjacency.get(from_sector, [])
	for n in neighbors:
		for unit in enemy_units:
			if unit.sector == n:
				return n
	return ""


# -------------------------------------------------------
# Called by TurnManager after squad resolution
# Enemies advance 1 tile toward nearest squad
# -------------------------------------------------------
func advance_enemies() -> void:
	var squad_sectors = []
	for squad in SquadManager.get_squads_for_ui():
		if squad.status != SquadManager.Status.LOST:
			squad_sectors.append(squad.sector)

	if squad_sectors.is_empty():
		return

	for unit in enemy_units:
		var neighbors = adjacency.get(unit.sector, [])
		var best = unit.sector
		var best_dist = _sector_distance(unit.sector, squad_sectors)

		for n in neighbors:
			# Don't stack on another enemy unit
			var occupied = false
			for other in enemy_units:
				if other.id != unit.id and other.sector == n:
					occupied = true
					break
			if occupied:
				continue

			var dist = _sector_distance(n, squad_sectors)
			if dist < best_dist:
				best_dist = dist
				best = n

		if best != unit.sector:
			# Leave previous tile — if no other enemy is there, mark appropriately
			var others_at_old = false
			for other in enemy_units:
				if other.id != unit.id and other.sector == unit.sector:
					others_at_old = true
					break
			if not others_at_old and hex_control.get(unit.sector, "") == "enemy":
				hex_control[unit.sector] = "neutral"

			unit.sector = best

	# Rebuild hex control from unit positions and squad positions
	_rebuild_hex_control()
	emit_signal("enemies_updated")


# -------------------------------------------------------
# Update hex_control based on current unit and squad positions
# -------------------------------------------------------
func _rebuild_hex_control() -> void:
	# Start: all tiles that have no squad and no enemy unit are neutral
	# (but if they were previously held by squads, keep held)
	var squad_sectors = []
	for squad in SquadManager.get_squads_for_ui():
		if squad.status != SquadManager.Status.LOST:
			squad_sectors.append(squad.sector)

	var enemy_sectors = []
	for unit in enemy_units:
		enemy_sectors.append(unit.sector)

	for sector in all_sectors:
		var has_squad  = sector in squad_sectors
		var has_enemy  = sector in enemy_sectors

		if has_squad and has_enemy:
			hex_control[sector] = "contested"
		elif has_squad:
			hex_control[sector] = "held"
		elif has_enemy:
			hex_control[sector] = "enemy"
		else:
			# Keep held if it was captured, otherwise neutral
			if hex_control.get(sector, "") == "held":
				hex_control[sector] = "held"
			elif hex_control.get(sector, "") == "contested":
				hex_control[sector] = "enemy"  # Contested with no squad = enemy takes over
			else:
				hex_control[sector] = hex_control.get(sector, "neutral")


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
# Internal helpers
# -------------------------------------------------------
func _push_enemy_back(unit: Dictionary, away_from: String) -> String:
	var neighbors = adjacency.get(unit.sector, [])
	# Find neighbor furthest from the attacked tile
	var best = ""
	var best_dist = -1
	for n in neighbors:
		if n == away_from:
			continue
		var occupied = false
		for other in enemy_units:
			if other.id != unit.id and other.sector == n:
				occupied = true
				break
		if not occupied:
			var d = _sector_distance(n, [away_from])
			if d > best_dist:
				best_dist = d
				best = n
	return best


func _sector_distance(from: String, targets: Array) -> int:
	var idx_from = all_sectors.find(from)
	if idx_from == -1:
		return 999
	var min_dist = 999
	for target in targets:
		var idx_to = all_sectors.find(target)
		if idx_to == -1:
			continue
		# BFS distance using adjacency
		var dist = _bfs_distance(from, target)
		if dist < min_dist:
			min_dist = dist
	return min_dist


func _bfs_distance(start: String, end: String) -> int:
	if start == end:
		return 0
	var visited = { start: true }
	var queue = [[start, 0]]
	while queue.size() > 0:
		var current = queue.pop_front()
		var node = current[0]
		var dist = current[1]
		for neighbor in adjacency.get(node, []):
			if neighbor == end:
				return dist + 1
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append([neighbor, dist + 1])
	return 999


func _build_adjacency() -> void:
	adjacency.clear()
	# 14-hex flat-top grid adjacency by index
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
