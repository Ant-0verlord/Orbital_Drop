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

	_build_space_sky()

	# Show mission briefing before starting
	_show_briefing()


# -------------------------------------------------------------------
# Space sky — the command deck turned out to be an open platform (railings,
# no walls) rather than a sealed room, so the right way to show "space
# outside" is a real sky wrapped around the whole thing rather than a
# single framed screen bolted to one side. Procedural (stars + nebula +
# one big planet), so there's no giant panorama texture to import and it
# looks correct from every angle as the player walks around the deck.
#
# ambient_light_source is left DISABLED on purpose — this only changes
# what's visible in the empty space around the platform, not how any
# existing surface is lit. Switch it to AMBIENT_SOURCE_SKY later if the
# deck should pick up some ambient colour/light from the sky itself.
# -------------------------------------------------------------------
func _build_space_sky() -> void:
	var shader = load("res://Shaders/SpaceSky.gdshader")
	if shader == null:
		return

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = shader

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR

	var world_env := WorldEnvironment.new()
	world_env.name = "SpaceEnvironment"
	world_env.environment = env
	add_child(world_env)


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
	var adjacency    = mission_data.get("adjacency", {})

	var axial_map: Dictionary = {}
	for i in range(min(sectors.size(), axial_list.size())):
		axial_map[sectors[i]] = axial_list[i]

	var zone_states: Dictionary = {}
	for s in sectors:
		zone_states[s] = { "state": "neutral", "squad": [], "enemy_count": 0, "marker": "", "marker_label": "" }
	for e in enemies:
		var sec = e.get("sector", "")
		if sec != "" and zone_states.has(sec):
			zone_states[sec]["state"] = "enemy"
			if e.get("is_priority", false):
				zone_states[sec]["marker"] = "priority"
				# Use whatever this mission's actual priority target is
				# called instead of a hardcoded name, so this still makes
				# sense on future missions with a different target.
				var target_name = mission_data.get("priority_target_name", "TARGET")
				zone_states[sec]["marker_label"] = String(target_name).replace("Commander ", "").to_upper()

	# Flag the tower and (if this mission has a fixed one) extraction zone
	# on the briefing map too, so the player can plan a route before
	# committing to the mission rather than discovering them mid-fight.
	var tower_sector = mission_data.get("radio_tower_sector", "")
	if tower_sector != "" and zone_states.has(tower_sector) and zone_states[tower_sector]["marker"] == "":
		zone_states[tower_sector]["marker"] = "tower"

	var extraction_sector = mission_data.get("extraction_sector", "")
	if extraction_sector != "" and zone_states.has(extraction_sector) and zone_states[extraction_sector]["marker"] == "":
		zone_states[extraction_sector]["marker"] = "extract"

	var mission_squad_names: Array = []
	for sq in squads:
		mission_squad_names.append(sq.get("name", ""))
		var sec = sq.get("sector", "")
		if sec != "" and zone_states.has(sec):
			zone_states[sec]["state"] = "held"
			# Array, not a single overwrite — more than one squad can
			# share a landing hex.
			zone_states[sec]["squad"].append(sq.get("name", ""))

	# Reinforcement squads spawned in during an earlier mission aren't part
	# of this mission's scripted roster above, so without this they'd be
	# invisible on the briefing map even though they're about to drop in
	# alongside the main force. Preview them on the same rally hexes
	# TurnManager will actually place them on once the mission starts.
	var carried_over: Array = []
	for key in SquadManager.squads:
		if key in mission_squad_names:
			continue
		if SquadManager.squads[key].status == SquadManager.Status.LOST:
			continue
		carried_over.append(key)

	if carried_over.size() > 0:
		var rally_candidates = TurnManager.find_rally_candidates(squads, enemies, sectors, adjacency)
		var fallback_sector = squads[0].get("sector", "") if squads.size() > 0 else ""
		for i in range(carried_over.size()):
			var sec = rally_candidates[i] if i < rally_candidates.size() else fallback_sector
			if sec != "" and zone_states.has(sec):
				zone_states[sec]["state"] = "held"
				zone_states[sec]["squad"].append(carried_over[i])

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
