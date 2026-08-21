extends Node3D
# =============================================================
# Epilogue.gd
# =============================================================
# Plays once the whole 5-mission campaign has actually been won (wired up
# from the Command Throne's report screen — "View Epilogue" only shows
# there once Mission 5 itself is beaten). A Star-Wars-crawl-style text
# scroll in front of the same SpaceSky backdrop used aboard the Command
# Centre, ending on a "sneaky cut" to a waving Orbital Drop banner
# instead of trying to actually render a believable dive through cloud
# cover. Every scene node here is built in code rather than hand-placed
# in a .tscn (same pattern CommandCentre.gd uses for its own sky), so
# there's nothing for the editor to lose track of.
#
# Runs as a state machine (see Phase / _phase) because the shot changes
# character several times rather than drifting continuously:
#
#   READING_A  — camera fixed, facing directly AWAY from the planet (a
#                pure starfield, no planet anywhere in frame) while the
#                first, lore-only half of the crawl scrolls past.
#   SNAPPING   — a quick whip-pan (not a slow drift) to a second "still
#                pure space" framing — the cut from lore into credits.
#   READING_B  — camera fixed again at the new framing while the second
#                half (a little more lore, then the credits) scrolls.
#   REVEALING  — once that text has scrolled fully away, the camera
#                slowly pans across to finally look at the planet.
#                Explosions on its surface start ramping up as it comes
#                into view.
#   ESCALATING — camera holds on the planet while the explosions keep
#                climbing toward their peak.
#   DIVING     — FOV rushes inward and the screen washes to white, as if
#                closing in on the cloud layer.
#   FLAG_HOLD  — the "sneaky cut": at full white, the starfield is swapped
#                for a plain sky and a waving Orbital Drop banner takes
#                its place, then the white fades away to reveal it. Much
#                simpler and more reliable than trying to actually render
#                a seamless descent through atmosphere.
#   (fade to black, back to the main menu)
#
# The "camera looks directly away from the planet" trick is what
# guarantees a planet-free background during the reading phases — the
# planet sits in a fixed sky direction (PLANET_DIR, matching
# SpaceSky.gdshader's own uniform), so facing the exact opposite
# direction puts it 180 degrees outside the frustum. Both cameras AND
# both crawl rigs are built relative to that "away" direction (via a
# proper looking-at basis, not hardcoded world axes), the same
# local-basis-instead-of-raw-world-axes idea the mirroring fix in
# SpaceSky.gdshader relies on — so everything stays consistent no matter
# which way PLANET_DIR itself happens to point.
#
# Tunable knobs, if the pacing feels off once you've actually watched it:
#   SCROLL_SPEED         — how fast the text rises (world units/sec)
#   AUTO_RETURN_DIST      — how far each half's text has to recede before
#                           moving on to the next stage
#   EXPLOSION_FREQ_MID/PEAK, EXPLOSION_AMOUNT_MID/PEAK — how far the
#                           finale's explosions escalate
#   FLAG_HOLD_DURATION    — how long the banner shot holds before fading out
# Pressing any key/mouse button skips straight to the main menu at any
# point, so a duration guess that runs long never actually traps anyone.
# =============================================================

enum Phase { READING_A, SNAPPING, READING_B, REVEALING, ESCALATING, DIVING, FLAG_HOLD }

var camera: Camera3D
var crawl_rig_a: Node3D
var crawl_label_a: Label3D
var crawl_rig_b: Node3D
var crawl_label_b: Label3D
var fade_rect: ColorRect
var sky_material: ShaderMaterial
var flag_mesh_instance: MeshInstance3D

const SCROLL_SPEED: float = 0.6
const CAMERA_FOV: float = 62.0
# More upright than a full theatrical crawl — still tilted back enough
# to read as receding into the distance, just not leaning back so hard
# it's straining to read.
const CRAWL_TILT_X: float = -0.45
const FORWARD_DIST: float = 9.0     # how far in front of camera each part starts
# How far below camera-centre each part starts — comfortably more than
# FORWARD_DIST * tan(CAMERA_FOV/2) (~5.4 units at the values above) so
# the very first line is already below the visible frustum, not merely
# low in frame. Paired with vertical_alignment = TOP below, which
# anchors the TOP line of text at this position and lets the rest of
# the (much taller) block hang further below it — so guaranteeing just
# this one line starts off-screen guarantees the whole block does.
const DOWN_OFFSET: float = 7.5

const SNAP_DURATION: float = 0.9
const SNAP_YAW: float = deg_to_rad(35.0)

const AUTO_RETURN_DIST: float = 16.0
const REVEAL_PAN_DURATION: float = 6.0
const ESCALATION_DURATION: float = 10.0

const DIVE_DURATION: float = 1.4
const DIVE_END_FOV: float = 16.0
const FLAG_REVEAL_FADE_DURATION: float = 1.0
const FLAG_CAMERA_FOV: float = 50.0
const FLAG_DISTANCE: float = 3.4
const FLAG_DRIFT_SPEED: float = 0.05
const FLAG_HOLD_DURATION: float = 7.0

const FADE_DURATION: float = 1.6

# Explosion frequency/brightness at each stage — see the matching
# uniforms in SpaceSky.gdshader (both default to 1.0, i.e. the planet's
# normal occasional-flash rate everywhere else this shader is used).
# Toned down from an earlier pass that ramped these much higher and
# ended up reading as too frantic for a finale beat.
const EXPLOSION_FREQ_START: float = 1.0
const EXPLOSION_FREQ_MID: float = 1.5
const EXPLOSION_FREQ_PEAK: float = 3.0
const EXPLOSION_AMOUNT_START: float = 1.0
const EXPLOSION_AMOUNT_MID: float = 1.4
const EXPLOSION_AMOUNT_PEAK: float = 2.0

# Same default planet_dir as SpaceSky.gdshader's uniform.
const PLANET_DIR := Vector3(1.0, -0.55, 0.04)

var _phase: int = Phase.READING_A
var _phase_time: float = 0.0
var _finishing: bool = false

var _away_dir: Vector3
var _snap_away_dir: Vector3
var _reading_basis: Basis
var _snap_to_basis: Basis
var _reveal_to_basis: Basis
var _reveal_from_basis: Basis

# NOTE: "[PARTNER NAME]" below is a placeholder — swap in your partner's
# actual name (or however you'd both like to be credited) before this
# ships anywhere final.
const PART1_TEXT := """ORBITAL DROP


EPILOGUE

Kerath-IV is quiet for the first time in longer than anyone
still breathing can remember.

Commander Vreth's hold on the hive spire broke the moment his
relay went dark, and with it went whatever was left holding
the enemy's scattered garrisons together. What followed
wasn't a battle so much as a retreat with nowhere left to
retreat to.

Squad Varro and Squad Kael, down to whoever answered the last
vox call, dug in around the final extraction zone as the
shuttle burned atmosphere on its way down. The data package
that cost so much to recover rode back up with them, intact,
into a sky finally clear of anything shooting back."""

const PART2_TEXT := """Command still doesn't know exactly what's on that drive. Only
that Kerath-IV was worth this much to someone, and that
whoever sent the first ships down here already knew that.

The platform lifts off. Behind it, a world starts, for once,
to go quiet on its own terms.


THE END



ORBITAL DROP


Created by

BEN
[PARTNER NAME]


A Year 12 Digital Technology assessment project


Built with Godot Engine



Thank you for playing."""


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_away_dir = (-PLANET_DIR).normalized()
	_snap_away_dir = _away_dir.rotated(Vector3.UP, SNAP_YAW)
	_reading_basis = Basis.looking_at(_away_dir, Vector3.UP)
	_snap_to_basis = Basis.looking_at(_snap_away_dir, Vector3.UP)
	_reveal_to_basis = Basis.looking_at(PLANET_DIR.normalized(), Vector3.UP)

	_build_space_sky()
	_build_scene()
	AudioManager.start_ambient()


# -------------------------------------------------------------------
# Sky — identical setup to CommandCentre._build_space_sky(), just with
# star_drift_speed turned on. That uniform defaults to 0.0 (see
# SpaceSky.gdshader), so nothing else that uses this same shader is
# affected by setting it here.
# -------------------------------------------------------------------
func _build_space_sky() -> void:
	var shader = load("res://Shaders/SpaceSky.gdshader")
	if shader == null:
		return

	sky_material = ShaderMaterial.new()
	sky_material.shader = shader
	sky_material.set_shader_parameter("star_drift_speed", 0.035)
	sky_material.set_shader_parameter("planet_explosion_frequency", EXPLOSION_FREQ_START)
	sky_material.set_shader_parameter("planet_explosion_amount", EXPLOSION_AMOUNT_START)

	var sky := Sky.new()
	sky.sky_material = sky_material
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


func _build_scene() -> void:
	# --- Camera --- anchored at the origin for the reading/reveal/dive
	# stages; only its orientation and FOV ever change there (it holds
	# dead still during READING_A/READING_B/ESCALATING so nothing
	# distracts from the text or the planet). It gets fully repositioned
	# once for the flag shot at the end (see _do_cut_swap()).
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = CAMERA_FOV
	camera.current = true
	add_child(camera)
	camera.global_transform = Transform3D(_reading_basis, Vector3.ZERO)

	crawl_rig_a = _build_crawl_rig("CrawlRigA", _reading_basis, PART1_TEXT)
	crawl_rig_b = _build_crawl_rig("CrawlRigB", _snap_to_basis, PART2_TEXT)
	crawl_label_a = crawl_rig_a.get_child(0)
	crawl_label_b = crawl_rig_b.get_child(0)

	# --- Skip hint --- a fixed 2D overlay, not part of the 3D crawl.
	var skip_layer := CanvasLayer.new()
	skip_layer.name = "SkipLayer"
	add_child(skip_layer)

	var skip_hint := Label.new()
	skip_hint.name = "SkipLabel"
	skip_hint.text = "Press any key to skip"
	skip_hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_hint.position = Vector2(-260, -50)
	skip_hint.size = Vector2(240, 30)
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_layer.add_child(skip_hint)

	# --- Fade layer --- transparent until a fade is actively happening;
	# reused for both the white "cut" wash and the final fade to black
	# (only the colour differs — see _do_cut_swap() / _finish()).
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "FadeLayer"
	fade_layer.layer = 10
	add_child(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)


# Builds one crawl rig + label, positioned/tilted relative to the given
# viewing basis rather than raw world axes (see the big header comment),
# and starting below that view's frustum so it rises INTO frame rather
# than being visible from the first frame.
func _build_crawl_rig(rig_name: String, view_basis: Basis, text: String) -> Node3D:
	var rig := Node3D.new()
	rig.name = rig_name
	var forward := -view_basis.z
	var view_down := -view_basis.y
	rig.position = forward * FORWARD_DIST + view_down * DOWN_OFFSET
	# Tilt back around the view's OWN right axis (not world X) by
	# composing an extra rotation after view_basis — this is what keeps
	# the "rises and recedes as it scrolls" motion working no matter
	# which way the camera is actually facing.
	rig.transform.basis = view_basis * Basis(Vector3.RIGHT, CRAWL_TILT_X)
	add_child(rig)

	var label := Label3D.new()
	label.name = "CrawlLabel"
	label.text = text
	label.font_size = 42
	label.pixel_size = 0.011
	label.width = 780.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# TOP anchors the origin at the first line, with the rest of the
	# (much taller) block hanging further below it — see DOWN_OFFSET's
	# comment for why that's what makes "start below the frustum" a
	# one-line guarantee instead of depending on the text's total length.
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# Amber, matching the main menu's accent colour (Color(1.0, 0.851,
	# 0.2) in MainMenu.gd) rather than a generic white crawl.
	label.modulate = Color(1.0, 0.851, 0.2)
	label.outline_size = 10
	label.outline_modulate = Color(0.02, 0.02, 0.03, 1.0)
	label.position = Vector3.ZERO
	rig.add_child(label)
	return rig


func _process(delta: float) -> void:
	if _finishing:
		return

	_phase_time += delta

	match _phase:
		Phase.READING_A:
			crawl_label_a.position.y += SCROLL_SPEED * delta
			if _receded_enough(crawl_label_a, _away_dir):
				_phase = Phase.SNAPPING
				_phase_time = 0.0

		Phase.SNAPPING:
			crawl_label_b.position.y += SCROLL_SPEED * delta
			var t = clamp(_phase_time / SNAP_DURATION, 0.0, 1.0)
			var eased = t * t * (3.0 - 2.0 * t)
			_set_camera_basis(_reading_basis.slerp(_snap_to_basis, eased))
			if t >= 1.0:
				_set_camera_basis(_snap_to_basis)
				_phase = Phase.READING_B
				_phase_time = 0.0

		Phase.READING_B:
			crawl_label_b.position.y += SCROLL_SPEED * delta
			if _receded_enough(crawl_label_b, _snap_away_dir):
				_reveal_from_basis = _snap_to_basis
				_phase = Phase.REVEALING
				_phase_time = 0.0

		Phase.REVEALING:
			var t = clamp(_phase_time / REVEAL_PAN_DURATION, 0.0, 1.0)
			var eased = t * t * (3.0 - 2.0 * t)
			_set_camera_basis(_reveal_from_basis.slerp(_reveal_to_basis, eased))
			_set_explosion_level(
				lerp(EXPLOSION_FREQ_START, EXPLOSION_FREQ_MID, eased),
				lerp(EXPLOSION_AMOUNT_START, EXPLOSION_AMOUNT_MID, eased)
			)
			if t >= 1.0:
				_set_camera_basis(_reveal_to_basis)
				crawl_rig_a.visible = false
				crawl_rig_b.visible = false
				_phase = Phase.ESCALATING
				_phase_time = 0.0

		Phase.ESCALATING:
			var t = clamp(_phase_time / ESCALATION_DURATION, 0.0, 1.0)
			var eased = t * t   # accelerating — explosions ramp faster as it goes
			_set_explosion_level(
				lerp(EXPLOSION_FREQ_MID, EXPLOSION_FREQ_PEAK, eased),
				lerp(EXPLOSION_AMOUNT_MID, EXPLOSION_AMOUNT_PEAK, eased)
			)
			if t >= 1.0:
				_phase = Phase.DIVING
				_phase_time = 0.0

		Phase.DIVING:
			var t = clamp(_phase_time / DIVE_DURATION, 0.0, 1.0)
			var eased = t * t
			camera.fov = lerp(CAMERA_FOV, DIVE_END_FOV, eased)
			fade_rect.color = Color(1.0, 1.0, 1.0, eased)
			if t >= 1.0:
				_do_cut_swap()
				_phase = Phase.FLAG_HOLD
				_phase_time = 0.0

		Phase.FLAG_HOLD:
			# A slow, gentle drift around the banner rather than a
			# static shot — contrast with the earlier "camera holds
			# still" reading phases is deliberate, this is a different
			# kind of beat.
			camera.rotate_y(FLAG_DRIFT_SPEED * delta)
			if _phase_time >= FLAG_HOLD_DURATION:
				_finish()


func _receded_enough(label: Label3D, away_dir: Vector3) -> bool:
	return label.global_transform.origin.dot(away_dir) > FORWARD_DIST + AUTO_RETURN_DIST


func _set_camera_basis(b: Basis) -> void:
	camera.global_transform = Transform3D(b, Vector3.ZERO)


func _set_explosion_level(freq: float, amount: float) -> void:
	if sky_material == null:
		return
	sky_material.set_shader_parameter("planet_explosion_frequency", freq)
	sky_material.set_shader_parameter("planet_explosion_amount", amount)


# The "sneaky cut" — swapped in at full white, so none of this is ever
# actually seen happening. Much simpler and more reliable than trying to
# render a real, continuous descent through cloud cover.
func _do_cut_swap() -> void:
	var old_env := get_node_or_null("SpaceEnvironment")
	if old_env:
		old_env.queue_free()

	var flat_env := Environment.new()
	flat_env.background_mode = Environment.BG_COLOR
	flat_env.background_color = Color(0.75, 0.79, 0.85)
	flat_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	flat_env.ambient_light_color = Color(1.0, 1.0, 1.0)
	flat_env.ambient_light_energy = 1.0
	flat_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR

	var flat_world_env := WorldEnvironment.new()
	flat_world_env.name = "FlagEnvironment"
	flat_world_env.environment = flat_env
	add_child(flat_world_env)

	camera.fov = FLAG_CAMERA_FOV
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, FLAG_DISTANCE))

	_build_flag()

	fade_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, FLAG_REVEAL_FADE_DURATION)
	tw.tween_callback(func() -> void: fade_rect.color = Color(0.0, 0.0, 0.0, 0.0))


func _build_flag() -> void:
	var flag_shader = load("res://Shaders/Flag.gdshader")
	var flag_tex = load("res://UI/Epilogue/orbital_drop_flag.png")
	if flag_shader == null or flag_tex == null:
		return

	var mat := ShaderMaterial.new()
	mat.shader = flag_shader
	mat.set_shader_parameter("logo_texture", flag_tex)

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(3.2, 2.0)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 1

	flag_mesh_instance = MeshInstance3D.new()
	flag_mesh_instance.name = "FlagMesh"
	flag_mesh_instance.mesh = mesh
	flag_mesh_instance.material_override = mat
	# PlaneMesh lies flat by default (normal facing +Y) — rotate +90
	# degrees around X so it stands upright facing +Z, toward the
	# camera positioned at (0, 0, FLAG_DISTANCE) looking back at the
	# origin. If it ever appears facing away/mirrored instead, flip the
	# sign here (untested outside this session — no live Godot to
	# confirm the rotation direction against).
	flag_mesh_instance.rotation.x = PI / 2.0
	add_child(flag_mesh_instance)


func _unhandled_input(event: InputEvent) -> void:
	if _finishing:
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_finish()


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	# Always fade through black regardless of what phase we were
	# interrupted in (e.g. a skip pressed mid-white-flash would otherwise
	# fade out through white instead) — only the alpha carries over.
	fade_rect.color = Color(0.0, 0.0, 0.0, fade_rect.color.a)
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, FADE_DURATION)
	tw.tween_callback(_return_to_menu)


func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
