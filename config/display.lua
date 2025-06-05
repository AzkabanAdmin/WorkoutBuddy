local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function WorkoutBuddy_DisplayTab()
    return {
        type = "group",
        name = "Display",
        order = 6,
        args = {
            reminderHeader = {
                type = "header",
                name = "Workout Reminder Frame",
                order = 1,
            },
            reminderOptions = {
                type = "group",
                name = "Workout Reminder Frame Options",
                inline = true,
                order = 2,
                args = {
                    centerNow = {
                        type = "execute",
                        name = "Center Frame Now",
                        width = "full",
                        order = 1,
                        func = function()
                            if WorkoutBuddy.ReminderCore and WorkoutBuddy.ReminderCore.CenterFrame then
                                WorkoutBuddy.ReminderCore:CenterFrame(true)
                            end
                        end,
                    },
                },
            },
            hydrationHeader = {
                type = "header",
                name = "Hydration Popup",
                order = 3,
            },
            hydrationOptions = {
                type = "group",
                name = "Hydration Frame Options",
                inline = true,
                order = 4,
                args = {
                    scale = {
                        type = "range",
                        name = "Scale",
                        min = 0.5, max = 2, step = 0.05,
                        order = 1,
                        get = function() return WorkoutBuddy.db.profile.hydration.scale or 1 end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.hydration.scale = val
                            if WorkoutBuddy.Hydration.frame then
                                WorkoutBuddy.Hydration.frame:SetScale(val)
                            end
                        end,
                    },
                    alpha = {
                        type = "range",
                        name = "Opacity",
                        min = 0.2, max = 1, step = 0.05,
                        order = 2,
                        get = function() return WorkoutBuddy.db.profile.hydration.alpha or 0.9 end,
                        set = function(info, val)
                            WorkoutBuddy.db.profile.hydration.alpha = val
                            if WorkoutBuddy.Hydration.frame then
                                WorkoutBuddy.Hydration.frame:SetAlpha(val)
                            end
                        end,
                    },
                    center = {
                        type = "execute",
                        name = "Center Frame",
                        order = 3,
                        func = function() WorkoutBuddy.Hydration:CenterFrame(true) end,
                    },
                },
            },
        },
    }
end

