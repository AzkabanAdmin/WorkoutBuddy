local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function WorkoutBuddy_StatsTab()
    return {
        type = "group",
        name = "Stats",
        order = 4,
        args = {
            timeframe = {
                type = "select",
                name = "Time Frame",
                order = 1,
                values = {
                    lifetime = "Lifetime",
                    day = "Today",
                    week = "This Week",
                    month = "This Month",
                    custom = "Custom",
                },
                get = function()
                    return WorkoutBuddy._statsTimeframe or "lifetime"
                end,
                set = function(info, val)
                    WorkoutBuddy._statsTimeframe = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WorkoutBuddy")
                end,
            },
            customInput = {
                type = "input",
                name = "Custom Range",
                desc = "Enter ranges like '5days', '2weeks', '3hours' or '10minutes'",
                order = 2,
                hidden = function()
                    return (WorkoutBuddy._statsTimeframe or "lifetime") ~= "custom"
                end,
                get = function()
                    return WorkoutBuddy._statsCustomInput or ""
                end,
                set = function(info, val)
                    WorkoutBuddy._statsCustomInput = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WorkoutBuddy")
                end,
            },
            summary = {
                type = "description",
                name = function()
                    local tf = WorkoutBuddy._statsTimeframe or "lifetime"
                    if tf == "custom" then
                        tf = WorkoutBuddy._statsCustomInput or "lifetime"
                    end
                    if WorkoutBuddy.Stats and WorkoutBuddy.Stats.GetSummary then
                        return WorkoutBuddy.Stats:GetSummary(tf)
                    end
                    return "No data"
                end,
                order = 3,
            },
        },
    }
end
