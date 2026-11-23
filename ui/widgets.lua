-- ui/widgets.lua
-- Workout Buddy's own UI kit: themes, panels, buttons, switches, sliders,
-- inputs, dropdowns, chips and scroll areas. Plain frames and textures only,
-- so it looks the same on every client and needs no libraries.

local _, WorkoutBuddy = ...

local UI = {}
WorkoutBuddy.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------------------
-- Themes
------------------------------------------------------------------------
UI.THEMES = {
    forest = {
        label = "Forest (default)",
        bg = { 0.050, 0.060, 0.055, 0.97 }, panel = { 0.085, 0.100, 0.090, 1 }, nav = { 0.065, 0.078, 0.070, 1 },
        border = { 0.20, 0.27, 0.22, 1 }, accent = { 0.32, 0.80, 0.44, 1 }, header = { 0.07, 0.17, 0.10, 1 },
        title = { 1.00, 0.82, 0.25, 1 },
    },
    midnight = {
        label = "Midnight",
        bg = { 0.045, 0.055, 0.080, 0.97 }, panel = { 0.075, 0.090, 0.130, 1 }, nav = { 0.060, 0.070, 0.105, 1 },
        border = { 0.20, 0.25, 0.36, 1 }, accent = { 0.36, 0.64, 1.00, 1 }, header = { 0.07, 0.11, 0.23, 1 },
        title = { 0.86, 0.92, 1.00, 1 },
    },
    ember = {
        label = "Ember",
        bg = { 0.070, 0.055, 0.045, 0.97 }, panel = { 0.115, 0.085, 0.065, 1 }, nav = { 0.090, 0.068, 0.052, 1 },
        border = { 0.34, 0.22, 0.14, 1 }, accent = { 1.00, 0.56, 0.22, 1 }, header = { 0.22, 0.10, 0.05, 1 },
        title = { 1.00, 0.84, 0.55, 1 },
    },
    violet = {
        label = "Violet",
        bg = { 0.060, 0.050, 0.075, 0.97 }, panel = { 0.100, 0.080, 0.125, 1 }, nav = { 0.078, 0.062, 0.098, 1 },
        border = { 0.29, 0.22, 0.38, 1 }, accent = { 0.72, 0.52, 1.00, 1 }, header = { 0.17, 0.09, 0.25, 1 },
        title = { 0.92, 0.85, 1.00, 1 },
    },
    classic = {
        label = "Classic gold",
        bg = { 0.070, 0.060, 0.040, 0.97 }, panel = { 0.110, 0.090, 0.060, 1 }, nav = { 0.085, 0.070, 0.045, 1 },
        border = { 0.42, 0.33, 0.15, 1 }, accent = { 1.00, 0.80, 0.20, 1 }, header = { 0.20, 0.15, 0.06, 1 },
        title = { 1.00, 0.82, 0.20, 1 },
    },
}
UI.THEME_ORDER = { "forest", "midnight", "ember", "violet", "classic" }

-- Fixed colors shared by every theme
UI.COLORS = {
    text = { 0.92, 0.92, 0.92, 1 }, muted = { 0.58, 0.60, 0.60, 1 }, danger = { 0.85, 0.25, 0.22, 1 },
    hover = { 1, 1, 1, 0.06 }, off = { 0.22, 0.23, 0.24, 1 }, input = { 0.03, 0.035, 0.035, 1 },
}

function UI.Theme()
    local key = WorkoutBuddy.db and WorkoutBuddy.db.profile.theme
    return UI.THEMES[key] or UI.THEMES.forest
end

--- Color for a role: a theme role ("accent", "panel"...) or a fixed one.
function UI.Color(role)
    return UI.Theme()[role] or UI.COLORS[role] or UI.COLORS.text
end

-- Every themed texture is remembered so a theme change repaints at once.
UI.painted = setmetatable({}, { __mode = "k" })

function UI.Paint(tex, role, alpha)
    UI.painted[tex] = { role = role, alpha = alpha }
    local c = UI.Color(role)
    tex:SetColorTexture(c[1], c[2], c[3], alpha or c[4] or 1)
    return tex
end

function UI.Repaint()
    for tex, p in pairs(UI.painted) do
        local c = UI.Color(p.role)
        tex:SetColorTexture(c[1], c[2], c[3], p.alpha or c[4] or 1)
    end
    for fs, role in pairs(UI.paintedText) do
        local c = UI.Color(role)
        fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end
    for _, fn in ipairs(UI.repaintHooks) do fn() end
end
UI.paintedText = setmetatable({}, { __mode = "k" })
UI.repaintHooks = {}

function UI.Tex(parent, layer, role, alpha, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    return UI.Paint(t, role, alpha)
end

function UI.Text(parent, template, role, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlight")
    if role then
        UI.paintedText[fs] = role
        local c = UI.Color(role)
        fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end
    fs:SetJustifyH("LEFT")
    return fs
end

--- Fill plus a 1 pixel border.
function UI.Box(f, fillRole, borderRole, fillAlpha)
    f.bg = UI.Tex(f, "BACKGROUND", fillRole or "panel", fillAlpha)
    f.bg:SetAllPoints(f)
    local b = borderRole or "border"
    local top = UI.Tex(f, "BORDER", b); top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    local bot = UI.Tex(f, "BORDER", b); bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(1)
    local lft = UI.Tex(f, "BORDER", b); lft:SetPoint("TOPLEFT"); lft:SetPoint("BOTTOMLEFT"); lft:SetWidth(1)
    local rgt = UI.Tex(f, "BORDER", b); rgt:SetPoint("TOPRIGHT"); rgt:SetPoint("BOTTOMRIGHT"); rgt:SetWidth(1)
    f.borders = { top, bot, lft, rgt }
    return f
end

function UI.SetBorderRole(f, role)
    for _, t in ipairs(f.borders or {}) do UI.Paint(t, role) end
end

local function Tooltip(owner, title, text)
    if not title then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1, 1, true)
    if text and text ~= "" then GameTooltip:AddLine(text, nil, nil, nil, true) end
    GameTooltip:Show()
end
UI.Tooltip = Tooltip

------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------
--- kind: "normal", "primary" (accent fill) or "danger".
function UI.Button(parent, text, w, h, kind, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 120, h or 24)
    UI.Box(b, kind == "primary" and "accent" or "panel", kind == "danger" and "danger" or (kind == "primary" and "accent" or "border"),
        kind == "primary" and 0.85 or nil)
    b.hl = UI.Tex(b, "HIGHLIGHT", "hover")
    b.hl:SetAllPoints(b)
    b.label = UI.Text(b, "GameFontHighlight", kind == "primary" and nil or (kind == "danger" and "danger" or "text"))
    if kind == "primary" then b.label:SetTextColor(0.05, 0.05, 0.05, 1) end
    b.label:SetPoint("CENTER")
    b.label:SetJustifyH("CENTER")
    b.label:SetText(text or "")
    b.kind = kind
    function b:SetLabel(t) self.label:SetText(t) end
    local enable = b.Enable
    function b:SetEnabledState(on)
        if on then self:Enable() else self:Disable() end
        self:SetAlpha(on and 1 or 0.4)
    end
    if onClick then b:SetScript("OnClick", function() onClick(b) end) end
    b:SetScript("OnEnter", function(self) Tooltip(self, self.tipTitle, self.tipText) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b._enable = enable
    return b
end

--- A small square icon button (close, remove...).
function UI.IconButton(parent, texture, size, tip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 18, size or 18)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.icon:SetTexture(texture)
    b.icon:SetVertexColor(0.75, 0.75, 0.75)
    b:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        Tooltip(self, tip)
    end)
    b:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.75, 0.75, 0.75)
        GameTooltip:Hide()
    end)
    if onClick then b:SetScript("OnClick", function() onClick(b) end) end
    return b
end

------------------------------------------------------------------------
-- Switch (on/off toggle)
------------------------------------------------------------------------
function UI.Switch(parent, onChange)
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(36, 18)
    s.track = s:CreateTexture(nil, "BACKGROUND")
    s.track:SetAllPoints(s)
    s.knob = s:CreateTexture(nil, "ARTWORK")
    s.knob:SetSize(14, 14)
    s.knob:SetColorTexture(0.95, 0.95, 0.95, 1)
    s.value = false
    function s:Paint()
        local c = self.value and UI.Color("accent") or UI.COLORS.off
        self.track:SetColorTexture(c[1], c[2], c[3], self.disabled and 0.4 or 1)
        self.knob:ClearAllPoints()
        self.knob:SetPoint(self.value and "RIGHT" or "LEFT", self, self.value and "RIGHT" or "LEFT", self.value and -2 or 2, 0)
        self.knob:SetAlpha(self.disabled and 0.5 or 1)
    end
    function s:SetValue(v) self.value = v and true or false; self:Paint() end
    function s:GetValue() return self.value end
    function s:SetDisabled(d) self.disabled = d and true or false; self:Paint() end
    s:SetScript("OnClick", function(self)
        if self.disabled then return end
        self:SetValue(not self.value)
        if onChange then onChange(self.value) end
    end)
    table.insert(UI.repaintHooks, function() s:Paint() end)
    s:Paint()
    return s
end

------------------------------------------------------------------------
-- Input
------------------------------------------------------------------------
--- opts: numeric, onCommit(text) on Enter or focus lost, onChange(text) while
-- typing, placeholder, multiline-free single line.
function UI.Input(parent, w, opts)
    opts = opts or {}
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w or 120, 24)
    UI.Box(holder, "input", "border")
    local e = CreateFrame("EditBox", nil, holder)
    e:SetPoint("TOPLEFT", 6, 0)
    e:SetPoint("BOTTOMRIGHT", -6, 0)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetTextColor(0.95, 0.95, 0.95)
    if opts.maxLetters then e:SetMaxLetters(opts.maxLetters) end
    holder.edit = e
    holder.placeholder = UI.Text(holder, "GameFontDisable")
    holder.placeholder:SetPoint("LEFT", 7, 0)
    holder.placeholder:SetText(opts.placeholder or "")
    holder.placeholder.ignoreOverlap = true -- drawn inside the box on purpose
    local function Hint() holder.placeholder:SetShown((e:GetText() or "") == "" and not e:HasFocus()) end
    holder.Hint = Hint
    local function Commit()
        if opts.onCommit and not holder.settingText then opts.onCommit(e:GetText() or "") end
    end
    e:SetScript("OnEnterPressed", function(self) Commit(); self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusLost", function() Commit(); Hint() end)
    e:SetScript("OnEditFocusGained", function(self) self:HighlightText(); holder.placeholder:Hide() end)
    e:SetScript("OnTextChanged", function(self, user)
        Hint()
        if user and opts.onChange then opts.onChange(self:GetText() or "") end
    end)
    function holder:SetText(t)
        self.settingText = true
        e:SetText(t or "")
        self.settingText = nil
        Hint()
    end
    function holder:GetText() return e:GetText() or "" end
    function holder:SetDisabled(d)
        e:EnableMouse(not d)
        if d then e:ClearFocus() end
        self:SetAlpha(d and 0.45 or 1)
    end
    Hint()
    return holder
end

------------------------------------------------------------------------
-- Dropdown with a shared, scrolling list
------------------------------------------------------------------------
local Menu

local MENU_ROW = 20
local MENU_MAX = 12

local function BuildMenu()
    Menu = CreateFrame("Frame", "WorkoutBuddyMenu", UIParent)
    Menu:SetFrameStrata("FULLSCREEN_DIALOG")
    Menu:SetClampedToScreen(true)
    Menu:EnableMouse(true)
    Menu:EnableMouseWheel(true)
    UI.Box(Menu, "panel", "accent")
    Menu.rows = {}
    Menu.offset = 0
    -- click anywhere else closes it
    Menu.catcher = CreateFrame("Button", nil, UIParent)
    Menu.catcher:SetFrameStrata("FULLSCREEN")
    Menu.catcher:SetAllPoints(UIParent)
    Menu.catcher:SetScript("OnClick", function() Menu:Close() end)
    Menu.catcher:Hide()
    function Menu:Close()
        self:Hide()
        self.catcher:Hide()
        self.owner = nil
    end
    function Menu:Draw()
        local items = self.items or {}
        local shown = math.min(#items, MENU_MAX)
        self:SetHeight(shown * MENU_ROW + 6)
        for i = 1, MENU_MAX do
            local row = self.rows[i]
            local item = items[i + self.offset]
            if i <= shown and item then
                if not row then
                    row = CreateFrame("Button", nil, self)
                    row:SetHeight(MENU_ROW)
                    row:SetPoint("TOPLEFT", 3, -3 - (i - 1) * MENU_ROW)
                    row:SetPoint("TOPRIGHT", -3, -3 - (i - 1) * MENU_ROW)
                    row.hl = UI.Tex(row, "HIGHLIGHT", "accent", 0.25)
                    row.hl:SetAllPoints(row)
                    row.sel = UI.Tex(row, "BACKGROUND", "accent", 0.18)
                    row.sel:SetAllPoints(row)
                    row.icon = row:CreateTexture(nil, "ARTWORK")
                    row.icon:SetSize(16, 16)
                    row.icon:SetPoint("LEFT", 6, 0)
                    row.text = UI.Text(row, "GameFontHighlightSmall")
                    row.text:SetPoint("LEFT", 6, 0)
                    row.text:SetPoint("RIGHT", -6, 0)
                    row.text:SetWordWrap(false)
                    row:SetScript("OnClick", function(r)
                        local owner = Menu.owner
                        Menu:Close()
                        if owner and r.item then owner:Choose(r.item.value) end
                    end)
                    self.rows[i] = row
                end
                row.item = item
                row.text:SetText(item.text or tostring(item.value))
                row.text:SetPoint("LEFT", item.icon and 26 or 6, 0)
                row.icon:SetShown(item.icon ~= nil)
                if item.icon then row.icon:SetTexture(item.icon) end
                row.sel:SetShown(self.owner and self.owner.value == item.value)
                row:Show()
            elseif row then
                row:Hide()
            end
        end
    end
    Menu:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = math.max(0, #(self.items or {}) - MENU_MAX)
        self.offset = math.max(0, math.min(maxOffset, self.offset - delta * 3))
        self:Draw()
    end)
    Menu:Hide()
end

--- opts: values() -> { {value=, text=, icon=}, ... }, get() -> value,
-- set(value), placeholder (text when nothing matches).
function UI.Dropdown(parent, w, opts)
    local d = CreateFrame("Button", nil, parent)
    d:SetSize(w or 200, 24)
    UI.Box(d, "input", "border")
    d.hl = UI.Tex(d, "HIGHLIGHT", "hover")
    d.hl:SetAllPoints(d)
    d.text = UI.Text(d, "GameFontHighlightSmall", "text")
    d.text:SetPoint("LEFT", 8, 0)
    d.text:SetPoint("RIGHT", -22, 0)
    d.text:SetWordWrap(false)
    d.arrow = UI.Text(d, "GameFontHighlightSmall", "accent")
    d.arrow:SetPoint("RIGHT", -7, 0)
    d.arrow:SetText("v")
    d.opts = opts
    function d:Refresh()
        self.value = opts.get and opts.get() or nil
        local text = opts.placeholder or ""
        for _, item in ipairs(opts.values() or {}) do
            if item.value == self.value then text = item.text break end
        end
        self.text:SetText(text)
    end
    function d:Choose(v)
        if opts.set then opts.set(v) end
        self:Refresh()
    end
    function d:SetDisabled(dis)
        self.disabled = dis and true or false
        self:SetAlpha(dis and 0.45 or 1)
    end
    d:SetScript("OnClick", function(self)
        if self.disabled then return end
        if not Menu then BuildMenu() end
        if Menu:IsShown() and Menu.owner == self then return Menu:Close() end
        Menu.owner = self
        Menu.items = opts.values() or {}
        Menu.offset = 0
        -- start scrolled so the current choice is visible
        for i, item in ipairs(Menu.items) do
            if item.value == self.value and i > MENU_MAX then Menu.offset = math.min(i - 1, #Menu.items - MENU_MAX) end
        end
        Menu:ClearAllPoints()
        Menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        Menu:SetWidth(math.max(self:GetWidth(), 160))
        Menu.catcher:Show()
        Menu:Show()
        Menu:Draw()
    end)
    d:Refresh()
    return d
end

function UI.CloseMenu()
    if Menu and Menu:IsShown() then Menu:Close() end
end

------------------------------------------------------------------------
-- Chip (small toggle pill: days of the week, presets...)
------------------------------------------------------------------------
function UI.Chip(parent, text, onClick)
    local c = CreateFrame("Button", nil, parent)
    c.label = UI.Text(c, "GameFontHighlightSmall")
    c.label:SetPoint("CENTER")
    c.label:SetJustifyH("CENTER")
    c.label:SetText(text)
    c:SetSize(math.max(36, (c.label:GetStringWidth() or 30) + 18), 22)
    UI.Box(c, "input", "border")
    c.hl = UI.Tex(c, "HIGHLIGHT", "hover")
    c.hl:SetAllPoints(c)
    function c:SetSelected(on)
        self.selected = on and true or false
        UI.Paint(self.bg, on and "accent" or "input", on and 0.35 or nil)
        UI.SetBorderRole(self, on and "accent" or "border")
    end
    if onClick then c:SetScript("OnClick", function() onClick(c) end) end
    c:SetSelected(false)
    return c
end

------------------------------------------------------------------------
-- Slider with an editable number box (drag for speed, type for precision)
------------------------------------------------------------------------
local VALUE_W = 52
local UNIT_W = 58

--- unit: short suffix shown after the box ("min", "%", "s"...).
-- percent=true shows 0.5 as 50 (the stored value stays 0.5).
function UI.Slider(parent, w, minV, maxV, step, onChange, unit, percent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w or 230, 24)
    local mul = percent and 100 or 1
    step = step or 1
    local s = CreateFrame("Slider", nil, holder)
    s:SetPoint("LEFT", 0, 0)
    s:SetPoint("RIGHT", holder, "RIGHT", -(VALUE_W + 6 + (unit and UNIT_W or 0)), 0)
    s:SetHeight(16)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouseWheel(true)
    s.track = UI.Tex(s, "BACKGROUND", "off")
    s.track:SetPoint("LEFT")
    s.track:SetPoint("RIGHT")
    s.track:SetHeight(4)
    s:SetThumbTexture(WHITE)
    local thumb = s:GetThumbTexture()
    if thumb then
        thumb:SetSize(10, 16)
        UI.Paint(thumb, "accent")
    end
    holder.slider = s

    local function Snap(v)
        v = math.max(minV, math.min(maxV, v))
        v = minV + math.floor((v - minV) / step + 0.5) * step
        return tonumber(string.format("%.4f", v))
    end
    local function Shown(v)
        local n = v * mul
        if math.abs(n - math.floor(n + 0.5)) < 0.001 then return tostring(math.floor(n + 0.5)) end
        return string.format("%.2f", n)
    end

    holder.box = UI.Input(holder, VALUE_W, {
        onCommit = function(text)
            local n = tonumber(text)
            if not n then holder.box:SetText(Shown(holder.current or minV)) return end
            local v = Snap(n / mul)
            holder:SetValue(v)
            if onChange then onChange(v) end
        end,
    })
    holder.box:SetPoint("LEFT", s, "RIGHT", 6, 0)
    holder.box.edit:SetJustifyH("RIGHT")
    if unit then
        holder.unit = UI.Text(holder, "GameFontHighlightSmall", "muted")
        holder.unit:SetPoint("LEFT", holder.box, "RIGHT", 5, 0)
        holder.unit:SetWidth(UNIT_W - 5)
        holder.unit:SetWordWrap(false)
        holder.unit:SetText(unit)
    end

    s:SetScript("OnValueChanged", function(_, v)
        v = Snap(v)
        holder.current = v
        if not holder.box.edit:HasFocus() then holder.box:SetText(Shown(v)) end
        if holder.setting then return end
        if onChange then onChange(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(Snap((self:GetValue() or minV) + delta * step))
    end)
    function holder:SetValue(v)
        v = Snap(tonumber(v) or minV)
        self.current = v
        self.setting = true
        s:SetValue(v)
        self.setting = nil
        if not self.box.edit:HasFocus() then self.box:SetText(Shown(v)) end
    end
    function holder:SetDisabled(d)
        s:EnableMouse(not d)
        self.box:SetDisabled(d)
        self:SetAlpha(d and 0.45 or 1)
    end
    return holder
end

------------------------------------------------------------------------
-- Overlap check: finds visible controls drawn on top of each other.
-- Used by /wob uicheck in game and by the offline tests on every page.
------------------------------------------------------------------------
local function Rect(r)
    local l, rt, t, b = r:GetLeft(), r:GetRight(), r:GetTop(), r:GetBottom()
    if not (l and rt and t and b) then return nil end
    if rt - l < 1 or t - b < 1 then return nil end
    return l, rt, t, b
end

local function Visible(r)
    if r.IsVisible then return r:IsVisible() end
    return r:IsShown()
end

local function Elements(f)
    local list = {}
    for _, child in ipairs({ f:GetChildren() }) do
        if Visible(child) and not child.ignoreOverlap then list[#list + 1] = child end
    end
    for _, region in ipairs({ f:GetRegions() }) do
        if region.GetText and region:GetObjectType() == "FontString" and Visible(region) and not region.ignoreOverlap then
            local text = region:GetText()
            if text and text ~= "" then list[#list + 1] = region end
        end
    end
    return list
end

local function Describe(r)
    if r.GetText and r:GetText() then return "\"" .. tostring(r:GetText()):sub(1, 30) .. "\"" end
    if r.label and r.label.GetText then return "[" .. tostring(r.label:GetText()) .. "]" end
    return r:GetObjectType()
end

--- Returns a list of "A overlaps B" strings for everything under root.
function UI.FindOverlaps(root, out, depth)
    out = out or {}
    depth = depth or 0
    if depth > 12 or not Visible(root) then return out end
    local els = Elements(root)
    for i = 1, #els do
        local l1, r1, t1, b1 = Rect(els[i])
        if l1 then
            for j = i + 1, #els do
                local l2, r2, t2, b2 = Rect(els[j])
                UI.pairsChecked = (UI.pairsChecked or 0) + (l2 and 1 or 0)
                if l2 and l1 < r2 - 1 and l2 < r1 - 1 and b1 < t2 - 1 and b2 < t1 - 1 then
                    out[#out + 1] = Describe(els[i]) .. " overlaps " .. Describe(els[j])
                end
            end
        end
    end
    for _, child in ipairs({ root:GetChildren() }) do
        if Visible(child) then UI.FindOverlaps(child, out, depth + 1) end
    end
    return out
end

--- Text that spills above or below the frame it belongs to (a row that
-- was measured too short, so its text runs into the next row).
function UI.FindOverflow(root, out, depth)
    out = out or {}
    depth = depth or 0
    if depth > 12 or not Visible(root) then return out end
    local _, _, pt, pb = Rect(root)
    if pt and root:GetObjectType() ~= "ScrollFrame" then
        for _, region in ipairs({ root:GetRegions() }) do
            if region:GetObjectType() == "FontString" and Visible(region) and not region.ignoreOverlap then
                local text = region:GetText()
                local _, _, t, b = Rect(region)
                if text and text ~= "" and t and (b < pb - 2 or t > pt + 2) then
                    out[#out + 1] = Describe(region) .. " spills out of its row"
                end
            end
        end
    end
    for _, child in ipairs({ root:GetChildren() }) do
        if Visible(child) then UI.FindOverflow(child, out, depth + 1) end
    end
    return out
end

--- Visible containers with no width or height that still hold visible
-- things. The game may not draw the contents of a frame without a size,
-- so every container gets one.
function UI.FindZeroSize(root, out, depth)
    out = out or {}
    depth = depth or 0
    if depth > 12 or not Visible(root) then return out end
    local hasContent = #Elements(root) > 0
    if not hasContent then
        for _, region in ipairs({ root:GetRegions() }) do
            if Visible(region) and region:GetObjectType() == "Texture" then hasContent = true break end
        end
    end
    local w, h = root:GetWidth() or 0, root:GetHeight() or 0
    if hasContent and (w < 1 or h < 1) then
        out[#out + 1] = Describe(root) .. string.format(" has no size (%dx%d)", w, h)
    end
    for _, child in ipairs({ root:GetChildren() }) do
        if Visible(child) then UI.FindZeroSize(child, out, depth + 1) end
    end
    return out
end

------------------------------------------------------------------------
-- Scroll area: a ScrollFrame with a content frame and a slim scroll bar
------------------------------------------------------------------------
function UI.Scroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(10, 10)
    sf:SetScrollChild(content)
    sf.content = content
    local bar = CreateFrame("Frame", nil, sf)
    bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 0, 0)
    bar:SetWidth(4)
    bar.track = UI.Tex(bar, "BACKGROUND", "border", 0.5)
    bar.track:SetAllPoints(bar)
    bar.thumb = UI.Tex(bar, "ARTWORK", "accent", 0.8)
    bar.thumb:SetWidth(4)
    sf.bar = bar
    function sf:UpdateBar()
        local viewH = self:GetHeight() or 1
        local contentH = self.content:GetHeight() or 1
        local range = math.max(0, contentH - viewH)
        bar:SetShown(range > 1)
        if range <= 1 then
            if (self:GetVerticalScroll() or 0) ~= 0 then self:SetVerticalScroll(0) end
            return
        end
        local thumbH = math.max(24, viewH * viewH / contentH)
        local pos = (self:GetVerticalScroll() or 0) / range
        bar.thumb:ClearAllPoints()
        bar.thumb:SetPoint("TOP", bar, "TOP", 0, -pos * (viewH - thumbH))
        bar.thumb:SetHeight(thumbH)
    end
    function sf:ScrollTo(y)
        local range = math.max(0, (self.content:GetHeight() or 0) - (self:GetHeight() or 0))
        self:SetVerticalScroll(math.max(0, math.min(range, y)))
        self:UpdateBar()
    end
    sf:SetScript("OnMouseWheel", function(self, delta)
        self:ScrollTo((self:GetVerticalScroll() or 0) - delta * 48)
    end)
    sf:SetScript("OnSizeChanged", function(self) self:UpdateBar() end)
    return sf
end

------------------------------------------------------------------------
-- Multi-line text box (import/export)
------------------------------------------------------------------------
function UI.Multiline(parent, w, h, readOnly)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w or 300, h or 80)
    UI.Box(holder, "input", "border")
    local sf = CreateFrame("ScrollFrame", nil, holder)
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", -6, 6)
    sf:EnableMouseWheel(true)
    local e = CreateFrame("EditBox", nil, sf)
    e:SetMultiLine(true)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetWidth((w or 300) - 14)
    e:SetHeight(h or 80)
    sf:SetScrollChild(e)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, (e:GetHeight() or 0) - (self:GetHeight() or 0))
        self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 30)))
    end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if readOnly then
        -- keep the exported text intact but still selectable for copying
        e:SetScript("OnTextChanged", function(self, user) if user then self:SetText(holder.fixed or ""); self:HighlightText() end end)
        e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    end
    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", function() e:SetFocus() end)
    holder.edit = e
    function holder:SetText(t) self.fixed = t; e:SetText(t or "") end
    function holder:GetText() return e:GetText() or "" end
    return holder
end

------------------------------------------------------------------------
-- Confirmation dialog
------------------------------------------------------------------------
function UI.Confirm(text, onAccept)
    if UI.autoConfirm then return onAccept() end -- offline tests accept right away
    if not StaticPopupDialogs["WORKOUTBUDDY_CONFIRM"] then
        StaticPopupDialogs["WORKOUTBUDDY_CONFIRM"] = {
            text = "%s", button1 = YES or "Yes", button2 = NO or "No",
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            OnAccept = function(_, data) if data and data.fn then data.fn() end end,
        }
    end
    local popup = StaticPopup_Show("WORKOUTBUDDY_CONFIRM", text)
    if popup then popup.data = { fn = onAccept } end
    return popup
end
