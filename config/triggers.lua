local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function WorkoutBuddy_TriggersTab()
    return {
        type = "group",
        name = "Custom Events",
        childGroups = "tab",
        order = 4,
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
                    addTrigger = { type="execute", name="Add Trigger", order=100, func=function()
                        if not WorkoutBuddy.db.profile.triggers then
                            WorkoutBuddy.db.profile.triggers = {}
                        end
                        local t = WorkoutBuddy.db.profile.triggers
                        t[#t+1] = { name="New Trigger", event="PLAYER_LEVEL_UP", customEvent="" }
                        WorkoutBuddy:RebuildTriggerOptions(WorkoutBuddy.automationOptions.args.triggers.args.triggerList.args, {"triggers","triggerList"}, "WorkoutBuddyAutomation")
                        WorkoutBuddy:RebuildConditionOptions(WorkoutBuddy.automationOptions.args.conditions.args.conditionList.args, {"conditions","conditionList"}, "WorkoutBuddyAutomation")
                        AceConfigDialog:SelectGroup("WorkoutBuddyAutomation", "triggers")
                        WorkoutBuddy.TriggerManager:RegisterEvents()
                    end },
                },
            },
            conditions = {
                type = "group",
                name = "Custom Events",
                order = 2,
                args = {
                    info = {
                        type = "description",
                        order = 0,
                        name = "Combine triggers and conditions to perform actions.",
                    },
                    conditionList = { type="group", name="", inline=false, order=1, args={} },
                    okButton = { type="execute", name="Okay", order=100, width=0.7, func=function()
                        AceConfigDialog:Close("WorkoutBuddyAutomation")
                    end },
                },
            },
        }
    }
end
