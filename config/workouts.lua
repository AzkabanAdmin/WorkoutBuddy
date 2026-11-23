-- config/workouts.lua
-- Workouts tab: your list, adding custom workouts and the library.

local _, WorkoutBuddy = ...
WorkoutBuddy.ConfigTabs = WorkoutBuddy.ConfigTabs or {}

local draft = { name = "", amount = "10", unit = "reps" }
local library = { category = nil, pick = nil }

local function Workouts()
    return WorkoutBuddy.db.profile.workouts
end

local function HasWorkout(name, unit)
    for _, w in ipairs(Workouts()) do
        if w.name == name and (w.unit or "") == (unit or "") then return true end
    end
    return false
end

local function AddWorkout(name, amount, unit)
    if HasWorkout(name, unit) then return false end
    table.insert(Workouts(), { name = name, amount = tonumber(amount) or 1, unit = unit or "" })
    return true
end

local function Refresh()
    WorkoutBuddy:RebuildWorkoutListOptions()
    WorkoutBuddy:NotifyConfigChanged()
end

local function CurrentCategory()
    local cats = WorkoutBuddy.GetLibraryCategories()
    if not library.category then library.category = cats[1] end
    return library.category
end

local function LibraryItems()
    local items, order = {}, {}
    local cat = CurrentCategory()
    for i, w in ipairs(WorkoutBuddy.WorkoutLibrary) do
        if w.category == cat then
            local key = tostring(i)
            items[key] = string.format("%s (%s %s)", w.name, w.amount, w.unit or "")
            order[#order + 1] = key
        end
    end
    return items, order
end

function WorkoutBuddy.ConfigTabs.Workouts()
    return {
        type = "group",
        name = "Workouts",
        order = 2,
        args = {
            listHeader = { type = "header", name = "Your workouts", order = 1 },
            listDesc = {
                type = "description",
                name = "Workout Buddy picks one of these at random. Edit the name, amount and unit right here.",
                order = 1.5,
            },
            workoutList = {
                type = "group",
                name = "",
                inline = true,
                order = 2,
                args = {}, -- filled by RebuildWorkoutListOptions
            },

            addHeader = { type = "header", name = "Add your own", order = 10 },
            newName = {
                type = "input",
                name = "Workout",
                order = 11,
                width = 1.3,
                get = function() return draft.name end,
                set = function(_, val) draft.name = val end,
            },
            newAmount = {
                type = "input",
                name = "Amount",
                order = 12,
                width = 0.5,
                get = function() return draft.amount end,
                set = function(_, val) draft.amount = val end,
            },
            newUnit = {
                type = "input",
                name = "Unit",
                order = 13,
                width = 0.6,
                get = function() return draft.unit end,
                set = function(_, val) draft.unit = val end,
            },
            add = {
                type = "execute",
                name = "Add",
                order = 14,
                width = 0.5,
                disabled = function() return strtrim(draft.name or "") == "" end,
                func = function()
                    local name = strtrim(draft.name or "")
                    if name == "" then return end
                    if AddWorkout(name, tonumber(draft.amount) or 10, strtrim(draft.unit or "")) then
                        draft.name = ""
                        Refresh()
                    else
                        WorkoutBuddy:Print(name .. " is already in your list.")
                    end
                end,
            },

            libraryHeader = { type = "header", name = "Workout library", order = 20 },
            libraryDesc = {
                type = "description",
                name = "Desk-friendly exercises you can do in a minute or two.",
                order = 20.5,
            },
            category = {
                type = "select",
                name = "Category",
                order = 21,
                values = function()
                    local vals = {}
                    for _, cat in ipairs(WorkoutBuddy.GetLibraryCategories()) do vals[cat] = cat end
                    return vals
                end,
                get = CurrentCategory,
                set = function(_, val)
                    library.category = val
                    library.pick = nil
                end,
            },
            pick = {
                type = "select",
                name = "Exercise",
                order = 22,
                width = "double",
                values = function() return (LibraryItems()) end,
                sorting = function() return select(2, LibraryItems()) end,
                get = function() return library.pick end,
                set = function(_, val) library.pick = val end,
            },
            addPick = {
                type = "execute",
                name = "Add selected",
                order = 23,
                disabled = function() return not library.pick end,
                func = function()
                    local w = WorkoutBuddy.WorkoutLibrary[tonumber(library.pick or "")]
                    if w and AddWorkout(w.name, w.amount, w.unit) then
                        Refresh()
                    elseif w then
                        WorkoutBuddy:Print(w.name .. " is already in your list.")
                    end
                end,
            },
            addCategory = {
                type = "execute",
                name = "Add whole category",
                order = 24,
                func = function()
                    local added = 0
                    for _, w in ipairs(WorkoutBuddy.WorkoutLibrary) do
                        if w.category == CurrentCategory() and AddWorkout(w.name, w.amount, w.unit) then
                            added = added + 1
                        end
                    end
                    WorkoutBuddy:Print(string.format("Added %d workout(s) from %s.", added, CurrentCategory()))
                    Refresh()
                end,
            },

            resetHeader = { type = "header", name = "", order = 30 },
            reset = {
                type = "execute",
                name = "Restore starter list",
                desc = "Replace your list with the starter workouts.",
                order = 31,
                confirm = true,
                confirmText = "Replace your workout list with the starter workouts?",
                func = function()
                    WorkoutBuddy.db.profile.workouts = WorkoutBuddy.CopyWorkouts(WorkoutBuddy.DEFAULT_WORKOUTS)
                    Refresh()
                end,
            },
            clear = {
                type = "execute",
                name = "Remove all",
                order = 32,
                confirm = true,
                confirmText = "Remove every workout from your list?",
                func = function()
                    wipe(Workouts())
                    Refresh()
                end,
            },
        },
    }
end
