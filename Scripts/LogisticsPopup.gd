extends Control
# =============================================================
# LogisticsPopup.gd
# Attach to: Control node named "LogisticsPopup" inside
#            LogisticsTerminal.tscn > StaticBody3D
#
# Builds its UI entirely in code — no extra scene setup needed.
# Reads squad list from SquadManager.
# On confirm, calls TurnManager.end_turn(allocations).
# =============================================================

var player: Node = null  # Set by LogisticsTerminal before opening

const SUPPLY_OPTIONS: Array = ["None", "Armaments", "Medi-Packs", "Fuel Cells"]
const SUPPLY_COST: Dictionary = {
	"None":       0,
	"Armaments":  2,
	"Medi-Packs": 2,
	"Fuel Cells": 2,
}

# allocations: { squad_name: { "Armaments": int, "Medi-Packs": int, "Fuel Cells": int } }
var allocations: Dictionary = {}
var squad_rows: Array = []

# UI node references
var budget_label:  Label
var warning_label: Label


func _ready() -> void:
	_build_ui()


# Called every time the popup opens to sync with current squad state
func refresh() -> void:
	_sync_allocations()
	_rebuild_squad_rows()
	_refresh_budget()


# -------------------------------------------------------
# Build UI in code
# -------------------------------------------------------
func _build_ui() -> void:
	# Size and anchor to centre of screen
	custom_minimum_size = Vector2(560, 0)
	set_anchors_preset(Control.PRESET_CENTER)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "LOGISTICS TERMINAL"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# Budget
	budget_label = Label.new()
	budget_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(budget_label)

	# Warning
	warning_label = Label.new()
	warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	warning_label.text = ""
	vbox.add_child(warning_label)

	vbox.add_child(HSeparator.new())

	# Column headers
	var header := HBoxContainer.new()
	for pair in [["Squad", 120], ["Status", 90], ["Armaments", 120], ["Medi-Packs", 120], ["Fuel Cells", 120]]:
		var lbl := Label.new()
		lbl.text = pair[0]
		lbl.custom_minimum_size.x = pair[1]
		lbl.add_theme_font_size_override("font_size", 12)
		header.add_child(lbl)
	vbox.add_child(header)

	vbox.add_child(HSeparator.new())

	# Squad rows container — rebuilt on refresh()
	var squad_container := VBoxContainer.new()
	squad_container.name = "SquadContainer"
	squad_container.add_theme_constant_override("separation", 8)
	vbox.add_child(squad_container)

	vbox.add_child(HSeparator.new())

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm Allocations"
	confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(confirm_btn)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)


func _rebuild_squad_rows() -> void:
	squad_rows.clear()
	var container = get_node_or_null("PanelContainer/VBoxContainer/SquadContainer")
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

	for squad in SquadManager.get_squads_for_ui():
		if squad.status == SquadManager.Status.LOST:
			continue
		var row_data = _build_squad_row(squad, container)
		squad_rows.append(row_data)


func _build_squad_row(squad: Dictionary, container: Node) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = squad.name
	name_lbl.custom_minimum_size.x = 120
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	var status_lbl := Label.new()
	status_lbl.text = SquadManager.STATUS_NAMES[squad.status]
	status_lbl.custom_minimum_size.x = 90
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.add_theme_color_override("font_color", _status_color(squad.status))
	row.add_child(status_lbl)

	var dropdowns: Dictionary = {}
	for supply in ["Armaments", "Medi-Packs", "Fuel Cells"]:
		var opt := OptionButton.new()
		opt.custom_minimum_size.x = 120
		for option in SUPPLY_OPTIONS:
			opt.add_item(option)
		# Restore saved selection
		var saved_cost = allocations.get(squad.name, {}).get(supply, 0)
		opt.selected = 0
		for i in SUPPLY_OPTIONS.size():
			if SUPPLY_COST[SUPPLY_OPTIONS[i]] == saved_cost and saved_cost > 0:
				opt.selected = i
				break
		opt.item_selected.connect(_on_supply_changed.bind(squad.name, supply, opt))
		row.add_child(opt)
		dropdowns[supply] = opt

	container.add_child(row)
	return { "squad": squad.name, "dropdowns": dropdowns }


# -------------------------------------------------------
# Logic
# -------------------------------------------------------
func _sync_allocations() -> void:
	for squad in SquadManager.get_squads_for_ui():
		if not allocations.has(squad.name):
			allocations[squad.name] = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }


func _on_supply_changed(_index: int, squad_name: String, supply: String, opt: OptionButton) -> void:
	if not allocations.has(squad_name):
		allocations[squad_name] = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	allocations[squad_name][supply] = SUPPLY_COST[SUPPLY_OPTIONS[opt.selected]]
	_refresh_budget()


func _refresh_budget() -> void:
	var total_budget = GameManager.get_current_mission_data().get("budget", 12)
	var spent: int = 0
	for squad_name in allocations:
		for supply in allocations[squad_name]:
			spent += allocations[squad_name][supply]
	var remaining = total_budget - spent
	budget_label.text = "Budget:  %d / %d  (%d remaining)" % [spent, total_budget, remaining]
	if remaining < 0:
		budget_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		warning_label.text = "Over budget! Remove some allocations."
	else:
		budget_label.remove_theme_color_override("font_color")
		warning_label.text = ""


func _on_confirm_pressed() -> void:
	var total_budget = GameManager.get_current_mission_data().get("budget", 12)
	var spent: int = 0
	for squad_name in allocations:
		for supply in allocations[squad_name]:
			spent += allocations[squad_name][supply]
	if spent > total_budget:
		warning_label.text = "Cannot confirm — over budget!"
		return

	warning_label.text = ""

	# Resolve the turn
	TurnManager.end_turn(allocations)

	# Reset allocations for next turn
	for squad_name in allocations:
		for supply in allocations[squad_name]:
			allocations[squad_name][supply] = 0

	_on_close_pressed()


func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()


func _status_color(status: int) -> Color:
	match status:
		SquadManager.Status.ACTIVE:   return Color(0.4, 0.9, 0.4)
		SquadManager.Status.WOUNDED:  return Color(0.9, 0.7, 0.2)
		SquadManager.Status.CRITICAL: return Color(0.9, 0.3, 0.3)
	return Color.WHITE
