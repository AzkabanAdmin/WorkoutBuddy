local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")


function WorkoutBuddy_ImportExportTab()
    return {
        type = "group",
        name = "Import/Export",
        order = 6,
        args = {
            importExportHeader = {
                type = "header",
                name = "Import/Export Workouts",
                order = 1,
            },
            exportBox = {
                type = "input",
                name = "Export Workouts",
                desc = "Copy this string to save/share your workouts.",
                width = "full",
                multiline = 3,
                order = 2,
                get = function() return WorkoutBuddy:SerializeWorkouts() end,
                set = function() end,
            },
            importBox = {
                type = "input",
                name = "Import Workouts",
                desc = "Paste here to import (overwrites your workouts!).",
                width = "full",
                multiline = 3,
                order = 3,
                get = function() return WorkoutBuddy._importBox or "" end,
                set = function(info, val) WorkoutBuddy._importBox = val end,
            },
            importButton = {
                type = "execute",
                name = "Import",
                desc = "Click to import workouts from above.",
                order = 4,
                confirm = true,
                confirmText = "This will overwrite your current workouts! Continue?",
                func = function()
                    if WorkoutBuddy._importBox and WorkoutBuddy._importBox ~= "" then
                        WorkoutBuddy:DeserializeWorkouts(WorkoutBuddy._importBox)
                        WorkoutBuddy._importBox = ""
                        WorkoutBuddy:RebuildWorkoutListOptions()
                        AceConfigDialog:SelectGroup("WorkoutBuddy", "workouts")
                        print("WorkoutBuddy: Workouts imported!")
                    end
                end,
            },
        }
    }
end

function WorkoutBuddy:SerializeWorkouts()
    local t = self.db.profile.workouts or {}
    local items = {}
    for _, w in ipairs(t) do
        table.insert(items, string.format("{name=%q,amount=%d,unit=%q}", w.name or "", w.amount or 0, w.unit or ""))
    end
    return "{" .. table.concat(items, ",") .. "}"
end

function WorkoutBuddy:DeserializeWorkouts(str)
    ---@diagnostic disable-next-line: deprecated
    local func, err = loadstring("return " .. str)
    if not func then
        print("WorkoutBuddy: Invalid import string!")
        return
    end
    local ok, tbl = pcall(func)
    if ok and type(tbl) == "table" then
        self.db.profile.workouts = tbl
        print("WorkoutBuddy: Import successful!")
    else
        print("WorkoutBuddy: Import failed!")
    end
end