local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("WorkoutBuddy", {
    type = "launcher",
    text = "Workout Buddy",
    icon = "Interface\\Icons\\Spell_Nature_Strength",

    OnClick = function(self, button)
        if button == "LeftButton" then
            -- Ensure frame exists
            if not WorkoutBuddy.ReminderFrame then
                if WorkoutBuddy.ReminderCore then
                    WorkoutBuddy.ReminderCore:CreateOrUpdateFrame()
                end
            end

            -- Always update display before toggling
            if WorkoutBuddy.ReminderCore then
                WorkoutBuddy.ReminderCore:UpdateDisplay()
            end

            if WorkoutBuddy.ReminderFrame then
                if WorkoutBuddy.ReminderFrame:IsShown() then
                    WorkoutBuddy:DbgPrint("Hiding frame")
                    WorkoutBuddy.ReminderFrame:Hide()
                else
                    WorkoutBuddy:DbgPrint("Showing frame")
                    WorkoutBuddy.ReminderFrame:Show()
                    WorkoutBuddy:StopMinimapPulse()
                    -- Ensure UI is refreshed on show
                    if WorkoutBuddy.ReminderCore then
                        WorkoutBuddy.ReminderCore:UpdateDisplay()
                    end
                end
            end

        elseif button == "RightButton" then
            if WorkoutBuddy.OpenConfig then
                WorkoutBuddy:OpenConfig()
            end
        end
    end,




    OnTooltipShow = function(tooltip)
        tooltip:AddLine("Workout Buddy")
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffffff00Left-Click:|r Toggle Workout Buddy Frame")
        tooltip:AddLine("|cffffff00Right-Click:|r Open Settings")
    end,
})

local icon = LibStub("LibDBIcon-1.0")

-- We'll hook into OnInitialize in the main file. This file only sets up the data object.
function WorkoutBuddy:InitMinimapButton()
    icon:Register("WorkoutBuddy", LDB, self.db.profile.minimap)
    self.minimapIcon = icon
end

-- Start pulsing the minimap icon
function WorkoutBuddy:StartMinimapPulse()
    local button = LibStub("LibDBIcon-1.0"):GetMinimapButton("WorkoutBuddy")
    if not button then return end

    -- If already pulsing, do nothing
    if button.pulseTicker then return end

    -- Save original alpha if not already saved
    button.originalAlpha = button.originalAlpha or button:GetAlpha()

    -- Pulse logic: fade in/out
    button.pulseTicker = C_Timer.NewTicker(0.5, function()
        if not button:IsShown() then return end
        local curAlpha = button:GetAlpha()
        button:SetAlpha(curAlpha < 1 and 1 or 0.4)
    end)
end

-- Stop pulsing the minimap icon
function WorkoutBuddy:StopMinimapPulse()
    local button = LibStub("LibDBIcon-1.0"):GetMinimapButton("WorkoutBuddy")
    if not button then return end

    if button.pulseTicker then
        button.pulseTicker:Cancel()
        button.pulseTicker = nil
    end

    -- Restore original alpha
    button:SetAlpha(button.originalAlpha or 1)
end
