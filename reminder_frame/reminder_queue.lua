-- reminder_queue.lua
-- The list of workouts waiting to be done.

local _, WorkoutBuddy = ...

local ReminderQueue = {}
WorkoutBuddy.ReminderQueue = ReminderQueue

local function Queue()
    return WorkoutBuddy.ReminderState.getQueue()
end

--- Add a workout. A workout already in the queue has its amount increased
-- instead of appearing twice.
function ReminderQueue:AddToQueue(activity)
    local queue = Queue()
    for _, w in ipairs(queue) do
        if w.name == activity.name and (w.unit or "") == (activity.unit or "") then
            w.amount = (tonumber(w.amount) or 0) + (tonumber(activity.amount) or 0)
            return
        end
    end
    table.insert(queue, { name = activity.name, amount = tonumber(activity.amount) or 0, unit = activity.unit or "" })
end

function ReminderQueue:SubtractAmount(idx, amt)
    local queue = Queue()
    local w = queue[idx]
    if not w then return end
    w.amount = math.max(0, (tonumber(w.amount) or 0) - (tonumber(amt) or 0))
    if w.amount <= 0 then
        table.remove(queue, idx)
    end
end

function ReminderQueue:RemoveAt(idx)
    local queue = Queue()
    if queue[idx] then table.remove(queue, idx) end
end

function ReminderQueue:Clear()
    wipe(Queue())
end

function ReminderQueue:Count()
    return #Queue()
end
