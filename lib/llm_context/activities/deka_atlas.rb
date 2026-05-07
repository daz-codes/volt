module LLMContext
  module Activities
    module DekaAtlas
      SLUG = "deka-atlas"
      NAME = "Deka Atlas"

      CONTRACT = {
        purity: "Deka Atlas race training — ten strongman-style weighted stations, no " \
                "running. Barbell and dumbbell work feature alongside classic carries.",
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
               "Single Unders, Atlas Shoulder to Carry. No running. Pair heavy stations " \
               "with machine conditioning to manage fatigue. The race stations remain the " \
               "headline movements, but workouts cannot be ONLY stations — every session " \
               "also needs supplementary work. " \
               "SUPPLEMENTARY MOVEMENTS (most sessions): weave KB Swings, KB Thrusters, " \
               "DB Devil Press, Walking Lunges, or Push-ups into station blocks or as " \
               "their own conditioning piece. These build the strength and conditioning " \
               "base that race stations alone don't cover — sessions with no supplementary " \
               "movement at all are too narrow. An abs finisher (sit-ups, leg raises, " \
               "planks, V-ups, Russian twists) is a good optional close-out."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Barbell:           Thrusters, Bar-Facing Burpees Over Bar
        Dumbbell:          Single Arm DB Ground to Overhead, DB Shoulder to Overhead Press, Bear Crawl
        Carries:           Farmer's Carry, Atlas Shoulder to Carry
        Bodyweight:        Surrender Lunges (weighted), Weighted Sit-ups, Jump Rope Single Unders
        Supplementary:     KB Swings, KB Thrusters, KB High Pull, DB Devil Press, Walking Lunges, Jump Squats, Push-ups, KB/DB Shoulder Press (feature in most sessions alongside race stations)
        Burpee variations: Box Jump Burpees, Plate Burpees, KB Burpees, DB Burpees
        Abs finisher:      Sit-ups, Leg Raises, Plank, V-ups, Russian Twists, Hollow Holds
      VOCAB

      EXAMPLES = [
        {
          name: "Atlas Taste",
          goal: "Touch five Atlas stations at race intensity.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Five-Station Circuit", format: "for_time",
              exercises: [
                { name: "Barbell Thrusters", reps: 20, equipment: "barbell" },
                { name: "Bar-Facing Burpees Over Bar", reps: 20, equipment: "barbell" },
                { name: "Single Arm DB Ground to Overhead", reps: 20, equipment: "dumbbells" },
                { name: "Dumbbell Bear Crawl", distance_m: 40, equipment: "dumbbells" },
                { name: "Jump Rope Single Unders", reps: 100, equipment: "jump_rope" }
              ] },
            { name: "Carry Finisher", format: "rounds", rounds: 3, rest_secs: 60,
              exercises: [ { name: "Farmer's Carry", distance_m: 60, equipment: "kettlebells" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Heavy Hands",
          goal: "Build strength-endurance on the loaded stations.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Barbell EMOM", format: "emom", duration_mins: 15, rest_secs: 0,
              exercises: [
                { name: "Barbell Thrusters", reps: 5, equipment: "barbell" },
                { name: "Bar-Facing Burpees Over Bar", reps: 10, equipment: "barbell" }
              ] },
            { name: "DB Circuit", format: "rounds", rounds: 4, rest_secs: 45,
              exercises: [
                { name: "DB Shoulder to Overhead Press", reps: 10, equipment: "dumbbells" },
                { name: "Dumbbell Bear Crawl", distance_m: 20, equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Ten-Station Simulation",
          goal: "Run the full Atlas race in one hit.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Race Simulation", format: "for_time",
              exercises: [
                { name: "Barbell Thrusters", reps: 20, equipment: "barbell" },
                { name: "Bar-Facing Burpees Over Bar", reps: 20, equipment: "barbell" },
                { name: "Surrender Lunges (weighted)", reps: 20, equipment: "dumbbells" },
                { name: "Single Arm DB Ground to Overhead", reps: 20, equipment: "dumbbells" },
                { name: "Dumbbell Bear Crawl", distance_m: 40, equipment: "dumbbells" },
                { name: "Weighted Sit-ups", reps: 20, equipment: "dumbbells" },
                { name: "Farmer's Carry", distance_m: 60, equipment: "kettlebells" },
                { name: "DB Shoulder to Overhead Press", reps: 20, equipment: "dumbbells" },
                { name: "Jump Rope Single Unders", reps: 100, equipment: "jump_rope" },
                { name: "Atlas Shoulder to Carry", distance_m: 100, equipment: "sled" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
