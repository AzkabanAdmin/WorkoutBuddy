-- wow_events.lua
-- Events offered in the custom trigger editor. The list is filtered at
-- runtime, so events the current client (Forever, Retail or Classic Era)
-- does not support are hidden automatically. Players can still type any
-- other event name in the editor.

local _, WorkoutBuddy = ...

WorkoutBuddy.WowEvents = {
    -- Achievements and milestones
    "ACHIEVEMENT_EARNED",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_START",
    "PLAYER_LEVEL_UP",
    "PLAYER_XP_UPDATE",
    "SKILL_LINES_CHANGED",
    "LEARNED_SPELL_IN_TAB",
    "NEW_RECIPE_LEARNED",

    -- Auction house, bank, mail, merchants
    "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "MAIL_SHOW",
    "MAIL_CLOSED",
    "MERCHANT_SHOW",
    "MERCHANT_CLOSED",
    "TRAINER_SHOW",
    "TRAINER_CLOSED",
    "GOSSIP_SHOW",
    "GOSSIP_CLOSED",

    -- Bags, loot and money
    "BAG_UPDATE",
    "LOOT_OPENED",
    "LOOT_CLOSED",
    "PLAYER_MONEY",

    -- Chat
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_RAID",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_TEXT_EMOTE",
    "CHAT_MSG_SYSTEM",
    "CHAT_MSG_LOOT",
    "CHAT_MSG_MONEY",
    "CHAT_MSG_SKILL",
    "CHAT_MSG_COMBAT_XP_GAIN",
    "CHAT_MSG_COMBAT_HONOR_GAIN",

    -- Combat and death
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_DEAD",
    "PLAYER_ALIVE",
    "PLAYER_UNGHOST",
    "RESURRECT_REQUEST",
    "UNIT_HEALTH",
    "DUEL_REQUESTED",
    "DUEL_FINISHED",

    -- Dungeons, raids, groups and queues
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "BOSS_KILL",
    "GROUP_ROSTER_UPDATE",
    "PARTY_INVITE_REQUEST",
    "READY_CHECK",
    "LFG_UPDATE",
    "LFG_PROPOSAL_SHOW",
    "LFG_ROLE_CHECK_SHOW",
    "LFG_COMPLETION_REWARD",
    "UPDATE_BATTLEFIELD_STATUS",
    "PVP_MATCH_COMPLETE",
    "SCENARIO_COMPLETED",
    "INSTANCE_BOOT_START",
    "WEEKLY_REWARDS_UPDATE",

    -- Player state
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGIN",
    "PLAYER_FLAGS_CHANGED",
    "PLAYER_UPDATE_RESTING",
    "PLAYER_CONTROL_LOST",
    "PLAYER_CONTROL_GAINED",
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_EQUIPMENT_CHANGED",
    "UPDATE_EXHAUSTION",
    "CINEMATIC_START",
    "CINEMATIC_STOP",
    "PLAY_MOVIE",

    -- Quests
    "QUEST_ACCEPTED",
    "QUEST_TURNED_IN",
    "QUEST_COMPLETE",
    "QUEST_FINISHED",
    "QUEST_LOG_UPDATE",

    -- Professions and trade
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_CLOSE",
    "TRADE_SHOW",
    "TRADE_CLOSED",

    -- Travel and zones
    "TAXIMAP_OPENED",
    "TAXIMAP_CLOSED",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "HEARTHSTONE_BOUND",
    "CONFIRM_SUMMON",
}

-- Short descriptions shown in the trigger editor
WorkoutBuddy.EventHelp = {
    PLAYER_LEVEL_UP          = "Fires when you gain a level.",
    PLAYER_XP_UPDATE         = "Your XP changed. Does not fire at max level.",
    UNIT_HEALTH              = "Checks a unit's health percent using the fields below. Fires only when the condition becomes true. Health can be hidden from addons in some situations on modern clients; the trigger then waits.",
    PLAYER_UPDATE_RESTING    = "You entered or left a rest area (inn or city).",
    PLAYER_REGEN_DISABLED    = "You entered combat.",
    PLAYER_REGEN_ENABLED     = "You left combat. A good moment for a quick set.",
    PLAYER_DEAD              = "You died. Push-ups build character.",
    PLAYER_ALIVE             = "You resurrected or released.",
    BAG_UPDATE               = "Your bags changed. Fires very often.",
    PLAYER_MONEY             = "Your gold changed.",
    GOSSIP_SHOW              = "An NPC dialogue opened.",
    PLAYER_TARGET_CHANGED    = "Your target changed.",
    CHAT_MSG_SAY             = "Someone used /say. Condition example: local msg = ...; return msg:find('hello')",
    CHAT_MSG_WHISPER         = "You received a whisper. The first argument is the message text.",
    ENCOUNTER_END            = "A boss encounter ended. Arguments: encounterID, name, difficultyID, groupSize, success (1 = kill).",
    ENCOUNTER_START          = "A boss encounter began. Arguments: encounterID, name, difficultyID, groupSize.",
    BOSS_KILL                = "A boss died. Arguments: encounterID, name.",
    ACHIEVEMENT_EARNED       = "You earned an achievement. Arguments: achievementID, alreadyEarned.",
    CHALLENGE_MODE_COMPLETED = "A Mythic+ keystone run finished.",
    CHALLENGE_MODE_START     = "A Mythic+ keystone run started.",
    LFG_UPDATE               = "Your dungeon finder status changed.",
    LFG_PROPOSAL_SHOW        = "A dungeon group was found.",
    LFG_ROLE_CHECK_SHOW      = "A role check is showing.",
    LFG_COMPLETION_REWARD    = "You finished a random dungeon and received the reward.",
    UPDATE_BATTLEFIELD_STATUS = "Your battleground queue status changed.",
    GROUP_ROSTER_UPDATE      = "Your group changed.",
    SCENARIO_COMPLETED       = "A scenario completed.",
    PVP_MATCH_COMPLETE       = "A battleground or arena match ended.",
    AUCTION_HOUSE_SHOW       = "You opened the Auction House.",
    WEEKLY_REWARDS_UPDATE    = "Your weekly rewards updated.",
    PLAYER_SPECIALIZATION_CHANGED = "You switched specialization.",
    QUEST_TURNED_IN          = "You turned in a quest. Arguments: questID, xpReward, moneyReward.",
    QUEST_ACCEPTED           = "You accepted a quest.",
    TAXIMAP_CLOSED           = "The flight map closed (often right as a flight starts).",
    PLAYER_CONTROL_LOST      = "You lost control of your character (flights, fear, cinematics).",
    ZONE_CHANGED_NEW_AREA    = "You entered a new zone.",
    PLAYER_ENTERING_WORLD    = "You logged in, reloaded or passed a loading screen.",
    PLAYER_FLAGS_CHANGED     = "Your AFK or DND flag changed.",
    CINEMATIC_START          = "A cinematic started.",
    READY_CHECK              = "A ready check started.",
}
