local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local TriggerManager = WorkoutBuddy and WorkoutBuddy.TriggerManager

-- Helper to wrap event toggles in their own inline container
local function EventBox(order, toggle)
    return {
        type = "group",
        inline = true,
        name = "",
        order = order,
        args = { toggle = toggle },
    }
end

function WorkoutBuddy:InitConfig()

    self.options = {
        name = "Workout Buddy",
        handler = WorkoutBuddy,
        type = "group",
        args = {
            general      = WorkoutBuddy_GeneralTab(),
            display      = WorkoutBuddy_DisplayTab(),
            workouts     = WorkoutBuddy_WorkoutsTab(),
            hydration    = WorkoutBuddy_HydrationTab(),
            stats        = WorkoutBuddy_StatsTab(),
            importexport = WorkoutBuddy_ImportExportTab(),
            profile      = WorkoutBuddy_ProfileTab and WorkoutBuddy_ProfileTab() or AceDBOptions:GetOptionsTable(WorkoutBuddy.db),
        },
    }

    self:RebuildWorkoutListOptions()
    self:RebuildCustomEventToggles()

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


-- Build checkboxes for custom triggers in the General tab
function WorkoutBuddy:RebuildCustomEventToggles()
    if not self.options or not self.options.args.general then return end
    local actArgs = self.options.args.general.args.eventTriggers.args
    local openArgs = self.options.args.general.args.openEvents.args

    -- remove old entries
    for k in pairs(actArgs) do
        if k:match("^custom") then actArgs[k] = nil end
    end
    for k in pairs(openArgs) do
        if k:match("^custom") then openArgs[k] = nil end
    end

    local triggers = self.db and self.db.profile and self.db.profile.triggers or {}
    local aIdx, oIdx = 10, 10
    for id, c in ipairs(triggers) do
        local target = (c.action == "open_frame") and openArgs or actArgs
        local idx = (c.action == "open_frame") and oIdx or aIdx
        local key = "custom" .. id
        target[key] = EventBox(idx, {
            type = "toggle",
            name = c.name or ("Custom " .. id),
            desc = WorkoutBuddy.TriggerManager.EventHelp[c.event] or nil,
            width = 0.8,
            order = 1,
            get = function() return c.enabled ~= false end,
            set = function(info, val) c.enabled = val end,
        })
        target[key].args.edit = {
            type = "execute",
            name = "",
            image = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up",
            imageWidth = 16,
            imageHeight = 16,
            width = 0.1,
            order = 1.1,
            func = function() WorkoutBuddy:OpenTriggerEditor(nil, id) end,
        }
        target[key].args.del = {
            type = "execute",
            name = "",
            image = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
            imageWidth = 16,
            imageHeight = 16,
            width = 0.1,
            order = 1.2,
            confirm = true,
            confirmText = "Delete custom event '" .. (c.name or "Custom" .. id) .. "'?",
            func = function()
                table.remove(triggers, id)
                WorkoutBuddy.TriggerManager:RegisterEvents()
                WorkoutBuddy:RebuildCustomEventToggles()
            end,
        }
        if c.action == "open_frame" then oIdx = oIdx + 1 else aIdx = aIdx + 1 end
    end
end

function WorkoutBuddy:OpenConfig(input)
    AceConfigDialog:Open("WorkoutBuddy")
end

