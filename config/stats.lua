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
                    week = "This Week",
                    month = "This Month",
                },
                get = function()
                    return WorkoutBuddy._statsTimeframe or "lifetime"
                end,
                set = function(info, val)
                    WorkoutBuddy._statsTimeframe = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("WorkoutBuddy")
                end,
            },
            summary = {
                type = "description",
                name = function()
                    local tf = WorkoutBuddy._statsTimeframe or "lifetime"
                    if WorkoutBuddy.Stats and WorkoutBuddy.Stats.GetSummary then
                        return WorkoutBuddy.Stats:GetSummary(tf)
                    end
                    return "No data"
                end,
                order = 2,
            },
        },
    }
end
