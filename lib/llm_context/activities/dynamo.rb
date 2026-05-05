module LLMContext
  module Activities
    module Dynamo
      SLUG = "dynamo"
      NAME = "Mega Fit"

      CONTRACT = {
        purity: "BODYWEIGHT ONLY. Dynamo sessions are pure bodyweight HIIT — the intensity " \
                "comes from speed, plyometrics, and volume, not load. Absolutely no dumbbells, " \
                "kettlebells, barbells, cardio machines, or any other equipment.",
        allowed_equipment: %w[],
        banned_equipment:  %w[barbell dumbbells kettlebells pull_up_bar wall_ball sled resistance_bands jump_rope rowing_machine assault_bike ski_erg treadmill],
        banned_exercise_patterns: [
          /\bkettlebell\b/i, /\bdumbbell\b/i, /\bbarbell\b/i,
          /\brow(er|ing)?\b/i, /\bski erg\b/i, /\btreadmill\b/i, /\bassault bike\b/i
        ].freeze,
        allowed_formats:   %w[tabata amrap matrix for_time rounds emom hundred ladder],
        primary_formats:   %w[tabata amrap for_time emom],
        warm_up:           :bodyweight_activation,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "Fast-paced with short rest. Plyometric explosiveness is the point — " \
               "burpees, jumping lunges, squat jumps, high knees, mountain climbers, " \
               "star jumps. Hundreds (100 rep challenges) make excellent finishers. " \
               "Tabatas are the signature format. No equipment in any section."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Plyometric: Burpees, Squat Jumps, Jumping Lunges, Box Jumps (use bodyweight cue), Star Jumps, Tuck Jumps
        Cardio:     High Knees, Mountain Climbers, Jumping Jacks, Skater Hops
        Strength:   Push-ups, Pike Push-ups, Dips, Pistol Squats, Bulgarian Split Squats
        Core:       Sit-ups, V-ups, Plank holds, Leg Raises, Flutter Kicks, Russian Twists
      VOCAB

      EXAMPLES = [
        {
          name: "Four Corners",
          goal: "Push through four tabata rounds and finish with a hundred.",
          duration_mins: 25,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy bodyweight cardio + Dynamic stretches", duration_s: 180, equipment: "bodyweight" } ] },
            { name: "Tabata Blocks", format: "tabata", intensity_style: "conditioning", rounds: 8, rest_secs: 10,
              exercises: [
                { name: "Burpees", duration_s: 20, equipment: "bodyweight" },
                { name: "Mountain Climbers", duration_s: 20, equipment: "bodyweight" },
                { name: "Squat Jumps", duration_s: 20, equipment: "bodyweight" },
                { name: "Push-ups", duration_s: 20, equipment: "bodyweight" }
              ] },
            { name: "The Hundred", format: "hundred", intensity_style: "conditioning",
              exercises: [ { name: "Sit-ups", reps: 100, equipment: "bodyweight" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Matrix HIIT",
          goal: "Cycle through a matrix of bodyweight patterns at high speed.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy bodyweight cardio + Dynamic stretches", duration_s: 180, equipment: "bodyweight" } ] },
            { name: "AMRAP Block", format: "amrap", duration_mins: 12, rest_secs: 15,
              exercises: [
                { name: "Burpees", reps: 10, equipment: "bodyweight" },
                { name: "Jumping Lunges", reps: 20, equipment: "bodyweight" },
                { name: "Push-ups", reps: 10, equipment: "bodyweight" }
              ] },
            { name: "EMOM Finish", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Squat Jumps", reps: 15, equipment: "bodyweight" },
                { name: "Mountain Climbers", reps: 30, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Short Blast",
          goal: "A fast, punchy 20-minute bodyweight hit with no kit.",
          duration_mins: 20,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy bodyweight cardio + Dynamic stretches", duration_s: 180, equipment: "bodyweight" } ] },
            { name: "Rounds", format: "rounds", rest_secs: 30,
              exercises: [
                { name: "Burpees", reps: 10, equipment: "bodyweight" },
                { name: "Jumping Lunges", reps: 20, equipment: "bodyweight" },
                { name: "V-ups", reps: 15, equipment: "bodyweight" }
              ] },
            { name: "Tabata Finisher", format: "tabata", rounds: 8, rest_secs: 10,
              exercises: [ { name: "High Knees", duration_s: 20, equipment: "bodyweight" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
