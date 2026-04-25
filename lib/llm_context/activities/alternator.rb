module LLMContext
  module Activities
    module Alternator
      SLUG = "alternator"
      NAME = "Pump & Grind"

      CONTRACT = {
        purity: "Alternator sessions alternate DIFFERENT cardio machines with floor " \
                "strength blocks. Each cardio block uses a new machine, and each floor " \
                "block pairs with the previous machine (push/pull balance).",
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike barbell dumbbells kettlebells wall_ball sled pull_up_bar jump_rope resistance_bands],
        banned_equipment:  %w[],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[rounds emom for_time amrap tabata ladder],
        primary_formats:   %w[rounds emom for_time],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "Structure: easy-cardio warm-up → alternating cardio/floor blocks → stretch " \
               "cool-down. Cardio blocks rotate machines (never the same machine twice in " \
               "a row). Floor blocks pair deliberately with the preceding cardio — after " \
               "ski erg (pull) do a push-focused floor, after rowing do lower body, after " \
               "assault bike do upper body, after treadmill do core or full body. No " \
               "separate activation or abs section. Treadmill-focused variants (formerly " \
               "Tread & Shred) stay within this structure — treadmill is one of the " \
               "rotating machines, not a whole-session dominant."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Cardio:  Row, Ski Erg, Assault Bike, Treadmill
        Push:    DB Bench, DB Shoulder Press, Push-ups
        Pull:    DB Row, Pull-ups, Inverted Row
        Lower:   Goblet Squats, DB Lunges, RDLs, Step-ups
        Full:    Thrusters, Man Makers, Burpees
        Core:    Plank, Sit-ups, Russian Twists, V-ups
      VOCAB

      EXAMPLES = [
        {
          name: "Short Switch",
          goal: "Two cardio machines, two floor blocks, one tight session.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Row Intervals", format: "rounds", rounds: 6, rest_secs: 30,
              exercises: [ { name: "Row", reps: "250m", equipment: "rowing_machine" } ] },
            { name: "Upper Body Floor", format: "rounds", rounds: 3, rest_secs: 45,
              exercises: [
                { name: "DB Bench Press", reps: 10, equipment: "dumbbells" },
                { name: "DB Row each side", reps: 10, equipment: "dumbbells" }
              ] },
            { name: "Assault Bike Sprints", format: "emom", duration_mins: 8, rest_secs: 0,
              exercises: [ { name: "Assault Bike", reps: "10 cal", equipment: "assault_bike" } ] },
            { name: "Core Floor", format: "rounds", rounds: 3, rest_secs: 30,
              exercises: [
                { name: "Plank", duration_s: 45, equipment: "bodyweight" },
                { name: "V-ups", reps: 20, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Three-Machine Alternator",
          goal: "Rotate three machines with balanced floor pairs between them.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Ski Erg Intervals", format: "rounds", rounds: 5, rest_secs: 30,
              exercises: [ { name: "SkiErg", reps: "250m", equipment: "ski_erg" } ] },
            { name: "Push Floor", format: "rounds", rounds: 3, rest_secs: 45,
              exercises: [
                { name: "DB Shoulder Press", reps: 10, equipment: "dumbbells" },
                { name: "Push-ups", reps: 15, equipment: "bodyweight" }
              ] },
            { name: "Row Intervals", format: "rounds", rounds: 5, rest_secs: 30,
              exercises: [ { name: "Row", reps: "250m", equipment: "rowing_machine" } ] },
            { name: "Lower Floor", format: "rounds", rounds: 3, rest_secs: 45,
              exercises: [
                { name: "Goblet Squat", reps: 10, equipment: "kettlebells" },
                { name: "DB RDL", reps: 10, equipment: "dumbbells" }
              ] },
            { name: "Assault Bike Sprints", format: "emom", duration_mins: 8, rest_secs: 0,
              exercises: [ { name: "Assault Bike", reps: "10 cal", equipment: "assault_bike" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Treadmill Focus",
          goal: "A treadmill-led alternator — runs bookend the floor strength work.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Treadmill Intervals", format: "rounds", rounds: 5, rest_secs: 45,
              exercises: [ { name: "Run", reps: "400m", notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Upper Body Floor", format: "rounds", rounds: 3, rest_secs: 45,
              exercises: [
                { name: "DB Bench Press", reps: 10, equipment: "dumbbells" },
                { name: "DB Row each side", reps: 10, equipment: "dumbbells" }
              ] },
            { name: "Treadmill Finisher", format: "for_time",
              exercises: [ { name: "Run", reps: "1km", equipment: "treadmill" } ] },
            { name: "Core Floor", format: "rounds", rounds: 3, rest_secs: 30,
              exercises: [
                { name: "Plank", duration_s: 45, equipment: "bodyweight" },
                { name: "Russian Twists", reps: 30, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
