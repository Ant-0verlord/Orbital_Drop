extends CanvasLayer

@onready var mission_label:  Label   = $BG/VBoxContainer/MissionLabel
@onready var class_label:    Label   = $BG/VBoxContainer/ClassLabel
@onready var briefing_text:  Label   = $BG/VBoxContainer/BriefingText
@onready var objective_text: Label   = $BG/VBoxContainer/ObjectiveText
@onready var map_preview:    Control = $BG/VBoxContainer/MapPreview
@onready var begin_btn:      Button  = $BG/VBoxContainer/BeginBtn

signal briefing_dismissed

const BRIEFINGS = [
	{
		"title":     "MISSION 01 — LANDFALL",
		"class":     "PRIORITY: ALPHA — COMMAND EYES ONLY",
		"narrative": "Insertion successful. Drop-pods have made contact with the surface of Kerath-IV. Initial scans confirm enemy presence across the landing zone — resistance was anticipated. Your squads are on the ground and awaiting orders from the Command Post.\n\nIntelligence suggests a high-value target is operating somewhere on this planet. Before we can locate them, we need to establish a foothold. Secure the surrounding sectors and eliminate any opposition that threatens the beachhead.\n\nFamiliarise yourself with Command Post systems. The Intel Desk, Vox-Caster, Logistics Terminal, Holo-Map and Command Throne are all online and at your disposal.",
		"objective": "Secure the landing zone. Hold 4 sectors by end of Turn 5.",
	},
	{
		"title":     "MISSION 02 — ADVANCE ON KERATH-IV",
		"class":     "PRIORITY: ALPHA — RESTRICTED DISTRIBUTION",
		"narrative": "The beachhead is established. We are pushing deeper into enemy-held territory along the Kerath-IV corridor. Ground teams have identified a viable advance route, but enemy forces are dug in and contesting every metre.\n\nEliminate all resistance in the operational theatre. We cannot afford to leave enemy units behind us as we push toward the interior — any stragglers will compromise the follow-on operation.\n\nReinforcement drop-pods have been authorised for this operation. If squads take heavy casualties, call in replacements through the Logistics Terminal. Be advised: enemy command has signalled for their own reinforcements. We have a window — use it.",
		"objective": "Eliminate all enemy forces in the operational theatre.",
	},
	{
		"title":     "MISSION 03 — THE IRON SALIENT",
		"class":     "PRIORITY: ALPHA — COMMAND CLEARANCE REQUIRED",
		"narrative": "Signals intelligence has identified a strategic communications tower at the centre of the Iron Salient — a ring of fortified positions deep in enemy-controlled terrain. This tower is the key.\n\nIf we can power the tower and hold it, we can triangulate the position of the enemy field commander directing resistance across the entire theatre. Command has designated this target VRETH. Without the tower active, Vreth's location remains unknown and the campaign stalls.\n\nEnemy forces know what we are attempting. Wave assaults are inbound through the passage corridors surrounding the position. Squads carrying Fuel Cells must reach the tower, power it over two consecutive turns, and hold it until the triangulation is complete. Do not let the tower fall.",
		"objective": "Power and hold the comms tower at sector Gamma-5B. Tower requires Fuel Cells for two consecutive turns to activate.",
	},
	{
		"title":     "MISSION 04 — CONTESTED HIVE SPIRE",
		"class":     "PRIORITY: SOVEREIGN — COMMAND CLEARANCE REQUIRED",
		"narrative": "Tower triangulation confirms it. Commander Vreth is operating from within the Hive Spire — a semi-subterranean network of cave passages and fortified chambers in the interior. Vreth is directing all enemy operations on Kerath-IV from this position.\n\nYour squads breach from two separate entry points on opposite flanks. Fight through to the centre and eliminate Vreth. The data package Vreth carries contains full enemy order-of-battle intelligence for the sector — it is the reason this entire campaign was authorised. It must be recovered intact.\n\nNote: the cave structure is partial, not sealed. Orbital assets remain effective throughout the network. However, do not deploy orbital strikes on Vreth's position directly. The data package will not survive the blast radius.\n\nBe advised: Vreth's death does not end this. The Spire has its own relay tower — take it and get it powered. Every hostile still on the field will contest it, but without that tower Command has no way to triangulate a safe extraction point on this stretch of the surface. Hold the relay and we can pinpoint exactly where to bring the shuttle down.",
		"objective": "Locate and eliminate Commander Vreth. Recover the data package intact, then take and power the relay tower — it's what lets Command pinpoint an extraction zone for the next phase. Orbital strikes are effective but must not target Vreth directly.",
	},
	{
		"title":     "MISSION 05 — EXTRACTION",
		"class":     "PRIORITY: SOVEREIGN — EYES ONLY — DESTROY AFTER READING",
		"narrative": "Vreth is down. The data package is secured. The Hive Spire relay you took and powered gave Command exactly what they needed — a designated extraction zone on the surface. The shuttle is not down yet — hold the theatre around it.\n\nEnemy forces are fully aware of what we are carrying and are massing toward the extraction zone from multiple vectors. Engage them, hold ground, fight this normally. Command will signal the moment the shuttle is inbound — from that point every squad has a short window to break off and converge on the zone before it lifts.\n\nThe squad carrying the data package is the priority — it must be aboard when the shuttle leaves. Any squad still off the zone when it lifts is left behind. There will be no second run.\n\nHold the line. Watch for the shuttle call. Get off this planet.",
		"objective": "Hold the theatre around the extraction zone. Once the shuttle is inbound, converge with all surviving squads before the final turn. The data carrier must extract for full mission success.",
	},
]

func _ready() -> void:
	begin_btn.pressed.connect(_on_begin_pressed)
	visible = false

func show_briefing(mission_index: int, zone_states: Dictionary, axial_map: Dictionary) -> void:
	if mission_index >= BRIEFINGS.size():
		emit_signal("briefing_dismissed")
		return

	var data = BRIEFINGS[mission_index]
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
