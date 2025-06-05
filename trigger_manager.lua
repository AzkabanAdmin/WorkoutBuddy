local WorkoutBuddy = WorkoutBuddy

--[[
TriggerManager handles custom triggers defined by users. Each trigger specifies
an event, an optional Lua condition, and an action (suggest a workout or open the
reminder frame).
]]

local TriggerManager = {}

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

-- Initialize and register events for all triggers
function TriggerManager:Init()
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
        local evt = t.event == "CUSTOM" and t.customEvent or t.event
        if evt and evt ~= "" then
            self.frame:RegisterEvent(evt)
        end
    end

    self.frame:SetScript("OnEvent", function(_, event, ...)
        self:HandleEvent(event, ...)
    end)
end

-- Handle a fired event and evaluate triggers
function TriggerManager:HandleEvent(event, ...)
    local triggers = WorkoutBuddy.db and WorkoutBuddy.db.profile and WorkoutBuddy.db.profile.triggers or {}
    for _, t in ipairs(triggers) do
        local evt = t.event == "CUSTOM" and t.customEvent or t.event
        if t.enabled ~= false and evt == event then
            local pass = true
            if t.custom and t.custom ~= "" then
                local f, err = loadstring(t.custom)
                if not f then
                    self:HandleError(err)
                    pass = false
                else
                    local ok, res = pcall(f, ...)
                    if ok then
                        pass = not not res
                    else
                        self:HandleError(res)
                        pass = false
                    end
                end
            end
            if pass then
                if t.action == "open_frame" then
                    if WorkoutBuddy.ReminderCore and WorkoutBuddy.ReminderCore.ShowIfAllowed then
                        WorkoutBuddy.ReminderCore:ShowIfAllowed()
                    end
                else
                    local src = t.name or event
                    WorkoutBuddy:SuggestWorkout(src)
                end
            end
        end
    end
end

function TriggerManager:HandleError(err)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000WorkoutBuddy trigger error:|r " .. tostring(err))
end

WorkoutBuddy.TriggerManager = TriggerManager
return TriggerManager
