extends Node3D
# =============================================================
# Epilogue.gd
# =============================================================
# Plays once the whole 5-mission campaign has actually been won (wired up
# from the Command Throne's report screen — "View Epilogue" only shows
# there once Mission 5 itself is beaten). A Star-Wars-crawl-style text
# scroll in front of the same SpaceSky backdrop used aboard the Command
# Centre, ending on a "sneaky cut" — zoom hard into the planet, wash to
# white at the end of the zoom, and land on a
# simple flat 2D scene: just the Orbital Drop banner on its pole,
# centred on screen, rising up into place — instead of trying to render
# a believable continuous descent all the way to the surface (or any
# kind of full ground set). Every scene node here is built in code
# rather than hand-placed in a .tscn (same pattern CommandCentre.gd uses
# for its own sky), so there's nothing for the editor to lose track of.
#
# Runs as a state machine (see Phase / _phase) because the shot changes
# character several times rather than drifting continuously:
#
#   READING_A  — camera fixed, facing directly AWAY from the planet (a
#                pure starfield, no planet anywhere in frame) while the
#                first, lore-only half of the crawl scrolls past.
#   SNAPPING   — a quick whip-pan (not a slow drift) to a second "still
#                pure space" framing — the cut into the crawl's second
#                half.
#   READING_B  — camera fixed again at the new framing while the second
#                half (a little more lore, then "THE END") scrolls.
#   REVEALING  — once that text has scrolled fully away, the camera
#                slowly pans across to finally look at the planet.
#                Explosions on the planet's surface start ramping up as
#                it comes into view.
#   DIVING     — no separate held "explosions build up" beat anymore —
#                as soon as the pan finishes the FOV rushes inward,
#                magnifying the planet until its surface fills the frame,
#                while the explosions keep climbing to their peak and the
#                screen washes to white.
#                Note this is a pure FOV zoom, with no camera travel: the
#                planet is drawn by SpaceSky.gdshader as part of the sky,
#                i.e. at infinity, so moving the camera towards it would
#                not change its size on screen by a single pixel. Only
#                narrowing the FOV actually closes the distance.
#   FLAG_HOLD  — the "sneaky cut": at full white, the whole 3D space
#                scene is swapped for a plain flat-colour 2D backdrop
#                (built by _build_finale_2d() under a CanvasLayer, not a
#                walkable 3D space) with just the Orbital Drop banner on
#                its pole, centred on screen. The pole is planted and
#                static; the flag itself rises up the pole into place
#                (see FLAG_RAISE_DURATION) rather than just appearing
#                already flying at full mast. Much simpler and more
#                reliable than actually rendering a seamless descent
#                through atmosphere onto the surface.
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
#   SCROLL_SPEED         — how fast the space crawl text rises (world
#                           units/sec)
#   CRAWL_CLEAR_MARGIN    — cushion past the top of frame before the next
#                           beat starts. Each half now runs until its text
#                           is genuinely gone, so how long the crawl takes
#                           is set by SCROLL_SPEED and the length of the
#                           text itself, not by a fixed distance
#   EXPLOSION_FREQ_MID/PEAK, EXPLOSION_AMOUNT_MID/PEAK — how far the
#                           finale's explosions escalate (MID by the end
#                           of the REVEALING pan, PEAK by the end of the
#                           DIVING cut)
#   DIVE_END_FOV/DURATION — how far the final zoom pushes in and how long
#                           it takes (the whole of the dive beat)
#   CRAWL_BOOST_PER_TICK/MAX — how much a mouse-wheel notch speeds the
#                           crawl up, and the ceiling on that
#   FLAG_HOLD_DURATION    — how long the 2D finale holds before fading out
#   FLAG_TEX_WIDTH_PX, FLAG_CLOTH_HEIGHT_PX — how big the flag's visible
#                           cloth is drawn (the rect around it is sized
#                           from these; see FLAG_CLOTH_BAND)
#   POLE_WIDTH_PX/TOP_MARGIN_PX — how thick the pole is and how far it
#                           pokes up above the raised flag
#   FLAG_RAISE_DURATION   — how long the rise up the pole takes
# Pressing any key or mouse button skips straight to the main menu at any
# point, so a duration guess that runs long never actually traps anyone.
# The mouse WHEEL is the exception — it fast-forwards the crawl instead of
# skipping (see _unhandled_input), so a player who just wants to get to the
# ending faster has something short of an all-or-nothing skip.
# =============================================================

enum Phase { READING_A, SNAPPING, READING_B, REVEALING, DIVING, FLAG_HOLD }

var camera: Camera3D
var crawl_rig_a: Node3D
var crawl_label_a: Label3D
var crawl_rig_b: Node3D
var crawl_label_b: Label3D
var fade_rect: ColorRect
var sky_material: ShaderMaterial

# Extra crawl speed from the mouse wheel — see CRAWL_BOOST_PER_TICK.
var _scroll_boost: float = 0.0

# --- 2D finale ---
var flag_sprite: TextureRect
var _flag_base_y: float
var _flag_top_y: float

const SCROLL_SPEED: float = 0.6

# --- Mouse-wheel fast-forward, crawl only ---
# Wheel down piles on speed, wheel up bleeds it back off again (never below
# the normal pace, and never into reverse). The boost also decays on its
# own, which makes this an ACTIVE fast-forward: spin to keep the text
# moving, stop and it eases back to reading pace within about a second
# rather than staying stuck fast because of one stray flick.
#
# Deliberately limited to the crawl. The planet reveal, the zoom and the
# flag hold are fixed-length beats built around their own easing curves and
# the wash to white — letting the wheel rush those would just desynchronise
# the ending. See _crawl_is_scrolling().
const CRAWL_BOOST_PER_TICK: float = 1.1
const CRAWL_BOOST_MAX: float = 4.4
# How fast the boost bleeds away, in units of scroll speed per second.
const CRAWL_BOOST_DECAY: float = 5.0
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

# Each half of the crawl runs until the text has genuinely left the top of
# the frame — see _crawl_finished(). How long that takes depends on how
# tall the rendered block is, so it's measured from the label rather than
# guessed at with a fixed distance; SCROLL_SPEED is the knob for pacing.
#
# Cushion (world units) past the top of frame before the next beat starts,
# so the last line is unambiguously gone rather than still clipping the
# edge as the camera moves.
const CRAWL_CLEAR_MARGIN: float = 0.8
# Used only if Label3D hasn't built its text mesh yet when it's first
# asked (get_aabb() comes back empty). Comfortably taller than either half
# of the crawl, so the worst case is a slightly late hand-off rather than a
# phase that never ends.
const CRAWL_FALLBACK_BLOCK_HEIGHT: float = 24.0
const REVEAL_PAN_DURATION: float = 4.0

# The dive is now a pure FOV zoom (see the DIVING note in the header), so
# these two carry the whole beat on their own — pushed further in and given
# a little longer to breathe than when a cloud rushing past the camera was
# doing half the work of selling it.
const DIVE_DURATION: float = 1.8
const DIVE_END_FOV: float = 10.0
const FLAG_REVEAL_FADE_DURATION: float = 1.0
# Bumped up from the original 5.0 so there's a proper beat to actually
# watch the flag rise up the pole and settle before it fades out.
const FLAG_HOLD_DURATION: float = 9.0

# =============================================================
# 2D finale scene — a plain flat-colour CanvasLayer scene (Control/
# ColorRect/TextureRect) instead of an actual walkable 3D space. It's
# swapped in at full white by _do_cut_swap() the same way the old 3D
# ground scene was, then drawn on top of whatever's left of the 3D world
# (which no longer matters — it's fully covered). The flag's position is
# screen-fraction based (times get_viewport().get_visible_rect().size),
# not fixed pixel coordinates, so it stays centred at whatever resolution
# the game actually runs at.
# =============================================================
const SKY_COLOR := Color(0.72, 0.68, 0.6)

# Sized up from the old 150x96 banner-in-a-scene version — this is the
# only thing on screen now, so it reads as a hero shot rather than a
# small prop. Keeps the same ~1.56:1 aspect ratio as the source texture.
const FLAG_TEX_WIDTH_PX: float = 320.0
# How tall the visible CLOTH is meant to read on screen.
const FLAG_CLOTH_HEIGHT_PX: float = 205.0
# Flag2D.gdshader insets the cloth from the top and bottom of its quad by
# its edge_margin uniform (0.06 each side, which is also the headroom the
# wave needs), leaving the cloth occupying this fraction of the quad. Keep
# in sync with that uniform — if they drift, the flag just reads slightly
# larger or smaller than intended, nothing breaks.
const FLAG_CLOTH_BAND: float = 0.88
# So the RECT has to be drawn taller than the cloth is meant to look —
# the rest is the shader's wave headroom, which is transparent.
const FLAG_TEX_HEIGHT_PX: float = FLAG_CLOTH_HEIGHT_PX / FLAG_CLOTH_BAND
# How long the rise up the pole takes (see Phase.FLAG_HOLD in _process()).
const FLAG_RAISE_DURATION: float = 3.0

# --- Flagpole --- static (doesn't rise, unlike the flag itself). Its own
# width plus the flag's width are centred as one combined block so the
# whole pole+flag assembly sits in the middle of the screen, not just
# the flag texture on its own.
const POLE_WIDTH_PX: float = 10.0
# How far the pole pokes up above the flag RECT's fully-raised top edge.
# The visible cloth starts a further FLAG_TEX_HEIGHT_PX * (1 -
# FLAG_CLOTH_BAND) / 2 (~14px) below that, so the gap actually seen above
# the cloth is roughly this plus that — enough to read as a proper pole
# cap, not a bare stick the flag is taped to.
const POLE_TOP_MARGIN_PX: float = 14.0
# How far the pole's bottom extends past the bottom of the screen —
# reads as "planted, continuing off-frame" rather than a pole that just
# stops in mid-air.
const POLE_BOTTOM_OVERHANG_PX: float = 80.0
const POLE_COLOR := Color(0.24, 0.24, 0.26)

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


THE END"""


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
	# dead still during READING_A/READING_B so nothing distracts from
	# the text). It's left wherever DIVING
	# ends once the 2D finale takes over (see _do_cut_swap()) — the 2D
	# CanvasLayer fully covers it from that point on, so it no longer
	# matters where the 3D camera is actually pointed.
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
	# Explicitly hidden until READING_B actually starts — rig_b sits only
	# ~35 degrees off rig_a's view direction (SNAP_YAW), which isn't a lot
	# of clearance against a 62-degree FOV, so without this it could peek
	# into frame at the edge WHILE rig_a is still reading, reading as two
	# blocks of text sitting beside each other rather than one at a time.
	crawl_rig_b.visible = false

	# --- Skip hint --- a fixed 2D overlay, not part of the 3D crawl.
	var skip_layer := CanvasLayer.new()
	skip_layer.name = "SkipLayer"
	add_child(skip_layer)

	var skip_hint := Label.new()
	skip_hint.name = "SkipLabel"
	skip_hint.text = "Scroll to speed up  ·  Press any key to skip"
	skip_hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_hint.position = Vector2(-400, -50)
	skip_hint.size = Vector2(380, 30)
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_layer.add_child(skip_hint)

	# --- Fade layer --- transparent until a fade is actively happening;
	# reused for both the white "cut" wash and the final fade to black
	# (only the colour differs — see _do_cut_swap() / _finish()). Layer
	# 10 keeps it above the 2D finale (layer 5, see _build_finale_2d())
	# as well as the 3D world.
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
	# Bleed off any mouse-wheel boost. move_toward rather than a multiply so
	# it settles exactly on zero instead of creeping towards it forever.
	_scroll_boost = move_toward(_scroll_boost, 0.0, CRAWL_BOOST_DECAY * delta)

	match _phase:
		Phase.READING_A:
			crawl_label_a.position.y += _crawl_step(delta)
			if _crawl_finished(crawl_label_a, _reading_basis):
				# Hide A the instant B is due to take over — guarantees
				# the two crawls are never both on screen together during
				# the whip-pan, however far A has actually scrolled.
				crawl_rig_a.visible = false
				crawl_rig_b.visible = true
				_phase = Phase.SNAPPING
				_phase_time = 0.0

		Phase.SNAPPING:
			crawl_label_b.position.y += _crawl_step(delta)
			# Explicitly typed rather than inferred with := — clamp() and
			# friends are generic builtins, so := on them trips GDScript's
			# type inference. Same in the phases below.
			var t: float = clamp(_phase_time / SNAP_DURATION, 0.0, 1.0)
			var eased: float = t * t * (3.0 - 2.0 * t)
			_set_camera_basis(_reading_basis.slerp(_snap_to_basis, eased))
			if t >= 1.0:
				_set_camera_basis(_snap_to_basis)
				_phase = Phase.READING_B
				_phase_time = 0.0

		Phase.READING_B:
			crawl_label_b.position.y += _crawl_step(delta)
			if _crawl_finished(crawl_label_b, _snap_to_basis):
				_reveal_from_basis = _snap_to_basis
				_phase = Phase.REVEALING
				_phase_time = 0.0

		Phase.REVEALING:
			var t: float = clamp(_phase_time / REVEAL_PAN_DURATION, 0.0, 1.0)
			var eased: float = t * t * (3.0 - 2.0 * t)
			_set_camera_basis(_reveal_from_basis.slerp(_reveal_to_basis, eased))
			_set_explosion_level(
				lerp(EXPLOSION_FREQ_START, EXPLOSION_FREQ_MID, eased),
				lerp(EXPLOSION_AMOUNT_START, EXPLOSION_AMOUNT_MID, eased)
			)
			if t >= 1.0:
				_set_camera_basis(_reveal_to_basis)
				crawl_rig_a.visible = false
				crawl_rig_b.visible = false
				_phase = Phase.DIVING
				_phase_time = 0.0

		Phase.DIVING:
			var t: float = clamp(_phase_time / DIVE_DURATION, 0.0, 1.0)
			var eased: float = t * t
			# Pure FOV zoom, held at the origin. The camera used to also
			# ease forward, which was there to close on the dive cloud —
			# with that gone there is nothing left in the scene to travel
			# towards, since the planet lives in the sky shader and so sits
			# at infinity. Moving would cost frames and change nothing.
			camera.fov = lerp(CAMERA_FOV, DIVE_END_FOV, eased)
			# No separate held "explosions build up" beat anymore — they
			# climb the rest of the way to PEAK during this same dive
			# instead of camera holding still to watch them do it first.
			_set_explosion_level(
				lerp(EXPLOSION_FREQ_MID, EXPLOSION_FREQ_PEAK, eased),
				lerp(EXPLOSION_AMOUNT_MID, EXPLOSION_AMOUNT_PEAK, eased)
			)
			fade_rect.color = Color(1.0, 1.0, 1.0, eased)
			if t >= 1.0:
				_do_cut_swap()
				_phase = Phase.FLAG_HOLD
				_phase_time = 0.0

		Phase.FLAG_HOLD:
			# The flag rises up the pole into its resting position over
			# FLAG_RAISE_DURATION, then just sits there for the rest of
			# the hold — eased so the rise itself isn't a linear crawl.
			if flag_sprite:
				var raise_t: float = clamp(_phase_time / FLAG_RAISE_DURATION, 0.0, 1.0)
				var eased_raise: float = raise_t * raise_t * (3.0 - 2.0 * raise_t)
				flag_sprite.position.y = lerp(_flag_base_y, _flag_top_y, eased_raise)

			if _phase_time >= FLAG_HOLD_DURATION:
				_finish()


# Per-frame scroll distance for the crawl, mouse-wheel boost included.
func _crawl_step(delta: float) -> float:
	return (SCROLL_SPEED + _scroll_boost) * delta


# The wheel only drives the crawl itself — everything from the planet
# reveal onward is a fixed-length beat that shouldn't be rushed.
func _crawl_is_scrolling() -> bool:
	return _phase == Phase.READING_A or _phase == Phase.SNAPPING or _phase == Phase.READING_B


# True once the WHOLE text block has travelled up past the top edge of the
# frame — not merely its origin.
#
# This used to test the label's ORIGIN against a fixed recession distance
# (FORWARD_DIST + AUTO_RETURN_DIST). Two things were wrong with that. The
# origin sits at the block's TOP line (vertical_alignment = TOP, see
# _build_crawl_rig), with the rest of the text hanging below it, so its
# position says nothing about where the LAST line has got to. And at the
# tuned values it tripped after 18.4 units of scroll, while even the top
# line didn't clear the frame until 20.2 — so the whip-pan and the planet
# reveal both cut away with the text still visibly on screen.
#
# Instead: take the lowest point of the actual rendered text and ask
# whether it has passed above the top of the camera's frustum. Reading it
# from the label (rather than counting lines) means wrapping is accounted
# for automatically, so editing PART1_TEXT/PART2_TEXT can't silently
# reintroduce an early cut.
func _crawl_finished(label: Label3D, view_basis: Basis) -> bool:
	var bounds: AABB = label.get_aabb()
	var local_bottom: float = bounds.position.y
	if bounds.size.y <= 0.0:
		local_bottom = -CRAWL_FALLBACK_BLOCK_HEIGHT

	# Only the local Y offset matters: the rig is tilted about the view's own
	# RIGHT axis, so the block's local X maps onto that axis and contributes
	# nothing to either the depth or the height measured below.
	var bottom: Vector3 = label.global_transform * Vector3(0.0, local_bottom, 0.0)

	var depth: float = bottom.dot(-view_basis.z)
	if depth <= 0.01:
		# Behind the camera plane means NOT finished, which is worth spelling
		# out because the instinct is the opposite. The block is tilted away
		# from the camera, so its lowest line is its NEAREST point — on a long
		# enough crawl that line starts out behind the camera and only comes
		# forward as the text scrolls up (depth rises steadily with the
		# scroll). So this is the state before the block has cleared, never
		# after it, and the frustum test below wouldn't be meaningful here
		# anyway — the top plane extends backwards behind the camera too, so a
		# point behind and well below it would read as "above" the plane.
		return false

	# Half-height of the frustum at that depth. Camera3D.fov is the VERTICAL
	# field of view (keep_aspect defaults to KEEP_HEIGHT), which is the axis
	# the crawl actually travels along.
	var top_edge: float = depth * tan(deg_to_rad(CAMERA_FOV * 0.5))
	return bottom.dot(view_basis.y) > top_edge + CRAWL_CLEAR_MARGIN


func _set_camera_basis(b: Basis) -> void:
	camera.global_transform = Transform3D(b, Vector3.ZERO)


func _set_explosion_level(freq: float, amount: float) -> void:
	if sky_material == null:
		return
	sky_material.set_shader_parameter("planet_explosion_frequency", freq)
	sky_material.set_shader_parameter("planet_explosion_amount", amount)


# The "sneaky cut" — swapped in at full white (at the end of the zoom), so none
# of this is ever actually seen happening. The old 3D ground scene (sun,
# terrain, mound) is gone entirely now — the 2D finale (see
# _build_finale_2d()) fully covers the screen, so there's nothing left
# for the 3D camera/lighting to do.
func _do_cut_swap() -> void:
	var old_env := get_node_or_null("SpaceEnvironment")
	if old_env:
		old_env.queue_free()
	_build_finale_2d()

	fade_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, FLAG_REVEAL_FADE_DURATION)
	tw.tween_callback(func() -> void: fade_rect.color = Color(0.0, 0.0, 0.0, 0.0))


# =============================================================
# 2D finale scene builders
# =============================================================
# Builds the whole "sneaky cut" payload: a flat CanvasLayer scene
# instead of a walkable 3D space — just a flat backdrop colour with the
# flag on its pole, centred on screen, rising into place.
func _build_finale_2d() -> void:
	# get_viewport_rect() is a CanvasItem convenience method (Control /
	# Node2D) — this script extends Node3D, so it has to go through
	# get_viewport() (a plain Node method available everywhere) instead.
	var screen_size: Vector2 = get_viewport().get_visible_rect().size

	var layer := CanvasLayer.new()
	layer.name = "Finale2D"
	layer.layer = 5
	add_child(layer)

	var root := Control.new()
	root.name = "FinaleRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = SKY_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	_build_flag_2d(root, screen_size)


# The flag on its pole, the whole assembly centred on screen — the pole
# is planted and static; only the flag cloth itself rises.
func _build_flag_2d(root: Control, screen_size: Vector2) -> void:
	# Centre the POLE + FLAG combined width as one block, rather than
	# just the flag texture on its own, so the pole doesn't end up
	# off-centre once the flag is hanging off it.
	var total_width: float = POLE_WIDTH_PX + FLAG_TEX_WIDTH_PX
	var pole_x: float = (screen_size.x - total_width) * 0.5
	var flag_x: float = pole_x + POLE_WIDTH_PX

	# _flag_top_y (the flag's fully-raised resting position) has to be
	# known before the pole is sized, since the pole's top sits just
	# above it.
	_flag_base_y = screen_size.y
	_flag_top_y = (screen_size.y - FLAG_TEX_HEIGHT_PX) * 0.5

	var pole := ColorRect.new()
	pole.name = "FlagPole2D"
	pole.color = POLE_COLOR
	var pole_top_y: float = _flag_top_y - POLE_TOP_MARGIN_PX
	var pole_bottom_y: float = screen_size.y + POLE_BOTTOM_OVERHANG_PX
	pole.position = Vector2(pole_x, pole_top_y)
	pole.size = Vector2(POLE_WIDTH_PX, pole_bottom_y - pole_top_y)
	root.add_child(pole)

	var flag_shader = load("res://Shaders/Flag2D.gdshader")
	var flag_tex = load("res://UI/Epilogue/orbital_drop_flag.png")
	if flag_shader == null or flag_tex == null:
		return

	var mat := ShaderMaterial.new()
	mat.shader = flag_shader

	flag_sprite = TextureRect.new()
	flag_sprite.name = "Flag2D"
	flag_sprite.texture = flag_tex
	flag_sprite.material = mat
	flag_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	flag_sprite.size = Vector2(FLAG_TEX_WIDTH_PX, FLAG_TEX_HEIGHT_PX)
	# Pinned edge (UV.x = 0 in Flag2D.gdshader, the "pole" side) sits
	# right against the pole rather than overlapping or gapped from it.
	flag_sprite.position.x = flag_x
	root.add_child(flag_sprite)

	# Drives the rise tween in _process()'s Phase.FLAG_HOLD case — the
	# flag starts below the bottom of the screen and rises up the pole
	# into its resting position over FLAG_RAISE_DURATION, i.e. it's
	# "drawn up into the screen" rather than simply appearing already at
	# full mast.
	flag_sprite.position.y = _flag_base_y


func _unhandled_input(event: InputEvent) -> void:
	if _finishing:
		return

	# Wheel notches drive the crawl's speed and must be handled BEFORE the
	# skip test below, not after: a wheel notch arrives as an
	# InputEventMouseButton with pressed = true, so without this branch
	# catching them first, nudging the wheel would fall straight through to
	# _finish() and silently skip the entire epilogue.
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				if _crawl_is_scrolling():
					_scroll_boost = min(_scroll_boost + CRAWL_BOOST_PER_TICK, CRAWL_BOOST_MAX)
				return
			MOUSE_BUTTON_WHEEL_UP:
				if _crawl_is_scrolling():
					_scroll_boost = max(_scroll_boost - CRAWL_BOOST_PER_TICK, 0.0)
				return
			MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
				# Sideways trackpad scrolling — swallowed for the same
				# reason, so a stray horizontal flick can't skip either.
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
