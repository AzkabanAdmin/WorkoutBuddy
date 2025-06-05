# Workout Buddy

*Workout Buddy* is a World of Warcraft addon that reminds players to perform short exercises during gameplay. It uses the Ace3 framework for addon structure, configuration UI, and event handling.

---

## Overview

Workout Buddy helps players stay active by suggesting quick exercises at intervals triggered by in-game events. The codebase is modular, making it easy to extend and maintain.

---

## Main Components

### `WorkoutBuddy.lua`
- Registers the addon with AceAddon.
- Initializes the saved database (`WorkoutBuddyDB`) and debug printing.
- Registers slash commands.
- `/wob center` can be used to reset the reminder frame to the middle of the screen.
- Sets up default workouts on first launch.
- Initializes the minimap button, configuration UI, and the reminder system.

### `events.lua`
- Handles core WoW events such as leveling up or changing zones.
- Triggers workout suggestions via `WorkoutBuddy:SuggestWorkout` based on player settings.
- Tracks XP bubbles to trigger reminders.

### `reminder_frame/`
Contains several modules:
- *reminder_core.lua*: Creates/updates the reminder frame, manages the exercise queue, and handles user interactions (complete, dismiss, partial).
- *reminder_queue.lua*: Manages the list of pending workouts (add, subtract, remove).
- *reminder_state.lua*: Stores frame settings and the queue in saved variables.
- *reminder_events.lua*: Decides when to show the reminder frame based on various gameplay events (e.g., taxi rides, quests).

---

## Configuration System

- *config.lua*: Builds the AceConfig options tree and registers it with WoW’s interface options.
- *Tab modules in `config/`:*
    - *general.lua*: Toggle which events trigger workouts.
    - *workouts.lua*: View, add, or remove workouts; quick-add from a predefined library.
    - *importexport.lua*: Export or import your workout list with serialized strings. Includes `SerializeWorkouts` and `DeserializeWorkouts` helpers.

---

## Minimap Button

- *minimap_button.lua*: Implements a LibDataBroker launcher that toggles the reminder frame or opens settings from the minimap.
- Pulses to indicate pending workouts.

---

## Workout Library

- *config/workout_library.lua*: Curated list of example exercises, categorized by type. Used for quick-add functionality.

---

## Addon Manifest

- *WorkoutBuddy.toc*: Lists files in load order and declares the saved variable `WorkoutBuddyDB`.

---

## Important Concepts

- **Global Table:** Exposes the `WorkoutBuddy` table globally for submodules to attach functionality.
- **Saved Variables:** User preferences and workout lists are stored in `WorkoutBuddyDB` (via AceDB), with profile support.
- **Reminder Queue:** Workouts accumulate in a queue. The reminder frame shows the queue and allows marking workouts as complete, partially complete, or dismissed.
- **Event-Driven:** Game events (e.g., `PLAYER_LEVEL_UP`, zone changes) and custom events in `reminder_events.lua` trigger suggestions and reminder displays.

---

## Learning More

- **Ace3 Framework:**  
  See the [Ace3 documentation](https://www.wowace.com/projects/ace3), especially AceAddon, AceDB, and AceConfig.

- **WoW Widget API:**  
  Check out [WoW Widget API](https://wowpedia.fandom.com/wiki/Widget_API) for frame creation and UI scripting, as used in `reminder_core.lua`.

- **SavedVariables & Profiles:**  
  Study how `LibStub("AceDB-3.0")` manages persistent data. The defaults table in `WorkoutBuddy.lua` shows the initial setup.

- **Addon Packaging:**  
  Review `WorkoutBuddy.toc` for load order and library embedding. For development, copy the addon directory to your `World of Warcraft/Interface/AddOns/` folder.

---

## Adding Events or Workouts

- **To add new triggers:**
  Modify `events.lua` or `reminder_events.lua`.

### Custom Events

Use the **Add Activity Event** or **Add Auto-Open Event** buttons at the bottom of the General tab to create advanced triggers and conditions.
This opens the **Custom Events** window where you can add one or more triggers, name the event, and define the action. Press *Okay* to save.
Each custom event appears in the checkbox list with a small pencil icon for editing and an "X" icon for deletion.
Conditions can combine triggers using `AND`/`OR` logic and either suggest a workout or open the reminder frame.

- **To extend the default workout library:**  
  Edit `config/workout_library.lua` and ensure the configuration UI can reference new categories.

---

## Contribution Guide

The codebase maintains a clear separation between gameplay event handling, configuration, and the reminder display.

**New contributors:**  
- Start with `WorkoutBuddy.lua` to see module initialization.
- Explore related files as needed for deeper understanding.

---

*Happy adventuring—and don’t forget to stretch!*
