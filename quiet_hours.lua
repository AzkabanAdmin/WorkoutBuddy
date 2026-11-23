-- quiet_hours.lua
-- Daily schedules that pause or silence workouts and hydration reminders,
-- for example no workouts after 10 PM. Workouts and hydration each have
-- their own schedule, days of the week and behavior. Times follow the
-- computer's local clock or the realm clock. Manual requests (/wob now,
-- /wob water) always work.

local _, WorkoutBuddy = ...

local QuietHours = {}
WorkoutBuddy.QuietHours = QuietHours

QuietHours.KINDS = { "workouts", "hydration" }
QuietHours.MODES = {
    workouts = { pause = true, collect = true },
    hydration = { pause = true, silent = true },
}
QuietHours.DAY_NAMES = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

local MINUTES_PER_DAY = 24 * 60

local function Opts()
    return WorkoutBuddy.db.profile.quiet_hours
end

--- Current time on the chosen clock.
-- @return minutes since midnight, weekday (1 = Sunday ... 7 = Saturday)
function QuietHours:Clock()
    if Opts().clock == "realm" then
        if C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime then
            local ok, t = pcall(C_DateAndTime.GetCurrentCalendarTime)
            if ok and type(t) == "table" and t.hour and t.minute and t.weekday then
                return t.hour * 60 + t.minute, t.weekday
            end
        end
        if GetGameTime then
            local h, m = GetGameTime()
            if h and m then
                -- No realm date on this client; the local weekday is the best guess.
                return h * 60 + m, date("*t", WorkoutBuddy.Now()).wday
            end
        end
    end
    local d = date("*t", WorkoutBuddy.Now())
    return d.hour * 60 + d.min, d.wday
end

local function PreviousDay(wday)
    return (wday + 5) % 7 + 1
end

--- Is this kind ("workouts" or "hydration") inside its quiet window now?
-- A window that ends after midnight belongs to the day it started on.
-- Start equal to end means the whole day.
function QuietHours:IsQuiet(kind)
    local s = Opts()[kind]
    if not (s and s.enabled) then return false end
    local start, stop = tonumber(s.start) or 0, tonumber(s.stop) or 0
    local now, wday = self:Clock()
    local day
    if start == stop then
        day = wday
    elseif start < stop then
        if now >= start and now < stop then day = wday end
    elseif now >= start then
        day = wday
    elseif now < stop then
        day = PreviousDay(wday)
    end
    if not day then return false end
    return type(s.days) ~= "table" or s.days[day] ~= false
end

--- The behavior for a kind right now: nil when not quiet, otherwise its mode.
function QuietHours:Mode(kind)
    if not self:IsQuiet(kind) then return nil end
    local mode = Opts()[kind].mode
    return self.MODES[kind][mode] and mode or "pause"
end

------------------------------------------------------------------------
-- Display helpers
------------------------------------------------------------------------
--- "10:00 PM (22:00)" for minutes since midnight.
function QuietHours.FormatTime(mins)
    mins = (tonumber(mins) or 0) % MINUTES_PER_DAY
    local h, m = math.floor(mins / 60), mins % 60
    local h12 = (h % 12 == 0) and 12 or (h % 12)
    return string.format("%d:%02d %s (%02d:%02d)", h12, m, h < 12 and "AM" or "PM", h, m)
end

--- Choices for a time picker in 15 minute steps.
function QuietHours.TimeChoices()
    if not QuietHours.timeValues then
        local values, order = {}, {}
        for mins = 0, MINUTES_PER_DAY - 15, 15 do
            values[mins] = QuietHours.FormatTime(mins)
            order[#order + 1] = mins
        end
        QuietHours.timeValues, QuietHours.timeOrder = values, order
    end
    return QuietHours.timeValues, QuietHours.timeOrder
end

local LABELS = {
    workouts = { pause = "paused", collect = "collected silently" },
    hydration = { pause = "paused", silent = "silent" },
}

--- One line describing a kind's state, for the settings tab and /wob quiet.
function QuietHours:StatusLine(kind)
    local s = Opts()[kind]
    local title = kind == "workouts" and "Workouts" or "Hydration"
    if not (s and s.enabled) then return title .. ": no quiet hours set." end
    local mode = self:Mode(kind)
    if mode then
        local untilText = (s.start == s.stop) and "the end of the day"
            or self.FormatTime(s.stop):gsub(" %(.*%)", "")
        return string.format("%s: |cFFFF8800quiet now (%s)|r until %s.", title, LABELS[kind][mode], untilText)
    end
    return string.format("%s: active. Quiet from %s to %s.", title,
        (self.FormatTime(s.start):gsub(" %(.*%)", "")), (self.FormatTime(s.stop):gsub(" %(.*%)", "")))
end

function QuietHours:ClockLine()
    local now = self:Clock()
    local which = Opts().clock == "realm" and "Realm time" or "Local time"
    return string.format("%s now: %s", which, (self.FormatTime(now):gsub(" %(.*%)", "")))
end

------------------------------------------------------------------------
-- Saved data upkeep (called from MigrateProfile)
------------------------------------------------------------------------
function QuietHours.Sanitize(q, defaults)
    if q.clock ~= "local" and q.clock ~= "realm" then q.clock = defaults.clock end
    for _, kind in ipairs(QuietHours.KINDS) do
        local s, d = q[kind], defaults[kind]
        for _, key in ipairs({ "start", "stop" }) do
            local n = tonumber(s[key])
            s[key] = (n and n >= 0 and n < MINUTES_PER_DAY) and math.floor(n) or d[key]
        end
        if not QuietHours.MODES[kind][s.mode] then s.mode = d.mode end
        if type(s.days) ~= "table" then s.days = {} end
        for i = 1, 7 do
            if type(s.days[i]) ~= "boolean" then s.days[i] = true end
        end
    end
end
