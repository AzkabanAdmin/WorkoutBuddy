-- workout_timer.lua
-- A visual timer for timed workouts (seconds or minutes): a short "get
-- ready" countdown, then the workout's own time with a progress bar, a
-- sound at the end and, if the player wants, the workout logged as done.
-- Started from the stopwatch button on a row of the workout window.

local _, WorkoutBuddy = ...

local Timer = {}
WorkoutBuddy.WorkoutTimer = Timer

local TICK = 0.1

local UNIT_SECONDS = {
    s = 1, sec = 1, secs = 1, second = 1, seconds = 1,
    m = 60, min = 60, mins = 60, minute = 60, minutes = 60,
}

--- How long a workout takes in seconds, or nil if it is not timed.
function WorkoutBuddy.WorkoutSeconds(w)
    if type(w) ~= "table" then return nil end
    local per = UNIT_SECONDS[strtrim(tostring(w.unit or "")):lower()]
    local amount = tonumber(w.amount)
    if not per or not amount or amount <= 0 then return nil end
    return amount * per
end

local function Opts()
    return WorkoutBuddy.db.profile.timer
end

local function Clock(seconds)
    seconds = math.max(0, math.ceil(seconds))
    if seconds >= 60 then return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60) end
    return tostring(seconds)
end

------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------
function Timer:CreateFrame()
    if self.frame then return self.frame end
    local UI = WorkoutBuddy.UI
    local f = CreateFrame("Frame", "WorkoutBuddy_TimerFrame", UIParent)
    self.frame = f
    f:SetSize(280, 156)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then Opts().x, Opts().y = math.floor(left + 0.5), math.floor(top + 0.5) end
    end)
    UI.Box(f, "bg", "accent")

    f.header = UI.Tex(f, "BACKGROUND", "header", nil, 1)
    f.header:SetPoint("TOPLEFT", 1, -1)
    f.header:SetPoint("TOPRIGHT", -1, -1)
    f.header:SetHeight(28)
    f.title = UI.Text(f, "GameFontNormal", "title")
    f.title:SetPoint("LEFT", f.header, "LEFT", 10, 0)
    f.title:SetPoint("RIGHT", f.header, "RIGHT", -10, 0)
    f.title:SetWordWrap(false)

    f.status = UI.Text(f, "GameFontHighlight", "muted")
    f.status:SetPoint("TOP", f.header, "BOTTOM", 0, -8)
    f.status:SetWidth(260)
    f.status:SetJustifyH("CENTER")

    f.number = UI.Text(f, "GameFontNormalHuge", "text")
    f.number:SetPoint("TOP", f.status, "BOTTOM", 0, -4)
    f.number:SetWidth(260)
    f.number:SetJustifyH("CENTER")

    f.track = UI.Tex(f, "ARTWORK", "off")
    f.track:SetPoint("TOPLEFT", 14, -94)
    f.track:SetPoint("TOPRIGHT", -14, -94)
    f.track:SetHeight(6)
    f.bar = UI.Tex(f, "OVERLAY", "accent")
    f.bar:SetPoint("TOPLEFT", f.track, "TOPLEFT")
    f.bar:SetHeight(6)

    f.cancel = UI.Button(f, "Cancel", 110, 24, nil, function() Timer:Cancel() end)
    f.cancel:SetPoint("BOTTOMLEFT", 14, 12)
    f.done = UI.Button(f, "Done", 110, 24, "primary", function() Timer:Finish(true) end)
    f.done:SetPoint("BOTTOMRIGHT", -14, 12)

    f:SetScript("OnHide", function()
        if Timer.running then Timer:Cancel(true) end
    end)
    tinsert(UISpecialFrames, f:GetName()) -- Escape cancels
    f:Hide()
    return f
end

function Timer:Place()
    local f, o = self.frame, Opts()
    f:ClearAllPoints()
    if o.x and o.y then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", o.x, o.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    end
end

------------------------------------------------------------------------
-- Running
------------------------------------------------------------------------
--- Start the timer for a queued workout (the table in the queue).
function Timer:Start(workout)
    local seconds = WorkoutBuddy.WorkoutSeconds(workout)
    if not seconds then return false end
    if self.running then self:Cancel(true) end
    local f = self:CreateFrame()
    self:Place()
    self.workout = workout
    self.duration = seconds
    self.ready = math.max(0, tonumber(Opts().countdown) or 3)
    self.elapsed = 0
    self.startedAt = GetTime() -- measure real time; counting ticks drifts
    self.running = true
    f.title:SetText(WorkoutBuddy:FormatWorkout(workout))
    f.done:SetScript("OnClick", function() Timer:Finish(true) end) -- a finished run swaps it to Close
    f.done:SetLabel("Done")
    f.done:SetEnabledState(true)
    f.cancel:Show()
    self:Draw()
    f:Show()
    self.ticker = C_Timer.NewTicker(TICK, function() Timer:Tick() end)
    return true
end

function Timer:Tick()
    if not self.running then return end
    self.elapsed = GetTime() - self.startedAt
    if self.elapsed >= self.ready + self.duration - 0.001 then
        self:Finish(false)
    else
        self:Draw()
    end
end

function Timer:Draw()
    local f = self.frame
    local width = math.max(1, (f.track:GetWidth() or 252))
    if self.elapsed < self.ready then
        f.status:SetText("Get ready...")
        f.number:SetText(Clock(self.ready - self.elapsed))
        f.bar:SetWidth(1)
        f.bar:SetAlpha(0.35)
    else
        local into = self.elapsed - self.ready
        f.status:SetText(into < 1 and "Go!" or "Keep going")
        f.number:SetText(Clock(self.duration - into))
        f.bar:SetWidth(math.max(1, width * math.min(1, into / self.duration)))
        f.bar:SetAlpha(1)
    end
end

local function StopTicker(self)
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    self.running = false
end

--- The time is up (or the player pressed Done).
function Timer:Finish(early)
    if not self.running then return end
    StopTicker(self)
    local f = self.frame
    local o = Opts()
    if not early then WorkoutBuddy.Sounds:Play(o.sound) end
    local logged = false
    if early or o.log_on_finish then
        local idx = WorkoutBuddy.ReminderCore:IndexOf(self.workout)
        if idx then
            WorkoutBuddy.ReminderCore:Complete(idx)
            logged = true
        end
    end
    f.status:SetText(early and "Nice work." or "Time!")
    f.number:SetText(logged and "Done" or "0")
    f.bar:SetWidth(math.max(1, f.track:GetWidth() or 252))
    f.bar:SetAlpha(1)
    f.cancel:Hide()
    f.done:SetLabel(logged and "Logged" or "Close")
    f.done:SetEnabledState(not logged)
    f.done:SetScript("OnClick", function() f:Hide() end)
    self.workout = nil
    C_Timer.After(logged and 2.5 or 6, function()
        if not Timer.running and f:IsShown() then f:Hide() end
    end)
end

--- Stop without logging anything.
function Timer:Cancel(silent)
    if not self.running then return end
    StopTicker(self)
    self.workout = nil
    if self.frame and not silent then self.frame:Hide() end
end
