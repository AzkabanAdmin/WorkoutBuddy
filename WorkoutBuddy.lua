-- WorkoutBuddy.lua
-- Core: addon object, saved variable defaults, client compatibility helpers,
-- workout suggestions and slash commands.

local addonName, ns = ...

local WorkoutBuddy = LibStub("AceAddon-3.0"):NewAddon(ns, "WorkoutBuddy", "AceConsole-3.0", "AceEvent-3.0")
_G.WorkoutBuddy = WorkoutBuddy -- global handle for macros and other addons

WorkoutBuddy.ADDON_NAME = addonName
WorkoutBuddy.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
    or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")) or "dev"
if WorkoutBuddy.VERSION:find("@", 1, true) then
    WorkoutBuddy.VERSION = "dev" -- running from the repository without packaging
end
WorkoutBuddy.ICON = "Interface\\Icons\\Spell_Nature_Strength"
WorkoutBuddy.DEBUG = false

local DB_VERSION = 2

------------------------------------------------------------------------
-- Client compatibility helpers
-- WoW Forever, Midnight (Retail) and Classic Era share most UI code, but
-- some events and APIs only exist on some clients, and modern clients can
-- hand addons "secret" values that cannot be compared or used in math.
------------------------------------------------------------------------
local probeFrame

--- True if the running client knows this event name.
function WorkoutBuddy.IsEventValid(event)
    if type(event) ~= "string" or event == "" or not event:match("^[A-Z0-9_]+$") then
        return false
    end
    if C_EventUtils and C_EventUtils.IsEventValid then
        return C_EventUtils.IsEventValid(event) and true or false
    end
    probeFrame = probeFrame or CreateFrame("Frame")
    local ok = pcall(probeFrame.RegisterEvent, probeFrame, event)
    if ok then probeFrame:UnregisterEvent(event) end
    return ok
end

--- Register an event on a plain frame only if the client supports it.
function WorkoutBuddy.SafeRegisterEvent(frame, event)
    if WorkoutBuddy.IsEventValid(event) then
        frame:RegisterEvent(event)
        return true
    end
    return false
end

--- True if the value is a secret value that addons may not inspect.
function WorkoutBuddy.IsSecret(value)
    local check = _G.issecretvalue
    return check ~= nil and check(value) == true
end

--- Which game this is: "forever", "classic" (Classic Era and other classic
-- clients) or "retail", from the client's interface number.
function WorkoutBuddy.GameFlavor()
    local iface = GetBuildInfo and tonumber((select(4, GetBuildInfo()))) or 0
    if iface >= 100000 then return "retail" end
    if iface >= 16000 and iface < 17000 then return "forever" end
    return "classic"
end

-- Content each game actually has. Forever runs on the modern engine, so
-- modern event names exist there even without the content; this table
-- hides those options. A probe that finds the content in the running client
-- wins over the table, so a client that adds it later shows it by itself.
-- Keep this current when adding content-based options (see CLAUDE.md).
WorkoutBuddy.GAME_CONTENT = {
    keystones = { retail = true,
        probe = function()
            local maps = C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapTable()
            return type(maps) == "table" and #maps > 0
        end },
    achievements = { retail = true, forever = true },
    dungeon_finder = { retail = true, forever = true },
    battlegrounds = { retail = true, forever = true, classic = true },
}

--- True if the running game has this kind of content.
function WorkoutBuddy.HasContent(feature)
    local c = WorkoutBuddy.GAME_CONTENT[feature]
    if not c then return true end
    if c[WorkoutBuddy.GameFlavor()] then return true end
    if c.probe then
        local ok, found = pcall(c.probe)
        if ok and found then return true end
    end
    return false
end

-- Game events that only matter where their content exists.
WorkoutBuddy.EVENT_CONTENT = {
    CHALLENGE_MODE_COMPLETED = "keystones", CHALLENGE_MODE_START = "keystones", CHALLENGE_MODE_RESET = "keystones",
    ACHIEVEMENT_EARNED = "achievements", CRITERIA_UPDATE = "achievements",
    LFG_UPDATE = "dungeon_finder", LFG_PROPOSAL_SHOW = "dungeon_finder", LFG_COMPLETION_REWARD = "dungeon_finder",
    UPDATE_BATTLEFIELD_STATUS = "battlegrounds",
}

--- True if the client knows the event and the game has its content.
function WorkoutBuddy.IsEventUseful(event)
    if not WorkoutBuddy.IsEventValid(event) then return false end
    local feature = WorkoutBuddy.EVENT_CONTENT[event]
    return feature == nil or WorkoutBuddy.HasContent(feature)
end

--- Current Unix time (server time where available).
function WorkoutBuddy.Now()
    return (GetServerTime and GetServerTime()) or time()
end

--- Unix time of local midnight for the given timestamp (default now).
function WorkoutBuddy.DayStart(ts)
    local d = date("*t", ts or WorkoutBuddy.Now())
    return time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
end

--- "YYYY-MM-DD" key in local time.
function WorkoutBuddy.DayKey(ts)
    return date("%Y-%m-%d", ts or WorkoutBuddy.Now())
end

function WorkoutBuddy.InCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player") == true)
end

function WorkoutBuddy:DbgPrint(...)
    if self.DEBUG then
        print("|cFF33FF99[WorkoutBuddy]|r", ...)
    end
end

-- NotifyConfigChanged, OpenConfig and InitConfig live in ui/window.lua.

------------------------------------------------------------------------
-- Copy helper (shows a selectable edit box; addons cannot write the
-- system clipboard on every client)
------------------------------------------------------------------------
function WorkoutBuddy:CopyToClipboard(text)
    if not StaticPopupDialogs["WORKOUTBUDDY_COPY"] then
        StaticPopupDialogs["WORKOUTBUDDY_COPY"] = {
            text = "Press Ctrl-C to copy:",
            button1 = CLOSE or "Close",
            hasEditBox = true,
            editBoxWidth = 350,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            OnShow = function(popup, data)
                local box = (popup.GetEditBox and popup:GetEditBox()) or popup.editBox or popup.EditBox
                if box then
                    box:SetText(data or popup.data or "")
                    box:SetFocus()
                    box:HighlightText()
                end
            end,
            EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        }
    end
    StaticPopup_Show("WORKOUTBUDDY_COPY", nil, nil, text)
end

------------------------------------------------------------------------
-- Saved variables
------------------------------------------------------------------------
WorkoutBuddy.DEFAULT_WORKOUTS = {
    { name = "Stand Up & Stretch", amount = 30, unit = "seconds" },
    { name = "Push-ups", amount = 10, unit = "reps" },
    { name = "Sit-ups", amount = 15, unit = "reps" },
    { name = "Jumping Jacks", amount = 20, unit = "reps" },
    { name = "Chair Squats", amount = 10, unit = "reps" },
    { name = "Look Away From Screen", amount = 20, unit = "seconds" },
}

local defaults = {
    profile = {
        enabled = true,
        theme = "forest", -- settings and workout window colors (ui/widgets.lua THEMES)
        login_message = true,
        workouts = nil, -- seeded from DEFAULT_WORKOUTS on first use
        workouts_seeded = false,
        event_map = {
            levelup = true,
            xpbubble = false,
            zonechange_newarea = false,
            zonechange_zone = false,
            zonechange_indoors = false,
            boss_kill = true,
            challenge_complete = true,
            achievement = false,
            player_death = false,
            quest_turnin = false,
            play_timer = true, -- sedentary break: every N minutes of play
        },
        play_timer_minutes = 45,
        suggest_cooldown = 30, -- seconds between automatic suggestions
        avoid_repeat = true,
        notify = {
            chat = true,
            sound = "None",
        },
        daily_goal = 5,
        triggers = {},
        stats = {},
        hydration = {
            enabled = false,
            mode = "smart", -- "smart" uses goals, "interval" is simple minutes
            unit = "oz",
            total = 32,
            timeframe = 120,
            per = 8,
            interval = 60,
            sound = "Alarm Clock",
            scale = 1.2,
            alpha = 0.95,
            bg_alpha = 0.94, -- background only; alpha fades everything
            auto_hide = 0,
            next_time = 0,
            last_time = 0,
        },
        reminder_frame = {
            scale = 1.0,
            alpha = 0.95,
            width = 340,
            height = 200, -- fits four workouts
            bg_alpha = 0.92, -- background only; alpha fades everything
            locked = false,
            autocenter = true,
            initialized = false,
        },
        reminder_events = {
            taxi = true,
            rested = false,
            quest = true,
            open_empty = false,
            lfg_queue = true,
            afk = false,
            auction_house = false,
            login = true,
            defer_combat = true,
            recap = true, -- after a boss fight or leaving an instance: recap and open
        },
        -- Built-in trigger key -> { name, amount, unit } to always add that
        -- workout instead of a random one (e.g. player_death = 5 Burpees)
        builtin_workouts = {},
        reminder_queue = {},
        quiet_hours = {
            clock = "local", -- "local" (computer clock) or "realm"
            workouts = {
                enabled = false,
                start = 22 * 60, -- minutes since midnight
                stop = 7 * 60,
                days = { true, true, true, true, true, true, true }, -- 1 = Sunday
                mode = "pause", -- "pause" skips suggestions, "collect" queues them silently
            },
            hydration = {
                enabled = false,
                start = 22 * 60,
                stop = 7 * 60,
                days = { true, true, true, true, true, true, true },
                mode = "pause", -- "pause" skips reminders, "silent" shows them without sound
            },
        },
        minimap = {
            hide = false,
            showInCompartment = true,
        },
        db_version = 0,
    },
}
WorkoutBuddy.defaults = defaults

local function CopyWorkouts(list)
    local out = {}
    for i, w in ipairs(list) do
        out[i] = { name = w.name, amount = w.amount, unit = w.unit }
    end
    return out
end
WorkoutBuddy.CopyWorkouts = CopyWorkouts

--- Bring older or freshly created profiles up to date.
function WorkoutBuddy:MigrateProfile()
    local p = self.db.profile

    -- Seed the starter list once. Users who delete everything keep an empty list.
    if not p.workouts_seeded then
        if type(p.workouts) ~= "table" or #p.workouts == 0 then
            p.workouts = CopyWorkouts(self.DEFAULT_WORKOUTS)
        end
        p.workouts_seeded = true
    end
    p.workouts = p.workouts or {}

    -- Sanitize workout entries
    for i = #p.workouts, 1, -1 do
        local w = p.workouts[i]
        if type(w) ~= "table" or type(w.name) ~= "string" or w.name == "" then
            table.remove(p.workouts, i)
        else
            w.amount = tonumber(w.amount) or 1
            w.unit = type(w.unit) == "string" and w.unit or ""
            w.category = nil
        end
    end

    -- Triggers from older versions may lack an options table; imports may be malformed
    p.triggers = type(p.triggers) == "table" and p.triggers or {}
    for i = #p.triggers, 1, -1 do
        local t = p.triggers[i]
        if type(t) ~= "table" or type(t.event) ~= "string" then
            table.remove(p.triggers, i)
        else
            t.options = type(t.options) == "table" and t.options or {}
            t.name = type(t.name) == "string" and t.name or ""
            if t.custom ~= nil and type(t.custom) ~= "string" then t.custom = nil end
            if t.customEvent ~= nil and type(t.customEvent) ~= "string" then t.customEvent = nil end
        end
    end

    self.QuietHours.Sanitize(p.quiet_hours, defaults.profile.quiet_hours)

    -- Set workouts (built-in events and "add a set workout" triggers)
    p.builtin_workouts = type(p.builtin_workouts) == "table" and p.builtin_workouts or {}
    for key, w in pairs(p.builtin_workouts) do
        p.builtin_workouts[key] = self.CleanSetWorkout(w)
    end
    for _, t in ipairs(p.triggers) do
        if t.action == "fixed" then
            t.workout = self.CleanSetWorkout(t.workout)
            if not t.workout then t.action = "workout" end
        end
    end

    -- Fields v1 saved but never used
    local rf = p.reminder_frame
    rf.sound, rf.show_when = nil, nil
    local h = p.hydration
    if h.x == 0 and h.y == 0 then h.x, h.y = nil, nil end -- v1 default put the popup in a corner
    h.initialized = nil
    for _, key in ipairs({ "total", "per", "timeframe", "interval" }) do
        local n = tonumber(h[key])
        h[key] = (n and n > 0) and n or defaults.profile.hydration[key] -- invalid values fall back to defaults
    end
    if p.daily_goal and p.daily_goal < 0 then p.daily_goal = 0 end

    p.db_version = DB_VERSION
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------
function WorkoutBuddy:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("WorkoutBuddyDB", defaults, true)
    self:MigrateProfile()

    if self.Sounds and self.Sounds.Init then self.Sounds:Init() end
    self:InitMinimapButton()
    self:InitConfig()

    self.TriggerManager:Init()
    self.ReminderCore:Init()
    self.ReminderEvents:Register()

    self:RegisterChatCommand("workoutbuddy", "HandleSlashCommand")
    self:RegisterChatCommand("wob", "HandleSlashCommand")

    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
end

function WorkoutBuddy:OnEnable()
    self:RegisterBuiltInEvents()
    self.Hydration:Resume()
    self:StartPlayTimer()

    if self.db.profile.login_message then
        self:Print(string.format("v%s loaded. Type |cFFFFD700/wob help|r for commands.", self.VERSION))
    end

    -- First run of a profile: show the frame once so the player can place it
    local rf = self.db.profile.reminder_frame
    if not rf.initialized then
        rf.initialized = true
        self.ReminderCore:Show()
    end

    local queue = self.ReminderState.getQueue()
    if #queue > 0 then self:StartMinimapPulse() end
end

function WorkoutBuddy:OnProfileChanged()
    self.Demo:Stop(true) -- put real data back into the profile it came from
    self:MigrateProfile()
    self.TriggerManager:RegisterEvents()
    self.ReminderEvents:Register()
    self.ReminderCore:OnProfileChanged()
    self.Hydration:OnProfileChanged()
    self:StartPlayTimer()
    self:RefreshMinimapButton()
    self:ForceFullConfigRefresh()
end

------------------------------------------------------------------------
-- Suggestions
------------------------------------------------------------------------
function WorkoutBuddy:PickWorkout()
    local workouts = self.db.profile.workouts or {}
    local n = #workouts
    if n == 0 then return nil end
    local idx = math.random(n)
    if n > 1 and self.db.profile.avoid_repeat and self.lastWorkoutName then
        for _ = 1, 4 do
            if workouts[idx].name ~= self.lastWorkoutName then break end
            idx = math.random(n)
        end
    end
    return workouts[idx]
end

--- Add a random workout to the queue.
-- @param source string  Label for what caused the suggestion.
-- @param manual boolean Manual requests skip the pause and cooldown checks.
function WorkoutBuddy:SuggestWorkout(source, manual)
    local p = self.db.profile
    local quiet = not manual and self.QuietHours:Mode("workouts")
    if not manual then
        if not p.enabled then return end
        if quiet == "pause" then
            self:DbgPrint("Suggestion skipped (quiet hours):", source)
            return
        end
        local cd = tonumber(p.suggest_cooldown) or 0
        local now = GetTime()
        if cd > 0 and self.lastSuggestAt and (now - self.lastSuggestAt) < cd then
            self:DbgPrint("Suggestion skipped (cooldown):", source)
            return
        end
    end

    local workout = self:PickWorkout()
    if not workout then
        if manual then self:Print("Your workout list is empty. Add some in /wob > Workouts.") end
        return
    end

    self.lastSuggestAt = GetTime()
    self.lastWorkoutName = workout.name
    self.playMinutes = 0 -- any break resets the sedentary timer

    self.ReminderQueue:AddToQueue(workout)
    self.ReminderCore:UpdateDisplay()
    if not (self.ReminderFrame and self.ReminderFrame:IsShown()) then
        self:StartMinimapPulse()
    end

    if quiet then return end -- collected silently: no chat line or sound
    if p.notify.chat then
        self:Print(string.format("|cFFAAFFAA%s|r: %s (%s)",
            source or "Workout", self:FormatWorkout(workout), "|cFF888888/wob show|r"))
    end
    if p.notify.sound and p.notify.sound ~= "None" then
        self.Sounds:Play(p.notify.sound)
    end
end

--- A valid copy of a set workout ({ name, amount, unit }), or nil.
function WorkoutBuddy.CleanSetWorkout(w)
    if type(w) ~= "table" or type(w.name) ~= "string" or not w.name:match("%S") then return nil end
    return {
        name = strtrim(w.name),
        amount = math.max(0, tonumber(w.amount) or 0),
        unit = type(w.unit) == "string" and strtrim(w.unit) or "",
    }
end

--- Add a specific workout every time something happens (a potion, a death...).
-- Unlike random suggestions there is no cooldown, so every occurrence counts;
-- repeats merge into one queue row. Chat and sound are skipped in combat,
-- where the recap after the fight covers them.
function WorkoutBuddy:AddSetWorkout(workout, source)
    local p = self.db.profile
    local w = self.CleanSetWorkout(workout)
    if not (p.enabled and w) then return end
    local quiet = self.QuietHours:Mode("workouts")
    if quiet == "pause" then return end

    self.ReminderQueue:AddToQueue(w)
    self.playMinutes = 0
    self.ReminderCore:UpdateDisplay()
    if not (self.ReminderFrame and self.ReminderFrame:IsShown()) then
        self:StartMinimapPulse()
    end

    if quiet or self.InCombat() then return end
    if p.notify.chat then
        self:Print(string.format("|cFFAAFFAA%s|r: %s", source or "Workout", self:FormatWorkout(w)))
    end
    if p.notify.sound and p.notify.sound ~= "None" then
        self.Sounds:Play(p.notify.sound)
    end
end

--- A built-in trigger fired: its set workout if one is chosen, else a random one.
function WorkoutBuddy:FireBuiltIn(key, source)
    local set = self.db.profile.builtin_workouts[key]
    if set then
        self:AddSetWorkout(set, source)
    else
        self:SuggestWorkout(source)
    end
end

function WorkoutBuddy:FormatWorkout(w)
    local s = w.name or "Workout"
    if w.amount and tonumber(w.amount) and tonumber(w.amount) > 0 then
        s = s .. " x" .. tostring(w.amount)
        if w.unit and w.unit ~= "" then s = s .. " " .. w.unit end
    end
    return s
end

function WorkoutBuddy:SetEnabled(on)
    self.db.profile.enabled = on and true or false
    self:Print(on and "Automatic workout suggestions |cFF00FF00resumed|r."
        or "Automatic workout suggestions |cFFFF5555paused|r. Type /wob resume to turn them back on.")
    self:StartPlayTimer()
    self:NotifyConfigChanged()
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local HELP = {
    "|cFFFFD700/wob|r - open settings",
    "|cFFFFD700/wob show|r - show or hide the workout queue",
    "|cFFFFD700/wob now|r - get a workout right now",
    "|cFFFFD700/wob water|r - log a drink of water",
    "|cFFFFD700/wob stats|r - print today's progress",
    "|cFFFFD700/wob pause|r / |cFFFFD700resume|r - pause or resume automatic suggestions",
    "|cFFFFD700/wob quiet|r - show quiet hours status",
    "|cFFFFD700/wob demo|r - sample data for screenshots (your real data is untouched)",
    "|cFFFFD700/wob share|r [today|week|recap] [party|raid|guild|say] - post a summary (only when you type it)",
    "|cFFFFD700/wob uicheck|r - check the settings window for overlapping controls",
    "|cFFFFD700/wob center|r - move the workout and hydration frames to the screen center",
    "|cFFFFD700/wob minimap|r - show or hide the minimap button",
}

function WorkoutBuddy:HandleSlashCommand(input)
    local cmd = strtrim(string.lower(input or ""))
    if cmd == "" or cmd == "config" or cmd == "options" then
        self:OpenConfig()
    elseif cmd == "help" or cmd == "?" then
        self:Print("Commands:")
        for _, line in ipairs(HELP) do print("  " .. line) end
    elseif cmd == "show" or cmd == "toggle" then
        self.ReminderCore:Toggle()
    elseif cmd == "now" or cmd == "suggest" or cmd == "workout" then
        self:SuggestWorkout("Requested", true)
        self.ReminderCore:Show()
    elseif cmd == "water" or cmd == "drink" then
        self.Hydration:LogDrink()
    elseif cmd == "stats" then
        self:Print(self.Stats:GetTodayLine())
    elseif cmd == "pause" or cmd == "off" then
        self:SetEnabled(false)
    elseif cmd == "resume" or cmd == "on" then
        self:SetEnabled(true)
    elseif cmd == "share" or cmd:match("^share ") then
        local what, channel = "today", nil
        for word in cmd:gmatch("%S+") do
            if word == "today" or word == "week" or word == "recap" then what = word
            elseif self.Stats.SHARE_CHANNELS[word:upper()] then channel = word:upper() end
        end
        if not channel then
            local text, why = self.Stats:ShareText(what)
            self:Print("Add where to post it: /wob share " .. what .. " party (or raid, guild, say).")
            print("  " .. (text and ("Preview: " .. text) or why))
        else
            local ok, why = self.Stats:Share(what, channel)
            if not ok then self:Print("|cFFFF5555" .. why .. "|r") end
        end
    elseif cmd == "uicheck" then
        local found = self.SettingsUI:CheckLayout()
        if #found == 0 then
            self:Print("|cFF66FF66No overlapping controls on any settings page.|r")
        else
            self:Print(string.format("|cFFFF5555%d overlap(s) found:|r", #found))
            for i = 1, math.min(#found, 15) do print("  " .. found[i]) end
        end
    elseif cmd == "demo" then
        self.Demo:Toggle()
    elseif cmd == "quiet" then
        local QH = self.QuietHours
        self:Print(QH:ClockLine())
        print("  " .. QH:StatusLine("workouts"))
        print("  " .. QH:StatusLine("hydration"))
    elseif cmd == "center" or cmd == "reset" then
        self.ReminderCore:CenterFrame(true)
        self.Hydration:CenterFrame(true)
        self:Print("Frames centered.")
    elseif cmd == "minimap" then
        self:SetMinimapButtonShown(self.db.profile.minimap.hide)
    elseif cmd == "debug" then
        self.DEBUG = not self.DEBUG
        self:Print("Debug " .. (self.DEBUG and "on" or "off"))
    else
        self:Print("Unknown command. Type /wob help")
    end
end
