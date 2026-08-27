# Orbital Drop — Development History

A day-by-day recap of the project's git history (180 commits, `30/03/2026` → `21/08/2026`, plus later entries for work not committed yet), reconstructed from commit metadata and the actual files each commit touched — since a lot of the original commit messages ("HUH", "sad", "um", "???") don't say much on their own. Where a message was clear, it's used as-is; where it wasn't, the recap below reflects what the changed files show actually happened.

*(Note on renaming the old messages themselves: it's technically possible via `git rebase` / `filter-repo`, but it rewrites every commit hash from that point forward, which means a force-push and would break any other clone of this repo — e.g. your partner's, if they have one. Not something to do casually. This document is the safer way to get a readable history without touching the real one.)*

---

### 30/03/2026 — Project kickoff
Repo initialized and the base Godot project scaffolded (`project.godot`, `.gitignore`, icon). A first test 3D node added to confirm everything worked.

### 20/04/2026 — Learning the tools
Mostly trial-and-error commits against a single test scene while getting comfortable with git/Godot together (several "test"/"another test" commits in a row). One real bit of cleanup: an unused `.editorconfig` removed.

### 22/04/2026 — The actual game begins
`Main.tscn` and a `GameManager` created, the first room model imported, `command_centre.tscn` created, and basic player movement scripted for the first time.

### 23/04/2026 — Player controller takes shape
Player script and walking refined; `command_centre.gd`, `button.gd`, and `main.gd` added to start tying the scene together.

### 24/04/2026 — Room import bug
A room-model fetch error broke things, got reverted, then properly fixed the same day.

### 28/04/2026 — First console models
Unused test script deleted. Holomap and Logistics Terminal 3D models (v1.1) brought in, and room hitboxes started.

### 29/04/2026 — Command Throne & Vox-Caster
Command Throne and Vox-Caster Array models modeled and wired into scenes alongside the command centre.

### 30/04/2026 — Intel Desk added
Intel Desk model and scene added; continued scripting on the player and command centre.

**Screenshots (11):** `Screenshot 2026-04-30 115251.png`, `Screenshot 2026-04-30 115434.png`, `Screenshot 2026-04-30 115717.png`, `Screenshot 2026-04-30 120040.png`, `Screenshot 2026-04-30 120311.png`, `Screenshot 2026-04-30 120341.png`, `Screenshot 2026-04-30 120657.png`, `Screenshot 2026-04-30 121615.png`, `Screenshot 2026-04-30 121716.png`, `Screenshot 2026-04-30 122305.png`, `Screenshot 2026-04-30 122359.png`

### 01/05/2026 — First interactive consoles
Intel Desk and Logistics Terminal made interactive for the first time. Spent a chunk of the day fighting an Intel Desk model import bug (create → revert → create → revert) before it landed.

**Screenshots (16):** `Screenshot 2026-05-01 123429.png`, `Screenshot 2026-05-01 123559.png`, `Screenshot 2026-05-01 123808.png`, `Screenshot 2026-05-01 130531.png`, `Screenshot 2026-05-01 130556.png`, `Screenshot 2026-05-01 130700.png`, `Screenshot 2026-05-01 131817.png`, `Screenshot 2026-05-01 174854.png`, `Screenshot 2026-05-01 175017.png`, `Screenshot 2026-05-01 175043.png`, `Screenshot 2026-05-01 190450.png`, `Screenshot 2026-05-01 190923.png`, `Screenshot 2026-05-01 191005.png`, `Screenshot 2026-05-01 191224.png`, `Screenshot 2026-05-01 191419.png`, `Screenshot 2026-05-01 193554.png`

### 02/05/2026 — The real architecture arrives
Big one: every console and manager rewritten as a proper dedicated script — `CommandCentre`, `CommandThrone`, `GameManager`, `HoloMap`, `IntelConsole`, `LogisticsTerminal`, `PlayerController`, `SquadManager`, `TurnManager`, `VoxCaster` — plus matching popups. This is essentially the day the codebase's real structure was born.

**Screenshots (13):** `Screenshot 2026-05-02 103005.png`, `Screenshot 2026-05-02 110604.png`, `Screenshot 2026-05-02 152305.png`, `Screenshot 2026-05-02 152805.png`, `Screenshot 2026-05-02 153050.png`, `Screenshot 2026-05-02 153114.png`, `Screenshot 2026-05-02 153157.png`, `Screenshot 2026-05-02 153208.png`, `Screenshot 2026-05-02 153217.png`, `Screenshot 2026-05-02 153225.png`, `Screenshot 2026-05-02 153232.png`, `Screenshot 2026-05-02 185551.png`, `Screenshot 2026-05-02 185732.png`

### 03/05/2026 — Wiring continues
Holomap, Main, and Command Centre scenes connected up further.

### 04/05/2026 — Stabilizing + first audio
Bug fixes across Command Centre/HoloMap/Intel/Logistics popups. First sound effects added (laser cannon, space ambience).

**Screenshots (16):** `Screenshot 2026-05-04 082750.png`, `Screenshot 2026-05-04 083401.png`, `Screenshot 2026-05-04 141254.png`, `Screenshot 2026-05-04 141548.png`, `Screenshot 2026-05-04 141826.png`, `Screenshot 2026-05-04 141912.png`, `Screenshot 2026-05-04 143040.png`, `Screenshot 2026-05-04 143225.png`, `Screenshot 2026-05-04 143237.png`, `Screenshot 2026-05-04 143244.png`, `Screenshot 2026-05-04 143252.png`, `Screenshot 2026-05-04 143301.png`, `Screenshot 2026-05-04 143501.png`, `Screenshot 2026-05-04 143603.png`, `Screenshot 2026-05-04 144012.png`, `Screenshot 2026-05-04 144853.png`

### 07/05/2026 — Console fixes
Command Centre, Game Manager, Intel Console, Logistics, and Vox-Caster scripts patched up.

**Screenshots (15):** `Screenshot 2026-05-07 100940.png`, `Screenshot 2026-05-07 101206.png`, `Screenshot 2026-05-07 101425.png`, `Screenshot 2026-05-07 101442.png`, `Screenshot 2026-05-07 101446.png`, `Screenshot 2026-05-07 101453.png`, `Screenshot 2026-05-07 101457.png`, `Screenshot 2026-05-07 101503.png`, `Screenshot 2026-05-07 101550.png`, `Screenshot 2026-05-07 102231.png`, `Screenshot 2026-05-07 102911.png`, `Screenshot 2026-05-07 102916.png`, `Screenshot 2026-05-07 102921.png`, `Screenshot 2026-05-07 102926.png`, `Screenshot 2026-05-07 102945.png`

### 08/05/2026 — General stabilization
A broad pass touching nearly every manager, console, and popup script at once.

### 11/05/2026 — More audio + Enemy Manager
Alarm/klaxon and button-toggle sound effects added. `EnemyManager` created and the other managers reworked to use it.

### 12/05/2026 — The folder reorg
Managers reworked again, and scripts split into the `Scripts/Consoles/`, `Scripts/Managers/`, `Scripts/Popups/` structure that's still in use today.

### 13/05/2026 — Post-reorg fixes
Follow-up fixes to Enemy/Squad managers and two popups after yesterday's restructure.

### 15/05/2026 — Room touch-ups
Minor tweaks to the test room model.

### 19/05/2026 — Holomap 2.0 begins
First pass at a new Holomap model.

### 22/05/2026 — Scripting + Holomap 2.0 progress
Manager/popup scripting pass alongside continued work on the Holomap 2.0 model.

**Screenshots (6):** `Screenshot 2026-05-22 092435.png`, `Screenshot 2026-05-22 092448.png`, `Screenshot 2026-05-22 092456.png`, `Screenshot 2026-05-22 092501.png`, `Screenshot 2026-05-22 092521.png`, `Screenshot 2026-05-22 095232.png`

### 25/05/2026 — Command Throne 2.0
A new Command Throne model started alongside the ongoing Holomap 2.0 import work.

**Screenshots (12):** `Screenshot 2026-05-25 095108.png`, `Screenshot 2026-05-25 095643.png`, `Screenshot 2026-05-25 095738.png`, `Screenshot 2026-05-25 095819.png`, `Screenshot 2026-05-25 100203.png`, `Screenshot 2026-05-25 100419.png`, `Screenshot 2026-05-25 100742.png`, `Screenshot 2026-05-25 100811.png`, `Screenshot 2026-05-25 100818.png`, `Screenshot 2026-05-25 100822.png`, `Screenshot 2026-05-25 100827.png`, `Screenshot 2026-05-25 100832.png`

### 26/05/2026 — Rollback day
The Command Throne/Holomap 2.0 experiments caused problems, so both got reverted back to the known-working versions.

### 27/05/2026 — Asset pipeline cleanup
Batch re-import of the v1.1 generation of models (Command Throne, Holomap, Intel Desk, Logistics, Vox-Caster, Room) plus the 2.0 models — getting the import settings consistent.

**Screenshots (6):** `Screenshot 2026-05-27 124223.png`, `Screenshot 2026-05-27 125316.png`, `Screenshot 2026-05-27 125321.png`, `Screenshot 2026-05-27 125327.png`, `Screenshot 2026-05-27 125332.png`, `Screenshot 2026-05-27 125340.png`

### 28/05/2026 — Safety net
A "Backup room" model added (insurance against another import mishap) plus a Holomap popup fix.

**Screenshots (1):** `Screenshot 2026-05-28 140526.png`

### 02/06/2026 — Logistics 2.0 + plain Intel Desk
Holomap popup fixed; Logistics Terminal 2.0 and a simpler Intel Desk model added.

### 03/06/2026 — GUI fixes
Command Throne and Logistics Terminal scene UI adjusted.

### 04/06/2026 — Import finished
Logistics Terminal 2.0 model import completed.

### 05/06/2026 — Small fixes
Backup room + a Command Throne scene tweak.

### 08/06/2026 — Vox-Caster refresh
Logistics Terminal 2.0 re-added, Command Throne tweaked, and the Vox-Caster Array model refreshed.

### 10/06/2026 — Import finished
Vox-Caster Array model import completed.

### 11/06/2026 — Manager + UI pass
Enemy/Game/Squad/Turn managers and two popups reworked; UI pass across all five console scenes.

**Screenshots (23):** `Screenshot 2026-06-11 101824.png`, `Screenshot 2026-06-11 101829.png`, `Screenshot 2026-06-11 101903.png`, `Screenshot 2026-06-11 101907.png`, `Screenshot 2026-06-11 101914.png`, `Screenshot 2026-06-11 101921.png`, `Screenshot 2026-06-11 102447.png`, `Screenshot 2026-06-11 102503.png`, `Screenshot 2026-06-11 103107.png`, `Screenshot 2026-06-11 103207.png`, `Screenshot 2026-06-11 103226.png`, `Screenshot 2026-06-11 103347.png`, `Screenshot 2026-06-11 103536.png`, `Screenshot 2026-06-11 103540.png`, `Screenshot 2026-06-11 104351.png`, `Screenshot 2026-06-11 104616.png`, `Screenshot 2026-06-11 104647.png`, `Screenshot 2026-06-11 104658.png`, `Screenshot 2026-06-11 104915.png`, `Screenshot 2026-06-11 104920.png`, `Screenshot 2026-06-11 104936.png`, `Screenshot 2026-06-11 105127.png`, `Screenshot 2026-06-11 105821.png`

### 12/06/2026 — More GUI work
Continued GUI updates to Command Throne and Vox-Caster, plus manager/popup tweaks.

**Screenshots (8):** `Screenshot 2026-06-12 114935.png`, `Screenshot 2026-06-12 115017.png`, `Screenshot 2026-06-12 115218.png`, `Screenshot 2026-06-12 115227.png`, `Screenshot 2026-06-12 115233.png`, `Screenshot 2026-06-12 115315.png`, `Screenshot 2026-06-12 115403.png`, `Screenshot 2026-06-12 120244.png`

### 16/06/2026 — The game becomes playable
The big one: `HexCanvas.gd` created (the hex-grid map renderer), with Holomap/Intel Desk scenes and three managers updated together. Commit message says it best: *"made game possible."* Vox-Caster hitbox fix too.

### 17/06/2026 — Mission 2 work begins
Holomap/Logistics scenes and four manager/popup scripts updated to support a second mission.

**Screenshots (6):** `Screenshot 2026-06-17 084240.png`, `Screenshot 2026-06-17 084808.png`, `Screenshot 2026-06-17 132124.png`, `Screenshot 2026-06-17 132136.png`, `Screenshot 2026-06-17 132405.png`, `Screenshot 2026-06-17 144749.png`

### 18/06/2026 — Mission 2 continues
Small Command Throne/Holomap tweak, plus more Mission 2 work on Enemy/Game/Turn managers.

**Screenshots (1):** `Screenshot 2026-06-18 095323.png`

### 22/06/2026 — Gameplay tuning
HoloMap bugfix, a new map, Logistics budget increased to 2, and a reinforcement alert added at the Intel console.

**Screenshots (17):** `Screenshot 2026-06-22 082923.png`, `Screenshot 2026-06-22 082952.png`, `Screenshot 2026-06-22 083001.png`, `Screenshot 2026-06-22 083033.png`, `Screenshot 2026-06-22 083307.png`, `Screenshot 2026-06-22 112756.png`, `Screenshot 2026-06-22 113636.png`, `Screenshot 2026-06-22 120727.png`, `Screenshot 2026-06-22 120733.png`, `Screenshot 2026-06-22 120915.png`, `Screenshot 2026-06-22 121015.png`, `Screenshot 2026-06-22 121209.png`, `Screenshot 2026-06-22 121333.png`, `Screenshot 2026-06-22 121353.png`, `Screenshot 2026-06-22 121415.png`, `Screenshot 2026-06-22 121615.png`, `Screenshot 2026-06-22 121935.png`

### 23/06/2026 — Bug fixes + features
Search bug fixed at Logistics/Intel, a scroll view added to Command Throne, max-reinforce logic added, Command Throne GUI fixed.

### 24/06/2026 — Debug tools + bug hunting
A debug mission-select added, with bug-fixing attempts across Enemy/Game/Squad managers and PlayerController; a couple of follow-up HexCanvas tweaks.

**Screenshots (11):** `Screenshot 2026-06-24 081801.png`, `Screenshot 2026-06-24 081954.png`, `Screenshot 2026-06-24 082120.png`, `Screenshot 2026-06-24 082226.png`, `Screenshot 2026-06-24 082448.png`, `Screenshot 2026-06-24 084828.png`, `Screenshot 2026-06-24 085103.png`, `Screenshot 2026-06-24 140841.png`, `Screenshot 2026-06-24 141908.png`, `Screenshot 2026-06-24 142456.png`, `Screenshot 2026-06-24 142506.png`

### 25/06/2026 — Orbital drop mechanic
Got the orbital-drop ("boom") effect working, added a delay to it, and added Intel Desk info displays.

**Screenshots (8):** `Screenshot 2026-06-25 140709.png`, `Screenshot 2026-06-25 140920.png`, `Screenshot 2026-06-25 141059.png`, `Screenshot 2026-06-25 141305.png`, `Screenshot 2026-06-25 141315.png`, `Screenshot 2026-06-25 141327.png`, `Screenshot 2026-06-25 141806.png`, `Screenshot 2026-06-25 142534.png`

### 26/06/2026 — Main menu begins
`SettingsManager` created, and the first version of the main menu (`MainMenu.gd` + scene) built.

**Screenshots (7):** `Screenshot 2026-06-26 091013.png`, `Screenshot 2026-06-26 142113.png`, `Screenshot 2026-06-26 142200.png`, `Screenshot 2026-06-26 142225.png`, `Screenshot 2026-06-26 142231.png`, `Screenshot 2026-06-26 142242.png`, `Screenshot 2026-06-26 143506.png`

### 29/06/2026 — First playable build
First web export (`BUILDS/BUILD1`) — this is when the game first became something playable outside the editor. Bug/signal fixes to HexCanvas and Vox-Caster popup alongside it.

**Screenshots (6):** `Screenshot 2026-06-29 093300.png`, `Screenshot 2026-06-29 093558.png`, `Screenshot 2026-06-29 093624.png`, `Screenshot 2026-06-29 093633.png`, `Screenshot 2026-06-29 093648.png`, `Screenshot 2026-06-29 093659.png`

### 30/06/2026 — Tutorial system begins
`TutorialOverlay`, `Arrow`, and `TutorialStep` scripts created and wired into the Logistics console as a beta tutorial.

**Screenshots (17):** `Screenshot 2026-06-30 094539.png`, `Screenshot 2026-06-30 094727.png`, `Screenshot 2026-06-30 094913.png`, `Screenshot 2026-06-30 094923.png`, `Screenshot 2026-06-30 094929.png`, `Screenshot 2026-06-30 094949.png`, `Screenshot 2026-06-30 095115.png`, `Screenshot 2026-06-30 095519.png`, `Screenshot 2026-06-30 113644.png`, `Screenshot 2026-06-30 113647.png`, `Screenshot 2026-06-30 113650.png`, `Screenshot 2026-06-30 113654.png`, `Screenshot 2026-06-30 113700.png`, `Screenshot 2026-06-30 113703.png`, `Screenshot 2026-06-30 113711.png`, `Screenshot 2026-06-30 114615.png`, `Screenshot 2026-06-30 114731.png`

### 01/07/2026 — itch.io export + new room
The itch.io web export redone, and a new room model brought in.

### 02/07/2026 — Reorg + Mission 4 begins
Tutorial scripts moved into their own `Scripts/Tutorial/` folder; Mission 4's map work started in `GameManager`.

### 03/07/2026 — New objective system
A beta mission-objective system built across HexCanvas, Enemy/Game/Squad managers, and the Holomap popup.

**Screenshots (2):** `Screenshot 2026-07-03 115637.png`, `Screenshot 2026-07-03 140153.png`

### 20/07/2026 — (no commits — screenshots only)
**Screenshots (6):** `Screenshot 2026-07-20 085130.png`, `Screenshot 2026-07-20 085933.png`, `Screenshot 2026-07-20 091341.png`, `Screenshot 2026-07-20 092018.png`, `Screenshot 2026-07-20 092024.png`, `Screenshot 2026-07-20 092051.png`

### 21/07/2026 — (no commits — screenshots only)
**Screenshots (1):** `Screenshot 2026-07-21 103623.png`

### 22/07/2026 — Mission updates (after a 3-week gap)
Broad mission-related updates across every manager and popup, plus a room model refresh and a same-day follow-up fix.

**Screenshots (4):** `Screenshot 2026-07-22 113156.png`, `Screenshot 2026-07-22 113215.png`, `Screenshot 2026-07-22 113223.png`, `Screenshot 2026-07-22 113230.png`

### 23/07/2026 — More mission work
Further updates to Enemy/Game managers and the Intel popup; a Vox-Caster Array exported to glTF.

**Screenshots (1):** `Screenshot 2026-07-23 132400.png`

### 24/07/2026 — Vox-Caster remodeled
Vox-Caster Array rebuilt as a "2.0" model; a small Player scene tweak (hand positioning).

### 29/07/2026 — (no commits — screenshots only)
**Screenshots (15):** `Screenshot 2026-07-29 083010.png`, `Screenshot 2026-07-29 083059.png`, `Screenshot 2026-07-29 102708.png`, `Screenshot 2026-07-29 102715.png`, `Screenshot 2026-07-29 102722.png`, `Screenshot 2026-07-29 102727.png`, `Screenshot 2026-07-29 102733.png`, `Screenshot 2026-07-29 103209.png`, `Screenshot 2026-07-29 103228.png`, `Screenshot 2026-07-29 103557.png`, `Screenshot 2026-07-29 103926.png`, `Screenshot 2026-07-29 105326.png`, `Screenshot 2026-07-29 105602.png`, `Screenshot 2026-07-29 105916.png`, `Screenshot 2026-07-29 105922.png`

### 30/07/2026 — Tutorial rolled out everywhere
The tutorial system extended across nearly every console, manager, and popup, plus a new build export.

**Screenshots (8):** `Screenshot 2026-07-30 081749.png`, `Screenshot 2026-07-30 081802.png`, `Screenshot 2026-07-30 111113.png`, `Screenshot 2026-07-30 112131.png`, `Screenshot 2026-07-30 113305.png`, `Screenshot 2026-07-30 114228.png`, `Screenshot 2026-07-30 115338.png`, `Screenshot 2026-07-30 115357.png`

### 31/07/2026 — The Guide system is built
A full in-game help/briefing system created in one pass: `GuideOverlay`, `MissionBriefingOverlay`, `GuideManager`, `Arrow_Canvas`, `BriefingHexPreview`, and `Objective_Text` all added together.

**Screenshots (11):** `Screenshot 2026-07-31 103957.png`, `Screenshot 2026-07-31 104005.png`, `Screenshot 2026-07-31 104012.png`, `Screenshot 2026-07-31 111041.png`, `Screenshot 2026-07-31 111053.png`, `Screenshot 2026-07-31 121836.png`, `Screenshot 2026-07-31 131423.png`, `Screenshot 2026-07-31 162426.png`, `Screenshot 2026-07-31 170749.png`, `Screenshot 2026-07-31 170949.png`, `Screenshot 2026-07-31 171037.png`

### 01/08/2026 — (no commits — screenshots only)
**Screenshots (1):** `Screenshot 2026-08-01 125359.png`

### 03/08/2026 — Bug fixes + a git mixup
Game/Squad manager fixes; a "final" Holomap model attempt; a merge got reverted and then reapplied the next day (a git hiccup, not lost work).

**Screenshots (5):** `Screenshot 2026-08-03 143429.png`, `Screenshot 2026-08-03 144131.png`, `Screenshot 2026-08-03 144253.png`, `Screenshot 2026-08-03 144330.png`, `Screenshot 2026-08-03 144406.png`

### 04/08/2026 — (no commits — screenshots only)
**Screenshots (8):** `Screenshot 2026-08-04 080615.png`, `Screenshot 2026-08-04 183946.png`, `Screenshot 2026-08-04 184221.png`, `Screenshot 2026-08-04 184352.png`, `Screenshot 2026-08-04 184641.png`, `Screenshot 2026-08-04 184733.png`, `Screenshot 2026-08-04 185118.png`, `Screenshot 2026-08-04 185232.png`

### 05/08/2026 — Guide system finished
Yesterday's revert reapplied properly, the Holomap 3.0 experiment rolled back, and a big pass finishing the Guide/Briefing system plus a new Command Centre room model. (A few stray Godot autosave `.tmp` files snuck into this commit — harmless, but worth deleting from the repo next time you're in there.)

**Screenshots (26):** `c67143c0-c57d-462e-8302-f01aa585fea1.png`, `Screenshot 2026-08-05 090302.png`, `Screenshot 2026-08-05 090420.png`, `Screenshot 2026-08-05 090521.png`, `Screenshot 2026-08-05 090819.png`, `Screenshot 2026-08-05 090839.png`, `Screenshot 2026-08-05 091004.png`, `Screenshot 2026-08-05 091104.png`, `Screenshot 2026-08-05 091134.png`, `Screenshot 2026-08-05 091526.png`, `Screenshot 2026-08-05 091724.png`, `Screenshot 2026-08-05 091732.png`, `Screenshot 2026-08-05 091808.png`, `Screenshot 2026-08-05 091816.png`, `Screenshot 2026-08-05 091828.png`, `Screenshot 2026-08-05 102754.png`, `Screenshot 2026-08-05 141135.png`, `Screenshot 2026-08-05 141324.png`, `Screenshot 2026-08-05 141725.png`, `Screenshot 2026-08-05 142711.png`, `Screenshot 2026-08-05 142732.png`, `Screenshot 2026-08-05 145145.png`, `Screenshot 2026-08-05 145150.png`, `Screenshot 2026-08-05 145327.png`, `Screenshot 2026-08-05 145331.png`, `Screenshot 2026-08-05 145358.png`

### 06/08/2026 — Reinforcement logic
Reinforcement rules updated across Game/Squad/Turn managers and the Holomap popup.

**Screenshots (3):** `Screenshot 2026-08-06 160830.png`, `Screenshot 2026-08-06 160901.png`, `Screenshot 2026-08-06 162551.png`

### 10/08/2026 — (no commits — screenshots only)
**Screenshots (2):** `Screenshot 2026-08-10 153909.png`, `Screenshot 2026-08-10 161724.png`

### 12/08/2026 — Squad navigation fix
A squad-pathing bug fixed across Holomap, BriefingHexPreview, HexCanvas, and the Enemy/Game/Squad managers.

**Screenshots (1):** `Screenshot 2026-08-12 140836.png`

### 13/08/2026 — Finalizing pass
A broad "finalizing" pass across Command Centre/Game/Guide/Squad/Turn managers, two build exports, supply tuning, and Mission 5 bug fixes.

**Screenshots (7):** `Screenshot 2026-08-13 084122.png`, `Screenshot 2026-08-13 084138.png`, `Screenshot 2026-08-13 084755.png`, `Screenshot 2026-08-13 090519.png`, `Screenshot 2026-08-13 091558.png`, `Screenshot 2026-08-13 094610.png`, `Screenshot 2026-08-13 095729.png`

### 14/08/2026 — Mission 4 reworked, Mission 5 redone
A large pass touching Command Centre, Guide, HexCanvas, all four managers, PlayerController, and three popups to rebuild Missions 4 and 5.

**Screenshots (12):** `Screenshot 2026-08-14 100835.png`, `Screenshot 2026-08-14 100909.png`, `Screenshot 2026-08-14 101720.png`, `Screenshot 2026-08-14 102126.png`, `Screenshot 2026-08-14 102258.png`, `Screenshot 2026-08-14 102829.png`, `Screenshot 2026-08-14 103007.png`, `Screenshot 2026-08-14 103022.png`, `Screenshot 2026-08-14 103033.png`, `Screenshot 2026-08-14 103215.png`, `Screenshot 2026-08-14 103617.png`, `Screenshot 2026-08-14 103805.png`

### 17/08/2026 — (no commits — screenshots only)
**Screenshots (2):** `Screenshot 2026-08-17 120010.png`, `Screenshot 2026-08-17 121722.png`

### 18/08/2026 — Ambient audio + Command Centre refresh
`AudioManager` created for ambient sound, a new Command Centre room model, a Hologram Panel shader started, and a recolored Holomap 3.0 model.

### 19/08/2026 — Guide improvements + new Command Throne
A "Help Nudge" added to the guide system; a bevel pass on Holomap 3.0; a new Command Throne 3.0 model ("Chair").

**Screenshots (14):** `Screenshot 2026-08-19 083324.png`, `Screenshot 2026-08-19 140454.png`, `Screenshot 2026-08-19 140505.png`, `Screenshot 2026-08-19 140513.png`, `Screenshot 2026-08-19 140529.png`, `Screenshot 2026-08-19 142120.png`, `Screenshot 2026-08-19 142129.png`, `Screenshot 2026-08-19 142136.png`, `Screenshot 2026-08-19 142150.png`, `Screenshot 2026-08-19 142157.png`, `Screenshot 2026-08-19 144406.png`, `Screenshot 2026-08-19 145010.png`, `Screenshot 2026-08-19 145349.png`, `Screenshot 2026-08-19 145357.png`

### 20/08/2026 — Big UI day
Manual reference images added (combat odds, console guides, hex legend, status ladder, turn cycle), the main menu fully built out (background art, shader, instructions popup), a full icon set added (play/settings/exit/instructions + map markers) — and this is the day the space sky shader and viewscreen backdrop were built, right before this session started.

**Screenshots (22):** `Screenshot 2026-08-20 084000.png`, `Screenshot 2026-08-20 084349.png`, `Screenshot 2026-08-20 084720.png`, `Screenshot 2026-08-20 110450.png`, `Screenshot 2026-08-20 110502.png`, `Screenshot 2026-08-20 123548.png`, `Screenshot 2026-08-20 123608.png`, `Screenshot 2026-08-20 123850.png`, `Screenshot 2026-08-20 125657.png`, `Screenshot 2026-08-20 130346.png`, `Screenshot 2026-08-20 131117.png`, `Screenshot 2026-08-20 150958.png`, `Screenshot 2026-08-20 162011.png`, `Screenshot 2026-08-20 162103.png`, `Screenshot 2026-08-20 162132.png`, `Screenshot 2026-08-20 180313.png`, `Screenshot 2026-08-20 180330.png`, `Screenshot 2026-08-20 180904.png`, `Screenshot 2026-08-20 193349.png`, `Screenshot 2026-08-20 194727.png`, `Screenshot 2026-08-20 195216.png`, `Screenshot 2026-08-20 195225.png`

### 21/08/2026 — Epilogue built out (working with Claude)
Planet edge/explosion polish and Retry Campaign / Return-to-Menu buttons landed on the mission report screen first, then the day's real focus: the Epilogue sequence. Crawl text, camera choreography, and a dive-into-cloud transition were built, leading into an ending that started as a 3D terrain/flag/helmet/memorial scene before being rebuilt as a flat, layered 2D finale instead — flag on its pole, rising into place over a backdrop, with the battlefield dressing and a credits roll both cut once they didn't earn their place. The flag banner needed the most iteration: its source texture turned out to have no real transparency at all (a fully opaque logo card), so getting a proper rippling cloth silhouette out of it took two shader rewrites — a chroma-key pass that stripped too much (reverted after review), then a wavy alpha-cutout silhouette that keeps the flag's solid black fill intact — followed by a final pass adding a procedural gold border that tracks the moving cutout edge instead of relying on the texture's static baked-in one. Still in progress as of this entry.

**Screenshots (22):** `Screenshot 2026-08-21 081332.png`, `Screenshot 2026-08-21 082059.png`, `Screenshot 2026-08-21 084323.png`, `Screenshot 2026-08-21 085001.png`, `Screenshot 2026-08-21 085018.png`, `Screenshot 2026-08-21 094337.png`, `Screenshot 2026-08-21 094344.png`, `Screenshot 2026-08-21 095430.png`, `Screenshot 2026-08-21 095613.png`, `Screenshot 2026-08-21 095618.png`, `Screenshot 2026-08-21 095621.png`, `Screenshot 2026-08-21 103728.png`, `Screenshot 2026-08-21 112638.png`, `Screenshot 2026-08-21 114947.png`, `Screenshot 2026-08-21 142738.png`, `Screenshot 2026-08-21 165418.png`, `Screenshot 2026-08-21 170135.png`, `Screenshot 2026-08-21 173109.png`, `Screenshot 2026-08-21 173850.png`, `Screenshot 2026-08-21 202723.png`, `Screenshot 2026-08-21 203630.png`, `Screenshot 2026-08-21 204244.png`

### 22/08/2026 — (no commits — screenshots only)
**Screenshots (2):** `Screenshot 2026-08-22 122016.png`, `Screenshot 2026-08-22 144723.png`

### 23/08/2026 — Flag shader finished, then a full-project review
A polish pass back over the epilogue rather than new features. The flag shader was reworked once more: the procedural gold border added on the 21st turned out to only hold up in the middle of the wave — at the extremes the rippling band was being pushed outside the texture entirely (roughly a third of the flag's width at any given moment), which switched the cutout off in those columns and put the texture's original straight border back on screen, the exact problem the procedural border was added to solve. Replaced with a cleaner approach: the texture is now *sampled through* the moving band rather than sitting still behind it, so the art's own gold border is carried along by the same wave that cuts the silhouette and lands on the cloth edge by construction — no second border needed, and the logo and text now ripple with the cloth instead of staying flat. The band was also changed to slide as one piece instead of pinching and bulging, which is what makes a single margin enough to guarantee it never clips against the quad.

Alongside that: the flag's sizing constants were split so the *visible cloth* is what gets dimensioned (the rect around it is derived, since the shader needs transparent headroom for the wave), the state machine's untyped locals were given explicit types, a stale `[PARTNER NAME]` note left over from the removed credits was deleted, and the now-unused 3D `Flag.gdshader` was marked as such so it's clear it can be dropped.

Then a full-project review pass over all 11,000 lines of script, the scenes and the shaders. Nine defects were found and fixed:

- **Main menu unusable after returning to it.** The player controller re-captures the mouse on its way out and mouse mode is global, so the menu loaded with the cursor hidden and locked to screen centre — no button clickable and no keyboard fallback, meaning the process had to be killed. `MainMenu._ready()` now sets the mouse visible.
- **`mission_complete` fired twice on every win.** It was emitted inside the `if won:` branch *and* again unconditionally underneath. The unconditional emit couldn't simply be deleted — the console popups only connect to `mission_complete` and branch on `report.won`, so it's what makes the *failure* report and its Retry button appear too. Restructured so `mission_failed` is the conditional one.
- **A new campaign inherited the previous run's casualties.** `start_campaign()` reset the mission index and supply pools but not the squad roster, so finishing a run and pressing Play started Mission 1 with the last run's dead squads still marked Lost — an instant turn-1 failure if both starting squads had died. Retry Campaign did this clearing by hand; it now lives in `start_campaign()` where both callers get it.
- **The guide never retired itself.** `turn_ended` passes a turn number but `GuideManager.on_turn_ended()` took no parameters, so the connection failed at emit time and the tutorial prompts ran all mission instead of stopping after turn 1.
- **Holo-Map clicks landed on the wrong hex.** The hit test used the flat-top pixel→axial inverse against a pointy-top layout, giving a containment hexagon rotated 30° against the one actually drawn — so part of each hex couldn't be clicked and a sliver outside it could, and reinforcement drops or orbital strikes could land on a neighbouring sector.
- **Tower / priority / extraction hexes were never tinted.** The colour override was computed *after* the polygon had already been drawn, so the whole block including its pulse animations was dead.
- **Map panning was broken on Missions 1 and 2.** When the map fits inside the canvas the clamp bounds invert, and Godot's `clamp()` silently collapses an inverted pair to the upper bound — the grid snapped to a fixed offset and then refused to move.
- **Seven of the Help tutorial arrows pointed at nothing.** All five Holo-Map steps and two of the four Command Throne steps used node paths that don't exist, so those steps showed with no arrow at all — including the two explaining the Turn Seal button.
- **Debug mission-jump keys were live in the build.** Number keys 1–5 reset the campaign with no confirmation and the code was self-labelled "remove before release"; now gated behind `OS.is_debug_build()` so they still work from the editor.

**Screenshots (3):** `Screenshot 2026-08-23 164505.png`, `Screenshot 2026-08-23 180943.png`, `Screenshot 2026-08-23 182231.png`

### 24/08/2026 — Epilogue ending, squad AI and the Holo-Map
A long day of play-testing feedback, working through the epilogue and then the consoles.

First, the epilogue's crawl was cutting away before either block of text had finished leaving the screen. The hand-off was triggered by testing the label's *origin* against a fixed recession distance, which was wrong twice over — the origin sits at the block's top line with the rest of the text hanging below it, so it says nothing about where the last line has got to, and at the tuned values it tripped after 18.4 units of scroll when even the top line didn't clear the frame until 20.2. Replaced with a real geometric test: take the lowest point of the rendered text (read from the label, so wrapping is handled and editing the text can't silently reintroduce an early cut) and check whether it has passed above the top of the camera's frustum. The one genuinely counter-intuitive case is handled explicitly — the block is tilted away from the camera, so its last line is its *nearest* point and on a long crawl starts out behind the camera, which means "behind the camera" has to read as *not yet finished* rather than the obvious opposite.

The epilogue's ending was reworked. The "dive into a cloud" transition is gone — the cloud rig, its shader material and its ~50 lines of builder code — and the beat is now a straight FOV zoom into the planet, pushed further in (62°→10°, about 7× magnification) and given a little longer to run since the cloud rushing past the camera used to do half the work of selling it. The camera's forward travel went with it: the planet is drawn by the sky shader, so it sits at infinity and moving toward it couldn't change its size on screen by a single pixel. Only the FOV actually closes the distance.

And the mouse wheel now fast-forwards the crawl instead of doing nothing useful: wheel down piles on speed up to about 8× reading pace, wheel up bleeds it back off, and the boost decays on its own so it's an active fast-forward rather than a switch that stays flipped. It's scoped to the crawl only — the reveal, the zoom and the flag hold are fixed-length beats built around their own easing and the wash to white, so letting the wheel rush those would just desynchronise the ending. Worth noting this was previously worse than a no-op: a wheel notch arrives as a mouse *button* press, so nudging the wheel used to fall through to the skip handler and silently abandon the whole epilogue.

Mission 4's squad AI was changed so that whichever squad is closest to the priority target always goes after it, full stop. Previously a squad standing on the comms tower was explicitly excluded from being picked as the hunter — a rule added earlier to stop tower garrisons being yanked away, but the effect was that a squad landing on the tower while Vreth was still alive stayed put powering it. The target now outranks the tower while it's alive: the tower is worth holding, but it's worth nothing if the mission's actual objective never gets hunted.

That change surfaced a latent freeze that had to be fixed with it. The `ATTACK_PRIORITY` movement branch has no "not already there" guard (unlike the tower branch, which does), so a hunting squad that ends up sharing a hex with the target calls `_path_toward(x, x)`, which returns an empty string — and the `if step_target == "": break` check sits *above* the goal overrides, so nothing re-checked it. The squad's sector was then assigned `""`: it dropped off the map permanently, every later target resolving from `""` to `""` again, while `capture_tile("")` quietly added a bogus entry to `hex_control` that the held-sector count treated as real. Rare before; much easier to hit now that squads hunt from the tower. Guarded.

The Vox-Caster's floating "!" now only appears when a squad is in Critical condition. It was previously raised at the start of every single turn regardless of how the squads were actually doing, so it was permanently lit and carried no information — exactly what an alert marker must not become. It also now clears itself on turns where nobody is critical, rather than only when the console is opened, so patching a squad back up to Wounded takes the marker down with it.

The Holo-Map can now actually be scrolled. Panning was bound to middle-mouse-drag and nothing else — no wheel, no left-drag — which on the Mission 3–5 maps left most players with no way they'd ever find to reach the edges; those grids are around 1250px wide against a 630px canvas, so roughly half the map sits off-screen at any moment. The wheel now scrolls vertically, shift+wheel horizontally (trackpad horizontal scroll is handled too), and the left button drags the map. Left-drag shares the button with hex selection safely: selection moved to fire on release, and only when the mouse travelled less than a few pixels, so dragging across the grid can't drop a reinforcement wherever the drag happened to end. A drag also no longer sticks to the cursor if the mouse is released outside the canvas.

Separately, on Missions 1 and 2 the map genuinely has nowhere to scroll — those grids are only ~300px and ~530px wide, so they fit the canvas entirely. Rather than leaving the pan wherever it happened to sit, it now centres them.

The Holo-Map's grid was given most of the screen. It had been a fixed 630×410 box inside a panel that fills the whole window, so it never grew — leaving a large dead strip of empty panel below it while the map itself was cut off mid-row. It now stretches into whatever room the popup has left over (roughly 1.9× taller at 1080p), the sector list gave back some of its height, and the header block above the grid — title, subtitle, turn line and legend — was cut down to match the sector list's text size, since it was eating close to a fifth of the popup before the map even started.

Because the canvas is no longer a fixed size, where the grid actually sits is now decided by the pan offset rather than by the hardcoded layout centre, so it recentres itself on resize and when the map changes — but deliberately *not* on the ordinary once-a-turn refresh, which would otherwise yank the view back to centre out from under a player who had scrolled somewhere on purpose.

**Screenshots (6):** `Screenshot 2026-08-24 103423.png`, `Screenshot 2026-08-24 104645.png`, `Screenshot 2026-08-24 110736.png`, `Screenshot 2026-08-24 145751.png`, `Screenshot 2026-08-24 165351.png`, `Screenshot 2026-08-24 192231.png`

### 25/08/2026 — Mission 5 extraction, and the orbital laser
Both halves of the same problem: getting to the shuttle, and what happens when you reach it. Then a new effect for the orbital strike.

The orbital strike now fires a visible beam. `OrbitalLaser.gdshader` plus a builder in `CommandCentre.gd` throws a Helldivers-style column of light from the command throne's position out along +X — which is very nearly straight at the planet, since the sky shader puts it at (1.0, -0.55, 0.04). Two nested cylinders: a thin near-white core inside a wider orange sheath, both additive, so the overlap down the middle is what actually blows out to white rather than either layer being white on its own. It hangs off the existing `orbital_strike_resolved` signal, so it can only fire on turns where a strike was actually armed and landed, and the whole rig builds itself, fires and frees itself — nothing accumulates over a campaign of repeated strikes.

Drop pods followed. Engaging the Turn Seal now launches a salvo from under the deck — one pod for each thing actually being sent, meaning every supply type allocated to every squad plus one for a reinforcement if one is called in. There's no ceiling on the count — the salvo is however big the turn was, so a heavy resupply across a full roster genuinely looks like one; the mission's supply pool and the two-supplies-per-squad rule keep it sane without an arbitrary cap. Past a certain size the pods close ranks rather than fanning wider, so the outermost ones never launch from beyond the edge of the deck. They fire staggered rather than in unison, fan out sideways so they don't launch through each other, and accelerate away rather than drifting at a constant crawl. They fly an arc rather than a straight line: up out from under the deck, over a crest, then away along the same heading the orbital laser fires on, so a strike and a resupply visibly converge on the same point out at the planet. Straight lines were wrong twice over — downward buried the whole salvo under the deck where nothing was ever seen, and straight upward climbed forever without turning over. The arc is only just curved — barely enough lift to rise out from under the deck before running essentially straight at the planet, bowing under six units off a dead-straight line across a 240-unit flight and finishing flat along the laser's axis. Pods also fade out DURING the last stretch of the flight rather than after it, so they thin away while already far off and small (down to under 40% of their launch size when the fade starts, under 8% when it ends) instead of vanishing at full brightness the instant they stop. Worth knowing for anyone tuning it: a quadratic Bézier only reaches half-way to its control point, so the arc-height constant is roughly double the height actually gained. There's also a one-second beat before the salvo goes, so there's time to look up from the console and watch it leave. The count is worked out back when allocations lock at Logistics, since by the time the turn resolves there's nothing left to count from, then spent when the seal is engaged. The pod body, its tapering trail and the strike beam all share the one shader — the pods just run it in the amber of the title screen's drop-pod glow, so the two read as the same craft.

The launch sound was synthesised from scratch rather than sourced: a mag-catapult release built from a metallic clank, a heavy low thump and a band-passed whoosh sweeping up and receding. The first attempt measured 85% high-frequency energy and would have sounded like hiss, so it was rebalanced until the attack was low/mid-led — a salvo of seven needs to read as heavy machinery, and it's mixed a few dB down for the same reason.

Tuned after a first look: thicker (core and sheath both roughly doubled), a lighter orange, and the beam now runs for exactly as long as the cannon-fire clip instead of a fixed 2 seconds. That last one reads the length off the audio stream at runtime rather than hardcoding a number, so swapping the sound can't leave a beam hanging in the air after it or cutting out halfway through — the snap-on, flash settle and fade are subtracted from the clip's length so the total matches it. There's a fallback for the sound failing to load, which currently does happen: a few clips in that folder are missing from disk and log a "Failed loading resource" at startup, worth chasing separately.

The white-inside/orange-outside gradient is a fresnel term rather than a texture, which is what makes it hold up from any angle: on a cylinder the surface facing you has its normal pointing at the camera and the silhouette edges have theirs perpendicular, so the falloff is correct wherever you walk to, where a UV ramp would only be right from one viewpoint. Two things had to be got right that a first pass would miss — the fresnel dot needs `abs()` because `cull_disabled` draws the far wall of the cylinder too, and the sheath needs an exponent *below* 1, since the fresnel term only reaches 1 exactly at the silhouette and anything above 1 crushes it into pale cream instead of orange. The colour ramp was checked numerically across the beam's radius before the values were settled.

Mission 5's extraction was made actually reachable. The data carrier was deliberately left on ADVANCE — "stay flexible, don't advertise where the data is" — until the shuttle was inbound, which sounds sensible and turns out to be arithmetically impossible: the shuttle window is the last 2 turns, the carrier starts about 16 hexes from the extraction zone, and even fuelled it covers 2 hexes a turn. It was given at most 4 hexes' worth of notice for a 16-hex journey, so it only ever arrived if ten-odd turns of wandering had happened to carry it the right way. It now heads straight there from turn 1, arriving around turn 8 fuelled or turn 16 unfuelled — which also makes keeping it supplied genuinely matter rather than being incidental.

The rest of the squads follow it for the most part: the number pushing to secure the zone was a flat 2 no matter how many were alive, and is now all but one, with the last left free to take ground for the tile score. Escorts were fixed too — the block meant to send them to the zone when there was nothing to intercept was keyed off a condition that could never be true (the empty case already broke out of the loop above it), so they'd silently fall through to plain advance targeting and wander off, which is exactly what that block was written to prevent.

Pathfinding itself was checked and cleared: traced from every starting squad to the extraction zone, the routes are direct and essentially monotonic, and none of them route through Mission 5's one-way tunnel sectors.

Squads now actually board the Mission 5 shuttle. There was no concept of boarding at all before — extraction was a headcount taken once, at mission end, of whoever happened to be standing on the zone hex, which meant a squad could reach the zone, hold it for two turns, get pushed off or worn down on the final turn, and count for nothing. Reaching the zone while the shuttle is down now sets a one-way `extracted` flag: that squad takes no further turn of any kind — no movement, no combat, no supply draw, no status decay — enemies can't advance onto its hex or wear it down, and it's counted as extracted regardless of what happens to the zone afterwards. The end-of-mission tally still falls back to "standing on the zone" as well, so this can never score lower than the old rule.

Shown everywhere it matters: `[ABOARD]` on the map hex and in the sector list (plain ASCII, same reason as the `[D]` carrier tag — the font has no fallback in the web export), an ABOARD SHUTTLE pill in place of the Active/Wounded status on the Command Throne and Intel Desk, a clear-channel confirmation line on the Vox-Caster instead of a supply request it can no longer act on, removal from the Logistics roster so points can't be spent on a squad that has left the planet, and a "SHUTTLE DOWN — Aboard: n" readout on the Holo-Map.

### 26/08/2026 — A second review pass, and the four-week recaps
A second full review pass over the whole project, and several of what it found were regressions from the previous day's work. The worst was that a squad standing ON the extraction zone walked straight back off it: `Goal.EXTRACT` only steered a squad that wasn't already there, so a fuelled one stepped onto the pad and then off again, and since boarding is only tested after the whole move loop it never got aboard — the carrier being the most likely victim, since it now heads there from turn 1. An orbital strike could also wound or kill squads that had already flown out, because the boarding guard added to overrun casualties was missing from bombardment casualties. Boarded squads were double-counted on the Holo-Map and Command Throne ("Aboard: 2 | At zone: 2" for two squads), missing from the throne's roster tally, and still broadcasting distress calls on the Vox-Caster.

Older defects fixed alongside them: the mission report was being shut in the same frame it appeared — engaging the Turn Seal on a mission-ending turn resolved the mission, showed the report, then closed the popup unconditionally, so the player saw nothing and had to walk back and reopen the throne to find their score. The per-mission alert reset matched a key prefix nothing writes, so dismissing a turn-numbered warning on one mission silently suppressed it on every later one. Reopening the Logistics Terminal capped each squad at one supply instead of two, and could leave a ticked box impossible to un-tick. An armed but unplaced orbital strike sealed the turn anyway and burned the charge with nothing fired. Mission 5's extraction bonus was calculated and then discarded — 440 points that appeared nowhere. The turn counter read one behind everywhere it was shown, opening at "Turn 0 / 5" and never reaching the last turn. A powered relay tower stopped counting as secured the moment its garrison was retasked, failing the mission with the reason "the tower was never taken and powered". And Logistics' end-of-mission overlay was a 40x40 ColorRect with no colour set, i.e. an opaque white square in the corner of the screen.

Spelling and text were checked across every quoted string in the project — 1,119 unique words — along with doubled words and stray spacing. Clean, and the British spellings are consistent throughout. All five missions' sector, axial and adjacency tables were re-validated for size, duplicates, range and reachability of every objective from every squad start.

Alongside the review, the project got a `DEV_RECAP.md`: four four-week recaps of roughly 150 words each, sitting beside this file rather than inside it so the day-by-day detail and the high-level view stay separate. Sixteen weeks, counted in working time rather than calendar time — the three weeks between the repo going up and work actually starting, and the two-and-a-half week July break, are skipped rather than counted, which is why Weeks 9–12 span six calendar weeks.

### 27/08/2026 — Sharpening the planet
The planet was reading as a soft blob rather than a body with a definite edge, and its surface as airbrushed. Four things were doing it. The disc's limb faded over 4.5% of its radius — about 2.4 degrees of sky, roughly forty pixels of blur at a 62-degree field of view — now cut to a fifth of that, giving a silhouette that actually reads as an edge, with the halo narrowed to match so it sits as a defined ring instead of blooming the boundary back out. The atmospheric haze was spread across roughly a third of the visible face; its falloff was steepened and its strength cut so it clings to the grazing limb and stops veiling the terrain underneath. Coastlines and the day/night terminator were both tightened. And the terrain relief shading was lifted from a barely-visible 0.10.

That last one needed care. Simply turning the relief up doubles the ridge-noise contribution, and ridge is thin winding lines — turning it up brings straight back the maze/circuit-board artifact this shader already fought once. So the extra contrast comes mostly from two new isotropic grain octaves instead, used for surface texture only and deliberately kept out of the elevation term, where they would have moved coastlines and snowlines around. Rendering the variants and measuring both the local contrast and the correlation with the ridge pattern found a weighting with the same overall surface contrast and about half as much of the maze showing through. Net result measured 34% more local contrast across the disc.
