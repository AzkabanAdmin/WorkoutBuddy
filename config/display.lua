-- config/display.lua
-- Display tab: workout window, hydration popup and minimap button.

local _, WorkoutBuddy = ...
WorkoutBuddy.ConfigTabs = WorkoutBuddy.ConfigTabs or {}

local function RF()
    return WorkoutBuddy.db.profile.reminder_frame
end

local function H()
    return WorkoutBuddy.db.profile.hydration
end

function WorkoutBuddy.ConfigTabs.Display()
    return {
        type = "group",
        name = "Display",
        order = 4,
        args = {
            reminderHeader = { type = "header", name = "Workout window", order = 1 },
            show = {
                type = "execute",
                name = "Show / hide",
                order = 2,
                func = function() WorkoutBuddy.ReminderCore:Toggle() end,
            },
            center = {
                type = "execute",
                name = "Move to center",
                order = 3,
                func = function() WorkoutBuddy.ReminderCore:CenterFrame(true) end,
            },
            resetSize = {
                type = "execute",
                name = "Reset size",
                order = 4,
                func = function()
                    RF().width, RF().height = nil, nil
                    WorkoutBuddy.ReminderCore:ApplyOptions()
                end,
            },
            scale = {
                type = "range",
                name = "Scale",
                min = 0.5, max = 2, step = 0.05, isPercent = true,
                order = 5,
                get = function() return RF().scale or 1 end,
                set = function(_, val)
                    RF().scale = val
                    WorkoutBuddy.ReminderCore:ApplyOptions()
                end,
            },
            alpha = {
                type = "range",
                name = "Opacity",
                min = 0.3, max = 1, step = 0.05, isPercent = true,
                order = 6,
                get = function() return RF().alpha or 0.95 end,
                set = function(_, val)
                    RF().alpha = val
                    WorkoutBuddy.ReminderCore:ApplyOptions()
                end,
            },
            locked = {
                type = "toggle",
                name = "Lock position and size",
                order = 7,
                width = "full",
                get = function() return RF().locked end,
                set = function(_, val)
                    RF().locked = val
                    WorkoutBuddy.ReminderCore:ApplyOptions()
                end,
            },
            autocenter = {
                type = "toggle",
                name = "Move the window back on screen if it ends up off screen",
                order = 8,
                width = "full",
                get = function() return RF().autocenter end,
                set = function(_, val) RF().autocenter = val end,
            },

            hydrationHeader = { type = "header", name = "Hydration popup", order = 20 },
            hydPreview = {
                type = "execute",
                name = "Preview",
                order = 21,
                func = function() WorkoutBuddy.Hydration:ShowPopup(true) end,
            },
            hydCenter = {
                type = "execute",
                name = "Move to center",
                order = 22,
                func = function() WorkoutBuddy.Hydration:CenterFrame(true) end,
            },
            hydScale = {
                type = "range",
                name = "Scale",
                min = 0.5, max = 2, step = 0.05, isPercent = true,
                order = 23,
                get = function() return H().scale or 1 end,
                set = function(_, val)
                    H().scale = val
                    WorkoutBuddy.Hydration:ApplyOptions()
                end,
            },
            hydAlpha = {
                type = "range",
                name = "Opacity",
                min = 0.3, max = 1, step = 0.05, isPercent = true,
                order = 24,
                get = function() return H().alpha or 0.95 end,
                set = function(_, val)
                    H().alpha = val
                    WorkoutBuddy.Hydration:ApplyOptions()
                end,
            },

            minimapHeader = { type = "header", name = "Minimap", order = 40 },
            minimap = {
                type = "toggle",
                name = "Show minimap button",
                order = 41,
                width = "full",
                get = function() return not WorkoutBuddy.db.profile.minimap.hide end,
                set = function(_, val) WorkoutBuddy:SetMinimapButtonShown(val) end,
            },
            compartment = {
                type = "toggle",
                name = "Show in the addon compartment (the addons button by the minimap)",
                order = 42,
                width = "full",
                hidden = function()
                    local icon = LibStub("LibDBIcon-1.0")
                    return not (icon.IsButtonCompartmentAvailable and icon:IsButtonCompartmentAvailable())
                end,
                get = function() return WorkoutBuddy.db.profile.minimap.showInCompartment end,
                set = function(_, val) WorkoutBuddy:SetCompartmentShown(val) end,
            },
        },
    }
end
