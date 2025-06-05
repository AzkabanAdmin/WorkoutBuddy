local TriggerManager = WorkoutBuddy and WorkoutBuddy.TriggerManager

function WorkoutBuddy:OnEnable()
    -- Level Up
    self:RegisterEvent("PLAYER_LEVEL_UP")
    -- Zone Change New Zone
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    -- Zone Change
    self:RegisterEvent("ZONE_CHANGED")
    -- Zone Change Indoors
    self:RegisterEvent("ZONE_CHANGED_INDOORS")
    -- XP Updates
    self:RegisterEvent("PLAYER_XP_UPDATE")
    -- Initialize previous XP bubble tracker
    self.lastXpBubble = self:CurrentXpBubble()
end

-- Level Up
function WorkoutBuddy:PLAYER_LEVEL_UP()
    if TriggerManager and TriggerManager.HandleEvent then
        TriggerManager:HandleEvent("PLAYER_LEVEL_UP")
    end
    if self.db.profile.event_map.levelup then
        self:SuggestWorkout("Level Up")
    end
end

-- Zone Change New Area
function WorkoutBuddy:ZONE_CHANGED_NEW_AREA()
    if TriggerManager and TriggerManager.HandleEvent then
        TriggerManager:HandleEvent("ZONE_CHANGED_NEW_AREA")
    end
    if self.db.profile.event_map.zonechange_newarea then
        self:SuggestWorkout("Major Zone Change")
    end
end

-- Zone Change
function WorkoutBuddy:ZONE_CHANGED()
    if TriggerManager and TriggerManager.HandleEvent then
        TriggerManager:HandleEvent("ZONE_CHANGED")
    end
    if self.db.profile.event_map.zonechange_zone then
        self:SuggestWorkout("Minor Zone Change")
    end
end

-- Zone Change Indoors/Outdoors
function WorkoutBuddy:ZONE_CHANGED_INDOORS()
    if TriggerManager and TriggerManager.HandleEvent then
        TriggerManager:HandleEvent("ZONE_CHANGED_INDOORS")
    end
    if self.db.profile.event_map.zonechange_indoors then
        self:SuggestWorkout("Indoors/Outdoors Change")
    end
end

-- XP Bubble logic
function WorkoutBuddy:PLAYER_XP_UPDATE()
    if TriggerManager and TriggerManager.HandleEvent then
        TriggerManager:HandleEvent("PLAYER_XP_UPDATE")
    end
    if not self.db.profile.event_map.xpbubble then return end
    local current = self:CurrentXpBubble()
    if current > (self.lastXpBubble or 0) then
        self:SuggestWorkout("XP Bubble")
    end
    self.lastXpBubble = current
end

-- Helper: Figure out which XP "bubble" the player is currently in
function WorkoutBuddy:CurrentXpBubble()
    local unit = "player"
    local currXP = UnitXP(unit)
    local maxXP = UnitXPMax(unit)
    local bubbles = 20  -- Classic XP bar has 20 bubbles per level
    if maxXP == 0 then return 0 end
    return math.floor((currXP / maxXP) * bubbles) + 1
end
