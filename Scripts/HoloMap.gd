extends StaticBody3D
# =============================================================
# HoloMap.gd
# Attach to: StaticBody3D inside Holomap.tscn
#
# Scene structure required:
#   Node3D
#     MeshInstance3D
#     StaticBody3D      (this script)
#       CollisionShape3D
#       HoloMapPopup    (Control node, HoloMapPopup.gd attached)
# =============================================================

@onready var popup: Control = $HoloMapPopup
var player: Node = null


func _ready() -> void:
	popup.visible = false
	player = get_tree().get_first_node_in_group("player")
	popup.player = player


func open_popup() -> void:
	popup.visible = true
	popup.refresh()


func close_popup() -> void:
	popup.visible = false
