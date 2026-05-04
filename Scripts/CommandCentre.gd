extends Node3D
# =============================================================
# command_centre.gd
# Attach to: root Node3D of Command_Centre.tscn
#
# Starts the current mission when the scene loads.
# Listens for mission complete/failed signals and
# shows the result screen.
# =============================================================

@onready var result_overlay: Control = $ResultOverlay  # Add this node — see below


func _ready() -> void:
	TurnManager.mission_complete.connect(_on_mission_complete)
	TurnManager.mission_failed.connect(_on_mission_failed)
	await get_tree().create_timer(0.1).timeout
	GameManager.start_current_mission()


func _on_mission_complete() -> void:
	GameManager.campaign_record.append("win")
	_show_result(true, "MISSION COMPLETE", "Your forces held the line. Stand by for campaign debrief.")


func _on_mission_failed(reason: String) -> void:
	GameManager.campaign_record.append("loss")
	_show_result(false, "MISSION FAILED", reason)


func _show_result(win: bool, title: String, message: String) -> void:
	if result_overlay == null:
		return
	result_overlay.visible = true

	var title_lbl = result_overlay.get_node_or_null("VBoxContainer/TitleLabel")
	var msg_lbl   = result_overlay.get_node_or_null("VBoxContainer/MessageLabel")

	if title_lbl:
		title_lbl.text = title
		title_lbl.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if win else Color(0.9, 0.3, 0.3)
		)
	if msg_lbl:
		msg_lbl.text = message
