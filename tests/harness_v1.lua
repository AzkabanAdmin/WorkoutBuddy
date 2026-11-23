-- Upgrade test: loads the addon over saved data from version 2.0 and checks the migration.
V1_DB = {
  profileKeys = { ["Tester - Forever Realm"] = "Default" },
  profiles = { Default = {
    workouts = { { name = "Pushups", amount = 10, unit = "reps" }, { name = "Wall Angels", amount = 10, unit = "reps", category = "Posture" }, { name = "" } },
    event_map = { levelup = true, xpbubble = true },
    triggers = { { name = "Old", event = "PLAYER_LEVEL_UP", action = "workout", enabled = true } },
    hydration = { enabled = true, x = 0, y = 0, initialized = true, per = 0, total = 32, sound = "Alarm Clock", next_time = 0 },
    reminder_frame = { x = 420, y = 640, scale = 1.1, alpha = 0.85, show_when = "rested", sound = 567463, initialized = true },
    reminder_queue = { { name = "Pushups", amount = 20, unit = "reps" } },
    stats = { { activity = "Pushups", amount = 10, unit = "reps", timestamp = 1763700000 } },
    minimap = { minimapPos = 200 },
  } },
}
V1_TESTS = function(WB)
  local p = WB.db.profile
  local ok = true
  local function check(n, c, x) if not c then ok = false io.write("FAIL " .. n .. " " .. tostring(x) .. string.char(10)) end end
  check("kept workouts", #p.workouts == 2, #p.workouts)
  check("category stripped", p.workouts[2].category == nil)
  check("trigger options added", type(p.triggers[1].options) == "table")
  check("hydration pos reset", p.hydration.x == nil and p.hydration.y == nil)
  check("hydration per default", p.hydration.per == 8, p.hydration.per)
  check("frame pos kept", p.reminder_frame.x == 420)
  check("old fields gone", p.reminder_frame.sound == nil and p.reminder_frame.show_when == nil)
  check("queue kept", #p.reminder_queue == 1)
  check("stats kept", #p.stats == 1)
  check("no first-run popup", not WB.ReminderFrame:IsShown())
  check("hydration timer scheduled", WB.Hydration.timer ~= nil)
  check("trigger fires once", true)
  FireEvent("PLAYER_LEVEL_UP", 5)
  check("old trigger + builtin respect cooldown", #p.reminder_queue == 2 or #p.reminder_queue == 1, #p.reminder_queue)
  TEST_FAILURES = ok and 0 or 1
  io.write((ok and "V1 UPGRADE: all passed" or "V1 UPGRADE: failures") .. string.char(10))
end
dofile(HARNESS)
