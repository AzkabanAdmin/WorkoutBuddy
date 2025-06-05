WorkoutBuddy:DbgPrint("Loaded: reminder_events.lua")

local ReminderEvents = {}

-- Helper to see if any workouts are queued
local function QueueHasItems()
    local q = WorkoutBuddy.ReminderState and WorkoutBuddy.ReminderState.getQueue()
    return q and #q > 0
end
local function QueueIsEmpty()
    local q = WorkoutBuddy.ReminderState and WorkoutBuddy.ReminderState.getQueue()
    return not q or #q == 0
end

-- Build a mapping of events -> condition functions based on user settings
local function BuildEventMap()
    local opts = WorkoutBuddy.db and WorkoutBuddy.db.profile and WorkoutBuddy.db.profile.reminder_events or {}
    local map = {}
    ReminderEvents.openWhenEmpty = opts.open_empty

    -- Always show queued workouts when logging in
    map["PLAYER_ENTERING_WORLD"] = true

    if opts.quest then
        map["QUEST_FINISHED"] = true
    end

    if opts.rested then
        map["PLAYER_UPDATE_RESTING"] = IsResting
    end

    if opts.taxi then
        local checkTaxi = function() return UnitOnTaxi("player") end
        map["TAXIMAP_CLOSED"] = checkTaxi
        map["PLAYER_CONTROL_LOST"] = checkTaxi
    end

    return map
end

function ReminderEvents:Register()
    if self.frame then
        self.frame:UnregisterAllEvents()
    else
        self.frame = CreateFrame("Frame")
    end

    self.events = BuildEventMap()

    for evt in pairs(self.events) do
        self.frame:RegisterEvent(evt)
    end

    self.frame:SetScript("OnEvent", function(_, event, ...)
        if WorkoutBuddy.TriggerManager and WorkoutBuddy.TriggerManager.HandleEvent then
            WorkoutBuddy.TriggerManager:HandleEvent(event, ...)
        end
        local condition = self.events[event]
        local shouldTrigger = false

        if type(condition) == "function" then
            if event == "TAXIMAP_CLOSED" or event == "PLAYER_CONTROL_LOST" then
                C_Timer.After(0.1, function()
                    local hasItems = QueueHasItems()
                    if condition() and (hasItems or (ReminderEvents.openWhenEmpty and QueueIsEmpty())) then
                        WorkoutBuddy:DbgPrint(event .. " triggers Reminder Frame.")
                        if WorkoutBuddy.ReminderCore and WorkoutBuddy.ReminderCore.ShowIfAllowed then
                            WorkoutBuddy.ReminderCore:ShowIfAllowed()
                        end
                    end
                end)
                return
            else
                shouldTrigger = condition()
            end
        else
            shouldTrigger = condition
        end

        local hasItems = QueueHasItems()
        if shouldTrigger and (hasItems or (ReminderEvents.openWhenEmpty and QueueIsEmpty())) then
            WorkoutBuddy:DbgPrint(event .. " triggers Reminder Frame.")
            if WorkoutBuddy.ReminderCore and WorkoutBuddy.ReminderCore.ShowIfAllowed then
                WorkoutBuddy.ReminderCore:ShowIfAllowed()
            end
        end
    end)
end

WorkoutBuddy.ReminderEvents = ReminderEvents

