WorkoutBuddy:DbgPrint("Loaded: reminder_queue.lua")

local ReminderState = WorkoutBuddy.ReminderState
local ReminderQueue = {}

function ReminderQueue:AddToQueue(activity)
    local queue = ReminderState.getQueue()
    for _, w in ipairs(queue) do
        if w.name == activity.name and (w.unit == activity.unit or not activity.unit) then
            w.amount = (w.amount or 0) + (activity.amount or 0)
            ReminderState.setQueue(queue)
            return
        end
    end
    table.insert(queue, CopyTable(activity))
    ReminderState.setQueue(queue)
end

function ReminderQueue:SubtractAmount(idx, amt)
    local queue = ReminderState.getQueue()
    if queue[idx] then
        queue[idx].amount = math.max(0, (queue[idx].amount or 0) - amt)
        if queue[idx].amount <= 0 then
            table.remove(queue, idx)
        end
        ReminderState.setQueue(queue)
    end
end


function ReminderQueue:RemoveAt(idx)
    local queue = ReminderState.getQueue()
    table.remove(queue, idx)
    ReminderState.setQueue(queue)
end

WorkoutBuddy.ReminderQueue = ReminderQueue

