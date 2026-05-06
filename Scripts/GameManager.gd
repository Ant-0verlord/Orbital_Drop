extends Node
# =============================================================
# GameManager.gd  —  AutoLoad singleton
# Register in: Project > Project Settings > AutoLoad
# Name: GameManager
# AutoLoad order: SquadManager, TurnManager, GameManager
# =============================================================

var current_mission: int = 0
var campaign_record: Array = []

var missions: Array = [
	{
		"title":        "Mission 1 — Planetary Insertion",
		"turns":        3,
		"budget":       12,
		"interference": 0.0,
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
		]
	},
	{
		"title":        "Mission 2 — Advance on Kerath-IV",
		"turns":        4,
		"budget":       12,
		"interference": 0.2,
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
		]
	},
	{
		"title":        "Mission 3 — The Iron Salient",
		"turns":        4,
		"budget":       12,
		"interference": 0.5,
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Delta-9", "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
		]
	},
	{
		"title":        "Mission 4 — Contested Hive Spire",
		"turns":        5,
		"budget":       12,
		"interference": 0.75,
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Delta-9", "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
		]
	},
	{
		"title":        "Mission 5 — Final Assault",
		"turns":        5,
		"budget":       14,
		"interference": 1.0,
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",    "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5",   "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Delta-9",   "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Rhael", "sector": "Epsilon-1", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
		]
	},
]


func get_current_mission_data() -> Dictionary:
	if current_mission < missions.size():
		return missions[current_mission]
	return {}


func start_current_mission() -> void:
	print("=== GameManager.start_current_mission() called ===")
	var data = get_current_mission_data()
	print("Mission data keys: ", data.keys())
	if data.is_empty():
		push_error("GameManager: No mission data for index %d" % current_mission)
		return
	TurnManager.start_mission(data)
	print("=== Squads after start: ", SquadManager.squads.keys(), " ===")
