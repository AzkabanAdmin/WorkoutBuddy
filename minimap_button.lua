-- minimap_button.lua
-- LibDataBroker launcher, minimap button and addon compartment entry.

local _, WorkoutBuddy = ...

local DBIcon = LibStub("LibDBIcon-1.0")
local NAME = "WorkoutBuddy"

local dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(NAME, {
    type = "launcher",
    text = "Workout Buddy",
    icon = WorkoutBuddy.ICON,

    OnClick = function(_, button)
        if button == "RightButton" then
            WorkoutBuddy:OpenConfig()
        elseif IsShiftKeyDown() then
            WorkoutBuddy:SuggestWorkout("Requested", true)
            WorkoutBuddy.ReminderCore:Show()
        else
            WorkoutBuddy.ReminderCore:Toggle()
        end
    end,

    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Workout Buddy")
        local queued = WorkoutBuddy.ReminderQueue:Count()
        tooltip:AddLine(string.format("%d workout(s) waiting", queued), 1, 1, 1)
        tooltip:AddLine(WorkoutBuddy.Stats:GetTodayLine(), 0.7, 1, 0.7, true)
        if not WorkoutBuddy.db.profile.enabled then
            tooltip:AddLine("Automatic suggestions are paused (/wob resume)", 1, 0.4, 0.4, true)
        end
        tooltip:AddLine(" ")
        tooltip:AddLine("|cFFFFFF00Left-Click:|r Show or hide the workout queue")
        tooltip:AddLine("|cFFFFFF00Shift-Click:|r Workout now")
        tooltip:AddLine("|cFFFFFF00Right-Click:|r Settings")
    end,
})

function WorkoutBuddy:InitMinimapButton()
    if not DBIcon:IsRegistered(NAME) then
        DBIcon:Register(NAME, dataObject, self.db.profile.minimap)
    end
end

function WorkoutBuddy:RefreshMinimapButton()
    local db = self.db.profile.minimap
    DBIcon:Refresh(NAME, db)
    if DBIcon.IsButtonCompartmentAvailable and DBIcon:IsButtonCompartmentAvailable() then
        if db.showInCompartment then
            DBIcon:AddButtonToCompartment(NAME)
        else
            DBIcon:RemoveButtonFromCompartment(NAME)
        end
    end
end

function WorkoutBuddy:SetMinimapButtonShown(show)
    self.db.profile.minimap.hide = not show
    self:RefreshMinimapButton()
    self:NotifyConfigChanged()
end

function WorkoutBuddy:SetCompartmentShown(show)
    self.db.profile.minimap.showInCompartment = show and true or false
    self:RefreshMinimapButton()
end

-- Pulse the minimap icon while workouts are waiting.
local pulse = { ticker = nil, dim = false }

function WorkoutBuddy:StartMinimapPulse()
    local button = DBIcon:GetMinimapButton(NAME)
    if not button or pulse.ticker then return end
    pulse.ticker = C_Timer.NewTicker(0.6, function()
        if not button.icon then return end
        pulse.dim = not pulse.dim
        button.icon:SetAlpha(pulse.dim and 0.35 or 1)
    end)
end

function WorkoutBuddy:StopMinimapPulse()
    if pulse.ticker then
        pulse.ticker:Cancel()
        pulse.ticker = nil
    end
    pulse.dim = false
    local button = DBIcon:GetMinimapButton(NAME)
    if button and button.icon then button.icon:SetAlpha(1) end
end
