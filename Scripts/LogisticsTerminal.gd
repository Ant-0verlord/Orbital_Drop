extends StaticBody3D
# =============================================================
# LogisticsTerminal.gd
# Attach to: StaticBody3D inside LogisticsTerminal.tscn
# =============================================================

@onready var popup: Control = $LogisticsPopup
var player: Node = null


func _ready() -> void:
	popup.visible = false
	player = get_tree().get_first_node_in_group("player")
	popup.player = player
	print("LogisticsTerminal _ready — player found: ", player != null)
	print("LogisticsTerminal _ready — squads: ", SquadManager.squads.keys())


func open_popup() -> void:
	print("=== OPENING LOGISTICS POPUP ===")
	print("Squads empty: ", SquadManager.squads.is_empty())
	print("Squads: ", SquadManager.squads.keys())
	popup.visible = true
	popup.refresh()


func close_popup() -> void:
	popup.visible = false
