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

func get_current_mission_data() -> Dictionary:
	if current_mission < missions.size():
		return missions[current_mission]
	return {}

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
	"Psi-1B", "Omega-1B", "Alpha-1B", "Beta-1B", "Gamma-1B", "Delta-1B", "Epsilon-1B",
	"Zeta-1B", "Eta-1B", "Theta-1B", "Iota-1B", "Kappa-1B", "Lambda-1B", "Mu-1B",
	"Nu-1B", "Xi-1B", "Omicron-1B", "Pi-1B", "Rho-1B", "Sigma-1B", "Tau-1B",
	"Upsilon-1B", "Phi-1B", "Chi-1B", "Psi-3B", "Omega-3B", "Alpha-3B", "Beta-3B",
	"Gamma-3B", "Delta-3B", "Epsilon-3B", "Zeta-3B", "Eta-3B", "Theta-3B", "Iota-3B",
	"Kappa-3B", "Lambda-3B", "Mu-3B", "Nu-3B", "Xi-3B", "Omicron-3B",
]

const M3_ADJACENCY = {
	0:  [1, 2, 10, 11, 14],
	1:  [0, 11, 12],
	2:  [0, 4, 14, 16],
	3:  [15, 17],
	4:  [2, 5, 16, 18, 20],
	5:  [4, 7, 20, 22],
	6:  [9, 21, 23],
	7:  [5, 8, 22, 24, 25],
	8:  [7, 9, 25, 26],
	9:  [6, 8, 23, 26, 27],
	10: [0, 11, 14, 28],
	11: [0, 1, 10, 12, 28, 29],
	12: [1, 11, 13, 29, 30],
	13: [12, 15, 30, 31, 32],
	14: [0, 2, 10, 16],
	15: [3, 13, 17, 32, 33],
	16: [2, 4, 14, 18],
	17: [3, 15, 19, 33],
	18: [4, 16, 20, 34],
	19: [17, 21],
	20: [4, 5, 18, 22, 34, 35],
	21: [6, 19, 23],
	22: [5, 7, 20, 24, 35, 36],
	23: [6, 9, 21, 27],
	24: [7, 22, 25, 36, 37, 38],
	25: [7, 8, 24, 26, 38, 39],
	26: [8, 9, 25, 27, 39, 40],
	27: [9, 23, 26, 40],
	28: [10, 11, 29],
	29: [11, 12, 28, 30],
	30: [12, 13, 29, 31],
	31: [13, 30, 32],
	32: [13, 15, 31, 33],
	33: [15, 17, 32],
	34: [18, 20, 35],
	35: [20, 22, 34, 36],
	36: [22, 24, 35, 37],
	37: [24, 36, 38],
	38: [24, 25, 37, 39],
	39: [25, 26, 38, 40],
	40: [26, 27, 39],
}

const M3_AXIAL = [
	Vector2(-2,  0), Vector2(-2,  1), Vector2(-1, -1), Vector2(-1,  2), Vector2( 0, -2),
	Vector2( 1, -2), Vector2( 1,  1), Vector2( 2, -2), Vector2( 2, -1), Vector2( 2,  0),
	Vector2(-3,  0), Vector2(-3,  1), Vector2(-3,  2), Vector2(-3,  3), Vector2(-2, -1),
	Vector2(-2,  3), Vector2(-1, -2), Vector2(-1,  3), Vector2( 0, -3), Vector2( 0,  3),
	Vector2( 1, -3), Vector2( 1,  2), Vector2( 2, -3), Vector2( 2,  1), Vector2( 3, -3),
	Vector2( 3, -2), Vector2( 3, -1), Vector2( 3,  0), Vector2(-4,  1), Vector2(-4,  2),
	Vector2(-4,  3), Vector2(-4,  4), Vector2(-3,  4), Vector2(-2,  4), Vector2( 1, -4),
	Vector2( 2, -4), Vector2( 3, -4), Vector2( 4, -4), Vector2( 4, -3), Vector2( 4, -2),
	Vector2( 4, -1),
]

# =============================================================
# MISSION 4 — Contested Hive Spire
# 22 sectors, pincer shape
# =============================================================
# =============================================================
# MISSION 4 — Contested Hive Spire
# 103 sectors, cave maze, two entrances
# =============================================================
const M4_SECTORS = [
	"Psi-1C", "Omega-1C", "Alpha-1C", "Beta-1C", "Gamma-1C", "Delta-1C",
	"Epsilon-1C", "Zeta-1C", "Eta-1C", "Theta-1C", "Iota-1C", "Kappa-1C",
	"Lambda-1C", "Mu-1C", "Nu-1C", "Xi-1C", "Omicron-1C", "Pi-1C",
	"Rho-1C", "Sigma-1C", "Tau-1C", "Upsilon-1C", "Phi-1C", "Chi-1C",
	"Psi-3C", "Omega-3C", "Alpha-3C", "Beta-3C", "Gamma-3C", "Delta-3C",
	"Epsilon-3C", "Zeta-3C", "Eta-3C", "Theta-3C", "Iota-3C", "Kappa-3C",
	"Lambda-3C", "Mu-3C", "Nu-3C", "Xi-3C", "Omicron-3C", "Pi-3C",
	"Rho-3C", "Sigma-3C", "Tau-3C", "Upsilon-3C", "Phi-3C", "Chi-3C",
	"Psi-5C", "Omega-5C", "Alpha-5C", "Beta-5C", "Gamma-5C", "Delta-5C",
	"Epsilon-5C", "Zeta-5C", "Eta-5C", "Theta-5C", "Iota-5C", "Kappa-5C",
	"Lambda-5C", "Mu-5C", "Nu-5C", "Xi-5C", "Omicron-5C", "Pi-5C",
	"Rho-5C", "Sigma-5C", "Tau-5C", "Upsilon-5C", "Phi-5C", "Chi-5C",
	"Psi-7C", "Omega-7C", "Alpha-7C", "Beta-7C", "Gamma-7C", "Delta-7C",
	"Epsilon-7C", "Zeta-7C", "Eta-7C", "Theta-7C", "Iota-7C", "Kappa-7C",
	"Lambda-7C", "Mu-7C", "Nu-7C", "Xi-7C", "Omicron-7C", "Pi-7C",
	"Rho-7C", "Sigma-7C", "Tau-7C", "Upsilon-7C", "Phi-7C", "Chi-7C",
	"Psi-9C", "Omega-9C", "Alpha-9C", "Beta-9C", "Gamma-9C", "Delta-9C",
	"Epsilon-9C",
]

const M4_ADJACENCY = {
	0:  [1, 4, 5],
	1:  [0, 2, 5],
	2:  [1],
	3:  [4, 9],
	4:  [0, 3, 5, 10],
	5:  [0, 1, 4, 10, 11],
	6:  [7, 15, 16],
	7:  [6, 8, 16],
	8:  [7],
	9:  [3, 17, 18],
	10: [4, 5, 11, 19],
	11: [5, 10, 12, 20],
	12: [11, 13, 20, 21],
	13: [12, 14, 21, 22],
	14: [13, 15, 22, 23],
	15: [6, 14, 16, 23, 24],
	16: [6, 7, 15, 24, 25],
	17: [9, 18, 29, 30],
	18: [9, 17, 19, 30, 31],
	19: [10, 18, 31],
	20: [11, 12, 21, 32, 33],
	21: [12, 13, 20, 22, 33, 34],
	22: [13, 14, 21, 23, 34, 35],
	23: [14, 15, 22, 24, 35, 36],
	24: [15, 16, 23, 25, 36, 37],
	25: [16, 24, 26, 37, 38],
	26: [25, 27, 38],
	27: [26],
	28: [42, 43],
	29: [17, 30, 44, 45],
	30: [17, 18, 29, 31, 45, 46],
	31: [18, 19, 30, 46, 47],
	32: [20, 33, 48, 49],
	33: [20, 21, 32, 34, 49, 50],
	34: [21, 22, 33, 35, 50, 51],
	35: [22, 23, 34, 36, 51, 52],
	36: [23, 24, 35, 37, 52, 53],
	37: [24, 25, 36, 38, 53, 54],
	38: [25, 26, 37, 54, 55],
	39: [40, 57, 58],
	40: [39, 41, 58, 59],
	41: [40, 59, 60],
	42: [28, 43, 61],
	43: [28, 42, 44, 61, 62],
	44: [29, 43, 45, 62, 63],
	45: [29, 30, 44, 46, 63],
	46: [30, 31, 45, 47],
	47: [31, 46, 48, 64],
	48: [32, 47, 49, 64, 65],
	49: [32, 33, 48, 50, 65, 66],
	50: [33, 34, 49, 51, 66, 67],
	51: [34, 35, 50, 52, 67, 68],
	52: [35, 36, 51, 53, 68, 69],
	53: [36, 37, 52, 54, 69, 70],
	54: [37, 38, 53, 55, 70],
	55: [38, 54, 56, 71],
	56: [55, 57, 71, 72],
	57: [39, 56, 58, 72, 73],
	58: [39, 40, 57, 59, 73],
	59: [40, 41, 58, 60, 74],
	60: [41, 59, 74],
	61: [42, 43, 62],
	62: [43, 44, 61, 63],
	63: [44, 45, 62],
	64: [47, 48, 65, 76, 77],
	65: [48, 49, 64, 66, 77, 78],
	66: [49, 50, 65, 67, 78, 79],
	67: [50, 51, 66, 68, 79, 80],
	68: [51, 52, 67, 69, 80, 81],
	69: [52, 53, 68, 70, 81, 82],
	70: [53, 54, 69, 82, 83],
	71: [55, 56, 72, 84, 85],
	72: [56, 57, 71, 73, 85],
	73: [57, 58, 72],
	74: [59, 60],
	75: [76],
	76: [64, 75, 77],
	77: [64, 65, 76, 78, 86],
	78: [65, 66, 77, 79, 86, 87],
	79: [66, 67, 78, 80, 87, 88],
	80: [67, 68, 79, 81, 88, 89],
	81: [68, 69, 80, 82, 89, 90],
	82: [69, 70, 81, 83, 90],
	83: [70, 82, 84],
	84: [71, 83, 85, 91],
	85: [71, 72, 84, 91, 92],
	86: [77, 78, 87, 94],
	87: [78, 79, 86, 88, 94],
	88: [79, 80, 87, 89],
	89: [80, 81, 88, 90],
	90: [81, 82, 89, 95],
	91: [84, 85, 92],
	92: [85, 91, 93],
	93: [92, 97],
	94: [86, 87],
	95: [90, 96, 100],
	96: [95, 101],
	97: [93],
	98: [99],
	99: [98, 100],
	100: [95, 99],
	101: [96, 102],
	102: [101],
}

const M4_AXIAL = [
	Vector2( -1, -5), Vector2(  0, -5), Vector2(  1, -5),
	Vector2( -3, -4), Vector2( -2, -4), Vector2( -1, -4),
	Vector2(  4, -4), Vector2(  5, -4), Vector2(  6, -4),
	Vector2( -4, -3), Vector2( -2, -3), Vector2( -1, -3),
	Vector2(  0, -3), Vector2(  1, -3), Vector2(  2, -3),
	Vector2(  3, -3), Vector2(  4, -3), Vector2( -5, -2),
	Vector2( -4, -2), Vector2( -3, -2), Vector2( -1, -2),
	Vector2(  0, -2), Vector2(  1, -2), Vector2(  2, -2),
	Vector2(  3, -2), Vector2(  4, -2), Vector2(  5, -2),
	Vector2(  6, -2), Vector2( -8, -1), Vector2( -6, -1),
	Vector2( -5, -1), Vector2( -4, -1), Vector2( -2, -1),
	Vector2( -1, -1), Vector2(  0, -1), Vector2(  1, -1),
	Vector2(  2, -1), Vector2(  3, -1), Vector2(  4, -1),
	Vector2(  7, -1), Vector2(  8, -1), Vector2(  9, -1),
	Vector2( -9,  0), Vector2( -8,  0), Vector2( -7,  0),
	Vector2( -6,  0), Vector2( -5,  0), Vector2( -4,  0),
	Vector2( -3,  0), Vector2( -2,  0), Vector2( -1,  0),
	Vector2(  0,  0), Vector2(  1,  0), Vector2(  2,  0),
	Vector2(  3,  0), Vector2(  4,  0), Vector2(  5,  0),
	Vector2(  6,  0), Vector2(  7,  0), Vector2(  8,  0),
	Vector2(  9,  0), Vector2( -9,  1), Vector2( -8,  1),
	Vector2( -7,  1), Vector2( -4,  1), Vector2( -3,  1),
	Vector2( -2,  1), Vector2( -1,  1), Vector2(  0,  1),
	Vector2(  1,  1), Vector2(  2,  1), Vector2(  4,  1),
	Vector2(  5,  1), Vector2(  6,  1), Vector2(  8,  1),
	Vector2( -6,  2), Vector2( -5,  2), Vector2( -4,  2),
	Vector2( -3,  2), Vector2( -2,  2), Vector2( -1,  2),
	Vector2(  0,  2), Vector2(  1,  2), Vector2(  2,  2),
	Vector2(  3,  2), Vector2(  4,  2), Vector2( -4,  3),
	Vector2( -3,  3), Vector2( -2,  3), Vector2( -1,  3),
	Vector2(  0,  3), Vector2(  3,  3), Vector2(  4,  3),
	Vector2(  5,  3), Vector2( -4,  4), Vector2(  0,  4),
	Vector2(  1,  4), Vector2(  5,  4), Vector2( -3,  5),
	Vector2( -2,  5), Vector2( -1,  5), Vector2(  1,  5),
	Vector2(  2,  5),
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
		"orbital_strikes": 0,
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
		"orbital_strikes": 0,
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
	"win_hexes":    22,
	"interference": 0.5,
	"objective":    "Hold 22 sectors against a reinforced enemy push.",
	"supply_pool":        { "Armaments": 10, "Medi-Packs": 8, "Fuel Cells": 10 },
	"reinforcement_pool": 1,
	"orbital_strikes":    1,
	"sectors":    M3_SECTORS,
	"adjacency":  M3_ADJACENCY,
	"axial":      M3_AXIAL,
	"reinforcement_schedule": { 3: 1, 4: 2 },
	"squads": [
		{ "name": "Squad Varro", "sector": "Psi-1B",  "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
		{ "name": "Squad Kael",  "sector": "Omega-1B","status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
		{ "name": "Squad Orin",  "sector": "Nu-1B",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
		{ "name": "Squad Davan", "sector": "Iota-1B", "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
	],
	"enemies": [
		{ "sector": "Theta-1B"   },
		{ "sector": "Sigma-1B"   },
		{ "sector": "Beta-3B"    },
		{ "sector": "Theta-3B"   },
		{ "sector": "Mu-3B"      },
		{ "sector": "Omicron-3B" },
	],
	},
		{
		"title":        "Mission 4 — Contested Hive Spire",
		"turns":        10,
		"win_hexes":    55,
		"interference": 0.75,
		"objective":    "Push through the cave network and hold 55 sectors. Comms are failing.",
		"supply_pool":        { "Armaments": 12, "Medi-Packs": 10, "Fuel Cells": 12 },
		"reinforcement_pool": 1,
		"orbital_strikes":    1,
		"sectors":    M4_SECTORS,
		"adjacency":  M4_ADJACENCY,
		"axial":      M4_AXIAL,
		"reinforcement_schedule": { 5: 1, 7: 2 },
		"squads": [
			{ "name": "Squad Varro", "sector": "Rho-3C",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Mu-5C",    "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Omicron-3C","status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Kappa-5C", "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
		],
		"enemies": [
			{ "sector": "Upsilon-1C" },
			{ "sector": "Phi-1C"     },
			{ "sector": "Chi-1C"     },
			{ "sector": "Theta-3C"   },
			{ "sector": "Iota-3C"    },
			{ "sector": "Kappa-3C"   },
			{ "sector": "Lambda-3C"  },
			{ "sector": "Beta-5C"    },
			{ "sector": "Gamma-5C"   },
			{ "sector": "Delta-5C"   },
			{ "sector": "Alpha-5C"   },
			{ "sector": "Omega-5C"   },
			{ "sector": "Sigma-5C"   },
			{ "sector": "Tau-5C"     },
			{ "sector": "Zeta-7C"    },
			{ "sector": "Eta-7C"     },
			{ "sector": "Theta-7C"   },
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
		"orbital_strikes": 0,
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

func get_current_axial_map() -> Dictionary:
	var data = get_current_mission_data()
	var sectors = data.get("sectors", [])
	var axial   = data.get("axial", [])
	var map: Dictionary = {}
	for i in range(min(sectors.size(), axial.size())):
		map[sectors[i]] = axial[i]
	return map

var orbital_strikes_pool: int = 0
var pending_bombardment: Dictionary = {}

func consume_orbital_strike() -> bool:
	if orbital_strikes_pool <= 0:
		return false
	orbital_strikes_pool -= 1
	return true

func get_orbital_strikes_pool() -> int:
	return orbital_strikes_pool

func queue_bombardment() -> bool:
	if not pending_reinforcement.is_empty():
		return false  # mutual exclusion with reinforcement
	pending_bombardment = { "sector": "", "placed": false }
	return true

func place_bombardment(sector: String) -> void:
	if pending_bombardment.is_empty():
		return
	pending_bombardment["sector"] = sector
	pending_bombardment["placed"] = true

func get_pending_bombardment() -> Dictionary:
	return pending_bombardment

func clear_pending_bombardment() -> void:
	pending_bombardment = {}

func has_pending_bombardment() -> bool:
	return not pending_bombardment.is_empty()


func start_current_mission() -> void:
	var data = get_current_mission_data()
	orbital_strikes_pool = data.get("orbital_strikes", 0)
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

func debug_jump_to_mission(index: int) -> void:
	if index < 0 or index >= missions.size():
		return

	current_mission = index
	supply_pool   = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	supply_spent  = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	reinforcement_pool      = 0
	orbital_strikes_pool    = 0
	pending_reinforcement   = {}
	pending_bombardment     = {}
	used_reinforcement_names = []

	start_current_mission()
	print("DEBUG: Jumped to mission %d — %s" % [index, missions[index].get("title", "")])

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
	if not pending_bombardment.is_empty():
		return
	pending_reinforcement = { "squad_name": squad_name, "sector": "", "placed": false }


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

func has_armed_bombardment() -> bool:
	return not pending_bombardment.is_empty() and pending_bombardment.get("placed", false)
