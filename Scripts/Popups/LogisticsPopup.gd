extends Control
# =============================================================
# LogisticsPopup.gd — fullscreen popup
# =============================================================

var player: Node = null

const SUPPLY_OPTIONS: Array = ["None", "Armaments", "Medi-Packs", "Fuel Cells"]
const SUPPLY_COST: Dictionary = { "None": 0, "Armaments": 2, "Medi-Packs": 2, "Fuel Cells": 2 }

var allocations: Dictionary = {}
var squad_rows: Array = []
var budget_label:  Label
var warning_label: Label
var lock_btn: Button
var pool_label: Label


func _ready() -> void:
	SquadManager.turn_resolved.connect(_on_turn_resolved)
	TurnManager.turn_started.connect(_on_turn_started)
	TurnManager.allocations_locked.connect(_on_allocations_locked)
	TurnManager.mission_complete.connect(_on_mission_complete)
	_build_ui()


func _on_turn_started(_turn: int) -> void:
	if visible: refresh()


func _on_turn_resolved() -> void:
	if visible: refresh()


func _on_allocations_locked() -> void:
	if lock_btn:
		lock_btn.text = "✓ Locked"
		lock_btn.disabled = true


func _on_mission_complete(report: Dictionary) -> void:
	_show_mission_end(report)


func refresh() -> void:
	if SquadManager.squads.is_empty(): return
	_sync_allocations()
	_rebuild_squad_rows()
	_refresh_budget()
	_refresh_pool()
	if lock_btn and not TurnManager.mission_over:
		lock_btn.text = "Lock Allocations"
		lock_btn.disabled = false


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0, 0, 0, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.name = "PanelContainer"
	panel.custom_minimum_size = Vector2(680, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Title
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "LOGISTICS TERMINAL"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	# Turn / held counter
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 24)
	vbox.add_child(status_row)

	var turn_lbl := Label.new()
	turn_lbl.name = "TurnLabel"
	turn_lbl.add_theme_font_size_override("font_size", 13)
	turn_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 0.9))
	status_row.add_child(turn_lbl)

	var held_lbl := Label.new()
	held_lbl.name = "HeldLabel"
	held_lbl.add_theme_font_size_override("font_size", 13)
	status_row.add_child(held_lbl)

	# Supply legend
	var legend_panel := PanelContainer.new()
	var ls := StyleBoxFlat.new()
	ls.bg_color = Color(0.06, 0.10, 0.16)
	ls.set_content_margin_all(8)
	legend_panel.add_theme_stylebox_override("panel", ls)
	vbox.add_child(legend_panel)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	legend_panel.add_child(lv)
	for line in [
		["Fuel Cells  →", "Squad moves to adjacent tile and captures it",    Color(0.4, 0.7, 1.0)],
		["Armaments  →", "Squad fights enemies at current or adjacent tile", Color(1.0, 0.6, 0.3)],
		["Medi-Packs →", "Squad heals (Critical→Wounded, Wounded→Active)",  Color(0.4, 0.9, 0.5)],
	]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var k := Label.new(); k.text = line[0]; k.custom_minimum_size.x = 110
		k.add_theme_font_size_override("font_size", 12)
		k.add_theme_color_override("font_color", line[2]); r.add_child(k)
		var v := Label.new(); v.text = line[1]
		v.add_theme_font_size_override("font_size", 12)
		v.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8)); r.add_child(v)
		lv.add_child(r)

	var instr := Label.new()
	instr.text = "Each supply costs 2 pts. Supplies are drawn from the mission pool — manage carefully."
	instr.add_theme_font_size_override("font_size", 11)
	instr.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	instr.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(instr)

	# Mission supply pool display
	pool_label = Label.new()
	pool_label.name = "PoolLabel"
	pool_label.add_theme_font_size_override("font_size", 13)
	pool_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(pool_label)

	budget_label = Label.new()
	budget_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(budget_label)

	warning_label = Label.new()
	warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	warning_label.text = ""
	vbox.add_child(warning_label)

	vbox.add_child(HSeparator.new())

	# Column headers
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	for pair in [["Squad", 120], ["Status / Sector", 140], ["Armaments", 120], ["Medi-Packs", 120], ["Fuel Cells", 120]]:
		var lbl := Label.new(); lbl.text = pair[0]
		lbl.custom_minimum_size.x = pair[1]
		lbl.add_theme_font_size_override("font_size", 12)
		header.add_child(lbl)
	vbox.add_child(header)

	vbox.add_child(HSeparator.new())

	var squad_container := VBoxContainer.new()
	squad_container.name = "SquadContainer"
	squad_container.add_theme_constant_override("separation", 10)
	vbox.add_child(squad_container)

	vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	lock_btn = Button.new()
	lock_btn.text = "Lock Allocations"
	lock_btn.pressed.connect(_on_lock_pressed)
	btn_row.add_child(lock_btn)

	var close_btn := Button.new()
	close_btn.text = "Close  [Esc]"
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)

	# Mission end overlay — hidden until mission resolves
	var end_overlay := ColorRect.new()
	end_overlay.name = "EndOverlay"
	end_overlay.color = Color(0, 0, 0, 0.82)
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_overlay.visible = false
	add_child(end_overlay)

	var end_vbox := VBoxContainer.new()
	end_vbox.name = "EndVBox"
	end_vbox.set_anchors_preset(Control.PRESET_CENTER)
	end_vbox.add_theme_constant_override("separation", 16)
	end_overlay.add_child(end_vbox)

	var end_title := Label.new()
	end_title.name = "EndTitle"
	end_title.add_theme_font_size_override("font_size", 32)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_vbox.add_child(end_title)

	var end_body := Label.new()
	end_body.name = "EndBody"
	end_body.add_theme_font_size_override("font_size", 15)
	end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	end_body.custom_minimum_size.x = 420
	end_vbox.add_child(end_body)

	var end_close := Button.new()
	end_close.text = "Close"
	end_close.pressed.connect(_on_close_pressed)
	end_vbox.add_child(end_close)


func _rebuild_squad_rows() -> void:
	var turn_lbl = get_node_or_null("PanelContainer/VBoxContainer/TurnLabel")
	var held_lbl = get_node_or_null("PanelContainer/VBoxContainer/HeldLabel")
	if turn_lbl: turn_lbl.text = "Turn %d / %d" % [TurnManager.current_turn, TurnManager.max_turns]
	if held_lbl:
		var held = EnemyManager.get_held_count()
		var req  = TurnManager.win_condition_hexes
		held_lbl.text = "Held: %d / %d required" % [held, req]
		held_lbl.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if held >= req else Color(0.9, 0.6, 0.2))

	squad_rows.clear()
	var container = get_node_or_null("PanelContainer/VBoxContainer/SquadContainer")
	if container == null: return
	for child in container.get_children(): child.queue_free()

	for squad in SquadManager.get_squads_for_ui():
		if squad.status == SquadManager.Status.LOST: continue
		squad_rows.append(_build_squad_row(squad, container))


func _build_squad_row(squad: Dictionary, container: Node) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_lbl := Label.new()
	name_lbl.text = squad.name
	name_lbl.custom_minimum_size.x = 120
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	var info_lbl := Label.new()
	info_lbl.text = "%s\n%s" % [SquadManager.STATUS_NAMES[squad.status], squad.sector]
	info_lbl.custom_minimum_size.x = 140
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.add_theme_color_override("font_color", _status_color(squad.status))
	row.add_child(info_lbl)

	var dropdowns: Dictionary = {}
	for supply in ["Armaments", "Medi-Packs", "Fuel Cells"]:
		var opt := OptionButton.new()
		opt.custom_minimum_size.x = 120
		for option in SUPPLY_OPTIONS: opt.add_item(option)
		var saved = allocations.get(squad.name, {}).get(supply, 0)
		opt.selected = 0
		for i in SUPPLY_OPTIONS.size():
			if SUPPLY_COST[SUPPLY_OPTIONS[i]] == saved and saved > 0:
				opt.selected = i; break
		opt.item_selected.connect(_on_supply_changed.bind(squad.name, supply, opt))

		# Disable dropdown if mission is over
		opt.disabled = TurnManager.mission_over
		row.add_child(opt)
		dropdowns[supply] = opt

	container.add_child(row)
	return { "squad": squad.name, "dropdowns": dropdowns }


func _sync_allocations() -> void:
	for squad in SquadManager.get_squads_for_ui():
		if not allocations.has(squad.name):
			allocations[squad.name] = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }


func _on_supply_changed(_index: int, squad_name: String, supply: String, opt: OptionButton) -> void:
	if TurnManager.mission_over:
		return
	if not allocations.has(squad_name):
		allocations[squad_name] = { "Armaments": 0, "Medi-Packs": 0, "Fuel Cells": 0 }
	allocations[squad_name][supply] = SUPPLY_COST[SUPPLY_OPTIONS[opt.selected]]
	if TurnManager.allocations_are_locked:
		TurnManager.allocations_are_locked = false
		if lock_btn:
			lock_btn.text = "Lock Allocations"
			lock_btn.disabled = false
	_refresh_budget()


func _refresh_pool() -> void:
	if pool_label == null:
		return
	var pool = GameManager.get_supply_pool()
	pool_label.text = "Mission Pool — Armaments: %d  |  Medi-Packs: %d  |  Fuel Cells: %d" % [
		pool.get("Armaments", 0),
		pool.get("Medi-Packs", 0),
		pool.get("Fuel Cells", 0),
	]
	# Warn if any supply type is running low
	var low = []
	for s in pool:
		if pool[s] <= 2 and pool[s] > 0:
			low.append(s)
		elif pool[s] == 0:
			low.append(s + " DEPLETED")
	if low.size() > 0:
		pool_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	else:
		pool_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))


func _refresh_budget() -> void:
	# Budget now shows this turn's pending spend vs what remains in the pool
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
	if TurnManager.mission_over:
		return
	# Check pending spend doesn't exceed pool for any type
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
	var overlay = get_node_or_null("EndOverlay")
	if overlay == null:
		return

	# Disable lock button
	if lock_btn:
		lock_btn.disabled = true
		lock_btn.text = "—"

	overlay.visible = true

	var end_title = overlay.get_node_or_null("EndVBox/EndTitle")
	var end_body  = overlay.get_node_or_null("EndVBox/EndBody")

	var won = report.get("won", false)

	if end_title:
		end_title.text = "MISSION COMPLETE" if won else "MISSION FAILED"
		end_title.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if won else Color(0.9, 0.3, 0.3))

	if end_body:
		var held    = report.get("held_hexes", 0)
		var req     = report.get("required_hexes", 0)
		var rating  = report.get("rating", "—")
		var score   = report.get("score", 0)
		var t_score = report.get("tile_score", 0)
		var t_bonus = report.get("turn_bonus", 0)
		var s_bonus = report.get("supply_bonus", 0)
		var turns   = report.get("turns", 0)
		end_body.text = (
			"Rating: %s  |  Score: %d\n\nTile score: %d   Turn bonus: %d   Supply bonus: %d\nSectors held: %d / %d   Turns: %d\n\nConsult the Command Throne for full debrief."
			% [rating, score, t_score, t_bonus, s_bonus, held, req, turns]
		)


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
