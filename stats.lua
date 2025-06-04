local WorkoutBuddy = WorkoutBuddy

local Stats = {}

local function timeNow()
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
    if timeframe == "lifetime" then return records end
    local now = timeNow()
    local start
    if timeframe == "week" then
        start = now - 7*86400
    elseif timeframe == "month" then
        local d = date("!*t", now)
        d.day, d.hour, d.min, d.sec = 1,0,0,0
        start = time(d)
    else
        return records
    end
    local out = {}
    for _,r in ipairs(records) do
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
    for _,r in ipairs(recs) do
        total = total + 1
        byActivity[r.activity] = (byActivity[r.activity] or 0) + 1
    end
    local lines = { string.format("Total Activities: %d", total) }
    for act,count in pairs(byActivity) do
        table.insert(lines, string.format("%s: %d", act, count))
    end
    return table.concat(lines, "\n")
end

WorkoutBuddy.Stats = Stats
return Stats
