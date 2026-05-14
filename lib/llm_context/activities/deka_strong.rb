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
          goal: "Short and sharp — your-call EMOM reps then a multi-station circuit, no running.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "The Forge", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Wall Balls", reps: 8, equipment: "wall_ball" },
                { name: "KB Swings", reps: 8, equipment: "kettlebells" }
              ] },
            { name: "Iron Storm", format: "rounds", rounds: 4, rest_secs: 45,
              exercises: [
                { name: "RAM Reverse Lunges", reps: 20 },
                { name: "Box Jump / Step Over", reps: 15, equipment: "bodyweight" },
                { name: "Sled Push / Pull", distance_m: 30, equipment: "sled" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Engine & Iron",
          goal: "30/30 row engine, your-call EMOM cycles, then a heavy strength accessory.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Slow Burn", format: "rounds", intensity_style: "high", rounds: 15, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "The Minotaur", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Thrusters", reps: 6, equipment: "kettlebells" },
                { name: "RAM Weighted Burpees", reps: 5, equipment: "bodyweight" }
              ] },
            { name: "Last Stand", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, equipment: "barbell" },
                { name: "Pull-ups", reps: 5, equipment: "pull_up_bar" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Triple Machine Grind",
          goal: "Compromised-cardio triplet rounds across all three machines, your-call EMOM cycles, then an abs close-out.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Desert Rain", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Row", distance_m: 250, equipment: "rowing_machine" },
                { name: "SkiErg", distance_m: 250, equipment: "ski_erg" },
                { name: "Air Bike", calories: 15, equipment: "assault_bike" }
              ] },
            { name: "Two Left Feet", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Box Step-overs", reps: 6, equipment: "bodyweight" },
                { name: "KB Swings", reps: 8, equipment: "kettlebells" },
                { name: "Med Ball Slams", reps: 8, equipment: "wall_ball" }
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
