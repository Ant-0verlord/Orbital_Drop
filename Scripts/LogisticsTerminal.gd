extends StaticBody3D
# =============================================================
# LogisticsTerminal.gd
# Attach to: StaticBody3D inside LogisticsTerminal.tscn
#
# Scene structure required:
#   Node3D
#     MeshInstance3D
#     StaticBody3D        (this script)
#       CollisionShape3D
#       LogisticsPopup    (Control node, LogisticsPopup.gd attached)
# =============================================================

@onready var popup: Control = $LogisticsPopup
var player: Node = null


func _ready() -> void:
	popup.visible = false
	# Find the player via group — add CharacterBody3D to group "player"
	# in Player.tscn (Node tab > Groups > add "player")
	player = get_tree().get_first_node_in_group("player")
	popup.player = player


func open_popup() -> void:
	popup.visible = true
	popup.refresh()


func close_popup() -> void:
	popup.visible = false
