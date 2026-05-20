module LLMContext
  module Activities
    module Deka
      SLUG = "deka"
      NAME = "Deka"

      CONTRACT = {
        purity: "Deka race training — 10-zone event covering all Deka variants generically. " \
                "Five run zones alternate with five functional zones.",
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
               "(500m–1km each). Stations: RAM Reverse Lunges, Row, Box Jump, Med Ball " \
               "Sit-up Throw, SkiErg, Farmer's Carry, Air Bike, Dead Ball Yoke Over, " \
               "Sled Push/Pull, RAM Weighted Burpees. When race_simulation? is true the " \
               "builder sets finisher: :required. The race stations remain the headline " \
               "movements, but workouts cannot be ONLY stations — every session also needs " \
               "supplementary work."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run zones:         Treadmill 500m
        Functional:        RAM Reverse Lunges, Row 500m, Box Jump, Med Ball Sit-up Throw, SkiErg 500m,
                           Farmer's Carry, Air Bike 25 cal, Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
      VOCAB

      # Canonical race-station exercises. Used by the validator to scope
      # race-relative wording ("race weight", "competition load") to actual
      # race movements — strength accessories like Deadlift get absolute
      # phrasing instead. Loose substring match, case-insensitive.
      RACE_STATIONS = [
        "Treadmill", "Run",
        "RAM Reverse Lunges", "Row", "Box Jump", "Med Ball Sit-up Throw",
        "SkiErg", "Farmer's Carry", "Air Bike", "Dead Ball Yoke Over",
        "Sled Push", "Sled Pull", "RAM Weighted Burpees"
      ].freeze

      EXAMPLES = [
        {
          name: "Race Taste",
          goal: "Single-exercise thruster EMOM then a 30/30 row engine to finish.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Thruster Hour", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Thrusters", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" }
              ] },
            { name: "Row Sprint", format: "rounds", rounds: 16, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Zone Mix",
          goal: "Compromised running, dual-machine 30/30 engine, a continuous circuit on row, RAM lunges and slams, then a heavy bench accessory.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Last Mile", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "RAM Reverse Lunges", reps: 20 },
                { name: "Sled Push", distance_m: 30, equipment: "sled" }
              ] },
            { name: "Row Sprint", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "Ski Sprint", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Three Engines", format: "continuous_circuit", duration_mins: 12,
              exercises: [
                { name: "Rowing Machine", equipment: "rowing_machine" },
                { name: "RAM Reverse Lunges", equipment: "bodyweight" },
                { name: "Med Ball Slams", equipment: "wall_ball" }
              ] },
            { name: "Iron Press", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Bench Press", reps: 5, notes: "heavy strength load — last rep should be a fight", equipment: "barbell" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Full Race",
          goal: "Full 10-zone Deka simulation in one hit.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
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
        },
        {
          name: "Stations Stacked",
          goal: "Compromised running, an alternating EMOM on Deka stations, and a tabata burner to close.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Race Repeats", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 20, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 30, equipment: "kettlebells" }
              ] },
            { name: "Box Cycle", format: "emom", duration_mins: 16, rest_secs: 0, alternating: true,
              exercises: [
                { name: "Box Jump / Step Over", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" },
                { name: "RAM Reverse Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)" }
              ] },
            { name: "Burpee Bash", format: "tabata",
              exercises: [
                { name: "RAM Weighted Burpees", equipment: "bodyweight" },
                { name: "Sit-ups", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Carry Day",
          goal: "30/30 engine, a heavy carry-and-sled triplet, a single-exercise lunge grind, and a hundred Med Ball Sit-up Throws to finish.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Engine Build", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Three Carries", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Farmer's Carry", distance_m: 60, equipment: "kettlebells" },
                { name: "Sled Push", distance_m: 40, notes: "race weight — full competition sled", equipment: "sled" },
                { name: "Sled Pull", distance_m: 20, notes: "race weight — full competition sled", equipment: "sled" }
              ] },
            { name: "The Lunge", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "RAM Reverse Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)" }
              ] },
            { name: "Century Throw", format: "hundred",
              exercises: [
                { name: "Med Ball Sit-up Throw", reps: 100, equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Zone Descent",
          goal: "One long run-broken descending pyramid — 1km runs interleaved with Med Ball Sit-up Throw, Sled Push and RAM Reverse Lunges, four tiers down.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Down the Zones", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 80, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 80, notes: "race weight — full competition sled across all tiers", equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 80 },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 60, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 60, equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 60 },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 40, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 40, notes: "race weight — full competition sled", equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 40 },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 20, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 20, equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 20 }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Engine Build",
          goal: "A long continuous zone 2 treadmill run, a hip mobility flow, light Deka technique stations, then a quiet cool-down — mobility woven into the main session.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy ski + Deka mobility prep", duration_s: 300, notes: "90/90 hip switches, ankle circles, thoracic open books, world's greatest stretch", equipment: "ski_erg" }
              ] },
            { name: "Long Run", format: "straight", duration_mins: 25,
              exercises: [
                { name: "Run", duration_s: 1500, notes: "conversational pace — nose-breathing where possible, building aerobic engine", equipment: "treadmill" }
              ] },
            { name: "Hip Mobility", format: "straight", duration_mins: 5,
              exercises: [
                { name: "90/90 Hip Switches", duration_s: 120, notes: "60s per side, smooth controlled transitions" },
                { name: "Couch Stretch", duration_s: 120, notes: "60s per side, square hips, breath stays calm" },
                { name: "Hip CARs", duration_s: 60, notes: "both legs, full controlled range of motion" }
              ] },
            { name: "Technique Stations", format: "rounds", rounds: 3, rest_secs: 20,
              exercises: [
                { name: "RAM Reverse Lunges", reps: 20, notes: "deliberate, controlled descent, focus on knee tracking" },
                { name: "Med Ball Sit-up Throw", reps: 20, notes: "light ball — well below race weight, smooth throw mechanics, full sit-up", equipment: "wall_ball" },
                { name: "Box Jump / Step Over", reps: 15, notes: "soft landings, full hip extension at the top", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Aerobic Zones",
          goal: "A steady row, an easy circuit with mobility woven into each round, slow goblet squats, then a quiet cool-down.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy row + Deka mobility prep", duration_s: 300, notes: "cat-cow, ankle circles, dynamic lunges", equipment: "rowing_machine" }
              ] },
            { name: "Steady State Row", format: "straight", duration_mins: 25,
              exercises: [
                { name: "Row", duration_s: 1500, notes: "easy aerobic pace — sustain the same effort the whole way, breath stays calm", equipment: "rowing_machine" }
              ] },
            { name: "Easy Circuit", format: "rounds", rounds: 4, rest_secs: 30,
              exercises: [
                { name: "RAM Reverse Lunges", reps: 20, notes: "deliberate steps, focus on knee tracking" },
                { name: "Foam Roller Thoracic Extensions", duration_s: 60, notes: "slow controlled extensions over a foam roller" },
                { name: "Walking Lunges", reps: 20, notes: "controlled tempo, full range", equipment: "bodyweight" }
              ] },
            { name: "Slow Press", format: "rounds", rounds: 4, rest_secs: 30,
              exercises: [
                { name: "Goblet Squat", reps: 12, notes: "light bell — well below race weight, 3-second eccentric, focus on form and depth", equipment: "kettlebells" },
                { name: "Wall Slides", duration_s: 60, notes: "shoulder and T-spine mobility — slow controlled overhead reach" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Zone Battle",
          goal: "Heavy deadlift triples, all-out 200m sprint repeats, heavy sled work, then a tabata finisher. Full recovery between every set.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Heavy Pull", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Deadlift", reps: 3, notes: "near-max strength load — last rep should be a fight", equipment: "barbell" }
              ] },
            { name: "Sprint Repeats", format: "rounds", rounds: 8, rest_secs: 90,
              exercises: [
                { name: "Run", distance_m: 200, notes: "all-out — every rep is maximum effort", equipment: "treadmill" }
              ] },
            { name: "Heavy Sled", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Sled Push", distance_m: 20, notes: "heavier than race weight — above competition load, drive 20m without breaking", equipment: "sled" }
              ] },
            { name: "Tabata Cooker", format: "tabata",
              exercises: [
                { name: "RAM Weighted Burpees", equipment: "bodyweight" },
                { name: "Sit-ups", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Iron Day",
          goal: "Heavy push press, ski sprint repeats, all-out sled sprints, then a tabata burner. Short, sharp, full-recovery work.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Heavy Press", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Push Press", reps: 3, notes: "near-max strength load — full recovery between sets", equipment: "barbell" }
              ] },
            { name: "Ski Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "all-out — every 30s is maximum, full recovery between", equipment: "ski_erg" }
              ] },
            { name: "Sled Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "Sled Push", distance_m: 15, notes: "heavier than race weight — sprint with the sled, heavy but fast", equipment: "sled" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "Med Ball Slams", equipment: "wall_ball" },
                { name: "KB Swings", equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
