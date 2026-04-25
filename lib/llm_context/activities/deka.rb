module LLMContext
  module Activities
    module Deka
      SLUG = "deka"
      NAME = "Deka"

      CONTRACT = {
        purity: "Deka race training — 10-zone event covering all Deka variants generically. " \
                "Five run zones alternate with five functional zones.",
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike wall_ball sled kettlebells],
        banned_equipment:  %w[barbell dumbbells pull_up_bar resistance_bands jump_rope],
        banned_exercise_patterns: [
          /\bbarbell\b/i, /\bdumbbell\b/i
        ].freeze,
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
               "builder sets finisher: :required. The race stations remain the primary " \
               "movements; supplementary exercises (see vocabulary) can appear occasionally " \
               "for variety but stations should still dominate. An abs finisher (sit-ups, " \
               "leg raises, planks, V-ups, Russian twists) is a good optional close-out."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run zones:         Treadmill 500m
        Functional:        RAM Reverse Lunges, Row 500m, Box Jump, Med Ball Sit-up Throw, SkiErg 500m,
                           Farmer's Carry, Air Bike 25 cal, Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
        Supplementary:     KB Swings, KB Thrusters, KB High Pull, Wall Balls, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press (use sparingly — stations remain primary)
        Burpee variations: Box Jump Burpees, Plate Burpees, Wall Ball Burpees, KB Burpees
        Abs finisher:      Sit-ups, Leg Raises, Plank, V-ups, Russian Twists, Hollow Holds
      VOCAB

      EXAMPLES = [
        {
          name: "Race Taste",
          goal: "One clean pass of the run-to-station shape.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Run-Station Repeats", format: "rounds", rounds: 4, rest_secs: 30,
              exercises: [
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "SkiErg", reps: "500m", equipment: "ski_erg" }
              ] },
            { name: "Station Finisher", format: "for_time",
              exercises: [
                { name: "Farmer's Carry", reps: "100m", equipment: "kettlebells" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Zone Mix",
          goal: "Build the engine with a mix of run repeats and station blocks.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Run Repeats", format: "rounds", rounds: 5, rest_secs: 45,
              exercises: [ { name: "Run", reps: "400m", notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Station Circuit", format: "emom", duration_mins: 15, rest_secs: 0,
              exercises: [
                { name: "Row", reps: "15 cal", equipment: "rowing_machine" },
                { name: "Air Bike", reps: "15 cal", equipment: "assault_bike" },
                { name: "RAM Reverse Lunges", reps: 15 }
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
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "RAM Reverse Lunges", reps: 30 },
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "Row", reps: "500m", equipment: "rowing_machine" },
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" },
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 25 },
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "SkiErg", reps: "500m", equipment: "ski_erg" },
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "Farmer's Carry", reps: "100m", equipment: "kettlebells" },
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "Air Bike", reps: "25 cal", equipment: "assault_bike" },
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "Dead Ball Yoke Over", reps: 20 },
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "Sled Push / Pull", reps: "100m", equipment: "sled" },
                { name: "Run", reps: "500m", equipment: "treadmill" },
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
