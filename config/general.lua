local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")


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
                name = "Event Triggers",
                order = 2,
            },
            eventTriggers = {
                type = "group",
                name = "Choose when Workout Buddy Triggers An Actviity!",
                inline = true,
                order = 3,
                args = {
                    levelup = {
                        type = "toggle",
                        name = "Level Up",
                        desc = "Trigger a workout when you gain a level.",
                        order = 1,
                        get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.event_map.levelup or false end,
                        set = function(info, val) WorkoutBuddy.db.profile.event_map.levelup = val end,
                    },
                    xpbubble = {
                        type = "toggle",
                        name = "XP Bubble",
                        desc = "Trigger a workout for every filled XP bubble.",
                        order = 2,
                        get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.event_map.xpbubble or false end,
                        set = function(info, val) WorkoutBuddy.db.profile.event_map.xpbubble = val end,
                    },
                    zonechange_newarea = {
                        type = "toggle",
                        name = "New Zone Change",
                        desc = "Trigger a workout when you enter a new zone.",
                        order = 3,
                        get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.event_map.zonechange_newarea or false end,
                        set = function(info, val) WorkoutBuddy.db.profile.event_map.zonechange_newarea = val end,
                    },
                    zonechange_zone = {
                        type = "toggle",
                        name = "All Zone Change",
                        desc = "Trigger a workout when you enter any new zone.",
                        order = 4,
                        get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.event_map.zonechange_zone or false end,
                        set = function(info, val) WorkoutBuddy.db.profile.event_map.zonechange_zone = val end,
                    },
                    zonechange_indoors = {
                        type = "toggle",
                        name = "Indoors Change",
                        desc = "Trigger a workout when you enter buildings.",
                        order = 5,
                        get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.event_map.zonechange_indoors or false end,
                        set = function(info, val) WorkoutBuddy.db.profile.event_map.zonechange_indoors = val end,
                    },
                },
            },
            frameHeader = {
                type = "header",
                name = "Reminder Frame",
                order = 4,
            },
            frameOptions = {
                type = "group",
                name = "Frame Options",
                inline = true,
                order = 5,
                args = {
                    autocenter = {
                        type = "toggle",
                        name = "Auto center when off-screen",
                        order = 1,
                        get = function()
                            local opts = WorkoutBuddy.ReminderState.getProfileOpts()
                            return opts.autocenter ~= false
                        end,
                        set = function(info, val)
                            local opts = WorkoutBuddy.ReminderState.getProfileOpts()
                            opts.autocenter = val
                        end,
                    },
                    centerNow = {
                        type = "execute",
                        name = "Center Frame Now",
                        order = 2,
                        func = function()
                            if WorkoutBuddy.ReminderCore and WorkoutBuddy.ReminderCore.CenterFrame then
                                WorkoutBuddy.ReminderCore:CenterFrame(true)
                            end
                        end,
                    },
                },
            },
        },
    }
end
