-- config/hydration.lua
-- Hydration tab.

local _, WorkoutBuddy = ...
WorkoutBuddy.ConfigTabs = WorkoutBuddy.ConfigTabs or {}

local function H()
    return WorkoutBuddy.db.profile.hydration
end

local function Restart()
    WorkoutBuddy.Hydration:Start()
    WorkoutBuddy:NotifyConfigChanged()
end

local function PositiveNumber(_, val)
    local n = tonumber(val)
    if not n or n <= 0 then return "Enter a number greater than 0." end
    return true
end

local function NumberInput(key, order, name, desc)
    return {
        type = "input",
        name = function() return (name:gsub("%%unit", WorkoutBuddy.Hydration:UnitLabel())) end,
        desc = desc,
        order = order,
        width = 0.9,
        validate = PositiveNumber,
        get = function() return tostring(H()[key] or "") end,
        set = function(_, val)
            H()[key] = tonumber(val)
            Restart()
        end,
    }
end

local function NextReminderText()
    local o = H()
    if not o.enabled then return "|cFF888888Hydration reminders are off.|r" end
    local mins = math.floor(WorkoutBuddy.Hydration:GetInterval() / 60 + 0.5)
    local text = string.format("You will be reminded about every |cFFFFD700%d minute(s)|r.", mins)
    local left = (tonumber(o.next_time) or 0) - WorkoutBuddy.Now()
    if left > 0 then
        text = text .. string.format(" Next reminder in about %d minute(s).", math.ceil(left / 60))
    end
    local total, unit = WorkoutBuddy.Stats:GetTodayWater()
    if total > 0 then
        text = text .. string.format("\nLogged today: |cFF66BBFF%d %s|r", total, unit or "")
    end
    return text
end

function WorkoutBuddy.ConfigTabs.Hydration()
    return {
        type = "group",
        name = "Hydration",
        order = 3,
        args = {
            intro = {
                type = "description",
                name = "A gentle popup reminds you to drink water. Click \"Drank it\" on the popup (or type /wob water) to log it.\n",
                order = 0,
            },
            enable = {
                type = "toggle",
                name = "Enable hydration reminders",
                width = "full",
                order = 1,
                get = function() return H().enabled end,
                set = function(_, val)
                    H().enabled = val
                    if val then WorkoutBuddy.Hydration:Start() else WorkoutBuddy.Hydration:Stop() end
                    WorkoutBuddy:NotifyConfigChanged()
                end,
            },
            status = {
                type = "description",
                name = NextReminderText,
                order = 2,
            },
            mode = {
                type = "select",
                name = "Reminder style",
                order = 3,
                values = { smart = "Daily goal (spread over a time window)", interval = "Every few minutes" },
                get = function() return H().mode or "smart" end,
                set = function(_, val)
                    H().mode = val
                    Restart()
                end,
            },
            unit = {
                type = "select",
                name = "Units",
                order = 4,
                width = 0.7,
                values = { oz = "Ounces (oz)", ml = "Milliliters (ml)" },
                get = function() return H().unit or "oz" end,
                set = function(_, val)
                    WorkoutBuddy.Hydration:SetUnit(val)
                    Restart()
                end,
            },
            smartGroup = {
                type = "group",
                name = "Goal",
                inline = true,
                order = 5,
                hidden = function() return (H().mode or "smart") ~= "smart" end,
                args = {
                    total = NumberInput("total", 1, "Drink this much (%unit)", "Total amount to drink over the time window."),
                    timeframe = {
                        type = "range",
                        name = "Over this many minutes",
                        order = 2,
                        min = 15, max = 720, step = 5,
                        get = function() return H().timeframe or 120 end,
                        set = function(_, val)
                            H().timeframe = val
                            Restart()
                        end,
                    },
                    per = NumberInput("per", 3, "Per reminder (%unit)", "How much to drink each time you are reminded."),
                },
            },
            intervalGroup = {
                type = "group",
                name = "Interval",
                inline = true,
                order = 5,
                hidden = function() return (H().mode or "smart") ~= "interval" end,
                args = {
                    interval = {
                        type = "range",
                        name = "Remind me every (minutes)",
                        min = 5, max = 240, step = 5,
                        order = 1,
                        width = 1.5,
                        get = function() return H().interval or 60 end,
                        set = function(_, val)
                            H().interval = val
                            Restart()
                        end,
                    },
                },
            },
            sound = {
                type = "select",
                name = "Sound",
                order = 6,
                values = function() return WorkoutBuddy.Sounds:GetList() end,
                get = function() return H().sound or "Alarm Clock" end,
                set = function(_, val)
                    H().sound = val
                    WorkoutBuddy.Sounds:Play(val)
                end,
            },
            autoHide = {
                type = "range",
                name = "Hide the popup after (seconds, 0 = never)",
                min = 0, max = 300, step = 5,
                order = 7,
                width = 1.5,
                get = function() return H().auto_hide or 0 end,
                set = function(_, val) H().auto_hide = val end,
            },
            test = {
                type = "execute",
                name = "Preview popup",
                order = 8,
                func = function() WorkoutBuddy.Hydration:ShowPopup(true) end,
            },
            testSound = {
                type = "execute",
                name = "Play sound",
                order = 9,
                func = function() WorkoutBuddy.Hydration:PlaySelectedSound() end,
            },
            logNow = {
                type = "execute",
                name = "Log a drink now",
                order = 10,
                func = function() WorkoutBuddy.Hydration:LogDrink() end,
            },
        },
    }
end
