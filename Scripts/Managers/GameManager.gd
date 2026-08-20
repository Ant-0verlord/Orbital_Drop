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

# Snapshot of supply_pool taken right after start_current_mission() adds
# this mission's grant on top of whatever carried over from earlier
# missions — i.e. the true total budget available this mission, not just
# this mission's own slice of it. calculate_score()'s supply_bonus scores
# against this, not the mission's base_pool alone (see note there for why
# that was scoring frugal players as if they'd blown their budget).
var mission_starting_supply: Dictionary = {}

# Guards start_current_mission()'s per-mission resource grant against
# running twice for the same mission — see the comment inside that
# function for why it's called twice per mission in the first place.
var _mission_resources_granted_for: int = -1

var reinforcement_pool: int = 0
var pending_reinforcement: Dictionary = {}
var used_reinforcement_names: Array = []
var tower_powered: bool = false
var tower_sector: String = ""
var priority_target_alive: bool = false
var priority_target_name: String = ""
var data_carrier_squad: String = ""
var extraction_zone: String = ""
var mission_type: String = "capture"  # "capture", "eliminate", "hold_tower", "extract"
var enemy_ai_mode: String = "aggressive"

var data_destroyed: bool = false
var seen_attention_events: Dictionary = {}


signal tower_activated
signal tower_lost
signal mission_advanced

# Squads Orin and Davan used to be scripted into every mission's starting
# roster — they're now reinforcement-only, so they're listed here instead
# alongside the original placeholder names. They keep their established
# identities, but only show up if actually called in.
const REINFORCEMENT_NAMES: Array = [
	"Squad Orin",
	"Squad Davan",
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
	"Psi-1B", "Omega-1B", "Alpha-1B", "Beta-1B", "Gamma-1B",
	"Delta-1B", "Epsilon-1B", "Zeta-1B", "Eta-1B", "Theta-1B",
	"Iota-1B", "Kappa-1B", "Lambda-1B", "Mu-1B", "Nu-1B",
	"Xi-1B", "Omicron-1B", "Pi-1B", "Rho-1B", "Sigma-1B",
	"Tau-1B", "Upsilon-1B", "Phi-1B", "Chi-1B", "Psi-3B",
	"Omega-3B", "Alpha-3B", "Beta-3B", "Gamma-3B", "Delta-3B",
	"Epsilon-3B", "Zeta-3B", "Eta-3B", "Theta-3B", "Iota-3B",
	"Kappa-3B", "Lambda-3B", "Mu-3B", "Nu-3B", "Xi-3B",
	"Omicron-3B", "Pi-3B", "Rho-3B", "Sigma-3B", "Tau-3B",
	"Upsilon-3B", "Phi-3B", "Chi-3B", "Psi-5B", "Omega-5B",
	"Alpha-5B", "Beta-5B", "Gamma-5B", "Delta-5B", "Epsilon-5B",
	"Zeta-5B", "Eta-5B", "Theta-5B", "Iota-5B", "Kappa-5B",
	"Lambda-5B", "Mu-5B", "Nu-5B", "Xi-5B", "Omicron-5B",
	"Pi-5B", "Rho-5B", "Sigma-5B", "Tau-5B", "Upsilon-5B",
	"Phi-5B", "Chi-5B", "Psi-7B", "Omega-7B", "Alpha-7B",
	"Beta-7B", "Gamma-7B", "Delta-7B", "Epsilon-7B", "Zeta-7B",
	"Eta-7B", "Theta-7B", "Iota-7B", "Kappa-7B", "Lambda-7B",
	"Mu-7B", "Nu-7B", "Xi-7B", "Omicron-7B", "Pi-7B",
	"Rho-7B", "Sigma-7B", "Tau-7B", "Upsilon-7B", "Phi-7B",
	"Chi-7B", "Psi-9B", "Omega-9B", "Alpha-9B", "Beta-9B",
	"Gamma-9B", "Delta-9B", "Epsilon-9B", "Zeta-9B", "Eta-9B",
	"Theta-9B", "Iota-9B", "Kappa-9B", "Lambda-9B", "Mu-9B",
	"Nu-9B", "Xi-9B", "Omicron-9B",
]

const M3_ADJACENCY = {
	0:   [1, 2, 3],
	1:   [0, 3, 4],
	2:   [0, 3, 7],
	3:   [0, 1, 2, 4, 8],
	4:   [1, 3, 8, 9],
	5:   [6, 10],
	6:   [5, 7, 10, 11],
	7:   [2, 6, 11, 12],
	8:   [3, 4, 9, 13, 14],
	9:   [4, 8, 14, 15],
	10:  [5, 6, 11, 21, 22],
	11:  [6, 7, 10, 12, 22, 23],
	12:  [7, 11, 13, 23, 24],
	13:  [8, 12, 14, 24, 25],
	14:  [8, 9, 13, 15, 25, 26],
	15:  [9, 14, 16, 26, 27],
	16:  [15, 17, 27, 28],
	17:  [16, 28],
	18:  [19, 29, 30],
	19:  [18, 20, 30, 31],
	20:  [19, 31, 32],
	21:  [10, 22, 33],
	22:  [10, 11, 21, 23, 33, 34],
	23:  [11, 12, 22, 24, 34, 35],
	24:  [12, 13, 23, 25, 35],
	25:  [13, 14, 24, 26],
	26:  [14, 15, 25, 27],
	27:  [15, 16, 26, 28, 36],
	28:  [16, 17, 27, 36, 37],
	29:  [18, 30, 38, 39],
	30:  [18, 19, 29, 31, 39, 40],
	31:  [19, 20, 30, 32, 40, 41],
	32:  [20, 31, 41, 42],
	33:  [21, 22, 34, 44, 45],
	34:  [22, 23, 33, 35, 45, 46],
	35:  [23, 24, 34, 46, 47],
	36:  [27, 28, 37, 49, 50],
	37:  [28, 36, 38, 50, 51],
	38:  [29, 37, 39, 51, 52],
	39:  [29, 30, 38, 40, 52, 53],
	40:  [30, 31, 39, 41, 53, 54],
	41:  [31, 32, 40, 42, 54, 55],
	42:  [32, 41, 55],
	43:  [44, 56],
	44:  [33, 43, 45, 56, 57],
	45:  [33, 34, 44, 46, 57, 58],
	46:  [34, 35, 45, 47, 58, 59],
	47:  [35, 46, 48, 59, 60],
	48:  [47, 60],
	49:  [36, 50, 61, 62],
	50:  [36, 37, 49, 51, 62, 63],
	51:  [37, 38, 50, 52, 63, 64],
	52:  [38, 39, 51, 53, 64, 65],
	53:  [39, 40, 52, 54, 65, 66],
	54:  [40, 41, 53, 55, 66, 67],
	55:  [41, 42, 54, 67, 68],
	56:  [43, 44, 57, 69],
	57:  [44, 45, 56, 58, 69, 70],
	58:  [45, 46, 57, 59, 70, 71],
	59:  [46, 47, 58, 60, 71, 72],
	60:  [47, 48, 59, 72, 73],
	61:  [49, 62, 74, 75],
	62:  [49, 50, 61, 63, 75, 76],
	63:  [50, 51, 62, 64, 76, 77],
	64:  [51, 52, 63, 65, 77, 78],
	65:  [52, 53, 64, 66, 78],
	66:  [53, 54, 65, 67, 79],
	67:  [54, 55, 66, 68, 79, 80],
	68:  [55, 67, 80, 81],
	69:  [56, 57, 70],
	70:  [57, 58, 69, 71],
	71:  [58, 59, 70, 72, 82],
	72:  [59, 60, 71, 73, 82, 83],
	73:  [60, 72, 74, 83],
	74:  [61, 73, 75, 84],
	75:  [61, 62, 74, 76, 84, 85],
	76:  [62, 63, 75, 77, 85, 86],
	77:  [63, 64, 76, 78, 86, 87],
	78:  [64, 65, 77, 87],
	79:  [66, 67, 80, 88],
	80:  [67, 68, 79, 81, 88],
	81:  [68, 80],
	82:  [71, 72, 83],
	83:  [72, 73, 82],
	84:  [74, 75, 85, 89],
	85:  [75, 76, 84, 86, 89, 90],
	86:  [76, 77, 85, 87, 90, 91],
	87:  [77, 78, 86, 91, 92],
	88:  [79, 80, 94, 95],
	89:  [84, 85, 90],
	90:  [85, 86, 89, 91],
	91:  [86, 87, 90, 92, 98],
	92:  [87, 91, 93, 98, 99],
	93:  [92, 94, 99, 100],
	94:  [88, 93, 95, 100, 101],
	95:  [88, 94, 96, 101, 102],
	96:  [95, 102, 103],
	97:  [104, 105],
	98:  [91, 92, 99, 106],
	99:  [92, 93, 98, 100, 106, 107],
	100: [93, 94, 99, 101, 107, 108],
	101: [94, 95, 100, 102, 108, 109],
	102: [95, 96, 101, 103, 109, 110],
	103: [96, 102, 104, 110, 111],
	104: [97, 103, 105, 111, 112],
	105: [97, 104, 112],
	106: [98, 99, 107],
	107: [99, 100, 106, 108],
	108: [100, 101, 107, 109],
	109: [101, 102, 108, 110],
	110: [102, 103, 109, 111],
	111: [103, 104, 110, 112],
	112: [104, 105, 111],
}

const M3_AXIAL = [
	Vector2(-1,-7), Vector2( 0,-7), Vector2(-2,-6), Vector2(-1,-6), Vector2( 0,-6),
	Vector2(-5,-5), Vector2(-4,-5), Vector2(-3,-5), Vector2(-1,-5), Vector2( 0,-5),
	Vector2(-5,-4), Vector2(-4,-4), Vector2(-3,-4), Vector2(-2,-4), Vector2(-1,-4),
	Vector2( 0,-4), Vector2( 1,-4), Vector2( 2,-4), Vector2( 4,-4), Vector2( 5,-4),
	Vector2( 6,-4), Vector2(-6,-3), Vector2(-5,-3), Vector2(-4,-3), Vector2(-3,-3),
	Vector2(-2,-3), Vector2(-1,-3), Vector2( 0,-3), Vector2( 1,-3), Vector2( 3,-3),
	Vector2( 4,-3), Vector2( 5,-3), Vector2( 6,-3), Vector2(-6,-2), Vector2(-5,-2),
	Vector2(-4,-2), Vector2( 0,-2), Vector2( 1,-2), Vector2( 2,-2), Vector2( 3,-2),
	Vector2( 4,-2), Vector2( 5,-2), Vector2( 6,-2), Vector2(-8,-1), Vector2(-7,-1),
	Vector2(-6,-1), Vector2(-5,-1), Vector2(-4,-1), Vector2(-3,-1), Vector2(-1,-1),
	Vector2( 0,-1), Vector2( 1,-1), Vector2( 2,-1), Vector2( 3,-1), Vector2( 4,-1),
	Vector2( 5,-1), Vector2(-8, 0), Vector2(-7, 0), Vector2(-6, 0), Vector2(-5, 0),
	Vector2(-4, 0), Vector2(-2, 0), Vector2(-1, 0), Vector2( 0, 0), Vector2( 1, 0),
	Vector2( 2, 0), Vector2( 3, 0), Vector2( 4, 0), Vector2( 5, 0), Vector2(-8, 1),
	Vector2(-7, 1), Vector2(-6, 1), Vector2(-5, 1), Vector2(-4, 1), Vector2(-3, 1),
	Vector2(-2, 1), Vector2(-1, 1), Vector2( 0, 1), Vector2( 1, 1), Vector2( 3, 1),
	Vector2( 4, 1), Vector2( 5, 1), Vector2(-6, 2), Vector2(-5, 2), Vector2(-3, 2),
	Vector2(-2, 2), Vector2(-1, 2), Vector2( 0, 2), Vector2( 3, 2), Vector2(-3, 3),
	Vector2(-2, 3), Vector2(-1, 3), Vector2( 0, 3), Vector2( 1, 3), Vector2( 2, 3),
	Vector2( 3, 3), Vector2( 4, 3), Vector2( 6, 3), Vector2(-1, 4), Vector2( 0, 4),
	Vector2( 1, 4), Vector2( 2, 4), Vector2( 3, 4), Vector2( 4, 4), Vector2( 5, 4),
	Vector2( 6, 4), Vector2(-1, 5), Vector2( 0, 5), Vector2( 1, 5), Vector2( 2, 5),
	Vector2( 3, 5), Vector2( 4, 5), Vector2( 5, 5),
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
	"Psi-1D", "Omega-1D", "Alpha-1D", "Beta-1D", "Gamma-1D",
	"Delta-1D", "Epsilon-1D", "Zeta-1D", "Eta-1D", "Theta-1D",
	"Iota-1D", "Kappa-1D", "Lambda-1D", "Mu-1D", "Nu-1D",
	"Xi-1D", "Omicron-1D", "Pi-1D", "Rho-1D", "Sigma-1D",
	"Tau-1D", "Upsilon-1D", "Phi-1D", "Chi-1D", "Psi-3D",
	"Omega-3D", "Alpha-3D", "Beta-3D", "Gamma-3D", "Delta-3D",
	"Epsilon-3D", "Zeta-3D", "Eta-3D", "Theta-3D", "Iota-3D",
	"Kappa-3D", "Lambda-3D", "Mu-3D", "Nu-3D", "Xi-3D",
	"Omicron-3D", "Pi-3D", "Rho-3D", "Sigma-3D", "Tau-3D",
	"Upsilon-3D", "Phi-3D", "Chi-3D", "Psi-5D", "Omega-5D",
	"Alpha-5D", "Beta-5D", "Gamma-5D", "Delta-5D", "Epsilon-5D",
	"Zeta-5D", "Eta-5D", "Theta-5D", "Iota-5D", "Kappa-5D",
	"Lambda-5D", "Mu-5D", "Nu-5D", "Xi-5D", "Omicron-5D",
	"Pi-5D", "Rho-5D", "Sigma-5D", "Tau-5D", "Upsilon-5D",
	"Phi-5D", "Chi-5D", "Psi-7D", "Omega-7D", "Alpha-7D",
	"Beta-7D", "Gamma-7D", "Delta-7D", "Epsilon-7D", "Zeta-7D",
	"Eta-7D", "Theta-7D", "Iota-7D", "Kappa-7D", "Lambda-7D",
	"Mu-7D", "Nu-7D", "Xi-7D", "Omicron-7D", "Pi-7D",
	"Rho-7D", "Sigma-7D", "Tau-7D", "Upsilon-7D", "Phi-7D",
	"Chi-7D", "Psi-9D", "Omega-9D", "Alpha-9D", "Beta-9D",
	"Gamma-9D", "Delta-9D", "Epsilon-9D", "Zeta-9D", "Eta-9D",
	"Theta-9D", "Iota-9D","Nu-9D",      # (5,-7)
	"Xi-9D",      # (6,-7)
	"Omicron-9D", # (6,-6)
	"Pi-9D",      # (7,-7)
	"Rho-9D",     # (7,-6)
	"Sigma-9D",   # (10,-4)
	"Tau-9D",     # (11,-5)
]

const M5_ADJACENCY = {
	0:   [1, 3],
	1:   [0, 2, 3, 4],
	2:   [1, 4, 5],
	3:   [0, 1, 4, 7],
	4:   [1, 2, 3, 5, 7, 8],
	5:   [2, 4, 6, 8, 9],
	6:   [5, 9, 10],
	7:   [3, 4, 8, 13, 14],
	8:   [4, 5, 7, 9, 14, 15],
	9:   [5, 6, 8, 10, 15, 16],
	10:  [6, 9, 16],
	11:  [12, 18, 19],
	12:  [11, 13, 19, 20],
	13:  [7, 12, 14, 20],
	14:  [7, 8, 13, 15],
	15:  [8, 9, 14, 16],
	16:  [9, 10, 15],
	17:  [18, 24, 25],
	18:  [11, 17, 19, 25],
	19:  [11, 12, 18, 20],
	20:  [12, 13, 19],
	21:  [22, 28],
	22:  [21, 23, 29],
	23:  [22, 29, 30],
	24:  [17, 25, 33, 34],
	25:  [17, 18, 24, 34],
	26:  [27, 37, 38],
	27:  [26, 38, 39],
	28:  [21],
	29:  [22, 23, 30, 40, 41],
	30:  [23, 29, 31, 41, 42],
	31:  [30, 42, 43],
	32:  [33, 46, 47],
	33:  [24, 32, 34, 47, 48],
	34:  [24, 25, 33, 48, 49],
	35:  [36, 50, 51],
	36:  [35, 51, 52],
	37:  [26, 38, 53],
	38:  [26, 27, 37, 39],
	39:  [27, 38],
	40:  [29, 41, 54, 55],
	41:  [29, 30, 40, 42, 55, 56],
	42:  [30, 31, 41, 43, 56, 57],
	43:  [31, 42, 44, 57, 58],
	44:  [43, 45, 58, 59],
	45:  [44, 46, 59, 60],
	46:  [32, 45, 47, 60, 61],
	47:  [32, 33, 46, 48, 61, 62],
	48:  [33, 34, 47, 49, 62, 63],
	49:  [34, 48, 50, 63, 64],
	50:  [35, 49, 51, 64],
	51:  [35, 36, 50, 52, 65],
	52:  [36, 51, 53, 65, 66],
	53:  [37, 52, 66, 67],
	54:  [40, 55, 68, 69],
	55:  [40, 41, 54, 56, 69, 70],
	56:  [41, 42, 55, 57, 70, 71],
	57:  [42, 43, 56, 58, 71, 72],
	58:  [43, 44, 57, 59, 72, 73],
	59:  [44, 45, 58, 60, 73],
	60:  [45, 46, 59, 61, 74],
	61:  [46, 47, 60, 62, 74, 75],
	62:  [47, 48, 61, 63, 75, 76],
	63:  [48, 49, 62, 64, 76, 77],
	64:  [49, 50, 63, 77],
	65:  [51, 52, 66],
	66:  [52, 53, 65, 67],
	67:  [53, 66],
	68:  [54, 69, 80],
	69:  [54, 55, 68, 70, 80, 81],
	70:  [55, 56, 69, 71, 81, 82],
	71:  [56, 57, 70, 72, 82, 83],
	72:  [57, 58, 71, 73, 83, 84],
	73:  [58, 59, 72, 84, 85],
	74:  [60, 61, 75, 86],
	75:  [61, 62, 74, 76, 86, 87],
	76:  [62, 63, 75, 77, 87, 88],
	77:  [63, 64, 76, 88],
	78:  [79, 93, 94],
	79:  [78, 94, 95],
	80:  [68, 69, 81],
	81:  [69, 70, 80, 82, 96],
	82:  [70, 71, 81, 83, 96, 97],
	83:  [71, 72, 82, 84, 97],
	84:  [72, 73, 83, 85],
	85:  [73, 84],
	86:  [74, 75, 87],
	87:  [75, 76, 86, 88],
	88:  [76, 77, 87, 98],
	89:  [90, 99],
	90:  [89, 91],
	91:  [90, 92, 100],
	92:  [91, 93, 100, 101],
	93:  [78, 92, 94, 101],
	94:  [78, 79, 93, 95],
	95:  [79, 94],
	96:  [81, 82, 97],
	97:  [82, 83, 96],
	98:  [88, 99, 102, 103],
	99:  [89, 98, 103, 104],
	100: [91, 92, 101],
	101: [92, 93, 100],
	102: [98, 103, 105],
	103: [98, 99, 102, 104, 105, 106],
	104: [99, 103, 106],
	105: [102, 103, 106],
	106: [103, 104, 105],107: [108, 110],          # Nu-9D (5,-7) — neighbors (6,-7) and (6,-6)
108: [107, 109, 110, 111], # Xi-9D (6,-7) — neighbors all around
109: [108, 111, 112],     # Omicron-9D (6,-6) — neighbors (6,-7),(7,-7),(7,-6)
110: [107, 108, 111, 13], # Pi-9D (7,-7) — connects to left tunnel + (7,-5) + Xi-9D
111: [109, 110, 112, 7],  # Rho-9D (7,-6) — connects to (8,-6) which is Zeta-1D
112: [113, 16],           # Sigma-9D (10,-4) — connects to Omicron-1D (10,-5)
113: [112, 10, 6],        # Tau-9D (11,-5) — connects to Iota-1D (10,-6) and Kappa-1D
}

const M5_AXIAL = [
	Vector2( 8,-8), Vector2( 9,-8), Vector2(10,-8),
	Vector2( 8,-7), Vector2( 9,-7), Vector2(10,-7), Vector2(11,-7),
	Vector2( 8,-6), Vector2( 9,-6), Vector2(10,-6), Vector2(11,-6),
	Vector2( 5,-5), Vector2( 6,-5), Vector2( 7,-5), Vector2( 8,-5),
	Vector2( 9,-5), Vector2(10,-5), Vector2( 3,-4), Vector2( 4,-4),
	Vector2( 5,-4), Vector2( 6,-4), Vector2(-7,-3), Vector2(-6,-3),
	Vector2(-5,-3), Vector2( 2,-3), Vector2( 3,-3), Vector2( 8,-3),
	Vector2( 9,-3), Vector2(-8,-2), Vector2(-6,-2), Vector2(-5,-2),
	Vector2(-4,-2), Vector2( 0,-2), Vector2( 1,-2), Vector2( 2,-2),
	Vector2( 4,-2), Vector2( 5,-2), Vector2( 7,-2), Vector2( 8,-2),
	Vector2( 9,-2), Vector2(-7,-1), Vector2(-6,-1), Vector2(-5,-1),
	Vector2(-4,-1), Vector2(-3,-1), Vector2(-2,-1), Vector2(-1,-1),
	Vector2( 0,-1), Vector2( 1,-1), Vector2( 2,-1), Vector2( 3,-1),
	Vector2( 4,-1), Vector2( 5,-1), Vector2( 6,-1), Vector2(-8, 0),
	Vector2(-7, 0), Vector2(-6, 0), Vector2(-5, 0), Vector2(-4, 0),
	Vector2(-3, 0), Vector2(-2, 0), Vector2(-1, 0), Vector2( 0, 0),
	Vector2( 1, 0), Vector2( 2, 0), Vector2( 4, 0), Vector2( 5, 0),
	Vector2( 6, 0), Vector2(-9, 1), Vector2(-8, 1), Vector2(-7, 1),
	Vector2(-6, 1), Vector2(-5, 1), Vector2(-4, 1), Vector2(-2, 1),
	Vector2(-1, 1), Vector2( 0, 1), Vector2( 1, 1), Vector2( 7, 1),
	Vector2( 8, 1), Vector2(-9, 2), Vector2(-8, 2), Vector2(-7, 2),
	Vector2(-6, 2), Vector2(-5, 2), Vector2(-4, 2), Vector2(-2, 2),
	Vector2(-1, 2), Vector2( 0, 2), Vector2( 2, 2), Vector2( 3, 2),
	Vector2( 4, 2), Vector2( 5, 2), Vector2( 6, 2), Vector2( 7, 2),
	Vector2( 8, 2), Vector2(-8, 3), Vector2(-7, 3), Vector2( 0, 3),
	Vector2( 1, 3), Vector2( 4, 3), Vector2( 5, 3), Vector2(-1, 4),
	Vector2( 0, 4), Vector2( 1, 4), Vector2(-1, 5), Vector2( 0, 5),Vector2( 5,-7),   # Nu-9D
	Vector2( 6,-7),   # Xi-9D
	Vector2( 6,-6),   # Omicron-9D
	Vector2( 7,-7),   # Pi-9D
	Vector2( 7,-6),   # Rho-9D
	Vector2(10,-4),   # Sigma-9D
	Vector2(11,-5),   # Tau-9D
]


var missions: Array = [
	{
		# Mission 1
		"mission_type":         "capture",
		"enemy_ai_mode": "aggressive",
		"has_priority_target":  false,
		"priority_target_name": "",
		"radio_tower_sector":   "",
		"title":        "Mission 1 — Planetary Insertion",
		"turns":        5,
		"win_hexes":    4,
		"interference": 0.0,
		"objective":    "Capture and hold 4 sectors by the end of Turn 5.",
		# Supply pools across all 5 missions cut well below their
		# original values (M1 was 8/6/8) -- squads' per-turn supply draw
		# is forced, not optional, so the old pools comfortably covered
		# a mission's full length. This makes running dry, and letting
		# a squad go unsupplied for a turn, a real possibility.
		#
		# All values kept even: every allocation costs a flat 2 points
		# (SUPPLY_COST in LogisticsPopup.gd), so an odd pool total
		# always left 1 point that could never actually be spent.
		#
		# Armaments kept higher than the others here specifically --
		# M1 has 3 enemies on the map plus a turn-4 reinforcement, and
		# the pool needs enough headroom to actually fight through them
		# (each armed engagement costs 2 points) rather than only
		# covering a couple of turns.
		"supply_pool":        { "Armaments": 12, "Medi-Packs": 8, "Fuel Cells": 8 },
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
		# Mission 2
		"mission_type":         "eliminate",
		"enemy_ai_mode": "aggressive",
		"has_priority_target":  false,
		"priority_target_name": "",
		"radio_tower_sector":   "",
		"title":        "Mission 2 — Advance on Kerath-IV",
		"turns":        7,
		"win_hexes":    8,
		"interference": 0.2,
		"objective":    "Secure 8 sectors. Enemy reinforcements inbound.",
		# Same headroom issue as M1, and more pressing here — this is an
		# "eliminate" mission, so ALL 5 starting enemies plus the 2 more
		# from the turn 5/6 reinforcement wave (7 total) actually need to
		# die to win, not just be pushed off sectors. Armaments bumped a
		# few points so that's realistically affordable.
		"supply_pool":        { "Armaments": 14, "Medi-Packs": 8, "Fuel Cells": 10 },
		"reinforcement_pool": 1,
		"sectors":    M2_SECTORS,
		"adjacency":  M2_ADJACENCY,
		"axial":      M2_AXIAL,
		"reinforcement_schedule": { 5: 1, 6: 1 },
		"orbital_strikes": 0,
		"squads": [
			{ "name": "Squad Varro", "sector": "Omicron-3", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Pi-7",      "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
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
	# Mission 3
	"title":             "Mission 3 — The Iron Salient",
	# Later missions (3-5) given more breathing room — 6 turns was tight
	# for powering the tower over 2 consecutive turns AND holding it
	# against wave assaults afterward.
	"turns":             8,
	"win_hexes":         0,
	"interference":      0.5,
	"mission_type":      "hold_tower",
	"enemy_ai_mode":     "wave",
	"has_priority_target": false,
	"priority_target_name": "",
	"radio_tower_sector": "Gamma-5B",
	"objective":         "Power the comms tower and hold it against enemy waves.",
	# Squads landing further north (Sigma-3B/Tau-3B) would otherwise take
	# a completely different, longer route to the tower than the ones
	# landing closer (Theta-5B/Upsilon-5B) — pure shortest-path BFS sends
	# each squad wherever's fewest hexes for THEM specifically. Routing
	# everyone through Alpha-7B first keeps the whole squad funnelling
	# down the same corridor instead of scattering across the map.
	"route_waypoint":    "Alpha-7B",
	"supply_pool":       { "Armaments": 10, "Medi-Packs": 8, "Fuel Cells": 10 },
	"reinforcement_pool": 1,
	"orbital_strikes":   1,
	"sectors":    M3_SECTORS,
	"adjacency":  M3_ADJACENCY,
	"axial":      M3_AXIAL,
	"reinforcement_schedule": { 2: 2, 3: 2, 4: 3 },
	# Both base squads drop on the far west edge, on neighbouring hexes
	# rather than stacked together. Squad count only grows from here if
	# reinforcements are called in — Theta-5B/Upsilon-5B (previously
	# Orin/Davan's scripted start) are no longer auto-occupied, so
	# there's extra room right at the landing zone for whoever's called in.
	"squads": [
		{ "name": "Squad Varro", "sector": "Sigma-3B",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
		{ "name": "Squad Kael",  "sector": "Tau-3B",     "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
	],
	# Original 9 enemies, minus Eta-5B (was boxed in and immediately
	# surrounded by the squad landing ring, giving it nothing to do) —
	# relocated to Alpha-7B instead, which sits directly on the shortest
	# path from the landing zone to the tower (confirmed by tracing the
	# actual BFS route squads path along), so it now intercepts squads
	# on the way rather than sitting trapped at the drop zone.
	# Also added Nu-3B/Delta-5B directly adjacent to the tower (Gamma-5B)
	# for a stronger perimeter, and Eta-9B/Rho-3B out on the far
	# southeast/east edges for extra map-wide spread.
	"enemies": [
		{ "sector": "Psi-1B"    },
		{ "sector": "Omega-1B"  },
		{ "sector": "Sigma-1B"  },
		{ "sector": "Gamma-3B"  },
		{ "sector": "Chi-3B"    },
		{ "sector": "Alpha-7B"  },
		{ "sector": "Pi-5B"     },
		{ "sector": "Eta-7B"    },
		{ "sector": "Lambda-7B" },
		{ "sector": "Nu-3B"     },
		{ "sector": "Delta-5B"  },
		{ "sector": "Eta-9B"    },
		{ "sector": "Rho-3B"    },
	],
	},
		{
		# Mission 4
		"mission_type":         "eliminate_priority",
		# Was "defensive" — a mode that made enemies hold position while
		# Vreth lived, then flip to specifically hunting down the data
		# carrier once he fell. That carrier-hunt no longer matches how
		# this mission is won (see win-check below), so enemies just use
		# the standard/default combat AI throughout, same as M1/M2.
		"enemy_ai_mode": "aggressive",
		"has_priority_target":  true,
		"priority_target_name": "Commander Vreth",
		"radio_tower_sector":   "Beta-5C",   # central cave sector — adjust after testing
		"title":        "Mission 4 — Contested Hive Spire",
		"turns":        12,
		"win_hexes":    55,
		"interference": 0.75,
		# Win condition: eliminate Vreth, then take and power the relay
		# tower — that's what pinpoints the extraction zone for Mission 5.
		# No requirement anymore for the data carrier to put distance
		# between itself and the remaining enemy forces.
		"objective":    "Locate and eliminate Commander Vreth, then take and power the relay tower to pinpoint an extraction zone.",
		# Bumped up across the board — this is the longest mission (10
		# turns), has the most enemies on the map (17), and now always
		# splits at least one squad off to hunt the priority target
		# separately from whoever's on tower duty, so demand on the pool
		# is genuinely higher than the other missions.
		"supply_pool":        { "Armaments": 14, "Medi-Packs": 12, "Fuel Cells": 14 },
		"reinforcement_pool": 1,
		"orbital_strikes":    2,
		"sectors":    M4_SECTORS,
		"adjacency":  M4_ADJACENCY,
		"axial":      M4_AXIAL,
		"reinforcement_schedule": { 5: 1, 7: 2 },
		"squads": [
			{ "name": "Squad Varro", "sector": "Rho-3C",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Mu-5C",    "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
		],
		"enemies": [
			{ "sector": "Beta-5C"    },  # Commander Vreth
			{ "sector": "Upsilon-1C" },
			{ "sector": "Phi-1C"     },
			{ "sector": "Chi-1C"     },
			{ "sector": "Theta-3C"   },
			{ "sector": "Iota-3C"    },
			{ "sector": "Kappa-3C"   },
			{ "sector": "Lambda-3C"  },
			{ "sector": "Gamma-5C", "is_priority": true    },
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
		# Mission 5
		"title":              "Mission 5 — Final Assault",
	"turns":              16,
	"win_hexes":          0,
	"interference":       0.9,
	"mission_type":       "extract",
	"enemy_ai_mode":      "rush_extraction",
	"has_priority_target": false,
	"priority_target_name": "",
	"radio_tower_sector": "",
	"objective":          "Hold the theatre around the extraction zone. Once the shuttle is inbound, all squads converge to board.",
	"extraction_sector":  "Beta-1D",
	# Bumped up a bit like M4 — final mission, enemies rushing the
	# extraction zone from multiple vectors, worth having some buffer
	# left to fight through rather than running dry right before the end.
	"supply_pool":        { "Armaments": 14, "Medi-Packs": 12, "Fuel Cells": 14 },
	"reinforcement_pool": 1,
	"orbital_strikes":    1,
	"sectors":    M5_SECTORS,
	"adjacency":  M5_ADJACENCY,
	"axial":      M5_AXIAL,
	"reinforcement_schedule": { 3: 2, 5: 3 },
	# Both base squads drop together in the far bottom-left corner of the
	# map, on neighbouring hexes rather than stacked. Upsilon-5D/Theta-7D
	# (previously Orin/Davan's scripted start) are free for whoever's
	# called in as a reinforcement to land near the rest of the group.
	"squads": [
		{ "name": "Squad Varro", "sector": "Eta-7D",     "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
		{ "name": "Squad Kael",  "sector": "Tau-5D",     "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
	],
	"enemies": [
		{ "sector": "Omega-3D"   },
		{ "sector": "Alpha-3D"   },
		{ "sector": "Beta-3D"    },
		{ "sector": "Sigma-3D"   },
		{ "sector": "Tau-3D"     },
		{ "sector": "Upsilon-3D" },
		{ "sector": "Phi-3D"     },
		{ "sector": "Omega-1D"   },
		{ "sector": "Beta-1D"    },
		{ "sector": "Tau-1D"     },
		{ "sector": "Xi-5D"      },
		# The tunnel network (Nu-9D through Tau-9D) isn't reachable from
		# the open map by normal pathing — enemies posted here don't sit
		# on any squad's route, they only surface at their tunnel's exit
		# hex once they move, so they read as an ambush instead of a
		# roadblock.
		{ "sector": "Nu-9D"      },  # tunnel entry -> exits near Mu-1D
		{ "sector": "Xi-9D"      },  # tunnel -> exits near Mu-1D/Zeta-1D
		{ "sector": "Omicron-9D" },  # tunnel -> exits near Zeta-1D/Sigma-9D
		{ "sector": "Pi-9D"      },  # tunnel -> exits at Mu-1D
		{ "sector": "Rho-9D"     },  # tunnel -> exits at Zeta-1D
		{ "sector": "Sigma-9D"   },  # tunnel -> exits at Omicron-1D
		{ "sector": "Tau-9D"     },  # tunnel -> exits at Iota-1D/Epsilon-1D
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
	data_destroyed = false
	var data = get_current_mission_data()
	orbital_strikes_pool = data.get("orbital_strikes", 0)
	if data.is_empty():
		push_error("GameManager: No mission data for index %d" % current_mission)
		return

	for key in seen_attention_events.keys():
		if key.begins_with("mission_"):
			seen_attention_events.erase(key)

	enemy_ai_mode = data.get("enemy_ai_mode", "aggressive")
	pending_reinforcement = {}
	# Bombardment status ("Strike resolved at ...") was never cleared between
	# missions here — only pending_reinforcement was — so a resolved strike
	# from a previous mission kept showing as "resolved" in the Logistics
	# Terminal on every mission after it, overlapping with the fresh state.
	pending_bombardment = {}
	tower_powered = false
	tower_sector = data.get("radio_tower_sector", "")
	priority_target_alive = data.get("has_priority_target", false)
	priority_target_name = data.get("priority_target_name", "")
	mission_type = data.get("mission_type", "capture")
	# data_carrier_squad and extraction_zone NOT reset here —
	# data_carrier carries across missions, extraction_zone set dynamically later

	# CommandCentre calls start_current_mission() twice per mission: once
	# to prep data for the briefing screen, again when the briefing is
	# dismissed and the mission actually starts. Without this guard, the
	# per-mission supply and reinforcement grants below ran twice — every
	# mission silently handed out double supplies, which is also what was
	# quietly wrecking the supply_bonus score (see calculate_score) since
	# that scores against a single mission's intended grant.
	if _mission_resources_granted_for != current_mission:
		_mission_resources_granted_for = current_mission

		var base_pool = data.get("supply_pool", { "Armaments": 8, "Medi-Packs": 4, "Fuel Cells": 4 })
		for s in base_pool:
			supply_pool[s] = supply_pool.get(s, 0) + base_pool[s]
		mission_starting_supply = supply_pool.duplicate()

		reinforcement_pool += data.get("reinforcement_pool", 0)
		supply_spent = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }

	# Actually starting the mission's turn loop (squad/enemy init, turn 1)
	# is CommandCentre._start_mission()'s job, called once the briefing is
	# dismissed — not this function's, which briefing-prep also calls.

func debug_jump_to_mission(index: int) -> void:
	data_destroyed = false
	if index < 0 or index >= missions.size():
		return

	enemy_ai_mode = "aggressive"
	current_mission = index
	supply_pool   = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	supply_spent  = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	mission_starting_supply  = {}
	_mission_resources_granted_for = -1
	reinforcement_pool      = 0
	orbital_strikes_pool    = 0
	pending_reinforcement   = {}
	pending_bombardment     = {}
	used_reinforcement_names = []
	tower_powered = false
	tower_sector = ""
	priority_target_alive = false
	priority_target_name = ""
	data_carrier_squad = ""
	extraction_zone = ""
	mission_type = "capture"

	# has_data is a per-squad flag that's deliberately NOT cleared by a
	# normal mission transition (see SquadManager.init_squads) — the whole
	# point is that it carries the data forward from Mission 4 into
	# Mission 5. But debug-jumping around out of order (e.g. testing
	# Mission 5 — which stamps has_data onto its first squad below — then
	# jumping back to Mission 4) left that flag stuck on whichever squad
	# last got it, showing them as already carrying data (📦) before
	# Vreth's even been touched, and quietly excluding them from ever
	# being picked to hunt him (see SquadManager._assign_goals). Debug
	# jumps need a clean slate every time, unlike a real campaign run.
	for squad_name in SquadManager.squads:
		SquadManager.squads[squad_name]["has_data"] = false

	# Mission 5's extract objective needs a squad already carrying the
	# intel — normally that's whoever eliminates Vreth mid-Mission-4, but
	# debug-jumping straight to Mission 5 skips that entirely. Hand it to
	# the mission's first scripted squad so the mission is testable on
	# its own; SquadManager picks this up when it builds the roster.
	if index == 4:
		var jump_squads = missions[index].get("squads", [])
		if jump_squads.size() > 0:
			data_carrier_squad = jump_squads[0].name

	# Same as advance_to_next_mission() — let CommandCentre show the
	# briefing/dossier rather than dropping straight into gameplay.
	emit_signal("mission_advanced")
	print("DEBUG: Jumped to mission %d — %s" % [index, missions[index].get("title", "")])

func start_campaign() -> void:
	current_mission = 0
	campaign_record = []
	used_reinforcement_names = []
	supply_pool = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	reinforcement_pool = 0
	supply_spent = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	mission_starting_supply = {}
	_mission_resources_granted_for = -1
	start_current_mission()


func advance_to_next_mission() -> void:
	current_mission += 1
	if current_mission >= missions.size():
		push_error("GameManager: No more missions.")
		return
	# Don't start the mission directly — let CommandCentre show the
	# briefing/dossier first, same as it does for mission 1. It calls
	# start_current_mission() itself once the player dismisses it.
	emit_signal("mission_advanced")


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


func queue_reinforcement(squad_name: String) -> bool:
	if not pending_bombardment.is_empty():
		return false  # mutual exclusion with bombardment
	pending_reinforcement = { "squad_name": squad_name, "sector": "", "placed": false }
	return true


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


func calculate_score(held_hexes: int, turns_taken: int, win_hexes: int, mission_won: bool = false) -> Dictionary:
	# win_hexes is legitimately 0 for non-capture mission types (hold_tower,
	# eliminate_priority, extract) — tile-count scoring just doesn't apply
	# to them. Dividing by it produced +-inf, and casting that to int gave
	# the int64 "indefinite" sentinel (-9223372036854775808), which then
	# wrecked the total score and the S/A/B/C rating entirely.
	var tile_score = 0
	if win_hexes > 0:
		tile_score = int((float(held_hexes) / float(win_hexes)) * 400)
	var max_turns  = get_current_mission_data().get("turns", 5)
	var turn_bonus = int((float(max_turns - turns_taken) / float(max_turns)) * 300)
	# Score against the pool actually available this mission (this
	# mission's own grant PLUS whatever carried over from being frugal in
	# earlier missions) — not just this mission's slice of it. Scoring
	# against the slice alone punished players for spending banked supply
	# they legitimately had on hand, on top of double-counting effects
	# from the resource-grant bug fixed in start_current_mission().
	var max_supplies = 0
	for s in mission_starting_supply: max_supplies += mission_starting_supply[s]
	var total_spent  = 0
	for s in supply_spent: total_spent += supply_spent[s]
	var supply_bonus = int((1.0 - float(total_spent) / float(max(max_supplies, 1))) * 300)
	# Clamp to the same +-300 range turn_bonus already operates in — an
	# unbounded penalty let a single overspent mission wipe out an
	# otherwise clean win's tile/turn bonuses and bury the total in
	# negative numbers for a mission that was, in gameplay terms, a win.
	supply_bonus = clampi(supply_bonus, -300, 300)
	var total = tile_score + turn_bonus + supply_bonus
	var rating = "F"
	if   total >= 900: rating = "S"
	elif total >= 700: rating = "A"
	elif total >= 500: rating = "B"
	elif total >= 300: rating = "C"
	elif mission_won:
		# F is meant to mean "failed the mission" — a mission that actually
		# succeeded (tower held, target eliminated, extraction made, etc.)
		# could still land under 300 here on missions where win_hexes is 0
		# (tile_score is forced to 0 for those — see above) and turn/supply
		# bonuses alone don't clear the C threshold. That showed up as an
		# "F" grade on a screen literally titled "MISSION COMPLETE", which
		# reads as a bug/contradiction rather than a low score. Floor a win
		# at the lowest passing grade instead — F stays reserved for
		# missions that were actually lost.
		rating = "C"
	return {
		"total":        total,
		"rating":       rating,
		"tile_score":   tile_score,
		"turn_bonus":   turn_bonus,
		"supply_bonus": supply_bonus,
	}

func calculate_extraction_bonus() -> Dictionary:
	var ez = extraction_zone
	var extracted_count = 0
	var data_extracted = false

	if data_destroyed:
		# Data was destroyed by orbital strike — can't be extracted
		for squad_name in SquadManager.squads:
			var squad = SquadManager.squads[squad_name]
			if squad.status != SquadManager.Status.LOST and squad.sector == ez:
				extracted_count += 1
		return {
			"extracted_count": extracted_count,
			"data_extracted":  false,
			"data_destroyed":  true,
			"bonus":           extracted_count * 80,
		}

	for squad_name in SquadManager.squads:
		var squad = SquadManager.squads[squad_name]
		if squad.status == SquadManager.Status.LOST:
			continue
		if squad.sector == ez:
			extracted_count += 1
			if squad.get("has_data", false):
				data_extracted = true

	var bonus = extracted_count * 80
	if data_extracted:
		bonus += 200

	return {
		"extracted_count": extracted_count,
		"data_extracted":  data_extracted,
		"data_destroyed":  false,
		"bonus":           bonus,
	}

func has_armed_bombardment() -> bool:
	return not pending_bombardment.is_empty() and pending_bombardment.get("placed", false)

func has_seen_attention(event_key: String) -> bool:
	return seen_attention_events.get(event_key, false)

func mark_attention_seen(event_key: String) -> void:
	seen_attention_events[event_key] = true

func progress_tower_power(squad_name: String) -> void:
	# Called when a squad spends a fuel turn at the tower
	# Tracked per-squad in SquadManager, resolution happens in SquadManager
	pass  # intentionally thin — actual tracking is in squad.tower_fuel_turns

func activate_tower() -> void:
	tower_powered = true
	emit_signal("tower_activated")

# Called once per turn, after combat/movement resolves, to check whether
# the enemy has actually taken the tower sector. Being powered used to be
# permanent once activated — nothing ever re-checked who controls the
# tile, so an enemy that fought its way onto it never actually cost you
# anything. Losing the sector now costs the power immediately; squads
# have to retake and re-power it from scratch.
func check_tower_still_held() -> void:
	if tower_sector == "" or not tower_powered:
		return
	if EnemyManager.get_hex_control().get(tower_sector, "") == "enemy":
		tower_powered = false
		SquadManager.reset_tower_progress()
		emit_signal("tower_lost")
