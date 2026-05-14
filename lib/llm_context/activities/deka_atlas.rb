module LLMContext
  module Activities
    module DekaAtlas
      SLUG = "deka-atlas"
      NAME = "Deka Atlas"

      CONTRACT = {
        purity: "Deka Atlas race training — ten strongman-style weighted stations, no " \
                "running. Barbell and dumbbell work feature alongside classic carries.",
        hybrid_family: true,
        allowed_equipment: %w[barbell dumbbells kettlebells sled jump_rope rowing_machine ski_erg assault_bike],
        banned_equipment:  %w[treadmill wall_ball pull_up_bar resistance_bands],
        banned_exercise_patterns: [
          /\btreadmill\b/i, /\brun(ning)?\b/i
        ].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred matrix mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "Stations: Barbell Thrusters, Bar-Facing Burpees Over Bar, Surrender " \
               "Lunges (weighted), Single Arm DB Ground to Overhead, Dumbbell Bear Crawl, " \
               "Weighted Sit-ups, Farmer's Carry, DB Shoulder to Overhead Press, Jump Rope " \
               "Single Unders, Atlas Shoulder to Carry. No running. Jump rope (Single/Double " \
               "Unders) is the race-relevant cardio modality — machines exist for warm-up " \
               "and engine work but the race-station cardio is jump rope. Pair heavy " \
               "stations with machine conditioning to manage fatigue. The race stations " \
               "remain the headline movements, but workouts cannot be ONLY stations — every " \
               "session also needs supplementary work."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Barbell:           Thrusters, Bar-Facing Burpees Over Bar
        Dumbbell:          Single Arm DB Ground to Overhead, DB Shoulder to Overhead Press, Bear Crawl
        Carries:           Farmer's Carry, Atlas Shoulder to Carry
        Bodyweight:        Surrender Lunges (weighted), Weighted Sit-ups, Jump Rope Single Unders
      VOCAB

      EXAMPLES = [
        {
          name: "Atlas Awakens",
          goal: "DB station EMOM into jump-rope 30/30 — short, sharp, no machines on the main work.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Strongman Hour", format: "emom", duration_mins: 12, rest_secs: 0,
              exercises: [
                { name: "Dumbbell Bear Crawl", distance_m: 10, equipment: "dumbbells" },
                { name: "DB Shoulder to Overhead Press", reps: 6, equipment: "dumbbells" },
                { name: "Weighted Sit-ups", reps: 8, equipment: "dumbbells" }
              ] },
            { name: "Skip & Smash", format: "rounds", intensity_style: "high", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 30, notes: "hard pace", equipment: "jump_rope" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Heavy Metal",
          goal: "Barbell EMOM, then a jump-rope 30/30 engine block, finished with Atlas carries.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "The Yoke", format: "emom", duration_mins: 12, rest_secs: 0,
              exercises: [
                { name: "Barbell Thrusters", reps: 5, equipment: "barbell" },
                { name: "Bar-Facing Burpees Over Bar", reps: 4, equipment: "barbell" }
              ] },
            { name: "Iron Will", format: "rounds", intensity_style: "high", rounds: 20, rest_secs: 30,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 30, notes: "hard pace", equipment: "jump_rope" }
              ] },
            { name: "Carry the Weight", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Atlas Shoulder to Carry", distance_m: 50, equipment: "sled" },
                { name: "Farmer's Carry", distance_m: 50, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Power Hour",
          goal: "Compromised jump-rope/carry/DB triplets, a barbell EMOM, and an abs close-out.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "The Boulder", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 60, equipment: "jump_rope" },
                { name: "Atlas Shoulder to Carry", distance_m: 50, equipment: "sled" },
                { name: "DB Devil Press", reps: 12, equipment: "dumbbells" }
              ] },
            { name: "Stone Cold", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Barbell Thrusters", reps: 5, equipment: "barbell" },
                { name: "Bar-Facing Burpees Over Bar", reps: 4, equipment: "barbell" }
              ] },
            { name: "Atlas Hold", format: "emom", duration_mins: 6, rest_secs: 0,
              exercises: [
                { name: "Weighted Sit-ups", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
