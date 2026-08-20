extends Control
# =============================================================
# InstructionsPopup.gd
# Attach to: Control (root of Scenes/InstructionsPopup.tscn)
#
# A self-contained, reusable "field manual" popup — instanced once in
# the main menu (Main.tscn) and once in the in-game Tab pause menu
# (Player.tscn). Each host wires its own Instructions button to call
# open() and (optionally) listens for the `closed` signal.
#
# This is deliberately different from the game's other two help
# systems, not a replacement for either:
#   - The per-console Help button / TutorialOverlay arrows are
#     spur-of-the-moment: short, contextual call-outs for whatever
#     popup you're standing in right now.
#   - The Guide bottom-bar / HelpNudge arrows are ambient nudges —
#     "go here next" — not explanations.
#   - This is the full written rulebook: everything explained in one
#     place, readable any time before a mission even starts or paused
#     mid-mission, like a board game's instruction booklet.
# =============================================================

signal closed

@onready var body: RichTextLabel = $PanelContainer/VBoxContainer/Body
@onready var back_btn: Button    = $PanelContainer/VBoxContainer/ButtonRow/BackBtn

const TEXT := """A campaign of 5 missions. Each one drops your squads into a hex-grid theatre where you manage supplies, direct combat from a safe command centre, and complete that mission's objective before the turn limit runs out or every squad you have is lost.

[font_size=20][b][color=#ffd933]1. THE TURN CYCLE[/color][/b][/font_size]
You don't control squads directly — you run a command centre with five stations, and each turn plays out in this order:
[b]1. Intel Console[/b] — read squad status reports and event notices (informational only).
[b]2. Vox-Caster Array[/b] — check what each squad is actually requesting this turn.
[b]3. Logistics Terminal[/b] — allocate supplies, and on later missions call in a reinforcement or arm an orbital strike.
[b]4. Holo-Map[/b] — if you armed a reinforcement drop or orbital strike, place it on the map. This step is skipped if you didn't arm anything.
[b]5. Command Throne[/b] — review the turn summary, then press [b]Engage Turn Seal[/b] to end the turn.
Allocations must be [b]Locked[/b] at the Logistics Terminal before Command Throne will let you end the turn. Ending a turn is irreversible — squads act, the enemy moves, and the result is final before the next turn begins.

[center][img=760]res://UI/Manual/turn_cycle.png[/img][/center]

[font_size=20][b][color=#ffd933]2. THE FIVE CONSOLES[/color][/b][/font_size]
[b]Intel Console[/b] — one status card per squad: name, condition, current sector, and a report of what happened to them last turn. Also surfaces event cards — enemy reinforcement warnings, landings, orbital strike results, and data package updates. A Critical squad's report always comes through clearly here, no matter how bad radio interference is elsewhere.

[center][img=760]res://UI/Manual/console_intel.png[/img][/center]

[b]Vox-Caster Array[/b] — the only place that shows what each squad is actually requesting (Armaments, Medi-Packs, or Fuel Cells). Signal quality depends on mission interference and degrades in stages: clear, then patchy (parts garbled), then a faint echo (the message may be [i]unreliable[/i] — possibly wrong), then dead silence. A Critical squad's request always comes through clean regardless of interference. Powering the Comms Tower (missions with one) improves reception for squads nearby — see Section 8.

[center][img=760]res://UI/Manual/console_voxcaster.png[/img][/center]

[b]Logistics Terminal[/b] — where you actually plan the turn. Tick up to 2 supply types per squad per turn from a shared mission-wide points pool (each tick costs [b]2 points[/b] — see Section 4). On later missions this is also where you spend a reinforcement charge to call in a new squad, or an orbital strike charge to arm a bombardment. You cannot Lock allocations while over budget on any supply, or while something is armed but not yet placed on the Holo-Map.

[center][img=760]res://UI/Manual/console_logistics.png[/img][/center]

[b]Command Throne[/b] — the mission briefing and turn-ending station. Shows your objective, turn counter, live progress toward it, squad roster, and last turn's debrief. [b]Engage Turn Seal[/b] here ends the turn — but only once allocations are Locked at Logistics. At mission end this is also where the score report and rating appear.

[center][img=760]res://UI/Manual/console_throne.png[/img][/center]

[b]Holo-Map[/b] — the full hex-grid view of the battlefield: who holds what, where every squad and enemy unit currently is. Its second job is placement: whenever a reinforcement or orbital strike is armed, opening the Holo-Map forces placement mode — click a target hex, confirm, and only then can you close it (or cancel, which refunds the charge). See Section 9 for the hex legend.

[i](The console screens above are illustrative layouts built from the actual button and label text in the game's files, not live screenshots.)[/i]

[font_size=20][b][color=#ffd933]3. SUPPLIES[/color][/b][/font_size]
Three supply types, each answering a different need a squad might radio in:
[b]Armaments[/b] — lets the squad fight this turn. An armed fight always kills the enemy on that tile, but risks a casualty to your own squad in the process (see Section 5).
[b]Medi-Packs[/b] — heals the squad one step: Critical → Wounded, or Wounded → Active. Has no effect on an already-Active squad.
[b]Fuel Cells[/b] — doubles movement to 2 hexes this turn, and is what a squad needs to be standing on and holding to power a Comms Tower.
Each tick at Logistics costs [b]2 points[/b] from one shared pool for the whole mission (not per squad) — unspent points carry over into the next mission. A squad can receive at most 2 supply types in a single turn.
If a squad is given a supply it doesn't end up using that turn (Armaments with no fight, Fuel Cells with no move), it's [b]banked[/b] instead of wasted — up to 3 items per squad — and automatically spent on a future turn it actually needs one, so a single missed or garbled request isn't fatal. A squad that goes [b]2 turns in a row[/b] with no effective supply (fresh or banked) automatically takes a casualty.

[font_size=20][b][color=#ffd933]4. SQUAD STATUS[/color][/b][/font_size]
Every squad sits on a four-step ladder: [b]Active → Wounded → Critical → Lost[/b].
It worsens one step at a time from: losing an unarmed fight, an unlucky armed-combat casualty roll, going 2 turns unsupplied, getting caught in an orbital strike's blast radius, or being overrun with nowhere left to retreat.
It improves one step at a time — Critical → Wounded → Active — from Medi-Packs, fresh or banked. You can't skip a step either direction.
[b]Lost is permanent[/b] for the rest of the campaign — that squad does not return next mission. If a Lost squad was carrying the recovered data package, the package is destroyed with them.

[center][img=760]res://UI/Manual/status_ladder.png[/img][/center]

[font_size=20][b][color=#ffd933]5. COMBAT[/color][/b][/font_size]
[b]Armed[/b] (squad has effective Armaments this turn): the enemy on that tile is always killed and the tile captured — but there's a [b]25% chance[/b] your own squad still takes a casualty in the exchange.
[b]Unarmed[/b]: a 60/40 roll. On a win, the enemy is pushed back and put on cooldown, and you hold the tile. On a loss, your squad takes a casualty and, if it was attacking, falls back to a nearby tile.
[b]Overrun[/b]: if an enemy ends its turn on your squad's own tile and that squad has no arms, it tries to flee to a clear adjacent tile rather than just standing there — only a squad that's genuinely boxed in with nowhere to run takes a casualty.
Movement is 1 hex per turn normally, 2 with effective Fuel Cells. Without fuel there's a flat [b]10% chance[/b] per turn a squad is bogged down and can't move at all.

[center][img=760]res://UI/Manual/combat_odds.png[/img][/center]

[font_size=20][b][color=#ffd933]6. REINFORCEMENTS[/color][/b][/font_size]
From mission 2 onward you have a limited pool of reinforcement charges. Spend one at Logistics, pick a squad name, then place them on the Holo-Map. Dropping directly onto an enemy-held hex is a [b]hot drop[/b] — that enemy is eliminated on landing as a surprise bonus, and if it happens to be that mission's priority target, it counts as killed and the data package transfers straight to the squad that dropped in.

[font_size=20][b][color=#ffd933]7. ORBITAL STRIKES[/color][/b][/font_size]
From mission 3 onward you have a limited pool of orbital strike charges. Arm one at Logistics, target a hex on the Holo-Map — the strike hits that hex [b]and its 6 neighbours[/b], killing every enemy unit caught in the blast. Any of your own squads in that same radius take a casualty too, so check the map before you fire. If the strike kills a priority target, the data they were carrying is destroyed rather than recovered.
[b]Reinforcements and orbital strikes are mutually exclusive[/b] — arming one locks out the other until it's placed/fired or cancelled.

[font_size=20][b][color=#ffd933]8. THE COMMS TOWER[/color][/b][/font_size]
On missions where one is present, a squad standing on the tower's sector with effective Fuel Cells for [b]2 consecutive turns[/b] powers it. Powering it reduces Vox-Caster interference for any squad within 3 hexes — a real reason to keep holding it even after its own objective is met. If fuel is interrupted mid-charge, progress resets to zero. If the enemy retakes the tower's tile at any point, power is lost immediately and has to be fully re-earned.

[font_size=20][b][color=#ffd933]9. THE HOLO-MAP[/color][/b][/font_size]
[center][img=600]res://UI/Manual/hex_legend.png[/img][/center]
A [b]pulsing / flashing red[/b] hex means there's an actual enemy unit standing there right now — not just enemy-controlled territory. A solid, non-flashing red hex is enemy ground that's currently empty, so treat flashing red as "contact here this instant," worth reacting to before your next turn. Under heavy interference an occupied hex can also flicker to static for a moment — that's the same signal-quality problem from the Vox-Caster (Section 2) affecting the map too, not a different state.
Special markers you may see: a Comms Tower icon (shows powered or unpowered), a priority target marker, and an extraction zone marker on the relevant missions.
Whenever a reinforcement or strike is armed, the Holo-Map forces placement mode until you confirm a hex or cancel (cancelling refunds the charge).

[font_size=20][b][color=#ffd933]10. MISSION TYPES & WIN CONDITIONS[/color][/b][/font_size]
[b]Capture[/b] — hold the required number of sectors by the turn limit.
[b]Eliminate[/b] — destroy every enemy unit on the map. Ends the instant the last one falls, no need to wait for the turn limit.
[b]Hold Tower[/b] — power the Comms Tower and still be holding it when the turn limit is reached. Losing the tower at any point resets your progress.
[b]Eliminate Priority[/b] — kill the named priority target, [i]then[/i] get the squad carrying the recovered data package a safe distance from every remaining living enemy before extraction is authorised. Losing that carrier squad after the kill fails the mission outright — the intel doesn't survive with them.
[b]Extract[/b] — fight freely until the extraction shuttle's arrival window opens, then get squads (especially your data carrier) to the extraction zone and aboard before time runs out.
[b]Any mission[/b] fails immediately if every squad you have reaches Lost status at the same time.

[font_size=20][b][color=#ffd933]11. SCORING[/color][/b][/font_size]
Missions are scored on tiles held, a turn-completion bonus, and a supply-efficiency bonus, combined into a letter rating from S down to F. Unspent supply points and surviving reinforcement charges carry forward into the next mission, so playing efficiently pays off later in the campaign too."""


func _ready() -> void:
	visible = false
	body.bbcode_enabled = true
	body.scroll_active = true
	body.fit_content = false
	body.text = TEXT
	back_btn.pressed.connect(_on_back_pressed)


func open() -> void:
	visible = true
	body.scroll_to_line(0)


func close() -> void:
	if not visible:
		return
	visible = false
	emit_signal("closed")


func _on_back_pressed() -> void:
	AudioManager.play_button_bottom()
	close()
