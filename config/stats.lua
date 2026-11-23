-- config/stats.lua
-- Stats tab.

local _, WorkoutBuddy = ...
WorkoutBuddy.ConfigTabs = WorkoutBuddy.ConfigTabs or {}

local view = { timeframe = "week", custom = "" }

function WorkoutBuddy.ConfigTabs.Stats()
    return {
        type = "group",
        name = "Stats",
        order = 5,
        args = {
            today = {
                type = "description",
                name = function() return "|cFF66FF66" .. WorkoutBuddy.Stats:GetTodayLine() .. "|r\n" end,
                fontSize = "medium",
                order = 1,
            },
            goal = {
                type = "range",
                name = "Daily goal (workouts)",
                desc = "How many workouts you aim to complete each day. 0 turns the goal off.",
                min = 0, max = 50, step = 1,
                order = 2,
                get = function() return WorkoutBuddy.db.profile.daily_goal or 0 end,
                set = function(_, val)
                    WorkoutBuddy.db.profile.daily_goal = val
                    WorkoutBuddy.ReminderCore:UpdateDisplay()
                end,
            },
            historyHeader = { type = "header", name = "History", order = 10 },
            timeframe = {
                type = "select",
                name = "Show",
                order = 11,
                values = {
                    day = "Today",
                    week = "This week",
                    month = "This month",
                    lifetime = "All time",
                    custom = "Custom range",
                },
                sorting = { "day", "week", "month", "lifetime", "custom" },
                get = function() return view.timeframe end,
                set = function(_, val) view.timeframe = val end,
            },
            customInput = {
                type = "input",
                name = "Custom range",
                desc = "For example 3days, 2weeks, 12hours or 90minutes.",
                order = 12,
                hidden = function() return view.timeframe ~= "custom" end,
                get = function() return view.custom end,
                set = function(_, val) view.custom = val end,
            },
            summary = {
                type = "description",
                name = function()
                    local tf = view.timeframe
                    if tf == "custom" then
                        if strtrim(view.custom) == "" then return "Enter a range above." end
                        tf = view.custom
                    end
                    return WorkoutBuddy.Stats:GetSummary(tf)
                end,
                fontSize = "medium",
                order = 13,
            },
            resetHeader = { type = "header", name = "", order = 20 },
            reset = {
                type = "execute",
                name = "Reset stats",
                desc = "Delete all logged workouts and water for this profile.",
                order = 21,
                confirm = true,
                confirmText = "Delete all of this profile's workout and water history? This cannot be undone.",
                func = function()
                    WorkoutBuddy.Stats:Reset()
                    WorkoutBuddy.ReminderCore:UpdateDisplay()
                end,
            },
        },
    }
end
