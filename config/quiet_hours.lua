-- config/quiet_hours.lua
-- Quiet Hours tab: daily schedules that pause or silence workouts and
-- hydration reminders.

local _, WorkoutBuddy = ...
WorkoutBuddy.ConfigTabs = WorkoutBuddy.ConfigTabs or {}

local function Q()
    return WorkoutBuddy.db.profile.quiet_hours
end

local MODE_CHOICES = {
    workouts = {
        values = {
            pause = "Pause: skip workout suggestions",
            collect = "Collect silently: queue them, no chat, sound or popup",
        },
        order = { "pause", "collect" },
    },
    hydration = {
        values = {
            pause = "Pause: skip hydration reminders",
            silent = "Silent: show the reminder without a sound",
        },
        order = { "pause", "silent" },
    },
}

local function Section(kind, order, title)
    local function S() return Q()[kind] end
    local function Off() return not S().enabled end
    local times, timeOrder = WorkoutBuddy.QuietHours.TimeChoices()
    local days = {}
    for i, name in ipairs(WorkoutBuddy.QuietHours.DAY_NAMES) do days[i] = name end

    return {
        type = "group",
        name = title,
        inline = true,
        order = order,
        args = {
            enabled = {
                type = "toggle",
                name = "Use quiet hours for " .. kind,
                width = "full",
                order = 1,
                get = function() return S().enabled end,
                set = function(_, val) S().enabled = val and true or false end,
            },
            status = {
                type = "description",
                name = function() return WorkoutBuddy.QuietHours:StatusLine(kind) .. "\n" end,
                order = 2,
            },
            start = {
                type = "select",
                name = "Quiet from",
                order = 3,
                width = 1.1,
                disabled = Off,
                values = times,
                sorting = timeOrder,
                get = function() return S().start end,
                set = function(_, val) S().start = val end,
            },
            stop = {
                type = "select",
                name = "Until",
                desc = "Set the same time as \"Quiet from\" to keep the whole day quiet.",
                order = 4,
                width = 1.1,
                disabled = Off,
                values = times,
                sorting = timeOrder,
                get = function() return S().stop end,
                set = function(_, val) S().stop = val end,
            },
            mode = {
                type = "select",
                name = "During quiet hours",
                order = 5,
                width = "full",
                disabled = Off,
                values = MODE_CHOICES[kind].values,
                sorting = MODE_CHOICES[kind].order,
                get = function() return S().mode end,
                set = function(_, val) S().mode = val end,
            },
            days = {
                type = "multiselect",
                name = "On these days",
                desc = "A window that runs past midnight belongs to the day it starts on.",
                order = 6,
                width = "full",
                disabled = Off,
                values = days,
                get = function(_, day) return S().days[day] ~= false end,
                set = function(_, day, val) S().days[day] = val and true or false end,
            },
        },
    }
end

function WorkoutBuddy.ConfigTabs.QuietHours()
    return {
        type = "group",
        name = "Quiet Hours",
        order = 3.5,
        args = {
            intro = {
                type = "description",
                name = "Turn workouts and hydration reminders off (or down) at set times, for example no workouts after 10 PM. "
                    .. "Workouts and hydration have separate schedules. /wob now and /wob water always work.\n",
                order = 0,
            },
            clock = {
                type = "select",
                name = "Clock",
                order = 1,
                width = 1.4,
                values = {
                    ["local"] = "Local time (this computer)",
                    realm = "Realm time",
                },
                sorting = { "local", "realm" },
                get = function() return Q().clock end,
                set = function(_, val) Q().clock = val end,
            },
            clockNow = {
                type = "description",
                name = function() return "|cFF888888" .. WorkoutBuddy.QuietHours:ClockLine() .. "|r\n" end,
                order = 2,
            },
            workouts = Section("workouts", 10, "Workouts"),
            hydration = Section("hydration", 20, "Hydration"),
        },
    }
end
