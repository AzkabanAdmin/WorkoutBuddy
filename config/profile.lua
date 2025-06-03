local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")


function WorkoutBuddy_ProfileTab()
    return AceDBOptions:GetOptionsTable(WorkoutBuddy.db)
end
