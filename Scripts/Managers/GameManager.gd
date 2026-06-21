extends Node
# =============================================================
# GameManager.gd  —  AutoLoad singleton
# =============================================================

var current_mission: int = 0
var campaign_record: Array = []

var supply_pool: Dictionary = {
	"Armaments":  0,
	"Medi-Packs": 0,
	"Fuel Cells": 0,
}

var supply_spent: Dictionary = {
	"Armaments":  0,
	"Medi-Packs": 0,
	"Fuel Cells": 0,
}

var reinforcement_pool: int = 0
var pending_reinforcement: Dictionary = {}
var used_reinforcement_names: Array = []

const REINFORCEMENT_NAMES: Array = [
	"Squad Taev",
	"Squad Miren",
	"Squad Cros",
	"Squad Veth",
	"Squad Orun",
]

# =============================================================
# MISSION 1 — Planetary Insertion
# 14 sectors, compact hub, 5 turns
# =============================================================
const M1_SECTORS = [
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

const M1_ADJACENCY = {
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

# Axial coordinates for HexCanvas — pointy-top hex grid
const M1_AXIAL = [
	Vector2( 0,  0),  # Alpha-7   — centre
	Vector2( 1, -1),  # Beta-2
	Vector2( 1,  0),  # Gamma-5
	Vector2( 0,  1),  # Delta-9
	Vector2(-1,  1),  # Epsilon-1
	Vector2(-1,  0),  # Zeta-3
	Vector2( 0, -1),  # Eta-6
	Vector2( 2, -2),  # Theta-3
	Vector2( 2, -1),  # Iota-8
	Vector2( 2,  0),  # Kappa-1
	Vector2( 1,  1),  # Lambda-4
	Vector2( 0,  2),  # Mu-6
	Vector2(-1,  2),  # Nu-2
	Vector2(-2,  1),  # Xi-7
]

# =============================================================
# MISSION 2 — Advance on Kerath-IV
# 18 sectors, long corridor, 7 turns
# Squads start left end, enemies at right end
# =============================================================
const M2_SECTORS = [
	"Omicron-3",  # 0  — left end (squad start)
	"Pi-7",       # 1
	"Rho-2",      # 2
	"Sigma-5",    # 3
	"Tau-9",      # 4
	"Upsilon-1",  # 5
	"Phi-4",      # 6
	"Chi-8",      # 7
	"Psi-2",      # 8
	"Omega-6",    # 9
	"Omicron-7",  # 10
	"Pi-3",       # 11
	"Rho-9",      # 12
	"Sigma-1",    # 13
	"Tau-5",      # 14
	"Upsilon-8",  # 15
	"Phi-2",      # 16
	"Chi-6",      # 17 — right end (enemy start)
]

# Long corridor — 3 rows, 6 columns roughly
# Row 0 (top):    0, 2, 4, 10, 12, 14, 16
# Row 1 (middle): 1, 3, 5,  7,  9, 11, 13, 15, 17
# Row 2 (bottom): 6, 8
const M2_ADJACENCY = {
	0:  [1, 2],
	1:  [0, 2, 3],
	2:  [0, 1, 3, 4],
	3:  [1, 2, 4, 5, 6],
	4:  [2, 3, 5, 10],
	5:  [3, 4, 6, 7, 10],
	6:  [3, 5, 7, 8],
	7:  [5, 6, 8, 9, 11],
	8:  [6, 7, 9],
	9:  [7, 8, 10, 11, 12],
	10: [4, 5, 9, 11, 13],
	11: [7, 9, 10, 12, 13],
	12: [9, 11, 13, 14],
	13: [10, 11, 12, 14, 15],
	14: [12, 13, 15, 16],
	15: [13, 14, 16, 17],
	16: [14, 15, 17],
	17: [15, 16],
}

# Long corridor axial layout — stretches along Q axis
const M2_AXIAL = [
	Vector2(-4,  0),  # Omicron-3
	Vector2(-4,  1),  # Pi-7
	Vector2(-3, -1),  # Rho-2
	Vector2(-3,  0),  # Sigma-5
	Vector2(-2, -1),  # Tau-9
	Vector2(-2,  0),  # Upsilon-1
	Vector2(-2,  1),  # Phi-4
	Vector2(-1,  0),  # Chi-8
	Vector2(-1,  1),  # Psi-2
	Vector2( 0,  0),  # Omega-6
	Vector2(-1, -1),  # Omicron-7
	Vector2( 0, -1),  # Pi-3
	Vector2( 1,  0),  # Rho-9
	Vector2( 1, -1),  # Sigma-1
	Vector2( 2,  0),  # Tau-5
	Vector2( 2, -1),  # Upsilon-8
	Vector2( 3,  0),  # Phi-2
	Vector2( 3, -1),  # Chi-6
]

# =============================================================
# MISSION 3 — The Iron Salient
# 20 sectors, branching fork
# =============================================================
const M3_SECTORS = [
	"Psi-7",     # 0
	"Omega-3",   # 1
	"Alpha-2B",  # 2
	"Beta-8B",   # 3
	"Gamma-4B",  # 4
	"Delta-6B",  # 5
	"Epsilon-9B",# 6
	"Zeta-1B",   # 7
	"Eta-5B",    # 8
	"Theta-7B",  # 9
	"Iota-3B",   # 10
	"Kappa-9B",  # 11
	"Lambda-2B", # 12
	"Mu-8B",     # 13
	"Nu-4B",     # 14
	"Xi-6B",     # 15
	"Omicron-1B",# 16
	"Pi-5B",     # 17
	"Rho-3B",    # 18
	"Sigma-7B",  # 19
]

const M3_ADJACENCY = {
	0:  [1, 2, 3],
	1:  [0, 2, 4],
	2:  [0, 1, 3, 5],
	3:  [0, 2, 6],
	4:  [1, 5, 7],
	5:  [2, 4, 6, 8],
	6:  [3, 5, 9],
	7:  [4, 8, 10],
	8:  [5, 7, 9, 11],
	9:  [6, 8, 12],
	10: [7, 11, 13],
	11: [8, 10, 12, 14],
	12: [9, 11, 15],
	13: [10, 14, 16],
	14: [11, 13, 15, 17],
	15: [12, 14, 18],
	16: [13, 17, 19],
	17: [14, 16, 18],
	18: [15, 17, 19],
	19: [16, 18],
}

const M3_AXIAL = [
	Vector2( 0,  0),  # Psi-7      — spine base
	Vector2( 0,  1),  # Omega-3
	Vector2( 1,  0),  # Alpha-2B
	Vector2( 1,  1),  # Beta-8B
	Vector2( 0,  2),  # Gamma-4B   — upper fork
	Vector2( 2,  0),  # Delta-6B   — lower fork
	Vector2( 2,  1),  # Epsilon-9B
	Vector2(-1,  2),  # Zeta-1B
	Vector2( 3,  0),  # Eta-5B
	Vector2( 3,  1),  # Theta-7B
	Vector2(-2,  3),  # Iota-3B
	Vector2( 4,  0),  # Kappa-9B
	Vector2( 4,  1),  # Lambda-2B
	Vector2(-3,  4),  # Mu-8B
	Vector2( 5,  0),  # Nu-4B
	Vector2( 5,  1),  # Xi-6B
	Vector2(-4,  5),  # Omicron-1B
	Vector2( 6,  0),  # Pi-5B
	Vector2( 6,  1),  # Rho-3B
	Vector2(-5,  6),  # Sigma-7B
]

# =============================================================
# MISSION 4 — Contested Hive Spire
# 22 sectors, pincer shape
# =============================================================
const M4_SECTORS = [
	"Tau-2B",    # 0
	"Upsilon-6B",# 1
	"Phi-9B",    # 2
	"Chi-3B",    # 3
	"Psi-5B",    # 4
	"Omega-8B",  # 5
	"Alpha-4C",  # 6
	"Beta-7C",   # 7
	"Gamma-1C",  # 8
	"Delta-3C",  # 9
	"Epsilon-6C",# 10
	"Zeta-9C",   # 11
	"Eta-2C",    # 12
	"Theta-5C",  # 13
	"Iota-8C",   # 14
	"Kappa-4C",  # 15
	"Lambda-7C", # 16
	"Mu-1C",     # 17
	"Nu-6C",     # 18
	"Xi-3C",     # 19
	"Omicron-9C",# 20
	"Pi-2C",     # 21
]

const M4_ADJACENCY = {
	0:  [1, 2, 6],
	1:  [0, 3, 7],
	2:  [0, 3, 4, 8],
	3:  [1, 2, 5, 9],
	4:  [2, 5, 10],
	5:  [3, 4, 11],
	6:  [0, 7, 12],
	7:  [1, 6, 8, 13],
	8:  [2, 7, 9, 14],
	9:  [3, 8, 10, 15],
	10: [4, 9, 11, 16],
	11: [5, 10, 17],
	12: [6, 13, 18],
	13: [7, 12, 14, 18],
	14: [8, 13, 15, 19],
	15: [9, 14, 16, 19],
	16: [10, 15, 17, 20],
	17: [11, 16, 21],
	18: [12, 13, 20],
	19: [14, 15, 21],
	20: [16, 18, 21],
	21: [17, 19, 20],
}

const M4_AXIAL = [
	Vector2(-3,  0),  # Tau-2B     — left pincer top
	Vector2(-3,  2),  # Upsilon-6B — left pincer bottom
	Vector2(-2, -1),  # Phi-9B
	Vector2(-2,  1),  # Chi-3B
	Vector2(-1, -2),  # Psi-5B     — upper arm
	Vector2(-1,  2),  # Omega-8B   — lower arm
	Vector2(-2,  0),  # Alpha-4C
	Vector2(-1,  0),  # Beta-7C    — centre left
	Vector2( 0,  0),  # Gamma-1C   — contested centre
	Vector2( 0,  1),  # Delta-3C
	Vector2( 1, -1),  # Epsilon-6C — upper right
	Vector2( 1,  1),  # Zeta-9C    — lower right
	Vector2(-2,  0),  # Eta-2C
	Vector2( 0, -1),  # Theta-5C
	Vector2( 1,  0),  # Iota-8C
	Vector2( 1,  1),  # Kappa-4C
	Vector2( 2, -1),  # Lambda-7C  — right pincer
	Vector2( 2,  1),  # Mu-1C
	Vector2(-1, -1),  # Nu-6C
	Vector2( 2,  0),  # Xi-3C
	Vector2( 3, -1),  # Omicron-9C — right tip
	Vector2( 3,  1),  # Pi-2C
]

# =============================================================
# MISSION 5 — Final Assault
# 24 sectors, irregular sprawl
# =============================================================
const M5_SECTORS = [
	"Rho-6C",    # 0
	"Sigma-2C",  # 1
	"Tau-8C",    # 2
	"Upsilon-4C",# 3
	"Phi-7C",    # 4
	"Chi-1C",    # 5
	"Psi-9C",    # 6
	"Omega-3C",  # 7
	"Alpha-5D",  # 8
	"Beta-2D",   # 9
	"Gamma-8D",  # 10
	"Delta-4D",  # 11
	"Epsilon-7D",# 12
	"Zeta-3D",   # 13
	"Eta-9D",    # 14
	"Theta-1D",  # 15
	"Iota-6D",   # 16
	"Kappa-2D",  # 17
	"Lambda-8D", # 18
	"Mu-5D",     # 19
	"Nu-3D",     # 20
	"Xi-9D",     # 21
	"Omicron-4D",# 22
	"Pi-7D",     # 23
]

const M5_ADJACENCY = {
	0:  [1, 2, 8],
	1:  [0, 3, 9],
	2:  [0, 3, 4, 10],
	3:  [1, 2, 5, 11],
	4:  [2, 5, 6, 12],
	5:  [3, 4, 7, 13],
	6:  [4, 7, 14],
	7:  [5, 6, 15],
	8:  [0, 9, 16],
	9:  [1, 8, 10, 17],
	10: [2, 9, 11, 18],
	11: [3, 10, 12, 19],
	12: [4, 11, 13, 20],
	13: [5, 12, 14, 21],
	14: [6, 13, 15, 22],
	15: [7, 14, 23],
	16: [8, 17],
	17: [9, 16, 18],
	18: [10, 17, 19],
	19: [11, 18, 20],
	20: [12, 19, 21],
	21: [13, 20, 22],
	22: [14, 21, 23],
	23: [15, 22],
}

const M5_AXIAL = [
	Vector2(-3, -1),  # Rho-6C
	Vector2(-3,  1),  # Sigma-2C
	Vector2(-2, -2),  # Tau-8C
	Vector2(-2,  0),  # Upsilon-4C
	Vector2(-1, -3),  # Phi-7C
	Vector2(-1,  1),  # Chi-1C
	Vector2( 0, -3),  # Psi-9C
	Vector2( 0,  1),  # Omega-3C
	Vector2(-2, -1),  # Alpha-5D
	Vector2(-2,  0),  # Beta-2D
	Vector2(-1, -1),  # Gamma-8D
	Vector2(-1,  0),  # Delta-4D
	Vector2( 0, -2),  # Epsilon-7D
	Vector2( 0,  0),  # Zeta-3D    — centre
	Vector2( 1, -2),  # Eta-9D
	Vector2( 1,  0),  # Theta-1D
	Vector2(-1, -2),  # Iota-6D
	Vector2( 0, -1),  # Kappa-2D
	Vector2( 1, -1),  # Lambda-8D
	Vector2( 1,  1),  # Mu-5D
	Vector2( 2, -1),  # Nu-3D
	Vector2( 2,  0),  # Xi-9D
	Vector2( 3, -1),  # Omicron-4D
	Vector2( 3,  0),  # Pi-7D
]


var missions: Array = [
	{
		"title":        "Mission 1 — Planetary Insertion",
		"turns":        5,
		"win_hexes":    4,
		"interference": 0.0,
		"objective":    "Capture and hold 4 sectors by the end of Turn 5.",
		"supply_pool":        { "Armaments": 8, "Medi-Packs": 6, "Fuel Cells": 8 },
		"reinforcement_pool": 0,
		"sectors":    M1_SECTORS,
		"adjacency":  M1_ADJACENCY,
		"axial":      M1_AXIAL,
		"reinforcement_schedule": { 4: 1 },
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
		],
		"enemies": [
			{ "sector": "Zeta-3"  },
			{ "sector": "Delta-9" },
			{ "sector": "Iota-8"  },
		],
	},
	{
		"title":        "Mission 2 — Advance on Kerath-IV",
		"turns":        7,
		"win_hexes":    8,
		"interference": 0.2,
		"objective":    "Secure 8 sectors. Enemy reinforcements inbound.",
		"supply_pool":        { "Armaments": 10, "Medi-Packs": 8, "Fuel Cells": 10 },
		"reinforcement_pool": 1,
		"sectors":    M2_SECTORS,
		"adjacency":  M2_ADJACENCY,
		"axial":      M2_AXIAL,
		"reinforcement_schedule": { 5: 1, 6: 1 },
		"squads": [
			{ "name": "Squad Varro", "sector": "Omicron-3", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Pi-7",      "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Rho-2",     "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
		],
		"enemies": [
			{ "sector": "Tau-5"     },
			{ "sector": "Upsilon-8" },
			{ "sector": "Phi-2"     },
			{ "sector": "Chi-6"     },
			{ "sector": "Omega-6"   },
		],
	},
	{
		"title":        "Mission 3 — The Iron Salient",
		"turns":        5,
		"win_hexes":    11,
		"interference": 0.5,
		"objective":    "Hold 11 sectors against a reinforced enemy push.",
		"supply_pool":        { "Armaments": 10, "Medi-Packs": 8, "Fuel Cells": 10 },
		"reinforcement_pool": 1,
		"sectors":    M3_SECTORS,
		"adjacency":  M3_ADJACENCY,
		"axial":      M3_AXIAL,
		"reinforcement_schedule": { 3: 1, 4: 2 },
		"squads": [
			{ "name": "Squad Varro", "sector": "Psi-7",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Omega-3", "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Alpha-2B","status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Beta-8B", "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
		],
		"enemies": [
			{ "sector": "Nu-4B"      },
			{ "sector": "Xi-6B"      },
			{ "sector": "Pi-5B"      },
			{ "sector": "Rho-3B"     },
			{ "sector": "Sigma-7B"   },
			{ "sector": "Omicron-1B" },
		],
	},
	{
		"title":        "Mission 4 — Contested Hive Spire",
		"turns":        5,
		"win_hexes":    13,
		"interference": 0.75,
		"objective":    "Hold 13 sectors. Comms are failing — trust your instincts.",
		"supply_pool":        { "Armaments": 10, "Medi-Packs": 8, "Fuel Cells": 10 },
		"reinforcement_pool": 1,
		"sectors":    M4_SECTORS,
		"adjacency":  M4_ADJACENCY,
		"axial":      M4_AXIAL,
		"reinforcement_schedule": { 3: 1, 4: 2 },
		"squads": [
			{ "name": "Squad Varro", "sector": "Tau-2B",    "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Upsilon-6B","status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Phi-9B",    "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Chi-3B",    "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
		],
		"enemies": [
			{ "sector": "Omicron-9C" },
			{ "sector": "Pi-2C"      },
			{ "sector": "Xi-3C"      },
			{ "sector": "Lambda-7C"  },
			{ "sector": "Mu-1C"      },
			{ "sector": "Nu-6C"      },
			{ "sector": "Zeta-9C"    },
		],
	},
	{
		"title":        "Mission 5 — Final Assault",
		"turns":        5,
		"win_hexes":    15,
		"interference": 1.0,
		"objective":    "Hold 15 sectors. All channels compromised. The final push begins.",
		"supply_pool":        { "Armaments": 12, "Medi-Packs": 10, "Fuel Cells": 12 },
		"reinforcement_pool": 2,
		"sectors":    M5_SECTORS,
		"adjacency":  M5_ADJACENCY,
		"axial":      M5_AXIAL,
		"reinforcement_schedule": { 3: 1, 4: 2 },
		"squads": [
			{ "name": "Squad Varro", "sector": "Rho-6C",    "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Sigma-2C",  "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Tau-8C",    "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Upsilon-4C","status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Rhael", "sector": "Phi-7C",    "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
		],
		"enemies": [
			{ "sector": "Pi-7D"      },
			{ "sector": "Omicron-4D" },
			{ "sector": "Xi-9D"      },
			{ "sector": "Nu-3D"      },
			{ "sector": "Mu-5D"      },
			{ "sector": "Lambda-8D"  },
			{ "sector": "Eta-9D"     },
			{ "sector": "Theta-1D"   },
		],
	},
]

func get_current_mission_data() -> Dictionary:
	if current_mission < missions.size():
		return missions[current_mission]
	return {}

func get_current_axial_map() -> Dictionary:
	var data = get_current_mission_data()
	var sectors = data.get("sectors", [])
	var axial   = data.get("axial", [])
	var map: Dictionary = {}
	for i in range(min(sectors.size(), axial.size())):
		map[sectors[i]] = axial[i]
	return map


func start_current_mission() -> void:
	var data = get_current_mission_data()
	if data.is_empty():
		push_error("GameManager: No mission data for index %d" % current_mission)
		return

	var base_pool = data.get("supply_pool", { "Armaments": 8, "Medi-Packs": 6, "Fuel Cells": 8 })
	for s in base_pool:
		supply_pool[s] = supply_pool.get(s, 0) + base_pool[s]

	reinforcement_pool += data.get("reinforcement_pool", 0)
	supply_spent = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	pending_reinforcement = {}

	TurnManager.start_mission(data)


func start_campaign() -> void:
	current_mission = 0
	campaign_record = []
	used_reinforcement_names = []
	supply_pool = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	reinforcement_pool = 0
	supply_spent = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	start_current_mission()


func advance_to_next_mission() -> void:
	current_mission += 1
	if current_mission >= missions.size():
		push_error("GameManager: No more missions.")
		return
	start_current_mission()


func consume_supplies(allocations: Dictionary) -> void:
	for squad_name in allocations:
		for supply_type in allocations[squad_name]:
			var amount = allocations[squad_name][supply_type]
			if amount > 0 and supply_pool.has(supply_type):
				supply_pool[supply_type]  -= amount
				supply_spent[supply_type] = supply_spent.get(supply_type, 0) + amount


func consume_reinforcement() -> bool:
	if reinforcement_pool <= 0:
		return false
	reinforcement_pool -= 1
	return true


func get_supply_pool() -> Dictionary:
	return supply_pool

func get_supply_spent() -> Dictionary:
	return supply_spent

func get_reinforcement_pool() -> int:
	return reinforcement_pool


func get_available_reinforcement_names() -> Array:
	var available = []
	for rname in REINFORCEMENT_NAMES:
		if not used_reinforcement_names.has(rname):
			if not SquadManager.squads.has(rname):
				available.append(rname)
	return available


func register_reinforcement_name(squad_name: String) -> void:
	if not used_reinforcement_names.has(squad_name):
		used_reinforcement_names.append(squad_name)


func queue_reinforcement(squad_name: String) -> void:
	pending_reinforcement = {
		"squad_name": squad_name,
		"sector":     "",
		"placed":     false,
	}


func place_reinforcement(sector: String) -> void:
	if pending_reinforcement.is_empty():
		return
	pending_reinforcement["sector"] = sector
	pending_reinforcement["placed"] = true


func get_pending_reinforcement() -> Dictionary:
	return pending_reinforcement

func clear_pending_reinforcement() -> void:
	pending_reinforcement = {}

func has_pending_reinforcement() -> bool:
	return not pending_reinforcement.is_empty() and pending_reinforcement.get("placed", false)


func calculate_score(held_hexes: int, turns_taken: int, win_hexes: int) -> Dictionary:
	var tile_score = int((float(held_hexes) / float(win_hexes)) * 400)
	var max_turns  = get_current_mission_data().get("turns", 5)
	var turn_bonus = int((float(max_turns - turns_taken) / float(max_turns)) * 300)
	var base_pool    = get_current_mission_data().get("supply_pool", {})
	var max_supplies = 0
	for s in base_pool: max_supplies += base_pool[s]
	var total_spent  = 0
	for s in supply_spent: total_spent += supply_spent[s]
	var supply_bonus = int((1.0 - float(total_spent) / float(max(max_supplies, 1))) * 300)
	var total = tile_score + turn_bonus + supply_bonus
	var rating = "F"
	if   total >= 900: rating = "S"
	elif total >= 700: rating = "A"
	elif total >= 500: rating = "B"
	elif total >= 300: rating = "C"
	return {
		"total":        total,
		"rating":       rating,
		"tile_score":   tile_score,
		"turn_bonus":   turn_bonus,
		"supply_bonus": supply_bonus,
	}
