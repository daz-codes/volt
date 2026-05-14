module LLMContext
  module Activities
    module DekaFit
      SLUG = "deka-fit"
      NAME = "Deka Fit"

      CONTRACT = {
        purity: "Deka Fit race training — 10-zone event, 5 run zones alternating with " \
                "5 functional zones. Running is half the race (10 × 500m).",
        hybrid_family: true,
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike wall_ball sled kettlebells barbell dumbbells pull_up_bar],
        banned_equipment:  %w[resistance_bands jump_rope],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred matrix mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "MANDATORY: every session includes at least 2 treadmill running intervals " \
               "(500m–1km each) placed between station blocks. Stations mirror the race: " \
               "RAM Reverse Lunges, Row, Box Jump, Med Ball Sit-up Throw, SkiErg, " \
               "Farmer's Carry, Air Bike, Dead Ball Yoke Over, Sled Push/Pull, Weighted " \
               "Burpees. When race_simulation? is true the builder sets finisher: :required " \
               "and the session covers all ten zones. The race stations remain the headline " \
               "movements, but workouts cannot be ONLY stations — every session also needs " \
               "supplementary work."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run zones:         Treadmill 500m
        Functional:        RAM Reverse Lunges, Row 500m, Box Jump / Step Over, Med Ball Sit-up Throw,
                           SkiErg 500m, Farmer's Carry, Air Bike 25 cal, Dead Ball Yoke Over,
                           Sled Push/Pull, RAM Weighted Burpees
      VOCAB

      EXAMPLES = [
        {
          name: "Wake the Dead",
          goal: "Your-call EMOM reps then 30/30 sprint cardio — short, sharp, high intensity.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "The Anvil", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Wall Balls", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" },
                { name: "Box Step-overs", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Sprint Finish", format: "rounds", intensity_style: "high", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Run", duration_s: 30, notes: "hard pace", equipment: "treadmill" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Death March",
          goal: "Compromised 500m runs alternating with functional zones, then your-call EMOM cycles.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "The Crucible", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "RAM Reverse Lunges", reps: 20 },
                { name: "Med Ball Sit-up Throw", reps: 20, equipment: "wall_ball" }
              ] },
            { name: "No Mercy", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Swings", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" },
                { name: "RAM Weighted Burpees", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Full Race",
          goal: "Simulate the full 10-zone Deka Fit race in one session.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Race Simulation", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "RAM Reverse Lunges", reps: 30 },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Row", distance_m: 500, equipment: "rowing_machine" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 25 },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "SkiErg", distance_m: 500, equipment: "ski_erg" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Farmer's Carry", distance_m: 100, equipment: "kettlebells" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Air Bike", calories: 25, equipment: "assault_bike" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Dead Ball Yoke Over", reps: 20 },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Sled Push / Pull", distance_m: 100, equipment: "sled" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "RAM Weighted Burpees", reps: 20 }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
