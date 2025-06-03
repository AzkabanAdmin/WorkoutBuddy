local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

function WorkoutBuddy:InitConfig()
    self.options = {
        name = "Workout Buddy",
        handler = WorkoutBuddy,
        type = "group",
        args = {
            general      = WorkoutBuddy_GeneralTab(),
            workouts     = WorkoutBuddy_WorkoutsTab(),
            importexport = WorkoutBuddy_ImportExportTab(),
            profile      = WorkoutBuddy_ProfileTab and WorkoutBuddy_ProfileTab() or AceDBOptions:GetOptionsTable(WorkoutBuddy.db),
        },
    }

    self:RebuildWorkoutListOptions()

    AceConfig:RegisterOptionsTable("WorkoutBuddy", self.options)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("WorkoutBuddy", "Workout Buddy")
    AceConfigDialog:AddToBlizOptions("WorkoutBuddy", "Profiles", "Workout Buddy", "profile")
end

function WorkoutBuddy:RebuildWorkoutListOptions()
    local args = self.options.args.workouts.args.workoutList.args
    wipe(args)
    local workouts = self.db and self.db.profile and self.db.profile.workouts or {}

    for i, workout in ipairs(workouts) do
        args["box" .. i] = {
            type = "group",
            name = workout.name or ("Workout " .. i),
            inline = false,
            order = i,
            args = {
                workoutAmount = {
                    type = "input",
                    name = "Amount",
                    desc = "How many? (e.g., reps, oz, seconds)",
                    order = 1,
                    width = 0.6,
                    get = function() return tostring(workout.amount or "") end,
                    set = function(info, val) workout.amount = tonumber(val) or workout.amount end,
                },
                workoutUnit = {
                    type = "input",
                    name = "Unit",
                    desc = "Unit (optional)",
                    order = 2,
                    width = 0.7,
                    get = function() return workout.unit or "" end,
                    set = function(info, val) workout.unit = val end,
                },
                removeBtn = {
                    type = "execute",
                    name = "Remove",
                    order = 3,
                    width = 0.7,
                    confirm = true,
                    confirmText = "Remove workout '" .. (workout.name or "") .. "'?",
                    func = function()
                        local newList = {}
                        for idx, w in ipairs(workouts) do
                            if idx ~= i then
                                table.insert(newList, w)
                            end
                        end
                        self.db.profile.workouts = newList
                        WorkoutBuddy:RebuildWorkoutListOptions()
                        AceConfigDialog:SelectGroup("WorkoutBuddy", "workouts")
                    end,
                },
            },
        }
    end
end

function WorkoutBuddy:OpenConfig(input)
    AceConfigDialog:Open("WorkoutBuddy")
end
