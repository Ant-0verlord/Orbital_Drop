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
	TurnManager.turn_ended.connect(_on_turn_ended)
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


# Quadratic Bezier through `control`. Kept as its own function so the
# position and the "just ahead" sample below both come from one definition
# of the curve.
func _pod_arc_point(t: float, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


func _set_pod_along_arc(t: float, rig: Node3D, a: Vector3, b: Vector3, c: Vector3) -> void:
	# The tween outlives a scene change by a frame or two in the worst case.
	if not is_instance_valid(rig):
		return
	var pos: Vector3 = _pod_arc_point(t, a, b, c)
	rig.position = pos
	# Sample slightly further along to get the direction of travel, so the
	# pod and the trail hanging off it stay pointed the way they're actually
	# going as the arc turns over. At t = 1 the two samples coincide, hence
	# the length guard — it just keeps the last good heading.
	var ahead: Vector3 = _pod_arc_point(min(t + 0.02, 1.0), a, b, c)
	var heading: Vector3 = ahead - pos
	if heading.length() > 0.001:
		rig.transform.basis = _basis_pointing_y_along(heading.normalized())


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
	# Only COUNT here, don't launch. Locking allocations at the Logistics
	# Terminal is where the numbers are readable — TurnManager clears
	# pending_allocations and the pending reinforcement as it resolves — but
	# the launch itself belongs to Engage Turn Seal, which is the moment the
	# player actually commits. So the tally is banked now and spent below.
	_pending_pod_count = _count_pod_launches()


func _on_turn_ended(_turn_number: int) -> void:
	var count: int = _pending_pod_count
	_pending_pod_count = 0
	if TurnManager.mission_over:
		return
	_launch_drop_pods(count)


# =============================================================
# Supply / reinforcement drop pods
# =============================================================
# Launched when the player engages the Turn Seal, which is the moment the
# turn is actually committed. The count is worked out earlier, back when
# allocations lock at the Logistics Terminal, because by the time the turn
# resolves TurnManager has already cleared pending_allocations and consumed
# the pending reinforcement — so there'd be nothing left to count from.
#
# One pod per thing actually being sent: each supply type allocated to each
# squad, plus one for a reinforcement squad if one is being dropped. No
# ceiling on the count — the salvo is however big the turn was, so a heavy
# resupply across a full roster genuinely looks like one. The real limit is
# the mission's supply pool and the two-supplies-per-squad rule, which
# between them keep it sane without needing an arbitrary cap here.
# Pods fly an ARC rather than a straight line: up out from under the deck,
# over a crest, then away along the same heading the orbital laser fires on
# (LASER_DIR, +X) so both converge on the same point out at the planet.
#
# The arc is a quadratic Bezier through a control point set above and a
# little ahead of the launch, and it is now only just curved: barely enough
# lift to rise out from under the deck before running essentially straight
# at the planet. The bow off a dead-straight launch-to-target line peaks at
# under 6 units across a 240-unit flight, and the pod finishes travelling
# flat along +X.
#
# Worth knowing when tuning: a quadratic Bezier only reaches HALF-way to
# its control point, so this is roughly double the height actually gained.
# Earlier passes at 48 arced far too high for the same reason.
const POD_ARC_HEIGHT: float = 16.0
# How far along the flight the crest sits. Higher leans the control point
# toward the target and pushes the crest later.
const POD_ARC_LEAN: float = 0.25
# A beat before the salvo goes, so there's time to look up from the console
# and actually watch it leave.
const POD_INITIAL_DELAY: float = 1.0
# Below the deck, measured off the throne so it moves with it if the deck
# is ever repositioned. Nudge the Y if the pods clip the underside.
const POD_LAUNCH_OFFSET := Vector3(0.0, -18.0, 0.0)
const POD_TRAVEL: float = 240.0
const POD_FLIGHT_TIME: float = 3.2   # a long, watchable climb rather than a blink
const POD_STAGGER: float = 0.22      # fired as a rolling salvo, not in unison
const POD_SPREAD: float = 7.0        # lateral gap so they don't launch through each other
# Total width the salvo is allowed to occupy. With no cap on pod count, a
# heavy turn could otherwise fan wide enough that the outermost pods launch
# from past the edge of the deck and appear out of thin air. Beyond this
# width they close ranks instead of spreading further.
const POD_FAN_MAX_WIDTH: float = 44.0
const POD_RADIUS: float = 2.0
const POD_TRAIL_RADIUS: float = 1.2
const POD_TRAIL_LENGTH: float = 34.0
# Where in the flight the pod starts fading, as a fraction of it. The fade
# overlaps the LAST stretch of travel rather than following it, so the pod
# thins out while it's already far off and small instead of vanishing at
# full brightness the moment it stops.
const POD_FADE_START_FRAC: float = 0.55
const POD_ENERGY: float = 3.4
const POD_LIGHT_ENERGY: float = 3.2
# Amber, matching the drop-pod glow on the title screen (see
# MenuBackground.gdshader's pod_color) so the two read as the same craft.
const POD_CORE_COLOR := Color(1.0, 0.97, 0.85, 1.0)
const POD_EDGE_COLOR := Color(1.0, 0.85, 0.3, 1.0)

# Banked at allocations-lock, spent at Engage Turn Seal — see the two
# handlers above.
var _pending_pod_count: int = 0


func _count_pod_launches() -> int:
	var pods := 0
	for squad_name in TurnManager.pending_allocations:
		var per_squad: Dictionary = TurnManager.pending_allocations[squad_name]
		for supply in per_squad:
			if int(per_squad[supply]) > 0:
				pods += 1
	if GameManager.has_pending_reinforcement():
		pods += 1
	return pods


func _launch_drop_pods(count: int) -> void:
	if count <= 0:
		return
	var shader = load("res://Shaders/OrbitalLaser.gdshader")
	if shader == null:
		return

	var launch_dir: Vector3 = LASER_DIR.normalized()
	var start: Vector3 = LASER_ORIGIN + POD_LAUNCH_OFFSET
	# The point the laser reaches out at the planet — pods aim for the same
	# place, so a strike and a resupply visibly go to the same sector.
	var target: Vector3 = LASER_ORIGIN + launch_dir * POD_TRAVEL
	# Fan across the axis perpendicular to both the heading and world up.
	var side: Vector3 = launch_dir.cross(Vector3.UP).normalized()

	# Tighten the spacing once the salvo would outgrow the deck, so a big
	# resupply packs in rather than spilling off the sides.
	var gaps: int = max(count - 1, 1)
	var spacing: float = min(POD_SPREAD, POD_FAN_MAX_WIDTH / float(gaps))

	for i in range(count):
		# Fan the salvo out sideways, centred on the launch point, so the
		# pods leave as a row rather than stacked on one line. They keep a
		# fraction of that offset at the far end so they converge on the
		# target without ending up perfectly on top of one another.
		var lateral: float = (float(i) - float(count - 1) * 0.5) * spacing
		_spawn_drop_pod(
			shader,
			start + side * lateral,
			target + side * lateral * 0.15,
			POD_INITIAL_DELAY + float(i) * POD_STAGGER
		)


func _spawn_drop_pod(shader: Shader, start: Vector3, target: Vector3, delay: float) -> void:
	# Control point: up from the launch, and a little way along toward the
	# target. See POD_ARC_HEIGHT for why this is about double the height
	# actually reached.
	var control: Vector3 = start + Vector3.UP * POD_ARC_HEIGHT + (target - start) * POD_ARC_LEAN

	var rig := Node3D.new()
	rig.name = "DropPod"
	add_child(rig)
	rig.transform = Transform3D(_basis_pointing_y_along((control - start).normalized()), start)

	# Same shader as the orbital laser, just in amber — so the pod core,
	# its trail and the strike beam all share one look.
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("core_color", POD_CORE_COLOR)
	mat.set_shader_parameter("edge_color", POD_EDGE_COLOR)
	mat.set_shader_parameter("edge_power", 0.7)
	mat.set_shader_parameter("energy", 0.0)
	mat.set_shader_parameter("travel_speed", 14.0)

	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = POD_RADIUS
	sphere.height = POD_RADIUS * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	body.mesh = sphere
	body.material_override = mat
	rig.add_child(body)

	var trail := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	# Widest where it meets the pod (local +Y end) and tapering away to
	# nothing behind it, which is what makes it read as a trail rather than
	# a rod the pod happens to be sitting on.
	cyl.top_radius = POD_TRAIL_RADIUS
	cyl.bottom_radius = POD_TRAIL_RADIUS * 0.12
	cyl.height = POD_TRAIL_LENGTH
	cyl.radial_segments = 12
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	trail.mesh = cyl
	trail.material_override = mat
	trail.position = Vector3(0.0, -POD_TRAIL_LENGTH * 0.5, 0.0)
	rig.add_child(trail)

	var glow := OmniLight3D.new()
	glow.light_color = POD_EDGE_COLOR
	glow.omni_range = 28.0
	glow.light_energy = 0.0
	rig.add_child(glow)

	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(AudioManager.play_pod_launch)
	tw.parallel().tween_property(mat, "shader_parameter/energy", POD_ENERGY, 0.12).from(0.0)
	tw.parallel().tween_property(glow, "light_energy", POD_LIGHT_ENERGY, 0.12).from(0.0)
	# EASE_IN so it accelerates away rather than moving at a constant
	# crawl — a pod under power, not one drifting.
	tw.parallel().tween_method(
		_set_pod_along_arc.bind(rig, start, control, target), 0.0, 1.0, POD_FLIGHT_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Delayed rather than sequential, so the fade runs DURING the last part
	# of the flight. from() is given explicitly because these begin part-way
	# through the step — without it the tweener would read whatever the
	# property happened to hold when its delay expired, which is fragile if
	# the ramp-up above is ever retimed.
	var fade_start: float = POD_FLIGHT_TIME * POD_FADE_START_FRAC
	var fade_time: float = POD_FLIGHT_TIME - fade_start
	tw.parallel().tween_property(mat, "shader_parameter/energy", 0.0, fade_time) \
		.from(POD_ENERGY).set_delay(fade_start)
	tw.parallel().tween_property(glow, "light_energy", 0.0, fade_time) \
		.from(POD_LIGHT_ENERGY).set_delay(fade_start)
	tw.tween_callback(rig.queue_free)

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
