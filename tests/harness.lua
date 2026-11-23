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
INVALID_EVENTS = { CHALLENGE_MODE_COMPLETED = true, ACHIEVEMENT_EARNED = true, LFG_UPDATE = true,
    CHALLENGE_MODE_START = true, WEEKLY_REWARDS_UPDATE = true, PLAYER_SPECIALIZATION_CHANGED = true }
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
check("builtin unsupported hidden", WB:IsBuiltInTriggerSupported("achievement") == false)
check("builtin supported", WB:IsBuiltInTriggerSupported("boss_kill") == true)
check("options table", WB.options and WB.options.args.general and WB.options.args.profile)

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

-- Option getters/setters: walk every option and call get, values, name, hidden, disabled
local walked, errs = 0, 0
local function walk(group, info)
    for k, opt in pairs(group.args or {}) do
        local inf = { k, handler = WB, options = WB.options, appName = "WorkoutBuddy" }
        if group == WB.options and k == "profile" then inf = { k, handler = opt.handler, options = WB.options } end
        for _, fld in ipairs({ "name", "desc", "hidden", "disabled", "values", "get", "sorting" }) do
            if type(opt[fld]) == "function" then
                walked = walked + 1
                local ok2, e = pcall(opt[fld], inf)
                if not ok2 then errs = errs + 1 realPrint("OPTION ERROR " .. k .. "." .. fld .. ": " .. tostring(e)) end
            end
        end
        if opt.type == "group" then walk(opt, inf) end
    end
end
local savedProfile = WB.options.args.profile; WB.options.args.profile = nil; walk(WB.options); WB.options.args.profile = savedProfile
check("options callable (" .. walked .. ")", errs == 0)

-- Execute safe buttons
local wo = WB.options.args.workouts.args
wo.category.set(nil, "Strength")
wo.pick.set(nil, select(2, (function() local v, o = nil, nil; return nil, wo.sorting and nil end)()) or "1")
local vals = wo.pick.values()
local firstKey = next(vals)
wo.pick.set(nil, firstKey)
local n0 = #WB.db.profile.workouts
wo.addPick.func()
check("library add", #WB.db.profile.workouts == n0 + 1)
wo.addPick.func()
check("library no duplicates", #WB.db.profile.workouts == n0 + 1)
wo.addCategory.func()
check("add category", #WB.db.profile.workouts > n0 + 1)
WB:RebuildWorkoutListOptions()
local savedProfile = WB.options.args.profile; WB.options.args.profile = nil; walk(WB.options); WB.options.args.profile = savedProfile
check("options after rebuild", errs == 0)

-- Trigger editor opens (AceGUI) without error
local okEd, eEd = pcall(function() WB:OpenTriggerEditor("workout") end)
check("trigger editor opens", okEd, eEd)

-- Slash commands
for _, c in ipairs({ "help", "show", "now", "water", "stats", "pause", "resume", "center", "minimap", "minimap", "bogus" }) do
    local okS, eS = pcall(WB.HandleSlashCommand, WB, c)
    check("slash " .. c, okS, eS)
end

-- Minimap tooltip
local tip = { AddLine = function() end }
local okT = pcall(LibStub("LibDataBroker-1.1"):GetDataObjectByName("WorkoutBuddy").OnTooltipShow, tip)
check("minimap tooltip", okT)

check("no error handler calls", not ERRORS, ERRORS)
realPrint(string.format("RESULT: %d passed, %d failed", pass, fail))
TEST_FAILURES = fail
if fail > 0 then
    realPrint("--- chat log tail ---")
    for i = math.max(1, #CHAT - 15), #CHAT do realPrint(CHAT[i]) end
end
