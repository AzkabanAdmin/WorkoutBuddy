-- reminder_events.lua
-- Opens the reminder frame automatically during natural downtime:
-- flights, queues, quest turn-ins, going AFK and so on.

local _, WorkoutBuddy = ...

local ReminderEvents = {}
WorkoutBuddy.ReminderEvents = ReminderEvents

local QUEUE_DELAY = 30 -- seconds in a queue before the frame opens
local TAXI_DELAY = 1   -- lets UnitOnTaxi() update after the event

local function Opts()
    return WorkoutBuddy.db.profile.reminder_events
end

local function QueueHasItems()
    return #WorkoutBuddy.ReminderState.getQueue() > 0
end

------------------------------------------------------------------------
-- Queue detection (dungeon finder and battlegrounds, where available)
------------------------------------------------------------------------
local LFG_CATEGORY_KEYS = {
    "LE_LFG_CATEGORY_LFD", "LE_LFG_CATEGORY_RF", "LE_LFG_CATEGORY_SCENARIO",
    "LE_LFG_CATEGORY_LFR", "LE_LFG_CATEGORY_FLEXRAID",
}

local function IsInQueue()
    if GetLFGMode then
        for _, key in ipairs(LFG_CATEGORY_KEYS) do
            local cat = _G[key]
            if cat then
                local ok, mode = pcall(GetLFGMode, cat)
                if ok and mode == "queued" then return true end
            end
        end
    end
    if GetBattlefieldStatus and GetMaxBattlefieldID then
        for i = 1, GetMaxBattlefieldID() or 0 do
            local ok, status = pcall(GetBattlefieldStatus, i)
            if ok and status == "queued" then return true end
        end
    end
    return false
end

function ReminderEvents.IsQueueOptionSupported()
    return WorkoutBuddy.IsEventValid("LFG_UPDATE") or WorkoutBuddy.IsEventValid("UPDATE_BATTLEFIELD_STATUS")
end

function ReminderEvents.QuestEvent()
    if WorkoutBuddy.IsEventValid("QUEST_TURNED_IN") then return "QUEST_TURNED_IN" end
    return "QUEST_FINISHED"
end

------------------------------------------------------------------------
-- Showing the frame
------------------------------------------------------------------------
function ReminderEvents:TryShowFrame()
    if not (QueueHasItems() or Opts().open_empty) then return end
    if WorkoutBuddy.QuietHours:IsQuiet("workouts") then return end -- never pop open during quiet hours
    if Opts().defer_combat and WorkoutBuddy.InCombat() then
        self.pendingShow = true
        return
    end
    WorkoutBuddy.ReminderCore:Show()
end

------------------------------------------------------------------------
-- Event handlers
------------------------------------------------------------------------
local handlers = {}

handlers.PLAYER_ENTERING_WORLD = function(self, isInitialLogin)
    if isInitialLogin and Opts().login then
        C_Timer.After(5, function() self:TryShowFrame() end)
    end
end

handlers.PLAYER_REGEN_ENABLED = function(self)
    if self.pendingShow then
        self.pendingShow = false
        C_Timer.After(2, function() self:TryShowFrame() end)
    end
end

local function OnQuestDone(self)
    if Opts().quest then self:TryShowFrame() end
end
handlers.QUEST_TURNED_IN = OnQuestDone
handlers.QUEST_FINISHED = OnQuestDone

handlers.PLAYER_UPDATE_RESTING = function(self)
    if Opts().rested and IsResting() then self:TryShowFrame() end
end

local function OnTaxiCheck(self)
    if not Opts().taxi or self.taxiPending then return end
    self.taxiPending = true
    C_Timer.After(TAXI_DELAY, function()
        self.taxiPending = false
        local onTaxi = UnitOnTaxi("player")
        if onTaxi and not self.taxiShown then
            self.taxiShown = true
            self:TryShowFrame()
        elseif not onTaxi then
            self.taxiShown = false
        end
    end)
end
handlers.TAXIMAP_CLOSED = OnTaxiCheck
handlers.PLAYER_CONTROL_LOST = OnTaxiCheck
handlers.PLAYER_CONTROL_GAINED = function(self)
    self.taxiShown = false
end

local function OnQueueUpdate(self)
    if not Opts().lfg_queue then return end
    if not IsInQueue() then
        self.queueShown = false
        return
    end
    if self.queueShown or self.queueTimer then return end
    self.queueTimer = C_Timer.NewTimer(QUEUE_DELAY, function()
        self.queueTimer = nil
        if IsInQueue() and not self.queueShown then
            self.queueShown = true
            WorkoutBuddy:DbgPrint("Still queued after " .. QUEUE_DELAY .. "s, showing reminder.")
            self:TryShowFrame()
        end
    end)
end
handlers.LFG_UPDATE = OnQueueUpdate
handlers.UPDATE_BATTLEFIELD_STATUS = OnQueueUpdate

handlers.PLAYER_FLAGS_CHANGED = function(self, unit)
    if unit ~= "player" or not Opts().afk then return end
    local isAFK = UnitIsAFK("player") and true or false
    if isAFK and not self.wasAFK then
        self:TryShowFrame()
    end
    self.wasAFK = isAFK
end

handlers.AUCTION_HOUSE_SHOW = function(self)
    if Opts().auction_house then self:TryShowFrame() end
end

------------------------------------------------------------------------
-- Registration
------------------------------------------------------------------------
function ReminderEvents:Register()
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event, ...)
            local h = handlers[event]
            if h then h(self, ...) end
        end)
    end
    self.frame:UnregisterAllEvents()
    if self.queueTimer then
        self.queueTimer:Cancel()
        self.queueTimer = nil
    end

    local o = Opts()
    local wanted = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }
    if o.quest then wanted[#wanted + 1] = self.QuestEvent() end
    if o.rested then wanted[#wanted + 1] = "PLAYER_UPDATE_RESTING" end
    if o.taxi then
        wanted[#wanted + 1] = "TAXIMAP_CLOSED"
        wanted[#wanted + 1] = "PLAYER_CONTROL_LOST"
        wanted[#wanted + 1] = "PLAYER_CONTROL_GAINED"
    end
    if o.lfg_queue then
        wanted[#wanted + 1] = "LFG_UPDATE"
        wanted[#wanted + 1] = "UPDATE_BATTLEFIELD_STATUS"
    end
    if o.afk then
        wanted[#wanted + 1] = "PLAYER_FLAGS_CHANGED"
        self.wasAFK = UnitIsAFK("player") and true or false
    end
    if o.auction_house then wanted[#wanted + 1] = "AUCTION_HOUSE_SHOW" end

    for _, evt in ipairs(wanted) do
        WorkoutBuddy.SafeRegisterEvent(self.frame, evt)
    end
end
