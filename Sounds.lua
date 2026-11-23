-- Sounds.lua
-- Registers Workout Buddy's sounds with LibSharedMedia and plays them.

local addonName, WorkoutBuddy = ...

local Sounds = {}
WorkoutBuddy.Sounds = Sounds

local media = LibStub("LibSharedMedia-3.0", true)

local BUNDLED = { "Bell", "Chime", "Heart", "IM", "Info", "Kachink", "Link", "Text1", "Text2", "Xylo" }

local function kit(key, fallback)
    return (SOUNDKIT and SOUNDKIT[key]) or fallback
end

function Sounds:Init()
    if not media or self.initialized then return end
    self.initialized = true
    media:Register("sound", "Alarm Clock", kit("ALARM_CLOCK_WARNING_3", 12889))
    media:Register("sound", "Raid Warning", kit("RAID_WARNING", 8959))
    media:Register("sound", "Whisper", kit("TELL_MESSAGE", 3081))
    media:Register("sound", "Level Up", kit("UI_LEVEL_UP", 888)) -- not in every client's SOUNDKIT
    media:Register("sound", "Quest Complete", kit("IG_QUEST_LIST_COMPLETE", 878))
    media:Register("sound", "Ready Check", kit("READY_CHECK", 8960))
    local base = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\"
    for _, name in ipairs(BUNDLED) do
        media:Register("sound", "WB: " .. name, base .. name .. ".ogg")
    end
end

--- Sound names for an AceConfig select.
function Sounds:GetList()
    local list = { None = "None" }
    if not media then return list end
    for name in pairs(media:HashTable("sound")) do
        list[name] = name
    end
    return list
end

function Sounds:Play(name)
    if not name or name == "None" or not media then return end
    local s = media:Fetch("sound", name, true)
    if not s or s == "" then return end
    if type(s) == "number" then
        PlaySound(s, "Master")
    else
        PlaySoundFile(s, "Master")
    end
end
