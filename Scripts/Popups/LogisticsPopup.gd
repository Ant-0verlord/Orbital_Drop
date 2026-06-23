extends Control
# =============================================================
# LogisticsPopup.gd — fullscreen popup
# UI built in scene, not in code.
# =============================================================

var player: Node = null

const SUPPLY_COST: int = 2

var allocations: Dictionary = {}
var squad_rows: Array = []
var pending_reinforcement_name: String = ""

@onready var turn_label: Label              = $PanelContainer/VBoxContainer/TurnLabel
@onready var held_label: Label              = $PanelContainer/VBoxContainer/HeldLabel
@onready var pool_label: Label              = $PanelContainer/VBoxContainer/PoolLabel
@onready var budget_label: Label            = $PanelContainer/VBoxContainer/BudgetLabel
@onready var warning_label: Label           = $PanelContainer/VBoxContainer/WarningLabel
@onready var squad_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/SquadContainer
@onready var lock_btn: Button               = $PanelContainer/VBoxContainer/ButtonRow/LockBtn
@onready var close_btn: Button              = $PanelContainer/VBoxContainer/ButtonRow/CloseBtn
@onready var end_overlay: ColorRect         = $EndOverlay
@onready var end_title: Label               = $EndOverlay/EndVBox/EndTitle
@onready var end_body: Label                = $EndOverlay/EndVBox/EndBody
@onready var end_close: Button              = $EndOverlay/EndVBox/EndClose

# Reinforcement section nodes — added to scene under VBoxContainer
@onready var reinforcement_panel: PanelContainer = $PanelContainer/VBoxContainer/ReinforcementPanel
@onready var reinforcement_pool_label: Label     = $PanelContainer/VBoxContainer/ReinforcementPanel/RVBox/ReinforcementPoolLabel
@onready var reinforcement_name_btn: OptionButton = $PanelContainer/VBoxContainer/ReinforcementPanel/RVBox/ReinforcementNameBtn
@onready var call_reinforcement_btn: Button      = $PanelContainer/VBoxContainer/ReinforcementPanel/RVBox/CallReinforcementBtn
@onready var reinforcement_status_label: Label   = $PanelContainer/VBoxContainer/ReinforcementPanel/RVBox/ReinforcementStatusLabel

@onready var bombardment_panel: PanelContainer = $PanelContainer/VBoxContainer/BombardmentPanel
@onready var bombardment_pool_label: Label     = $PanelContainer/VBoxContainer/BombardmentPanel/BVBox/BombardmentPoolLabel
@onready var arm_bombardment_btn: Button       = $PanelContainer/VBoxContainer/BombardmentPanel/BVBox/ArmBombardmentBtn
@onready var bombardment_status_label: Label   = $PanelContainer/VBoxContainer/BombardmentPanel/BVBox/BombardmentStatusLabel


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.allocations_locked.connect(_on_allocations_locked)
	TurnManager.mission_complete.connect(_on_mission_complete)

	lock_btn.pressed.connect(_on_lock_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	end_close.pressed.connect(_on_close_pressed)
	call_reinforcement_btn.pressed.connect(_on_call_reinforcement_pressed)

	end_overlay.visible = false
	warning_label.text = ""

	_refresh_reinforcement_panel()


func _on_turn_started(_turn: int) -> void:
	_reset_allocations()
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
	_refresh_reinforcement_panel()
	_refresh_bombardment_panel()
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

	var name_lbl := Label.new()
	name_lbl.text = squad.name
	name_lbl.custom_minimum_size.x = 120
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	var info_lbl := Label.new()
	info_lbl.text = "%s\n%s" % [SquadManager.STATUS_NAMES[squad.status], squad.sector]
	info_lbl.custom_minimum_size.x = 130
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.add_theme_color_override("font_color", _status_color(squad.status))
	row.add_child(info_lbl)

	var checkboxes: Dictionary = {}
	for supply in ["Armaments", "Medi-Packs", "Fuel Cells"]:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 110

		var cb := CheckBox.new()
		cb.text = supply
		cb.add_theme_font_size_override("font_size", 12)
		cb.disabled = TurnManager.mission_over

		var saved = allocations.get(squad.name, {}).get(supply, 0)
		cb.button_pressed = saved > 0

		col.add_child(cb)

		var cost_lbl := Label.new()
		cost_lbl.text = "(%d pts)" % SUPPLY_COST
		cost_lbl.add_theme_font_size_override("font_size", 10)
		cost_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		col.add_child(cost_lbl)

		row.add_child(col)
		checkboxes[supply] = cb

	# Wire up mutual exclusion AFTER all checkboxes exist
	for supply in checkboxes:
		var cb = checkboxes[supply]
		cb.toggled.connect(
			_on_supply_toggled.bind(squad.name, supply, checkboxes)
		)

	# Apply initial disabled state if one is already ticked
	var any_ticked = false
	var ticked_supply = ""
	for supply in checkboxes:
		if checkboxes[supply].button_pressed:
			any_ticked = true
			ticked_supply = supply
			break
	if any_ticked:
		for supply in checkboxes:
			if supply != ticked_supply:
				checkboxes[supply].disabled = true

	squad_container.add_child(row)
	var sep := HSeparator.new()
	squad_container.add_child(sep)

	return { "squad": squad.name, "checkboxes": checkboxes }


func _sync_allocations() -> void:
	for squad in SquadManager.get_squads_for_ui():
		if not allocations.has(squad.name):
			allocations[squad.name] = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }


func _on_supply_toggled(pressed: bool, squad_name: String, supply: String, checkboxes: Dictionary) -> void:
	if TurnManager.mission_over: return
	if not allocations.has(squad_name):
		allocations[squad_name] = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }

	if pressed:
		# Record this supply
		allocations[squad_name][supply] = SUPPLY_COST

		# Count how many are now ticked for this squad
		var ticked_count = 0
		for s in checkboxes:
			if checkboxes[s].button_pressed:
				ticked_count += 1

		# Once 2 are ticked, lock the remaining unticked one(s)
		if ticked_count >= 2:
			for s in checkboxes:
				if not checkboxes[s].button_pressed:
					checkboxes[s].disabled = true
	else:
		# Unticked — clear this allocation, re-enable everything else
		allocations[squad_name][supply] = 0
		for s in checkboxes:
			checkboxes[s].disabled = TurnManager.mission_over

	if TurnManager.allocations_are_locked:
		TurnManager.allocations_are_locked = false
		lock_btn.text = "Lock Allocations"
		lock_btn.disabled = false

	_refresh_budget()


# -------------------------------------------------------
# Reinforcement panel
# -------------------------------------------------------w

func _reset_allocations() -> void:
	for squad_name in allocations:
		for s in allocations[squad_name]:
			allocations[squad_name][s] = 0

func _on_call_reinforcement_pressed() -> void:
	if TurnManager.mission_over: return
	if GameManager.get_reinforcement_pool() <= 0: return
	if not GameManager.get_pending_reinforcement().is_empty(): return

	var idx = reinforcement_name_btn.selected
	if idx < 0: return
	var chosen_name = reinforcement_name_btn.get_item_text(idx)

	if not GameManager.consume_reinforcement():
		return  # safety guard, shouldn't happen given the check above

	GameManager.queue_reinforcement(chosen_name)
	_refresh_reinforcement_panel()

	# Unlock if locked — player needs to visit Holo-Map before locking
	if TurnManager.allocations_are_locked:
		TurnManager.allocations_are_locked = false
		lock_btn.text = "Lock Allocations"
		lock_btn.disabled = false

	warning_label.text = "Reinforcement queued — visit Holo-Map to place drop zone before locking."
	warning_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))


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
		warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		budget_label.remove_theme_color_override("font_color")
		if warning_label.text == "Over pool limit on one or more supply types!":
			warning_label.text = ""


func _on_lock_pressed() -> void:
	if TurnManager.mission_over: return

	# Block locking if reinforcement queued but not placed
	var pending = GameManager.get_pending_reinforcement()
	if not pending.is_empty() and not pending.get("placed", false):
		warning_label.text = "Cannot lock — place reinforcement drop zone on Holo-Map first."
		warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		return

	var pool = GameManager.get_supply_pool()
	var pending_supply: Dictionary = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	for sn in allocations:
		for s in allocations[sn]:
			if pending_supply.has(s):
				pending_supply[s] += allocations[sn][s]
	for s in pending_supply:
		if pending_supply[s] > pool.get(s, 0):
			warning_label.text = "Cannot lock — %s exceeds mission pool!" % s
			warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
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

	# Show carry-over supplies
	var carry_pool = report.get("supply_pool", {})
	var carry_reinf = report.get("reinforcements", 0)
	var carry_text = ""
	if not carry_pool.is_empty():
		carry_text = "\n\nCarrying forward — Arms: %d  Meds: %d  Fuel: %d  Reinf: %d" % [
			carry_pool.get("Armaments", 0),
			carry_pool.get("Medi-Packs", 0),
			carry_pool.get("Fuel Cells", 0),
			carry_reinf,
		]

	end_title.text = "MISSION COMPLETE" if won else "MISSION FAILED"
	end_title.add_theme_color_override("font_color",
		Color(0.4, 0.9, 0.4) if won else Color(0.9, 0.3, 0.3))
	end_title.add_theme_font_size_override("font_size", 32)

	end_body.text = (
		"Rating: %s  |  Score: %d\n\nTile: %d   Turn bonus: %d   Supply bonus: %d\nSectors held: %d / %d   Turns: %d%s\n\nSee Command Throne for full debrief."
		% [rating, score, t_score, t_bonus, s_bonus, held, req, turns, carry_text]
	)
	end_body.add_theme_font_size_override("font_size", 14)
	end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD

func _on_arm_bombardment_pressed() -> void:
	if TurnManager.mission_over: return
	if GameManager.get_orbital_strikes_pool() <= 0: return
	if not GameManager.get_pending_bombardment().is_empty(): return
	if not GameManager.consume_orbital_strike(): return
	if not GameManager.queue_bombardment():
		return
	_refresh_bombardment_panel()

func _on_close_pressed() -> void:
	visible = false
	if player and player.has_method("on_popup_closed"):
		player.on_popup_closed()

func _refresh_reinforcement_panel() -> void:
	if reinforcement_panel == null:
		return

	var pool = GameManager.get_reinforcement_pool()
	var has_pending = not GameManager.get_pending_reinforcement().is_empty()
	var bombardment_active = not GameManager.get_pending_bombardment().is_empty()

	reinforcement_panel.visible = pool > 0 or has_pending

	if reinforcement_pool_label:
		reinforcement_pool_label.text = "Reinforcement Drops Available: %d" % pool
		reinforcement_pool_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if pool > 0 else Color(0.5, 0.5, 0.5))

	if reinforcement_name_btn:
		reinforcement_name_btn.clear()
		var available = GameManager.get_available_reinforcement_names()
		for n in available:
			reinforcement_name_btn.add_item(n)
		reinforcement_name_btn.disabled = pool <= 0 or has_pending or bombardment_active or TurnManager.mission_over

	if call_reinforcement_btn:
		call_reinforcement_btn.disabled = pool <= 0 or has_pending or bombardment_active or TurnManager.mission_over

	if reinforcement_status_label:
		if has_pending:
			var drop = GameManager.get_pending_reinforcement()
			var placed = drop.get("placed", false)
			var name  = drop.get("squad_name", "")
			var sector = drop.get("sector", "")
			if placed:
				reinforcement_status_label.text = "✓ %s dropping to %s — visit Holo-Map to confirm" % [name, sector]
				reinforcement_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			else:
				reinforcement_status_label.text = "⚠ %s queued — visit Holo-Map to place drop zone" % name
				reinforcement_status_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		elif bombardment_active:
			reinforcement_status_label.text = "— Locked while Orbital Strike is armed —"
			reinforcement_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			reinforcement_status_label.text = ""

func _refresh_bombardment_panel() -> void:
	if bombardment_panel == null:
		return

	var pool = GameManager.get_orbital_strikes_pool()
	var has_pending = not GameManager.get_pending_bombardment().is_empty()
	var reinforcement_active = not GameManager.get_pending_reinforcement().is_empty()

	bombardment_panel.visible = pool > 0 or has_pending

	if bombardment_pool_label:
		bombardment_pool_label.text = "Orbital Strikes Available: %d" % pool
		bombardment_pool_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if pool > 0 else Color(0.5, 0.5, 0.5))

	if arm_bombardment_btn:
		arm_bombardment_btn.disabled = pool <= 0 or has_pending or reinforcement_active or TurnManager.mission_over

	if bombardment_status_label:
		if has_pending:
			var drop = GameManager.get_pending_bombardment()
			var placed = drop.get("placed", false)
			if placed:
				bombardment_status_label.text = "✓ Strike resolved at %s" % drop.get("sector", "")
				bombardment_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			else:
				bombardment_status_label.text = "⚠ Strike armed — visit Holo-Map to select target"
				bombardment_status_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		elif reinforcement_active:
			bombardment_status_label.text = "— Locked while Reinforcement is queued —"
			bombardment_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			bombardment_status_label.text = ""

func _status_color(status: int) -> Color:
	match status:
		SquadManager.Status.ACTIVE:   return Color(0.4, 0.9, 0.4)
		SquadManager.Status.WOUNDED:  return Color(0.9, 0.7, 0.2)
		SquadManager.Status.CRITICAL: return Color(0.9, 0.3, 0.3)
	return Color.WHITE
