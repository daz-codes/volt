module LLMContext
  module Activities
    module DekaStrong
      SLUG = "deka-strong"
      NAME = "Deka Strong"

      CONTRACT = {
        purity: "Deka Strong training — no running. Strength-endurance and station capacity " \
                "via the 10 weighted functional zones. Most sessions use 4-6 stations with " \
                "supplementary movement work; full 10-zone sessions are valid but uncommon.",
        hybrid_family: true,
        allowed_equipment: %w[rowing_machine ski_erg assault_bike wall_ball sled kettlebells barbell dumbbells pull_up_bar],
        banned_equipment:  %w[treadmill resistance_bands jump_rope],
        banned_exercise_patterns: [
          /\btreadmill\b/i, /\brun(ning)?\b/i
        ].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred matrix mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "No running. Build anaerobic capacity on ski erg, assault bike, or rower " \
               "instead — 30s hard/30s easy or 400m repeats. Stations: RAM Reverse Lunges, " \
               "Row, Box Jump, Med Ball Sit-up Throw, SkiErg, Farmer's Carry, Air Bike, " \
               "Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees. **Most sessions " \
               "use 4-6 stations** with supplementary movement work; full 10-zone sessions " \
               "are valid but uncommon — roughly 1 in 5 workouts."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Stations:          RAM Reverse Lunges, Row 500m, Box Jump, Med Ball Sit-up Throw, SkiErg 500m,
                           Farmer's Carry, Air Bike 25 cal, Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
        Engine:            Ski Erg 500m repeats, Rower 500m repeats, Assault Bike 30s/30s
      VOCAB

      EXAMPLES = [
        {
          name: "Station Capacity",
          goal: "Single-exercise KB swing EMOM then a 30/30 row engine to finish.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "The Forge", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Swings", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" }
              ] },
            { name: "Row Sprint", format: "rounds", rounds: 12, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Engine & Iron",
          goal: "Triple-machine 30/30 engine block, a thruster EMOM, then a heavy deadlift accessory.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Row Sprint", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "Ski Sprint", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Bike Sprint", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Air Bike", duration_s: 30, notes: "hard pace", equipment: "assault_bike" }
              ] },
            { name: "The Minotaur", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Thrusters", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" }
              ] },
            { name: "Last Stand", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, equipment: "barbell" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Triple Machine Grind",
          goal: "Compromised cardio rounds, a med-ball sit-up throw EMOM grind, a rotating continuous circuit on row, KB swings and box step-overs, then a hundred to close.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Desert Rain", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Row", distance_m: 250, equipment: "rowing_machine" },
                { name: "RAM Reverse Lunges", reps: 20 },
                { name: "SkiErg", distance_m: 250, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 30, equipment: "sled" }
              ] },
            { name: "Throw Down", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "Med Ball Sit-up Throw", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" }
              ] },
            { name: "Strong Rotation", format: "continuous_circuit", duration_mins: 12,
              exercises: [
                { name: "Rowing Machine", equipment: "rowing_machine" },
                { name: "KB Swings", equipment: "kettlebells" },
                { name: "Box Step-overs", equipment: "bodyweight" }
              ] },
            { name: "The Centurion", format: "hundred",
              exercises: [
                { name: "KB Swings", reps: 100, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
