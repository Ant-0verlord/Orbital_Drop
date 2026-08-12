extends Node
# =============================================================
# GuideManager.gd — AutoLoad singleton
# Tracks tutorial step progress and drives guide visuals
# =============================================================

signal step_changed(step: String)
signal guide_dismissed

enum Step {
	NONE,
	BRIEFING,
	VISIT_INTEL,
	VISIT_VOX,
	VISIT_LOGISTICS,
	LOCK_ALLOCS,
	VISIT_HOLOMAP,
	VISIT_THRONE,
	COMPLETE,
}

var current_step: Step = Step.NONE
var guide_active: bool = false
var turn_1_done:  bool = false
var dismissed:    bool = false
var popup_open:   bool = false
# Once the guide has been ended — manually via the dismiss button, or
# automatically after turn 1 — it's done for the whole campaign. Without
# this, start_guide() (called at the start of every mission) would just
# reset everything and bring the tutorial prompts back for mission 2 on.
var guide_completed: bool = false

func _ready() -> void:
	TurnManager.turn_ended.connect(on_turn_ended)

func set_popup_open(open: bool) -> void:
	popup_open = open

# Console world positions (Y offset added for arrow height)
const CONSOLE_POSITIONS = {
	"intel":      Vector3( 0.284, 2.2,  3.564),
	"vox":        Vector3(-0.03,  2.0, -3.31 ),
	"logistics":  Vector3( 4.351, 2.3,  0.473),
	"holomap":    Vector3( 0.018, 2.5,  0.0  ),
	"throne":     Vector3(-6.96,  2.6, -0.086),
}

func start_guide() -> void:
	if guide_completed:
		return
	guide_active = true
	dismissed    = false
	turn_1_done  = false
	_set_step(Step.VISIT_INTEL)

func dismiss() -> void:
	dismissed       = true
	guide_active    = false
	guide_completed = true
	_set_step(Step.NONE)
	emit_signal("guide_dismissed")

func on_console_opened(console: String) -> void:
	if not guide_active:
		return
	match current_step:
		Step.VISIT_INTEL:
			if console == "intel":
				_set_step(Step.VISIT_VOX)
		Step.VISIT_VOX:
			if console == "vox":
				_set_step(Step.VISIT_LOGISTICS)
		Step.VISIT_LOGISTICS:
			if console == "logistics":
				_set_step(Step.LOCK_ALLOCS)
		Step.VISIT_HOLOMAP:
			if console == "holomap":
				if GameManager.get_pending_reinforcement().is_empty() and GameManager.get_pending_bombardment().is_empty():
					_set_step(Step.VISIT_THRONE)
		Step.VISIT_THRONE:
			if console == "throne":
				pass  # throne handles its own completion

func on_allocs_locked() -> void:
	if not guide_active:
		return
	if current_step == Step.LOCK_ALLOCS:
		var has_pending = not GameManager.get_pending_reinforcement().is_empty() or not GameManager.get_pending_bombardment().is_empty()
		_set_step(Step.VISIT_HOLOMAP if has_pending else Step.VISIT_THRONE)

func on_turn_ended() -> void:
	if not guide_active:
		return
	if not turn_1_done:
		turn_1_done = true
		# After turn 1 — guide fully retires: hide prompt bar and arrow,
		# and mark it done for good so it doesn't come back next mission.
		_set_step(Step.NONE)
		guide_active    = false
		guide_completed = true
		emit_signal("guide_dismissed")

func get_target_console() -> String:
	match current_step:
		Step.VISIT_INTEL:     return "intel"
		Step.VISIT_VOX:       return "vox"
		Step.VISIT_LOGISTICS: return "logistics"
		Step.LOCK_ALLOCS:     return "logistics"
		Step.VISIT_HOLOMAP:   return "holomap"
		Step.VISIT_THRONE:    return "throne"
	return ""

func get_prompt_text() -> String:
	match current_step:
		Step.VISIT_INTEL:
			return "STEP 1 — Visit the Intel Desk: review squad action reports"
		Step.VISIT_VOX:
			return "STEP 2 — Visit the Vox-Caster Array: check squad supply requests"
		Step.VISIT_LOGISTICS:
			return "STEP 3 — Visit the Logistics Terminal: allocate supplies to squads"
		Step.LOCK_ALLOCS:
			return "STEP 4 — Lock your allocations at the Logistics Terminal before proceeding"
		Step.VISIT_HOLOMAP:
			return "STEP 5 — Visit the Holo-Map: place your pending drop or strike"
		Step.VISIT_THRONE:
			return "STEP 6 — Visit the Command Throne: engage the Turn Seal to end the turn"
	return ""

func _set_step(step: Step) -> void:
	current_step = step
	emit_signal("step_changed", get_target_console())
