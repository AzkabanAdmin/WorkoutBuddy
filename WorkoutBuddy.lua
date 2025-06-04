local addonName, WorkoutBuddy = ...
local AceDBOptions = LibStub("AceDBOptions-3.0")
WorkoutBuddy = LibStub("AceAddon-3.0"):NewAddon(WorkoutBuddy or {}, "WorkoutBuddy", "AceConsole-3.0", "AceEvent-3.0")
_G.WorkoutBuddy = WorkoutBuddy -- Make it accessible in other files
if _G.WorkoutBuddy_Sounds then
    WorkoutBuddy.Sounds = _G.WorkoutBuddy_Sounds
    _G.WorkoutBuddy_Sounds = nil
end
if _G.WorkoutBuddy_Hydration then
    WorkoutBuddy.Hydration = _G.WorkoutBuddy_Hydration
    _G.WorkoutBuddy_Hydration = nil
end
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
        stats = {},
        hydration = {
            enabled = false,
            mode = "smart", -- "smart" uses goals, "interval" is simple minutes
            total = 32,
            timeframe = 120,
            per = 8,
            interval = 60,

            sound = "Alarm Clock",
            scale = 1.2,
            alpha = 0.9,
            x = 0,
            y = 0,
            next_time = 0,
            last_time = 0,
        },
        -- Reminder frame settings (position, scaling, etc.)
        reminder_frame = {
            x = 400,
            y = 500,
            scale = 1.1,
            alpha = 0.85,
            show_when = "rested",
            sound = 567463,
            autocenter = true,
        },
        -- Stored queue of pending workouts
        reminder_queue = {},
    }
}


function WorkoutBuddy:InitDB()
    if self.db and self.db.profile then return end -- already initialized
    self.db = LibStub("AceDB-3.0"):New("WorkoutBuddyDB", defaults, true)
end

function WorkoutBuddy:OnInitialize()
    self:InitDB()
    if WorkoutBuddy.Sounds and WorkoutBuddy.Sounds.Init then
        WorkoutBuddy.Sounds:Init()
    end
    if self.InitMinimapButton then
        self:InitMinimapButton()
    end
    -- If workouts is nil or empty, set defaults
    if not self.db.profile.workouts or #self.db.profile.workouts == 0 then
        self.db.profile.workouts = {
            { name = "Stretch", amount = 30, unit = "seconds" },
            { name = "Pushups", amount = 10, unit = "reps" },
            { name = "Sit-ups", amount = 15, unit = "reps" },
            { name = "Jumping Jacks", amount = 20, unit = "reps" },
        }
    end
    self:InitConfig()
    WorkoutBuddy.ReminderCore:Init()
    self:RegisterChatCommand("workoutbuddy", "HandleSlashCommand")
    self:RegisterChatCommand("wob", "HandleSlashCommand")
    self:Print("Workout Buddy loaded! Type /workoutbuddy to open settings.")

    -- Listen for AceDB profile events
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset",  "OnProfileChanged")

    if WorkoutBuddy.ReminderEvents then
        WorkoutBuddy.ReminderEvents:Register()
    end

    if WorkoutBuddy.Hydration and WorkoutBuddy.Hydration.Resume then
        WorkoutBuddy.Hydration:Resume()
    end

end

function WorkoutBuddy:OnProfileChanged()
    -- Only set defaults if the list is missing or empty
    if not self.db.profile.workouts or #self.db.profile.workouts == 0 then
        self.db.profile.workouts = {
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

    if WorkoutBuddy.Hydration and WorkoutBuddy.Hydration.OnProfileChanged then
        WorkoutBuddy.Hydration:OnProfileChanged()
    elseif WorkoutBuddy.Hydration and WorkoutBuddy.Hydration.Resume then
        -- Fallback for older versions
        WorkoutBuddy.Hydration:Resume()
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

function WorkoutBuddy:HandleSlashCommand(input)
    input = strtrim(string.lower(input or ""))
    if input == "center" then
        if self.ReminderCore and self.ReminderCore.CenterFrame then
            self.ReminderCore:CenterFrame(true)
            self:Print("Reminder frame centered.")
        end
    else
        self:OpenConfig()
    end
end
