-- ui/page_workouts.lua
-- Workouts page: your list (compact, filterable, edit in place), adding
-- your own, and the built-in library by category.

local _, WorkoutBuddy = ...
local UI = WorkoutBuddy.UI
local Settings = WorkoutBuddy.SettingsUI

local function P() return WorkoutBuddy.db.profile end
local function Workouts() return P().workouts end

local ROW_H = 30
local FILTER_FROM = 8 -- show the filter box once the list is this long

local function HasWorkout(name, unit)
    for _, w in ipairs(Workouts()) do
        if w.name:lower() == tostring(name):lower() and (w.unit or "") == (unit or "") then return true end
    end
    return false
end

--- Add to the list unless it is already there. Returns true if added.
function WorkoutBuddy:AddWorkout(name, amount, unit)
    name = strtrim(tostring(name or ""))
    unit = strtrim(tostring(unit or ""))
    if name == "" or HasWorkout(name, unit) then return false end
    table.insert(Workouts(), { name = name, amount = math.max(0, tonumber(amount) or 1), unit = unit })
    return true
end

------------------------------------------------------------------------
-- Your workouts
------------------------------------------------------------------------
local state = { filter = "", draft = { name = "", amount = "10", unit = "reps" }, category = nil }

local function BuildWorkoutRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_H)
    r.hover = UI.Tex(r, "BACKGROUND", "hover")
    r.hover:SetAllPoints(r)
    r.name = UI.Input(r, 260, {
        onCommit = function(v)
            v = strtrim(v)
            if v ~= "" then r.workout.name = v else r.name:SetText(r.workout.name) end
        end,
    })
    r.name:SetPoint("LEFT", 0, 0)
    r.amount = UI.Input(r, 60, {
        onCommit = function(v)
            local n = tonumber(v)
            if n and n >= 0 then r.workout.amount = n else r.amount:SetText(tostring(r.workout.amount or "")) end
        end,
    })
    r.amount:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
    r.unit = UI.Input(r, 100, { onCommit = function(v) r.workout.unit = strtrim(v) end })
    r.unit:SetPoint("LEFT", r.amount, "RIGHT", 8, 0)
    r.remove = UI.IconButton(r, "Interface\\Buttons\\UI-StopButton", 16, "Remove from your list", function()
        for i, w in ipairs(Workouts()) do
            if w == r.workout then table.remove(Workouts(), i) break end
        end
        Settings:Changed()
    end)
    r.remove:SetPoint("LEFT", r.unit, "RIGHT", 12, 0)
    return r
end

local listSpec = {
    type = "custom",
    search = { label = "Your workouts", desc = "workout list, edit name amount unit, remove, filter" },
    build = function(row)
        row.rows = {}
        row.filter = UI.Input(row, 260, {
            placeholder = "Filter your workouts...",
            onChange = function(text)
                state.filter = text
                Settings:Render()
                row.filter.edit:SetFocus() -- keep typing after the re-layout
            end,
        })
        row.heads = UI.Text(row, "GameFontHighlightSmall", "muted")
        row.heads:SetText("Workout                                                              Amount       Unit")
        row.empty = UI.Text(row, "GameFontHighlight", "muted")
    end,
    layout = function(row, width)
        local list = Workouts()
        local y = 0
        local useFilter = #list >= FILTER_FROM
        row.filter:SetShown(useFilter)
        if useFilter then
            row.filter:ClearAllPoints()
            row.filter:SetPoint("TOPLEFT", 0, -y)
            if not row.filter.edit:HasFocus() then row.filter:SetText(state.filter) end
            y = y + 32
        else
            state.filter = ""
        end
        local needle = strtrim(state.filter):lower()
        local shown = 0
        for _, w in ipairs(list) do
            if needle == "" or w.name:lower():find(needle, 1, true) then
                shown = shown + 1
                local r = row.rows[shown] or BuildWorkoutRow(row)
                row.rows[shown] = r
                r.workout = w
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                r:SetWidth(width)
                if not r.name.edit:HasFocus() then r.name:SetText(w.name) end
                if not r.amount.edit:HasFocus() then r.amount:SetText(tostring(w.amount or "")) end
                if not r.unit.edit:HasFocus() then r.unit:SetText(w.unit or "") end
                r:Show()
                y = y + ROW_H + 2
            end
        end
        for i = shown + 1, #row.rows do row.rows[i]:Hide() end
        row.empty:ClearAllPoints()
        row.empty:SetPoint("TOPLEFT", 4, -y - 4)
        if #list == 0 then
            row.empty:SetText("Your list is empty. Add your own below or pick from the library.")
        elseif shown == 0 then
            row.empty:SetText("No workouts match \"" .. state.filter .. "\".")
        end
        row.empty:SetShown(shown == 0)
        if shown == 0 then y = y + 26 end
        return y + 4
    end,
}

local addSpec = {
    type = "custom",
    search = { label = "Add your own workout", desc = "new custom exercise" },
    build = function(row)
        row.name = UI.Input(row, 260, { placeholder = "Workout name", onCommit = function(v) state.draft.name = v end })
        row.name:SetPoint("TOPLEFT", 0, -4)
        row.amount = UI.Input(row, 60, { placeholder = "10", onCommit = function(v) state.draft.amount = v end })
        row.amount:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
        row.unit = UI.Input(row, 100, { placeholder = "reps", onCommit = function(v) state.draft.unit = v end })
        row.unit:SetPoint("LEFT", row.amount, "RIGHT", 8, 0)
        row.add = UI.Button(row, "Add", 70, 24, "primary", function()
            state.draft.name = row.name:GetText()
            state.draft.amount = row.amount:GetText()
            state.draft.unit = row.unit:GetText()
            local name = strtrim(state.draft.name)
            if name == "" then return Settings:Status("|cFFFF5555Type a name first.|r") end
            if WorkoutBuddy:AddWorkout(name, tonumber(state.draft.amount) or 10, state.draft.unit) then
                state.draft.name = ""
                Settings:Status("|cFF66FF66Added " .. name .. ".|r")
            else
                Settings:Status(name .. " is already in your list.")
            end
            Settings:Changed()
        end)
        row.add:SetPoint("LEFT", row.unit, "RIGHT", 12, 0)
    end,
    layout = function(row)
        if not row.name.edit:HasFocus() then row.name:SetText(state.draft.name) end
        if not row.amount.edit:HasFocus() then row.amount:SetText(state.draft.amount) end
        if not row.unit.edit:HasFocus() then row.unit:SetText(state.draft.unit) end
        return 34
    end,
}

------------------------------------------------------------------------
-- Library
------------------------------------------------------------------------
local function Category()
    local cats = WorkoutBuddy.GetLibraryCategories()
    if not state.category then state.category = cats[1] end
    return state.category
end

local librarySpec = {
    type = "custom",
    search = { label = "Workout library", desc = "built-in exercises: cardio, stretching, posture, strength, eyes, breathing, habits" },
    build = function(row)
        row.chips = {}
        row.items = {}
        row.addAll = UI.Button(row, "Add whole category", 160, 24, nil, function()
            local added = 0
            for _, w in ipairs(WorkoutBuddy.WorkoutLibrary) do
                if w.category == Category() and WorkoutBuddy:AddWorkout(w.name, w.amount, w.unit) then added = added + 1 end
            end
            Settings:Status(string.format("Added %d workout(s) from %s.", added, Category()))
            Settings:Changed()
        end)
    end,
    layout = function(row, width)
        local y, x = 0, 0
        for i, cat in ipairs(WorkoutBuddy.GetLibraryCategories()) do
            local chip = row.chips[i]
            if not chip then
                chip = UI.Chip(row, cat, function(self)
                    state.category = self.cat
                    Settings:Changed()
                end)
                chip.cat = cat
                row.chips[i] = chip
            end
            chip:SetSelected(cat == Category())
            if x + chip:GetWidth() > width then x = 0; y = y + 28 end
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", x, -y)
            chip:Show()
            x = x + chip:GetWidth() + 6
        end
        y = y + 34
        local n = 0
        for _, w in ipairs(WorkoutBuddy.WorkoutLibrary) do
            if w.category == Category() then
                n = n + 1
                local r = row.items[n]
                if not r then
                    r = CreateFrame("Frame", nil, row)
                    r:SetHeight(26)
                    r.hover = UI.Tex(r, "BACKGROUND", "hover")
                    r.hover:SetAllPoints(r)
                    r.text = UI.Text(r, "GameFontHighlight", "text")
                    r.text:SetPoint("LEFT", 6, 0)
                    r.add = UI.Button(r, "+ Add", 80, 22, nil, function()
                        if WorkoutBuddy:AddWorkout(r.w.name, r.w.amount, r.w.unit) then
                            Settings:Status("|cFF66FF66Added " .. r.w.name .. ".|r")
                        end
                        Settings:Changed()
                    end)
                    r.add:SetPoint("RIGHT", -4, 0)
                    row.items[n] = r
                end
                r.w = w
                r:SetWidth(width)
                r.text:SetText(w.name .. "  |cFF888888" .. tostring(w.amount) .. " " .. (w.unit or "") .. "|r")
                local have = HasWorkout(w.name, w.unit)
                r.add:SetLabel(have and "In your list" or "+ Add")
                r.add:SetEnabledState(not have)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                r:Show()
                y = y + 28
            end
        end
        for i = n + 1, #row.items do row.items[i]:Hide() end
        row.addAll:ClearAllPoints()
        row.addAll:SetPoint("TOPLEFT", 0, -y - 4)
        return y + 34
    end,
}

Settings:AddPage({
    key = "workouts",
    label = "Workouts",
    icon = "Interface\\Icons\\Spell_Nature_Strength",
    order = 2,
    count = function() return tostring(#Workouts()) end,
    specs = function()
        return {
            { type = "section", label = "Your workouts",
                desc = "Random workouts are picked from this list. Edit a name, amount or unit right in the row." },
            listSpec,
            { type = "section", label = "Add your own" },
            addSpec,
            { type = "section", label = "Workout library", desc = "Desk-friendly exercises you can do in a minute or two." },
            librarySpec,
            { type = "section", label = "Reset" },
            { type = "buttons", items = {
                { text = "Restore starter list", width = 170, confirm = "Replace your workout list with the starter workouts?",
                    func = function() P().workouts = WorkoutBuddy.CopyWorkouts(WorkoutBuddy.DEFAULT_WORKOUTS) end },
                { text = "Remove all", width = 120, kind = "danger", confirm = "Remove every workout from your list?",
                    func = function() wipe(Workouts()) end },
            } },
        }
    end,
})
