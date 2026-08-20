extends StaticBody3D
# =============================================================
# VoxCaster.gd
# Attach to: StaticBody3D inside Vox-Caster_Array.tscn
# =============================================================


@onready var popup: Control = $VoxCasterPopup
var player: Node = null

var _alert_marker: Label3D = null
var _alert_bob_t: float = 0.0
# Best-effort height guess, not visually confirmed — the array's own
# CollisionShape3D (in this StaticBody3D's local space, same scale) tops
# out around local y ≈ 2.73, so this sits a bit above that. Nudge this if
# it ends up buried in/clipping the antenna mesh in-game.
const ALERT_MARKER_Y: float = 3.15


func _ready() -> void:
	popup.visible = false
	player = get_tree().get_first_node_in_group("player")
	popup.player = player
	_build_alert_marker()
	popup.attention_changed.connect(_on_attention_changed)

func open_popup() -> void:
	popup.visible = true
	popup.refresh()
	GuideManager.on_console_opened("vox")
	# Walking up and opening the console counts as noticing it — even if
	# the player never presses the in-popup Help button, which is the only
	# thing that actually clears _help_attention. Without this the "!"
	# would keep floating above an already-checked console indefinitely.
	_set_marker_visible(false)


func close_popup() -> void:
	popup.visible = false


# -------------------------------------------------------
# Floating "!" over the console — a much more discoverable version of the
# in-popup Help-button pulse (see VoxCasterPopup.attention_changed): that
# one only nudges a button nobody sees until they've already opened the
# console. This is visible from across the deck instead.
# -------------------------------------------------------
func _build_alert_marker() -> void:
	_alert_marker = Label3D.new()
	_alert_marker.text = "!"
	_alert_marker.font_size = 160
	_alert_marker.outline_size = 24
	_alert_marker.modulate = Color(1.0, 0.851, 0.2, 1.0)
	_alert_marker.outline_modulate = Color(0.15, 0.1, 0.0, 1.0)
	_alert_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_marker.no_depth_test = true
	_alert_marker.position = Vector3(0, ALERT_MARKER_Y, 0)
	_alert_marker.visible = false
	add_child(_alert_marker)


func _on_attention_changed(on: bool) -> void:
	_set_marker_visible(on)


func _set_marker_visible(on: bool) -> void:
	if _alert_marker == null:
		return
	_alert_marker.visible = on
	_alert_bob_t = 0.0


func _process(delta: float) -> void:
	if _alert_marker == null or not _alert_marker.visible:
		return
	_alert_bob_t += delta * 2.4
	_alert_marker.position.y = ALERT_MARKER_Y + sin(_alert_bob_t) * 0.18
