# Workout Buddy

## 2.4.0

### New
- **Timer for timed workouts.** Workouts measured in seconds or minutes (Look Away From Screen, stretches, planks...) get a stopwatch button next to the check mark. It counts you in ("Get ready... 3, 2, 1"), times the workout with a big countdown and a progress bar, and plays a sound when the time is up. The workout is logged for you, or press Done to finish early. The check mark still works as before.
  - Settings under Workouts > Timed workouts: show the button, the get-ready countdown (0 to 10 seconds), the sound, and whether to log the workout automatically.
- **Stop water reminders for the day.** New Hydration setting: once you log a daily amount (for example 64 oz), reminders pause and start again tomorrow. The Hydration page shows how much you have had against it.
- **Show long workout names in full.** New option under Window & look: long names wrap onto up to three lines and the row grows to fit, instead of being shortened with "...".

## 2.3.0

### New
- **A new settings window.** Workout Buddy now has its own settings window instead of the standard options panel: pages on the left (Triggers, Workouts, Hydration, Quiet hours, Window & look, Stats, Profiles), a short description under every option, and everything scrolls.
  - **Search every setting** from the box at the top. Results show from every page, and clicking through jumps to the setting.
  - **One Triggers page.** Every trigger is one row with its on/off switch and what it gives (a random workout, a set workout and amount, or opening the window). Only the triggers you use are listed; "+ Add a trigger" walks you through when, details and what it gives.
  - **Themes:** Forest (default), Midnight, Ember, Violet and Classic gold, for the settings and the workout window.
  - The game's Options > AddOns entry has a button that opens it, and /wob still does.
- **Share your progress, only when you choose to.** The Stats page has a Share button (and `/wob share`) that posts one line to party, raid, guild or say: today's workouts, this week, or the last boss fight recap. Workout Buddy never posts anywhere on its own.
- **Type exact values.** Every slider has a number box next to it.
- **Background opacity** for the workout window and the hydration popup fades only the dark background, so you can keep the text and buttons solid. Overall opacity still fades everything.
- The hydration popup follows the theme.
- **Workout window options:** hide the title bar, hide the close button, and close the window automatically once every workout is done (all under Window & look; the last one is off by default).
- The "new workouts" chat option now says plainly that only you see those lines.
- **Options match your game.** Options for content a game does not have are hidden, for example Mythic+ keystones on WoW Forever and Classic Era. If a game adds that content later, the option appears by itself.
- **Set workouts per action.** Make something in the game always cost a specific workout, every time it happens. For example: each mana potion adds 3 push-ups and each death adds 5 burpees. Repeats add up in one row, so ten potions become Push-ups x30.
  - Custom triggers have a new action, "Add a set workout every time". These skip the minimum time between suggestions, so every occurrence counts.
  - Built-in events (You died, Boss defeated, Level up and the rest) can each have a set workout instead of a random one. Find it under Workouts > Set workouts for events.
- **"Count an item I use"** button in General. Adding an item is quick, with no item IDs or exact names needed:
  - pick it from a list of the usable items in your bags (with icons),
  - click "Use an item to add it" and just drink the potion or eat the food,
  - or start typing and pick from the suggestions. Shift-clicking or dragging an item into the box works too.
  - Presets count any potion, healthstone, food or drink, flask or elixir, or any consumable. Spells can be named too.
- **Boss fight and instance recap.** When a boss fight ends, and when you leave a dungeon or raid, chat shows what was added (for example "Boss fight recap: Push-ups x30 reps, Burpees x10 reps") and the workout window opens once you are out of combat. Workouts added during combat no longer announce one by one.

## 2.2.2

### Fixed
- The progress line at the bottom of the workout window no longer runs under the "Workout now" button. It now reads like "4 / 5 today, 7-day streak".
- The workout window is a little taller by default, so four workouts fit without the last one being cut off.

## 2.2.1

### New
- `/wob demo` fills the workout window, hydration popup and stats with sample data, for taking screenshots. Your real workouts and stats are untouched and come back when you run it again, reload or log out.

## 2.2.0

### New
- **Quiet hours.** Turn workouts and hydration reminders off, or down, at set times of day. For example: no workouts after 10 PM, but keep water reminders. Find it in the new Quiet Hours tab.
  - Workouts and hydration each have their own schedule, days of the week and behavior.
  - Workouts can be paused (skipped) or collected silently (queued with no chat line, sound or popup). The workout window never opens by itself during quiet hours.
  - Hydration reminders can be paused or shown without a sound.
  - Follow your computer's clock or the realm clock. Windows can run past midnight, and the same start and end time keeps a whole day quiet.
  - `/wob now` and `/wob water` always work. `/wob quiet` shows what is quiet right now, and the minimap tooltip shows it too.

### Fixed
- Logging part of a workout could record it against the wrong workout if a row above it was removed while the box was open.
- A health trigger on your target or focus now fires as soon as you pick a new target that is already below the threshold.
- Water totals no longer add ounces and milliliters together after switching units on the same day.
- Profile imports now check every setting's type, so a hand-edited profile cannot break the windows.
- An imported trigger with Lua code can no longer fire before it is reviewed.
- "Reset size" restores the window's default size.

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
