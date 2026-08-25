extends Node
# =============================================================
# AudioManager.gd — AutoLoad singleton
#
# Central sound player: UI/console clicks, console alerts (alarms),
# orbital strike cannon fire, and a rotating background ambience loop.
#
# To add or change a sound, edit the constants below — nothing else
# in the file needs to change. All SFX play through the "SFX" audio
# bus and the ambience loop plays through "Music", both of which
# SettingsManager already has volume sliders wired up for.
# =============================================================

const SFX_DIR = "res://Sounds/Music/Sounds for Orbital Drop/"

# ---- Button clicks — two distinct sounds ----
# BOTTOM: the button row every console popup shares along its bottom edge
# (Close, Help, End Turn, Lock) — plus opening/closing a console itself.
# OTHER: everything else (placement confirm/cancel, call reinforcement,
# arm bombardment, next mission) — the more specific, less frequent actions.
const BUTTON_CLICK_BOTTOM: String = SFX_DIR + "Buttons/cyber-elecrtic-sci-fi-digital-robot-ui-6.mp3"
const BUTTON_CLICK_OTHER: String  = SFX_DIR + "Buttons/cyber-elecrtic-sci-fi-digital-robot-ui-10.mp3"

# ---- Console alert — plays whenever a console has something new to
# report (reinforcement warnings/landings, priority target down, data
# destroyed/lost, etc.), whether or not that console is currently open ----
const ALARM: String = SFX_DIR + "Space Ambience/edr-synth-alarm-01-169969.mp3"

# ---- Orbital strike cannon fire ----
const CANNON_FIRE: String = SFX_DIR + "Laser Cannon Sounds/gman-lasers.mp3"

# ---- Background ambience — rotates between these (not the full set of
# 5) so the loop doesn't get too repetitive across a long session. Add/
# remove entries here to change the rotation. ----
const AMBIENT_TRACKS: Array[String] = [
	SFX_DIR + "Space Ambience/audiopapkin-ambient-soundscapes-001-space-atmosphere-303246.mp3",
	SFX_DIR + "Space Ambience/audiopapkin-ambient-soundscapes-004-space-atmosphere-303243.mp3",
	SFX_DIR + "Space Ambience/audiopapkin-ambient-soundscapes-007-space-atmosphere-304974.mp3",
]

const SFX_POOL_SIZE: int = 6

var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _ambient_player: AudioStreamPlayer
var _ambient_order: Array[String] = []
var _stream_cache: Dictionary = {}  # path -> loaded AudioStream, avoids re-loading every play


func _ready() -> void:
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Music"
	add_child(_ambient_player)
	_ambient_player.finished.connect(_on_ambient_finished)

	# Ambience runs continuously from boot (menu through every mission) —
	# call stop_ambient() from anywhere if a scene ever needs quiet.
	start_ambient()


func _load(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	var stream = load(path)
	if stream == null:
		push_warning("AudioManager: couldn't load %s" % path)
		return null
	_stream_cache[path] = stream
	return stream


func _play_sfx(path: String, volume_offset_db: float = 0.0) -> void:
	var stream = _load(path)
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_pool[_pool_index]
	_pool_index = (_pool_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_offset_db
	player.play()


func play_button_bottom() -> void:
	_play_sfx(BUTTON_CLICK_BOTTOM)


func play_button_other() -> void:
	_play_sfx(BUTTON_CLICK_OTHER)


# The source file plays quite loud/harsh at its native level next to
# everything else routed through this manager — knocked it down a fair
# bit by default so it reads as an alert chime instead of a jump-scare.
# Bump ALARM_VOLUME_DB back toward 0 (or positive) if it ends up too
# quiet once actually heard in-game.
const ALARM_VOLUME_DB: float = -10.0

func play_alarm() -> void:
	_play_sfx(ALARM, ALARM_VOLUME_DB)


func play_cannon_fire() -> void:
	_play_sfx(CANNON_FIRE, 2.0)


# How long the cannon-fire clip runs, so a visual effect can be matched to
# it rather than to a hardcoded guess that drifts the moment the sound is
# swapped (see CommandCentre._fire_orbital_laser()). Read off the stream
# itself; the fallback covers the sound failing to load, which does happen
# — some clips in this folder are currently missing from disk and log a
# "Failed loading resource" on startup.
const CANNON_FIRE_FALLBACK_LENGTH: float = 2.2

func get_cannon_fire_length() -> float:
	var stream = _load(CANNON_FIRE)
	if stream == null:
		return CANNON_FIRE_FALLBACK_LENGTH
	var seconds: float = stream.get_length()
	# Some imported formats report 0 when the length isn't known ahead of
	# time; treat that as "no idea" rather than "instantaneous".
	if seconds <= 0.05:
		return CANNON_FIRE_FALLBACK_LENGTH
	return seconds


# -------------------------------------------------------
# Background ambience — shuffled rotation through AMBIENT_TRACKS,
# never repeating a track until the whole set has played once.
# -------------------------------------------------------
func start_ambient() -> void:
	if _ambient_player.playing:
		return
	_queue_next_ambient()


func stop_ambient() -> void:
	_ambient_player.stop()


func _queue_next_ambient() -> void:
	if AMBIENT_TRACKS.is_empty():
		return
	if _ambient_order.is_empty():
		_ambient_order = AMBIENT_TRACKS.duplicate()
		_ambient_order.shuffle()
	var next_path: String = _ambient_order.pop_front()
	var stream = _load(next_path)
	if stream == null:
		return
	_ambient_player.stream = stream
	_ambient_player.play()


func _on_ambient_finished() -> void:
	_queue_next_ambient()
