local WorkoutBuddy = WorkoutBuddy

local TriggerManager = {}

-- List of common events that users can easily select from. This is not
-- exhaustive like WeakAuras but covers the major gameplay events used by the
-- addon. Users can also supply their own custom event names.
-- Common events with readable labels. Users may also enter a custom event name
-- when "Custom Event" is selected.
TriggerManager.EventList = {
    PLAYER_LEVEL_UP = "PLAYER_LEVEL_UP",
    PLAYER_XP_UPDATE = "PLAYER_XP_UPDATE",
    ZONE_CHANGED_NEW_AREA = "ZONE_CHANGED_NEW_AREA",
    ZONE_CHANGED = "ZONE_CHANGED",
    ZONE_CHANGED_INDOORS = "ZONE_CHANGED_INDOORS",
    PLAYER_ENTERING_WORLD = "PLAYER_ENTERING_WORLD",
    PLAYER_UPDATE_RESTING = "PLAYER_UPDATE_RESTING",
    QUEST_FINISHED = "QUEST_FINISHED",
    TAXIMAP_CLOSED = "TAXIMAP_CLOSED",
    PLAYER_CONTROL_LOST = "PLAYER_CONTROL_LOST",
    PLAYER_REGEN_DISABLED = "PLAYER_REGEN_DISABLED",
    PLAYER_REGEN_ENABLED = "PLAYER_REGEN_ENABLED",
    PLAYER_DEAD = "PLAYER_DEAD",
    PLAYER_ALIVE = "PLAYER_ALIVE",
    BAG_UPDATE = "BAG_UPDATE",
    BAG_UPDATE_DELAYED = "BAG_UPDATE_DELAYED",
    PLAYER_MONEY = "PLAYER_MONEY",
    QUEST_ACCEPTED = "QUEST_ACCEPTED",
    QUEST_TURNED_IN = "QUEST_TURNED_IN",
    GOSSIP_SHOW = "GOSSIP_SHOW",
    UNIT_HEALTH = "UNIT_HEALTH",
    UNIT_POWER_UPDATE = "UNIT_POWER_UPDATE",
    UNIT_AURA = "UNIT_AURA",
    UNIT_SPELLCAST_SUCCEEDED = "UNIT_SPELLCAST_SUCCEEDED",
    COMBAT_LOG_EVENT_UNFILTERED = "COMBAT_LOG_EVENT_UNFILTERED",
    CUSTOM = "Custom Event",
}

function TriggerManager:Init()
    self.triggerStates = {}
    self:RegisterEvents()
end

function TriggerManager:RegisterEvents()
    if self.frame then
        self.frame:UnregisterAllEvents()
    else
        self.frame = CreateFrame("Frame")
    end

    local triggers = WorkoutBuddy.db and WorkoutBuddy.db.profile and WorkoutBuddy.db.profile.triggers or {}
    for _, t in ipairs(triggers) do
        local evt = t.event
        if evt == "CUSTOM" then
            evt = t.customEvent
        end
        if evt and evt ~= "" then
            self.frame:RegisterEvent(evt)
        end
    end

    self.frame:SetScript("OnEvent", function(_, event, ...)
        self:HandleEvent(event, ...)
    end)
end

function TriggerManager:HandleEvent(event, ...)
    local triggered = false
    local triggers = WorkoutBuddy.db and WorkoutBuddy.db.profile and WorkoutBuddy.db.profile.triggers or {}
    for id, t in ipairs(triggers) do
        local evt = t.event == "CUSTOM" and t.customEvent or t.event
        if evt == event then
            local state = true
            if t.custom and t.custom ~= "" then
                local f, err = loadstring(t.custom)
                if not f then
                    self:HandleError(err)
                    state = false
                else
                    local ok, res = pcall(f, ...)
                    if ok then
                        state = res and true or false
                    else
                        self:HandleError(res)
                        state = false
                    end
                end
            end
            self.triggerStates[id] = state
            triggered = true
        end
    end
    if triggered then
        self:EvaluateConditions()
    end
end

function TriggerManager:HandleError(err)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000WorkoutBuddy trigger error:|r " .. tostring(err))
end

function TriggerManager:CheckCondition(cond)
    local logic = cond.logic or "AND"
    local result = (logic == "AND")
    for _, id in ipairs(cond.triggers or {}) do
        local state = self.triggerStates[id]
        if logic == "AND" then
            if not state then return false end
        elseif logic == "OR" then
            if state then return true end
            result = false
        end
    end
    if logic == "OR" then
        -- result already handled
    end
    if cond.custom and cond.custom ~= "" then
        local f, err = loadstring(cond.custom)
        if not f then
            self:HandleError(err)
            return false
        else
            local ok, res = pcall(f)
            if not ok then
                self:HandleError(res)
                return false
            end
            if not res then return false end
        end
    end
    return result
end

function TriggerManager:EvaluateConditions()
    local conds = WorkoutBuddy.db and WorkoutBuddy.db.profile and WorkoutBuddy.db.profile.conditions or {}
    for _, cond in ipairs(conds) do
        if cond.enabled ~= false and self:CheckCondition(cond) then
            local action = cond.action or "workout"
            if action == "open_frame" then
                if WorkoutBuddy.ReminderCore and WorkoutBuddy.ReminderCore.ShowIfAllowed then
                    WorkoutBuddy.ReminderCore:ShowIfAllowed()
                end
            else
                local src = cond.activity or cond.name or "Trigger"
                WorkoutBuddy:SuggestWorkout(src)
            end
        end
    end
end

WorkoutBuddy.TriggerManager = TriggerManager
return TriggerManager
