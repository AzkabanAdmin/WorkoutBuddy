-- config.lua
-- Builds the options tree and registers it with the game's settings panel.

local _, WorkoutBuddy = ...

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")

local Tabs = WorkoutBuddy.ConfigTabs

function WorkoutBuddy:InitConfig()
    local profileTab = AceDBOptions:GetOptionsTable(self.db)
    profileTab.order = 100

    self.options = {
        name = "Workout Buddy",
        handler = WorkoutBuddy,
        type = "group",
        childGroups = "tab",
        args = {
            general      = Tabs.General(),
            workouts     = Tabs.Workouts(),
            hydration    = Tabs.Hydration(),
            quiethours   = Tabs.QuietHours(),
            display      = Tabs.Display(),
            stats        = Tabs.Stats(),
            importexport = Tabs.ImportExport(),
            profile      = profileTab,
        },
    }

    self:RebuildWorkoutListOptions()
    self:RebuildCustomEventToggles()

    AceConfig:RegisterOptionsTable("WorkoutBuddy", self.options)
    AceConfigDialog:SetDefaultSize("WorkoutBuddy", 760, 640)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("WorkoutBuddy", "Workout Buddy")
end

function WorkoutBuddy:OpenConfig()
    if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames["WorkoutBuddy"] then
        AceConfigDialog:Close("WorkoutBuddy")
    else
        AceConfigDialog:Open("WorkoutBuddy")
    end
end

function WorkoutBuddy:ForceFullConfigRefresh()
    if not self.options then return end
    self:RebuildWorkoutListOptions()
    self:RebuildCustomEventToggles()
    self:NotifyConfigChanged()
end

------------------------------------------------------------------------
-- Workout list (one inline group per workout)
------------------------------------------------------------------------
function WorkoutBuddy:RebuildWorkoutListOptions()
    if not self.options then return end
    local args = self.options.args.workouts.args.workoutList.args
    wipe(args)
    local workouts = self.db.profile.workouts or {}

    if #workouts == 0 then
        args.empty = {
            type = "description",
            name = "|cFF888888Your list is empty. Add a workout below or pick some from the library.|r",
            order = 1,
        }
        return
    end

    for i, workout in ipairs(workouts) do
        args["w" .. i] = {
            type = "group",
            name = "",
            inline = true,
            order = i,
            args = {
                name = {
                    type = "input",
                    name = "Workout",
                    order = 1,
                    width = 1.3,
                    get = function() return workout.name or "" end,
                    set = function(_, val)
                        val = strtrim(val or "")
                        if val ~= "" then workout.name = val end
                    end,
                },
                amount = {
                    type = "input",
                    name = "Amount",
                    order = 2,
                    width = 0.5,
                    get = function() return tostring(workout.amount or "") end,
                    set = function(_, val) workout.amount = tonumber(val) or workout.amount end,
                    validate = function(_, val)
                        local n = tonumber(val)
                        if not n or n < 0 then return "Enter a number of 0 or more." end
                        return true
                    end,
                },
                unit = {
                    type = "input",
                    name = "Unit",
                    desc = "For example reps, seconds or minutes. Optional.",
                    order = 3,
                    width = 0.6,
                    get = function() return workout.unit or "" end,
                    set = function(_, val) workout.unit = strtrim(val or "") end,
                },
                remove = {
                    type = "execute",
                    name = "Remove",
                    order = 4,
                    width = 0.5,
                    func = function()
                        for idx, w in ipairs(self.db.profile.workouts) do
                            if w == workout then
                                table.remove(self.db.profile.workouts, idx)
                                break
                            end
                        end
                        self:RebuildWorkoutListOptions()
                        self:NotifyConfigChanged()
                    end,
                },
            },
        }
    end
end

------------------------------------------------------------------------
-- Custom trigger rows in the General tab
------------------------------------------------------------------------
function WorkoutBuddy:RebuildCustomEventToggles()
    if not self.options then return end
    local general = self.options.args.general.args
    local actArgs = general.customTriggers.args
    local openArgs = general.customOpen.args
    wipe(actArgs)
    wipe(openArgs)

    local triggers = self.db.profile.triggers or {}
    local counts = { workout = 0, open_frame = 0 }
    for id, c in ipairs(triggers) do
        local isOpen = c.action == "open_frame"
        local target = isOpen and openArgs or actArgs
        local kind = isOpen and "open_frame" or "workout"
        counts[kind] = counts[kind] + 1
        local isItem = c.event == self.TriggerManager.ITEM_USED
        local evt = isItem and c.event or (self.TriggerManager.TriggerEvent(c) or "?")
        local label = (c.name and c.name ~= "") and c.name or (isItem and "Item used" or evt)
        if c.action == "fixed" and c.workout then
            label = label .. " |cFF888888(adds " .. self:FormatWorkout(c.workout) .. ")|r"
        end
        if c.imported then label = label .. " |cFFFF8800(imported, review to enable)|r" end

        target["t" .. id] = {
            type = "group",
            name = "",
            inline = true,
            order = id,
            args = {
                toggle = {
                    type = "toggle",
                    name = label,
                    desc = string.format("Event: %s\n%s", evt, self.EventHelp[evt] or ""),
                    width = 1.8,
                    order = 1,
                    disabled = function() return c.imported end,
                    get = function() return c.enabled ~= false end,
                    set = function(_, val)
                        c.enabled = val
                        self.TriggerManager:RegisterEvents()
                    end,
                },
                edit = {
                    type = "execute",
                    name = "Edit",
                    width = 0.4,
                    order = 2,
                    func = function() self:OpenTriggerEditor(nil, id) end,
                },
                del = {
                    type = "execute",
                    name = "Delete",
                    width = 0.45,
                    order = 3,
                    confirm = true,
                    confirmText = "Delete trigger '" .. label .. "'?",
                    func = function()
                        table.remove(triggers, id)
                        self.TriggerManager:Reset()
                        self:RebuildCustomEventToggles()
                        self:NotifyConfigChanged()
                    end,
                },
            },
        }
    end

    if counts.workout == 0 then
        actArgs.none = { type = "description", order = 1,
            name = "|cFF888888No custom triggers yet. Add one to suggest a workout on any game event.|r" }
    end
    if counts.open_frame == 0 then
        openArgs.none = { type = "description", order = 1,
            name = "|cFF888888No custom auto-open events yet.|r" }
    end
end
