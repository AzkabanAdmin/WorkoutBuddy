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
    local ok, _, _, _, _, _, classID, subclassID = pcall(fn, itemID)
    if ok then return classID, subclassID end
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
    local bySpell, byName = {}, {}
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
                    if spellName or spellID then
                        local classID, subclassID = ItemInstant(itemID)
                        local info = {
                            itemID = itemID,
                            name = (ItemName(itemID) or ""):lower(),
                            spellName = (spellName or ""):lower(),
                            classID = classID,
                            subclassID = subclassID,
                        }
                        if spellID then bySpell[spellID] = info end
                        if spellName then byName[spellName:lower()] = info end
                    end
                end
            end
        end
    end
    self.bySpell, self.byName = bySpell, byName
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
    return { name = "", spellName = spellName:lower() } -- a plain spell, not from an item
end

local function HasWord(info, word)
    return (info.name ~= "" and info.name:find(word, 1, true))
        or (info.spellName ~= "" and info.spellName:find(word, 1, true))
end

--- Split "Mana Potion, Healthstone" into lowercase names.
function ItemUse.ParseNames(text)
    local names = {}
    for part in tostring(text or ""):gmatch("[^,;]+") do
        local n = strtrim(part):lower()
        if n ~= "" then names[#names + 1] = n end
    end
    return names
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
        self.bySpell, self.byName = nil, nil
        return
    end
    if not WorkoutBuddy.SafeRegisterEvent(self.frame, "BAG_UPDATE_DELAYED") then
        WorkoutBuddy.SafeRegisterEvent(self.frame, "BAG_UPDATE")
    end
    WorkoutBuddy.SafeRegisterEvent(self.frame, "PLAYER_ENTERING_WORLD")
    self:Rebuild()
end
