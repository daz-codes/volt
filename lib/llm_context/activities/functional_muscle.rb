module LLMContext
  module Activities
    module FunctionalMuscle
      SLUG = "functional-muscle"
      NAME = "Functional Muscle"

      CONTRACT = {
        purity: "Functional Muscle — a fixed class format with its own warm-up, metabolic " \
                "blocks, upper and lower strength, abs 100, and cool-down in a strict order. " \
                "This is not a freeform session.",
        allowed_equipment: %w[barbell dumbbells kettlebells pull_up_bar wall_ball jump_rope rowing_machine assault_bike ski_erg],
        banned_equipment:  %w[treadmill sled resistance_bands],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[straight rounds emom tabata hundred ladder mountain amrap for_time matrix],
        primary_formats:   %w[rounds emom tabata hundred],
        signature_formats: %w[tabata hundred mountain switchback],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :required,
        core:              :required,
        notes: "FIXED SESSION ORDER: (1) 5-min easy cardio warm-up on a single machine, (2) " \
               "metabolic blocks chosen from continuous circuit / interval circuit / 10-1 " \
               "ladder / cardio intervals / every-2-min EMOM / TWENTY20 / death race / " \
               "up-down switchback ladder / tabata / Bear Mountain, (3) Upper Body Strength " \
               "(rounds: 5, rest 60s, reps 10, ONE exercise), (4) Lower Body Strength (same " \
               "shape), (5) Abs/Pilates 100 (hundred or straight-list or rounds; 100 reps " \
               "total), (6) cool-down stretches. Section names must be creative (never " \
               '"Block 1", "Tabata 1"). Tabata exercises must be compounds (two movements ' \
               'fused, name contains "and"/"with"/"to"/"+"). Weights are effort-cued (light/' \
               "moderate/working) so athletes self-select load."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Metabolic:  Continuous circuits (EMOM rotating), Interval circuits (rounds every 2 min),
                    10-1 ladders, Cardio intervals (1 min hard / 1 min rest), TWENTY20,
                    Up & Down switchback ladders, Death Race, Bear Mountain
        Tabatas:    Compound pairs — Squat Curl and Press, KB Swing with Side Lunge,
                    Bent Over Row to Deadlift, Push-up to T-Rotation, Plate Halo and Twist
        Strength:   Low Row, Lat Pulldown, Bench Press, Shoulder Press, Leg Press, Squats, Deadlifts, Lunges
        Abs 100:    Pilates 100, 4–5 abs exercises × 20 reps, single abs × 100
      VOCAB

      EXAMPLES = [
        {
          name: "Classic FM",
          goal: "The core class shape — metabolic, strength, abs, out the door.",
          duration_mins: 45,
          sections: [
            { name: "Easy Row Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy Row", duration_s: 300, notes: "easy pace", equipment: "rowing_machine" } ] },
            { name: "The Grind Loop", format: "emom", duration_mins: 12, rest_secs: 0,
              exercises: [
                { name: "Row", notes: "steady sustainable effort", equipment: "rowing_machine" },
                { name: "KB Swings", notes: "20 reps, light–moderate", equipment: "kettlebells" },
                { name: "Sit-ups", notes: "20 reps", equipment: "bodyweight" }
              ] },
            { name: "The Burner", format: "tabata", rounds: 8, rest_secs: 10,
              exercises: [
                { name: "Squat Curl and Press", duration_s: 20, equipment: "dumbbells" },
                { name: "KB Swing with Side Lunge", duration_s: 20, equipment: "kettlebells" }
              ] },
            { name: "Upper Body Strength", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [ { name: "Bench Press", reps: 10, notes: "working weight", equipment: "barbell" } ] },
            { name: "Lower Body Strength", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [ { name: "Squats", reps: 10, notes: "working weight", equipment: "barbell" } ] },
            { name: "The Hundred", format: "hundred",
              exercises: [ { name: "Plate Serves", reps: 100, notes: "light plate", equipment: "dumbbells" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Ladder Day",
          goal: "A 10-1 ladder sits centre stage between warm-up and abs.",
          duration_mins: 45,
          sections: [
            { name: "Easy Ride Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy Ride", duration_s: 300, notes: "easy pace", equipment: "assault_bike" } ] },
            { name: "Pulse Raiser", format: "tabata", rounds: 8, rest_secs: 10,
              exercises: [
                { name: "Push Up to T-Rotation", duration_s: 20, equipment: "bodyweight" },
                { name: "KB Clean and Press", duration_s: 20, equipment: "kettlebells" }
              ] },
            { name: "Ten-to-One Ladder", format: "ladder",
              varies: "reps", start: 10, end: 1, step: 1, rest_between_rungs: 30,
              exercises: [
                { name: "KB Swings", equipment: "kettlebells" },
                { name: "Wall Balls", equipment: "wall_ball" },
                { name: "Burpees", equipment: "bodyweight" }
              ] },
            { name: "Upper Body Strength", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [ { name: "Shoulder Press", reps: 10, notes: "working weight", equipment: "dumbbells" } ] },
            { name: "Lower Body Strength", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [ { name: "Lunges", reps: 10, notes: "working weight", equipment: "dumbbells" } ] },
            { name: "Core 100", format: "straight",
              exercises: [
                { name: "Sit-ups", reps: 25, equipment: "bodyweight" },
                { name: "Leg Raises", reps: 25, equipment: "bodyweight" },
                { name: "Russian Twists", reps: 25, equipment: "bodyweight" },
                { name: "Plank", duration_s: 60, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Long FM",
          goal: "A 60-min version — TWENTY20 plus Bear Mountain plus the standard close.",
          duration_mins: 60,
          sections: [
            { name: "Easy Ski Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy Ski", duration_s: 300, notes: "easy pace", equipment: "ski_erg" } ] },
            { name: "TWENTY20", format: "rounds", rounds: 5, rest_secs: 0,
              exercises: [
                { name: "Row", reps: "20 cal", notes: "hard sustainable effort", equipment: "rowing_machine" },
                { name: "KB Swings", reps: 20, equipment: "kettlebells" }
              ] },
            { name: "Bear Mountain", format: "mountain",
              varies: "reps", start: 1, peak: 5, end: 1, step: 1, rest_between_rungs: 30,
              exercises: [ { name: "Bear", notes: "moderate barbell — clean → press → front squat → press → back squat = 1 rep", equipment: "barbell" } ] },
            { name: "Upper Body Strength", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [ { name: "Low Row", reps: 10, notes: "working weight", equipment: "dumbbells" } ] },
            { name: "Lower Body Strength", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [ { name: "Deadlifts", reps: 10, notes: "working weight", equipment: "barbell" } ] },
            { name: "Shoulder Burn", format: "hundred",
              exercises: [ { name: "Lateral Raises", reps: 100, notes: "light DB", equipment: "dumbbells" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
