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
               "supplementary work. " \
               "SUPPLEMENTARY MOVEMENTS (most sessions): weave KB Swings, Med Ball Slams, " \
               "Wall Balls, KB Thrusters, Walking Lunges, or Push-ups into station blocks " \
               "or as their own conditioning piece. These build the strength and engine " \
               "that race stations alone don't cover — sessions with no supplementary " \
               "movement at all are too narrow. Only full race-simulation sessions skip them. " \
               "STRENGTH ACCESSORY (most non-race-simulation sessions): include one strength " \
               "accessory block — rounds format, 3-6 reps heavy at 120s rest with " \
               "intensity_style: high, OR 8-10 reps moderate at 90s rest. Draw from " \
               "the Strength accessory line (Deadlift, Bench Press, Push Press, Bent-Over " \
               "Row, Pull-ups, Bulgarian Split Squat). Never more than one strength block " \
               "per session, never the centrepiece, and never replaces a run or a station. " \
               "DURATION INTERVALS: a 3-4 round work-rest block on a single conditioning " \
               "movement (Wall Balls, Burpees, Walking Lunges, KB Swings, Med Ball Slams) " \
               "is a valid alternative to rep-based rounds — use rounds format with " \
               "duration_s: 120 and rest_secs: 120 for the canonical 2-min work / 2-min " \
               "rest shape. The clean-minute rule applies only to cardio machines, not " \
               "to these functional movements. " \
               "An abs finisher (sit-ups, leg raises, planks, V-ups, Russian twists) is a " \
               "good optional close-out."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run zones:         Treadmill 500m
        Functional:        RAM Reverse Lunges, Row 500m, Box Jump, Med Ball Sit-up Throw, SkiErg 500m,
                           Farmer's Carry, Air Bike 25 cal, Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
        Supplementary:     KB Swings, KB Thrusters, KB High Pull, Wall Balls, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press (feature in most sessions alongside race stations)
        Strength accessory: Bench Press, Deadlift, Romanian Deadlift, Sumo Deadlift, Single-Leg Deadlift, Split Squat, Bulgarian Split Squat, B-stance Squat, B-stance Deadlift, Landmine Press, Landmine Row, Push Press, Bent-Over Row, Pull-ups, Chin-ups, Dips, Toes-to-bar (most non-race-simulation sessions — max 1 strength round, never the main work)
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
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "SkiErg", distance_m: 500, equipment: "ski_erg" }
              ] },
            { name: "Station Finisher", format: "for_time",
              exercises: [
                { name: "Farmer's Carry", distance_m: 100, equipment: "kettlebells" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" },
                { name: "KB Swings", reps: 20, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Zone Mix",
          goal: "Run repeats, heavy lifting, and stations laced with supplementary work.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Run Repeats", format: "rounds", rounds: 5, rest_secs: 45,
              exercises: [ { name: "Run", distance_m: 400, notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Bench Press", reps: 5, equipment: "barbell" },
                { name: "Bent-Over Row", reps: 5, equipment: "barbell" }
              ] },
            { name: "Heavy Hands", format: "rounds", rounds: 4, rest_secs: 90,
              exercises: [
                { name: "Row", distance_m: 250, equipment: "rowing_machine" },
                { name: "RAM Reverse Lunges", reps: 20 },
                { name: "Med Ball Slams", reps: 20, equipment: "wall_ball" }
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
        }
      ].freeze
    end
  end
end
