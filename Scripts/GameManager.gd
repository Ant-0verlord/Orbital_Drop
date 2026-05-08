extends Node
# =============================================================
# GameManager.gd  —  AutoLoad singleton
# AutoLoad order: SquadManager, TurnManager, GameManager
# =============================================================

var current_mission: int = 0
var campaign_record: Array = []

# Neutral sectors shown on the holo-map (no squad assigned)
# These expand as missions progress
var missions: Array = [
	{
		"title":        "Mission 1 — Planetary Insertion",
		"objective":    "Establish a foothold. Keep both squads alive for all 3 turns.",
		"turns":        3,
		"budget":       12,
		"interference": 0.0,
		"neutral_sectors": ["Zeta-3", "Eta-6", "Theta-1", "Iota-4", "Kappa-8"],
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
		]
	},
	{
		"title":        "Mission 2 — Advance on Kerath-IV",
		"objective":    "Push three squads into contested sectors. Hold Alpha-7 and Beta-2.",
		"turns":        4,
		"budget":       12,
		"interference": 0.2,
		"neutral_sectors": ["Zeta-3", "Eta-6", "Theta-1", "Iota-4", "Kappa-8", "Lambda-2"],
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
		]
	},
	{
		"title":        "Mission 3 — The Iron Salient",
		"objective":    "Prevent sector collapse. Keep at least 2 squads operational.",
		"turns":        4,
		"budget":       12,
		"interference": 0.5,
		"neutral_sectors": ["Zeta-3", "Eta-6", "Theta-1", "Iota-4", "Kappa-8", "Lambda-2", "Mu-7"],
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Delta-9", "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
		]
	},
	{
		"title":        "Mission 4 — Contested Hive Spire",
		"objective":    "Hold the Hive Spire approach. No squad can fall to Critical status.",
		"turns":        5,
		"budget":       12,
		"interference": 0.75,
		"neutral_sectors": ["Zeta-3", "Eta-6", "Theta-1", "Iota-4", "Kappa-8", "Lambda-2", "Mu-7", "Nu-5"],
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.ARMAMENTS  },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED,  "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,   "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Davan", "sector": "Delta-9", "status": SquadManager.Status.CRITICAL, "need": SquadManager.Need.MEDI_PACKS },
		]
	},
	{
		"title":        "Mission 5 — Final Assault",
		"objective":    "Survive all 5 turns. Lose no more than one squad.",
		"turns":        5,
		"budget":       14,
		"interference": 1.0,
		"neutral_sectors": ["Zeta-3", "Eta-6", "Theta-1", "Iota-4", "Kappa-8", "Lambda-2", "Mu-7", "Nu-5", "Xi-1"],
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
	if data.is_empty():
		push_error("GameManager: No mission data for index %d" % current_mission)
		return
	TurnManager.start_mission(data)
	print("=== Squads after start: ", SquadManager.squads.keys(), " ===")
