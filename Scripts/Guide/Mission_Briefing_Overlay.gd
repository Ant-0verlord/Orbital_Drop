extends CanvasLayer
# =============================================================
# MissionBriefingOverlay.gd
# Full-screen mission briefing before each mission starts.
# =============================================================

@onready var mission_label:   Label   = $BG/VBoxContainer/MissionLabel
@onready var class_label:     Label   = $BG/VBoxContainer/ClassLabel
@onready var briefing_text:   Label   = $BG/VBoxContainer/BriefingText
@onready var objective_text:  Label   = $BG/VBoxContainer/ObjectiveText
@onready var map_preview:     Control = $BG/VBoxContainer/MapPreview
@onready var begin_btn:       Button  = $BG/VBoxContainer/BeginBtn

signal briefing_dismissed

func _ready() -> void:
	begin_btn.pressed.connect(_on_begin_pressed)
	visible = false

func show_briefing(mission_index: int, zone_states: Dictionary, axial_map: Dictionary) -> void:
	if mission_index >= MissionBriefingOverlay.BRIEFINGS.size():
		emit_signal("briefing_dismissed")
		return

	var data = MissionBriefingOverlay.BRIEFINGS[mission_index]
	mission_label.text  = data.title
	class_label.text    = data.get("class", "")
	briefing_text.text  = data.narrative
	objective_text.text = data.objective

	# Pass zone states to hex preview
	map_preview.setup(zone_states, axial_map)

	visible = true
	begin_btn.disabled = true

	# Enable begin after 2 seconds
	await get_tree().create_timer(2.0).timeout
	begin_btn.disabled = false

func _on_begin_pressed() -> void:
	visible = false
	emit_signal("briefing_dismissed")
