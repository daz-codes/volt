module LLMContext
  module Activities
    module HybridRace
      SLUG = "hybrid-race"
      NAME = "Hybrid Race"

      CONTRACT = {
        purity: "Hybrid race-prep training — treadmill running intervals alternating with " \
                "weighted functional stations. Builds the engine and station capacity for " \
                "any run-and-stations race format. Each session draws freely from a wide " \
                "library of stations rather than locking into a fixed event shape.",
        hybrid_family: true,
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike sled wall_ball kettlebells barbell dumbbells pull_up_bar],
        banned_equipment:  %w[resistance_bands jump_rope],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred matrix mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "Every session should include at least 2 treadmill running intervals " \
               "(400m–1km each) placed between station blocks. Stations draw from a wide " \
               "library: Sled Push/Pull, SkiErg, Rowing, Air Bike, Farmer's Carry, Wall " \
               "Balls, Sandbag Lunges, RAM Reverse Lunges, Box Jump, Med Ball Sit-up Throw, " \
               "Dead Ball Yoke Over, Burpee Broad Jumps, Weighted Burpees. Mix freely — " \
               "most sessions use 4-6 stations, not all of them."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Running:           Treadmill 400m, 500m, 1km repeats
        Stations:          Sled Push/Pull, SkiErg, Rowing Machine, Air Bike, Farmer's Carry,
                           Wall Balls, Sandbag Lunges, RAM Reverse Lunges, Box Jump,
                           Med Ball Sit-up Throw, Dead Ball Yoke Over, Burpee Broad Jumps,
                           Weighted Burpees
      VOCAB

      EXAMPLES = [
        {
          name: "Sprint & Stations",
          goal: "Short and sharp — your-call EMOM reps then 30/30 cardio to finish.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Hammer Time", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Wall Balls", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" },
                { name: "KB Swings", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" }
              ] },
            { name: "Engine Builder", format: "rounds", intensity_style: "high", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Heavy Hands",
          goal: "Compromised running into your-call EMOM cycles, then a heavy strength accessory.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Last Mile", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "Wall Balls", reps: 30, equipment: "wall_ball" },
                { name: "KB Swings", reps: 30, equipment: "kettlebells" }
              ] },
            { name: "Final Boss", format: "emom", duration_mins: 8, rest_secs: 0,
              exercises: [
                { name: "KB Thrusters", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" },
                { name: "Box Step-overs", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, equipment: "barbell" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Triple Threat",
          goal: "30/30 multi-machine engine, compromised-running circuit, then an abs close-out.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Engine Builder I", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "Engine Builder II", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Engine Builder III", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 30,
              exercises: [
                { name: "Air Bike", duration_s: 30, notes: "hard pace", equipment: "assault_bike" }
              ] },
            { name: "Tip of the Spear", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "Sled Push", distance_m: 15, equipment: "sled" },
                { name: "Sandbag Lunges", distance_m: 20, equipment: "sled" }
              ] },
            { name: "Gut Check", format: "rounds", rounds: 3, rest_secs: 30,
              exercises: [
                { name: "V-ups", reps: 20, equipment: "bodyweight" },
                { name: "Russian Twists", reps: 20, equipment: "bodyweight" },
                { name: "Plank", duration_s: 45, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
