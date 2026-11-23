-- trigger_manager.lua
-- Player-defined triggers. Each trigger names an event, optional built-in
-- options (health threshold, rested state), an optional Lua condition and an
-- action: "workout" (suggest a workout) or "open_frame" (show the queue).
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
local function CategoryOf(evt)
    return evt:match("^([A-Z]+)_") or "OTHER"
end
TriggerManager.CategoryOf = CategoryOf

function TriggerManager:BuildCatalog()
    if self.EventCategories then return end
    self.EventCategories, self.CategoryOrder = {}, {}
    local seen = {}
    for _, evt in ipairs(WorkoutBuddy.WowEvents or {}) do
        if not seen[evt] and WorkoutBuddy.IsEventValid(evt) then
            seen[evt] = true
            local cat = CategoryOf(evt)
            if not self.EventCategories[cat] then
                self.EventCategories[cat] = {}
                table.insert(self.CategoryOrder, cat)
            end
            table.insert(self.EventCategories[cat], evt)
        end
    end
    table.sort(self.CategoryOrder)
    for _, list in pairs(self.EventCategories) do table.sort(list) end
end

------------------------------------------------------------------------
-- Registration
------------------------------------------------------------------------
local function TriggerEvent(t)
    if t.event == "CUSTOM" then return t.customEvent end
    return t.event
end
TriggerManager.TriggerEvent = TriggerEvent

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
    for _, t in ipairs(Triggers()) do
        local evt = TriggerEvent(t)
        t._lastPass = nil
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

    if t.action == "open_frame" then
        WorkoutBuddy.ReminderEvents:TryShowFrame()
    else
        WorkoutBuddy:SuggestWorkout((t.name and t.name ~= "") and t.name or event)
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
