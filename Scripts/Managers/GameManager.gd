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

var missions: Array = [
	{
		"title":        "Mission 1 — Planetary Insertion",
		"turns":        5,
		"win_hexes":    4,
		"interference": 0.0,
		"objective":    "Capture and hold 4 sectors by the end of Turn 5.",
		"supply_pool": { "Armaments": 8, "Medi-Packs": 6, "Fuel Cells": 8 },
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
		"turns":        5,
		"win_hexes":    7,
		"interference": 0.2,
		"objective":    "Secure 7 sectors. Enemy reinforcements inbound.",
		"supply_pool": { "Armaments": 10, "Medi-Packs": 8, "Fuel Cells": 10 },
		"squads": [
			{ "name": "Squad Varro", "sector": "Alpha-7", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
			{ "name": "Squad Kael",  "sector": "Beta-2",  "status": SquadManager.Status.WOUNDED, "need": SquadManager.Need.MEDI_PACKS },
			{ "name": "Squad Orin",  "sector": "Gamma-5", "status": SquadManager.Status.ACTIVE,  "need": SquadManager.Need.FUEL_CELLS },
		],
		"enemies": [
			{ "sector": "Iota-8"   },
			{ "sector": "Nu-2"     },
			{ "sector": "Kappa-1"  },
			{ "sector": "Lambda-4" },
			{ "sector": "Mu-6"     },
		],
	},
	{
		"title":        "Mission 3 — The Iron Salient",
		"turns":        5,
		"win_hexes":    8,
		"interference": 0.5,
		"objective":    "Hold 8 sectors against a reinforced enemy push.",
		"supply_pool": { "Armaments": 10, "Medi-Packs": 8, "Fuel Cells": 10 },
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
			{ "sector": "Xi-7"     },
		],
	},
	{
		"title":        "Mission 4 — Contested Hive Spire",
		"turns":        5,
		"win_hexes":    9,
		"interference": 0.75,
		"objective":    "Hold 9 sectors. Comms are failing — trust your instincts.",
		"supply_pool": { "Armaments": 10, "Medi-Packs": 8, "Fuel Cells": 10 },
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
			{ "sector": "Xi-7"     },
			{ "sector": "Theta-3"  },
		],
	},
	{
		"title":        "Mission 5 — Final Assault",
		"turns":        5,
		"win_hexes":    10,
		"interference": 1.0,
		"objective":    "Hold 10 sectors. All channels compromised. The final push begins.",
		"supply_pool": { "Armaments": 12, "Medi-Packs": 10, "Fuel Cells": 12 },
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
			{ "sector": "Theta-3"  },
			{ "sector": "Eta-6"    },
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

	var pool = data.get("supply_pool", { "Armaments": 8, "Medi-Packs": 6, "Fuel Cells": 8 })
	supply_pool = pool.duplicate()
	supply_spent = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }

	TurnManager.start_mission(data)


func consume_supplies(allocations: Dictionary) -> void:
	for squad_name in allocations:
		for supply_type in allocations[squad_name]:
			var amount = allocations[squad_name][supply_type]
			if amount > 0:
				supply_pool[supply_type]  -= amount
				supply_spent[supply_type] += amount


func get_supply_pool() -> Dictionary:
	return supply_pool


func get_supply_spent() -> Dictionary:
	return supply_spent


func calculate_score(held_hexes: int, turns_taken: int, win_hexes: int) -> Dictionary:
	var tile_score   = int((float(held_hexes) / float(win_hexes)) * 400)

	var max_turns    = get_current_mission_data().get("turns", 5)
	var turn_bonus   = int((float(max_turns - turns_taken) / float(max_turns)) * 300)

	var pool         = get_current_mission_data().get("supply_pool", {})
	var max_supplies = 0
	for s in pool: max_supplies += pool[s]
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
