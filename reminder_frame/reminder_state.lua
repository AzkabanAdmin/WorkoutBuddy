WorkoutBuddy:DbgPrint("Loaded: reminder_state.lua")
-- reminder_state.lua
local PROFILE_KEY = "reminder_frame"
local QUEUE_KEY = "reminder_queue"
local DEFAULTS = {
    x = 400, y = 500, scale = 1.1, alpha = 0.85,
    show_when = "rested", sound = 567463,
    autocenter = true,
    initialized = false, -- tracks if frame has been centered at least once
}
local function getProfileOpts()
    if not WorkoutBuddy.db or not WorkoutBuddy.db.profile then return DEFAULTS end
    if not WorkoutBuddy.db.profile[PROFILE_KEY] then
        WorkoutBuddy.db.profile[PROFILE_KEY] = CopyTable(DEFAULTS)
    end
    return WorkoutBuddy.db.profile[PROFILE_KEY]
end
local function getQueue()
    if not WorkoutBuddy.db or not WorkoutBuddy.db.profile then return {} end
    if not WorkoutBuddy.db.profile[QUEUE_KEY] then
        WorkoutBuddy.db.profile[QUEUE_KEY] = {}
    end
    return WorkoutBuddy.db.profile[QUEUE_KEY]
end
local function setQueue(queue)
    if WorkoutBuddy.db and WorkoutBuddy.db.profile then
        WorkoutBuddy.db.profile[QUEUE_KEY] = queue
    end
end

WorkoutBuddy = WorkoutBuddy or {}
WorkoutBuddy.ReminderState = {
    PROFILE_KEY = PROFILE_KEY,
    QUEUE_KEY = QUEUE_KEY,
    DEFAULTS = DEFAULTS,
    getProfileOpts = getProfileOpts,
    getQueue = getQueue,
    setQueue = setQueue,
}
