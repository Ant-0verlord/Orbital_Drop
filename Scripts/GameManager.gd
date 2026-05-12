extends Node
# =============================================================
# GameManager.gd  —  AutoLoad singleton
# =============================================================

var current_mission: int = 0
var campaign_record: Array = []

var missions: Array = [
	{
		"title":        "Mission 1 — Planetary Insertion",
		"turns":        5,
		"budget":       8,
		"win_hexes":    5,
		"interference": 0.0,
		"objective":    "Capture and hold 5 sectors by the end of Turn 5.",
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
		],
		"enemies": [
			{ "sector": "Zeta-3"  },
			{ "sector": "Delta-9" },
		],
	},
	{
		"title":        "Mission 2 — Advance on Kerath-IV",
		"turns":        5,
		"budget":       10,
		"win_hexes":    7,
		"interference": 0.2,
		"objective":    "Secure 7 sectors. Enemy reinforcements inbound.",
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
		],
		"enemies": [
			{ "sector": "Iota-8"  },
			{ "sector": "Nu-2"    },
			{ "sector": "Kappa-1" },
		],
	},
	{
		"title":        "Mission 3 — The Iron Salient",
		"turns":        5,
		"budget":       10,
		"win_hexes":    8,
		"interference": 0.5,
		"objective":    "Hold 8 sectors against a reinforced enemy push.",
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
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
		"title":        "Mission 4 — Contested Hive Spire",
		"turns":        5,
		"budget":       10,
		"win_hexes":    9,
		"interference": 0.75,
		"objective":    "Hold 9 sectors. Comms are failing — trust your instincts.",
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Delta-9", "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
		],
		"enemies": [
			{ "sector": "Iota-8"   },
			{ "sector": "Kappa-1"  },
			{ "sector": "Lambda-4" },
			{ "sector": "Mu-6"     },
			{ "sector": "Nu-2"     },
		],
	},
	{
		"title":        "Mission 5 — Final Assault",
		"turns":        5,
		"budget":       12,
		"win_hexes":    10,
		"interference": 1.0,
		"objective":    "Hold 10 sectors. All channels compromised. The final push begins.",
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Beta-2",    "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Delta-9",   "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Rhael", "sector": "Epsilon-1", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
		],
		"enemies": [
			{ "sector": "Iota-8"   },
			{ "sector": "Kappa-1"  },
			{ "sector": "Lambda-4" },
			{ "sector": "Mu-6"     },
			{ "sector": "Nu-2"     },
			{ "sector": "Xi-7"     },
		],
	},
]


func get_current_mission_data() -> Dictionary:
	if current_mission < missions.size():
		return missions[current_mission]
	return {}


func start_current_mission() -> void:
	var data = get_current_mission_data()
	if data.is_empty():
		push_error("GameManager: No mission data for index %d" % current_mission)
		return
	TurnManager.start_mission(data)
