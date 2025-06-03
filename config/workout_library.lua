-- workout_library.lua

local function W(name, amount, unit, category)
    return { name = name, amount = amount, unit = unit, category = category }
end

WorkoutLibrary = {
    -- Hydration
    W("Drink Water", 8, "oz", "Hydration"),
    W("Drink Herbal Tea", 1, "cup", "Hydration"),
    W("Drink Electrolyte Water", 8, "oz", "Hydration"),
    W("Refill Water Bottle", 1, "time", "Hydration"),
    W("Lemon Water", 8, "oz", "Hydration"),
    W("Sip Water", 4, "oz", "Hydration"),
    W("Green Tea", 1, "cup", "Hydration"),
    W("Take Water Break", 1, "time", "Hydration"),
    W("Sparkling Water", 8, "oz", "Hydration"),
    W("Room Temp Water", 8, "oz", "Hydration"),

    -- Cardio
    W("March in Place", 30, "seconds", "Cardio"),
    W("Jumping Jacks", 15, "reps", "Cardio"),
    W("High Knees", 30, "seconds", "Cardio"),
    W("Butt Kicks", 30, "seconds", "Cardio"),
    W("Seated Knee Raises", 15, "reps", "Cardio"),
    W("Desk Push-ups", 10, "reps", "Cardio"),
    W("Shadow Boxing", 30, "seconds", "Cardio"),
    W("Arm Circles", 15, "reps", "Cardio"),
    W("Seated Leg Extensions", 15, "reps", "Cardio"),
    W("Seated Calf Raises", 15, "reps", "Cardio"),

    -- Stretching/Mobility
    W("Stand Up & Stretch", 30, "seconds", "Stretching"),
    W("Neck Rolls", 10, "reps", "Stretching"),
    W("Shoulder Rolls", 10, "reps", "Stretching"),
    W("Wrist Circles", 15, "reps", "Stretching"),
    W("Finger/Hand Stretches", 30, "seconds", "Stretching"),
    W("Seated Side Bends", 10, "reps", "Stretching"),
    W("Seated Torso Twists", 10, "reps", "Stretching"),
    W("Seated Knee Hugs", 10, "reps", "Stretching"),
    W("Standing Quad Stretch", 30, "seconds", "Stretching"),
    W("Seated Hamstring Stretch", 30, "seconds", "Stretching"),

    -- Eyes & Breathing
    W("Eye Relaxation (20-20-20 Rule)", 20, "seconds", "Eyes & Breathing"),
    W("Deep Breaths", 10, "reps", "Eyes & Breathing"),
    W("Palming (Cover Eyes)", 30, "seconds", "Eyes & Breathing"),
    W("Focus on Distant Object", 20, "seconds", "Eyes & Breathing"),
    W("Close Eyes & Rest", 20, "seconds", "Eyes & Breathing"),
    W("Eye Circles", 10, "reps", "Eyes & Breathing"),
    W("Nostril Breathing", 10, "reps", "Eyes & Breathing"),
    W("Blink Rapidly", 10, "reps", "Eyes & Breathing"),
    W("Slow Exhale", 10, "reps", "Eyes & Breathing"),
    W("Progressive Muscle Relax", 30, "seconds", "Eyes & Breathing"),

    -- Posture & Misc
    W("Posture Check", 1, "time", "Posture"),
    W("Ergonomic Check", 1, "time", "Posture"),
    W("Foot Circles", 10, "reps", "Posture"),
    W("Ankle Circles", 10, "reps", "Posture"),
    W("Seated Back Extension", 10, "reps", "Posture"),
    W("Stand and Sit", 10, "reps", "Posture"),
    W("Chair Adjustment", 1, "time", "Posture"),
    W("Desk Cleanup", 1, "time", "Posture"),
    W("Shoulder Blade Squeeze", 10, "reps", "Posture"),
    W("Wall Angels", 10, "reps", "Posture"),

    -- Strength
    W("Chair Squats", 10, "reps", "Strength"),
    W("Seated Calf Raises", 15, "reps", "Strength"),
    W("Desk Push-ups", 10, "reps", "Strength"),
    W("Wall Push-ups", 12, "reps", "Strength"),
    W("Standing Lunges", 10, "reps", "Strength"),
    W("Standing Calf Raises", 15, "reps", "Strength"),
    W("Isometric Glute Squeeze", 15, "seconds", "Strength"),
    W("Seated Ab Squeeze", 15, "seconds", "Strength"),
    W("Single Leg Stand (per leg)", 20, "seconds", "Strength"),
    W("Desk Tricep Dips", 10, "reps", "Strength"),
    W("Book Shoulder Press", 10, "reps", "Strength"),
}

return WorkoutLibrary
