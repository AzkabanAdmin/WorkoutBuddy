-- reminder_core.lua
-- The workout queue window: create, lay out and handle clicks.

local _, WorkoutBuddy = ...

local ReminderCore = {}
WorkoutBuddy.ReminderCore = ReminderCore

local ROW_H = 28
local MIN_W, MIN_H, MAX_W, MAX_H = 280, 140, 640, 480
local HEADER_H = 32
local FOOTER_H = 30

local THEME = {
    headerStart = { 0.08, 0.28, 0.12, 0.98 },
    headerEnd   = { 0.04, 0.14, 0.07, 0.92 },
    headerLine  = { 0.35, 0.85, 0.35, 0.8 },
    rowEven     = { 0.06, 0.12, 0.07, 0.18 },
    rowOdd      = { 0.04, 0.08, 0.05, 0.10 },
    rowHover    = { 0.15, 0.40, 0.18, 0.35 },
    btnComplete = { 0.20, 0.90, 0.20 },
    btnPartial  = { 1.00, 0.78, 0.00 },
    btnDismiss  = { 0.90, 0.20, 0.20 },
    titleGold   = "|cFFFFD700",
    labelName   = "|cFFAAFFAA",
    labelAmount = "|cFFCCCCCC",
}

local function Opts()
    return WorkoutBuddy.ReminderState.getProfileOpts()
end

local function Queue()
    return WorkoutBuddy.ReminderState.getQueue()
end

------------------------------------------------------------------------
-- Small widget helpers
------------------------------------------------------------------------
local function ApplyGradient(texture, c1, c2)
    texture:SetColorTexture(1, 1, 1, 1)
    local ok = texture.SetGradient and CreateColor and pcall(texture.SetGradient, texture, "HORIZONTAL",
        CreateColor(c1[1], c1[2], c1[3], c1[4]), CreateColor(c2[1], c2[2], c2[3], c2[4]))
    if not ok then
        texture:SetColorTexture(c1[1], c1[2], c1[3], c1[4])
    end
end

local function ShowTooltip(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

local function MakeActionButton(parent, texture, color, tooltip)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(22, 22)
    btn:SetNormalTexture(texture)
    local r, g, b = color[1], color[2], color[3]
    local nt = btn:GetNormalTexture()
    if nt then nt:SetVertexColor(r, g, b) end
    btn:SetScript("OnEnter", function(self)
        local t = self:GetNormalTexture()
        if t then t:SetVertexColor(math.min(1, r * 1.3), math.min(1, g * 1.3), math.min(1, b * 1.3)) end
        ShowTooltip(self, tooltip)
    end)
    btn:SetScript("OnLeave", function(self)
        local t = self:GetNormalTexture()
        if t then t:SetVertexColor(r, g, b) end
        GameTooltip:Hide()
    end)
    return btn
end

------------------------------------------------------------------------
-- Positioning
------------------------------------------------------------------------
function ReminderCore:ApplyOptions()
    local f = self.frame
    if not f then return end
    local o = Opts()
    f:SetScale(o.scale or 1)
    f:SetAlpha(o.alpha or 0.95)
    f:SetSize(
        math.min(MAX_W, math.max(MIN_W, o.width or 340)),
        math.min(MAX_H, math.max(MIN_H, o.height or 200)))
    f:ClearAllPoints()
    if o.x and o.y then
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", o.x, o.y)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end
    if f.resizer then f.resizer:SetShown(not o.locked) end
end

--- Color the window with the theme chosen in Window & look. Background
-- opacity fades only the backdrop, header and border; text stays solid.
function ReminderCore:ApplyTheme()
    local f = self.frame
    if not f then return end
    local th = WorkoutBuddy.UI.Theme()
    local h, a, bg = th.header, th.accent, th.bg
    local o = Opts()
    local k = tonumber(o.bg_alpha) or 0.92
    ApplyGradient(f.headerBg, { math.min(1, h[1] * 1.7), math.min(1, h[2] * 1.7), math.min(1, h[3] * 1.7), k },
        { h[1], h[2], h[3], k })
    f.headerLine:SetColorTexture(a[1], a[2], a[3], 0.8 * k)
    if f.SetBackdropColor then
        f:SetBackdropColor(bg[1], bg[2], bg[3], k)
        f:SetBackdropBorderColor(a[1] * 0.7, a[2] * 0.7, a[3] * 0.7, math.min(1, k + 0.05))
    end
    self.rowAlpha = k
    self:UpdateDisplay()
end

function ReminderCore:CenterFrame(save)
    if save then
        local o = Opts()
        o.x, o.y = nil, nil
    end
    self:ApplyOptions()
end

local function SavePosition(frame)
    local left, top = frame:GetLeft(), frame:GetTop()
    if left and top then
        local o = Opts()
        o.x, o.y = math.floor(left + 0.5), math.floor(top + 0.5)
    end
end

function ReminderCore:EnsureOnScreen()
    local f = self.frame
    if not f or not Opts().autocenter then return end
    local left, right, top, bottom = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
    if not left then return end
    local sw, sh = UIParent:GetWidth() / f:GetScale(), UIParent:GetHeight() / f:GetScale()
    if right < 0 or left > sw or top < 0 or bottom > sh then
        self:CenterFrame(true)
    end
end

------------------------------------------------------------------------
-- Frame creation
------------------------------------------------------------------------
function ReminderCore:CreateFrame()
    if self.frame then return self.frame end

    local f = CreateFrame("Frame", "WorkoutBuddy_ReminderFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame = f
    WorkoutBuddy.ReminderFrame = f

    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetResizable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    if f.SetResizeBounds then
        f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    elseif f.SetMinResize then
        f:SetMinResize(MIN_W, MIN_H)
        f:SetMaxResize(MAX_W, MAX_H)
    end

    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.04, 0.08, 0.05, 0.92)
    f:SetBackdropBorderColor(0.25, 0.60, 0.25, 0.85)

    -- Header
    local headerBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBg:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    headerBg:SetHeight(HEADER_H)
    f.headerBg = headerBg

    local headerLine = f:CreateTexture(nil, "ARTWORK")
    headerLine:SetPoint("TOPLEFT", headerBg, "BOTTOMLEFT")
    headerLine:SetPoint("TOPRIGHT", headerBg, "BOTTOMRIGHT")
    headerLine:SetHeight(1)
    f.headerLine = headerLine

    local titleIcon = f:CreateTexture(nil, "OVERLAY")
    titleIcon:SetSize(20, 20)
    titleIcon:SetPoint("LEFT", headerBg, "LEFT", 8, 0)
    titleIcon:SetTexture(WorkoutBuddy.ICON)
    titleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("LEFT", titleIcon, "RIGHT", 6, 0)
    f.title:SetText(THEME.titleGold .. "Workout Buddy|r")

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 0, 0)
    f.close:SetScript("OnClick", function() f:Hide() end)

    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(16, 16)
    gear:SetPoint("RIGHT", f.close, "LEFT", -2, 0)
    gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    gear:SetScript("OnClick", function() WorkoutBuddy:OpenConfig() end)
    gear:SetScript("OnEnter", function(self) ShowTooltip(self, "Settings") end)
    gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Scrolling list (mouse wheel; no template needed)
    f.scroll = CreateFrame("ScrollFrame", nil, f)
    f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(HEADER_H + 8))
    f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, FOOTER_H + 4)
    f.scroll:EnableMouseWheel(true)
    f.scroll:SetScript("OnMouseWheel", function(scroll, delta)
        local range = scroll:GetVerticalScrollRange() or 0
        local v = math.max(0, math.min(range, scroll:GetVerticalScroll() - delta * ROW_H))
        scroll:SetVerticalScroll(v)
    end)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(MIN_W, ROW_H)
    f.scroll:SetScrollChild(f.content)
    f.rows = {}

    f.emptyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.emptyLabel:SetPoint("TOPLEFT", f.scroll, "TOPLEFT", 4, -6)
    f.emptyLabel:SetPoint("TOPRIGHT", f.scroll, "TOPRIGHT", -4, -6)
    f.emptyLabel:SetJustifyH("CENTER")
    f.emptyLabel:SetText(THEME.titleGold .. "No workouts queued.|r\n" ..
        "|cFF888888Workouts appear here as you play. Click \"Workout now\" for one right away.|r")

    -- Footer: progress and a button for an instant workout
    f.suggest = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.suggest:SetSize(100, 20)
    f.suggest:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 7)
    f.suggest:SetText("Workout now")

    -- Short progress line that stops before the button instead of running under it
    f.progress = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.progress:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 12)
    f.progress:SetPoint("RIGHT", f.suggest, "LEFT", -6, 0)
    f.progress:SetJustifyH("LEFT")
    f.progress:SetWordWrap(false)
    f.suggest:SetScript("OnClick", function() WorkoutBuddy:SuggestWorkout("Requested", true) end)

    -- Resize grip
    f.resizer = CreateFrame("Button", nil, f)
    f.resizer:SetPoint("BOTTOMRIGHT", -3, 3)
    f.resizer:SetSize(16, 16)
    f.resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    f.resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    f.resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    f.resizer:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    f.resizer:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        local o = Opts()
        o.width, o.height = math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5)
        SavePosition(f)
        ReminderCore:UpdateDisplay()
    end)

    f:SetScript("OnSizeChanged", function() ReminderCore:LayoutRows() end)
    f:SetScript("OnDragStart", function(frame)
        if not Opts().locked then frame:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)
    f:SetScript("OnShow", function()
        WorkoutBuddy:StopMinimapPulse()
        ReminderCore:UpdateDisplay()
    end)
    f:SetScript("OnHide", function()
        if ReminderCore.partialBox then ReminderCore.partialBox:Hide() end
    end)

    tinsert(UISpecialFrames, f:GetName()) -- Escape closes it
    f:Hide()
    self:ApplyOptions()
    self:ApplyTheme()
    return f
end

------------------------------------------------------------------------
-- Rows (pooled and reused)
------------------------------------------------------------------------
local function CreateRow(f)
    local row = CreateFrame("Frame", nil, f.content)
    row:SetHeight(ROW_H)
    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)

    local sep = row:CreateTexture(nil, "BORDER")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", 2, 0)
    sep:SetPoint("BOTTOMRIGHT", -2, 0)
    sep:SetColorTexture(1, 1, 1, 0.06)

    row.btnD = MakeActionButton(row, "Interface\\Buttons\\UI-StopButton", THEME.btnDismiss, "Skip this workout")
    row.btnD:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.btnP = MakeActionButton(row, "Interface\\Buttons\\UI-RefreshButton", THEME.btnPartial, "Log part of it")
    row.btnP:SetPoint("RIGHT", row.btnD, "LEFT", -3, 0)
    row.btnC = MakeActionButton(row, "Interface\\Buttons\\UI-CheckBox-Check", THEME.btnComplete, "Done! Log it")
    row.btnC:SetPoint("RIGHT", row.btnP, "LEFT", -3, 0)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.label:SetPoint("RIGHT", row.btnC, "LEFT", -6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row.btnC:SetScript("OnClick", function() ReminderCore:Complete(row.index) end)
    row.btnP:SetScript("OnClick", function() ReminderCore:ShowPartialInput(row.index) end)
    row.btnD:SetScript("OnClick", function() ReminderCore:Dismiss(row.index) end)

    row:SetScript("OnEnter", function(self)
        local c = THEME.rowHover
        self.bg:SetColorTexture(c[1], c[2], c[3], c[4])
    end)
    row:SetScript("OnLeave", function(self)
        local c = self.baseColor
        self.bg:SetColorTexture(c[1], c[2], c[3], c[4])
    end)
    return row
end

function ReminderCore:LayoutRows()
    local f = self.frame
    if not f then return end
    local w = math.max(MIN_W - 16, (f.scroll:GetWidth() or MIN_W) - 2)
    f.content:SetWidth(w)
    for _, row in ipairs(f.rows) do row:SetWidth(w) end
end

function ReminderCore:UpdateDisplay()
    local f = self.frame
    if not f then return end
    local queue = Queue()

    for i, workout in ipairs(queue) do
        local row = f.rows[i]
        if not row then
            row = CreateRow(f)
            row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
            f.rows[i] = row
        end
        row.index = i
        local base = (i % 2 == 0) and THEME.rowEven or THEME.rowOdd
        local k = self.rowAlpha or 1
        row.baseColor = { base[1], base[2], base[3], base[4] * k }
        local c = row.baseColor
        row.bg:SetColorTexture(c[1], c[2], c[3], c[4])
        local amount = ""
        if tonumber(workout.amount) and tonumber(workout.amount) > 0 then
            amount = string.format("  %s%s %s|r", THEME.labelAmount, tostring(workout.amount), workout.unit or "")
        end
        row.label:SetText(string.format("%s%s|r%s", THEME.labelName, workout.name or "?", amount))
        row:Show()
    end
    for i = #queue + 1, #f.rows do
        f.rows[i]:Hide()
    end

    f.content:SetHeight(math.max(ROW_H, #queue * ROW_H))
    self:LayoutRows()
    f.emptyLabel:SetShown(#queue == 0)
    f.progress:SetText(WorkoutBuddy.Stats:GetShortLine())

    local range = f.scroll:GetVerticalScrollRange() or 0
    if f.scroll:GetVerticalScroll() > range then f.scroll:SetVerticalScroll(range) end

    if #queue == 0 then WorkoutBuddy:StopMinimapPulse() end
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------
function ReminderCore:IndexOf(workout)
    for i, w in ipairs(Queue()) do
        if w == workout then return i end
    end
    return nil
end

function ReminderCore:Complete(idx)
    local w = Queue()[idx]
    if not w then return end
    WorkoutBuddy.Stats:AddRecord(w.name, w.amount, w.unit, false)
    WorkoutBuddy.ReminderQueue:RemoveAt(idx)
    WorkoutBuddy.playMinutes = 0
    self:UpdateDisplay()
end

function ReminderCore:Dismiss(idx)
    WorkoutBuddy.ReminderQueue:RemoveAt(idx)
    self:UpdateDisplay()
end

function ReminderCore:CommitPartial(idx, amt)
    local w = Queue()[idx]
    amt = tonumber(amt) or 0
    if not w or amt <= 0 then return end
    WorkoutBuddy.Stats:AddRecord(w.name, amt, w.unit, true)
    WorkoutBuddy.ReminderQueue:SubtractAmount(idx, amt)
    WorkoutBuddy.playMinutes = 0
    self:UpdateDisplay()
end

function ReminderCore:ShowPartialInput(idx)
    local w = Queue()[idx]
    if not w then return end
    local box = self.partialBox
    if not box then
        box = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        self.partialBox = box
        box:SetSize(200, 52)
        box:SetFrameStrata("DIALOG")
        box:SetClampedToScreen(true)
        box:EnableMouse(true)
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        box:SetBackdropColor(0.05, 0.10, 0.06, 0.95)
        box:SetBackdropBorderColor(0.25, 0.60, 0.25, 0.85)

        box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        box.label:SetPoint("TOPLEFT", 8, -7)
        box.label:SetPoint("TOPRIGHT", -8, -7)
        box.label:SetJustifyH("LEFT")
        box.label:SetWordWrap(false)

        box.edit = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
        box.edit:SetSize(60, 20)
        box.edit:SetPoint("BOTTOMLEFT", 14, 7)
        box.edit:SetAutoFocus(false)
        box.edit:SetNumeric(true)
        box.edit:SetMaxLetters(5)

        -- Look the workout up again on commit: rows above it may have been
        -- removed while the box was open, which shifts its row number.
        local function commit()
            local row = ReminderCore:IndexOf(box.workout)
            if row then ReminderCore:CommitPartial(row, box.edit:GetText()) end
            box:Hide()
        end
        box.edit:SetScript("OnEnterPressed", commit)
        box.edit:SetScript("OnEscapePressed", function() box:Hide() end)

        local ok = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
        ok:SetSize(50, 20)
        ok:SetPoint("LEFT", box.edit, "RIGHT", 6, 0)
        ok:SetText(OKAY or "OK")
        ok:SetScript("OnClick", commit)

        local cancel = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
        cancel:SetSize(60, 20)
        cancel:SetPoint("LEFT", ok, "RIGHT", 4, 0)
        cancel:SetText(CANCEL or "Cancel")
        cancel:SetScript("OnClick", function() box:Hide() end)
    end

    box.workout = w
    box.label:SetText(string.format("|cFFFFD700How many %s did you do?|r",
        (w.unit and w.unit ~= "") and w.unit or "of " .. (w.name or "it")))
    box:ClearAllPoints()
    box:SetPoint("BOTTOM", self.frame, "TOP", 0, 4)
    box.edit:SetText("")
    box:Show()
    box.edit:SetFocus()
end

------------------------------------------------------------------------
-- Show / hide
------------------------------------------------------------------------
function ReminderCore:Show()
    local f = self:CreateFrame()
    if not f:IsShown() then
        self:EnsureOnScreen()
        f:Show()
    else
        self:UpdateDisplay()
    end
end

function ReminderCore:Toggle()
    local f = self:CreateFrame()
    if f:IsShown() then f:Hide() else self:Show() end
end

-- Kept for older macros that called this name
function ReminderCore:ShowIfAllowed()
    self:Show()
end

function ReminderCore:OnProfileChanged()
    self:ApplyOptions()
    self:ApplyTheme()
    self:UpdateDisplay()
end

function ReminderCore:Init()
    self:CreateFrame()
end
