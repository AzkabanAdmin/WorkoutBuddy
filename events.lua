-- events.lua
-- Built-in workout triggers (level up, boss kills, zones, ...) and the
-- play-time break timer. Custom triggers live in trigger_manager.lua.

local _, WorkoutBuddy = ...

local function EventMap()
    return WorkoutBuddy.db.profile.event_map
end

-- Built-in trigger -> game event. Options whose event the client lacks are
-- hidden in the settings (see config/general.lua).
WorkoutBuddy.BUILTIN_TRIGGER_EVENTS = {
    levelup = "PLAYER_LEVEL_UP",
    xpbubble = "PLAYER_XP_UPDATE",
    zonechange_newarea = "ZONE_CHANGED_NEW_AREA",
    zonechange_zone = "ZONE_CHANGED",
    zonechange_indoors = "ZONE_CHANGED_INDOORS",
    boss_kill = "ENCOUNTER_END",
    challenge_complete = "CHALLENGE_MODE_COMPLETED",
    achievement = "ACHIEVEMENT_EARNED",
    player_death = "PLAYER_DEAD",
    quest_turnin = "QUEST_TURNED_IN",
}

function WorkoutBuddy:IsBuiltInTriggerSupported(key)
    local evt = self.BUILTIN_TRIGGER_EVENTS[key]
    return evt == nil or self.IsEventValid(evt)
end

function WorkoutBuddy:RegisterBuiltInEvents()
    for _, evt in pairs(self.BUILTIN_TRIGGER_EVENTS) do
        if self.IsEventValid(evt) then
            self:RegisterEvent(evt)
        end
    end
    self.lastXpBubble = self:CurrentXpBubble()
end

function WorkoutBuddy:PLAYER_LEVEL_UP()
    if EventMap().levelup then self:SuggestWorkout("Level Up") end
end

function WorkoutBuddy:ZONE_CHANGED_NEW_AREA()
    if EventMap().zonechange_newarea then self:SuggestWorkout("New Zone") end
end

function WorkoutBuddy:ZONE_CHANGED()
    if EventMap().zonechange_zone then self:SuggestWorkout("Zone Change") end
end

function WorkoutBuddy:ZONE_CHANGED_INDOORS()
    if EventMap().zonechange_indoors then self:SuggestWorkout("Indoors/Outdoors") end
end

-- One "bubble" is 1/20th of a level.
function WorkoutBuddy:CurrentXpBubble()
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if self.IsSecret(cur) or self.IsSecret(max) or not max or max == 0 then return 0 end
    return math.floor((cur / max) * 20) + 1
end

function WorkoutBuddy:PLAYER_XP_UPDATE()
    local current = self:CurrentXpBubble()
    if EventMap().xpbubble and current > (self.lastXpBubble or 0) then
        self:SuggestWorkout("XP Bubble")
    end
    self.lastXpBubble = current
end

-- ENCOUNTER_END: encounterID, encounterName, difficultyID, groupSize, success
function WorkoutBuddy:ENCOUNTER_END(_, _, _, _, _, success)
    if self.IsSecret(success) then return end
    if success == 1 and EventMap().boss_kill then
        self:SuggestWorkout("Boss Defeated")
    end
end

function WorkoutBuddy:CHALLENGE_MODE_COMPLETED()
    if EventMap().challenge_complete then self:SuggestWorkout("Keystone Complete") end
end

-- ACHIEVEMENT_EARNED: achievementID, alreadyEarned
function WorkoutBuddy:ACHIEVEMENT_EARNED(_, _, alreadyEarned)
    if not alreadyEarned and EventMap().achievement then
        self:SuggestWorkout("Achievement")
    end
end

function WorkoutBuddy:PLAYER_DEAD()
    if EventMap().player_death then self:SuggestWorkout("You Died") end
end

function WorkoutBuddy:QUEST_TURNED_IN()
    if EventMap().quest_turnin then self:SuggestWorkout("Quest Turned In") end
end

------------------------------------------------------------------------
-- Play-time break timer: suggest a workout after N minutes of active play
-- without one. Minutes spent AFK or in a loading screen do not count, and
-- any suggestion or completed workout restarts the count.
------------------------------------------------------------------------
function WorkoutBuddy:StartPlayTimer()
    if self.playTicker then
        self.playTicker:Cancel()
        self.playTicker = nil
    end
    self.playMinutes = 0
    local p = self.db.profile
    if not (p.enabled and p.event_map.play_timer) then return end
    self.playTicker = C_Timer.NewTicker(60, function() self:OnPlayMinute() end)
end

function WorkoutBuddy:OnPlayMinute()
    local p = self.db.profile
    if not (p.enabled and p.event_map.play_timer) then return end
    if UnitIsAFK("player") then return end
    self.playMinutes = (self.playMinutes or 0) + 1
    local target = tonumber(p.play_timer_minutes) or 45
    if self.playMinutes >= target and not self.InCombat() then
        self.lastSuggestAt = nil -- the break timer is never blocked by the cooldown
        self:SuggestWorkout(string.format("%d min of play", self.playMinutes))
    end
end
