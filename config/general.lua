-- config/general.lua
-- General tab: on/off, workout triggers, notifications and auto-open events.

local _, WorkoutBuddy = ...
WorkoutBuddy.ConfigTabs = WorkoutBuddy.ConfigTabs or {}

local function P()
    return WorkoutBuddy.db.profile
end

-- Toggle for a built-in workout trigger; hidden when the client lacks its event.
local function TriggerToggle(key, order, name, desc)
    return {
        type = "toggle",
        name = name,
        desc = desc,
        width = "full",
        order = order,
        hidden = function() return not WorkoutBuddy:IsBuiltInTriggerSupported(key) end,
        get = function() return P().event_map[key] end,
        set = function(_, val) P().event_map[key] = val end,
    }
end

-- Toggle for an auto-open event.
local function OpenToggle(key, order, name, desc, hidden)
    return {
        type = "toggle",
        name = name,
        desc = desc,
        width = "full",
        order = order,
        hidden = hidden,
        get = function() return P().reminder_events[key] end,
        set = function(_, val)
            P().reminder_events[key] = val
            WorkoutBuddy.ReminderEvents:Register()
        end,
    }
end

function WorkoutBuddy.ConfigTabs.General()
    return {
        type = "group",
        name = "General",
        order = 1,
        args = {
            intro = {
                type = "description",
                name = "Workout Buddy turns moments in the game into short exercise breaks. Workouts collect in a small queue window; tick them off when you have done them.\n",
                fontSize = "medium",
                order = 0,
            },
            enabled = {
                type = "toggle",
                name = "Suggest workouts automatically",
                desc = "Turn off to pause all automatic suggestions. You can still use /wob now.",
                width = "full",
                order = 1,
                get = function() return P().enabled end,
                set = function(_, val) WorkoutBuddy:SetEnabled(val) end,
            },

            ------------------------------------------------------------
            triggersHeader = { type = "header", name = "Suggest a workout when...", order = 10 },
            playTimer = {
                type = "toggle",
                name = "|cFF66FF66I have been playing for a while|r",
                desc = "Suggest a break after this many minutes of play without one. Time spent AFK does not count. Sitting less is one of the best things you can do for your health.",
                width = 1.6,
                order = 11,
                get = function() return P().event_map.play_timer end,
                set = function(_, val)
                    P().event_map.play_timer = val
                    WorkoutBuddy:StartPlayTimer()
                end,
            },
            playTimerMinutes = {
                type = "range",
                name = "Minutes of play",
                min = 10, max = 120, step = 5,
                order = 12,
                disabled = function() return not P().event_map.play_timer end,
                get = function() return P().play_timer_minutes end,
                set = function(_, val) P().play_timer_minutes = val end,
            },
            events = {
                type = "group",
                name = "Game events",
                inline = true,
                order = 13,
                args = {
                    boss_kill = TriggerToggle("boss_kill", 1, "|cFFFFD700Boss defeated|r",
                        "After every successful boss kill in a dungeon or raid."),
                    challenge_complete = TriggerToggle("challenge_complete", 2, "|cFFFFD700Mythic+ keystone completed|r",
                        "When a keystone dungeon finishes."),
                    levelup = TriggerToggle("levelup", 3, "Level up", "When you gain a level."),
                    xpbubble = TriggerToggle("xpbubble", 4, "XP bubble",
                        "Every time you fill one of the 20 bubbles on the XP bar. Great while leveling."),
                    quest_turnin = TriggerToggle("quest_turnin", 5, "Quest turned in",
                        "Every time you turn in a quest. Can be frequent while leveling."),
                    achievement = TriggerToggle("achievement", 6, "Achievement earned",
                        "When you earn an achievement. Can be frequent."),
                    player_death = TriggerToggle("player_death", 7, "You died",
                        "Nothing like push-ups to reflect on your choices."),
                    zonechange_newarea = TriggerToggle("zonechange_newarea", 8, "Entering a new zone",
                        "When you travel into a different zone."),
                    zonechange_zone = TriggerToggle("zonechange_zone", 9, "Any sub-zone change",
                        "Every sub-zone change. Very frequent; the cooldown below keeps it in check."),
                    zonechange_indoors = TriggerToggle("zonechange_indoors", 10, "Going indoors or outdoors",
                        "When you enter or leave a building."),
                },
            },
            customTriggers = {
                type = "group",
                name = "Custom triggers",
                inline = true,
                order = 14,
                args = {}, -- filled by RebuildCustomEventToggles
            },
            addCustom = {
                type = "execute",
                name = "Add custom trigger",
                desc = "Suggest a workout on any game event, with optional conditions.",
                width = 1.2,
                order = 15,
                func = function() WorkoutBuddy:OpenTriggerEditor("workout") end,
            },

            ------------------------------------------------------------
            notifyHeader = { type = "header", name = "Suggestions", order = 20 },
            cooldown = {
                type = "range",
                name = "Minimum time between suggestions (seconds)",
                desc = "Automatic suggestions that arrive sooner than this after the previous one are skipped. Stops busy events from flooding your queue.",
                min = 0, max = 900, step = 15,
                width = 1.6,
                order = 21,
                get = function() return P().suggest_cooldown end,
                set = function(_, val) P().suggest_cooldown = val end,
            },
            chat = {
                type = "toggle",
                name = "Announce new workouts in chat",
                width = "full",
                order = 22,
                get = function() return P().notify.chat end,
                set = function(_, val) P().notify.chat = val end,
            },
            avoidRepeat = {
                type = "toggle",
                name = "Avoid suggesting the same workout twice in a row",
                width = "full",
                order = 23,
                get = function() return P().avoid_repeat end,
                set = function(_, val) P().avoid_repeat = val end,
            },
            sound = {
                type = "select",
                name = "Sound for new workouts",
                order = 24,
                values = function() return WorkoutBuddy.Sounds:GetList() end,
                get = function() return P().notify.sound or "None" end,
                set = function(_, val)
                    P().notify.sound = val
                    WorkoutBuddy.Sounds:Play(val)
                end,
            },
            loginMessage = {
                type = "toggle",
                name = "Show a message in chat when the addon loads",
                width = "full",
                order = 25,
                get = function() return P().login_message end,
                set = function(_, val) P().login_message = val end,
            },

            ------------------------------------------------------------
            openHeader = { type = "header", name = "Open the workout window automatically when...", order = 30 },
            openDesc = {
                type = "description",
                name = "During natural downtime, the window opens if workouts are waiting.",
                order = 31,
            },
            openEvents = {
                type = "group",
                name = "Downtime",
                inline = true,
                order = 32,
                args = {
                    taxi = OpenToggle("taxi", 1, "|cFF66BBFFTaking a flight path|r", "Opens shortly after a flight starts."),
                    lfg_queue = OpenToggle("lfg_queue", 2, "|cFF66BBFFWaiting in a dungeon or battleground queue|r",
                        "Opens after 30 seconds in a queue, so instant pops do not interrupt you.",
                        function() return not WorkoutBuddy.ReminderEvents.IsQueueOptionSupported() end),
                    quest = OpenToggle("quest", 3, "Turning in a quest", "Opens after you turn in a quest."),
                    login = OpenToggle("login", 4, "Logging in", "Opens a few seconds after you log in."),
                    afk = OpenToggle("afk", 5, "Going AFK", "Opens once each time you go AFK."),
                    auction_house = OpenToggle("auction_house", 6, "Opening the Auction House", "Auction House sessions can be long.",
                        function() return not WorkoutBuddy.IsEventValid("AUCTION_HOUSE_SHOW") end),
                    rested = OpenToggle("rested", 7, "Entering an inn or city", "Can be frequent in busy cities."),
                },
            },
            deferCombat = OpenToggle("defer_combat", 33, "Wait until combat ends",
                "Never pop the window open in the middle of a fight; it opens once you leave combat instead."),
            openEmpty = OpenToggle("open_empty", 34, "Open even when no workouts are waiting",
                "Show the window on the events above even if the queue is empty."),
            customOpen = {
                type = "group",
                name = "Custom auto-open events",
                inline = true,
                order = 35,
                args = {}, -- filled by RebuildCustomEventToggles
            },
            addCustomOpen = {
                type = "execute",
                name = "Add custom auto-open event",
                width = 1.2,
                order = 36,
                func = function() WorkoutBuddy:OpenTriggerEditor("open_frame") end,
            },
        },
    }
end
