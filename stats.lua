-- stats.lua
-- Records completed workouts and water, and summarizes them.

local _, WorkoutBuddy = ...

local Stats = {}
WorkoutBuddy.Stats = Stats

local DAY = 86400

local function profile()
    return WorkoutBuddy.db and WorkoutBuddy.db.profile
end

function Stats:GetRecords()
    local p = profile()
    if not p then return {} end
    p.stats = p.stats or {}
    return p.stats
end

local function isWater(r)
    return r.kind == "water"
end

local ML_PER_OZ = 29.5735

--- The unit water totals are shown in (the hydration setting).
local function waterUnit()
    local p = profile()
    return (p and p.hydration and p.hydration.unit == "ml") and "ml" or "oz"
end

--- A water record's amount in the given unit, so switching units midday
-- does not add ounces and milliliters together.
local function waterAmount(r, unit)
    local amount = r.amount or 0
    local from = (r.unit == "ml") and "ml" or "oz"
    if from == unit then return amount end
    return (unit == "ml") and amount * ML_PER_OZ or amount / ML_PER_OZ
end

--- Log a workout (full or partial).
function Stats:AddRecord(name, amount, unit, partial)
    if not profile() then return end
    local before = self:GetTodayCount()
    table.insert(self:GetRecords(), {
        activity = name,
        amount = tonumber(amount) or 0,
        unit = unit,
        partial = partial and true or nil,
        timestamp = WorkoutBuddy.Now(),
    })
    local goal = profile().daily_goal or 0
    if goal > 0 and before < goal and self:GetTodayCount() >= goal then
        WorkoutBuddy:Print(string.format("|cFF00FF00Daily goal reached!|r %d workouts today. Streak: %d day(s).",
            self:GetTodayCount(), self:GetStreak()))
    end
    WorkoutBuddy:NotifyConfigChanged()
end

--- Log a drink of water.
function Stats:AddWater(amount, unit)
    if not profile() then return end
    table.insert(self:GetRecords(), {
        kind = "water",
        activity = "Water",
        amount = tonumber(amount) or 0,
        unit = unit,
        timestamp = WorkoutBuddy.Now(),
    })
    WorkoutBuddy:NotifyConfigChanged()
end

function Stats:Reset()
    local p = profile()
    if p then p.stats = {} end
    WorkoutBuddy:NotifyConfigChanged()
end

------------------------------------------------------------------------
-- Time frames
------------------------------------------------------------------------
local UNIT_SECONDS = {
    minute = 60, minutes = 60, min = 60, mins = 60, m = 60,
    hour = 3600, hours = 3600, hr = 3600, hrs = 3600, h = 3600,
    day = DAY, days = DAY, d = DAY,
    week = 7 * DAY, weeks = 7 * DAY, w = 7 * DAY,
    month = 30 * DAY, months = 30 * DAY,
}

--- Start timestamp for a time frame, or nil for lifetime.
function Stats:GetStart(timeframe)
    local now = WorkoutBuddy.Now()
    if not timeframe or timeframe == "lifetime" then return nil end
    if timeframe == "day" then
        return WorkoutBuddy.DayStart(now)
    elseif timeframe == "week" then
        -- Weeks start on Monday
        local d = date("*t", now)
        local sinceMonday = (d.wday + 5) % 7
        return WorkoutBuddy.DayStart(now) - sinceMonday * DAY
    elseif timeframe == "month" then
        local d = date("*t", now)
        return time({ year = d.year, month = d.month, day = 1, hour = 0, min = 0, sec = 0 })
    end
    local num, unit = tostring(timeframe):lower():match("^%s*(%d+)%s*(%a+)%s*$")
    num = tonumber(num)
    if num and unit and UNIT_SECONDS[unit] then
        return now - num * UNIT_SECONDS[unit]
    end
    return nil, true -- invalid custom string
end

------------------------------------------------------------------------
-- Summaries
------------------------------------------------------------------------
function Stats:GetTodayCount()
    local start = WorkoutBuddy.DayStart()
    local n = 0
    local recs = self:GetRecords()
    for i = #recs, 1, -1 do
        local r = recs[i]
        if (r.timestamp or 0) < start then break end -- records are appended in time order
        if not isWater(r) then n = n + 1 end
    end
    return n
end

function Stats:GetTodayWater()
    local start = WorkoutBuddy.DayStart()
    local total, unit = 0, waterUnit()
    local recs = self:GetRecords()
    for i = #recs, 1, -1 do
        local r = recs[i]
        if (r.timestamp or 0) < start then break end
        if isWater(r) then total = total + waterAmount(r, unit) end
    end
    return math.floor(total + 0.5), unit
end

--- Consecutive days (ending today, or yesterday if nothing logged yet today)
-- with at least one workout.
function Stats:GetStreak()
    local days = {}
    for _, r in ipairs(self:GetRecords()) do
        if not isWater(r) and r.timestamp then
            days[WorkoutBuddy.DayKey(r.timestamp)] = true
        end
    end
    local t = WorkoutBuddy.DayStart() + 12 * 3600 -- noon avoids DST edge cases
    if not days[WorkoutBuddy.DayKey(t)] then t = t - DAY end
    local streak = 0
    while days[WorkoutBuddy.DayKey(t)] do
        streak = streak + 1
        t = t - DAY
    end
    return streak
end

function Stats:GetTodayLine()
    local goal = profile() and profile().daily_goal or 0
    local count = self:GetTodayCount()
    local line = goal > 0 and string.format("Today: %d / %d workouts", count, goal)
        or string.format("Today: %d workouts", count)
    line = line .. string.format(", streak %d day(s)", self:GetStreak())
    local water, unit = self:GetTodayWater()
    if water > 0 then
        line = line .. string.format(", water %d %s", water, unit or "")
    end
    return line
end

--- Compact progress for the workout window's footer, e.g. "4 / 5 today, 7-day streak".
function Stats:GetShortLine()
    local goal = profile() and profile().daily_goal or 0
    local count = self:GetTodayCount()
    local line = goal > 0 and string.format("%d / %d today", count, goal) or string.format("%d today", count)
    local streak = self:GetStreak()
    if streak > 0 then line = line .. string.format(", %d-day streak", streak) end
    return line
end

function Stats:GetSummary(timeframe)
    local start, invalid = self:GetStart(timeframe)
    if invalid then
        return "|cFFFF5555Could not read that range.|r Try something like 3days, 2weeks or 90minutes."
    end

    local total, partials, water = 0, 0, 0
    local wUnit = waterUnit()
    local byActivity, order = {}, {}
    local activeDays = {}

    for _, r in ipairs(self:GetRecords()) do
        if not start or (r.timestamp or 0) >= start then
            if isWater(r) then
                water = water + waterAmount(r, wUnit)
            else
                total = total + 1
                if r.partial then partials = partials + 1 end
                activeDays[WorkoutBuddy.DayKey(r.timestamp or 0)] = true
                local key = r.activity or "?"
                if not byActivity[key] then
                    byActivity[key] = { amount = 0, unit = r.unit, sessions = 0 }
                    order[#order + 1] = key
                end
                local a = byActivity[key]
                a.amount = a.amount + (r.amount or 0)
                a.sessions = a.sessions + 1
                if r.unit and r.unit ~= "" then a.unit = r.unit end
            end
        end
    end

    table.sort(order, function(a, b)
        if byActivity[a].sessions ~= byActivity[b].sessions then
            return byActivity[a].sessions > byActivity[b].sessions
        end
        return a < b
    end)

    local days = 0
    for _ in pairs(activeDays) do days = days + 1 end

    local lines = {
        string.format("|cFFFFD700Workouts logged:|r %d  |cFF888888(%d partial)|r", total, partials),
        string.format("|cFFFFD700Active days:|r %d", days),
    }
    if water > 0 then
        lines[#lines + 1] = string.format("|cFF66BBFFWater:|r %d %s", math.floor(water + 0.5), wUnit)
    end
    if #order > 0 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = "|cFFFFD700By activity|r"
        for _, act in ipairs(order) do
            local a = byActivity[act]
            local unitStr = (a.unit and a.unit ~= "") and (" " .. a.unit) or ""
            lines[#lines + 1] = string.format("  %s: |cFFFFFFFF%s%s|r in %d session(s)",
                act, tostring(a.amount), unitStr, a.sessions)
        end
    else
        lines[#lines + 1] = " "
        lines[#lines + 1] = "|cFF888888Nothing logged in this period yet. Complete a workout from the reminder frame to start tracking.|r"
    end
    return table.concat(lines, "\n")
end
