local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Helper: Get sorted unique categories from the WorkoutLibrary
local function GetLibraryCategories()
    local cats, seen = {}, {}
    for _, w in ipairs(WorkoutLibrary) do
        if w.category and not seen[w.category] then
            table.insert(cats, w.category)
            seen[w.category] = true
        end
    end
    table.sort(cats)
    return cats
end

function WorkoutBuddy_WorkoutsTab()
    return {
        type = "group",
        name = "Workouts",
        order = 3,
        args = {
            workoutListHeader = {
                type = "header",
                name = "Your Workout List",
                order = 1,
            },
            workoutList = {
                type = "group",
                name = "Workout/Activity List",
                inline = true,
                order = 2,
                args = {}, -- Dynamically built in RebuildWorkoutListOptions
            },
            addWorkoutSeparator = {
                type = "description",
                name = " ",
                order = 2.9,
            },
            newWorkoutInput = {
                type = "input",
                name = "Add New Workout",
                desc = "Type a new workout activity and press Enter",
                order = 3,
                get = function() return WorkoutBuddy._newWorkoutInput or "" end,
                set = function(info, val) WorkoutBuddy._newWorkoutInput = val end,
            },
            addWorkout = {
                type = "execute",
                name = "Add Custom Workout",
                desc = "Add the new custom workout to the list",
                order = 4,
                func = function(info)
                    local self = info and info.handler or WorkoutBuddy
                    if not self.db or not self.db.profile then return end
                    local newW = (self._newWorkoutInput or ""):gsub("^%s*(.-)%s*$", "%1")
                    if newW ~= "" then
                        local newList = {}
                        for _, w in ipairs(self.db.profile.workouts or {}) do
                            table.insert(newList, w)
                        end
                        table.insert(newList, { name = newW, amount = 10, unit = "" })
                        self.db.profile.workouts = newList
                        self._newWorkoutInput = ""
                        self:RebuildWorkoutListOptions()
                        AceConfigDialog:SelectGroup("WorkoutBuddy", "workouts")
                    end
                end,
            },
            workoutLibraryHeader = {
                type = "header",
                name = "Workout Library",
                order = 6,
            },
            libraryCategoryDropdown = {
                type = "select",
                name = "Category",
                order = 7,
                width = "double",
                values = function()
                    local vals = {}
                    for i, cat in ipairs(GetLibraryCategories()) do
                        vals[i] = cat
                    end
                    return vals
                end,
                get = function()
                    return WorkoutBuddy._libraryCategoryIndex or 1
                end,
                set = function(info, val)
                    WorkoutBuddy._libraryCategoryIndex = val
                    WorkoutBuddy._libraryIndex = 1 -- reset workout selection
                end,
            },
            libraryDropdown = {
                type = "select",
                name = "Quick Add from Library",
                order = 8,
                width = "double",
                values = function()
                    local vals, filtered = {}, {}
                    local cats = GetLibraryCategories()
                    local catIdx = WorkoutBuddy._libraryCategoryIndex or 1
                    local selectedCat = cats[catIdx]
                    for i, w in ipairs(WorkoutLibrary) do
                        if w.category == selectedCat then
                            table.insert(filtered, w)
                        end
                    end
                    -- Store for button usage
                    WorkoutBuddy._filteredLibrary = filtered
                    for i, w in ipairs(filtered) do
                        vals[i] = string.format("%s (%s %s)", w.name, w.amount, w.unit or "")
                    end
                    return vals
                end,
                get = function() return WorkoutBuddy._libraryIndex or 1 end,
                set = function(info, val) WorkoutBuddy._libraryIndex = val end,
            },
            addLibraryWorkout = {
                type = "execute",
                name = "Add Selected Workout",
                order = 9,
                func = function()
                    local idx = WorkoutBuddy._libraryIndex or 1
                    local filtered = WorkoutBuddy._filteredLibrary or {}
                    if filtered[idx] then
                        table.insert(WorkoutBuddy.db.profile.workouts, CopyTable(filtered[idx]))
                        WorkoutBuddy:RebuildWorkoutListOptions()
                        AceConfigDialog:SelectGroup("WorkoutBuddy", "workouts")
                    end
                end,
            },
        },
    }
end
