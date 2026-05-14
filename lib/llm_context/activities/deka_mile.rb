module LLMContext
  module Activities
    module DekaMile
      SLUG = "deka-mile"
      NAME = "Deka Mile"

      CONTRACT = {
        purity: "Deka Mile race training — running-heavy Deka variant. Treadmill mileage " \
                "is the backbone of every session.",
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
        notes: "MANDATORY: every session includes at least 2 treadmill intervals, and " \
               "runs are usually longer than the 500m Deka Fit zone (800m–mile repeats " \
               "are common). Engine-building blocks on treadmill should appear regularly " \
               "(400m repeats, mile repeats, 4min hard efforts). The race stations remain " \
               "the headline functional movements, but workouts cannot be ONLY runs and " \
               "stations — every session also needs supplementary work. " \
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
               "An abs finisher (sit-ups, leg raises, planks, V-ups, Russian twists) is a " \
               "good optional close-out."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run blocks:        Treadmill 400m–mile repeats, 4min hard efforts, tempo runs
        Stations:          RAM Reverse Lunges, Row, Box Jump, SkiErg, Farmer's Carry, Air Bike,
                           Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
        Supplementary:     KB Swings, KB Thrusters, KB High Pull, Wall Balls, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press (feature in most sessions alongside race stations)
        Strength accessory: Bench Press, Deadlift, Romanian Deadlift, Sumo Deadlift, Single-Leg Deadlift, Split Squat, Bulgarian Split Squat, B-stance Squat, B-stance Deadlift, Landmine Press, Landmine Row, Push Press, Bent-Over Row, Pull-ups, Chin-ups, Dips, Toes-to-bar (most non-race-simulation sessions — max 1 strength round, never the main work)
        Burpee variations: Box Jump Burpees, Plate Burpees, Wall Ball Burpees, KB Burpees
        Abs finisher:      Sit-ups, Leg Raises, Plank, V-ups, Russian Twists, Hollow Holds
      VOCAB

      EXAMPLES = [
        {
          name: "Mile Repeats",
          goal: "Dial in mile pace with short station breaks between efforts.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Mile Efforts", format: "rounds", rounds: 3, rest_secs: 120,
              exercises: [
                { name: "Run", distance_m: 1600, notes: "steady-hard", equipment: "treadmill" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" }
              ] },
            { name: "Station Finisher", format: "for_time",
              exercises: [
                { name: "Row", distance_m: 500, equipment: "rowing_machine" },
                { name: "Farmer's Carry", distance_m: 100, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Short & Sharp",
          goal: "Mix treadmill 400s with functional stations.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "400 Repeats", format: "rounds", rounds: 6, rest_secs: 60,
              exercises: [ { name: "Run", distance_m: 400, notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Station Block", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "SkiErg", calories: 15, equipment: "ski_erg" },
                { name: "RAM Reverse Lunges", reps: 15 }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Long Race",
          goal: "Alternate long runs with stations for a proper race-pace grind.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Run-Station Alternation", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 1600, equipment: "treadmill" },
                { name: "RAM Reverse Lunges", reps: 30 },
                { name: "Run", distance_m: 800, equipment: "treadmill" },
                { name: "Row", distance_m: 500, equipment: "rowing_machine" },
                { name: "Run", distance_m: 800, equipment: "treadmill" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" },
                { name: "Run", distance_m: 800, equipment: "treadmill" },
                { name: "SkiErg", distance_m: 500, equipment: "ski_erg" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
