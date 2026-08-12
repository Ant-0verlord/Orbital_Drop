extends Node3D
# =============================================================
# CommandCentre.gd
# =============================================================

@onready var result_overlay:    Control     = $ResultOverlay
@onready var briefing_overlay:  CanvasLayer = $MissionBriefingOverlay
@onready var guide_overlay:     CanvasLayer = $GuideOverlay

func _ready() -> void:
	TurnManager.mission_complete.connect(_on_mission_complete)
	TurnManager.mission_failed.connect(_on_mission_failed)
	TurnManager.allocations_locked.connect(_on_allocations_locked)
	GameManager.mission_advanced.connect(_show_briefing)

	if result_overlay:
		result_overlay.visible = false

	# Set camera reference for guide arrows
	var cam = get_viewport().get_camera_3d()
	if cam and guide_overlay:
		guide_overlay.set_camera(cam)

	# Show mission briefing before starting
	_show_briefing()

func _show_briefing() -> void:
	if briefing_overlay == null:
		_start_mission()
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Build zone states for preview
	GameManager.start_current_mission()  # init data but don't start turn yet

	var mission_data = GameManager.get_current_mission_data()
	var sectors      = mission_data.get("sectors", [])
	var axial_list   = mission_data.get("axial", [])
	var enemies      = mission_data.get("enemies", [])
	var squads       = mission_data.get("squads", [])

	var axial_map: Dictionary = {}
	for i in range(min(sectors.size(), axial_list.size())):
		axial_map[sectors[i]] = axial_list[i]

	var zone_states: Dictionary = {}
	for s in sectors:
		zone_states[s] = { "state": "neutral", "squad": [], "enemy_count": 0 }
	for e in enemies:
		var sec = e.get("sector", "")
		if sec != "" and zone_states.has(sec):
			zone_states[sec]["state"] = "enemy"
	for sq in squads:
		var sec = sq.get("sector", "")
		if sec != "" and zone_states.has(sec):
			zone_states[sec]["state"] = "held"
			# Array, not a single overwrite — more than one squad can
			# share a landing hex.
			zone_states[sec]["squad"].append(sq.get("name", ""))

	briefing_overlay.briefing_dismissed.connect(_on_briefing_dismissed, CONNECT_ONE_SHOT)
	briefing_overlay.show_briefing(GameManager.current_mission, zone_states, axial_map)

func _on_briefing_dismissed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_start_mission()

func _start_mission() -> void:
	GameManager.start_current_mission()
	TurnManager.start_mission(GameManager.get_current_mission_data())
	GuideManager.start_guide()

func _on_allocations_locked() -> void:
	GuideManager.on_allocs_locked()

func _on_mission_complete(report: Dictionary) -> void:
	GuideManager.on_turn_ended()
	GameManager.campaign_record.append("win")
	_show_result(true, "MISSION COMPLETE", "Objective achieved.")

func _on_mission_failed(reason: String) -> void:
	GuideManager.on_turn_ended()
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
			Color(0.4, 0.9, 0.4) if win else Color(0.9, 0.3, 0.3))
	if msg_lbl:
		msg_lbl.text = message
