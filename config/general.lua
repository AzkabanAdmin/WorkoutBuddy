local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Helper used by both the Automation tab and this General tab
local function WorkoutBuddy_AutomationGroup(order, name, path)
    local group = WorkoutBuddy_TriggersTab()
    group.order = order or group.order
    if name then group.name = name end
    local rebuildPath = path or {"triggers"}
    group.args.addTrigger.func = function()
        local t = WorkoutBuddy.db.profile.triggers
        t[#t+1] = { name="New Trigger", event="PLAYER_LEVEL_UP", customEvent="" }
        WorkoutBuddy:RebuildTriggerOptions(group.args.triggerList.args, rebuildPath)
        local condPath = {unpack(rebuildPath)}
        table.insert(condPath, "conditionList")
        WorkoutBuddy:RebuildConditionOptions(group.args.conditionList.args, condPath)
        AceConfigDialog:SelectGroup("WorkoutBuddy", unpack(rebuildPath))
        WorkoutBuddy.TriggerManager:RegisterEvents()
    end
    group.args.addCondition.func = function()
        local c = WorkoutBuddy.db.profile.conditions
        c[#c+1] = { name="New Condition", logic="AND", triggers={}, activity="", action="workout" }
        local condPath = {unpack(rebuildPath)}
        table.insert(condPath, "conditionList")
        WorkoutBuddy:RebuildConditionOptions(group.args.conditionList.args, condPath)
        AceConfigDialog:SelectGroup("WorkoutBuddy", unpack(condPath))
    end
    return group
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
                    taxi = {
                        type = "toggle",
                        name = "On Flight Path",
                        desc = "Show the reminder frame while on a taxi if workouts are queued.",
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
                    },
                    rested = {
                        type = "toggle",
                        name = "When Rested",
                        desc = "Show the reminder frame when becoming rested and workouts are queued.",
                        order = 2,
                        get = function()
                            return WorkoutBuddy.db and WorkoutBuddy.db.profile.reminder_events and WorkoutBuddy.db.profile.reminder_events.rested or false
                        end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.reminder_events.rested = val
                            if WorkoutBuddy.ReminderEvents and WorkoutBuddy.ReminderEvents.Register then
                                WorkoutBuddy.ReminderEvents:Register()
                            end
                        end,
                    },
                    quest = {
                        type = "toggle",
                        name = "Quest Turn-in",
                        desc = "Show the reminder frame after turning in a quest if workouts are queued.",
                        order = 3,
                        get = function()
                            return WorkoutBuddy.db and WorkoutBuddy.db.profile.reminder_events and WorkoutBuddy.db.profile.reminder_events.quest or false
                        end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.reminder_events.quest = val
                            if WorkoutBuddy.ReminderEvents and WorkoutBuddy.ReminderEvents.Register then
                                WorkoutBuddy.ReminderEvents:Register()
                            end
                        end,
                    },
                },
            },
            automationHeader = {
                type = "header",
                name = "Custom Automation",
                order = 8,
            },
            automation = WorkoutBuddy_AutomationGroup(9, "Automation", {"general", "automation"}),
        },
    }
end
