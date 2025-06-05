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
            workouts     = WorkoutBuddy_WorkoutsTab(),
            hydration    = WorkoutBuddy_HydrationTab(),
            stats        = WorkoutBuddy_StatsTab(),
            importexport = WorkoutBuddy_ImportExportTab(),
            profile      = WorkoutBuddy_ProfileTab and WorkoutBuddy_ProfileTab() or AceDBOptions:GetOptionsTable(WorkoutBuddy.db),
        },
    }

    self:RebuildWorkoutListOptions()
    self:RebuildTriggerOptions(self.options.args.general.args.automation.args.triggers.args.triggerList.args,
        {"general","automation","triggers","triggerList"})
    self:RebuildConditionOptions(self.options.args.general.args.automation.args.conditions.args.conditionList.args,
        {"general","automation","conditions","conditionList"})
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

function WorkoutBuddy:RebuildTriggerOptions(targetArgs, path, root)
    local args = targetArgs
        or (self.options.args.general and self.options.args.general.args.automation
            and self.options.args.general.args.automation.args.triggers.args.triggerList.args)
    local selectPath = path or {"triggers"}
    local rootName = root or "WorkoutBuddy"
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
                    width = 2,
                    values = TriggerManager.EventList,
                    get = function() return t.event end,
                    set = function(info, val)
                        t.event = val
                        WorkoutBuddy.TriggerManager:RegisterEvents()
                    end,
                },
                customEvent = {
                    type = "input",
                    name = "Custom Event Name",
                    order = 3,
                    width = 1.8,
                    hidden = function() return t.event ~= "CUSTOM" end,
                    get = function() return t.customEvent or "" end,
                    set = function(info, val)
                        t.customEvent = val
                        WorkoutBuddy.TriggerManager:RegisterEvents()
                    end,
                },
                custom = {
                    type = "input",
                    name = "Custom Lua (return true/false)",
                    multiline = true,
                    width = "full",
                    order = 4,
                    hidden = function() return t.event ~= "CUSTOM" end,
                    get = function() return t.custom or "" end,
                    set = function(info, val) t.custom = val end,
                },
                up = {
                    type = "execute",
                    name = "Up",
                    order = 5,
                    disabled = function() return i == 1 end,
                    func = function()
                        if i > 1 then
                            local tmp = triggers[i]
                            table.remove(triggers, i)
                            table.insert(triggers, i-1, tmp)
                            WorkoutBuddy:RebuildTriggerOptions(targetArgs, selectPath, rootName)
                            WorkoutBuddy:RebuildConditionOptions(nil, selectPath, rootName)
                            AceConfigDialog:SelectGroup(rootName, unpack(selectPath))
                        end
                    end,
                },
                down = {
                    type = "execute",
                    name = "Down",
                    order = 6,
                    disabled = function() return i == #triggers end,
                    func = function()
                        if i < #triggers then
                            local tmp = triggers[i]
                            table.remove(triggers, i)
                            table.insert(triggers, i+1, tmp)
                            WorkoutBuddy:RebuildTriggerOptions(targetArgs, selectPath, rootName)
                            WorkoutBuddy:RebuildConditionOptions(nil, selectPath, rootName)
                            AceConfigDialog:SelectGroup(rootName, unpack(selectPath))
                        end
                    end,
                },
                remove = {
                    type = "execute",
                    name = "Remove",
                    order = 7,
                    func = function()
                        table.remove(triggers, i)
                        WorkoutBuddy:RebuildTriggerOptions(targetArgs, selectPath, rootName)
                        WorkoutBuddy:RebuildConditionOptions(nil, selectPath, rootName)
                        WorkoutBuddy.TriggerManager:RegisterEvents()
                        AceConfigDialog:SelectGroup(rootName, unpack(selectPath))
                    end,
                },
            },
        }
    end
    WorkoutBuddy:RebuildCustomEventToggles()
end

function WorkoutBuddy:RebuildConditionOptions(targetArgs, path, root)
    local args = targetArgs
        or (self.options.args.general and self.options.args.general.args.automation
            and self.options.args.general.args.automation.args.conditions.args.conditionList.args)
    local selectPath = path or {"triggers", "conditionList"}
    local rootName = root or "WorkoutBuddy"
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
                up = {
                    type = "execute",
                    name = "Up",
                    order = 7,
                    disabled = function() return i == 1 end,
                    func = function()
                        if i > 1 then
                            local tmp = conds[i]
                            table.remove(conds, i)
                            table.insert(conds, i-1, tmp)
                            WorkoutBuddy:RebuildConditionOptions(targetArgs, selectPath, rootName)
                            AceConfigDialog:SelectGroup(rootName, unpack(selectPath))
                        end
                    end,
                },
                down = {
                    type = "execute",
                    name = "Down",
                    order = 8,
                    disabled = function() return i == #conds end,
                    func = function()
                        if i < #conds then
                            local tmp = conds[i]
                            table.remove(conds, i)
                            table.insert(conds, i+1, tmp)
                            WorkoutBuddy:RebuildConditionOptions(targetArgs, selectPath, rootName)
                            AceConfigDialog:SelectGroup(rootName, unpack(selectPath))
                        end
                    end,
                },
                remove = {
                    type = "execute",
                    name = "Remove",
                    order = 9,
                    func = function()
                        table.remove(conds, i)
                        WorkoutBuddy:RebuildConditionOptions(targetArgs, selectPath, rootName)
                        AceConfigDialog:SelectGroup(rootName, unpack(selectPath))
                    end,
                },
            },
        }
    end
    WorkoutBuddy:RebuildCustomEventToggles()
end

-- Build checkboxes for custom conditions in the General tab
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

    local conds = self.db and self.db.profile and self.db.profile.conditions or {}
    local aIdx, oIdx = 10, 10
    for id, c in ipairs(conds) do
        local target = (c.action == "open_frame") and openArgs or actArgs
        local idx = (c.action == "open_frame") and oIdx or aIdx
        local key = "custom" .. id
        target[key] = {
            type = "toggle",
            name = c.name or ("Custom " .. id),
            order = idx,
            width = 1.2,
            get = function() return c.enabled ~= false end,
            set = function(info, val) c.enabled = val end,
        }
        target[key .. "Edit"] = {
            type = "execute",
            name = "",
            image = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up",
            imageWidth = 16,
            imageHeight = 16,
            width = 0.2,
            order = idx + 0.1,
            func = function() WorkoutBuddy:OpenAutomationOptions() end,
        }
        target[key .. "Del"] = {
            type = "execute",
            name = "",
            image = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
            imageWidth = 16,
            imageHeight = 16,
            width = 0.2,
            order = idx + 0.2,
            confirm = true,
            confirmText = "Delete custom event '" .. (c.name or "Custom" .. id) .. "'?",
            func = function()
                table.remove(conds, id)
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

function WorkoutBuddy:OpenAutomationOptions(target)
    AceConfigDialog:Open("WorkoutBuddy")
    local path = {"general", "automation"}
    if target == "triggers" or target == "conditions" then
        table.insert(path, target)
    else
        table.insert(path, "conditions")
    end
    AceConfigDialog:SelectGroup("WorkoutBuddy", unpack(path))
end
