---@diagnostic disable: undefined-field, need-check-nil
WorkoutBuddy:DbgPrint("Loaded: reminder_core.lua")

local WorkoutBuddy = WorkoutBuddy
local ReminderState = WorkoutBuddy.ReminderState
local ReminderQueue = WorkoutBuddy.ReminderQueue

local ReminderCore = {}


--------------------------------------------------------
-- Utility Functions
--------------------------------------------------------

local function SetTooltip(frame, text)
    if not frame then return end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
end

function ReminderCore:ShowIfAllowed()
    -- Only open if frame exists and not already open
    if WorkoutBuddy.ReminderFrame and not WorkoutBuddy.ReminderFrame:IsShown() then
        self:UpdateDisplay()
        WorkoutBuddy.ReminderFrame:Show()
        WorkoutBuddy:StopMinimapPulse()
    elseif not WorkoutBuddy.ReminderFrame then
        self:CreateOrUpdateFrame()
        self:UpdateDisplay()
        WorkoutBuddy.ReminderFrame:Show()
        WorkoutBuddy:StopMinimapPulse()
    end
end


--------------------------------------------------------
-- Frame Creation
--------------------------------------------------------
function ReminderCore:CreateOrUpdateFrame()
    if WorkoutBuddy.ReminderFrame then return end -- Already created
    WorkoutBuddy:DbgPrint("ReminderCore: Creating Frame")

    local opts = ReminderState.getProfileOpts()  -- FIX: define opts

    WorkoutBuddy.ReminderFrame = CreateFrame("Frame", "WorkoutBuddy_ReminderFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    WorkoutBuddy.ReminderFrame:SetSize(320, 140)
    WorkoutBuddy.ReminderFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    WorkoutBuddy.ReminderFrame:SetScale(opts.scale or 1.1)
    WorkoutBuddy.ReminderFrame:SetAlpha(opts.alpha or 0.85)
    WorkoutBuddy.ReminderFrame:SetMovable(true)
    WorkoutBuddy.ReminderFrame:EnableMouse(true)
    WorkoutBuddy.ReminderFrame:RegisterForDrag("LeftButton")
    WorkoutBuddy.ReminderFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    WorkoutBuddy.ReminderFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetLeft(), self:GetTop()
        opts.x, opts.y = math.floor(x + 0.5), math.floor(y + 0.5)
    end)

    WorkoutBuddy.ReminderFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    WorkoutBuddy.ReminderFrame:SetBackdropColor(0, 0, 0, 0.85)

    -- Title
    WorkoutBuddy.ReminderFrame.title = WorkoutBuddy.ReminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    WorkoutBuddy.ReminderFrame.title:SetPoint("TOP", WorkoutBuddy.ReminderFrame, "TOP", 0, -12)
    WorkoutBuddy.ReminderFrame.title:SetText("Workout Buddy")

    -- Close button
    WorkoutBuddy.ReminderFrame.close = CreateFrame("Button", nil, WorkoutBuddy.ReminderFrame, "UIPanelCloseButton")
    WorkoutBuddy.ReminderFrame.close:SetPoint("TOPRIGHT", -4, -4)
    WorkoutBuddy.ReminderFrame.close:SetScript("OnClick", function() WorkoutBuddy.ReminderFrame:Hide() end)

    -- Workout display area
    WorkoutBuddy.ReminderFrame.scroll = CreateFrame("ScrollFrame", nil, WorkoutBuddy.ReminderFrame, "UIPanelScrollFrameTemplate")
    WorkoutBuddy.ReminderFrame.scroll:SetPoint("TOPLEFT", 14, -36)
    WorkoutBuddy.ReminderFrame.scroll:SetPoint("BOTTOMRIGHT", -34, 38)
    WorkoutBuddy.ReminderFrame.content = CreateFrame("Frame", nil, WorkoutBuddy.ReminderFrame)
    WorkoutBuddy.ReminderFrame.content:SetSize(250, 80)
    WorkoutBuddy.ReminderFrame.scroll:SetScrollChild(WorkoutBuddy.ReminderFrame.content)
    WorkoutBuddy.ReminderFrame.items = {}

    WorkoutBuddy.ReminderFrame:SetScript("OnHide", function(self)
        ReminderCore.currentIndex = nil
    end)
    tinsert(UISpecialFrames, WorkoutBuddy.ReminderFrame:GetName())
    WorkoutBuddy.ReminderFrame:Hide()
    WorkoutBuddy.ReminderFrame:SetAlpha(1)
    WorkoutBuddy.ReminderFrame:SetFrameStrata("HIGH")
    WorkoutBuddy:DbgPrint("ReminderCore: Frame forced to show and alpha 1.")

    -- Resizer in bottom-right
    WorkoutBuddy.ReminderFrame.resizer = CreateFrame("Button", nil, WorkoutBuddy.ReminderFrame)
    WorkoutBuddy.ReminderFrame.resizer:SetPoint("BOTTOMRIGHT", -4, 4)
    WorkoutBuddy.ReminderFrame.resizer:SetSize(16, 16)
    WorkoutBuddy.ReminderFrame.resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    WorkoutBuddy.ReminderFrame.resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    WorkoutBuddy.ReminderFrame.resizer:SetScript("OnMouseDown", function(self)
        WorkoutBuddy.ReminderFrame:StartSizing("BOTTOMRIGHT")
    end)
    WorkoutBuddy.ReminderFrame.resizer:SetScript("OnMouseUp", function(self)
    WorkoutBuddy.ReminderFrame:StopMovingOrSizing()
    -- Enforce min/max manually
    local w, h = WorkoutBuddy.ReminderFrame:GetWidth(), WorkoutBuddy.ReminderFrame:GetHeight()
    local minW, minH, maxW, maxH = 200, 100, 600, 400
    if w < minW then WorkoutBuddy.ReminderFrame:SetWidth(minW) elseif w > maxW then WorkoutBuddy.ReminderFrame:SetWidth(maxW) end
    if h < minH then WorkoutBuddy.ReminderFrame:SetHeight(minH) elseif h > maxH then WorkoutBuddy.ReminderFrame:SetHeight(maxH) end
    ReminderCore:UpdateDisplay()
    end)
    WorkoutBuddy.ReminderFrame:SetResizable(true)
    local minW, minH = 300, 120
    WorkoutBuddy.ReminderFrame:SetScript("OnSizeChanged", function(self, width, height)
        if width < minW then self:SetWidth(minW) end
        if height < minH then self:SetHeight(minH) end
        ReminderCore:UpdateDisplay()
    end)

 


end

--------------------------------------------------------
-- Queue and Display Logic
--------------------------------------------------------
function ReminderCore:UpdateDisplay()
    if not WorkoutBuddy.ReminderFrame then return end
    local queue = ReminderState.getQueue()

    -- Always remove old items FIRST
    for _, child in ipairs(WorkoutBuddy.ReminderFrame.items or {}) do
        child:Hide()
        child:SetParent(nil)
    end
    wipe(WorkoutBuddy.ReminderFrame.items)

    -- Handle empty queue (show message, not hide frame)
    if #queue == 0 then
        -- Show empty message label
        if not WorkoutBuddy.ReminderFrame.emptyLabel then
            local label = WorkoutBuddy.ReminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            label:SetPoint("CENTER", WorkoutBuddy.ReminderFrame, "CENTER", 0, 0)
            label:SetText("No workouts queued!")
            WorkoutBuddy.ReminderFrame.emptyLabel = label
        end
        WorkoutBuddy.ReminderFrame.emptyLabel:Show()
        -- Optionally hide content scroll area if you want
        if WorkoutBuddy.ReminderFrame.scroll then
            WorkoutBuddy.ReminderFrame.scroll:Hide()
        end
        return
    else
        -- Hide the empty label if showing rows
        if WorkoutBuddy.ReminderFrame.emptyLabel then
            WorkoutBuddy.ReminderFrame.emptyLabel:Hide()
        end
        if WorkoutBuddy.ReminderFrame.scroll then
            WorkoutBuddy.ReminderFrame.scroll:Show()
        end
    end

    local rowWidth = WorkoutBuddy.ReminderFrame.scroll:GetWidth() - 10
    local rowHeight = 26
    local y = -4

    for i, workout in ipairs(queue) do
        -- Row container frame
        local rowFrame = CreateFrame("Frame", nil, WorkoutBuddy.ReminderFrame.content)
        rowFrame:SetSize(rowWidth, rowHeight)
        rowFrame:SetPoint("TOPLEFT", 0, y)

        -- Optional: alternating row color
        local r, g, b, a = 0, 0, 0, (i % 2 == 0) and 0.10 or 0.18
        rowFrame.bg = rowFrame:CreateTexture(nil, "BACKGROUND")
---@diagnostic disable-next-line: param-type-mismatch
        rowFrame.bg:SetAllPoints(true)
        rowFrame.bg:SetColorTexture(r, g, b, a)

        -- Workout label
        local label = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", 4, 0)
        label:SetWidth(rowWidth - 96)
        label:SetJustifyH("LEFT")
        label:SetText(string.format("%d. %s: %s %s", i, workout.name, workout.amount, workout.unit or ""))
        label:SetWordWrap(true)
        label:SetMaxLines(3)

        -- 1. Complete Button (green check)
        local btnComplete = CreateFrame("Button", nil, rowFrame)
        btnComplete:SetSize(22, 22)
        btnComplete:SetPoint("LEFT", label, "RIGHT", 4, 0)
        btnComplete:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Check")
        btnComplete:SetScript("OnClick", function()
            ReminderQueue:RemoveAt(i)
            ReminderCore:UpdateDisplay()
        end)
        SetTooltip(btnComplete, "Mark as complete")

        -- 2. Partial Button (refresh icon)
        local btnPartial = CreateFrame("Button", nil, rowFrame)
        btnPartial:SetSize(22, 22)
        btnPartial:SetPoint("LEFT", btnComplete, "RIGHT", 2, 0)
        btnPartial:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton")
        btnPartial:SetScript("OnClick", function()
            ReminderCore:ShowPartialInput(i, workout)
        end)
        SetTooltip(btnPartial, "Partial complete")

        -- 3. Dismiss Button (stop icon)
        local btnDismiss = CreateFrame("Button", nil, rowFrame)
        btnDismiss:SetSize(22, 22)
        btnDismiss:SetPoint("LEFT", btnPartial, "RIGHT", 2, 0)
        btnDismiss:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
        btnDismiss:SetScript("OnClick", function()
            ReminderQueue:RemoveAt(i)
            ReminderCore:UpdateDisplay()
        end)
        SetTooltip(btnDismiss, "Dismiss/remove")

        -- Optional: thin separator line at bottom of each row
        local sep = rowFrame:CreateTexture(nil, "BORDER")
        sep:SetColorTexture(1,1,1,0.08)
        sep:SetHeight(1)
        sep:SetPoint("BOTTOMLEFT", 2, 0)
        sep:SetPoint("BOTTOMRIGHT", -2, 0)

        -- Save for cleanup
        WorkoutBuddy.ReminderFrame.items[#WorkoutBuddy.ReminderFrame.items+1] = rowFrame

        y = y - rowHeight
    end

    WorkoutBuddy.ReminderFrame.content:SetHeight(-y + 6)
end



function ReminderCore:ShowPartialInput(index, workout)
    if WorkoutBuddy.ReminderFrame.partialBox then
        WorkoutBuddy.ReminderFrame.partialBox:Hide()
        WorkoutBuddy.ReminderFrame.partialBox = nil
    end

    -- Small input box with OK/Cancel, anchored under the correct row
    local box = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)

    box:SetSize(120, 32)
    box:SetPoint("BOTTOM", WorkoutBuddy.ReminderFrame, "TOP", 0, 10)
    box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    box:SetBackdropColor(0,0,0,0.85)

    local edit = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
    edit:SetSize(36, 24)
    edit:SetPoint("LEFT", 6, 0)
    edit:SetAutoFocus(true)
    edit:SetNumeric(true)
    edit:SetText("")
    edit:SetScript("OnEnterPressed", function()
        local amt = tonumber(edit:GetText()) or 0
        ReminderQueue:SubtractAmount(index, amt)
        box:Hide()
        ReminderCore:UpdateDisplay()
    end)

    local ok = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    ok:SetSize(32, 24)
    ok:SetPoint("LEFT", edit, "RIGHT", 4, 0)
    ok:SetText("OK")
    ok:SetScript("OnClick", function()
        local amt = tonumber(edit:GetText()) or 0
        ReminderQueue:SubtractAmount(index, amt)
        box:Hide()
        ReminderCore:UpdateDisplay()
    end)

    local cancel = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
    cancel:SetSize(28, 24)
    cancel:SetPoint("LEFT", ok, "RIGHT", 2, 0)
    cancel:SetText("X")
    cancel:SetScript("OnClick", function()
        box:Hide()
    end)

    WorkoutBuddy.ReminderFrame.partialBox = box
    box:Show()
    edit:SetFocus()
end

--------------------------------------------------------
-- Actions
--------------------------------------------------------
function ReminderCore:HandleComplete()
    local idx = ReminderCore.currentIndex or 1
    local queue = ReminderState.getQueue()
    if queue[idx] then
        ReminderQueue:RemoveAt(idx)
        ReminderCore:UpdateDisplay()
    end
end

function ReminderCore:HandlePartial()
    local idx = ReminderCore.currentIndex or 1
    local queue = ReminderState.getQueue()
    if queue[idx] then
        local amt = tonumber(WorkoutBuddy.ReminderFrame.inputPartial:GetText()) or 0
        if amt > 0 then
            ReminderQueue:SubtractAmount(idx, amt)
            ReminderCore:UpdateDisplay()
        end
    end
end

function ReminderCore:HandleDismiss()
    local idx = ReminderCore.currentIndex or 1
    local queue = ReminderState.getQueue()
    if queue[idx] then
        ReminderQueue:RemoveAt(idx)
        ReminderCore:UpdateDisplay()
    end
end

--------------------------------------------------------
-- Utility: For Testing
--------------------------------------------------------
function ReminderCore:DebugAddTest()
    ReminderQueue:AddToQueue({ name = "Debug Pushups", amount = 10, unit = "reps" })
    ReminderCore:UpdateDisplay()
end

--------------------------------------------------------
-- Initialization
--------------------------------------------------------
function ReminderCore:Init()
    WorkoutBuddy:DbgPrint("ReminderCore: Init function called")
    self:CreateOrUpdateFrame()
    -- Optionally, show test reminder on load
    -- self:DebugAddTest()
end

WorkoutBuddy.ReminderCore = ReminderCore

-- You MUST call this in your addon loader or main file:
-- WorkoutBuddy.ReminderCore:Init()

return ReminderCore
