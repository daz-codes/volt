module LLMContext
  module Activities
    module DekaFit
      SLUG = "deka-fit"
      NAME = "Deka Fit"

      CONTRACT = {
        purity: "Deka Fit race training — 10-zone event, 5 run zones alternating with " \
                "5 functional zones. Running is half the race (10 × 500m).",
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
               "supplementary work. " \
               "SUPPLEMENTARY MOVEMENTS (most sessions): weave KB Swings, Med Ball Slams, " \
               "Wall Balls, KB Thrusters, Walking Lunges, or Push-ups into station blocks " \
               "or as their own conditioning piece. These build the strength and engine " \
               "that race stations alone don't cover — sessions with no supplementary " \
               "movement at all are too narrow. Only full race-simulation sessions skip them. " \
               "STRENGTH ACCESSORY (most non-race-simulation sessions): include one strength " \
               "accessory block — rounds format, 3-6 reps heavy at 120s rest with " \
               "intensity_style: max_effort, OR 8-10 reps moderate at 90s rest. Draw from " \
               "the Strength accessory line (Deadlift, Bench Press, Push Press, Bent-Over " \
               "Row, Pull-ups, Bulgarian Split Squat). Never more than one strength block " \
               "per session, never the centrepiece, and never replaces a run or a station. " \
               "An abs finisher (sit-ups, leg raises, planks, V-ups, Russian twists) is a " \
               "good optional close-out."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run zones:         Treadmill 500m
        Functional:        RAM Reverse Lunges, Row 500m, Box Jump / Step Over, Med Ball Sit-up Throw,
                           SkiErg 500m, Farmer's Carry, Air Bike 25 cal, Dead Ball Yoke Over,
                           Sled Push/Pull, RAM Weighted Burpees
        Supplementary:     KB Swings, KB Thrusters, KB High Pull, Wall Balls, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press (feature in most sessions alongside race stations)
        Strength accessory: Bench Press, Deadlift, Romanian Deadlift, Sumo Deadlift, Single-Leg Deadlift, Split Squat, Bulgarian Split Squat, B-stance Squat, B-stance Deadlift, Landmine Press, Landmine Row, Push Press, Bent-Over Row, Pull-ups, Chin-ups, Dips, Toes-to-bar (most non-race-simulation sessions — max 1 strength round, never the main work)
        Burpee variations: Box Jump Burpees, Plate Burpees, Wall Ball Burpees, KB Burpees
        Abs finisher:      Sit-ups, Leg Raises, Plank, V-ups, Russian Twists, Hollow Holds
      VOCAB

      EXAMPLES = [
        {
          name: "Single Rotation",
          goal: "Drill one clean run-to-station transition at race pace.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Run-Station Repeats", format: "rounds", rounds: 4, rest_secs: 30,
              exercises: [
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" }
              ] },
            { name: "Station Finisher", format: "for_time",
              exercises: [
                { name: "Row", reps: "500m", equipment: "rowing_machine" },
                { name: "Farmer's Carry", reps: "100m", equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Half Race",
          goal: "Practise five race zones under accumulated fatigue.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Run & Stations", format: "for_time",
              exercises: [
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "RAM Reverse Lunges", reps: 30 },
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "Row", reps: "500m", equipment: "rowing_machine" },
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" }
              ] },
            { name: "Engine Block", format: "rounds", rounds: 5, rest_secs: 45,
              exercises: [ { name: "Run", reps: "400m", notes: "hard pace", equipment: "treadmill" } ] },
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
