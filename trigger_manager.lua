local WorkoutBuddy = WorkoutBuddy

--[[
TriggerManager handles custom triggers defined by users. Each trigger specifies
an event, an optional Lua condition, and an action (suggest a workout or open the
reminder frame).
]]

local TriggerManager = {}

-- Helper to see if any workouts are queued
local function QueueHasItems()
    local q = WorkoutBuddy.ReminderState and WorkoutBuddy.ReminderState.getQueue()
    return q and #q > 0
end
local function QueueIsEmpty()
    local q = WorkoutBuddy.ReminderState and WorkoutBuddy.ReminderState.getQueue()
    return not q or #q == 0
end

-- Build the event list from the wow_events.lua file
TriggerManager.EventList = {}
if WorkoutBuddy_WowEvents then
    local events = {}
    for _, evt in ipairs(WorkoutBuddy_WowEvents) do
        table.insert(events, evt)
    end
    table.sort(events)
    for _, evt in ipairs(events) do
        local cat = evt:match("^([A-Z]+)_") or "Other"
        if not TriggerManager.EventList[cat] then
            TriggerManager.EventList[cat] = {}
        end
        TriggerManager.EventList[cat][evt] = evt
    end
end

TriggerManager.EventHelp = {
    PLAYER_LEVEL_UP = "Fires when you gain a level. Example condition: return true",
    PLAYER_XP_UPDATE = "Your XP changed. Example: return UnitXP('player') % UnitXPMax('player') == 0",
    UNIT_HEALTH = "Check a unit's health percentage with operators. Uses trigger options.",
    PLAYER_UPDATE_RESTING = "Args: isResting. Guided field lets you choose resting or not.",
    PLAYER_REGEN_DISABLED = "You entered combat. Example: return true",
    PLAYER_REGEN_ENABLED = "You left combat. Example: return true",
    PLAYER_DEAD = "When you die. Example: return true",
    PLAYER_ALIVE = "When you resurrect. Example: return true",
    BAG_UPDATE = "Your bags changed. Example: return true",
    PLAYER_MONEY = "Money changed. Example: return GetMoney()>0",
    GOSSIP_SHOW = "NPC gossip opened. Example: return true",
    PLAYER_TARGET_CHANGED = "Target changed. Example: return UnitIsFriend('player','target')",
    CHAT_MSG_SAY = "Chat message say. Args: msg. Example: return msg:find('hello')",
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
            if t.options and t.event == "UNIT_HEALTH" then
                local unit = t.options.unit or "player"
                local max = UnitHealthMax(unit)
                local cur = UnitHealth(unit)
                local pct = (max > 0) and (cur / max * 100) or 0
                local val = tonumber(t.options.value or 0) or 0
                local op = t.options.op or "<"
                if op == "<" then pass = pct < val
                elseif op == "<=" then pass = pct <= val
                elseif op == ">" then pass = pct > val
                elseif op == ">=" then pass = pct >= val
                elseif op == "==" then pass = pct == val
                elseif op == "~=" then pass = pct ~= val end
            elseif t.options and t.event == "PLAYER_UPDATE_RESTING" then
                local isResting = IsResting()
                local desired = t.options.state == "resting"
                pass = (isResting == desired)
            end
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
                    local openEmpty = WorkoutBuddy.db and WorkoutBuddy.db.profile and WorkoutBuddy.db.profile.reminder_events and WorkoutBuddy.db.profile.reminder_events.open_empty
                    local hasItems = QueueHasItems()
                    if WorkoutBuddy.ReminderCore and WorkoutBuddy.ReminderCore.ShowIfAllowed and (hasItems or (openEmpty and QueueIsEmpty())) then
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
