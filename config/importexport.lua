-- config/importexport.lua
-- Share workout lists and back up whole profiles.
--
-- Imports never run code. Workout lists are read by a small parser that only
-- understands { name = "...", amount = 10, unit = "..." } entries, and profiles
-- are decoded with AceSerializer. Custom trigger conditions inside an imported
-- profile stay switched off until the player reviews and saves them.

local _, WorkoutBuddy = ...
WorkoutBuddy.ConfigTabs = WorkoutBuddy.ConfigTabs or {}

local AceSerializer = LibStub("AceSerializer-3.0")

local MAX_WORKOUTS = 200
local MAX_NAME = 80
local PROFILE_PREFIX = "WOB1:"

local pending = { workouts = "", profile = "" }

------------------------------------------------------------------------
-- Workout list format
------------------------------------------------------------------------
function WorkoutBuddy:SerializeWorkouts()
    local items = {}
    for _, w in ipairs(self.db.profile.workouts or {}) do
        items[#items + 1] = string.format("{name=%q,amount=%s,unit=%q}",
            w.name or "", tostring(tonumber(w.amount) or 0), w.unit or "")
    end
    return "{" .. table.concat(items, ",") .. "}"
end

local ESCAPES = { n = "\n", t = "\t", r = "\r", ["\\"] = "\\", ['"'] = '"', ["'"] = "'", ["\n"] = "\n" }

--- Parse a workout list string without executing it.
-- @return list or nil, errorMessage
function WorkoutBuddy.ParseWorkoutList(str)
    if type(str) ~= "string" then return nil, "nothing to import" end
    local pos, len = 1, #str

    local function fail(msg) error({ msg = msg .. " (at character " .. pos .. ")" }, 0) end
    local function skip() pos = str:find("[^%s]", pos) or (len + 1) end
    local function peek() skip() return str:sub(pos, pos) end
    local function expect(c)
        if peek() ~= c then fail("expected '" .. c .. "'") end
        pos = pos + 1
    end

    local function parseString()
        local q = peek()
        if q ~= '"' and q ~= "'" then fail("expected text in quotes") end
        pos = pos + 1
        local out = {}
        while pos <= len do
            local c = str:sub(pos, pos)
            if c == q then
                pos = pos + 1
                return table.concat(out)
            elseif c == "\\" then
                local n = str:sub(pos + 1, pos + 1)
                if ESCAPES[n] then
                    out[#out + 1] = ESCAPES[n]
                    pos = pos + 2
                else
                    local digits = str:match("^%d%d?%d?", pos + 1)
                    if not digits then fail("bad escape in text") end
                    out[#out + 1] = string.char(tonumber(digits) % 256)
                    pos = pos + 1 + #digits
                end
            elseif c == "\n" then
                fail("unfinished text")
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
        fail("unfinished text")
    end

    local function parseNumber()
        skip()
        local s = str:match("^%-?%d+%.?%d*", pos)
        if not s then fail("expected a number") end
        pos = pos + #s
        return tonumber(s)
    end

    local function parseValue()
        local c = peek()
        if c == '"' or c == "'" then return parseString() end
        return parseNumber()
    end

    local function separator()
        local c = peek()
        if c == "," or c == ";" then pos = pos + 1 end
    end

    local ok, result = pcall(function()
        local list = {}
        expect("{")
        while peek() ~= "}" do
            if pos > len then fail("unexpected end") end
            expect("{")
            local entry = {}
            while peek() ~= "}" do
                if pos > len then fail("unexpected end") end
                local key = str:match("^[%a_][%w_]*", pos)
                if not key then fail("expected a field name") end
                pos = pos + #key
                expect("=")
                entry[key] = parseValue()
                separator()
            end
            pos = pos + 1
            list[#list + 1] = entry
            if #list > MAX_WORKOUTS then fail("too many workouts") end
            separator()
        end
        pos = pos + 1
        skip()
        if pos <= len then fail("unexpected text after the list") end
        return list
    end)
    if not ok then
        return nil, type(result) == "table" and result.msg or tostring(result)
    end

    -- Keep only well-formed entries
    local clean = {}
    for _, e in ipairs(result) do
        if type(e.name) == "string" and e.name:match("%S") then
            clean[#clean + 1] = {
                name = strtrim(e.name):sub(1, MAX_NAME),
                amount = math.max(0, tonumber(e.amount) or 1),
                unit = type(e.unit) == "string" and strtrim(e.unit):sub(1, 20) or "",
            }
        end
    end
    if #clean == 0 then return nil, "no workouts found" end
    return clean
end

function WorkoutBuddy:DeserializeWorkouts(str)
    local list, err = self.ParseWorkoutList(strtrim(str or ""))
    if not list then
        self:Print("|cFFFF5555Import failed:|r " .. err)
        return false
    end
    self.db.profile.workouts = list
    self.db.profile.workouts_seeded = true
    self:Print(string.format("Imported %d workout(s).", #list))
    return true
end

------------------------------------------------------------------------
-- Profile format
------------------------------------------------------------------------
function WorkoutBuddy:SerializeProfile()
    local copy = CopyTable(self.db.profile)
    copy.reminder_queue = nil
    return PROFILE_PREFIX .. AceSerializer:Serialize(copy)
end

--- Validate and apply an imported profile.
function WorkoutBuddy:DeserializeProfile(str)
    str = strtrim(str or "")
    if str:sub(1, #PROFILE_PREFIX) == PROFILE_PREFIX then
        str = str:sub(#PROFILE_PREFIX + 1)
    end
    local ok, data = AceSerializer:Deserialize(str)
    if not ok or type(data) ~= "table" then
        self:Print("|cFFFF5555Profile import failed:|r that does not look like a Workout Buddy profile.")
        return false
    end

    -- Only accept known settings, with matching types
    local known = self.defaults.profile
    local accepted = { workouts = "table", workouts_seeded = "boolean" }
    for k, v in pairs(known) do accepted[k] = type(v) end
    for k in pairs(data) do
        if not accepted[k] or (accepted[k] ~= "nil" and type(data[k]) ~= accepted[k]) then
            data[k] = nil
        end
    end

    -- Imported trigger code stays off until reviewed
    local flagged = 0
    for _, t in ipairs(type(data.triggers) == "table" and data.triggers or {}) do
        if type(t) == "table" and type(t.custom) == "string" and t.custom:match("%S") then
            t.imported = true
            t.enabled = false
            flagged = flagged + 1
        end
    end

    -- Start from defaults, then lay the imported settings on top so anything
    -- missing from the import keeps a sensible value.
    local queue = CopyTable(self.db.profile.reminder_queue or {})
    self.db:ResetProfile(false, true)
    local p = self.db.profile
    local replaceWhole = { workouts = true, triggers = true, stats = true }
    for k, v in pairs(data) do
        if type(v) == "table" and type(p[k]) == "table" and not replaceWhole[k] then
            for kk, vv in pairs(v) do p[k][kk] = vv end
        else
            p[k] = v
        end
    end
    p.reminder_queue = queue
    self:OnProfileChanged()

    self:Print("Profile imported.")
    if flagged > 0 then
        self:Print(string.format("|cFFFF8800%d imported trigger(s) contain Lua code and were switched off. Review them in General > Custom triggers and save to enable.|r", flagged))
    end
    return true
end

------------------------------------------------------------------------
-- Tab
------------------------------------------------------------------------
function WorkoutBuddy.ConfigTabs.ImportExport()
    return {
        type = "group",
        name = "Import/Export",
        order = 6,
        args = {
            workoutsHeader = { type = "header", name = "Workout list", order = 1 },
            exportBox = {
                type = "input",
                name = "Export (copy this to share your list)",
                width = "full",
                multiline = 4,
                order = 2,
                get = function() return WorkoutBuddy:SerializeWorkouts() end,
                set = function() end,
            },
            importBox = {
                type = "input",
                name = "Import (paste a list here, then click Import)",
                width = "full",
                multiline = 4,
                order = 3,
                get = function() return pending.workouts end,
                set = function(_, val) pending.workouts = val end,
            },
            importButton = {
                type = "execute",
                name = "Import",
                order = 4,
                disabled = function() return strtrim(pending.workouts) == "" end,
                confirm = true,
                confirmText = "Replace your current workout list with the imported one?",
                func = function()
                    if WorkoutBuddy:DeserializeWorkouts(pending.workouts) then
                        pending.workouts = ""
                        WorkoutBuddy:RebuildWorkoutListOptions()
                        WorkoutBuddy:NotifyConfigChanged()
                    end
                end,
            },

            profileHeader = { type = "header", name = "Whole profile", order = 10 },
            profileDesc = {
                type = "description",
                name = "Backs up every setting, workout, trigger and your stats history.",
                order = 10.5,
            },
            profileExportBox = {
                type = "input",
                name = "Export",
                width = "full",
                multiline = 4,
                order = 11,
                get = function() return WorkoutBuddy:SerializeProfile() end,
                set = function() end,
            },
            profileImportBox = {
                type = "input",
                name = "Import",
                width = "full",
                multiline = 4,
                order = 12,
                get = function() return pending.profile end,
                set = function(_, val) pending.profile = val end,
            },
            profileImportButton = {
                type = "execute",
                name = "Import profile",
                order = 13,
                disabled = function() return strtrim(pending.profile) == "" end,
                confirm = true,
                confirmText = "Overwrite every setting in the current profile?",
                func = function()
                    if WorkoutBuddy:DeserializeProfile(pending.profile) then
                        pending.profile = ""
                    end
                end,
            },
        },
    }
end
