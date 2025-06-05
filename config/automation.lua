local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function WorkoutBuddy_AutomationGroup()
    return {
        type = "group",
        name = "Custom Events",
        childGroups = "tab",
        order = 8,
        args = {
            triggers = {
                type = "group",
                name = "Triggers",
                order = 1,
                args = {
                    info = {
                        type = "description",
                        order = 0,
                        name = "Define triggers that listen for game events.",
                    },
                    triggerList = { type="group", name="", inline=false, order=1, args={} },
                    addTrigger = {
                        type = "execute",
                        name = "Add Trigger",
                        order = 100,
                        func = function()
                            WorkoutBuddy.db.profile.triggers = WorkoutBuddy.db.profile.triggers or {}
                            local t = WorkoutBuddy.db.profile.triggers
                            t[#t+1] = { name="New Trigger", event="PLAYER_LEVEL_UP", customEvent="" }
                            WorkoutBuddy:RebuildTriggerOptions(WorkoutBuddy.options.args.general.args.automation.args.triggers.args.triggerList.args,
                                {"general","automation","triggers","triggerList"})
                            WorkoutBuddy:RebuildConditionOptions(nil, {"general","automation","conditions","conditionList"})
                            AceConfigDialog:SelectGroup("WorkoutBuddy", "general", "automation", "triggers")
                            WorkoutBuddy.TriggerManager:RegisterEvents()
                        end
                    },
                },
            },
            conditions = {
                type = "group",
                name = "Conditions",
                order = 2,
                args = {
                    info = {
                        type = "description",
                        order = 0,
                        name = "Combine triggers and conditions to perform actions.",
                    },
                    conditionList = { type="group", name="", inline=false, order=1, args={} },
                    addCondition = {
                        type = "execute",
                        name = "Add Condition",
                        order = 98,
                        func = function()
                            WorkoutBuddy.db.profile.conditions = WorkoutBuddy.db.profile.conditions or {}
                            local c = WorkoutBuddy.db.profile.conditions
                            c[#c+1] = { name="New Condition", triggers={}, logic="AND", action="workout" }
                            WorkoutBuddy:RebuildConditionOptions(WorkoutBuddy.options.args.general.args.automation.args.conditions.args.conditionList.args,
                                {"general","automation","conditions","conditionList"})
                            WorkoutBuddy:RebuildCustomEventToggles()
                            AceConfigDialog:SelectGroup("WorkoutBuddy", "general", "automation", "conditions")
                        end
                    },
                    saveButton = {
                        type = "execute",
                        name = "Save",
                        order = 100,
                        width = 0.7,
                        func = function()
                            WorkoutBuddy:RebuildCustomEventToggles()
                            AceConfigDialog:Close("WorkoutBuddy")
                        end
                    },
                },
            },
        }
    }
end

