Overview

This repository contains a World of Warcraft addon called Workout Buddy. The addon reminds players to perform short exercises during gameplay. It uses the Ace3 framework for addon structure, configuration UI, and event handling.

Main Components

WorkoutBuddy.lua

The main addon file registers the addon using AceAddon, sets up a debug printing function, initializes the saved database (WorkoutBuddyDB), and registers slash commands. Default workouts are created on first launch. It also initializes the minimap button, configuration UI, and the reminder system.

events.lua

Handles core WoW events such as leveling up or changing zones. Each event checks the player’s settings and may trigger a workout suggestion via WorkoutBuddy:SuggestWorkout. It also tracks XP bubbles to trigger reminders.

reminder_frame/

Contains several modules:

reminder_core.lua – creates and updates the reminder frame, manages the queue of exercises, and provides user interactions (complete/dismiss/partial).

reminder_queue.lua – manages the list of pending workouts (add, subtract, remove).

reminder_state.lua – stores frame settings and the queue in the saved variables.

reminder_events.lua – decides when to show the reminder frame based on various gameplay events (e.g., taxi rides or quests).

Config System

config.lua builds the AceConfig options tree and registers it with the game’s interface options. It links to tab modules under config/ such as:

general.lua – toggles to choose which events trigger workouts.

workouts.lua – interface for viewing, adding, or removing workouts and quick-adding from a predefined library.

importexport.lua – lets users export or import their workout list using serialized strings. It provides helper functions SerializeWorkouts and DeserializeWorkouts.

Minimap Button

minimap_button.lua creates a LibDataBroker launcher that toggles the reminder frame or opens the settings from the minimap. It also pulses to indicate pending workouts.

Workout Library

config/workout_library.lua defines a curated list of example exercises categorized by type. This library is used for quick-add functionality.

Addon Manifest

WorkoutBuddy.toc lists files in the order the game loads them and declares the saved variable WorkoutBuddyDB.

Important Concepts

Global Table: The addon exposes WorkoutBuddy globally so submodules can attach functionality.

Saved Variables: User preferences and workout lists are stored in WorkoutBuddyDB using AceDB. Profiles support is handled automatically.

Reminder Queue: Workouts accumulate in a queue. The reminder frame shows the queue with options to mark workouts complete, partially complete, or dismiss.

Event-driven: Both game events (PLAYER_LEVEL_UP, zone changes, etc.) and custom events in reminder_events.lua trigger the suggestion system and the reminder display.

Pointers for Learning More

Ace3 Framework
Explore the Ace3 documentation, especially AceAddon, AceDB, and AceConfig, since much of the addon relies on these libraries.

WoW Widget API
Review Blizzard’s frame widget APIs to understand frame creation and user interactions found in reminder_core.lua.

SavedVariables & Profiles
Look into how LibStub("AceDB-3.0") manages persistent data. The defaults table in WorkoutBuddy.lua shows the initial profile setup.

Addon Packaging
Study WorkoutBuddy.toc to see how files are loaded and how libraries are embedded. For development, the addon directory must be copied to World of Warcraft’s Interface/AddOns folder.

Adding Events or Workouts

To add new triggers, modify events.lua or reminder_events.lua.

To extend the default workout library, edit config/workout_library.lua and ensure the configuration UI can reference new categories.

This structure provides a clean separation between gameplay event handling, user interface configuration, and the reminder display system. New contributors should start by reading WorkoutBuddy.lua and follow how it initializes these modules, then explore individual files as needed.