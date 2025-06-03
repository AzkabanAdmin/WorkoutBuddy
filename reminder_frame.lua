-- reminder_frame.lua
-- This should be the LAST loaded reminder file in your .toc!

WorkoutBuddy:DbgPrint("Loaded: reminder_frame.lua")
WorkoutBuddy:DbgPrint("Init function called")


-- This function should be called after your main addon is initialized!
function WorkoutBuddy.InitReminder()
    WorkoutBuddy.ReminderCore:CreateOrUpdateFrame()
    WorkoutBuddy.ReminderEvents:Register()
end

-- Optionally, make a simple API:
function WorkoutBuddy.ShowReminderFrame()
    WorkoutBuddy.ReminderCore:ShowIfAllowed()
end
