# Orbital Drop — Four-Week Recaps

A high-level pass over the project's development in four-week blocks, one short recap each. For the day-by-day detail behind any of these, see `DEV_HISTORY.md`.

Sixteen weeks in total, counted in *working* time rather than calendar time. Two stretches are skipped rather than counted: the three weeks between the repo going up on 30 March and work actually starting on 20 April, and the two-and-a-half week break in July (3rd to 20th). Week 1 therefore begins on 20 April, and the July gap sits inside Weeks 9–12, which is why that block spans six calendar weeks. Across the calendar the project runs 148 days; 110 of those were working days, which is the sixteen weeks below.

---

## Weeks 1–4 · 20/04 → 15/05 — From first steps to a real codebase

The repo had gone up three weeks earlier with nothing in it but a scaffolded Godot project, so this is where the project actually starts. The first days went on learning the tools as much as building — a run of throwaway "test" commits against a single scene while getting git and Godot to cooperate. On 22 April the game proper began: `Main.tscn`, a `GameManager`, the first room model, and a player who could walk around.

Then the command centre filled up fast — Holomap, Logistics Terminal, Command Throne, Vox-Caster Array and Intel Desk all modelled and placed within a week, with the first two becoming interactive on 1 May after a long fight with an import bug.

The turning point was 2 May, when every console and manager was rewritten as a proper dedicated script, plus matching popups. That is effectively the day the codebase's real structure was born, and it still holds. The block closed with the first audio, an `EnemyManager`, and the folder reorg the project still uses.

## Weeks 5–8 · 19/05 → 12/06 — The 2.0 models, and a lesson in reverting

The quietest stretch, and mostly art rather than code. Second-generation models were started for the Holomap and Command Throne, and it went badly enough that 26 May was spent rolling both back to known-good versions — the first real sign that this project's models and imports were going to be the fragile part, not its logic.

What followed was the unglamorous cleanup that made the rest possible: a batch re-import to get settings consistent across every model, and a backup room added purely as insurance against the next mishap. With that in place the 2.0 work went in properly — a new Logistics Terminal, a simpler Intel Desk, a refreshed Vox-Caster Array — each taking a couple of days to model and then finish importing.

Underneath the art, the managers and popups got a broad rework and all five console scenes had a UI pass. Nothing here is dramatic, but it left the game tidy enough to build something real on top of.

## Weeks 9–12 · 16/06 → 30/07 — It becomes a game, then ships

This block opens with the single most important day in the project. On 16 June `HexCanvas.gd` was created — the hex-grid map renderer — alongside updates to three managers and two scenes. The commit message said it best: *"made game possible."* Until then there was a beautifully modelled command centre with nothing to actually command.

Everything accelerated from there. Mission 2 support, gameplay tuning, a debug mission-select for testing, the orbital drop mechanic, Intel Desk readouts, a `SettingsManager` and the first main menu — and on 29 June the first web export, the point the game became something playable outside the editor. The tutorial system started the next day.

The two-and-a-half week July break falls in the middle of this block and isn't counted toward the four weeks. Work resumed on 22 July with a broad mission overhaul, a rebuilt Vox-Caster, and the tutorial extended from one console to nearly all of them.

## Weeks 13–16 · 31/07 → 25/08 — Guides, polish, and a full review

The final stretch, and the most varied. It opened with the entire Guide and briefing system — `GuideOverlay`, `MissionBriefingOverlay`, `GuideManager`, `BriefingHexPreview` — built in a single pass on 31 July, finished a few days later, and followed by reinforcement logic and a squad-pathing bug traced across six scripts. Missions 4 and 5 were then substantially rebuilt.

Presentation took over from there: ambient audio and an `AudioManager`, a new Command Centre room, a Holomap 3.0 and Command Throne 3.0, and on 20 August a large UI day covering the manual reference images, the main menu, an icon set and the procedural space sky.

From 21 August the work was done alongside Claude and changed character again. The epilogue was built and then rebuilt from 3D into a flat 2D finale. A full review of all 11,000 lines on 23 August turned up nine real defects, including an unusable main menu and a campaign inheriting its previous run's casualties. The last days added the Mission 5 extraction fix, the orbital laser and the supply drop pods.
