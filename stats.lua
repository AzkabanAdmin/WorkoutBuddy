local WorkoutBuddy = WorkoutBuddy

local Stats = {}

local function timeNow()

    -- Use WoW API if available, otherwise fall back to Lua's os.time()
    return (GetServerTime and GetServerTime()) or os.time()
end

function Stats:AddRecord(name, amount, unit, partial)
    if not WorkoutBuddy.db or not WorkoutBuddy.db.profile then return end
    WorkoutBuddy.db.profile.stats = WorkoutBuddy.db.profile.stats or {}
    table.insert(WorkoutBuddy.db.profile.stats, {
        activity = name,
        amount = amount,
        unit = unit,
        partial = partial,
        timestamp = timeNow(),
    })

    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if reg then reg:NotifyChange("WorkoutBuddy") end
end

function Stats:GetRecords()
    if not WorkoutBuddy.db or not WorkoutBuddy.db.profile then return {} end
    return WorkoutBuddy.db.profile.stats or {}
end

local function filterRecords(records, timeframe)
    if timeframe == "lifetime" or not timeframe then return records end

    local now = timeNow()
    local start

    if timeframe == "day" then
        start = now - 86400
    elseif timeframe == "week" then
        start = now - 7 * 86400
    elseif timeframe == "month" then
        local d = date("!*t", now)
        d.day, d.hour, d.min, d.sec = 1, 0, 0, 0
        start = time(d)
    else
        -- Allow custom strings like '5d' or '2w'
        local num, unit = timeframe:match("^(%d+)%s*([dw])$")
        num = tonumber(num)
        if num and unit then
            if unit == "d" then
                start = now - num * 86400
            elseif unit == "w" then
                start = now - num * 7 * 86400
            end
        end
    end

    if not start then return records end

    local out = {}
    for _, r in ipairs(records) do
        if (r.timestamp or 0) >= start then
            table.insert(out, r)
        end
    end
    return out
end

function Stats:GetSummary(timeframe)
    local recs = filterRecords(self:GetRecords(), timeframe)
    local total = 0
    local byActivity = {}

    for _, r in ipairs(recs) do
        total = total + 1
        local key = r.activity
        byActivity[key] = byActivity[key] or { amount = 0, unit = r.unit }
        byActivity[key].amount = byActivity[key].amount + (r.amount or 0)
        if r.unit and r.unit ~= "" then
            byActivity[key].unit = r.unit
        end
    end

    local lines = { string.format("Total Workouts: %d", total) }
    for act, info in pairs(byActivity) do
        local unitStr = info.unit and info.unit ~= "" and (" " .. info.unit) or ""
        table.insert(lines, string.format("%s: %d%s", act, info.amount, unitStr))
    end

    return table.concat(lines, "\n")
end

WorkoutBuddy.Stats = Stats
return Stats
