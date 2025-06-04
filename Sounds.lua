local _, WorkoutBuddy = ...
WorkoutBuddy = WorkoutBuddy or _G.WorkoutBuddy
if WorkoutBuddy and WorkoutBuddy.DbgPrint then
    WorkoutBuddy:DbgPrint("Loaded: Sounds.lua")
end

local Sounds = {}
local media = LibStub("LibSharedMedia-3.0")

function Sounds:Init()
    if not media then return end
    -- register a few built-in sounds
    media:Register("sound", "Alarm Clock", SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889)
    media:Register("sound", "Raid Warning", SOUNDKIT.RAID_WARNING or 8959)
    media:Register("sound", "Whisper", SOUNDKIT.TELL_MESSAGE or 3081)
    media:Register("sound", "None", "")
end

function Sounds:GetList()
    local list = {}
    if not media then return list end
    for name in pairs(media:HashTable("sound")) do
        list[name] = name
    end
    return list
end

function Sounds:Play(name)
    if not name or name == "None" then return end
    if not media then return end
    local s = media:Fetch("sound", name, true)
    if not s or s == "" then return end
    if type(s) == "number" then
        PlaySound(s, "Master")
    else
        PlaySoundFile(s, "Master")
    end
end

if WorkoutBuddy then
    WorkoutBuddy.Sounds = Sounds
else
    _G.WorkoutBuddy_Sounds = Sounds
end
return Sounds