local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local TriggerManager = WorkoutBuddy and WorkoutBuddy.TriggerManager

function WorkoutBuddy:InitConfig()
    self.options = {
        name = "Workout Buddy",
        handler = WorkoutBuddy,
        type = "group",
        args = {
            general      = WorkoutBuddy_GeneralTab(),
            triggers     = WorkoutBuddy_TriggersTab(),
            workouts     = WorkoutBuddy_WorkoutsTab(),
            hydration    = WorkoutBuddy_HydrationTab(),
            stats        = WorkoutBuddy_StatsTab(),
            importexport = WorkoutBuddy_ImportExportTab(),
            profile      = WorkoutBuddy_ProfileTab and WorkoutBuddy_ProfileTab() or AceDBOptions:GetOptionsTable(WorkoutBuddy.db),
        },
    }

    self:RebuildWorkoutListOptions()
    self:RebuildTriggerOptions()
    self:RebuildConditionOptions()

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

function WorkoutBuddy:RebuildTriggerOptions()
    local args = self.options.args.triggers.args.triggerList.args
    wipe(args)
    local triggers = self.db and self.db.profile and self.db.profile.triggers or {}
    for i, t in ipairs(triggers) do
        args["tr" .. i] = {
            type = "group",
            name = t.name or ("Trigger " .. i),
            inline = true,
            order = i,
            args = {
                name = {
                    type = "input",
                    name = "Name",
                    order = 1,
                    get = function() return t.name or "" end,
                    set = function(info, val) t.name = val end,
                },
                event = {
                    type = "select",
                    name = "Event",
                    order = 2,
                    width = 1.7,
                    values = TriggerManager.EventList,
                    get = function() return t.event end,
                    set = function(info, val) t.event = val; WorkoutBuddy.TriggerManager:RegisterEvents() end,
                },
                customEvent = {
                    type = "input",
                    name = "Custom Event Name",
                    order = 3,
                    width = 1.7,
                    hidden = function() return t.event ~= "CUSTOM" end,
                    get = function() return t.customEvent or "" end,
                    set = function(info, val) t.customEvent = val; WorkoutBuddy.TriggerManager:RegisterEvents() end,
                },
                custom = {
                    type = "input",
                    name = "Custom Lua (return true/false)",
                    multiline = true,
                    width = "full",
                    order = 4,
                    get = function() return t.custom or "" end,
                    set = function(info, val) t.custom = val end,
                },
                remove = {
                    type = "execute",
                    name = "Remove",
                    order = 5,
                    func = function()
                        table.remove(triggers, i)
                        WorkoutBuddy:RebuildTriggerOptions()
                        WorkoutBuddy:RebuildConditionOptions()
                        WorkoutBuddy.TriggerManager:RegisterEvents()
                        AceConfigDialog:SelectGroup("WorkoutBuddy", "triggers")
                    end,
                },
            },
        }
    end
end

function WorkoutBuddy:RebuildConditionOptions()
    local args = self.options.args.triggers.args.conditionList.args
    wipe(args)
    local conds = self.db and self.db.profile and self.db.profile.conditions or {}
    for i, c in ipairs(conds) do
        args["cond" .. i] = {
            type = "group",
            name = c.name or ("Condition " .. i),
            inline = true,
            order = i,
            args = {
                name = {
                    type = "input",
                    name = "Name",
                    order = 1,
                    get = function() return c.name or "" end,
                    set = function(info, val) c.name = val end,
                },
                triggerIds = {
                    type = "input",
                    name = "Trigger IDs (comma separated)",
                    order = 2,
                    get = function()
                        return table.concat(c.triggers or {}, ",")
                    end,
                    set = function(info, val)
                        local t = {}
                        for num in string.gmatch(val, "(%d+)") do
                            table.insert(t, tonumber(num))
                        end
                        c.triggers = t
                    end,
                },
                logic = {
                    type = "select",
                    name = "Logic",
                    order = 3,
                    values = { AND = "AND", OR = "OR" },
                    get = function() return c.logic or "AND" end,
                    set = function(info, val) c.logic = val end,
                },
                activity = {
                    type = "input",
                    name = "Activity Name",
                    order = 4,
                    get = function() return c.activity or "" end,
                    set = function(info, val) c.activity = val end,
                },
                action = {
                    type = "select",
                    name = "Action",
                    order = 5,
                    values = { workout = "Suggest Workout", open_frame = "Open Reminder Frame" },
                    get = function() return c.action or "workout" end,
                    set = function(info, val) c.action = val end,
                },
                custom = {
                    type = "input",
                    name = "Custom Lua (return true/false)",
                    multiline = true,
                    width = "full",
                    order = 6,
                    get = function() return c.custom or "" end,
                    set = function(info, val) c.custom = val end,
                },
                remove = {
                    type = "execute",
                    name = "Remove",
                    order = 7,
                    func = function()
                        table.remove(conds, i)
                        WorkoutBuddy:RebuildConditionOptions()
                        AceConfigDialog:SelectGroup("WorkoutBuddy", "triggers", "conditionList")
                    end,
                },
            },
        }
    end
end

function WorkoutBuddy:OpenConfig(input)
    AceConfigDialog:Open("WorkoutBuddy")
end
