local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function WorkoutBuddy_TriggersTab()
    return {
        type = "group",
        name = "Automation",
        order = 4,
        args = {
            info = { type="description", order=0, name="Define custom triggers and conditions. Triggers listen for game events and conditions combine them to perform actions." },
            triggerHeader = { type="header", name="Triggers", order=1 },
            triggerList = { type="group", name="Triggers", inline=false, order=2, args={} },
            addTrigger = { type="execute", name="Add Trigger", order=3, func=function()
                local t = WorkoutBuddy.db.profile.triggers
                t[#t+1] = { name="New Trigger", event="PLAYER_LEVEL_UP", customEvent="" }
                WorkoutBuddy:RebuildTriggerOptions(nil, {"triggers"})
                WorkoutBuddy:RebuildConditionOptions(nil, {"triggers", "conditionList"})
                AceConfigDialog:SelectGroup("WorkoutBuddy", "triggers")
                WorkoutBuddy.TriggerManager:RegisterEvents()
            end },
            conditionHeader = { type="header", name="Conditions", order=4 },
            conditionList = { type="group", name="Conditions", inline=false, order=5, args={} },
            addCondition = { type="execute", name="Add Condition", order=6, func=function()
                local c = WorkoutBuddy.db.profile.conditions
                c[#c+1] = { name="New Condition", logic="AND", triggers={}, activity="", action="workout" }
                WorkoutBuddy:RebuildConditionOptions(nil, {"triggers", "conditionList"})
                AceConfigDialog:SelectGroup("WorkoutBuddy", "triggers", "conditionList")
            end },
        }
    }
end
