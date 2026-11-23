# Workout Buddy: notes for contributors and coding assistants

Workout Buddy is a World of Warcraft addon built on a few Ace3 modules (addon, events, saved variables) with its own settings UI in `ui/`. One package supports WoW Forever (interface 16001), Midnight / Retail (120105, 120107) and Classic Era (11509). See `README.md` for features, layout and the release steps.

## Getting started on a new machine

1. Clone the repo. The folder name must be `WorkoutBuddy` when it is copied or linked into a game's `Interface\AddOns` folder.
2. Install Node.js, then run the offline tests:
   ```
   cd tests
   npm install
   npm test
   ```
3. Optional: in VS Code, install the recommended extensions (`.vscode/extensions.json`) for WoW API completion.

To try the addon in game, link the repo into the AddOns folder (Windows example, run in an elevated prompt):
```
mklink /J "<WoW folder>\_forever_\Interface\AddOns\WorkoutBuddy" "<path to this repo>"
```
Running unpackaged shows version "dev" because the TOC holds `@project-version@`, which the packager replaces with the tag name.

## Rules that keep it working on every client

- **Events:** only register events through `WorkoutBuddy.SafeRegisterEvent` or after `WorkoutBuddy.IsEventValid`. Each client has a different event set and registering an unknown event raises an error that can stop the addon loading. AceEvent's `RegisterEvent` errors too, so check validity first (see `RegisterBuiltInEvents` in `events.lua`).
- **Game content:** an event existing is not enough. Forever runs on the modern engine, so modern event names (keystones, for example) exist there without the content. Gate content-based options with `WorkoutBuddy.HasContent(feature)` / `IsEventUseful(event)` and keep `GAME_CONTENT` and `EVENT_CONTENT` in `WorkoutBuddy.lua` current: research each client yourself (warcraft.wiki.gg, the client's data, other addons in the AddOns folders) instead of asking Tim, and prefer a live probe over a hard-coded entry. Known 2026-11-22: Forever has achievements, dungeon finder and battleground queues, no Mythic+.
- **Secret values:** Forever and Midnight can return secret values from unit APIs such as `UnitHealth`. Check with `WorkoutBuddy.IsSecret` before comparing or doing math.
- **Lua 5.1:** WoW runs Lua 5.1. Use `loadstring` (not `load`) to compile strings. No `goto`, `//`, bitwise operators or `_ENV`.
- **APIs:** prefer namespaced APIs (`C_AddOns`, `C_Timer`, `C_EventUtils`) with fallbacks.
- **Custom triggers** are dispatched only from `trigger_manager.lua`. Do not call `TriggerManager:HandleEvent` from other handlers, or triggers fire twice.
- **Saved variables:** AceDB copies defaults in once at load. Setting a key to `nil` later does not restore its default; assign the default explicitly. Add upgrades for older saved data to `WorkoutBuddy:MigrateProfile`.
- **Imports never run code.** Workout lists use the parser in `sharing.lua`; profiles use AceSerializer, and imported Lua conditions stay disabled until reviewed.
- **UI frames** are created once and reused (see the row pool in `reminder_frame/reminder_core.lua`).
- **No overlapping controls, ever.** The test mock resolves anchors and sizes (text at about 6.5 px per character), and `npm test` fails if any two visible controls overlap on any settings page or trigger form state (`UI.FindOverlaps`), or if a visible container has no size (`UI.FindZeroSize`; the game may not draw what is inside a frame without a height), or if text spills out of its row (`UI.FindOverflow`; always `SetWidth` before measuring text with `GetStringHeight`, the game measures anchor-only text as one line). Mock frames start at 0x0 like the game. In game, `/wob uicheck` runs both checks on the real window. Give every control a fixed width, give text an explicit width or wrap, and chain rows of buttons with one anchor each. When adding a page or form state, add it to the overlap tests.
- **Settings window:** pages are lists of specs in `ui/page_*.lua` and `ui/pages.lua`; `ui/window.lua` builds each row once and re-lays it out. Every spec with a label (or a `search` field) is found by the search. Keep logic out of the UI: trigger rules live in `trigger_list.lua`, imports in `sharing.lua`. Colors come from `UI.THEMES`; paint with `UI.Tex`/`UI.Text` roles so theme changes repaint.

## Libraries

Bundled in `Libs/` (not fetched at package time): Ace3 modules AceAddon, AceConsole, AceEvent, AceDB and AceSerializer with LibStub and CallbackHandler (from WoWUIDev/Ace3), LibDBIcon-1.0 and LibDataBroker-1.1, LibSharedMedia-3.0 (from the WowAce repositories). When updating them, keep only the modules the TOC loads and run the tests.

## Before committing

- Run `npm test` in `tests`.
- Add user-facing changes to `CHANGELOG.md` (it becomes the CurseForge changelog).
- After a game patch, update the `## Interface` line in `WorkoutBuddy.toc`. Check a client's value in game with `/dump select(4, GetBuildInfo())`.

## Status

- **Released:** 2.2.2 (tag pushed 2026-11-22): window footer and height fix, page screenshots. First release meant for the public page.
- **Previous:** 2.2.1 (`/wob demo`), 2.2.0 (quiet hours; tested in game by Tim), 2.1.0.
- **Unreleased (committed locally, not pushed):** 2.3.0: new settings window (own UI kit, side navigation, search, themes), set workouts per action, the "I use an item or spell" trigger (`ITEM_USED`), and the boss fight and instance recap. Item triggers requested by a user (ordsneakysneaky, 2026-10-09). Tim is testing it in game through the dev link (CurseForge copy backed up at `_forever_\Interface\WorkoutBuddy-curseforge-backup`; restore it after release).
- **Tests:** 279 passing (`npm test` in `tests`).
- **Release rule:** only push to `main` together with a release tag, so stray untagged pushes do not create alpha builds on CurseForge.

## Open work

- **CurseForge page (Tim, by hand):** the gallery images and the description are uploaded on CurseForge by hand; there is no API for gallery images (checked 2026-11-22). The description loads images from GitHub, so replacing a file in `media/` updates the page. 2.3.0 media (settings window) is in `media/` with names the description uses; re-paste `media/curseforge-description.md` and replace the gallery when 2.3.0 is released.
- **Updating media:** Tim takes shots with `/wob demo` on and drops them in `media/_incoming` (git-ignored). Claude views them, then `python scripts/media.py crop` / `gif` (use `--scale 2` for the small in-game window at 1080p) into `media/` under the names the description uses.
- **Promotion ideas (Tim's call):** Wago Addons and WoWInterface listings, one post each in r/WowUI and the WoWUIDev Discord, fitness-minded streamers, and a small update around New Year.

- **In-game check of 2.3.0:** potions and healthstones counted through `UNIT_SPELLCAST_SUCCEEDED` on each client, especially whether Midnight hides the spell ID during encounters (the trigger then skips, by design), and the recap after a real boss fight.
- In-game check of quiet hours on each client, especially the realm clock (`C_DateAndTime.GetCurrentCalendarTime`, falling back to `GetGameTime`) on Classic Era and Forever.
- Ideas not started: a "snooze for 1 hour" button, and quiet hours that follow instance or combat state instead of the clock.

## Change log

- 2026-11-22: 2.3.0 built: set workouts per action, item and spell triggers, boss fight and instance recap.
- 2026-11-22: 2.2.2 with CurseForge screenshots and GIF; footer and window height fix.
- 2026-11-22: `/wob demo` screenshot mode, `scripts/media.py`, CurseForge description in `media/`.
- 2026-11-22: Review on a second machine; quiet hours feature; fixes for partial logging, target health triggers, mixed water units, nested profile import checks, imported trigger safety and Reset size. Removed merged `codex/*` branches.
- 2026-11-22: 2.1.0 released (WoW Forever support, packaging, tests).

## Releasing

Push to `main`, then push a tag (`2.1.1`, `2.1.1-beta1`, `2.1.1-alpha1`). CurseForge's automatic packager builds the file from the tag using `.pkgmeta`. To build a zip locally instead, run `python scripts/build_zip.py 2.1.1`.
