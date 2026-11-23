-- item_use.lua
-- Recognizes when the player uses an item (potion, healthstone, food...) or
-- casts a named spell, for "I use an item or spell" triggers.
--
-- Using an item casts its "use" spell, so a successful spellcast is matched
-- against the items in the player's bags. The bag lookup is rebuilt when the
-- bags change, which keeps each spellcast check to a table lookup. It only
-- runs while at least one item trigger is enabled.

local _, WorkoutBuddy = ...

local ItemUse = {}
WorkoutBuddy.ItemUse = ItemUse

-- Presets match the item's class (Consumable = 0) and subclass where the
-- client provides them, and otherwise English words in the item or spell
-- name (Classic Era files most consumables under one subclass).
ItemUse.PRESETS = {
    potion = { label = "Any potion", sub = { [1] = true }, words = { "potion" } },
    healthstone = { label = "Healthstone", words = { "healthstone" } },
    food = { label = "Food or drink", sub = { [5] = true }, words = { "food", "drink", "refreshment" } },
    flask = { label = "Flask or elixir", sub = { [2] = true, [3] = true }, words = { "flask", "elixir" } },
    consumable = { label = "Any consumable", anyConsumable = true },
}
ItemUse.PRESET_ORDER = { "named", "potion", "healthstone", "food", "flask", "consumable" }
ItemUse.PRESET_LABELS = { named = "Items or spells I name" }
for key, p in pairs(ItemUse.PRESETS) do ItemUse.PRESET_LABELS[key] = p.label end

local CONSUMABLE_CLASS = 0

------------------------------------------------------------------------
-- Client API wrappers (namespaced first, with fallbacks)
------------------------------------------------------------------------
local function ItemSpell(itemID)
    local fn = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if not fn then return nil end
    local ok, name, spellID = pcall(fn, itemID)
    if ok then return name, spellID end
end

local function ItemInstant(itemID)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return nil end
    local ok, _, _, _, _, icon, classID, subclassID = pcall(fn, itemID)
    if ok then return classID, subclassID, icon end
end

local function ItemName(itemID)
    if C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok and name then return name end
    end
    if GetItemInfo then
        local ok, name = pcall(GetItemInfo, itemID)
        if ok then return name end
    end
end

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and name then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok then return name end
    end
end

local function ContainerAPI()
    local c = C_Container
    if c and c.GetContainerNumSlots and c.GetContainerItemID then
        return c.GetContainerNumSlots, c.GetContainerItemID
    end
    return GetContainerNumSlots, GetContainerItemID
end

------------------------------------------------------------------------
-- Bag lookup: use-spell -> item details
------------------------------------------------------------------------
function ItemUse:Rebuild()
    local bySpell, byName, items = {}, {}, {}
    local numSlots, itemIDAt = ContainerAPI()
    if numSlots and itemIDAt then
        local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
        local seen = {}
        for bag = 0, lastBag do
            local okN, slots = pcall(numSlots, bag)
            for slot = 1, (okN and tonumber(slots)) or 0 do
                local okI, itemID = pcall(itemIDAt, bag, slot)
                if okI and itemID and not seen[itemID] then
                    seen[itemID] = true
                    local spellName, spellID = ItemSpell(itemID)
                    local displayName = ItemName(itemID)
                    if (spellName or spellID) and displayName then
                        local classID, subclassID, icon = ItemInstant(itemID)
                        local info = {
                            itemID = itemID,
                            displayName = displayName,
                            icon = icon,
                            name = displayName:lower(),
                            spellName = (spellName or ""):lower(),
                            classID = classID,
                            subclassID = subclassID,
                        }
                        items[#items + 1] = info
                        if spellID then bySpell[spellID] = info end
                        if spellName then byName[spellName:lower()] = info end
                    end
                end
            end
        end
    end
    table.sort(items, function(a, b)
        local ac, bc = a.classID == CONSUMABLE_CLASS, b.classID == CONSUMABLE_CLASS
        if ac ~= bc then return ac end -- consumables first
        return a.displayName < b.displayName
    end)
    self.bySpell, self.byName, self.items = bySpell, byName, items
end

--- Usable items in the bags (consumables first), for the editor's picker.
function ItemUse:BagItems()
    self:Rebuild()
    return self.items
end

--- Bag items whose name contains the typed text (case-insensitive).
function ItemUse:Suggest(text, limit)
    local needle = ItemUse.CleanName(text):lower()
    local out = {}
    if needle == "" then return out end
    for _, info in ipairs(self.items or self:BagItems()) do
        if info.name:find(needle, 1, true) then
            out[#out + 1] = info
            if #out >= (limit or 6) then break end
        end
    end
    return out
end

--- Details for a successful spellcast: the item it came from, if any, plus
-- the spell's own name. Nil when nothing is known about it.
function ItemUse:Lookup(spellID)
    if type(spellID) ~= "number" then return nil end
    if not self.bySpell then self:Rebuild() end
    local info = self.bySpell[spellID]
    if info then return info end
    local spellName = SpellName(spellID)
    if not spellName then return nil end
    info = self.byName[spellName:lower()]
    if info then return info end
    return { name = "", spellName = spellName:lower(), displayName = spellName } -- a plain spell, not from an item
end

local function HasWord(info, word)
    return (info.name ~= "" and info.name:find(word, 1, true))
        or (info.spellName ~= "" and info.spellName:find(word, 1, true))
end

--- Plain name from typed text or a shift-clicked / dragged item link.
-- "|cff..|Hitem:..|h[Major Mana Potion]|h|r" becomes "Major Mana Potion";
-- quality and texture icons inside the name are removed.
function ItemUse.CleanName(text)
    text = tostring(text or "")
    text = text:match("|h%[(.-)%]|h") or text
    text = text:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return strtrim(text)
end

--- The names in a trigger's list, in their original spelling.
function ItemUse.NameList(text)
    local names = {}
    -- links may contain commas in other fields, so pull them out first
    local rest = tostring(text or ""):gsub("|H.-|h%[(.-)%]|h", function(n) return "," .. n .. "," end)
    for part in rest:gmatch("[^,;]+") do
        local n = ItemUse.CleanName(part)
        if n ~= "" then names[#names + 1] = n end
    end
    return names
end

--- Split "Mana Potion, Healthstone" into lowercase names.
function ItemUse.ParseNames(text)
    local names = ItemUse.NameList(text)
    for i, n in ipairs(names) do names[i] = n:lower() end
    return names
end

--- The list text with a name added (no duplicates) or removed.
function ItemUse.AddName(text, name)
    name = ItemUse.CleanName(name)
    local names = ItemUse.NameList(text)
    if name == "" then return table.concat(names, ", ") end
    for _, n in ipairs(names) do
        if n:lower() == name:lower() then return table.concat(names, ", ") end
    end
    names[#names + 1] = name
    return table.concat(names, ", ")
end

function ItemUse.RemoveName(text, name)
    local out = {}
    for _, n in ipairs(ItemUse.NameList(text)) do
        if n:lower() ~= tostring(name):lower() then out[#out + 1] = n end
    end
    return table.concat(out, ", ")
end

------------------------------------------------------------------------
-- "Use an item to add it": catch the next item or spell the player uses
------------------------------------------------------------------------
function ItemUse:Capture(callback, seconds)
    self:StopCapture()
    self:Rebuild()
    local f = self.captureFrame or CreateFrame("Frame")
    self.captureFrame = f
    f:SetScript("OnEvent", function(_, _, unit, _, spellID)
        if unit ~= "player" or WorkoutBuddy.IsSecret(spellID) then return end
        local info = ItemUse:Lookup(spellID)
        if not (info and info.displayName) then return end
        ItemUse:StopCapture()
        callback(info.displayName)
    end)
    if not WorkoutBuddy.SafeRegisterEvent(f, "UNIT_SPELLCAST_SUCCEEDED") then return false end
    self.captureTimer = C_Timer.NewTimer(seconds or 30, function()
        ItemUse.captureTimer = nil
        ItemUse:StopCapture()
        callback(nil)
    end)
    return true
end

function ItemUse:StopCapture()
    if self.captureFrame then self.captureFrame:UnregisterAllEvents() end
    if self.captureTimer then
        self.captureTimer:Cancel()
        self.captureTimer = nil
    end
end

--- Does this use match a trigger's options ({ preset = ..., items = "..." })?
function ItemUse.Matches(options, info)
    if not info then return false end
    local preset = options.preset or "named"
    if preset == "named" then
        for _, n in ipairs(ItemUse.ParseNames(options.items)) do
            if info.name == n or info.spellName == n or HasWord(info, n) then return true end
        end
        return false
    end
    local p = ItemUse.PRESETS[preset]
    if not p then return false end
    if info.classID == CONSUMABLE_CLASS then
        if p.anyConsumable then return true end
        if p.sub and p.sub[info.subclassID] then return true end
    end
    for _, word in ipairs(p.words or {}) do
        if HasWord(info, word) then return true end
    end
    return false
end

------------------------------------------------------------------------
-- Turned on by TriggerManager while an item trigger is enabled
------------------------------------------------------------------------
function ItemUse:SetActive(on)
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function() ItemUse:Rebuild() end)
    end
    self.frame:UnregisterAllEvents()
    self.active = on and true or false
    if not on then
        self.bySpell, self.byName, self.items = nil, nil, nil
        return
    end
    if not WorkoutBuddy.SafeRegisterEvent(self.frame, "BAG_UPDATE_DELAYED") then
        WorkoutBuddy.SafeRegisterEvent(self.frame, "BAG_UPDATE")
    end
    WorkoutBuddy.SafeRegisterEvent(self.frame, "PLAYER_ENTERING_WORLD")
    self:Rebuild()
end
