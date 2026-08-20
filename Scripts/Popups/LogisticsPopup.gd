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
var _help_attention: bool = false
var _attention_pulse: float = 0.0
var pool_bars: Dictionary = {}
var pool_val_labels: Dictionary = {}


@onready var title_label: Label             = $PanelContainer/VBoxContainer/Title
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
@onready var bombardment_pool_label: Label     = $PanelContainer/VBoxContainer/BombardmentPanel/BombardmentPoolLabel
@onready var arm_bombardment_btn: Button       = $PanelContainer/VBoxContainer/BombardmentPanel/ArmBombardmentBtn
@onready var bombardment_status_label: Label   = $PanelContainer/VBoxContainer/BombardmentPanel/BombardmentStatusLabel

@onready var help_btn: Button = $PanelContainer/VBoxContainer/ButtonRow/HelpBtn
@onready var tutorial_overlay: Control = $TutorialOverlay  # add TutorialOverlay.tscn as a child
@onready var help_nudge: Control = $HelpNudge



func _ready() -> void:
	_style_header("LOGISTICS TERMINAL", "Allocate supplies, call reinforcements, arm orbital strikes")
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.allocations_locked.connect(_on_allocations_locked)
	TurnManager.mission_complete.connect(_on_mission_complete)

	lock_btn.pressed.connect(_on_lock_pressed)
	close_btn.pressed.connect(_on_close_pressed)
	end_close.pressed.connect(_on_close_pressed)
	call_reinforcement_btn.pressed.connect(_on_call_reinforcement_pressed)
	arm_bombardment_btn.pressed.connect(_on_arm_bombardment_pressed)

	end_overlay.visible = false
	warning_label.text = ""

	_style_primary_button(lock_btn)
	_style_primary_button(call_reinforcement_btn)
	_style_primary_button(arm_bombardment_btn)

	# Inside a ScrollContainer, a child only stretches to the full
	# available width if explicitly told to expand — otherwise it
	# shrinks to its content's natural width, which made every squad
	# card render far narrower than the console frame around it.
	squad_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_build_pool_section()
	_build_squad_header_row()

	# LegendPanel is an empty, unused leftover node — with the new global
	# theme giving every PanelContainer a visible rounded card background,
	# it would otherwise show up as an empty box. Hide it.
	var legend_panel := get_node_or_null("PanelContainer/VBoxContainer/LegendPanel")
	if legend_panel:
		legend_panel.visible = false

	_refresh_reinforcement_panel()
	_refresh_bombardment_panel()
	help_btn.pressed.connect(_on_help_pressed)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if not visible:
		return
	if GameManager.has_seen_attention("help_nudge_seen_logistics"):
		return
	GameManager.mark_attention_seen("help_nudge_seen_logistics")
	help_nudge.point_at(help_btn)

func _process(delta: float) -> void:
	if not _help_attention or help_btn == null:
		return
	_attention_pulse += delta * 3.0
	var t = (sin(_attention_pulse) + 1.0) * 0.5
	help_btn.modulate = Color(1.0, lerp(0.6, 1.0, t), lerp(0.0, 0.3, t), 1.0)

func set_help_attention(on: bool) -> void:
	_help_attention = on
	_attention_pulse = 0.0
	if not on and help_btn != null:
		help_btn.modulate = Color.WHITE

func _on_help_pressed() -> void:
	AudioManager.play_button_bottom()
	set_help_attention(false)
	GameManager.mark_attention_seen("logistics_turn")
	GameManager.mark_attention_seen("logistics_reinforcement")
	GameManager.mark_attention_seen("logistics_bombardment")
	var steps: Array[TutorialStep] = [
		_step(
			"POINTS POOL — One bar per supply type, shared across all squads for the whole mission. The bar fills with what you've allocated this turn against what's left in the pool, and turns red if you overspend. Unspent points carry over into the next mission.",
			^"PanelContainer/VBoxContainer/PointsPoolCard"
		),
		_step(
			"SQUAD ROWS — Each squad can receive up to 2 supply types per turn. Armaments guarantee a kill (25% casualty risk). Medi-Packs heal one level. Fuel Cells extend movement and power the tower. Unused supplies are banked for later.",
			^"PanelContainer/VBoxContainer/ScrollContainer/SquadContainer"
		),
		_step(
			"LOCK ALLOCATIONS — Once you are happy with your supply choices, lock them here. You cannot end the turn at the Command Throne until allocations are locked.",
			^"PanelContainer/VBoxContainer/ButtonRow/LockBtn"
		),
	]

	# M2+ — reinforcement panel
	if GameManager.current_mission >= 1 and GameManager.get_reinforcement_pool() > 0 or not GameManager.get_pending_reinforcement().is_empty():
		steps.append(_step(
			"REINFORCEMENT DROP — Call in a replacement squad via drop-pod. Select a squad name, call the drop, then visit the Holo-Map to choose where they land. You have a limited number per mission.",
			^"PanelContainer/VBoxContainer/ReinforcementPanel"
		))

	# M3+ — bombardment panel
	if GameManager.current_mission >= 2 and (GameManager.get_orbital_strikes_pool() > 0 or not GameManager.get_pending_bombardment().is_empty()):
		steps.append(_step(
			"ORBITAL STRIKE — Arm a strike here, then target a hex on the Holo-Map. Destroys all enemies in the target hex and its 6 neighbours. WARNING: kills friendly squads in the blast zone, and striking the priority target destroys the data.",
			^"PanelContainer/VBoxContainer/BombardmentPanel"
		))

	tutorial_overlay.start(steps, self)

func _step(text: String, path: NodePath) -> TutorialStep:
	var s := TutorialStep.new()
	s.text = text
	s.target_path = path
	return s

func _on_turn_started(_turn: int) -> void:
	_reset_allocations()
	# TurnManager.start_mission() fires turn_started with turn 0 exactly once,
	# right when a new mission begins — every other turn_started fires with
	# turn >= 1. Use that to clear the previous mission's end-of-mission
	# overlay, which otherwise stays visible forever and overlaps the fresh
	# mission's UI (this must run even if the popup isn't currently open).
	if _turn == 0:
		end_overlay.visible = false
	if not GameManager.has_seen_attention("logistics_turn"):
		set_help_attention(true)
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

func _get_objective_text(data: Dictionary) -> String:
	var mission_type = data.get("mission_type", "capture")
	var turns_left = TurnManager.max_turns - TurnManager.current_turn
	match mission_type:
		"capture":
			return "Hold %d sectors by end of Turn %d." % [TurnManager.win_condition_hexes, TurnManager.max_turns]
		"eliminate":
			var remaining = EnemyManager.get_total_enemy_count()
			return "Eliminate all enemy forces. %d units remaining." % remaining
		"hold_tower":
			if GameManager.tower_powered:
				return "Tower active — hold it until mission end. %d turns remaining." % turns_left
			else:
				return "Capture and power the comms tower. Power requires 2 turns of Fuel Cells."
		"eliminate_priority":
			if GameManager.priority_target_alive:
				return "Eliminate %s. Optional: power the comms tower." % GameManager.priority_target_name
			else:
				return "Data secured. Break contact — get the carrier at least %d tiles from every remaining enemy before extraction is authorised." % TurnManager.DATA_CARRIER_SAFE_DISTANCE
		"extract":
			var ez = GameManager.extraction_zone
			return "Hold the theatre around the extraction zone (%s) — engage freely. Once the shuttle is inbound (%d turns before mission end), break off and converge to board. Data carrier must extract." % [ez, TurnManager.SHUTTLE_ARRIVAL_WINDOW]
	return data.get("objective", "")

# "Held: X / Y required" only makes sense for capture-type missions
# (M1). Every other mission type shows its own progress/objective
# readout instead — mirrors CommandThronePopup's _update_held_label().
func _update_held_label() -> void:
	if not held_label:
		return
	var mission_type = GameManager.mission_type
	match mission_type:
		"capture":
			var held = EnemyManager.get_held_count()
			var req  = TurnManager.win_condition_hexes
			held_label.text = "Held: %d / %d required" % [held, req]
			held_label.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.4) if held >= req else Color(0.9, 0.6, 0.2))
		"eliminate":
			var remaining = EnemyManager.get_total_enemy_count()
			held_label.text = "Enemies: %d remaining" % remaining
			held_label.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.4) if remaining == 0 else Color(0.9, 0.6, 0.2))
		"hold_tower":
			var powered = GameManager.tower_powered
			held_label.text = "Tower: %s" % ("ACTIVE ⚡" if powered else "UNPOWERED")
			held_label.add_theme_color_override("font_color",
				Color(0.4, 0.9, 0.4) if powered else Color(0.9, 0.6, 0.2))
		"eliminate_priority":
			var alive = GameManager.priority_target_alive
			if alive:
				held_label.text = "Target: AT LARGE ✦"
				held_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			else:
				var carrier_name = GameManager.data_carrier_squad
				var carrier_ok = carrier_name != "" and SquadManager.squads.has(carrier_name) \
					and SquadManager.squads[carrier_name].status != SquadManager.Status.LOST
				if not carrier_ok:
					held_label.text = "Data carrier lost ✗"
					held_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
				else:
					var dist = EnemyManager.get_distance_to_nearest_enemy(SquadManager.squads[carrier_name].sector)
					var safe = dist >= TurnManager.DATA_CARRIER_SAFE_DISTANCE
					held_label.text = "Carrier clear: %d / %d tiles" % [min(dist, TurnManager.DATA_CARRIER_SAFE_DISTANCE), TurnManager.DATA_CARRIER_SAFE_DISTANCE]
					held_label.add_theme_color_override("font_color",
						Color(0.4, 0.9, 0.4) if safe else Color(0.9, 0.6, 0.2))
		"extract":
			var ez = GameManager.extraction_zone
			var at_ez = 0
			for squad in SquadManager.get_squads_for_ui():
				if squad.sector == ez and squad.status != SquadManager.Status.LOST:
					at_ez += 1
			var turns_left = TurnManager.max_turns - TurnManager.current_turn
			if turns_left > TurnManager.SHUTTLE_ARRIVAL_WINDOW:
				held_label.text = "Holding theatre — shuttle in %d turns" % (turns_left - TurnManager.SHUTTLE_ARRIVAL_WINDOW)
				held_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
			else:
				held_label.text = "SHUTTLE INBOUND — At extraction: %d squad(s)" % at_ez
				held_label.add_theme_color_override("font_color",
					Color(0.4, 0.9, 0.4) if at_ez > 0 else Color(0.9, 0.6, 0.2))

func _rebuild_squad_rows() -> void:
	if turn_label:
		turn_label.text = "Turn %d / %d" % [TurnManager.current_turn, TurnManager.max_turns]
	_update_held_label()

	squad_rows.clear()
	for child in squad_container.get_children():
		child.queue_free()

	for squad in SquadManager.get_squads_for_ui():
		if squad.status == SquadManager.Status.LOST: continue
		squad_rows.append(_build_squad_row(squad))


func _build_squad_row(squad: Dictionary) -> Dictionary:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(squad.status))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var name_lbl := Label.new()
	# Tag the data carrier here too — this row was previously identical
	# whether or not a squad was holding the recovered data package, with
	# no lasting way to tell who has it.
	name_lbl.text = squad.name + (" 📦" if squad.get("has_data", false) else "")
	name_lbl.custom_minimum_size.x = 120
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	var info_lbl := Label.new()
	info_lbl.text = "%s\n%s" % [SquadManager.STATUS_NAMES[squad.status], squad.sector]
	info_lbl.custom_minimum_size.x = 130
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.add_theme_color_override("font_color", _status_color(squad.status))
	row.add_child(info_lbl)

		# Force M1 T1 allocations

	# Per-squad checkboxes — cost and supply name are shown once in the
	# column header row above the whole list now (see
	# _build_squad_header_row()), so each cell here is just a big,
	# centred toggle aligned under its header.
	var checkboxes: Dictionary = {}
	for supply in ["Armaments", "Medi-Packs", "Fuel Cells"]:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 110
		col.alignment = BoxContainer.ALIGNMENT_CENTER

		var cb := CheckBox.new()
		cb.text = ""
		cb.add_theme_constant_override("icon_max_width", 32)
		cb.disabled = TurnManager.mission_over
		cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var saved = allocations.get(squad.name, {}).get(supply, 0)
		cb.button_pressed = saved > 0
		_style_checkbox(cb)

		col.add_child(cb)
		row.add_child(col)
		checkboxes[supply] = cb

	var is_forced_turn = (GameManager.current_mission == 0 and SquadManager.current_turn == 0 and not GuideManager.turn_1_done)
	if is_forced_turn:
		_apply_forced_allocation(squad, checkboxes)

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

	squad_container.add_child(card)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	squad_container.add_child(spacer)

	return { "squad": squad.name, "checkboxes": checkboxes }

func _apply_forced_allocation(squad: Dictionary, checkboxes: Dictionary) -> void:
	# Force the squad's stated need supply — and Armaments if Active
	var forced: Array[String] = []
	match squad.need:
		SquadManager.Need.MEDI_PACKS:  forced.append("Medi-Packs")
		SquadManager.Need.FUEL_CELLS:  forced.append("Fuel Cells")
		SquadManager.Need.ARMAMENTS:   forced.append("Armaments")

	# Active squads also get Armaments as second supply if not already
	if squad.status == SquadManager.Status.ACTIVE and not forced.has("Armaments"):
		forced.append("Armaments")

	for supply in checkboxes:
		var cb = checkboxes[supply]
		if forced.has(supply):
			cb.button_pressed = true
			cb.disabled = true
			if not allocations.has(squad.name):
				allocations[squad.name] = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
			allocations[squad.name][supply] = SUPPLY_COST
		else:
			cb.button_pressed = false
			cb.disabled = true  # lock out everything not forced
		_style_checkbox(cb)

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

	for s in checkboxes:
		_style_checkbox(checkboxes[s])

	_refresh_budget()


# -------------------------------------------------------
# Makes ticked supply checkboxes obviously highlighted —
# the default theme checkbox is too subtle for new testers.
# -------------------------------------------------------
func _style_checkbox(cb: CheckBox) -> void:
	if cb.button_pressed:
		cb.add_theme_color_override("font_color", Color(0.15, 0.9, 0.4))
		cb.add_theme_color_override("font_color_hover", Color(0.15, 0.9, 0.4))
		cb.add_theme_color_override("font_color_disabled", Color(0.15, 0.65, 0.35))
		cb.modulate = Color(1.25, 1.25, 1.1)
	else:
		cb.remove_theme_color_override("font_color")
		cb.remove_theme_color_override("font_color_hover")
		cb.remove_theme_color_override("font_color_disabled")
		cb.modulate = Color(1, 1, 1)


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
	# Reinforcement and bombardment are mutually exclusive for the turn —
	# check this BEFORE consuming a reinforcement charge below. Bombardment
	# used to only be re-disabled on its own panel's next refresh, so this
	# button could still be clicked while a strike was pending; that
	# consumed a reinforcement charge that queue_reinforcement() then
	# silently refused to queue, permanently losing the charge.
	if not GameManager.get_pending_bombardment().is_empty(): return

	var idx = reinforcement_name_btn.selected
	if idx < 0: return
	var chosen_name = reinforcement_name_btn.get_item_text(idx)

	if not GameManager.consume_reinforcement():
		return  # safety guard, shouldn't happen given the check above

	if not GameManager.queue_reinforcement(chosen_name):
		GameManager.reinforcement_pool += 1  # roll back — shouldn't happen given the check above
		return

	AudioManager.play_button_other()
	_refresh_reinforcement_panel()
	_refresh_bombardment_panel()  # keep the other panel's button state in sync too

	# Unlock if locked — player needs to visit Holo-Map before locking
	if TurnManager.allocations_are_locked:
		TurnManager.allocations_are_locked = false
		lock_btn.text = "Lock Allocations"
		lock_btn.disabled = false

	warning_label.text = "Reinforcement queued — visit Holo-Map to place drop zone before locking."
	warning_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))


func _refresh_pool() -> void:
	if pool_label == null: return
	# Pool numbers now live on the Points Pool bars built in
	# _build_pool_section() (updated from _refresh_budget() below, since
	# that function already computes both pool and pending together).
	# The old text label is kept updated but hidden, so nothing else that
	# reads pool_label.text elsewhere silently breaks.
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
		_update_pool_bar(s, pen, p)

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
	AudioManager.play_button_bottom()
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

	# Data package status — only relevant on missions with a priority
	# target/data carrier (eliminate_priority, extract).
	var data_text = ""
	match report.get("data_status", ""):
		"secured":
			data_text = "\n\nData package: SECURED — carried by %s." % report.get("data_carrier", "")
		"destroyed":
			data_text = "\n\nData package: DESTROYED — did not survive."
		"at_large":
			data_text = "\n\nData package: NOT RECOVERED — priority target still at large."
		"unaccounted":
			data_text = "\n\nData package: STATUS UNKNOWN — recovery not confirmed."

	end_title.text = "MISSION COMPLETE" if won else "MISSION FAILED"
	end_title.add_theme_color_override("font_color",
		Color(0.4, 0.9, 0.4) if won else Color(0.9, 0.3, 0.3))
	end_title.add_theme_font_size_override("font_size", 32)

	end_body.text = (
		"Rating: %s  |  Score: %d\n\nTile: %d   Turn bonus: %d   Supply bonus: %d\nSectors held: %d / %d   Turns: %d%s%s\n\nSee Command Throne for full debrief."
		% [rating, score, t_score, t_bonus, s_bonus, held, req, turns, data_text, carry_text]
	)
	end_body.add_theme_font_size_override("font_size", 14)
	end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD

func _on_arm_bombardment_pressed() -> void:
	if TurnManager.mission_over: return
	if GameManager.get_orbital_strikes_pool() <= 0: return
	if not GameManager.get_pending_bombardment().is_empty(): return
	# Same mutual-exclusion check as the reinforcement side, and for the
	# same reason — see the comment in _on_call_reinforcement_pressed().
	if not GameManager.get_pending_reinforcement().is_empty(): return
	if not GameManager.consume_orbital_strike(): return
	if not GameManager.queue_bombardment():
		GameManager.orbital_strikes_pool += 1  # roll back — shouldn't happen given the check above
		return
	AudioManager.play_button_other()
	_refresh_bombardment_panel()
	_refresh_reinforcement_panel()  # keep the other panel's button state in sync too

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
	
	if pool > 0 and not GameManager.has_seen_attention("logistics_reinforcement"):
		set_help_attention(true)

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

	if pool > 0 and not GameManager.has_seen_attention("logistics_bombardment"):
		set_help_attention(true)

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


# -------------------------------------------------------
# Console header — big bold title + small grey subtitle,
# matching the Field Manual mockup layouts. The scene has
# no Subtitle node, so it's built here at runtime and
# inserted right under Title.
# -------------------------------------------------------
func _style_header(title_text: String, subtitle_text: String) -> void:
	if title_label:
		title_label.text = title_text
		title_label.add_theme_font_size_override("font_size", 24)
		title_label.add_theme_color_override("font_color", Color(0.91, 0.91, 0.91))

		var subtitle_label := Label.new()
		subtitle_label.text = subtitle_text
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		subtitle_label.add_theme_font_size_override("font_size", 13)
		subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.73))
		var parent := title_label.get_parent()
		parent.add_child(subtitle_label)
		parent.move_child(subtitle_label, title_label.get_index() + 1)


# -------------------------------------------------------
# "Points Pool" card — a rounded panel with one labelled
# progress bar per supply type, replacing the old plain
# text pool/budget lines with the visual bar shown in the
# Field Manual's Logistics Terminal mockup. Built once and
# kept in sync from _refresh_budget() via _update_pool_bar().
# -------------------------------------------------------
func _build_pool_section() -> void:
	if pool_label == null:
		return

	var card := PanelContainer.new()
	card.name = "PointsPoolCard"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.106, 0.122, 0.153, 1.0)
	style.border_color = Color(0.235, 0.259, 0.306, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	var header_lbl := Label.new()
	header_lbl.text = "POINTS POOL"
	header_lbl.add_theme_font_size_override("font_size", 12)
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.851, 0.2))
	vb.add_child(header_lbl)

	for supply in ["Armaments", "Medi-Packs", "Fuel Cells"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = supply
		name_lbl.custom_minimum_size.x = 90
		name_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(name_lbl)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size.x = 64
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)

		vb.add_child(row)
		pool_bars[supply] = bar
		pool_val_labels[supply] = val_lbl

	var parent := pool_label.get_parent()
	parent.add_child(card)
	parent.move_child(card, pool_label.get_index())

	# The old plain-text pool/budget lines are superseded by the bars
	# above — hidden rather than removed, so their existing refresh
	# logic elsewhere keeps running harmlessly.
	pool_label.visible = false
	budget_label.visible = false


func _update_pool_bar(supply: String, pending: int, pool: int) -> void:
	if not pool_bars.has(supply):
		return
	var bar: ProgressBar = pool_bars[supply]
	bar.max_value = max(pool, 1)
	bar.value = pending

	var over := pending > pool
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.2, 0.2) if over else Color(1.0, 0.851, 0.2)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)

	var val_lbl: Label = pool_val_labels[supply]
	val_lbl.text = "%d / %d" % [pending, pool]
	val_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3) if over else Color(0.85, 0.85, 0.85))


# -------------------------------------------------------
# Column header row above the squad list — "SQUAD",
# "STATUS", and one header per supply type (with its point
# cost), so each squad row below can drop its per-checkbox
# label and just show a big centred toggle, matching the
# Field Manual mockup's table layout.
# -------------------------------------------------------
func _build_squad_header_row() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)

	var name_h := Label.new()
	name_h.text = "SQUAD"
	name_h.custom_minimum_size.x = 120
	name_h.add_theme_font_size_override("font_size", 12)
	name_h.add_theme_color_override("font_color", Color(1.0, 0.851, 0.2))
	header.add_child(name_h)

	var status_h := Label.new()
	status_h.text = "STATUS"
	status_h.custom_minimum_size.x = 130
	status_h.add_theme_font_size_override("font_size", 12)
	status_h.add_theme_color_override("font_color", Color(1.0, 0.851, 0.2))
	header.add_child(status_h)

	for supply in ["Armaments", "Medi-Packs", "Fuel Cells"]:
		var col_h := Label.new()
		col_h.text = "%s (%d pts)" % [supply, SUPPLY_COST]
		col_h.custom_minimum_size.x = 110
		col_h.add_theme_font_size_override("font_size", 12)
		col_h.add_theme_color_override("font_color", Color(1.0, 0.851, 0.2))
		col_h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col_h.autowrap_mode = TextServer.AUTOWRAP_WORD
		header.add_child(col_h)

	var scroll := squad_container.get_parent()
	var parent := scroll.get_parent()
	parent.add_child(header)
	parent.move_child(header, scroll.get_index())


# -------------------------------------------------------
# Rounded card background for each squad allocation row —
# matches the card style used at the Intel Console,
# Vox-Caster, Command Throne, and the Field Manual mockups.
# -------------------------------------------------------
func _card_style(status: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_content_margin_all(10)
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left   = 4
	style.border_width_top    = 1
	style.border_width_right  = 1
	style.border_width_bottom = 1
	match status:
		SquadManager.Status.ACTIVE:
			style.bg_color     = Color(0.13, 0.20, 0.13)
			style.border_color = Color(0.3, 0.65, 0.3)
		SquadManager.Status.WOUNDED:
			style.bg_color     = Color(0.20, 0.17, 0.08)
			style.border_color = Color(0.85, 0.6, 0.15)
		SquadManager.Status.CRITICAL:
			style.bg_color     = Color(0.22, 0.08, 0.08)
			style.border_color = Color(0.9, 0.2, 0.2)
		_:
			style.bg_color     = Color(0.13, 0.13, 0.18)
			style.border_color = Color(0.4, 0.4, 0.55)
	return style


# -------------------------------------------------------
# Amber-filled "primary" CTA button style — mirrors
# CommandThronePopup._style_primary_button() for the
# reinforcement/orbital-strike action buttons.
# -------------------------------------------------------
func _style_primary_button(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.275, 0.216, 0.039, 1.0)
	normal.border_color = Color(1.0, 0.851, 0.2, 1.0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate()
	hover.bg_color = Color(0.35, 0.275, 0.05, 1.0)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.22, 0.17, 0.03, 1.0)

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color(0.055, 0.063, 0.078, 1.0)
	disabled.border_color = Color(0.157, 0.173, 0.204, 1.0)
	disabled.set_border_width_all(2)
	disabled.set_corner_radius_all(10)
	disabled.content_margin_left = 16
	disabled.content_margin_right = 16
	disabled.content_margin_top = 8
	disabled.content_margin_bottom = 8

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(1.0, 0.851, 0.2))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))
