-- config/workout_library.lua
-- Ready-made desk-friendly exercises players can add with one click.

local _, WorkoutBuddy = ...

local function W(name, amount, unit, category)
    return { name = name, amount = amount, unit = unit, category = category }
end

WorkoutBuddy.WorkoutLibrary = {
    -- Cardio
    W("Run in Place", 30, "seconds", "Cardio"),
    W("Jumping Jacks", 15, "reps", "Cardio"),
    W("High Knees", 30, "seconds", "Cardio"),
    W("Butt Kicks", 30, "seconds", "Cardio"),
    W("March in Place", 60, "seconds", "Cardio"),
    W("Step Touches", 30, "seconds", "Cardio"),
    W("Shadow Boxing", 30, "seconds", "Cardio"),
    W("Seated Knee Raises", 15, "reps", "Cardio"),
    W("Walk Around the Room", 2, "minutes", "Cardio"),
    W("Take the Stairs", 1, "flight", "Cardio"),

    -- Stretching and mobility
    W("Stand Up & Stretch", 30, "seconds", "Stretching"),
    W("Neck Rolls", 10, "reps", "Stretching"),
    W("Shoulder Rolls", 10, "reps", "Stretching"),
    W("Arm Circles", 15, "reps", "Stretching"),
    W("Wrist Circles", 15, "reps", "Stretching"),
    W("Finger and Hand Stretches", 30, "seconds", "Stretching"),
    W("Seated Side Bends", 10, "reps", "Stretching"),
    W("Seated Torso Twists", 10, "reps", "Stretching"),
    W("Seated Knee Hugs", 10, "reps", "Stretching"),
    W("Standing Quad Stretch", 30, "seconds", "Stretching"),
    W("Seated Hamstring Stretch", 30, "seconds", "Stretching"),
    W("Chest Opener", 30, "seconds", "Stretching"),
    W("Hip Flexor Stretch", 30, "seconds", "Stretching"),

    -- Eyes and breathing
    W("20-20-20 Eye Break", 20, "seconds", "Eyes & Breathing"),
    W("Deep Breaths", 10, "reps", "Eyes & Breathing"),
    W("Box Breathing", 4, "rounds", "Eyes & Breathing"),
    W("Palming (Cover Eyes)", 30, "seconds", "Eyes & Breathing"),
    W("Close Eyes & Rest", 20, "seconds", "Eyes & Breathing"),
    W("Eye Circles", 10, "reps", "Eyes & Breathing"),
    W("Blink Slowly", 10, "reps", "Eyes & Breathing"),
    W("Progressive Muscle Relaxation", 60, "seconds", "Eyes & Breathing"),

    -- Posture
    W("Posture Check", 1, "check", "Posture"),
    W("Chair and Screen Check", 1, "check", "Posture"),
    W("Chin Tucks", 10, "reps", "Posture"),
    W("Shoulder Blade Squeeze", 10, "reps", "Posture"),
    W("Wall Angels", 10, "reps", "Posture"),
    W("Seated Back Extension", 10, "reps", "Posture"),
    W("Foot and Ankle Circles", 10, "reps", "Posture"),
    W("Stand and Sit", 10, "reps", "Posture"),

    -- Strength
    W("Push-ups", 10, "reps", "Strength"),
    W("Desk Push-ups", 10, "reps", "Strength"),
    W("Wall Push-ups", 12, "reps", "Strength"),
    W("Chair Squats", 10, "reps", "Strength"),
    W("Standing Lunges", 10, "reps", "Strength"),
    W("Standing Calf Raises", 15, "reps", "Strength"),
    W("Glute Bridges", 12, "reps", "Strength"),
    W("Plank", 30, "seconds", "Strength"),
    W("Wall Sit", 30, "seconds", "Strength"),
    W("Desk Tricep Dips", 10, "reps", "Strength"),
    W("Seated Ab Squeeze", 15, "seconds", "Strength"),
    W("Single Leg Stand (each leg)", 20, "seconds", "Strength"),

    -- Healthy habits
    W("Drink a Glass of Water", 1, "glass", "Healthy Habits"),
    W("Healthy Snack Check", 1, "check", "Healthy Habits"),
    W("Step Outside for Fresh Air", 1, "minute", "Healthy Habits"),
    W("Tidy Your Desk", 1, "minute", "Healthy Habits"),
}

function WorkoutBuddy.GetLibraryCategories()
    local cats, seen = {}, {}
    for _, w in ipairs(WorkoutBuddy.WorkoutLibrary) do
        if not seen[w.category] then
            seen[w.category] = true
            cats[#cats + 1] = w.category
        end
    end
    table.sort(cats)
    return cats
end
