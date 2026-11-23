# Workout Buddy: notes for contributors and coding assistants

Workout Buddy is an Ace3-based World of Warcraft addon. One package supports WoW Forever (interface 16001), Midnight / Retail (120105, 120107) and Classic Era (11509). See `README.md` for features, layout and the release steps.

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
- **Secret values:** Forever and Midnight can return secret values from unit APIs such as `UnitHealth`. Check with `WorkoutBuddy.IsSecret` before comparing or doing math.
- **Lua 5.1:** WoW runs Lua 5.1. Use `loadstring` (not `load`) to compile strings. No `goto`, `//`, bitwise operators or `_ENV`.
- **APIs:** prefer namespaced APIs (`C_AddOns`, `C_Timer`, `C_EventUtils`) with fallbacks.
- **Custom triggers** are dispatched only from `trigger_manager.lua`. Do not call `TriggerManager:HandleEvent` from other handlers, or triggers fire twice.
- **Saved variables:** AceDB copies defaults in once at load. Setting a key to `nil` later does not restore its default; assign the default explicitly. Add upgrades for older saved data to `WorkoutBuddy:MigrateProfile`.
- **Imports never run code.** Workout lists use the parser in `config/importexport.lua`; profiles use AceSerializer, and imported Lua conditions stay disabled until reviewed.
- **UI frames** are created once and reused (see the row pool in `reminder_frame/reminder_core.lua`).

## Libraries

Bundled in `Libs/` (not fetched at package time): Ace3 (from WoWUIDev/Ace3), LibDBIcon-1.0 and LibDataBroker-1.1, LibSharedMedia-3.0 (from the WowAce repositories). When updating them, keep only the modules the TOC loads and run the tests.

## Before committing

- Run `npm test` in `tests`.
- Add user-facing changes to `CHANGELOG.md` (it becomes the CurseForge changelog).
- After a game patch, update the `## Interface` line in `WorkoutBuddy.toc`. Check a client's value in game with `/dump select(4, GetBuildInfo())`.

## Status

- **Released:** 2.2.0 (tag pushed 2026-11-22): quiet hours and the review fixes listed in `CHANGELOG.md`. In-game testing pending.
- **Previous:** 2.1.0 (2026-11-22).
- **Unreleased on `main`:** 2.2.1, adds `/wob demo` screenshot mode.
- **Tests:** 146 passing (`npm test` in `tests`).

## Open work

- **CurseForge page media.** Tim takes the screenshots in game with `/wob demo` on; Claude runs `python scripts/media.py collect`, views each image, crops with `crop` and builds `goal.gif` with `gif`, saving into `media/` with the names `media/curseforge-description.md` uses (`goal.gif`, `queue.png`, `hydration.png`, `quiet-hours.png`, `stats.png`). Then commit and push. CurseForge has no API for gallery images (checked 2026-11-22), so Tim uploads the gallery images and pastes the description once by hand; after that, replacing a file in `media/` updates the page's images.

- In-game check of quiet hours on each client, especially the realm clock (`C_DateAndTime.GetCurrentCalendarTime`, falling back to `GetGameTime`) on Classic Era and Forever.
- Ideas not started: a "snooze for 1 hour" button, and quiet hours that follow instance or combat state instead of the clock.

## Change log

- 2026-11-22: `/wob demo` screenshot mode, `scripts/media.py`, CurseForge description in `media/`.
- 2026-11-22: Review on a second machine; quiet hours feature; fixes for partial logging, target health triggers, mixed water units, nested profile import checks, imported trigger safety and Reset size. Removed merged `codex/*` branches.
- 2026-11-22: 2.1.0 released (WoW Forever support, packaging, tests).

## Releasing

Push to `main`, then push a tag (`2.1.1`, `2.1.1-beta1`, `2.1.1-alpha1`). CurseForge's automatic packager builds the file from the tag using `.pkgmeta`. To build a zip locally instead, run `python scripts/build_zip.py 2.1.1`.
