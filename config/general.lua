local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Helper to create a small boxed container around an event option
local function EventBox(order, toggle)
    return {
        type = "group",
        inline = true,
        name = "",
        order = order,
        args = { toggle = toggle },
    }
end

function WorkoutBuddy_GeneralTab()
    return {
        type = "group",
        name = "General",
        order = 1,
        args = {
            description = {
                type = "description",
                name = "Welcome to Workout Buddy! Take fitness breaks while you play.",
                order = 1,
            },
            eventTriggersHeader = {
                type = "header",
                name = "Workout Event Triggers",
                order = 2,
            },
            eventTriggers = {
                type = "group",
                name = "Choose when Workout Buddy Triggers An Actviity!",
                inline = true,
                order = 3,
                args = {
                    levelup = EventBox(1, {
                        type = "toggle",
                        name = "Level Up",
                        desc = "Trigger a workout when you gain a level.",
                        width = "full",
                        order = 1,
                        get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.event_map.levelup or false end,
                        set = function(info, val) WorkoutBuddy.db.profile.event_map.levelup = val end,
                    }),
                    xpbubble = EventBox(2, {
                        type = "toggle",
                        name = "XP Bubble",
                        desc = "Trigger a workout for every filled XP bubble.",
                        width = "full",
                        order = 1,
                        get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.event_map.xpbubble or false end,
                        set = function(info, val) WorkoutBuddy.db.profile.event_map.xpbubble = val end,
                    }),
                    zonechange_newarea = EventBox(3, {
                        type = "toggle",
                        name = "New Zone Change",
                        desc = "Trigger a workout when you enter a new zone.",
                        width = "full",
                        order = 1,
                        get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.event_map.zonechange_newarea or false end,
                        set = function(info, val) WorkoutBuddy.db.profile.event_map.zonechange_newarea = val end,
                    }),
                    zonechange_zone = EventBox(4, {
                        type = "toggle",
                        name = "All Zone Change",
                        desc = "Trigger a workout when you enter any new zone.",
                        width = "full",
                        order = 1,
                        get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.event_map.zonechange_zone or false end,
                        set = function(info, val) WorkoutBuddy.db.profile.event_map.zonechange_zone = val end,
                    }),
                    zonechange_indoors = EventBox(5, {
                        type = "toggle",
                        name = "Indoors Change",
                        desc = "Trigger a workout when you enter buildings.",
                        width = "full",
                        order = 1,
                        get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.event_map.zonechange_indoors or false end,
                        set = function(info, val) WorkoutBuddy.db.profile.event_map.zonechange_indoors = val end,
                    }),
                    -- custom triggers inserted dynamically
                },
            },
            addCustom = {
                type = "execute",
                name = "Add Activity Event",
                width = "full",
                order = 3.5,
                func = function() WorkoutBuddy:OpenTriggerEditor("workout") end,
            },
            openEventsHeader = {
                type = "header",
                name = "Auto-Open Events",
                order = 6,
            },
            openEvents = {
                type = "group",
                name = "Open Reminder Frame Automatically",
                inline = true,
                order = 7,
                args = {
                    taxi = EventBox(1, {
                        type = "toggle",
                        name = "On Flight Path",
                        desc = "Show the reminder frame while on a taxi if workouts are queued.",
                        width = "full",
                        order = 1,
                        get = function()
                            return WorkoutBuddy.db and WorkoutBuddy.db.profile.reminder_events and WorkoutBuddy.db.profile.reminder_events.taxi or false
                        end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.reminder_events.taxi = val
                            if WorkoutBuddy.ReminderEvents and WorkoutBuddy.ReminderEvents.Register then
                                WorkoutBuddy.ReminderEvents:Register()
                            end
                        end,
                    }),
                    rested = EventBox(2, {
                        type = "toggle",
                        name = "When Rested",
                        desc = "Show the reminder frame when becoming rested and workouts are queued.",
                        width = "full",
                        order = 1,
                        get = function()
                            return WorkoutBuddy.db and WorkoutBuddy.db.profile.reminder_events and WorkoutBuddy.db.profile.reminder_events.rested or false
                        end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.reminder_events.rested = val
                            if WorkoutBuddy.ReminderEvents and WorkoutBuddy.ReminderEvents.Register then
                                WorkoutBuddy.ReminderEvents:Register()
                            end
                        end,
                    }),
                    quest = EventBox(3, {
                        type = "toggle",
                        name = "Quest Turn-in",
                        desc = "Show the reminder frame after turning in a quest if workouts are queued.",
                        width = "full",
                        order = 1,
                        get = function()
                            return WorkoutBuddy.db and WorkoutBuddy.db.profile.reminder_events and WorkoutBuddy.db.profile.reminder_events.quest or false
                        end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.reminder_events.quest = val
                            if WorkoutBuddy.ReminderEvents and WorkoutBuddy.ReminderEvents.Register then
                                WorkoutBuddy.ReminderEvents:Register()
                            end
                        end,
                    }),
                    -- custom open triggers inserted dynamically
                },
            },
            openEmpty = {
                type = "toggle",
                name = "Open When No Activities",
                desc = "Also show the reminder frame when the queue is empty.",
                width = "full",
                order = 6.1,
                get = function()
                    return WorkoutBuddy.db and WorkoutBuddy.db.profile.reminder_events and WorkoutBuddy.db.profile.reminder_events.open_empty or false
                end,
                set = function(info, val)
                    WorkoutBuddy.db.profile.reminder_events.open_empty = val
                    if WorkoutBuddy.ReminderEvents and WorkoutBuddy.ReminderEvents.Register then
                        WorkoutBuddy.ReminderEvents:Register()
                    end
                end,
            },
            addCustomOpen = {
                type = "execute",
                name = "Add Auto-Open Event",
                width = "full",
                order = 7.5,
                func = function() WorkoutBuddy:OpenTriggerEditor("open_frame") end,
            },
            -- custom events toggles are injected dynamically
        },
    }
end
