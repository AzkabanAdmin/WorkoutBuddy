-- ui/pages.lua
-- Hydration, Quiet hours, Window, Stats and Profiles pages.

local _, WorkoutBuddy = ...
local UI = WorkoutBuddy.UI
local Settings = WorkoutBuddy.SettingsUI

local function P() return WorkoutBuddy.db.profile end
local function H() return P().hydration end
local function RF() return P().reminder_frame end
local function RE() return P().reminder_events end

local function SoundValues()
    local list = {}
    for name in pairs(WorkoutBuddy.Sounds:GetList()) do list[#list + 1] = name end
    table.sort(list, function(a, b)
        if a == "None" then return true elseif b == "None" then return false end
        return a < b
    end)
    local values = {}
    for _, name in ipairs(list) do values[#values + 1] = { value = name, text = name } end
    return values
end

local function PositiveNumber(text)
    local n = tonumber(text)
    if not n or n <= 0 then return "Enter a number greater than 0." end
end

------------------------------------------------------------------------
-- Hydration
------------------------------------------------------------------------
local function Restart() WorkoutBuddy.Hydration:Start() end

local function NextReminderText()
    local o = H()
    if not o.enabled then return "|cFF888888Hydration reminders are off.|r" end
    local mins = math.floor(WorkoutBuddy.Hydration:GetInterval() / 60 + 0.5)
    local text = string.format("You will be reminded about every |cFFFFD700%d minute(s)|r.", mins)
    local left = (tonumber(o.next_time) or 0) - WorkoutBuddy.Now()
    if left > 0 then text = text .. string.format(" Next reminder in about %d minute(s).", math.ceil(left / 60)) end
    local total, unit = WorkoutBuddy.Stats:GetTodayWater()
    if total > 0 then text = text .. string.format("\nLogged today: |cFF66BBFF%d %s|r", total, unit or "") end
    return text
end

local function Smart() return (H().mode or "smart") == "smart" end

Settings:AddPage({
    key = "hydration",
    label = "Hydration",
    icon = "Interface\\Icons\\INV_Drink_07",
    order = 3,
    count = function() return H().enabled and "on" or "off" end,
    specs = function()
        local unitLabel = function() return WorkoutBuddy.Hydration:UnitLabel() end
        return {
            { type = "section", label = "Hydration reminders",
                desc = "A small popup reminds you to drink water. Click \"Drank it\" on the popup, or type /wob water, to log it." },
            { type = "toggle", label = "Remind me to drink water", keywords = "water hydration enable",
                get = function() return H().enabled end,
                set = function(v)
                    H().enabled = v and true or false
                    if v then WorkoutBuddy.Hydration:Start() else WorkoutBuddy.Hydration:Stop() end
                end },
            { type = "text", text = NextReminderText, role = "text" },
            { type = "select", label = "Reminder style", keywords = "mode goal interval",
                disabled = function() return not H().enabled end,
                values = { { value = "smart", text = "Daily goal over a time window" }, { value = "interval", text = "Every few minutes" } },
                get = function() return H().mode or "smart" end,
                set = function(v) H().mode = v; Restart() end },
            { type = "select", label = "Units", keywords = "ounces milliliters oz ml", width = 160,
                values = { { value = "oz", text = "Ounces (oz)" }, { value = "ml", text = "Milliliters (ml)" } },
                get = function() return H().unit or "oz" end,
                set = function(v) WorkoutBuddy.Hydration:SetUnit(v); Restart() end },
            { type = "input", label = function() return "Drink this much (" .. unitLabel() .. ")" end,
                desc = "Total amount to drink over the time window.", hidden = function() return not Smart() end,
                validate = PositiveNumber,
                get = function() return H().total end, set = function(v) H().total = tonumber(v); Restart() end },
            { type = "slider", label = "Over this many minutes", hidden = function() return not Smart() end,
                min = 15, max = 720, step = 5, unit = "min",
                get = function() return H().timeframe or 120 end, set = function(v) H().timeframe = v; Restart() end },
            { type = "input", label = function() return "Per reminder (" .. unitLabel() .. ")" end,
                desc = "How much to drink each time you are reminded.", hidden = function() return not Smart() end,
                validate = PositiveNumber,
                get = function() return H().per end, set = function(v) H().per = tonumber(v); Restart() end },
            { type = "slider", label = "Remind me every", hidden = Smart,
                min = 5, max = 240, step = 5, unit = "min",
                get = function() return H().interval or 60 end, set = function(v) H().interval = v; Restart() end },
            { type = "select", label = "Sound", keywords = "audio alert",
                values = SoundValues, get = function() return H().sound or "Alarm Clock" end,
                set = function(v) H().sound = v; WorkoutBuddy.Sounds:Play(v) end },
            { type = "slider", label = "Hide the popup after", desc = "0 keeps it until you click it.",
                min = 0, max = 300, step = 5, unit = "seconds",
                get = function() return H().auto_hide or 0 end, set = function(v) H().auto_hide = v end },
            { type = "buttons", search = { label = "Preview, play sound, log a drink", desc = "test hydration popup" }, items = {
                { text = "Preview popup", func = function() WorkoutBuddy.Hydration:ShowPopup(true) end },
                { text = "Play sound", func = function() WorkoutBuddy.Hydration:PlaySelectedSound() end },
                { text = "Log a drink now", func = function() WorkoutBuddy.Hydration:LogDrink() end },
            } },
        }
    end,
})

------------------------------------------------------------------------
-- Quiet hours
------------------------------------------------------------------------
local QH = function() return WorkoutBuddy.QuietHours end

local function TimeValues()
    local values, order = QH().TimeChoices()
    local out = {}
    for _, mins in ipairs(order) do out[#out + 1] = { value = mins, text = values[mins] } end
    return out
end

local DAY_SHORT = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

local function DaysSpec(kind)
    return {
        type = "custom",
        search = { label = "Quiet hours days of the week", desc = kind },
        build = function(row)
            row.label = UI.Text(row, "GameFontHighlight", "text")
            row.label:SetPoint("TOPLEFT", 12, -8)
            row.label:SetText("On these days")
            row.chips = {}
            for i, day in ipairs(DAY_SHORT) do
                local chip = UI.Chip(row, day, function(self)
                    local s = P().quiet_hours[kind]
                    s.days[self.day] = not (s.days[self.day] ~= false)
                    Settings:Changed()
                end)
                chip.day = i
                chip:SetWidth(46)
                chip:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12 - (7 - i) * 50, -6)
                row.chips[i] = chip
            end
        end,
        layout = function(row)
            local s = P().quiet_hours[kind]
            for i, chip in ipairs(row.chips) do
                chip:SetSelected(s.days[i] ~= false)
                chip:SetAlpha(s.enabled and 1 or 0.45)
                chip:EnableMouse(s.enabled and true or false)
            end
            row.label:SetAlpha(s.enabled and 1 or 0.5)
            return 36
        end,
    }
end

local function QuietSection(kind, title, modes)
    local function S() return P().quiet_hours[kind] end
    local function Off() return not S().enabled end
    return {
        { type = "section", label = title },
        { type = "toggle", label = "Use quiet hours for " .. kind, keywords = "night silence schedule",
            get = function() return S().enabled end, set = function(v) S().enabled = v and true or false end },
        { type = "text", text = function() return QH():StatusLine(kind) end, role = "muted" },
        { type = "select", label = "Quiet from", width = 180, disabled = Off, values = TimeValues,
            get = function() return S().start end, set = function(v) S().start = v end },
        { type = "select", label = "Until", desc = "The same time as \"Quiet from\" keeps the whole day quiet.",
            width = 180, disabled = Off, values = TimeValues,
            get = function() return S().stop end, set = function(v) S().stop = v end },
        { type = "select", label = "During quiet hours", width = 300, disabled = Off, values = modes,
            get = function() return S().mode end, set = function(v) S().mode = v end },
        DaysSpec(kind),
    }
end

Settings:AddPage({
    key = "quiet",
    label = "Quiet hours",
    icon = "Interface\\Icons\\Spell_Nature_Sleep",
    order = 4,
    count = function()
        local q = P().quiet_hours
        local n = (q.workouts.enabled and 1 or 0) + (q.hydration.enabled and 1 or 0)
        return n > 0 and tostring(n) or ""
    end,
    specs = function()
        local specs = {
            { type = "section", label = "Quiet hours",
                desc = "Turn workouts and water reminders off, or down, at set times. For example: no workouts after 10 PM. /wob now and /wob water always work." },
            { type = "select", label = "Clock", width = 240, keywords = "realm local time",
                values = { { value = "local", text = "Local time (this computer)" }, { value = "realm", text = "Realm time" } },
                get = function() return P().quiet_hours.clock end, set = function(v) P().quiet_hours.clock = v end },
            { type = "text", text = function() return QH():ClockLine() end, role = "muted" },
        }
        for _, s in ipairs(QuietSection("workouts", "Workouts", {
            { value = "pause", text = "Pause: skip workouts" },
            { value = "collect", text = "Collect silently: queue them, no chat, sound or popup" },
        })) do specs[#specs + 1] = s end
        for _, s in ipairs(QuietSection("hydration", "Hydration", {
            { value = "pause", text = "Pause: skip water reminders" },
            { value = "silent", text = "Silent: show the reminder without a sound" },
        })) do specs[#specs + 1] = s end
        return specs
    end,
})

------------------------------------------------------------------------
-- Window (appearance, workout window, auto-open, popup, minimap)
------------------------------------------------------------------------
local function AutoOpen(key, label, desc, hidden)
    return { type = "toggle", label = label, desc = desc, hidden = hidden, keywords = "open automatically downtime",
        get = function() return RE()[key] end,
        set = function(v) RE()[key] = v and true or false; WorkoutBuddy.ReminderEvents:Register() end }
end

Settings:AddPage({
    key = "window",
    label = "Window & look",
    icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
    order = 5,
    specs = function()
        return {
            { type = "section", label = "Look" },
            { type = "select", label = "Theme", desc = "Colors for this window, the workout window and the hydration popup.",
                keywords = "color skin style appearance", width = 200,
                values = function()
                    local out = {}
                    for _, key in ipairs(UI.THEME_ORDER) do out[#out + 1] = { value = key, text = UI.THEMES[key].label } end
                    return out
                end,
                get = function() return P().theme end,
                set = function(v)
                    P().theme = v
                    UI.Repaint()
                    WorkoutBuddy.ReminderCore:ApplyTheme()
                    WorkoutBuddy.Hydration:ApplyTheme()
                end },

            { type = "section", label = "Workout window" },
            { type = "buttons", search = { label = "Show, center or reset the workout window", desc = "position size" }, items = {
                { text = "Show / hide", func = function() WorkoutBuddy.ReminderCore:Toggle() end },
                { text = "Move to center", func = function() WorkoutBuddy.ReminderCore:CenterFrame(true) end },
                { text = "Reset size", func = function()
                    local d = WorkoutBuddy.defaults.profile.reminder_frame
                    RF().width, RF().height = d.width, d.height
                    WorkoutBuddy.ReminderCore:ApplyOptions()
                end },
            } },
            { type = "slider", label = "Scale", min = 0.5, max = 2, step = 0.05, unit = "%", percent = true,
                get = function() return RF().scale or 1 end,
                set = function(v) RF().scale = v; WorkoutBuddy.ReminderCore:ApplyOptions() end },
            { type = "slider", label = "Background opacity", keywords = "transparent alpha see through",
                desc = "Fades only the dark background, header and border. Text and buttons stay fully visible. 0 hides the background.",
                min = 0, max = 1, step = 0.05, unit = "%", percent = true,
                get = function() return RF().bg_alpha or 0.92 end,
                set = function(v) RF().bg_alpha = v; WorkoutBuddy.ReminderCore:ApplyTheme() end },
            { type = "slider", label = "Overall opacity", keywords = "transparent alpha fade",
                desc = "Fades the whole window, text and buttons included.",
                min = 0.3, max = 1, step = 0.05, unit = "%", percent = true,
                get = function() return RF().alpha or 0.95 end,
                set = function(v) RF().alpha = v; WorkoutBuddy.ReminderCore:ApplyOptions() end },
            { type = "toggle", label = "Show the title bar", keywords = "header name icon gear clean minimal",
                desc = "The icon, the name and the settings gear. Settings stay on /wob and the minimap button.",
                get = function() return RF().show_header ~= false end,
                set = function(v) RF().show_header = v and true or false; WorkoutBuddy.ReminderCore:ApplyOptions() end },
            { type = "toggle", label = "Show the close button", keywords = "x exit hide minimal",
                desc = "Escape and /wob show still close the window.",
                get = function() return RF().show_close ~= false end,
                set = function(v) RF().show_close = v and true or false; WorkoutBuddy.ReminderCore:ApplyOptions() end },
            { type = "toggle", label = "Close the window when every workout is done", keywords = "auto close hide empty finished",
                desc = "Waits a moment after your last one so you can see the final count.",
                get = function() return RF().autoclose end,
                set = function(v) RF().autoclose = v and true or false end },
            { type = "toggle", label = "Lock position and size",
                get = function() return RF().locked end,
                set = function(v) RF().locked = v and true or false; WorkoutBuddy.ReminderCore:ApplyOptions() end },
            { type = "toggle", label = "Move it back on screen if it ends up off screen",
                get = function() return RF().autocenter end, set = function(v) RF().autocenter = v and true or false end },

            { type = "section", label = "Open the workout window automatically",
                desc = "During natural downtime, the window opens if workouts are waiting. It never opens in the middle of a fight." },
            AutoOpen("taxi", "Taking a flight path", "Opens shortly after a flight starts."),
            AutoOpen("lfg_queue", "Waiting in a dungeon or battleground queue", "After 30 seconds in a queue, so instant pops do not interrupt you.",
                function() return not WorkoutBuddy.ReminderEvents.IsQueueOptionSupported() end),
            AutoOpen("recap", "After a boss fight or leaving a dungeon or raid",
                "Also prints a recap of what was added, for example Push-ups x30, Burpees x10.",
                function() return not WorkoutBuddy.IsEventValid("ENCOUNTER_END") end),
            AutoOpen("quest", "Turning in a quest"),
            AutoOpen("login", "Logging in", "A few seconds after you log in."),
            AutoOpen("afk", "Going AFK", "Once each time you go AFK."),
            AutoOpen("auction_house", "Opening the Auction House", nil,
                function() return not WorkoutBuddy.IsEventValid("AUCTION_HOUSE_SHOW") end),
            AutoOpen("rested", "Entering an inn or city", "Can be frequent in busy cities."),
            AutoOpen("open_empty", "Open even when no workouts are waiting"),

            { type = "section", label = "Hydration popup" },
            { type = "buttons", search = { label = "Preview or center the hydration popup", desc = "water" }, items = {
                { text = "Preview", func = function() WorkoutBuddy.Hydration:ShowPopup(true) end },
                { text = "Move to center", func = function() WorkoutBuddy.Hydration:CenterFrame(true) end },
            } },
            { type = "slider", label = "Popup scale", min = 0.5, max = 2, step = 0.05, unit = "%", percent = true,
                get = function() return H().scale or 1 end,
                set = function(v) H().scale = v; WorkoutBuddy.Hydration:ApplyOptions() end },
            { type = "slider", label = "Popup background opacity", keywords = "transparent alpha water",
                desc = "Fades only the popup's background, header and border.",
                min = 0, max = 1, step = 0.05, unit = "%", percent = true,
                get = function() return H().bg_alpha or 0.94 end,
                set = function(v) H().bg_alpha = v; WorkoutBuddy.Hydration:ApplyTheme() end },
            { type = "slider", label = "Popup overall opacity", keywords = "transparent alpha water fade",
                desc = "Fades the whole popup, text and buttons included.",
                min = 0.3, max = 1, step = 0.05, unit = "%", percent = true,
                get = function() return H().alpha or 0.95 end,
                set = function(v) H().alpha = v; WorkoutBuddy.Hydration:ApplyOptions() end },

            { type = "section", label = "Minimap" },
            { type = "toggle", label = "Show the minimap button", keywords = "icon",
                get = function() return not P().minimap.hide end, set = function(v) WorkoutBuddy:SetMinimapButtonShown(v) end },
            { type = "toggle", label = "Show in the addon compartment", desc = "The addons button next to the minimap.",
                hidden = function()
                    local icon = LibStub("LibDBIcon-1.0")
                    return not (icon.IsButtonCompartmentAvailable and icon:IsButtonCompartmentAvailable())
                end,
                get = function() return P().minimap.showInCompartment end, set = function(v) WorkoutBuddy:SetCompartmentShown(v) end },
        }
    end,
})

------------------------------------------------------------------------
-- Stats
------------------------------------------------------------------------
local view = { timeframe = "week", custom = "" }
local share = { what = "today", channel = "PARTY" }

Settings:AddPage({
    key = "stats",
    label = "Stats",
    icon = "Interface\\Icons\\INV_Misc_Book_09",
    order = 6,
    count = function() return tostring(WorkoutBuddy.Stats:GetTodayCount()) end,
    specs = function()
        return {
            { type = "section", label = "Today" },
            { type = "text", font = "GameFontHighlightLarge", text = function() return "|cFF66FF66" .. WorkoutBuddy.Stats:GetTodayLine() .. "|r" end },
            { type = "slider", label = "Daily goal", desc = "How many workouts you aim for each day. 0 turns the goal off.",
                keywords = "target streak", min = 0, max = 50, step = 1,
                unit = "workouts",
                get = function() return P().daily_goal or 0 end,
                set = function(v) P().daily_goal = v; WorkoutBuddy.ReminderCore:UpdateDisplay() end },
            { type = "section", label = "History" },
            { type = "select", label = "Show", width = 180, keywords = "week month all time range",
                values = { { value = "day", text = "Today" }, { value = "week", text = "This week" }, { value = "month", text = "This month" },
                    { value = "lifetime", text = "All time" }, { value = "custom", text = "Custom range" } },
                get = function() return view.timeframe end, set = function(v) view.timeframe = v end },
            { type = "input", label = "Custom range", desc = "For example 3days, 2weeks, 12hours or 90minutes.", width = 140,
                hidden = function() return view.timeframe ~= "custom" end,
                get = function() return view.custom end, set = function(v) view.custom = v end },
            { type = "text", text = function()
                local tf = view.timeframe
                if tf == "custom" then
                    if strtrim(view.custom) == "" then return "|cFF888888Enter a range above.|r" end
                    tf = view.custom
                end
                return WorkoutBuddy.Stats:GetSummary(tf)
            end },
            { type = "section", label = "Share",
                desc = "Post a one-line summary to a chat channel. Nothing is ever posted unless you click Share." },
            { type = "select", label = "What to share", width = 220, keywords = "share post announce brag",
                values = { { value = "today", text = "Today's workouts" }, { value = "week", text = "This week" },
                    { value = "recap", text = "Last boss fight or instance recap" } },
                get = function() return share.what end, set = function(v) share.what = v end },
            { type = "select", label = "Where", width = 220, keywords = "say party raid guild channel",
                values = function()
                    local out = {}
                    for _, key in ipairs(WorkoutBuddy.Stats.SHARE_ORDER) do
                        out[#out + 1] = { value = key, text = WorkoutBuddy.Stats.SHARE_CHANNELS[key].label }
                    end
                    return out
                end,
                get = function() return share.channel end, set = function(v) share.channel = v end },
            { type = "text", role = "muted", text = function()
                local text, why = WorkoutBuddy.Stats:ShareText(share.what)
                return text and ("Preview: |cFFFFFFFF" .. text .. "|r") or why
            end },
            { type = "button", label = "Share now", desc = "Sends the preview above, once.", text = "Share", kind = "primary",
                func = function()
                    local ok, why = WorkoutBuddy.Stats:Share(share.what, share.channel)
                    Settings:Status(ok and "|cFF66FF66Shared.|r" or ("|cFFFF5555" .. why .. "|r"))
                end },

            { type = "section", label = "Reset" },
            { type = "button", label = "Reset stats", desc = "Deletes all logged workouts and water for this profile.",
                text = "Reset stats", kind = "danger",
                confirm = "Delete all of this profile's workout and water history? This cannot be undone.",
                func = function() WorkoutBuddy.Stats:Reset(); WorkoutBuddy.ReminderCore:UpdateDisplay() end },
        }
    end,
})

------------------------------------------------------------------------
-- Profiles and sharing
------------------------------------------------------------------------
local pending = { workouts = "", profile = "" }

local function ProfileValues(includeCurrent)
    local db = WorkoutBuddy.db
    local current = db:GetCurrentProfile()
    local out = {}
    for _, name in ipairs(db:GetProfiles({}) or {}) do
        if includeCurrent or name ~= current then out[#out + 1] = { value = name, text = name } end
    end
    table.sort(out, function(a, b) return a.text < b.text end)
    return out
end

local function ShareSpec(key, title, exportFn, importFn, confirmText)
    return {
        type = "custom",
        search = { label = title, desc = "import export share copy paste backup" },
        build = function(row)
            row.exLabel = UI.Text(row, "GameFontHighlight", "text")
            row.exLabel:SetPoint("TOPLEFT", 0, -4)
            row.exLabel:SetText("Export: click the box, then press Ctrl-C to copy")
            row.export = UI.Multiline(row, 600, 60, true)
            row.export:SetPoint("TOPLEFT", 0, -22)
            row.imLabel = UI.Text(row, "GameFontHighlight", "text")
            row.imLabel:SetPoint("TOPLEFT", 0, -92)
            row.imLabel:SetText("Import: paste here, then click Import")
            row.import = UI.Multiline(row, 600, 60)
            row.import:SetPoint("TOPLEFT", 0, -110)
            row.import.edit:SetScript("OnTextChanged", function(e) pending[key] = e:GetText() or "" end)
            row.button = UI.Button(row, "Import", 100, 24, "primary", function()
                if strtrim(pending[key]) == "" then return Settings:Status("Paste something to import first.") end
                UI.Confirm(confirmText, function()
                    if importFn(pending[key]) then
                        pending[key] = ""
                        row.import:SetText("")
                        Settings:Status("|cFF66FF66Imported.|r")
                    else
                        Settings:Status("|cFFFF5555Import failed. See chat for details.|r")
                    end
                    Settings:Changed()
                end)
            end)
            row.button:SetPoint("TOPLEFT", 0, -178)
        end,
        layout = function(row, width)
            row.export:SetWidth(width)
            row.export.edit:SetWidth(width - 14)
            row.import:SetWidth(width)
            row.import.edit:SetWidth(width - 14)
            row.export:SetText(exportFn())
            return 210
        end,
    }
end

Settings:AddPage({
    key = "profiles",
    label = "Profiles",
    icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
    order = 7,
    count = function() return "" end,
    specs = function()
        local db = WorkoutBuddy.db
        return {
            { type = "section", label = "Profiles",
                desc = "Each character uses a profile. Share one between characters, or keep them separate." },
            { type = "text", text = function() return "Current profile: |cFFFFD700" .. db:GetCurrentProfile() .. "|r" end },
            { type = "select", label = "Switch to profile", width = 220, keywords = "character change",
                values = function() return ProfileValues(true) end,
                get = function() return db:GetCurrentProfile() end, set = function(v) db:SetProfile(v) end },
            { type = "input", label = "New profile", desc = "Type a name and press Enter to create it and switch to it.", width = 220,
                get = function() return "" end,
                set = function(v)
                    v = strtrim(v)
                    if v ~= "" then db:SetProfile(v) end
                end },
            { type = "select", label = "Copy settings from", desc = "Replaces this profile's settings with another profile's.",
                width = 220, placeholder = "Choose a profile",
                values = function() return ProfileValues(false) end, get = function() return nil end,
                set = function(v)
                    UI.Confirm("Copy every setting from '" .. v .. "' into this profile?", function()
                        db:CopyProfile(v)
                        Settings:Changed()
                    end)
                end },
            { type = "select", label = "Delete a profile", width = 220, placeholder = "Choose a profile",
                values = function() return ProfileValues(false) end, get = function() return nil end,
                set = function(v)
                    UI.Confirm("Delete the profile '" .. v .. "'?", function()
                        db:DeleteProfile(v)
                        Settings:Changed()
                    end)
                end },
            { type = "button", label = "Reset this profile", desc = "Back to the default settings.", text = "Reset profile",
                kind = "danger", confirm = "Reset every setting in this profile to its default?",
                func = function() db:ResetProfile() end },

            { type = "section", label = "Share your workout list",
                desc = "Imports are read as plain data and never run code." },
            ShareSpec("workouts", "Share your workout list",
                function() return WorkoutBuddy:SerializeWorkouts() end,
                function(text) return WorkoutBuddy:DeserializeWorkouts(text) end,
                "Replace your current workout list with the imported one?"),
            { type = "section", label = "Back up the whole profile",
                desc = "Every setting, workout, trigger and your stats history. Lua conditions in imported triggers stay off until you review them." },
            ShareSpec("profile", "Back up or restore the whole profile",
                function() return WorkoutBuddy:SerializeProfile() end,
                function(text) return WorkoutBuddy:DeserializeProfile(text) end,
                "Overwrite every setting in the current profile?"),
        }
    end,
})
