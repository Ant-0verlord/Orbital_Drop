extends Node
# =============================================================
# GameManager.gd  —  AutoLoad singleton
# AutoLoad order: SquadManager, TurnManager, GameManager, EnemyManager
# =============================================================

var current_mission: int = 0
var campaign_record: Array = []

var missions: Array = [
	{
		"title":         "Mission 1 — Planetary Insertion",
		"turns":         3,
		"budget":        8,
		"interference":  0.0,
		"objective":     "Hold at least 4 sectors by end of Turn 3.",
		"win_hexes":     4,   # Number of held hexes needed to win
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
		],
		# Enemies start 3 hops from squad sectors
		"enemies": [
			{ "sector": "Kappa-1"  },  # 3 hops from Alpha-7
			{ "sector": "Lambda-4" },  # 3 hops from Alpha-7
		],
	},
	{
		"title":         "Mission 2 — Advance on Kerath-IV",
		"turns":         4,
		"budget":        10,
		"interference":  0.2,
		"objective":     "Hold at least 5 sectors by end of Turn 4.",
		"win_hexes":     5,
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
		],
		"enemies": [
			{ "sector": "Kappa-1"  },
			{ "sector": "Lambda-4" },
			{ "sector": "Mu-6"     },
		],
	},
	{
		"title":         "Mission 3 — The Iron Salient",
		"turns":         4,
		"budget":        10,
		"interference":  0.5,
		"objective":     "Hold at least 6 sectors. Do not let the salient break.",
		"win_hexes":     6,
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Delta-9", "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
		],
		"enemies": [
			{ "sector": "Iota-8"   },
			{ "sector": "Kappa-1"  },
			{ "sector": "Lambda-4" },
			{ "sector": "Mu-6"     },
		],
	},
	{
		"title":         "Mission 4 — Contested Hive Spire",
		"turns":         5,
		"budget":        10,
		"interference":  0.75,
		"objective":     "Hold the Hive Spire approaches. 7 sectors required.",
		"win_hexes":     7,
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Delta-9", "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
		],
		"enemies": [
			{ "sector": "Theta-3"  },
			{ "sector": "Iota-8"   },
			{ "sector": "Kappa-1"  },
			{ "sector": "Lambda-4" },
			{ "sector": "Mu-6"     },
		],
	},
	{
		"title":         "Mission 5 — Final Assault",
		"turns":         5,
		"budget":        12,
		"interference":  1.0,
		"objective":     "Hold 8 sectors. No retreat. No quarter.",
		"win_hexes":     8,
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",    "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Delta-9",   "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Rhael", "sector": "Epsilon-1", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
		],
		"enemies": [
			{ "sector": "Theta-3"  },
			{ "sector": "Iota-8"   },
			{ "sector": "Kappa-1"  },
			{ "sector": "Lambda-4" },
			{ "sector": "Mu-6"     },
			{ "sector": "Nu-2"     },
		],
	},
]


func get_current_mission_data() -> Dictionary:
	if current_mission < missions.size():
		return missions[current_mission]
	return {}


func get_win_hex_count() -> int:
	return get_current_mission_data().get("win_hexes", 4)


func count_held_hexes(zone_states: Dictionary) -> int:
	var count = 0
	for sector in zone_states:
		var state = zone_states[sector].get("state", "unknown")
		var enemy_count = zone_states[sector].get("enemy_count", 0)
		if state in ["held", "contested"] and enemy_count == 0:
			count += 1
	return count


func start_current_mission() -> void:
	print("=== GameManager.start_current_mission() called ===")
	var data = get_current_mission_data()
	if data.is_empty():
		push_error("GameManager: No mission data for index %d" % current_mission)
		return
	TurnManager.start_mission(data)
	print("=== Squads after start: ", SquadManager.squads.keys(), " ===")
