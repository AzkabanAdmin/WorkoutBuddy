-- trigger_manager.lua
-- Player-defined triggers. Each trigger names an event, optional built-in
-- options (health threshold, rested state, item used), an optional Lua
-- condition and an action: "workout" (suggest a random workout), "fixed"
-- (add a set workout every time) or "open_frame" (show the queue).
--
-- ITEM_USED is Workout Buddy's own trigger type: it listens to the player's
-- successful spellcasts and matches them to items through item_use.lua.
--
-- TriggerManager is the only place custom triggers are dispatched from, so a
-- trigger fires exactly once per event.

local _, WorkoutBuddy = ...

local TriggerManager = {}
WorkoutBuddy.TriggerManager = TriggerManager

-- WoW runs Lua 5.1, where load() only accepts a function. loadstring()
-- compiles a string.
local loadstring = loadstring

TriggerManager.EventHelp = WorkoutBuddy.EventHelp

------------------------------------------------------------------------
-- Event catalog for the editor (filtered to what this client supports)
------------------------------------------------------------------------
local ITEM_USED = "ITEM_USED"
local ITEM_USED_EVENT = "UNIT_SPELLCAST_SUCCEEDED"
TriggerManager.ITEM_USED = ITEM_USED

local function CategoryOf(evt)
    return evt:match("^([A-Z]+)_") or "OTHER"
end
TriggerManager.CategoryOf = CategoryOf

function TriggerManager:BuildCatalog()
    if self.EventCategories then return end
    self.EventCategories, self.CategoryOrder = {}, {}
    local seen = {}
    for _, evt in ipairs(WorkoutBuddy.WowEvents or {}) do
        if not seen[evt] and WorkoutBuddy.IsEventUseful(evt) then -- hide events for content this game lacks
            seen[evt] = true
            local cat = CategoryOf(evt)
            if not self.EventCategories[cat] then
                self.EventCategories[cat] = {}
                table.insert(self.CategoryOrder, cat)
            end
            table.insert(self.EventCategories[cat], evt)
        end
    end
    -- Workout Buddy's own "I use an item or spell" trigger
    if WorkoutBuddy.IsEventValid(ITEM_USED_EVENT) then
        local cat = CategoryOf(ITEM_USED)
        if not self.EventCategories[cat] then
            self.EventCategories[cat] = {}
            table.insert(self.CategoryOrder, cat)
        end
        table.insert(self.EventCategories[cat], ITEM_USED)
    end
    table.sort(self.CategoryOrder)
    for _, list in pairs(self.EventCategories) do table.sort(list) end
end

------------------------------------------------------------------------
-- Registration
------------------------------------------------------------------------
-- The game event a trigger listens to.
local function TriggerEvent(t)
    if t.event == "CUSTOM" then return t.customEvent end
    if t.event == ITEM_USED then return ITEM_USED_EVENT end
    return t.event
end
TriggerManager.TriggerEvent = TriggerEvent

--- True if a trigger can use this event name on this client.
function TriggerManager.IsTriggerEventValid(evt)
    if evt == ITEM_USED then return WorkoutBuddy.IsEventValid(ITEM_USED_EVENT) end
    return WorkoutBuddy.IsEventValid(evt)
end

local function Triggers()
    local p = WorkoutBuddy.db and WorkoutBuddy.db.profile
    return p and p.triggers or {}
end

function TriggerManager:Init()
    self.frame = self.frame or CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        self:HandleEvent(event, ...)
    end)
    self.compiled = {}
    self.warned = {}
    self:RegisterEvents()
end

-- Health triggers on these units are re-checked when the unit changes, so a
-- new target that is already below the threshold fires right away.
local UNIT_CHANGE_EVENTS = { PLAYER_TARGET_CHANGED = "target", PLAYER_FOCUS_CHANGED = "focus" }

function TriggerManager:RegisterEvents()
    if not self.frame then return end
    self.frame:UnregisterAllEvents()
    local needItems = false
    for _, t in ipairs(Triggers()) do
        local evt = TriggerEvent(t)
        t._lastPass = nil
        if t.enabled ~= false and t.event == ITEM_USED then needItems = true end
        if t.enabled ~= false and t.event == "UNIT_HEALTH" then
            for changeEvent, unit in pairs(UNIT_CHANGE_EVENTS) do
                if t.options.unit == unit then WorkoutBuddy.SafeRegisterEvent(self.frame, changeEvent) end
            end
        end
        if t.enabled ~= false and evt and evt ~= "" then
            if not WorkoutBuddy.SafeRegisterEvent(self.frame, evt) then
                self:WarnOnce("badevent:" .. evt, string.format(
                    "Trigger '%s' uses the event %s, which this game client does not have. It will not fire.",
                    t.name ~= "" and t.name or "?", evt))
            end
        end
    end
    WorkoutBuddy.ItemUse:SetActive(needItems)
end

------------------------------------------------------------------------
-- Evaluation
------------------------------------------------------------------------
local COMPARE = {
    ["<"] = function(a, b) return a < b end,
    ["<="] = function(a, b) return a <= b end,
    [">"] = function(a, b) return a > b end,
    [">="] = function(a, b) return a >= b end,
    ["=="] = function(a, b) return math.floor(a + 0.5) == b end,
    ["~="] = function(a, b) return math.floor(a + 0.5) ~= b end,
}

-- Returns true/false, or nil when the value cannot be read right now.
local function HealthCondition(t, unitArg)
    local unit = t.options.unit or "player"
    if unitArg and unitArg ~= unit then return nil end -- event was for another unit
    if not UnitExists(unit) then return false end
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    if WorkoutBuddy.IsSecret(cur) or WorkoutBuddy.IsSecret(max) then
        return nil
    end
    if type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then return false end
    local pct = cur / max * 100
    local cmp = COMPARE[t.options.op or "<"] or COMPARE["<"]
    return cmp(pct, tonumber(t.options.value) or 50)
end

function TriggerManager:Compile(code, name)
    local f = self.compiled[code]
    if f == nil then
        local err
        f, err = loadstring(code, "WorkoutBuddy trigger: " .. (name or "?"))
        if not f then
            self:WarnOnce("compile:" .. code, "Trigger '" .. (name or "?") .. "' has a Lua error: " .. tostring(err))
            f = false
        end
        self.compiled[code] = f
    end
    return f or nil
end

function TriggerManager:HandleEvent(event, ...)
    local changedUnit = UNIT_CHANGE_EVENTS[event]
    if changedUnit then
        for _, t in ipairs(Triggers()) do
            if t.enabled ~= false and t.event == "UNIT_HEALTH" and t.options.unit == changedUnit then
                t._lastPass = nil -- a different unit: start the edge detection over
                self:Evaluate(t, "UNIT_HEALTH", changedUnit)
            end
        end
    end
    for _, t in ipairs(Triggers()) do
        if t.enabled ~= false and TriggerEvent(t) == event then
            self:Evaluate(t, event, ...)
        end
    end
end

function TriggerManager:Evaluate(t, event, ...)
    local pass = true
    local edge = false

    if t.event == "UNIT_HEALTH" then
        local res = HealthCondition(t, ...)
        if res == nil then return end -- other unit, or health hidden right now
        pass, edge = res, true
    elseif t.event == "PLAYER_UPDATE_RESTING" and t.options.state then
        pass = (IsResting() and true or false) == (t.options.state == "resting")
    elseif t.event == ITEM_USED then
        -- UNIT_SPELLCAST_SUCCEEDED: unit, castGUID, spellID
        local unit, _, spellID = ...
        if unit ~= "player" or WorkoutBuddy.IsSecret(spellID) then return end
        if not WorkoutBuddy.ItemUse.Matches(t.options, WorkoutBuddy.ItemUse:Lookup(spellID)) then return end
    end

    -- Imported code is never run, and the trigger never fires without its
    -- condition, until the player reviews and saves it.
    if t.imported and t.custom and t.custom ~= "" then return end

    if pass and t.custom and t.custom ~= "" then
        local f = self:Compile(t.custom, t.name)
        if not f then return end
        local ok, res = pcall(f, ...)
        if ok then
            pass = res and true or false
        else
            self:WarnOnce("run:" .. t.custom, "Trigger '" .. (t.name or "?") .. "' condition failed: " .. tostring(res))
            return
        end
    end

    -- Edge triggering for continuous conditions: fire once when the
    -- condition becomes true, not on every update while it stays true.
    if edge then
        local was = t._lastPass
        t._lastPass = pass
        if was then return end
    end

    if not pass then return end

    local label = (t.name and t.name ~= "") and t.name or (t.event == ITEM_USED and "Item used" or event)
    if t.action == "open_frame" then
        WorkoutBuddy.ReminderEvents:TryShowFrame()
    elseif t.action == "fixed" and t.workout then
        WorkoutBuddy:AddSetWorkout(t.workout, label)
    else
        WorkoutBuddy:SuggestWorkout(label)
    end
end

function TriggerManager:WarnOnce(key, msg)
    self.warned = self.warned or {}
    if self.warned[key] then return end
    self.warned[key] = true
    WorkoutBuddy:Print("|cFFFF5555" .. msg .. "|r")
end

--- Called after a trigger is edited so its compiled code and warnings refresh.
function TriggerManager:Reset()
    self.compiled = {}
    self.warned = {}
    self:RegisterEvents()
end
