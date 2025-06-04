WorkoutBuddy:DbgPrint("Loaded: hydration.lua")

local Hydration = {}

Hydration.DEFAULTS = {
    enabled = false,
    mode = "smart", -- "smart" uses goals; "interval" uses minutes
    total = 32,       -- total ounces per cycle
    timeframe = 120,  -- minutes
    per = 8,          -- ounces per reminder
    interval = 60,    -- minutes for simple interval mode
    sound = "alarm",
    scale = 1.2,
    alpha = 0.9,
    x = 0,
    y = 0,
    next_time = 0,
    last_time = 0,
}

Hydration.soundNames = {
    none = "None",
    alarm = "Alarm Clock",
    raid = "Raid Warning",
    whisper = "Whisper",
}

Hydration.soundMap = {
    none = nil,
    alarm = SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889,
    raid = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959,
    whisper = SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081,
}

local function opts()
    if not WorkoutBuddy.db or not WorkoutBuddy.db.profile then return Hydration.DEFAULTS end
    if not WorkoutBuddy.db.profile.hydration then
        WorkoutBuddy.db.profile.hydration = CopyTable(Hydration.DEFAULTS)
    end
    return WorkoutBuddy.db.profile.hydration
end

function Hydration:GetInterval()
    local o = opts()
    if o.mode == "interval" then
        return (o.interval or 60) * 60
    end
    local reminders = math.max(1, math.ceil((o.total or 32) / (o.per or 8)))
    return ((o.timeframe or 120) * 60) / reminders
end

function Hydration:CreateFrame()
    if self.frame then return end
    local o = opts()
    self.frame = CreateFrame("Frame", "WorkoutBuddy_HydrationFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame:SetSize(220, 80)
    self.frame:SetPoint("CENTER", UIParent, "CENTER", o.x or 0, o.y or 0)
    self.frame:SetScale(o.scale or 1)
    self.frame:SetAlpha(o.alpha or 0.9)
    self.frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    self.frame:SetBackdropColor(0, 0, 0, 0.85)
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    self.frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local x, y = f:GetLeft(), f:GetTop()
        o.x, o.y = math.floor(x + 0.5), math.floor(y + 0.5)
    end)

    self.frame.text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.frame.text:SetPoint("CENTER")
    self.frame.close = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
    self.frame.close:SetPoint("TOPRIGHT", -4, -4)
    self.frame.close:SetScript("OnClick", function() self.frame:Hide() end)
    tinsert(UISpecialFrames, self.frame:GetName())
    self.frame:Hide()
end

function Hydration:CenterFrame(save)
    self:CreateFrame()
    local o = opts()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER")
    if save then
        local x, y = self.frame:GetLeft(), self.frame:GetTop()
        o.x, o.y = math.floor(x + 0.5), math.floor(y + 0.5)
    end
end

function Hydration:ShowPopup(test)
    self:CreateFrame()
    local o = opts()
    self.frame:SetScale(o.scale or 1)
    self.frame:SetAlpha(o.alpha or 0.9)
    local msg
    if o.mode == "interval" then
        msg = "Time to drink water!"
    else
        msg = string.format("Drink %d oz of water!", o.per or 8)
    end
    self.frame.text:SetText(msg)
    self.frame:Show()
    if not test and o.sound and self.soundMap[o.sound] then
        PlaySound(self.soundMap[o.sound], "Master")
    end
end

function Hydration:PlaySelectedSound()
    local o = opts()
    if o.sound and self.soundMap[o.sound] then
        PlaySound(self.soundMap[o.sound], "Master")
    end
end

function Hydration:OnTimer()
    local o = opts()
    o.last_time = GetServerTime()
    self:ShowPopup(false)
    local interval = self:GetInterval()
    o.next_time = o.last_time + interval
    self.timer = C_Timer.NewTimer(interval, function() Hydration:OnTimer() end)
end

function Hydration:Start()
    self:Stop()
    local o = opts()
    if not o.enabled then return end
    local interval = self:GetInterval()
    local now = GetServerTime()
    o.last_time = now
    o.next_time = now + interval
    self.timer = C_Timer.NewTimer(interval, function() Hydration:OnTimer() end)
end

function Hydration:Stop()
    if self.timer and self.timer.Cancel then
        self.timer:Cancel()
        self.timer = nil
    end
end

function Hydration:Resume()
    self:Stop()
    local o = opts()
    if not o.enabled then return end
    local now = GetServerTime()
    local delay = (o.next_time or now) - now
    if delay <= 0 then delay = 1 end
    self.timer = C_Timer.NewTimer(delay, function() Hydration:OnTimer() end)
end

WorkoutBuddy.Hydration = Hydration
return Hydration

