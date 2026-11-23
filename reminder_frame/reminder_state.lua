-- reminder_state.lua
-- Accessors for the reminder frame's saved settings and workout queue.

local _, WorkoutBuddy = ...

local ReminderState = {}
WorkoutBuddy.ReminderState = ReminderState

function ReminderState.getProfileOpts()
    return WorkoutBuddy.db.profile.reminder_frame
end

function ReminderState.getQueue()
    local p = WorkoutBuddy.db and WorkoutBuddy.db.profile
    if not p then return {} end
    if type(p.reminder_queue) ~= "table" then p.reminder_queue = {} end
    return p.reminder_queue
end
