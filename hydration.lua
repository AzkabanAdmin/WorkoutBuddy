
local _, WorkoutBuddy = ...
WorkoutBuddy = WorkoutBuddy or _G.WorkoutBuddy
if WorkoutBuddy and WorkoutBuddy.DbgPrint then
    WorkoutBuddy:DbgPrint("Loaded: hydration.lua")
end

local Hydration = {}

Hydration.DEFAULTS = {
    enabled = false,
    mode = "smart", -- "smart" uses goals; "interval" uses minutes
    total = 32,       -- total ounces per cycle
    timeframe = 120,  -- minutes
    per = 8,          -- ounces per reminder
    interval = 60,    -- minutes for simple interval mode

    sound = "Alarm Clock",
    scale = 1.2,
    alpha = 0.9,
    x = 0,
    y = 0,
    next_time = 0,
    last_time = 0,
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

function Hydration:ApplyOptions()
    if not self.frame then return end
    local o = opts()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", o.x or 0, o.y or 0)
    self.frame:SetScale(o.scale or 1)
    self.frame:SetAlpha(o.alpha or 0.9)
end

function Hydration:CreateFrame()
    if self.frame then return end
    self.frame = CreateFrame("Frame", "WorkoutBuddy_HydrationFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame:SetSize(220, 80)
    self:ApplyOptions()
    self.frame:SetClampedToScreen(true)
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
        local cX, cY = f:GetCenter()
        local pX, pY = UIParent:GetCenter()
        local opt = opts()
        opt.x = math.floor(cX - pX + 0.5)
        opt.y = math.floor(cY - pY + 0.5)
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", opt.x, opt.y)
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
        local cX, cY = self.frame:GetCenter()
        local pX, pY = UIParent:GetCenter()
        o.x = math.floor(cX - pX + 0.5)
        o.y = math.floor(cY - pY + 0.5)
    end
end

function Hydration:ShowPopup(test)
    self:CreateFrame()
    self:ApplyOptions()
    local o = opts()
    local msg
    if o.mode == "interval" then
        msg = "Time to drink water!"
    else
        msg = string.format("Drink %d oz of water!", o.per or 8)
    end
    self.frame.text:SetText(msg)
    self.frame:Show()

    if not test and o.sound then
        WorkoutBuddy.Sounds:Play(o.sound)
    end
end

function Hydration:PlaySelectedSound()
    local o = opts()
    WorkoutBuddy.Sounds:Play(o.sound)
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

-- Reapply profile settings when the active profile changes
function Hydration:OnProfileChanged()
    local o = opts()
    self:CreateFrame()
    self:ApplyOptions()
    if o.enabled then
        self:Resume()
    else
        self:Stop()
    end
end

if WorkoutBuddy then
    WorkoutBuddy.Hydration = Hydration
else
    _G.WorkoutBuddy_Hydration = Hydration
end
return Hydration

