-- hydration.lua
-- Water reminders on a timer, with a small movable popup.

local _, WorkoutBuddy = ...

local Hydration = {}
WorkoutBuddy.Hydration = Hydration

local MIN_INTERVAL = 60 -- never remind more often than once a minute

local function opts()
    return WorkoutBuddy.db.profile.hydration
end

------------------------------------------------------------------------
-- Scheduling
------------------------------------------------------------------------
function Hydration:GetInterval()
    local o = opts()
    local seconds
    if o.mode == "interval" then
        seconds = (tonumber(o.interval) or 60) * 60
    else
        local per = math.max(1, tonumber(o.per) or 8)
        local reminders = math.max(1, math.ceil((tonumber(o.total) or 32) / per))
        seconds = ((tonumber(o.timeframe) or 120) * 60) / reminders
    end
    return math.max(MIN_INTERVAL, seconds)
end

function Hydration:Schedule(delay)
    self:Stop()
    local o = opts()
    o.next_time = WorkoutBuddy.Now() + delay
    self.timer = C_Timer.NewTimer(delay, function() Hydration:OnTimer() end)
end

function Hydration:OnTimer()
    self.timer = nil
    local o = opts()
    if not o.enabled then return end
    local quiet = WorkoutBuddy.QuietHours:Mode("hydration")
    if quiet ~= "pause" then
        o.last_time = WorkoutBuddy.Now()
        self:ShowPopup(quiet == "silent") -- silent quiet hours: popup without sound
    end
    self:Schedule(self:GetInterval())
end

--- Start a fresh cycle (used when settings change).
function Hydration:Start()
    if not opts().enabled then return self:Stop() end
    self:Schedule(self:GetInterval())
end

function Hydration:Stop()
    if self.timer then
        self.timer:Cancel()
        self.timer = nil
    end
end

--- Continue the saved schedule after login or reload.
function Hydration:Resume()
    local o = opts()
    if not o.enabled then return self:Stop() end
    local delay = (tonumber(o.next_time) or 0) - WorkoutBuddy.Now()
    if delay > self:GetInterval() then delay = self:GetInterval() end
    if delay < 15 then delay = 15 end -- let the UI settle after a loading screen
    self:Schedule(delay)
end

function Hydration:OnProfileChanged()
    if self.frame then
        self.frame:Hide()
        self:ApplyOptions()
        self:ApplyTheme()
    end
    self:Resume()
end

------------------------------------------------------------------------
-- Amounts and units
------------------------------------------------------------------------
local ML_PER_OZ = 29.5735

function Hydration:UnitLabel()
    return opts().unit == "ml" and "ml" or "oz"
end

--- Switch units and convert the saved amounts so goals stay the same.
function Hydration:SetUnit(unit)
    local o = opts()
    if unit == o.unit then return end
    local factor = (unit == "ml") and ML_PER_OZ or (1 / ML_PER_OZ)
    local roundTo = (unit == "ml") and 10 or 1
    local function conv(v)
        local n = (tonumber(v) or 0) * factor
        return math.max(roundTo, math.floor(n / roundTo + 0.5) * roundTo)
    end
    o.total = conv(o.total)
    o.per = conv(o.per)
    o.unit = unit
end

function Hydration:LogDrink(amount)
    local o = opts()
    amount = amount or (o.mode == "interval" and 0 or o.per) or 0
    if amount <= 0 then amount = (o.unit == "ml") and 250 or 8 end
    WorkoutBuddy.Stats:AddWater(amount, self:UnitLabel())
    local total, unit = WorkoutBuddy.Stats:GetTodayWater()
    WorkoutBuddy:Print(string.format("|cFF66BBFFLogged %d %s of water.|r Today: %d %s", amount, self:UnitLabel(), total, unit or ""))
end

------------------------------------------------------------------------
-- Popup frame
------------------------------------------------------------------------
function Hydration:ApplyOptions()
    local f = self.frame
    if not f then return end
    local o = opts()
    f:SetScale(o.scale or 1)
    f:SetAlpha(o.alpha or 0.95)
    f:ClearAllPoints()
    if o.x and o.y then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", o.x, o.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
end

function Hydration:CreateFrame()
    if self.frame then return self.frame end
    local hf = CreateFrame("Frame", "WorkoutBuddy_HydrationFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame = hf
    hf:SetSize(250, 104)
    hf:SetClampedToScreen(true)
    hf:SetFrameStrata("HIGH")
    hf:SetMovable(true)
    hf:EnableMouse(true)
    hf:RegisterForDrag("LeftButton")

    hf:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    local headerBg = hf:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBg:SetPoint("TOPLEFT", hf, "TOPLEFT", 3, -3)
    headerBg:SetPoint("TOPRIGHT", hf, "TOPRIGHT", -3, -3)
    headerBg:SetHeight(26)
    hf.headerBg = headerBg

    local headerLine = hf:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT", headerBg, "BOTTOMLEFT")
    headerLine:SetPoint("TOPRIGHT", headerBg, "BOTTOMRIGHT")
    headerLine:SetHeight(1)
    hf.headerLine = headerLine

    local title = hf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", headerBg, "LEFT", 8, 0)
    title:SetText("Hydration Reminder")
    hf.title = title

    local close = CreateFrame("Button", nil, hf, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() hf:Hide() end)

    hf.text = hf:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    hf.text:SetPoint("TOP", headerBg, "BOTTOM", 0, -10)
    hf.text:SetJustifyH("CENTER")

    local drank = CreateFrame("Button", nil, hf, "UIPanelButtonTemplate")
    drank:SetSize(100, 22)
    drank:SetPoint("BOTTOM", hf, "BOTTOM", -54, 10)
    drank:SetText("Drank it")
    drank:SetScript("OnClick", function()
        Hydration:LogDrink()
        hf:Hide()
    end)

    local later = CreateFrame("Button", nil, hf, "UIPanelButtonTemplate")
    later:SetSize(100, 22)
    later:SetPoint("LEFT", drank, "RIGHT", 8, 0)
    later:SetText("Remind in 10m")
    later:SetScript("OnClick", function()
        Hydration:Schedule(600)
        hf:Hide()
    end)

    hf:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    hf:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            local o = opts()
            o.x, o.y = math.floor(left + 0.5), math.floor(top + 0.5)
        end
    end)
    hf:SetScript("OnHide", function()
        if Hydration.hideTimer then
            Hydration.hideTimer:Cancel()
            Hydration.hideTimer = nil
        end
    end)

    tinsert(UISpecialFrames, hf:GetName())
    hf:Hide()
    self:ApplyOptions()
    self:ApplyTheme()
    return hf
end

local function Hex(c)
    return string.format("|cFF%02X%02X%02X", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

--- Theme colors (Window & look). Background opacity fades only the
-- backdrop, header and border; the message and buttons stay solid.
function Hydration:ApplyTheme()
    local f = self.frame
    if not f then return end
    local th = WorkoutBuddy.UI.Theme()
    local h, a, bg, t = th.header, th.accent, th.bg, th.title
    local k = tonumber(opts().bg_alpha) or 0.94
    if f.SetBackdropColor then
        f:SetBackdropColor(bg[1], bg[2], bg[3], k)
        f:SetBackdropBorderColor(a[1] * 0.7, a[2] * 0.7, a[3] * 0.7, math.min(1, k + 0.05))
    end
    f.headerBg:SetColorTexture(h[1], h[2], h[3], k)
    f.headerLine:SetColorTexture(a[1], a[2], a[3], 0.8 * k)
    f.title:SetTextColor(t[1], t[2], t[3])
    self.textColor, self.amountColor = Hex(a), Hex(t)
    if f:IsShown() then self:SetMessage() end
end

function Hydration:SetMessage()
    local f, o = self.frame, opts()
    local text, amount = self.textColor or "|cFF66BBFF", self.amountColor or "|cFFFFD700"
    if o.mode == "interval" then
        f.text:SetText(text .. "Time to drink some water!|r")
    else
        f.text:SetText(string.format("%sDrink |r%s%d %s|r%s of water!|r", text, amount, o.per or 8, self:UnitLabel(), text))
    end
end

function Hydration:CenterFrame(save)
    self:CreateFrame()
    if save then
        local o = opts()
        o.x, o.y = nil, nil
    end
    self:ApplyOptions()
end

--- Show the popup. `silent` skips the sound (settings preview, silent quiet hours).
function Hydration:ShowPopup(silent)
    local f = self:CreateFrame()
    self:ApplyOptions()
    local o = opts()
    self:ApplyTheme()
    self:SetMessage()
    f:Show()

    if not silent then
        WorkoutBuddy.Sounds:Play(o.sound)
    end

    if self.hideTimer then self.hideTimer:Cancel() end
    self.hideTimer = nil
    local auto = tonumber(o.auto_hide) or 0
    if auto > 0 then
        self.hideTimer = C_Timer.NewTimer(auto, function()
            Hydration.hideTimer = nil
            f:Hide()
        end)
    end
end

function Hydration:PlaySelectedSound()
    WorkoutBuddy.Sounds:Play(opts().sound)
end
