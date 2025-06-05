local _, WorkoutBuddy = ...
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function restartTimer()
    if WorkoutBuddy.db and WorkoutBuddy.db.profile
        and WorkoutBuddy.db.profile.hydration
        and WorkoutBuddy.db.profile.hydration.enabled then
        WorkoutBuddy.Hydration:Start()
    end
end

function WorkoutBuddy_HydrationTab()
    return {
        type = "group",
        name = "Hydration",
        order = 5,
        args = {
            enable = {
                type = "toggle",
                name = "Enable Hydration Reminders",
                order = 1,
                get = function() return WorkoutBuddy.db and WorkoutBuddy.db.profile.hydration and WorkoutBuddy.db.profile.hydration.enabled end,
                set = function(info, val)
                    WorkoutBuddy.db.profile.hydration.enabled = val
                    if val then
                        WorkoutBuddy.Hydration:Start()
                    else
                        WorkoutBuddy.Hydration:Stop()
                    end
                end,
            },
            mode = {
                type = "select",
                name = "Reminder Mode",
                desc = "Choose scheduling method",
                order = 2,
                values = { smart = "Goal Based", interval = "Simple Interval" },
                get = function() return WorkoutBuddy.db.profile.hydration.mode or "smart" end,
                set = function(info, val)
                    WorkoutBuddy.db.profile.hydration.mode = val
                    restartTimer()
                end,
            },
            smartGroup = {
                type = "group",
                name = "Goal Based",
                inline = true,
                order = 3,
                hidden = function() return (WorkoutBuddy.db.profile.hydration.mode or "smart") ~= "smart" end,
                args = {
                    total = {
                        type = "input",
                        name = "Total Ounces",
                        desc = "Total amount to drink over the timeframe",
                        order = 1,
                        get = function() return tostring((WorkoutBuddy.db.profile.hydration.total or 32)) end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.hydration.total = tonumber(val) or WorkoutBuddy.db.profile.hydration.total
                            restartTimer()
                        end,
                    },
                    timeframe = {
                        type = "input",
                        name = "Timeframe (minutes)",
                        order = 2,
                        get = function() return tostring((WorkoutBuddy.db.profile.hydration.timeframe or 120)) end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.hydration.timeframe = tonumber(val) or WorkoutBuddy.db.profile.hydration.timeframe
                            restartTimer()
                        end,
                    },
                    per = {
                        type = "input",
                        name = "Ounces per Reminder",
                        order = 3,
                        get = function() return tostring((WorkoutBuddy.db.profile.hydration.per or 8)) end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.hydration.per = tonumber(val) or WorkoutBuddy.db.profile.hydration.per
                            restartTimer()
                        end,
                    },
                },
            },
            intervalGroup = {
                type = "group",
                name = "Simple Interval",
                inline = true,
                order = 3,
                hidden = function() return (WorkoutBuddy.db.profile.hydration.mode or "smart") ~= "interval" end,
                args = {
                    interval = {
                        type = "input",
                        name = "Reminder Every (minutes)",
                        order = 1,
                        get = function() return tostring((WorkoutBuddy.db.profile.hydration.interval or 60)) end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.hydration.interval = tonumber(val) or WorkoutBuddy.db.profile.hydration.interval
                            restartTimer()
                        end,
                    },
                },
            },
            sound = {
                type = "select",
                name = "Sound",
                order = 4,
                values = function()
                    return WorkoutBuddy.Sounds:GetList()
                end,
                get = function() return WorkoutBuddy.db.profile.hydration.sound or "Alarm Clock" end,
                set = function(info, val)
                    WorkoutBuddy.db.profile.hydration.sound = val
                    restartTimer()
                end,
            },
            testSound = {
                type = "execute",
                name = "Test Sound",
                order = 5,
                func = function() WorkoutBuddy.Hydration:PlaySelectedSound() end,
            },
            test = {
                type = "execute",
                name = "Test Popup",
                order = 6,
                func = function() WorkoutBuddy.Hydration:ShowPopup(true) end,
            },
        },
    }
end

