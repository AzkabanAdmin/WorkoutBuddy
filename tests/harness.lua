-- Mocked WoW client plus the main test suite. Run with: npm test
-- Mock WoW client (Forever-like: some retail events missing, secret health).
----------------------------------------------------------------------------
-- Lua 5.1 shims
loadstring = load
unpack = table.unpack
getfenv = function() return _G end
setfenv = function(f) return f end
math.mod = math.fmod
bit = { band = function(a, b) return a & b end, bor = function(a, b) return a | b end,
        lshift = function(a, b) return a << b end, rshift = function(a, b) return a >> b end }
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strsplit = function(d, s) local out = {} for p in (s .. d):gmatch("(.-)" .. d) do out[#out + 1] = p end return table.unpack(out) end
strmatch, strfind, strsub, strlen, strlower, strupper, format, gsub, strrep, strbyte, strchar =
    string.match, string.find, string.sub, string.len, string.lower, string.upper, string.format, string.gsub, string.rep, string.byte, string.char
tinsert, tremove, tconcat, sort = table.insert, table.remove, table.concat, table.sort
floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
strlenutf8 = function(s) return utf8.len(s) or #s end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
table.wipe = wipe -- WoW provides both
date, time = os.date, os.time
debugstack = function() return "" end
geterrorhandler = function() return function(e) print("ERRORHANDLER: " .. tostring(e)) ERRORS = (ERRORS or 0) + 1 end end
securecallfunction = function(f, ...) return f(...) end
issecurevariable = function() return false end
hooksecurefunc = function() end
CopyTable = function(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end

----------------------------------------------------------------------------
-- Clock and timers
NOW = 1763800000
local gameTime = 1000
GetTime = function() return gameTime end
GetServerTime = function() return math.floor(NOW) end
local timers = {}
local function newTimer(delay, fn, iterations)
    local t = { at = gameTime + delay, fn = fn, delay = delay, left = iterations }
    function t:Cancel() self.cancelled = true end
    function t:IsCancelled() return self.cancelled end
    timers[#timers + 1] = t
    return t
end
C_Timer = {
    After = function(d, f) newTimer(d, f, 1) end,
    NewTimer = function(d, f) return newTimer(d, f, 1) end,
    NewTicker = function(d, f, n) return newTimer(d, f, n or math.huge) end,
}
function Advance(seconds)
    local target = gameTime + seconds
    while true do
        local nextT
        for _, t in ipairs(timers) do
            if not t.cancelled and t.at <= target and (not nextT or t.at < nextT.at) then nextT = t end
        end
        if not nextT then break end
        local delta = nextT.at - gameTime
        gameTime = nextT.at
        NOW = NOW + delta
        nextT.left = nextT.left - 1
        if nextT.left <= 0 then nextT.cancelled = true else nextT.at = nextT.at + nextT.delay end
        nextT.fn(nextT)
    end
    NOW = NOW + (target - gameTime)
    gameTime = target
end

----------------------------------------------------------------------------
-- Events
-- Like the real Forever client: modern event names exist (keystones too),
-- but some retail-only systems are missing.
INVALID_EVENTS = { WEEKLY_REWARDS_UPDATE = true, PLAYER_SPECIALIZATION_CHANGED = true }
C_EventUtils = { IsEventValid = function(e) return not INVALID_EVENTS[e] end }
local eventFrames = {}
function FireEvent(event, ...)
    for f in pairs(eventFrames) do
        if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
    end
end

----------------------------------------------------------------------------
-- Frames
local function noop() end
local Methods = {}
local FrameMT = { __index = function(t, k) if Methods[k] then return Methods[k] end if type(k) == "string" and k:match("^[A-Z]") then return noop end return nil end }
local function NewObject(kind, name, parent)
    local o = setmetatable({ _kind = kind, _scripts = {}, _events = {}, _w = 100, _h = 20,
        _shown = (kind ~= "Frame"), _name = name, _parent = parent, _alpha = 1 }, FrameMT)
    if name then _G[name] = o end
    return o
end
function Methods:RegisterEvent(e)
    if INVALID_EVENTS[e] then error("Attempt to register unknown event \"" .. e .. "\"") end
    self._events[e] = true; eventFrames[self] = true
end
function Methods:RegisterUnitEvent(e) Methods.RegisterEvent(self, e) end
function Methods:UnregisterEvent(e) self._events[e] = nil end
function Methods:UnregisterAllEvents() self._events = {} end
function Methods:IsEventRegistered(e) return self._events[e] end
function Methods:SetScript(s, f) self._scripts[s] = f end
function Methods:GetScript(s) return self._scripts[s] end
function Methods:HookScript(s, f) local old = self._scripts[s]; self._scripts[s] = function(...) if old then old(...) end f(...) end end
function Methods:Show() if not self._shown then self._shown = true if self._scripts.OnShow then self._scripts.OnShow(self) end end end
function Methods:Hide() if self._shown then self._shown = false if self._scripts.OnHide then self._scripts.OnHide(self) end end end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self._shown end
function Methods:IsVisible() return self._shown end
function Methods:GetName() return self._name end
function Methods:GetParent() return self._parent end
function Methods:SetParent(p) self._parent = p end
function Methods:SetWidth(w) self._w = w end
function Methods:SetHeight(h) self._h = h end
function Methods:SetSize(w, h) self._w, self._h = w, h end
function Methods:GetWidth() return self._w end
function Methods:GetHeight() return self._h end
function Methods:GetSize() return self._w, self._h end
function Methods:GetLeft() return 100 end
function Methods:GetRight() return 100 + self._w end
function Methods:GetTop() return 600 end
function Methods:GetBottom() return 600 - self._h end
function Methods:GetCenter() return 200, 500 end
function Methods:GetScale() return 1 end
function Methods:GetEffectiveScale() return 1 end
function Methods:SetAlpha(a) self._alpha = a end
function Methods:GetAlpha() return self._alpha end
function Methods:GetFrameLevel() return 1 end
function Methods:GetFrameStrata() return "MEDIUM" end
function Methods:GetObjectType() return self._kind end
function Methods:IsObjectType(k) return self._kind == k end
function Methods:SetText(t) self._text = t end
function Methods:GetText() return self._text end
function Methods:GetStringWidth() return 50 end
function Methods:GetStringHeight() return 12 end
function Methods:GetVerticalScrollRange() return 0 end
function Methods:GetVerticalScroll() return 0 end
function Methods:GetNumPoints() return 1 end
function Methods:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
function Methods:IsMouseOver() return false end
function Methods:GetChecked() return self._checked end
function Methods:SetChecked(v) self._checked = v end
function Methods:GetValue() return self._value or 0 end
function Methods:SetValue(v) self._value = v end
function Methods:GetMinMaxValues() return 0, 1 end
function Methods:IsEnabled() return true end
function Methods:GetFontObject() return NewObject("Font") end
function Methods:GetFont() return "font", 12, "" end
function Methods:GetTextColor() return 1, 1, 1, 1 end
function Methods:GetVertexColor() return 1, 1, 1, 1 end
function Methods:GetCursorPosition() return 0 end
function Methods:GetNumLetters() return 0 end
function Methods:GetMaxLetters() return 0 end
function Methods:IsMovable() return true end
function Methods:GetChildren() return end
function Methods:GetRegions() return end
function Methods:CreateTexture() return NewObject("Texture", nil, self) end
function Methods:CreateFontString() return NewObject("FontString", nil, self) end
function Methods:CreateAnimationGroup() return NewObject("AnimationGroup", nil, self) end
function Methods:CreateAnimation() return NewObject("Animation", nil, self) end
function Methods:GetNormalTexture() self._nt = self._nt or NewObject("Texture"); return self._nt end
function Methods:GetHighlightTexture() self._ht = self._ht or NewObject("Texture"); return self._ht end
function Methods:GetPushedTexture() self._pt = self._pt or NewObject("Texture"); return self._pt end
function Methods:GetDisabledTexture() self._dt = self._dt or NewObject("Texture"); return self._dt end
function Methods:GetCheckedTexture() self._ct = self._ct or NewObject("Texture"); return self._ct end
function Methods:GetFontString() self._fs = self._fs or NewObject("FontString"); return self._fs end
function Methods:SetFontString(fs) self._fs = fs end
function Methods:GetScrollChild() return self._child end
function Methods:SetScrollChild(c) self._child = c end
function Methods:GetID() return 1 end
function Methods:GetTexture() return "" end

CreateFrame = function(kind, name, parent, template)
    local f = NewObject(kind, name, parent)
    if template and template:find("BackdropTemplate") then f.SetBackdrop = noop end
    if kind == "Slider" or (template and template:find("Slider")) then
        f.Low = NewObject("FontString"); f.High = NewObject("FontString"); f.Text = NewObject("FontString")
    end
    if template and template:find("ScrollFrame") then f.ScrollBar = NewObject("Slider"); if name then _G[name .. "ScrollBar"] = f.ScrollBar end end
    if kind == "EditBox" then f.Left, f.Right, f.Middle = NewObject("Texture"), NewObject("Texture"), NewObject("Texture") end
    if template and template:find("UIDropDownMenuTemplate") then
        _G[(name or "x") .. "Button"] = NewObject("Button"); _G[(name or "x") .. "Text"] = NewObject("FontString")
        _G[(name or "x") .. "Left"] = NewObject("Texture"); _G[(name or "x") .. "Middle"] = NewObject("Texture"); _G[(name or "x") .. "Right"] = NewObject("Texture")
    end
    if template and template:find("UICheckButtonTemplate") then f.Text = NewObject("FontString") end
    return f
end
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
UIParent = NewObject("Frame", "UIParent"); UIParent._shown = true; UIParent._w, UIParent._h = 1920, 1080
Minimap = NewObject("Frame", "Minimap"); Minimap._shown = true
GameTooltip = NewObject("GameTooltip", "GameTooltip")
WorldFrame = NewObject("Frame", "WorldFrame")
UISpecialFrames = {}
StaticPopupDialogs = {}
StaticPopup_Show = function() end
BackdropTemplateMixin = {}
SOUNDKIT = { ALARM_CLOCK_WARNING_3 = 12889, RAID_WARNING = 8959, TELL_MESSAGE = 3081 }
SOUNDS_PLAYED = {}
PlaySound = function(id) SOUNDS_PLAYED[#SOUNDS_PLAYED + 1] = id end
PlaySoundFile = function(p) SOUNDS_PLAYED[#SOUNDS_PLAYED + 1] = p end
Settings = {
    RegisterCanvasLayoutCategory = function(f, n) return { GetID = function() return n end, ID = n } end,
    RegisterCanvasLayoutSubcategory = function(c, f, n) return { GetID = function() return n end, ID = n } end,
    RegisterAddOnCategory = noop, GetCategory = function() return nil end, OpenToCategory = noop,
}
C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end }
GetLocale = function() return "enUS" end
GetCurrentRegion = function() return 1 end
GetCurrentRegionName = function() return "US" end
GetRealmName = function() return "Forever Realm" end
GetNormalizedRealmName = function() return "ForeverRealm" end
UnitName = function() return "Tester" end
UnitNameUnmodified = UnitName
UnitFactionGroup = function() return "Alliance" end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitRace = function() return "Human", "Human" end
UnitXP = function() return XP or 0 end
UnitXPMax = function() return 1000 end
UnitIsAFK = function() return AFK end
IsResting = function() return false end
UnitOnTaxi = function() return ON_TAXI end
InCombatLockdown = function() return IN_COMBAT end
UnitAffectingCombat = function() return IN_COMBAT end
UnitExists = function() return true end
SECRET = setmetatable({}, { __lt = function() error("attempt to compare a secret value") end,
    __le = function() error("attempt to compare a secret value") end,
    __div = function() error("attempt to perform arithmetic on a secret value") end })
UnitHealth = function() return SECRET_HEALTH and SECRET or 800 end
UnitHealthMax = function() return SECRET_HEALTH and SECRET or 1000 end
issecretvalue = function(v) return v == SECRET end
IsLoggedIn = function() return LOGGED_IN end
IsShiftKeyDown = function() return false end
GetBattlefieldStatus = function() return "none" end
GetMaxBattlefieldID = function() return 2 end
CLOSE, OKAY, CANCEL, ACCEPT, NONE = "Close", "Okay", "Cancel", "Accept", "None"
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = 18, 1, 2
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
ChatFontNormal, GameFontNormal, GameFontHighlight, GameFontHighlightSmall, GameFontNormalSmall, GameFontDisable, GameFontNormalLarge, GameFontHighlightLarge =
    {}, {}, {}, {}, {}, {}, {}, {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) CHAT[#CHAT + 1] = m end }
CHAT = {}
local realPrint = print
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end CHAT[#CHAT + 1] = table.concat(t, " ") end
SlashCmdList = {}
hash_SlashCmdList = {}
GetBuildInfo = function() return "1.60.1", "70500", "Nov 2026", 16001 end
GetCVar = function() return "0" end
C_UIFileAsset = { IsKnownFile = function() return true end }

----------------------------------------------------------------------------
-- Load addon
if V1_DB then WorkoutBuddyDB = V1_DB end
local ns = {}
for _, f in ipairs(ADDON_FILES) do
    local chunk, err = loadfile(f)
    if not chunk then error("load " .. f .. ": " .. err) end
    local ok, e = pcall(chunk, "WorkoutBuddy", ns)
    if not ok then error("run " .. f .. ": " .. tostring(e)) end
end
FireEvent("ADDON_LOADED", "WorkoutBuddy")
LOGGED_IN = true
FireEvent("PLAYER_LOGIN")
FireEvent("PLAYER_ENTERING_WORLD", true, false)

----------------------------------------------------------------------------
-- Tests
local WB = _G.WorkoutBuddy
if V1_TESTS then V1_TESTS(WB) return end
local pass, fail = 0, 0
local function check(name, cond, extra)
    if cond then pass = pass + 1 else fail = fail + 1 realPrint("FAIL: " .. name .. (extra and (" :: " .. tostring(extra)) or "")) end
end
local function chatHas(pattern)
    for _, m in ipairs(CHAT) do if tostring(m):find(pattern) then return true end end
    return false
end

check("addon global", WB and WB.db)
check("version dev fallback", WB.VERSION == "dev", WB.VERSION)
check("starter workouts seeded", #WB.db.profile.workouts == #WB.DEFAULT_WORKOUTS)
check("login message", chatHas("loaded"))
check("first run shows frame", WB.ReminderFrame and WB.ReminderFrame:IsShown())
check("forever detected", WB.GameFlavor() == "forever")
check("keystones hidden on Forever although the event exists", WB.IsEventValid("CHALLENGE_MODE_COMPLETED")
    and WB:IsBuiltInTriggerSupported("challenge_complete") == false)
check("achievements shown on Forever", WB:IsBuiltInTriggerSupported("achievement") == true)
check("queues shown on Forever", WB.ReminderEvents.IsQueueOptionSupported())
check("builtin supported", WB:IsBuiltInTriggerSupported("boss_kill") == true)
check("settings window registered", WB.SettingsUI and WB.SettingsUI.pages.triggers and WB.SettingsUI.blizzardPanel)

-- Level up -> suggestion
FireEvent("PLAYER_LEVEL_UP", 2)
local q = WB.ReminderState.getQueue()
check("level up queued", #q == 1, #q)
-- Cooldown blocks immediate second suggestion
FireEvent("PLAYER_LEVEL_UP", 3)
check("cooldown", #q == 1 and (q[1].amount == WB.db.profile.workouts[1].amount or true))
local total = 0 for _, w in ipairs(q) do total = total + 1 end
check("cooldown count", total == 1, total)
Advance(31)
-- Boss kill (success) and wipe
FireEvent("ENCOUNTER_END", 1, "Boss", 1, 5, 0)
check("wipe ignored", #q == 1)
FireEvent("ENCOUNTER_END", 1, "Boss", 1, 5, 1)
local count = 0 for _, w in ipairs(q) do count = count + (w.amount or 0) end
check("boss kill queued", count > 0 and (#q == 2 or #q == 1))

-- Complete first
WB.ReminderCore:UpdateDisplay()
local name = q[1].name
WB.ReminderCore:Complete(1)
check("complete logs stat", WB.Stats:GetTodayCount() == 1)
check("streak 1", WB.Stats:GetStreak() == 1)
check("today line", WB.Stats:GetTodayLine():find("Today: 1 / 5"))

-- Partial
WB:SuggestWorkout("Requested", true)
local idx = #q
local before = q[idx].amount
WB.ReminderCore:ShowPartialInput(idx)
WB.ReminderCore:CommitPartial(idx, 1)
check("partial subtracts", (q[idx] and q[idx].amount == before - 1) or before == 1)
check("partial logs", WB.Stats:GetTodayCount() == 2)

-- Stats summary
local s = WB.Stats:GetSummary("week")
check("summary has workouts", s:find("Workouts logged:|r 2"), s)
check("custom range invalid", WB.Stats:GetSummary("abc"):find("Could not read"))
check("custom range ok", WB.Stats:GetSummary("3days"):find("Workouts logged"))

-- Dismiss all
while #q > 0 do WB.ReminderCore:Dismiss(1) end
check("queue empty", #q == 0)

-- Custom trigger: UNIT_HEALTH edge + secret
table.insert(WB.db.profile.triggers, { name = "Low HP", event = "UNIT_HEALTH", action = "workout", enabled = true,
    options = { unit = "player", op = "<", value = 50 } })
WB.TriggerManager:Reset()
Advance(60)
FireEvent("UNIT_HEALTH", "player")
check("health above threshold no fire", #q == 0)
UnitHealth = function() return SECRET_HEALTH and SECRET or 800 end
SECRET_HEALTH = true
FireEvent("UNIT_HEALTH", "player")
check("secret health ignored, no error", #q == 0 and not ERRORS)
SECRET_HEALTH = false
UnitHealth = function() return 300 end
UnitHealthMax = function() return 1000 end
WB.db.profile.triggers[1].options.op = "<"
WB.db.profile.triggers[1].options.value = 50
FireEvent("UNIT_HEALTH", "player")
check("health below fires once", #q == 1, #q)
Advance(60)
FireEvent("UNIT_HEALTH", "player")
check("edge trigger no repeat", #q == 1 and q[1].amount == WB.db.profile.workouts[1].amount or #q == 1)
FireEvent("UNIT_HEALTH", "target")
check("other unit ignored", #q == 1)

-- Custom Lua condition trigger
wipe(WB.db.profile.triggers)
table.insert(WB.db.profile.triggers, { name = "Hello", event = "CHAT_MSG_SAY", action = "workout", enabled = true,
    options = {}, custom = "local msg = ...; return msg:find('hello') ~= nil" })
WB.TriggerManager:Reset()
WB.ReminderQueue:Clear()
Advance(60)
FireEvent("CHAT_MSG_SAY", "nope")
check("condition false", #q == 0)
FireEvent("CHAT_MSG_SAY", "hello there")
check("condition true fires", #q == 1, #q)
-- Bad code
table.insert(WB.db.profile.triggers, { name = "Broken", event = "CHAT_MSG_SAY", action = "workout", enabled = true, options = {}, custom = "return (" })
WB.TriggerManager:Reset()
FireEvent("CHAT_MSG_SAY", "x")
check("broken code warns", chatHas("Lua error"))
-- Unknown event trigger does not break registration
table.insert(WB.db.profile.triggers, { name = "Vault", event = "WEEKLY_REWARDS_UPDATE", action = "workout", enabled = true, options = {} })
local ok = pcall(function() WB.TriggerManager:Reset() end)
check("invalid trigger event safe", ok and chatHas("does not have"))

-- Double fire check: open_frame trigger on PLAYER_ENTERING_WORLD fires once
wipe(WB.db.profile.triggers)
local fired = 0
local origTry = WB.ReminderEvents.TryShowFrame
WB.ReminderEvents.TryShowFrame = function(self) fired = fired + 1 end
table.insert(WB.db.profile.triggers, { name = "PEW", event = "PLAYER_ENTERING_WORLD", action = "open_frame", enabled = true, options = {} })
WB.TriggerManager:Reset()
FireEvent("PLAYER_ENTERING_WORLD", false, false)
check("custom trigger fires exactly once", fired == 1, fired)
WB.ReminderEvents.TryShowFrame = origTry
wipe(WB.db.profile.triggers)
WB.TriggerManager:Reset()

-- Auto-open: taxi + combat deferral
WB.ReminderFrame:Hide()
WB.ReminderQueue:Clear()
WB:SuggestWorkout("Requested", true)
ON_TAXI = true
FireEvent("PLAYER_CONTROL_LOST")
FireEvent("TAXIMAP_CLOSED")
Advance(2)
check("taxi opens frame", WB.ReminderFrame:IsShown())
WB.ReminderFrame:Hide()
ON_TAXI = false
IN_COMBAT = true
FireEvent("QUEST_TURNED_IN", 1, 0, 0)
check("combat defers", not WB.ReminderFrame:IsShown())
IN_COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
Advance(3)
check("opens after combat", WB.ReminderFrame:IsShown())
-- AFK
WB.ReminderFrame:Hide()
WB.db.profile.reminder_events.afk = true
WB.ReminderEvents:Register()
AFK = true
FireEvent("PLAYER_FLAGS_CHANGED", "player")
check("afk opens", WB.ReminderFrame:IsShown())
WB.ReminderFrame:Hide()
FireEvent("PLAYER_FLAGS_CHANGED", "player")
check("afk only once", not WB.ReminderFrame:IsShown())
AFK = false

-- Play timer
WB.ReminderQueue:Clear()
WB.db.profile.play_timer_minutes = 10
WB:StartPlayTimer()
Advance(60 * 9 + 5)
check("play timer not yet", #q == 0)
Advance(60)
check("play timer fires", #q == 1, #q)
AFK = true
WB.ReminderQueue:Clear()
Advance(60 * 15)
check("afk time not counted", #q == 0)
AFK = false

-- Hydration
local h = WB.db.profile.hydration
h.enabled = true
h.per, h.total, h.timeframe = 8, 32, 120
check("interval smart", WB.Hydration:GetInterval() == 1800, WB.Hydration:GetInterval())
h.per = 0
check("interval never zero", WB.Hydration:GetInterval() >= 60)
h.per = 8
WB.Hydration:Start()
Advance(1801)
check("hydration popup", WorkoutBuddy_HydrationFrame and WorkoutBuddy_HydrationFrame:IsShown())
check("hydration sound", #SOUNDS_PLAYED > 0)
WB.Hydration:LogDrink()
check("water logged", select(1, WB.Stats:GetTodayWater()) == 8)
WB.Hydration:SetUnit("ml")
check("unit convert", h.per == 240 and h.total == 950, h.per .. "/" .. h.total)
WB.Hydration:SetUnit("oz")
check("unit convert back", h.per == 8 and h.total == 32, h.per .. "/" .. h.total)

-- Import/export workouts
WB.db.profile.workouts = { { name = 'Say "hi"\\', amount = 5, unit = "reps" }, { name = "Plank", amount = 30.5, unit = "seconds" } }
local exported = WB:SerializeWorkouts()
check("export/import roundtrip", WB:DeserializeWorkouts(exported) and WB.db.profile.workouts[1].name == 'Say "hi"\\' and WB.db.profile.workouts[2].amount == 30.5, exported)
check("legacy import", WB:DeserializeWorkouts('{{name="Pushups",amount=10,unit="reps"},{name="Stretch",amount=30,unit="seconds"}}') and #WB.db.profile.workouts == 2)
check("code injection rejected", not WB:DeserializeWorkouts('{{name=os.exit(),amount=1}}'))
check("garbage rejected", not WB:DeserializeWorkouts('hello'))
check("trailing junk rejected", not WB:DeserializeWorkouts('{{name="a",amount=1}} print(1)'))

-- Profile export/import with trigger code
table.insert(WB.db.profile.triggers, { name = "Code", event = "CHAT_MSG_SAY", action = "workout", enabled = true, options = {}, custom = "return true" })
local prof = WB:SerializeProfile()
check("profile export prefix", prof:sub(1, 5) == "WOB1:")
WB.db.profile.triggers = {}
check("profile import", WB:DeserializeProfile(prof))
local t = WB.db.profile.triggers[1]
check("imported code disabled", t and t.imported and t.enabled == false)
check("profile garbage rejected", not WB:DeserializeProfile("not a profile"))
local partial = LibStub("AceSerializer-3.0"):Serialize({ workouts = { { name = "Only", amount = 1, unit = "" } }, hydration = { unit = "ml" }, bogus = 5 })
check("partial profile import", WB:DeserializeProfile(partial))
check("partial keeps defaults", WB.db.profile.notify and WB.db.profile.notify.chat == true and WB.db.profile.hydration.per == 8 and WB.db.profile.hydration.unit == "ml")
check("partial imported workouts", #WB.db.profile.workouts == 1 and WB.db.profile.bogus == nil)
WB:SuggestWorkout("Requested", true)
check("works after partial import", true)

-- Profile switch
WB.db:SetProfile("Second")
check("new profile seeded", #WB.db.profile.workouts == #WB.DEFAULT_WORKOUTS)
WB.db:SetProfile("Default")

-- Settings window: open every page, render it, and call every spec function
local SUI, UIK = WB.SettingsUI, WB.UI
UIK.autoConfirm = true
local walked, errs = 0, 0
local function walk()
    for _, page in ipairs(SUI.order) do
        local okShow, eShow = pcall(SUI.Show, SUI, page.key)
        if not okShow then errs = errs + 1 realPrint("PAGE ERROR " .. page.key .. ": " .. tostring(eShow)) end
        if page.count then
            local okC, eC = pcall(page.count)
            if not okC then errs = errs + 1 realPrint("COUNT ERROR " .. page.key .. ": " .. tostring(eC)) end
        end
        for i, spec in ipairs(SUI:Specs(page)) do
            for _, fld in ipairs({ "label", "desc", "hidden", "disabled", "values", "get", "text" }) do
                if type(spec[fld]) == "function" then
                    walked = walked + 1
                    local ok2, e = pcall(spec[fld])
                    if not ok2 then errs = errs + 1 realPrint("SPEC ERROR " .. page.key .. "#" .. i .. "." .. fld .. ": " .. tostring(e)) end
                end
            end
        end
    end
end
SUI.FindSpec = function(pageKey, label)
    for _, spec in ipairs(SUI:Specs(SUI.pages[pageKey])) do
        local l = type(spec.label) == "function" and spec.label() or spec.label
        if spec.type ~= "section" and (l == label or (spec.search and spec.search.label == label)) then return spec end
    end
end
walk()
check("settings pages render (" .. walked .. ")", errs == 0 and walked > 50, walked)
check("settings window shown", SUI:IsShown())
check("all pages registered", #SUI.order == 7, #SUI.order)

-- Workout library and adding your own
local n0 = #WB.db.profile.workouts
local lib = SUI.FindSpec("workouts", "Workout library")
SUI:Show("workouts")
local libRow = lib._row
local firstItem = libRow.items[1]
firstItem.add._scripts.OnClick(firstItem.add)
check("library add", #WB.db.profile.workouts == n0 + 1, #WB.db.profile.workouts)
firstItem = libRow.items[1]
check("library row shows in list", firstItem.add.label:GetText() == "In your list")
check("library no duplicates", not WB:AddWorkout(firstItem.w.name, 5, firstItem.w.unit))
libRow.addAll._scripts.OnClick(libRow.addAll)
check("add category", #WB.db.profile.workouts > n0 + 1)
check("add your own", WB:AddWorkout("Desk Push-ups", 12, "reps") and not WB:AddWorkout("desk push-ups", 1, "reps"))
walk()
check("pages after changes", errs == 0)

-- Search finds settings across pages
local res = SUI:SearchResults("sound")
local pagesFound = {}
for _, g in ipairs(res) do pagesFound[g.page.key] = #g.specs end
check("search sound finds triggers and hydration", pagesFound.triggers and pagesFound.hydration, next(pagesFound))
check("search multiple words", #SUI:SearchResults("quiet hours clock") >= 1)
check("search custom areas", (function()
    for _, g in ipairs(SUI:SearchResults("potions")) do if g.page.key == "triggers" then return true end end
end)())
check("search nothing", #SUI:SearchResults("zzqqxx") == 0)
local okS, eS = pcall(SUI.SetSearch, SUI, "theme")
check("search renders", okS and SUI.searchText == "theme", eS)
local themeSpec = SUI.FindSpec("window", "Theme")
pcall(SUI.GoTo, SUI, "window", themeSpec)
check("search jump goes to page", SUI.current == "window" and SUI.searchText == "")

-- Theme switch repaints and colors the workout window
themeSpec.set("ember")
check("theme saved", WB.db.profile.theme == "ember" and UIK.Theme() == UIK.THEMES.ember)
local okT2 = pcall(UIK.Repaint)
check("theme repaint", okT2)
themeSpec.set("forest")

-- Slash commands
for _, c in ipairs({ "help", "show", "now", "water", "stats", "pause", "resume", "center", "minimap", "minimap", "bogus" }) do
    local okS, eS = pcall(WB.HandleSlashCommand, WB, c)
    check("slash " .. c, okS, eS)
end

-- Minimap tooltip
local tip = { AddLine = function() end }
local okT = pcall(LibStub("LibDataBroker-1.1"):GetDataObjectByName("WorkoutBuddy").OnTooltipShow, tip)
check("minimap tooltip", okT)

----------------------------------------------------------------------------
-- Quiet hours
local QH = WB.QuietHours
q = WB.ReminderState.getQueue() -- profile imports above replaced the queue table
local qh = WB.db.profile.quiet_hours
-- Set the local clock. 2026-11-20 is a Friday (wday 6).
local function at(day, hour, min)
    NOW = os.time({ year = 2026, month = 11, day = day, hour = hour, min = min or 0, sec = 0 })
end
local FRI, SAT = 20, 21
check("quiet: friday fixture", os.date("*t", os.time({ year = 2026, month = 11, day = FRI, hour = 12 })).wday == 6)
check("quiet: defaults off", qh.workouts.enabled == false and qh.hydration.enabled == false and qh.clock == "local")
at(FRI, 23)
check("quiet: disabled is never quiet", not QH:IsQuiet("workouts"))
qh.workouts.enabled = true -- 22:00 to 07:00 by default
check("quiet: 23:00 inside", QH:IsQuiet("workouts"))
at(SAT, 3)
check("quiet: 03:00 after midnight inside", QH:IsQuiet("workouts"))
at(FRI, 12)
check("quiet: noon outside", not QH:IsQuiet("workouts"))
at(FRI, 7)
check("quiet: end time is exclusive", not QH:IsQuiet("workouts"))
at(FRI, 22)
check("quiet: start time is inclusive", QH:IsQuiet("workouts"))

-- Days: a window past midnight belongs to the day it started
for i = 1, 7 do qh.workouts.days[i] = (i == 6) end -- Friday only
at(FRI, 23)
check("quiet: friday night on", QH:IsQuiet("workouts"))
at(SAT, 3)
check("quiet: saturday 3am belongs to friday", QH:IsQuiet("workouts"))
at(FRI, 3)
check("quiet: friday 3am belongs to thursday", not QH:IsQuiet("workouts"))
for i = 1, 7 do qh.workouts.days[i] = true end

-- Daytime window and whole day
qh.workouts.start, qh.workouts.stop = 9 * 60, 17 * 60
at(FRI, 12)
check("quiet: daytime window", QH:IsQuiet("workouts"))
at(FRI, 20)
check("quiet: outside daytime window", not QH:IsQuiet("workouts"))
qh.workouts.start, qh.workouts.stop = 0, 0
check("quiet: same start and end is all day", QH:IsQuiet("workouts"))
qh.workouts.start, qh.workouts.stop = 22 * 60, 7 * 60

-- Pause mode: automatic suggestions skipped, manual still works
WB.ReminderQueue:Clear()
WB.lastSuggestAt = nil
at(FRI, 23)
qh.workouts.mode = "pause"
FireEvent("PLAYER_LEVEL_UP", 10)
check("quiet pause: no automatic workout", #q == 0, #q)
WB:SuggestWorkout("Requested", true)
check("quiet pause: manual still works", #q == 1, #q)

-- Auto-open never pops the window during quiet hours
WB.ReminderFrame:Hide()
WB.ReminderEvents:TryShowFrame()
check("quiet: no auto-open", not WB.ReminderFrame:IsShown())
at(FRI, 12)
WB.ReminderEvents:TryShowFrame()
check("quiet over: auto-open works", WB.ReminderFrame:IsShown())

-- Collect mode: queued without chat or sound
WB.ReminderQueue:Clear()
WB.lastSuggestAt = nil
at(FRI, 23)
qh.workouts.mode = "collect"
WB.db.profile.notify.sound = "Raid Warning"
local chatBefore, soundsBefore = #CHAT, #SOUNDS_PLAYED
FireEvent("PLAYER_LEVEL_UP", 11)
check("quiet collect: queued", #q == 1, #q)
check("quiet collect: no chat line", #CHAT == chatBefore, #CHAT - chatBefore)
check("quiet collect: no sound", #SOUNDS_PLAYED == soundsBefore)
at(FRI, 12)
WB.lastSuggestAt = nil
FireEvent("PLAYER_LEVEL_UP", 12)
check("quiet over: chat and sound back", #CHAT > chatBefore and #SOUNDS_PLAYED > soundsBefore)
WB.db.profile.notify.sound = "None"

-- Play timer does not count paused quiet time
qh.workouts.mode = "pause"
WB.ReminderQueue:Clear()
WB.db.profile.play_timer_minutes = 10
WB:StartPlayTimer()
at(FRI, 23)
local function minutes(n) for _ = 1, n do Advance(60) NOW = NOW - 60 end end -- keep the clock at 23:00
minutes(15)
check("quiet pause: play timer frozen", #q == 0 and (WB.playMinutes or 0) == 0, WB.playMinutes)
qh.workouts.enabled = false

-- Hydration: pause skips the popup, silent shows it without sound
local hyd = WB.db.profile.hydration
hyd.enabled = true
qh.hydration.enabled = true
qh.hydration.mode = "pause"
WorkoutBuddy_HydrationFrame:Hide()
at(FRI, 23)
local snd = #SOUNDS_PLAYED
WB.Hydration:OnTimer()
check("quiet hydration pause: no popup", not WorkoutBuddy_HydrationFrame:IsShown())
check("quiet hydration pause: still scheduled", WB.Hydration.timer ~= nil)
qh.hydration.mode = "silent"
WB.Hydration:OnTimer()
check("quiet hydration silent: popup shown", WorkoutBuddy_HydrationFrame:IsShown())
check("quiet hydration silent: no sound", #SOUNDS_PLAYED == snd)
WorkoutBuddy_HydrationFrame:Hide()
at(FRI, 12)
WB.Hydration:OnTimer()
check("quiet hydration over: popup with sound", WorkoutBuddy_HydrationFrame:IsShown() and #SOUNDS_PLAYED > snd)
WorkoutBuddy_HydrationFrame:Hide()
qh.hydration.enabled = false

-- Realm clock
qh.workouts.enabled = true
at(FRI, 12)
qh.clock = "realm"
C_DateAndTime = { GetCurrentCalendarTime = function() return { hour = 23, minute = 30, weekday = 6, monthDay = 20, month = 11, year = 2026 } end }
check("quiet realm: uses realm time", QH:IsQuiet("workouts"))
C_DateAndTime = nil
GetGameTime = function() return 23, 15 end
check("quiet realm: falls back to GetGameTime", QH:IsQuiet("workouts"))
GetGameTime = nil
check("quiet realm: falls back to local time", not QH:IsQuiet("workouts"))
qh.clock = "local"

-- Status text and slash command
at(FRI, 23)
check("quiet status quiet", QH:StatusLine("workouts"):find("quiet now") and QH:StatusLine("workouts"):find("7:00 AM"), QH:StatusLine("workouts"))
at(FRI, 12)
check("quiet status active", QH:StatusLine("workouts"):find("10:00 PM"), QH:StatusLine("workouts"))
check("quiet status off", QH:StatusLine("hydration"):find("no quiet hours"))
check("format time", QH.FormatTime(0) == "12:00 AM (00:00)" and QH.FormatTime(13 * 60 + 45) == "1:45 PM (13:45)")
check("slash quiet", pcall(WB.HandleSlashCommand, WB, "quiet") and chatHas("Local time now"))
qh.workouts.enabled = false

-- Bad saved values are repaired
qh.workouts.start, qh.workouts.mode, qh.clock, qh.hydration.days = "abc", "bogus", "mars", "x"
WB:MigrateProfile()
check("quiet sanitize", qh.workouts.start == 22 * 60 and qh.workouts.mode == "pause" and qh.clock == "local"
    and type(qh.hydration.days) == "table" and qh.hydration.days[3] == true)

-- Quiet settings survive a profile export and import
qh.workouts.enabled, qh.workouts.start = true, 23 * 60
qh.workouts.days[1] = false
local qexport = WB:SerializeProfile()
qh.workouts.enabled, qh.workouts.start, qh.workouts.days[1] = false, 22 * 60, true
WB:DeserializeProfile(qexport)
qh = WB.db.profile.quiet_hours
check("quiet import roundtrip", qh.workouts.enabled and qh.workouts.start == 23 * 60 and qh.workouts.days[1] == false)
qh.workouts.enabled = false

----------------------------------------------------------------------------
-- 2.1.1 fixes
q = WB.ReminderState.getQueue()
-- Imported trigger with code never fires, even if switched on another way
wipe(WB.db.profile.triggers)
table.insert(WB.db.profile.triggers, { name = "Imp", event = "CHAT_MSG_SAY", action = "workout", enabled = true,
    imported = true, options = {}, custom = "return false" })
WB.TriggerManager:Reset()
WB.ReminderQueue:Clear()
WB.lastSuggestAt = nil
FireEvent("CHAT_MSG_SAY", "hi")
check("imported trigger never fires unreviewed", #q == 0, #q)
wipe(WB.db.profile.triggers)

-- Health trigger on target re-checks when the target changes
table.insert(WB.db.profile.triggers, { name = "Target low", event = "UNIT_HEALTH", action = "workout", enabled = true,
    options = { unit = "target", op = "<", value = 50 } })
WB.TriggerManager:Reset()
UnitHealth = function() return 300 end
FireEvent("UNIT_HEALTH", "target")
check("target health fires", #q == 1, #q)
WB.lastSuggestAt = nil
FireEvent("UNIT_HEALTH", "target")
check("target health edge holds", #q == 1 and q[1].amount == WB.db.profile.workouts[1].amount or #q == 1)
local qAmount = 0 for _, w in ipairs(q) do qAmount = qAmount + w.amount end
FireEvent("PLAYER_TARGET_CHANGED")
local qAmount2 = 0 for _, w in ipairs(q) do qAmount2 = qAmount2 + w.amount end
check("new low target fires on target change", qAmount2 > qAmount, qAmount .. " -> " .. qAmount2)
wipe(WB.db.profile.triggers)
WB.TriggerManager:Reset()
UnitHealth = function() return 800 end

-- Partial box follows its workout when a row above is removed
WB.ReminderQueue:Clear()
WB.ReminderQueue:AddToQueue({ name = "Top", amount = 5, unit = "reps" })
WB.ReminderQueue:AddToQueue({ name = "Bottom", amount = 10, unit = "reps" })
WB.ReminderCore:ShowPartialInput(2)
WB.ReminderCore:Dismiss(1)
local box = WB.ReminderCore.partialBox
box.edit:SetText("4")
-- the OK button runs the same commit as Enter
box.edit._scripts.OnEnterPressed(box.edit)
check("partial follows workout", #q == 1 and q[1].name == "Bottom" and q[1].amount == 6, q[1] and (q[1].name .. " " .. q[1].amount))
WB.ReminderQueue:Clear()

-- Nested profile import values are type checked
local bad = LibStub("AceSerializer-3.0"):Serialize({ hydration = { scale = "big", per = 12 },
    reminder_frame = { x = { 1 }, y = 300, width = "wide" } })
check("nested import accepted", WB:DeserializeProfile(bad))
local hp, rp = WB.db.profile.hydration, WB.db.profile.reminder_frame
check("nested bad types dropped", hp.scale == 1.2 and hp.per == 12 and rp.x == nil and rp.y == 300 and rp.width == 340,
    tostring(hp.scale) .. " " .. tostring(rp.x) .. " " .. tostring(rp.width))

-- Water totals convert between units
WB.Stats:Reset()
WB.db.profile.hydration.unit = "oz"
WB.Stats:AddWater(8, "oz")
WB.Hydration:SetUnit("ml")
WB.Stats:AddWater(250, "ml")
local wTotal, wUnit = WB.Stats:GetTodayWater()
check("water mixed units", wUnit == "ml" and wTotal == 487, wTotal .. " " .. tostring(wUnit))
WB.Hydration:SetUnit("oz")

-- Reset size restores the default size
WB.db.profile.reminder_frame.width, WB.db.profile.reminder_frame.height = 500, 400
SUI.FindSpec("window", "Show, center or reset the workout window").items[3].func()
check("reset size uses defaults", WB.db.profile.reminder_frame.width == 340 and WB.db.profile.reminder_frame.height == 200)

----------------------------------------------------------------------------
-- Demo mode (/wob demo): sample data that never replaces real data
local Demo = WB.Demo
at(FRI, 15)
WB.Stats:Reset()
WB.ReminderQueue:Clear()
WB.Stats:AddRecord("Real Workout", 1, "reps", false)
WB.ReminderQueue:AddToQueue({ name = "Real Queue Item", amount = 3, unit = "reps" })
local realStats, realQueue = WB.db.profile.stats, WB.db.profile.reminder_queue
WB.db.profile.daily_goal = 5
WorkoutBuddy_HydrationFrame:Hide()
check("slash demo on", pcall(WB.HandleSlashCommand, WB, "demo") and Demo:IsActive())
local dq = WB.ReminderState.getQueue()
check("demo sample queue", #dq == 4 and dq[1].name == "Push-ups", #dq)
check("demo today 4 of 5", WB.Stats:GetTodayLine():find("Today: 4 / 5"), WB.Stats:GetTodayLine())
check("demo week streak", WB.Stats:GetStreak() == 7, WB.Stats:GetStreak())
check("demo water shown", select(1, WB.Stats:GetTodayWater()) == 32)
check("demo history summary", WB.Stats:GetSummary("week"):find("By activity"))
check("footer short line", WB.Stats:GetShortLine() == "4 / 5 today, 7-day streak", WB.Stats:GetShortLine())
check("footer uses short line", WB.ReminderFrame.progress:GetText() == WB.Stats:GetShortLine(), WB.ReminderFrame.progress:GetText())
check("demo window and popup", WB.ReminderFrame:IsShown() and WorkoutBuddy_HydrationFrame:IsShown())
WB.ReminderCore:Complete(1)
check("demo goal reached message", chatHas("Daily goal reached"))
check("demo real stats untouched", #realStats == 1 and realStats[1].activity == "Real Workout")
check("demo export has real stats", (function()
    local okD, data = LibStub("AceSerializer-3.0"):Deserialize(WB:SerializeProfile():sub(6))
    return okD and #data.stats == 1 and data.stats[1].activity == "Real Workout"
end)())
check("slash demo off", pcall(WB.HandleSlashCommand, WB, "demo") and not Demo:IsActive())
check("demo restores real data", WB.db.profile.stats == realStats and WB.db.profile.reminder_queue == realQueue
    and realQueue[1].name == "Real Queue Item")
check("demo hides popup", not WorkoutBuddy_HydrationFrame:IsShown())

-- Logout or reload during the demo restores before saving
-- (Firing PLAYER_LOGOUT itself would also run AceDB's logout cleanup, which
-- strips defaults from the profile as if the game were closing.)
Demo:Start()
check("demo listens for logout", Demo.logoutFrame:IsEventRegistered("PLAYER_LOGOUT"))
Demo.logoutFrame:GetScript("OnEvent")(Demo.logoutFrame, "PLAYER_LOGOUT")
check("demo logout restores", not Demo:IsActive() and WB.db.profile.stats == realStats and WB.db.profile.reminder_queue == realQueue)

-- Switching profile during the demo restores the original profile
Demo:Start()
WB.db:SetProfile("Second")
check("demo stops on profile switch", not Demo:IsActive())
WB.db:SetProfile("Default")
check("demo profile switch restores", WB.db.profile.stats == realStats and #WB.db.profile.stats == 1)

-- Importing during the demo keeps the import, not the real data
Demo:Start()
WB:DeserializeProfile(LibStub("AceSerializer-3.0"):Serialize({ stats = { { activity = "Imported", amount = 1, timestamp = NOW } } }))
check("demo import wins", not Demo:IsActive() and #WB.db.profile.stats == 1 and WB.db.profile.stats[1].activity == "Imported")

-- Early-morning history stays in time order and never in the future
local early = os.time({ year = 2026, month = 11, day = FRI, hour = 0, min = 2, sec = 0 })
local hist = Demo.BuildHistory(early, "oz")
local ordered, future = true, false
for i, r in ipairs(hist) do
    if i > 1 and r.timestamp < hist[i - 1].timestamp then ordered = false end
    if r.timestamp > early then future = true end
end
check("demo history ordered", ordered and not future and #hist == 33 + 28, #hist)

----------------------------------------------------------------------------
-- Set workouts, item use triggers and the raid recap
q = WB.ReminderState.getQueue()
local P = WB.db.profile
P.enabled = true
P.quiet_hours.workouts.enabled = false
P.notify.chat = true
wipe(P.triggers)
WB.TriggerManager:Reset()
WB.ReminderQueue:Clear()
at(FRI, 15)

local function queued(name)
    for _, w in ipairs(WB.ReminderState.getQueue()) do if w.name == name then return w.amount end end
    return 0
end

-- Built-in event with a set workout: every occurrence counts, no cooldown
P.event_map.player_death = true
P.builtin_workouts.player_death = { name = "Burpees", amount = 5, unit = "reps" }
FireEvent("PLAYER_DEAD")
FireEvent("PLAYER_DEAD")
check("set workout per death", queued("Burpees") == 10, queued("Burpees"))
check("set workout announced out of combat", chatHas("You Died.*Burpees x5"))

-- Choosing it in the Workouts tab
-- The same through the trigger list (Triggers page rows)
local TLm = WB.TriggerList
local function entryFor(id)
    for _, e in ipairs(TLm:Entries()) do if e.id == id then return e end end
end
local deathEntry = entryFor("b:player_death")
check("trigger list shows death with set workout", deathEntry and deathEntry.gives.mode == "set"
    and deathEntry.gives.workout.name == "Burpees")
TLm:SetGives(deathEntry, "random")
check("set workout back to random", P.builtin_workouts.player_death == nil)
local firstW = P.workouts[1]
P.event_map.levelup = true
TLm:SetGives(entryFor("b:levelup"), "set", { name = firstW.name, amount = 7, unit = firstW.unit })
check("set workout chosen from list", P.builtin_workouts.levelup and P.builtin_workouts.levelup.amount == 7
    and P.builtin_workouts.levelup.name == firstW.name)
TLm:SetGives(entryFor("b:levelup"), "random")
check("only enabled built-ins listed", entryFor("b:xpbubble") == nil and entryFor("b:levelup") ~= nil)
TLm:SetEnabled(entryFor("b:levelup"), false)
check("switched off stays visible until reopened", entryFor("b:levelup") and not entryFor("b:levelup").enabled)
TLm:ResetVisibility()
check("hidden after reopening", entryFor("b:levelup") == nil)
local availableBefore = #TLm:AvailableBuiltins()
TLm:AddBuiltin("levelup", "random")
check("add a built-in", P.event_map.levelup and #TLm:AvailableBuiltins() == availableBefore - 1)
P.builtin_workouts.player_death = { name = "Burpees", amount = 5, unit = "reps" }

-- Mock bags: Classic-style consumables (subclass 0) so presets fall back to names
local BAG = { [1] = 111, [2] = 222, [3] = 333 }
local ITEMS = {
    [111] = { name = "Major Mana Potion", spell = "Restore Mana", spellID = 5001, class = 0, sub = 0 },
    [222] = { name = "Healthstone", spell = "Healthstone", spellID = 5002, class = 0, sub = 0 },
    [333] = { name = "Roasted Quail", spell = "Food", spellID = 5003, class = 0, sub = 0 },
}
local SPELLS = { [5001] = "Restore Mana", [5002] = "Healthstone", [5003] = "Food", [9999] = "Fireball" }
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 4 or 0 end,
    GetContainerItemID = function(bag, slot) return bag == 0 and BAG[slot] or nil end,
}
C_Item = {
    GetItemSpell = function(id) local i = ITEMS[id] if i then return i.spell, i.spellID end end,
    GetItemInfoInstant = function(id) local i = ITEMS[id] if i then return id, "Consumable", "Consumable", "", 0, i.class, i.sub end end,
    GetItemNameByID = function(id) return ITEMS[id] and ITEMS[id].name end,
}
C_Spell = { GetSpellName = function(id) return SPELLS[id] end }

check("item use idle without triggers", not WB.ItemUse.active)
table.insert(P.triggers, { name = "Mana potion", event = "ITEM_USED", action = "fixed", enabled = true,
    options = { preset = "potion" }, workout = { name = "Push-ups", amount = 3, unit = "reps" } })
WB.TriggerManager:Reset()
check("item use active with a trigger", WB.ItemUse.active and WB.ItemUse.bySpell and WB.ItemUse.bySpell[5001] ~= nil)
WB.ReminderQueue:Clear()
IN_COMBAT = true
local chatBeforePots = #CHAT
for _ = 1, 10 do FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 5001) end
check("ten potions = 30 push-ups", queued("Push-ups") == 30, queued("Push-ups"))
check("no chat per potion in combat", #CHAT == chatBeforePots, #CHAT - chatBeforePots)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "raid3", "Cast-2", 5001)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3", 9999)
check("other units and spells ignored", queued("Push-ups") == 30)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-4", SECRET)
check("secret spell ignored safely", queued("Push-ups") == 30 and not ERRORS)
IN_COMBAT = false

-- Presets and named items/spells
local IU = WB.ItemUse
check("preset food by spell name", IU.Matches({ preset = "food" }, IU:Lookup(5003)))
check("preset healthstone", IU.Matches({ preset = "healthstone" }, IU:Lookup(5002)))
check("preset potion not food", not IU.Matches({ preset = "potion" }, IU:Lookup(5003)))
check("preset any consumable", IU.Matches({ preset = "consumable" }, IU:Lookup(5003)))
check("named item", IU.Matches({ preset = "named", items = "major mana potion" }, IU:Lookup(5001)))
check("named partial and spell", IU.Matches({ preset = "named", items = "Mana Potion, Fireball" }, IU:Lookup(9999)))
check("named no match", not IU.Matches({ preset = "named", items = "Healthstone" }, IU:Lookup(5001)))
check("retail subclass potion", IU.Matches({ preset = "potion" },
    { name = "algari mana elixir thing", spellName = "refreshing", classID = 0, subclassID = 1 }))

-- Bags change: a new item is recognized after the bag update
ITEMS[444] = { name = "Superior Healing Potion", spell = "Healing Potion", spellID = 5004, class = 0, sub = 0 }
SPELLS[5004] = "Healing Potion"
BAG[4] = 444
FireEvent("BAG_UPDATE_DELAYED")
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-5", 5004)
check("new bag item counted", queued("Push-ups") == 33, queued("Push-ups"))

-- Random action on an item trigger still works, and the editor opens on item and set triggers
-- Triggers page: rows, the add form and editing
SUI:Show("triggers")
local trigList = SUI.FindSpec("triggers", "Your triggers")
local mana = entryFor("c:1")
check("trigger list row label", mana and mana.label == "Mana potion" and mana.gives.mode == "set"
    and mana.sub:find("Using any potion"), mana and mana.sub)
check("trigger rows rendered", trigList._row and trigList._row.entryRows[1] and trigList._row.entryRows[1]:IsShown())
local okEd2, eEd2 = pcall(SUI.OpenTriggerForm, SUI, 1)
check("edit form opens on item trigger", okEd2 and SUI.form and SUI.form.kind == "item" and SUI.form.index == 1, eEd2)
local okSave, eSave = pcall(SUI.SaveTriggerForm, SUI)
check("edit form saves", okSave and SUI.form == nil and P.triggers[1].workout.amount == 3, eSave)
local okEd3, eEd3 = pcall(SUI.OpenTriggerForm, SUI)
check("add form opens on the tiles", okEd3 and SUI.form and SUI.form.kind == nil, eEd3)
SUI:CloseTriggerForm()

-- Saved data upkeep: a set trigger without a valid workout falls back to random
table.insert(P.triggers, { name = "Broken set", event = "PLAYER_DEAD", action = "fixed", enabled = true, options = {}, workout = { amount = 3 } })
WB:MigrateProfile()
check("broken set workout falls back", P.triggers[2].action == "workout" and P.triggers[2].workout == nil)
table.remove(P.triggers, 2)
P.builtin_workouts.bogus = "x"
WB:MigrateProfile()
check("bad builtin workout removed", P.builtin_workouts.bogus == nil and P.builtin_workouts.player_death.amount == 5)

-- Boss fight recap: totals for the fight, window waits for combat to end
WB.ReminderQueue:Clear()
WB.ReminderFrame:Hide()
FireEvent("ENCOUNTER_START", 1, "Boss", 14, 20)
IN_COMBAT = true
for _ = 1, 4 do FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-6", 5001) end
FireEvent("PLAYER_DEAD")
FireEvent("ENCOUNTER_END", 1, "Boss", 14, 20, 0)
Advance(2)
check("boss recap printed", chatHas("Boss fight recap.*Push%-ups x12 reps, Burpees x5 reps"))
check("boss recap waits for combat", not WB.ReminderFrame:IsShown())
IN_COMBAT = false
FireEvent("PLAYER_REGEN_ENABLED")
Advance(3)
check("boss recap opens after combat", WB.ReminderFrame:IsShown())

-- Instance recap when leaving
WB.ReminderFrame:Hide()
IsInInstance = function() return true, "raid" end
FireEvent("PLAYER_ENTERING_WORLD", false, false)
FireEvent("PLAYER_DEAD")
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-7", 5001)
IsInInstance = function() return false, "none" end
FireEvent("PLAYER_ENTERING_WORLD", false, false)
check("instance recap printed", chatHas("Instance recap.*Burpees x5 reps, Push%-ups x3 reps"))
check("instance recap opens", WB.ReminderFrame:IsShown())

-- Recap off: nothing printed
P.reminder_events.recap = false
WB.ReminderEvents:Register()
local chatBeforeOff = #CHAT
FireEvent("ENCOUNTER_START", 2, "Boss", 14, 20)
FireEvent("PLAYER_DEAD")
FireEvent("ENCOUNTER_END", 2, "Boss", 14, 20, 1)
Advance(2)
local recapLine = false
for i = chatBeforeOff + 1, #CHAT do if CHAT[i]:find("recap") then recapLine = true end end
check("recap off is silent", not recapLine)
P.reminder_events.recap = true
WB.ReminderEvents:Register()

-- Quiet hours pause set workouts too
P.quiet_hours.workouts.enabled = true
P.quiet_hours.workouts.mode = "pause"
at(FRI, 23)
local burpeesBefore = queued("Burpees")
FireEvent("PLAYER_DEAD")
check("quiet hours pause set workouts", queued("Burpees") == burpeesBefore)
P.quiet_hours.workouts.enabled = false

-- Options still callable with the new settings
walk()
check("settings pages with set workouts", errs == 0)
wipe(P.triggers)
WB.TriggerManager:Reset()
check("item use idle again", not WB.ItemUse.active)

-- Beginner-friendly item picking
local classicLink = "|cff1eff00|Hitem:13444::::::::60:::::|h[Major Mana Potion]|h|r"
local retailLink = "|cnIQ3:|Hitem:212241::::::::80:::::|h[Algari Mana Potion |A:Professions-ChatIcon-Quality-Tier3:17:17::1|a]|h|r"
check("link to name (classic)", IU.CleanName(classicLink) == "Major Mana Potion", IU.CleanName(classicLink))
check("link to name (quality icon)", IU.CleanName(retailLink) == "Algari Mana Potion", IU.CleanName(retailLink))
check("typed name trimmed", IU.CleanName("  Healthstone ") == "Healthstone")
local list = IU.AddName("", classicLink)
list = IU.AddName(list, "healthstone")
list = IU.AddName(list, "Major Mana Potion") -- duplicate, any case
check("add names without duplicates", list == "Major Mana Potion, healthstone", list)
check("remove a name", IU.RemoveName(list, "HEALTHSTONE") == "Major Mana Potion")
check("names from a pasted link list", #IU.NameList(classicLink .. ", Healthstone") == 2)
check("stored link still matches", IU.Matches({ preset = "named", items = classicLink }, IU:Lookup(5001)))
local bagItems = IU:BagItems()
check("bag picker lists usable items", #bagItems == 4 and bagItems[1].displayName == "Healthstone", #bagItems)
local sug = IU:Suggest("mana")
check("typing suggests from bags", #sug == 1 and sug[1].displayName == "Major Mana Potion", #sug)
check("suggest accepts a link", #IU:Suggest(classicLink) == 1)
check("no suggestion for empty text", #IU:Suggest("") == 0)
local captured = false
check("capture starts", IU:Capture(function(name) captured = name end, 30))
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "raid2", "Cast-8", 5002)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", 5002)
check("use an item to add it", captured == "Healthstone", tostring(captured))
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-10", 5001)
check("capture stops after one", captured == "Healthstone")
captured = false
IU:Capture(function(name) captured = name end, 30)
Advance(31)
check("capture times out", captured == nil)
SUI:Show("triggers")
local itemBtn = SUI.FindSpec("triggers", "Your triggers")._row.itemBtn
local okQuick, eQuick = pcall(itemBtn._scripts.OnClick, itemBtn)
check("count an item button opens the item form", okQuick and SUI.form and SUI.form.kind == "item", eQuick)
-- add items the beginner ways: bag list, use-it-to-add-it, typing
local okBag = pcall(SUI.AddFormItem, SUI, IU:BagItems()[2].displayName)
check("form: add from bags", okBag and SUI.form.t.options.items == IU:BagItems()[2].displayName, SUI.form.t.options.items)
SUI.form.typed = "quail"
SUI:LayoutSuggestions()
local sugRow = SUI.triggerListRow.form.suggestions[1]
check("form: typing suggests", sugRow and sugRow:IsShown() and sugRow.name == "Roasted Quail")
sugRow._scripts.OnClick(sugRow)
check("form: click suggestion adds", #IU.NameList(SUI.form.t.options.items) == 2)
local capBtn = SUI.triggerListRow.form.capture
capBtn._scripts.OnClick(capBtn)
FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-11", 5002) -- Healthstone, not yet in the list
check("form: use an item to add it", #IU.NameList(SUI.form.t.options.items) == 3, SUI.form.t.options.items)
SUI.form.t.workout = { name = "Squats", amount = 4, unit = "reps" }
SUI.triggerListRow.form.wName:SetText("Squats")
SUI.triggerListRow.form.wAmount:SetText("4")
SUI.triggerListRow.form.wUnit:SetText("reps")
local countBefore = #P.triggers
check("form: save item trigger", SUI:SaveTriggerForm() and #P.triggers == countBefore + 1)
local saved = P.triggers[#P.triggers]
check("form: auto name and set workout", saved.event == "ITEM_USED" and saved.name:find("Healthstone")
    and saved.workout.name == "Squats" and saved.workout.amount == 4, saved.name)
-- a built-in added through the form
SUI:OpenTriggerForm()
SUI.form.builtin = "quest_turnin"
SUI:SetFormGives("set")
SUI.triggerListRow.form.wName:SetText("Lunges")
SUI.triggerListRow.form.wAmount:SetText("6")
SUI.triggerListRow.form.wUnit:SetText("reps")
check("form: add built-in with set workout", SUI:SaveTriggerForm() and P.event_map.quest_turnin
    and P.builtin_workouts.quest_turnin.name == "Lunges" and P.builtin_workouts.quest_turnin.amount == 6)
-- validation message instead of saving
SUI:OpenTriggerForm(nil, "ITEM_USED")
SUI.form.t.options.preset = "named"
check("form: empty item list is refused", not SUI:SaveTriggerForm() and SUI.form ~= nil)
SUI:CloseTriggerForm()
-- any game event: search list
SUI:OpenTriggerForm()
SUI.form.kind = "event"
SUI.form.t.event = nil
SUI:Render()
SUI.form.eventFilter = "loot"
SUI:LayoutEventList()
local evRow = SUI.triggerListRow.form.eventRows[1]
check("form: event search filters", evRow and evRow:IsShown() and evRow.evt:find("LOOT"), evRow and evRow.evt)
evRow._scripts.OnClick(evRow)
check("form: pick event keeps the form", SUI.form and SUI.form.t.event == evRow.evt)
SUI:CloseTriggerForm()

-- Game detection per client, and live probes that override the table
local realBuild = GetBuildInfo
GetBuildInfo = function() return "12.0.5", "1", "Nov 2026", 120005 end
check("retail detected, keystones shown", WB.GameFlavor() == "retail" and WB:IsBuiltInTriggerSupported("challenge_complete"))
GetBuildInfo = function() return "1.15.9", "1", "Nov 2026", 11509 end
check("classic detected, no keystones or achievements", WB.GameFlavor() == "classic"
    and not WB.HasContent("keystones") and not WB.HasContent("achievements") and WB.HasContent("battlegrounds"))
GetBuildInfo = realBuild
C_ChallengeMode = { GetMapTable = function() return { 375, 376 } end }
check("probe: a client that adds keystones shows them", WB.HasContent("keystones") and WB:IsBuiltInTriggerSupported("challenge_complete"))
C_ChallengeMode = { GetMapTable = function() return {} end }
check("probe: empty keystone list stays hidden", not WB.HasContent("keystones"))
C_ChallengeMode = { GetMapTable = function() error("not here") end }
check("probe errors are safe", not WB.HasContent("keystones"))
C_ChallengeMode = nil
WB.TriggerManager.EventCategories = nil
WB.TriggerManager:BuildCatalog()
local hasKeystoneEvent = false
for _, list in pairs(WB.TriggerManager.EventCategories) do
    for _, e in ipairs(list) do if e == "CHALLENGE_MODE_COMPLETED" then hasKeystoneEvent = true end end
end
check("event list hides keystone events on Forever", not hasKeystoneEvent)
check("unknown content counts as present", WB.HasContent("something_new"))

check("no error handler calls", not ERRORS, ERRORS)
realPrint(string.format("RESULT: %d passed, %d failed", pass, fail))
TEST_FAILURES = fail
if fail > 0 then
    realPrint("--- chat log tail ---")
    for i = math.max(1, #CHAT - 15), #CHAT do realPrint(CHAT[i]) end
end
