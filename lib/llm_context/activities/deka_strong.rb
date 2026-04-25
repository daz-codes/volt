module LLMContext
  module Activities
    module DekaStrong
      SLUG = "deka-strong"
      NAME = "Deka Strong"

      CONTRACT = {
        purity: "Deka Strong race training — no running. Ten weighted functional zones " \
                "back-to-back, with emphasis on strength-endurance and station capacity.",
        allowed_equipment: %w[rowing_machine ski_erg assault_bike wall_ball sled kettlebells],
        banned_equipment:  %w[treadmill barbell dumbbells pull_up_bar resistance_bands jump_rope],
        banned_exercise_patterns: [
          /\btreadmill\b/i, /\bbarbell\b/i, /\bdumbbell\b/i, /\brun(ning)?\b/i
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
               "Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees. The race stations " \
               "remain the primary movements; supplementary exercises (see vocabulary) can " \
               "appear occasionally for variety but stations should still dominate."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Stations:      RAM Reverse Lunges, Row 500m, Box Jump, Med Ball Sit-up Throw, SkiErg 500m,
                       Farmer's Carry, Air Bike 25 cal, Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
        Engine:        Ski Erg 500m repeats, Rower 500m repeats, Assault Bike 30s/30s
        Supplementary: KB Swings, KB Thrusters, KB High Pull, Wall Balls, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press (use sparingly — stations remain primary)
      VOCAB

      EXAMPLES = [
        {
          name: "Station Capacity",
          goal: "Hit five stations with short transitions — no running, all grit.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "ski_erg" } ] },
            { name: "Five-Station Circuit", format: "for_time",
              exercises: [
                { name: "Row", reps: "500m", equipment: "rowing_machine" },
                { name: "RAM Reverse Lunges", reps: 30 },
                { name: "SkiErg", reps: "500m", equipment: "ski_erg" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" },
                { name: "Air Bike", reps: "25 cal", equipment: "assault_bike" }
              ] },
            { name: "Sled Finisher", format: "rounds", rounds: 4, rest_secs: 45,
              exercises: [ { name: "Sled Push / Pull", reps: "50m", equipment: "sled" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Engine & Stations",
          goal: "Build cardio capacity without a treadmill and finish with heavy stations.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Machine Intervals", format: "rounds", rounds: 8, rest_secs: 30,
              exercises: [
                { name: "Row", reps: "250m", equipment: "rowing_machine" },
                { name: "Assault Bike", reps: "10 cal", equipment: "assault_bike" }
              ] },
            { name: "Station Block", format: "emom", duration_mins: 15, rest_secs: 0,
              exercises: [
                { name: "Farmer's Carry", reps: "40m", equipment: "kettlebells" },
                { name: "Dead Ball Yoke Over", reps: 15 },
                { name: "RAM Weighted Burpees", reps: 10 }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Ten Zones, No Run",
          goal: "Move through all ten Deka Strong zones back-to-back.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Race Simulation", format: "for_time",
              exercises: [
                { name: "RAM Reverse Lunges", reps: 30 },
                { name: "Row", reps: "500m", equipment: "rowing_machine" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" },
                { name: "Med Ball Sit-up Throw", reps: 25 },
                { name: "SkiErg", reps: "500m", equipment: "ski_erg" },
                { name: "Farmer's Carry", reps: "100m", equipment: "kettlebells" },
                { name: "Air Bike", reps: "25 cal", equipment: "assault_bike" },
                { name: "Dead Ball Yoke Over", reps: 20 },
                { name: "Sled Push / Pull", reps: "100m", equipment: "sled" },
                { name: "RAM Weighted Burpees", reps: 20 }
              ] },
            { name: "Engine Finisher", format: "rounds", rounds: 6, rest_secs: 30,
              exercises: [ { name: "Row", reps: "250m", equipment: "rowing_machine" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
