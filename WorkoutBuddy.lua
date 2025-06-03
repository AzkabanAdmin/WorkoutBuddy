local AceDBOptions = LibStub("AceDBOptions-3.0")
local WorkoutBuddy = LibStub("AceAddon-3.0"):NewAddon("WorkoutBuddy", "AceConsole-3.0", "AceEvent-3.0")
_G.WorkoutBuddy = WorkoutBuddy  -- Make it accessible in other files
WorkoutBuddy.DEBUG = false

function WorkoutBuddy:DbgPrint(...)
    if self.DEBUG then
        print("[WorkoutBuddy]", ...)
    end
end


local defaults = {
    profile = {
        custom_workouts = {},
        event_map = {
            levelup = true,
            xpbubble = false,
            zonechange_newarea = false,
            zonechange_zone = false,
            zonechange_indoors = false,
        },
    }
}


function WorkoutBuddy:InitDB()
    if self.db and self.db.profile then return end -- already initialized
    self.db = LibStub("AceDB-3.0"):New("WorkoutBuddyDB", defaults, true)
end

function WorkoutBuddy:OnInitialize()
    self:InitDB()
    if self.InitMinimapButton then
        self:InitMinimapButton()
    end
    -- If workouts is nil or empty, set defaults
    if not self.db.profile.workouts or #self.db.profile.workouts == 0 then
        self.db.profile.workouts = {
            { name = "Drink Water", amount = 8, unit = "oz" },
            { name = "Stretch", amount = 30, unit = "seconds" },
            { name = "Pushups", amount = 10, unit = "reps" },
            { name = "Sit-ups", amount = 15, unit = "reps" },
            { name = "Jumping Jacks", amount = 20, unit = "reps" },
        }
    end
    self:InitConfig()
    WorkoutBuddy.ReminderCore:Init()
    self:RegisterChatCommand("workoutbuddy", "OpenConfig")
    self:RegisterChatCommand("wob", "OpenConfig")
    self:Print("Workout Buddy loaded! Type /workoutbuddy to open settings.")

    -- Listen for AceDB profile events
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset",  "OnProfileChanged")

    if WorkoutBuddy.ReminderEvents then
        WorkoutBuddy.ReminderEvents:Register()
    end

end

function WorkoutBuddy:OnProfileChanged()
    -- Only set defaults if the list is missing or empty
    if not self.db.profile.workouts or #self.db.profile.workouts == 0 then
        self.db.profile.workouts = {
            { name = "Drink Water", amount = 8, unit = "oz" },
            { name = "Stretch", amount = 30, unit = "seconds" },
            { name = "Pushups", amount = 10, unit = "reps" },
            { name = "Sit-ups", amount = 15, unit = "reps" },
            { name = "Jumping Jacks", amount = 20, unit = "reps" },
        }
    end
    self:RebuildWorkoutListOptions()
    self:ForceFullConfigRefresh()

    if WorkoutBuddy.ReminderCore and WorkoutBuddy.ReminderCore.OnProfileChanged then
        WorkoutBuddy.ReminderCore:OnProfileChanged()
    end
end


function WorkoutBuddy:SuggestWorkout(source)
    local workouts = self.db.profile.workouts
    if #workouts == 0 then return end
    local workout = workouts[math.random(#workouts)]
    local msg = workout.name or "Workout"

    if workout.amount and workout.amount > 0 then
        msg = msg .. " - " .. workout.amount
        if workout.unit and workout.unit ~= "" then
            msg = msg .. " " .. workout.unit
        end
    end

    self:DbgPrint("Workout Buddy ("..(source or "Event").."): " .. msg)

    -- Add to reminder queue!
    if WorkoutBuddy.ReminderQueue and WorkoutBuddy.ReminderCore then
        WorkoutBuddy.ReminderQueue:AddToQueue(workout)
        WorkoutBuddy.ReminderCore:UpdateDisplay()
        WorkoutBuddy:StartMinimapPulse()
    end
end

-- Helper function to fully refresh the config UI
function WorkoutBuddy:ForceFullConfigRefresh()
    -- Rebuild options from current profile and update config UI
    self:RebuildWorkoutListOptions()
    -- If using AceConfigDialog, close and re-open to force UI to update
    if InterfaceOptionsFrame then
        InterfaceOptionsFrame:Hide()
        C_Timer.After(0.2, function()
            InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        end)
    end
end
