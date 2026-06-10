extends Control
# =============================================================
# LogisticsPopup.gd — fullscreen popup
# UI built in scene, not in code.
# =============================================================

var player: Node = null

const SUPPLY_COST: int = 2

var allocations: Dictionary = {}
var squad_rows: Array = []

@onready var turn_label: Label              = $PanelContainer/VBoxContainer/TurnLabel
@onready var held_label: Label              = $PanelContainer/VBoxContainer/HeldLabel
@onready var pool_label: Label              = $PanelContainer/VBoxContainer/PoolLabel
@onready var budget_label: Label            = $PanelContainer/VBoxContainer/BudgetLabel
@onready var warning_label: Label           = $PanelContainer/VBoxContainer/WarningLabel
@onready var squad_container: VBoxContainer = $PanelContainer/VBoxContainer/SquadContainer
@onready var lock_btn: Button               = $PanelContainer/VBoxContainer/ButtonRow/LockBtn
@onready var close_btn: Button              = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn
@onready var end_overlay: ColorRect         = $EndOverlay
@onready var end_title: Label               = $EndOverlay/EndVBox/EndTitle
@onready var end_body: Label                = $EndOverlay/EndVBox/EndBody
@onready var end_close: Button              = $EndOverlay/EndVBox/EndClose


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.allocations_locked.connect(_on_allocations_locked)
	TurnManager.mission_complete.connect(_on_mission_complete)

	lock_btn.pressed.connect(_on_lock_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	end_close.pressed.connect(_on_close_pressed)

	end_overlay.visible = false
	warning_label.text = ""


func _on_turn_started(_turn: int) -> void:
	if visible: refresh()

func _on_turn_resolved() -> void:
	if visible: refresh()

func _on_allocations_locked() -> void:
	lock_btn.text = "✓ Locked"
	lock_btn.disabled = true

func _on_mission_complete(report: Dictionary) -> void:
	_show_mission_end(report)


func refresh() -> void:
	if SquadManager.squads.is_empty(): return
	_sync_allocations()
	_rebuild_squad_rows()
	_refresh_pool()
	_refresh_budget()
	if not TurnManager.mission_over:
		lock_btn.text = "Lock Allocations"
		lock_btn.disabled = false


func _rebuild_squad_rows() -> void:
	if turn_label:
		turn_label.text = "Turn %d / %d" % [TurnManager.current_turn, TurnManager.max_turns]
	if held_label:
		var held = EnemyManager.get_held_count()
		var req  = TurnManager.win_condition_hexes
		held_label.text = "Held: %d / %d required" % [held, req]
		held_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if held >= req else Color(0.9, 0.6, 0.2))

	squad_rows.clear()
	for child in squad_container.get_children():
		child.queue_free()

	for squad in SquadManager.get_squads_for_ui():
		if squad.status == SquadManager.Status.LOST: continue
		squad_rows.append(_build_squad_row(squad))


func _build_squad_row(squad: Dictionary) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Squad name
	var name_lbl := Label.new()
	name_lbl.text = squad.name
	name_lbl.custom_minimum_size.x = 120
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	# Status + sector
	var info_lbl := Label.new()
	info_lbl.text = "%s\n%s" % [SquadManager.STATUS_NAMES[squad.status], squad.sector]
	info_lbl.custom_minimum_size.x = 130
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.add_theme_color_override("font_color", _status_color(squad.status))
	row.add_child(info_lbl)

	# One checkbox per supply type
	var checkboxes: Dictionary = {}
	for supply in ["Armaments", "Medi-Packs", "Fuel Cells"]:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 110

		var cb := CheckBox.new()
		cb.text = supply
		cb.add_theme_font_size_override("font_size", 12)
		cb.disabled = TurnManager.mission_over

		# Restore saved state
		var saved = allocations.get(squad.name, {}).get(supply, 0)
		cb.button_pressed = saved > 0

		cb.toggled.connect(_on_supply_toggled.bind(squad.name, supply))
		col.add_child(cb)

		# Show cost hint
		var cost_lbl := Label.new()
		cost_lbl.text = "(%d pts)" % SUPPLY_COST
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		col.add_child(cost_lbl)

		row.add_child(col)
		checkboxes[supply] = cb

	squad_container.add_child(row)

	# Divider between squads
	var sep := HSeparator.new()
	squad_container.add_child(sep)

	return { "squad": squad.name, "checkboxes": checkboxes }


func _sync_allocations() -> void:
	for squad in SquadManager.get_squads_for_ui():
		if not allocations.has(squad.name):
			allocations[squad.name] = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }


func _on_supply_toggled(pressed: bool, squad_name: String, supply: String) -> void:
	if TurnManager.mission_over: return
	if not allocations.has(squad_name):
		allocations[squad_name] = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	allocations[squad_name][supply] = SUPPLY_COST if pressed else 0
	if TurnManager.allocations_are_locked:
		TurnManager.allocations_are_locked = false
		lock_btn.text = "Lock Allocations"
		lock_btn.disabled = false
	_refresh_budget()


func _refresh_pool() -> void:
	if pool_label == null: return
	var pool = GameManager.get_supply_pool()
	pool_label.text = "Mission Pool — Armaments: %d  |  Medi-Packs: %d  |  Fuel Cells: %d" % [
		pool.get("Armaments", 0),
		pool.get("Medi-Packs", 0),
		pool.get("Fuel Cells", 0),
	]
	var low = false
	for s in pool:
		if pool[s] <= 2:
			low = true
	pool_label.add_theme_color_override("font_color",
		Color(0.9, 0.5, 0.2) if low else Color(0.7, 0.85, 1.0))


func _refresh_budget() -> void:
	var pool = GameManager.get_supply_pool()
	var pending: Dictionary = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	for sn in allocations:
		for s in allocations[sn]:
			if pending.has(s):
				pending[s] += allocations[sn][s]

	var over = false
	var parts = []
	for s in ["Armaments", "Medi-Packs", "Fuel Cells"]:
		var p   = pool.get(s, 0)
		var pen = pending.get(s, 0)
		parts.append("%s: %d/%d" % [s, pen, p])
		if pen > p:
			over = true

	budget_label.text = "This turn:  " + "   ".join(parts)

	if over:
		budget_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		warning_label.text = "Over pool limit on one or more supply types!"
	else:
		budget_label.remove_theme_color_override("font_color")
		warning_label.text = ""


func _on_lock_pressed() -> void:
	if TurnManager.mission_over: return
	var pool = GameManager.get_supply_pool()
	var pending: Dictionary = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	for sn in allocations:
		for s in allocations[sn]:
			if pending.has(s):
				pending[s] += allocations[sn][s]
	for s in pending:
		if pending[s] > pool.get(s, 0):
			warning_label.text = "Cannot lock — %s exceeds mission pool!" % s
			return
	warning_label.text = ""
	TurnManager.lock_allocations(allocations)


func _show_mission_end(report: Dictionary) -> void:
	lock_btn.disabled = true
	lock_btn.text = "—"
	end_overlay.visible = true

	var won     = report.get("won", false)
	var held    = report.get("held_hexes", 0)
	var req     = report.get("required_hexes", 0)
	var rating  = report.get("rating", "—")
	var score   = report.get("score", 0)
	var t_score = report.get("tile_score", 0)
	var t_bonus = report.get("turn_bonus", 0)
	var s_bonus = report.get("supply_bonus", 0)
	var turns   = report.get("turns", 0)

	end_title.text = "MISSION COMPLETE" if won else "MISSION FAILED"
	end_title.add_theme_color_override("font_color",
		Color(0.4, 0.9, 0.4) if won else Color(0.9, 0.3, 0.3))
	end_title.add_theme_font_size_override("font_size", 32)

	end_body.text = (
		"Rating: %s  |  Score: %d\n\nTile: %d   Turn bonus: %d   Supply bonus: %d\nSectors held: %d / %d   Turns: %d\n\nSee Command Throne for full debrief."
		% [rating, score, t_score, t_bonus, s_bonus, held, req, turns]
	)
	end_body.add_theme_font_size_override("font_size", 14)
	end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD


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
