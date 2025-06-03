WorkoutBuddy:DbgPrint("Loaded: reminder_events.lua")

local ReminderEvents = {}

function ReminderEvents:Register()
    local eventFrame = CreateFrame("Frame")

    -- Just add more events and conditions here as needed
    local eventsToRegister = {
        PLAYER_ENTERING_WORLD = true,
        QUEST_FINISHED = true,
        PLAYER_UPDATE_RESTING = IsResting,
        TAXIMAP_CLOSED = function() return UnitOnTaxi("player") end,
        PLAYER_CONTROL_LOST = function() return UnitOnTaxi("player") end,
        -- Add more!
    }

    for evt in pairs(eventsToRegister) do
        eventFrame:RegisterEvent(evt)
    end

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        local condition = eventsToRegister[event]
        local shouldTrigger = false

        if type(condition) == "function" then
            -- For taxi, need short delay for status to update
            if event == "TAXIMAP_CLOSED" or event == "PLAYER_CONTROL_LOST" then
                C_Timer.After(0.1, function()
                    if condition() then
                        WorkoutBuddy:DbgPrint(event .. " (conditional) triggers Reminder Frame.")
                        if WorkoutBuddy.ReminderCore and WorkoutBuddy.ReminderCore.ShowIfAllowed then
                            WorkoutBuddy.ReminderCore:ShowIfAllowed()
                        end
                    end
                end)
                return
            else
                shouldTrigger = condition()
            end
        else
            shouldTrigger = true
        end

        if shouldTrigger then
            WorkoutBuddy:DbgPrint(event .. " triggers Reminder Frame.")
            if WorkoutBuddy.ReminderCore and WorkoutBuddy.ReminderCore.ShowIfAllowed then
                WorkoutBuddy.ReminderCore:ShowIfAllowed()
            end
        end
    end)
end

WorkoutBuddy.ReminderEvents = ReminderEvents
