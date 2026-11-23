# Workout Buddy

## 2.1.0

### New
- **WoW Forever support.** Runs on WoW Forever (1.60.1), Midnight (Retail) and Classic Era from one download.
- **Play-time break timer.** Suggests a break after a set number of minutes of play (default 45). AFK time does not count.
- **Daily goal and streaks.** Track today's workouts against a goal and see how many days in a row you have been active. Progress shows in the workout window and minimap tooltip.
- **Water logging.** The hydration popup has "Drank it" and "Remind in 10m" buttons, and `/wob water` logs a drink. Choose ounces or milliliters.
- **Quest turned in** workout trigger.
- **Queue detection** now covers battleground queues as well as the dungeon finder.
- **"Workout now" button** and `/wob now` for an instant workout.
- Chat announcement and optional sound when a workout is added.
- Minimum time between suggestions, so busy events cannot flood the queue.
- Avoids suggesting the same workout twice in a row.
- Pause and resume with `/wob pause` and `/wob resume`, or the switch at the top of the settings.
- Window scale, opacity, lock and size settings. Size is remembered.
- Addon compartment entry, and an option to hide the minimap button.
- Custom triggers can use any event name and an optional Lua condition, and can be edited without changing them until you click Save.
- Expanded workout library (healthy habits, eye breaks, more strength and stretches) with "Add whole category".
- Stats show active days, activity totals sorted by frequency, and water, with a reset button.

### Fixed
- Custom Lua conditions never worked (they used `load`, which only accepts functions in WoW's Lua). They now compile correctly and errors are reported once.
- Custom triggers could fire twice for the same event.
- An event missing from the current game client could stop the addon from loading. Unsupported options are now hidden automatically.
- Health triggers added a workout on every health update while below the threshold; they now fire once when the condition becomes true, and ignore health that the game hides from addons.
- "Today", "This week" and "This month" stats used rolling windows and UTC; they now follow your local calendar.
- Hydration settings of 0 could create a runaway timer. Values are now validated, with a one-minute minimum.
- The workout window created new frames on every refresh. Rows are now reused.
- Moving the window after switching profiles saved the position to the old profile.
- The window no longer pops open in the middle of combat; it waits until combat ends.
- Logging in or passing a loading screen no longer reopens the window each time; only the first login does.
- Importing a workout list ran the pasted text as code. Imports are now parsed safely, and Lua conditions in imported profiles stay off until you review them.
- Importing a partial profile no longer leaves missing settings blank.
- A first-time hydration popup no longer appears when hydration reminders are off.

### Updated
- Ace3, LibDBIcon and LibSharedMedia updated to their latest versions, including their WoW Forever fixes.
- Bundled sounds can be picked from the sound lists ("WB: Bell", "WB: Chime" and more).
