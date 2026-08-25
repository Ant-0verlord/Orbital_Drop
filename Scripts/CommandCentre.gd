extends Node3D
# =============================================================
# CommandCentre.gd
# =============================================================

# Optional — there is no ResultOverlay node in Command_Centre.tscn at the
# moment, because the mission result is presented by the Command Throne's
# own report panel instead. get_node_or_null (rather than $ResultOverlay)
# is what keeps that from logging a "Node not found" error on every load;
# every use below is already null-guarded, so adding the node back would
# simply switch this second display on.
@onready var result_overlay:    Control     = get_node_or_null("ResultOverlay")
@onready var briefing_overlay:  CanvasLayer = $MissionBriefingOverlay
@onready var guide_overlay:     CanvasLayer = $GuideOverlay

func _ready() -> void:
	TurnManager.mission_complete.connect(_on_mission_complete)
	TurnManager.mission_failed.connect(_on_mission_failed)
	TurnManager.allocations_locked.connect(_on_allocations_locked)
	TurnManager.orbital_strike_resolved.connect(_on_orbital_strike_resolved)
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
#
# planet_dir / planet_angular_radius (both uniforms on SpaceSky.gdshader)
# are best-effort guesses at which way is "forward" for the deck — there's
# no way to check that from here. Fastest way to dial them in without
# waiting on a round of edits: while the game is running from the editor,
# open the "Remote" tab in the Scene dock (next to the normal scene
# tree), find SpaceEnvironment > Environment > Sky > Sky Material, and
# edit the Shader Parameters there directly — changes apply live.
# -------------------------------------------------------------------
func _build_space_sky() -> void:
	var shader = load("res://Shaders/SpaceSky.gdshader")
	if shader == null:
		return

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = shader

	var sky := Sky.new()
	sky.sky_material = sky_mat
	# The sky shader gets baked into a cubemap at this resolution before
	# it's shown — the default is low enough that our procedural planet
	# terrain (fine noise detail) came out as visibly blocky squares
	# instead of smooth continents. Bumping this fixed that.
	#
	# Bumped again from 1024 -> 2048 (the largest standard tier below
	# Godot's RADIANCE_SIZE_MAX) after the latest planet rework added a
	# lot more fine detail (coastlines, clouds, city lights) — at 1024 the
	# now much-larger, much-closer-looking disc was visibly soft/blurry
	# in-game even though it wasn't a rendering bug. This quadruples the
	# texel count (2048² vs 1024², × 6 cube faces), which does cost more
	# to re-bake — the sky re-renders in realtime every frame because the
	# shader uses TIME (cloud drift, aurora). If this turns out to be too
	# heavy on lower-end hardware, dropping back to RADIANCE_SIZE_1024
	# here is the one line to revert.
	sky.radiance_size = Sky.RADIANCE_SIZE_2048

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR

	var world_env := WorldEnvironment.new()
	world_env.name = "SpaceEnvironment"
	world_env.environment = env
	add_child(world_env)


# =============================================================
# Orbital strike beam
# =============================================================
# Fired from the command throne's position out along +X when a strike
# actually resolves (TurnManager only emits orbital_strike_resolved when a
# bombardment was armed and landed, so this can't fire on a turn where
# nothing was called in). Built in code like the sky above, so there's
# nothing in the .tscn for the editor to lose track of.
#
# +X is very nearly straight at the planet: SpaceSky's planet_dir is
# (1.0, -0.55, 0.04), so the beam leaves the deck on the correct side and
# heads out toward the disc. If you'd rather it point dead-on at the planet
# instead of along the axis, set LASER_DIR to that vector normalised — it's
# the one line that decides it.
const LASER_ORIGIN := Vector3(33.496, 8.628, 0.352)
const LASER_DIR := Vector3(1.0, 0.0, 0.0)
# Long enough to run off past anything the player can see, so it reads as
# reaching the planet rather than stopping in mid-air.
const LASER_LENGTH: float = 400.0
const LASER_CORE_RADIUS: float = 0.6
const LASER_GLOW_RADIUS: float = 2.4
const LASER_STRIKE_TIME: float = 0.07   # snap on, no windup
const LASER_FLASH_SETTLE: float = 0.25  # muzzle flash drops to a steady burn
const LASER_FADE: float = 0.7
# The beam runs for exactly as long as the cannon-fire clip, so the sound
# and the visual start and stop together. Read from the stream at runtime
# rather than hardcoded, so swapping the sound doesn't silently leave a
# beam hanging in the air after it (or cutting out halfway through). This
# is the sustain in the middle — the snap-on, flash settle and fade are
# subtracted from the clip's length below so the TOTAL matches it.
const LASER_MIN_SUSTAIN: float = 0.2
const LASER_CORE_ENERGY: float = 5.5
const LASER_GLOW_ENERGY: float = 2.2


func _on_orbital_strike_resolved(_report: Dictionary) -> void:
	_fire_orbital_laser()


func _fire_orbital_laser() -> void:
	var shader = load("res://Shaders/OrbitalLaser.gdshader")
	if shader == null:
		return

	var rig := Node3D.new()
	rig.name = "OrbitalLaser"
	add_child(rig)
	rig.position = LASER_ORIGIN
	# CylinderMesh runs along its own +Y, so aim that axis down LASER_DIR
	# and everything below can be built in plain local coordinates.
	rig.transform.basis = _basis_pointing_y_along(LASER_DIR.normalized())

	# Wider, dimmer, mostly-orange sheath first, then the hot core inside
	# it. Both are additive, so the overlap in the middle is what actually
	# blows out to white rather than either layer being white on its own.
	# edge_power below 1 on the sheath — see the note on that uniform in
	# OrbitalLaser.gdshader. Anything above 1 leaves it looking washed-out
	# cream rather than orange, because the fresnel term only hits 1 right
	# at the silhouette.
	var glow_mat := _make_laser_material(shader, LASER_GLOW_ENERGY, 0.5)
	var core_mat := _make_laser_material(shader, LASER_CORE_ENERGY, 4.5)
	_add_laser_cylinder(rig, LASER_GLOW_RADIUS, glow_mat)
	_add_laser_cylinder(rig, LASER_CORE_RADIUS, core_mat)

	# A brief flash at the muzzle end so the deck itself is lit by the
	# shot — without this the beam reads as painted on top of the scene
	# rather than coming from it.
	var flash := OmniLight3D.new()
	flash.name = "LaserFlash"
	# Kept in step with the shader's edge_color so the light the deck
	# catches is the same orange as the beam casting it.
	flash.light_color = Color(1.0, 0.65, 0.32)
	flash.omni_range = 26.0
	flash.light_energy = 0.0
	rig.add_child(flash)

	var sound_length: float = AudioManager.get_cannon_fire_length()
	var sustain: float = max(
		LASER_MIN_SUSTAIN,
		sound_length - LASER_STRIKE_TIME - LASER_FLASH_SETTLE - LASER_FADE
	)

	var tw := create_tween()
	tw.tween_property(core_mat, "shader_parameter/energy", LASER_CORE_ENERGY, LASER_STRIKE_TIME).from(0.0)
	tw.parallel().tween_property(glow_mat, "shader_parameter/energy", LASER_GLOW_ENERGY, LASER_STRIKE_TIME).from(0.0)
	tw.parallel().tween_property(flash, "light_energy", 7.0, LASER_STRIKE_TIME).from(0.0)
	tw.tween_property(flash, "light_energy", 2.4, LASER_FLASH_SETTLE)
	tw.tween_interval(sustain)
	tw.tween_property(core_mat, "shader_parameter/energy", 0.0, LASER_FADE)
	tw.parallel().tween_property(glow_mat, "shader_parameter/energy", 0.0, LASER_FADE)
	tw.parallel().tween_property(flash, "light_energy", 0.0, LASER_FADE)
	# The whole rig is temporary — it builds itself, fires, and cleans up,
	# so nothing accumulates over a long campaign of repeated strikes.
	tw.tween_callback(rig.queue_free)


func _make_laser_material(shader: Shader, energy: float, edge_power: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("edge_power", edge_power)
	return mat


func _add_laser_cylinder(rig: Node3D, radius: float, mat: ShaderMaterial) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = LASER_LENGTH
	mesh.radial_segments = 20
	mesh.rings = 1
	# No end caps — a flat disc at the far end would catch the light and
	# read as the beam stopping at a wall.
	mesh.cap_top = false
	mesh.cap_bottom = false

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	# CylinderMesh is centred on its origin, so push it out by half its
	# length to make the beam START at the throne rather than straddle it.
	mi.position = Vector3(0.0, LASER_LENGTH * 0.5, 0.0)
	rig.add_child(mi)


# A basis whose local +Y points along `dir`. Basis.looking_at() aims -Z,
# which is the wrong axis for a cylinder, hence building it by hand. The
# "pick a reference axis that isn't parallel to dir" step is what stops it
# collapsing when the beam is fired straight up or down.
func _basis_pointing_y_along(dir: Vector3) -> Basis:
	var up := dir.normalized()
	var reference := Vector3.UP
	if abs(up.dot(reference)) > 0.99:
		reference = Vector3.RIGHT
	var right := reference.cross(up).normalized()
	# right.cross(up), NOT up.cross(right) — the other order yields a basis
	# with determinant -1, i.e. a mirrored transform, which flips the
	# cylinder's winding and normals.
	var forward := right.cross(up).normalized()
	return Basis(right, up, forward)


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

# TurnManager emits mission_complete when a mission ENDS, win or lose, with
# the outcome carried in report.won — so this has to check it rather than
# assume, otherwise a failed mission would announce "MISSION COMPLETE".
#
# Neither handler appends to GameManager.campaign_record any more:
# TurnManager already appends a proper per-mission dictionary (mission,
# won, score, rating) for every mission, while these two were pushing bare
# "win"/"loss" strings into that same array — so it ended up holding two
# different shapes of entry for every mission played.
func _on_mission_complete(report: Dictionary) -> void:
	GuideManager.on_turn_ended()
	if report.get("won", false):
		_show_result(true, "MISSION COMPLETE", "Objective achieved.")

func _on_mission_failed(reason: String) -> void:
	GuideManager.on_turn_ended()
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
