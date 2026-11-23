-- trigger_list.lua
-- One list of "when to work out" entries for the settings window. Built-in
-- triggers (event_map + builtin_workouts) and custom triggers (triggers)
-- are stored differently, but the player sees and edits them the same way:
-- on or off, and what each one gives (a random workout, a set workout, or
-- opening the window).

local _, WorkoutBuddy = ...

local TL = {}
WorkoutBuddy.TriggerList = TL

TL.BUILTINS = {
    { key = "player_death", label = "You die", desc = "Every time your character dies.", icon = "Interface\\Icons\\Ability_Rogue_FeignDeath" },
    { key = "boss_kill", label = "Boss defeated", desc = "After every successful boss kill in a dungeon or raid.", icon = "Interface\\Icons\\Achievement_Boss_Ragnaros" },
    { key = "challenge_complete", label = "Mythic+ keystone completed", desc = "When a keystone dungeon finishes.", icon = "Interface\\Icons\\INV_Relics_Hourglass" },
    { key = "play_timer", label = "Playing for a while", desc = "After a number of minutes of play without a break. AFK time does not count.", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
    { key = "levelup", label = "Level up", desc = "When you gain a level.", icon = "Interface\\Icons\\Spell_Holy_SurgeOfLight" },
    { key = "xpbubble", label = "XP bubble filled", desc = "Every time you fill one of the 20 bubbles on the XP bar.", icon = "Interface\\Icons\\INV_Misc_Gem_Pearl_04" },
    { key = "quest_turnin", label = "Quest turned in", desc = "Every time you turn in a quest. Frequent while leveling.", icon = "Interface\\Icons\\INV_Misc_Note_01" },
    { key = "achievement", label = "Achievement earned", desc = "When you earn an achievement.", icon = "Interface\\Icons\\Achievement_General" },
    { key = "zonechange_newarea", label = "Entering a new zone", desc = "When you travel into a different zone.", icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = "zonechange_zone", label = "Any sub-zone change", desc = "Every sub-zone change. Very frequent.", icon = "Interface\\Icons\\INV_Misc_Map02" },
    { key = "zonechange_indoors", label = "Going indoors or outdoors", desc = "When you enter or leave a building.", icon = "Interface\\Icons\\INV_Misc_Key_03" },
}
TL.BUILTIN_BY_KEY = {}
for _, b in ipairs(TL.BUILTINS) do TL.BUILTIN_BY_KEY[b.key] = b end

local ITEM_ICON = "Interface\\Icons\\INV_Potion_76"
local EVENT_ICON = "Interface\\Icons\\INV_Misc_Gear_01"

local function P() return WorkoutBuddy.db.profile end

-- Built-ins switched off while the page is open stay listed (dimmed) until
-- the page is opened again, so a mis-click is easy to undo.
TL.keepVisible = {}
function TL:ResetVisibility() wipe(self.keepVisible) end

------------------------------------------------------------------------
-- Descriptions
------------------------------------------------------------------------
--- Short line describing what a custom trigger listens for.
function TL.Describe(t)
    local TM = WorkoutBuddy.TriggerManager
    local o = t.options or {}
    if t.event == TM.ITEM_USED then
        local preset = o.preset or "named"
        if preset == "named" then
            local names = WorkoutBuddy.ItemUse.NameList(o.items)
            return "Using " .. (#names > 0 and table.concat(names, ", ") or "an item")
        end
        return "Using " .. (WorkoutBuddy.ItemUse.PRESET_LABELS[preset] or "an item"):lower()
    elseif t.event == "UNIT_HEALTH" then
        local ops = { ["<"] = "below", ["<="] = "at or below", [">"] = "above", [">="] = "at or above", ["=="] = "at", ["~="] = "not at" }
        local unit = o.unit or "player"
        return string.format("%s health %s %s%%", (unit:gsub("^%l", string.upper)), ops[o.op or "<"] or "below", tostring(o.value or 50))
    elseif t.event == "PLAYER_UPDATE_RESTING" then
        return (o.state == "active") and "Leaving an inn or city" or "Entering an inn or city"
    end
    return "Game event " .. tostring(TM.TriggerEvent(t) or "?")
end

------------------------------------------------------------------------
-- Entries
------------------------------------------------------------------------
local function GivesOf(mode, workout) return { mode = mode, workout = workout } end

--- Every trigger to show: built-ins that are on (or just switched off), then
-- all custom triggers.
function TL:Entries()
    local out = {}
    local p = P()
    for _, b in ipairs(self.BUILTINS) do
        if WorkoutBuddy:IsBuiltInTriggerSupported(b.key) and (p.event_map[b.key] or self.keepVisible[b.key]) then
            local set = p.builtin_workouts[b.key]
            local sub = b.desc
            if b.key == "play_timer" then
                sub = string.format("Every %d minutes of play without a break. AFK time does not count.", tonumber(p.play_timer_minutes) or 45)
            end
            out[#out + 1] = {
                id = "b:" .. b.key, kind = "builtin", key = b.key, label = b.label, sub = sub, icon = b.icon,
                enabled = p.event_map[b.key] and true or false,
                gives = set and GivesOf("set", set) or GivesOf("random"),
            }
        end
    end
    local TM = WorkoutBuddy.TriggerManager
    for i, t in ipairs(p.triggers) do
        local mode = (t.action == "fixed" and t.workout) and "set" or (t.action == "open_frame" and "open") or "random"
        out[#out + 1] = {
            id = "c:" .. i, kind = "custom", index = i,
            label = (t.name and t.name ~= "") and t.name or TL.Describe(t),
            sub = TL.Describe(t) .. (t.imported and "  |cFFFF8800(imported: open and save to enable)|r" or ""),
            icon = (t.event == TM.ITEM_USED) and ITEM_ICON or EVENT_ICON,
            enabled = t.enabled ~= false and not t.imported,
            locked = t.imported and true or false,
            canOpen = true,
            gives = GivesOf(mode, t.workout),
        }
    end
    return out
end

--- Built-ins that are supported here and currently off (offered in "Add").
function TL:AvailableBuiltins()
    local out = {}
    for _, b in ipairs(self.BUILTINS) do
        if WorkoutBuddy:IsBuiltInTriggerSupported(b.key) and not P().event_map[b.key] then out[#out + 1] = b end
    end
    return out
end

local function Changed(key)
    if key == "play_timer" then WorkoutBuddy:StartPlayTimer() end
end

function TL:SetEnabled(e, on)
    if e.kind == "builtin" then
        P().event_map[e.key] = on and true or false
        if not on then self.keepVisible[e.key] = true end
        Changed(e.key)
    else
        local t = P().triggers[e.index]
        if not t or t.imported then return end
        t.enabled = on and true or false
        WorkoutBuddy.TriggerManager:RegisterEvents()
    end
end

--- mode: "random", "set" (with workout) or "open" (custom triggers only).
function TL:SetGives(e, mode, workout)
    if e.kind == "builtin" then
        P().builtin_workouts[e.key] = (mode == "set") and WorkoutBuddy.CleanSetWorkout(workout) or nil
    else
        local t = P().triggers[e.index]
        if not t then return end
        if mode == "set" then
            t.workout = WorkoutBuddy.CleanSetWorkout(workout)
            t.action = t.workout and "fixed" or "workout"
        else
            t.workout = nil
            t.action = (mode == "open") and "open_frame" or "workout"
        end
    end
end

function TL:Remove(e)
    if e.kind == "builtin" then
        P().event_map[e.key] = false
        P().builtin_workouts[e.key] = nil
        self.keepVisible[e.key] = nil
        Changed(e.key)
    else
        table.remove(P().triggers, e.index)
        WorkoutBuddy.TriggerManager:Reset()
    end
end

function TL:AddBuiltin(key, mode, workout)
    if not self.BUILTIN_BY_KEY[key] then return false end
    P().event_map[key] = true
    self:SetGives({ kind = "builtin", key = key }, mode, workout)
    Changed(key)
    return true
end

------------------------------------------------------------------------
-- Saving a custom trigger (validation lives here, not in the UI)
------------------------------------------------------------------------
--- Validate and store a custom trigger. index replaces an existing one.
-- @return true, or false and a message for the player
function TL:SaveCustom(t, index)
    local TM = WorkoutBuddy.TriggerManager
    local IU = WorkoutBuddy.ItemUse
    t.options = type(t.options) == "table" and t.options or {}
    local evt = (t.event == "CUSTOM") and t.customEvent or t.event
    if type(evt) ~= "string" or evt == "" then return false, "Choose when this trigger fires." end
    evt = strtrim(evt):upper()
    if not TM.IsTriggerEventValid(evt) then
        return false, "'" .. evt .. "' is not an event this game client knows."
    end
    t.event, t.customEvent = evt, nil

    if t.event == TM.ITEM_USED and (t.options.preset or "named") == "named"
        and #IU.ParseNames(t.options.items) == 0 then
        return false, "Add at least one item or spell, or pick a group such as Any potion."
    end
    if t.action == "fixed" then
        t.workout = WorkoutBuddy.CleanSetWorkout(t.workout)
        if not t.workout then return false, "Choose the workout to add each time." end
    else
        t.workout = nil
        if t.action ~= "open_frame" then t.action = "workout" end
    end
    if t.custom and strtrim(t.custom) == "" then t.custom = nil end
    if t.custom then
        local ok, err = loadstring(t.custom)
        if not ok then return false, "Lua condition error: " .. tostring(err) end
    end

    t.imported, t._lastPass = nil, nil
    t.name = strtrim(t.name or "")
    if t.name == "" and t.event == TM.ITEM_USED then
        local preset = t.options.preset or "named"
        t.name = preset == "named" and table.concat(IU.NameList(t.options.items), ", ")
            or IU.PRESET_LABELS[preset] or ""
    end
    if t.enabled == nil then t.enabled = true end

    local triggers = P().triggers
    if index and triggers[index] then
        wipe(triggers[index])
        for k, v in pairs(t) do triggers[index][k] = v end
    else
        table.insert(triggers, t)
    end
    TM:Reset()
    return true
end
