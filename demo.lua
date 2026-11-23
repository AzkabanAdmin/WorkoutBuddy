-- demo.lua
-- Screenshot mode (/wob demo). Swaps in a sample queue and a week of sample
-- history so every window looks lived-in, then puts the real data back.
-- The real queue and stats are never changed: the sample tables replace
-- them only while the demo is on, and logging out or reloading restores
-- them before the game saves.

local _, WorkoutBuddy = ...

local Demo = {}
WorkoutBuddy.Demo = Demo

local DAY = 86400

local SAMPLE_QUEUE = {
    { name = "Push-ups", amount = 15, unit = "reps" },
    { name = "Shoulder Rolls", amount = 30, unit = "seconds" },
    { name = "Chair Squats", amount = 12, unit = "reps" },
    { name = "Look Away From Screen", amount = 20, unit = "seconds" },
}

-- Workouts done each day, oldest first (today last). Today stays one short
-- of the default goal so completing a row shows "Daily goal reached!".
local DAILY = { 5, 3, 6, 4, 5, 6, 4 }
local ROTATION = {
    { "Push-ups", 15, "reps" }, { "Jumping Jacks", 20, "reps" }, { "Chair Squats", 12, "reps" },
    { "Stand Up & Stretch", 30, "seconds" }, { "Plank", 30, "seconds" }, { "Wall Sit", 30, "seconds" },
}

--- A week of sample records in time order (GetTodayCount relies on it).
function Demo.BuildHistory(now, waterUnit)
    local records = {}
    local today = WorkoutBuddy.DayStart(now)
    local drink = (waterUnit == "ml") and 250 or 8
    local pick = 0
    for d = 1, #DAILY do
        local dayStart = today - (#DAILY - d) * DAY
        local isToday = (d == #DAILY)
        -- Spread entries over the day; today only up to the current time.
        local span = isToday and math.max(60, now - dayStart - 60) or (14 * 3600)
        local base = isToday and dayStart or (dayStart + 8 * 3600)
        local count = DAILY[d]
        local events = {}
        for i = 1, count do
            pick = pick % #ROTATION + 1
            local r = ROTATION[pick]
            events[#events + 1] = {
                activity = r[1], amount = r[2], unit = r[3],
                partial = (i == 2 and d % 3 == 0) and true or nil,
                timestamp = base + math.floor(span * i / (count + 1)),
            }
        end
        for i = 1, 4 do
            events[#events + 1] = {
                kind = "water", activity = "Water", amount = drink, unit = waterUnit,
                timestamp = base + math.floor(span * (i - 0.5) / 4),
            }
        end
        table.sort(events, function(a, b) return a.timestamp < b.timestamp end)
        for _, e in ipairs(events) do records[#records + 1] = e end
    end
    return records
end

function Demo:IsActive()
    return self.saved ~= nil
end

function Demo:Start()
    if self.saved then return end
    local p = WorkoutBuddy.db.profile
    self.saved = { profile = p, queue = p.reminder_queue, stats = p.stats }

    local queue = {}
    for i, w in ipairs(SAMPLE_QUEUE) do queue[i] = { name = w.name, amount = w.amount, unit = w.unit } end
    p.reminder_queue = queue
    p.stats = Demo.BuildHistory(WorkoutBuddy.Now(), WorkoutBuddy.Hydration:UnitLabel())

    WorkoutBuddy.ReminderCore:Show()
    WorkoutBuddy.ReminderCore:UpdateDisplay()
    WorkoutBuddy.Hydration:ShowPopup(true)
    WorkoutBuddy:NotifyConfigChanged()
    WorkoutBuddy:Print("|cFFFFD700Demo mode on.|r Sample workouts and a week of sample stats are showing; your real data is untouched. "
        .. "Type |cFFFFD700/wob demo|r again to turn it off (reloading also turns it off).")
end

function Demo:Stop(quiet)
    local s = self.saved
    if not s then return end
    self.saved = nil
    s.profile.reminder_queue = s.queue
    s.profile.stats = s.stats
    if quiet then return end
    WorkoutBuddy.ReminderCore:UpdateDisplay()
    if WorkoutBuddy.Hydration.frame then WorkoutBuddy.Hydration.frame:Hide() end
    WorkoutBuddy:NotifyConfigChanged()
    WorkoutBuddy:Print("Demo mode off. Your workouts and stats are back.")
end

function Demo:Toggle()
    if self.saved then self:Stop() else self:Start() end
end

-- Restore real data before the game writes saved variables.
function Demo:OnLogout()
    self:Stop(true)
end

Demo.logoutFrame = CreateFrame("Frame")
Demo.logoutFrame:SetScript("OnEvent", function() Demo:OnLogout() end)
WorkoutBuddy.SafeRegisterEvent(Demo.logoutFrame, "PLAYER_LOGOUT")
