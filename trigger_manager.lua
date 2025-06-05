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
    QUEST_LOG_UPDATE = "QUEST_LOG_UPDATE",
    PLAYER_TARGET_CHANGED = "PLAYER_TARGET_CHANGED",
    PLAYER_EQUIPMENT_CHANGED = "PLAYER_EQUIPMENT_CHANGED",
    SKILL_LINES_CHANGED = "SKILL_LINES_CHANGED",
    GUILD_ROSTER_UPDATE = "GUILD_ROSTER_UPDATE",
    CHAT_MSG_LOOT = "CHAT_MSG_LOOT",
    CHAT_MSG_SYSTEM = "CHAT_MSG_SYSTEM",
    MERCHANT_SHOW = "MERCHANT_SHOW",
    MAIL_SHOW = "MAIL_SHOW",
    BAG_OPEN = "BAG_OPEN",
    BAG_CLOSED = "BAG_CLOSED",
    PLAYER_LOGIN = "PLAYER_LOGIN",
    PLAYER_LOGOUT = "PLAYER_LOGOUT",
    ACHIEVEMENT_EARNED = "ACHIEVEMENT_EARNED",
    PET_BATTLE_OPENING_DONE = "PET_BATTLE_OPENING_DONE",
    PET_BATTLE_CLOSE = "PET_BATTLE_CLOSE",
    CHALLENGE_MODE_COMPLETED = "CHALLENGE_MODE_COMPLETED",
    UNIT_HEALTH = "UNIT_HEALTH",
    UNIT_POWER_UPDATE = "UNIT_POWER_UPDATE",
    UNIT_AURA = "UNIT_AURA",
    UNIT_SPELLCAST_SUCCEEDED = "UNIT_SPELLCAST_SUCCEEDED",
    COMBAT_LOG_EVENT_UNFILTERED = "COMBAT_LOG_EVENT_UNFILTERED",
    CHAT_MSG_SAY = "CHAT_MSG_SAY",
    CHAT_MSG_YELL = "CHAT_MSG_YELL",
    CHAT_MSG_GUILD = "CHAT_MSG_GUILD",
    CHAT_MSG_PARTY = "CHAT_MSG_PARTY",
    PLAYER_STARTED_MOVING = "PLAYER_STARTED_MOVING",
    PLAYER_STOPPED_MOVING = "PLAYER_STOPPED_MOVING",
    INSTANCE_ENCOUNTER_ENGAGE_UNIT = "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
    RAID_BOSS_EMOTE = "RAID_BOSS_EMOTE",
    SPELLS_CHANGED = "SPELLS_CHANGED",
    CUSTOM = "Custom Event",
}

TriggerManager.EventHelp = {
    PLAYER_LEVEL_UP = "Fires when you gain a level. Example condition: return true",
    PLAYER_XP_UPDATE = "Your XP changed. Example: return UnitXP('player') % UnitXPMax('player') == 0",
    QUEST_TURNED_IN = "Quest completed. Example: return true",
    UNIT_HEALTH = "Args: unit. Example: return UnitHealth(arg1)/UnitHealthMax(arg1) < 0.5",
    UNIT_POWER_UPDATE = "Args: unit, powerType. Example: return powerType=='MANA' and UnitPower(unit)<100",
    PLAYER_REGEN_DISABLED = "You entered combat. Example: return true",
    PLAYER_REGEN_ENABLED = "You left combat. Example: return true",
    PLAYER_DEAD = "When you die. Example: return true",
    PLAYER_ALIVE = "When you resurrect. Example: return true",
    BAG_UPDATE = "Your bags changed. Example: return true",
    PLAYER_MONEY = "Money changed. Example: return GetMoney()>0",
    QUEST_ACCEPTED = "Quest accepted. Args: questId. Example: return questId==12345",
    GOSSIP_SHOW = "NPC gossip opened. Example: return true",
    PLAYER_TARGET_CHANGED = "Target changed. Example: return UnitIsFriend('player','target')",
    PLAYER_STARTED_MOVING = "Player started moving. Example: return true",
    PLAYER_STOPPED_MOVING = "Player stopped moving. Example: return true",
    CHAT_MSG_SAY = "Chat message say. Args: msg. Example: return msg:find('hello')",
    INSTANCE_ENCOUNTER_ENGAGE_UNIT = "Boss fight started. Example: return true",
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
