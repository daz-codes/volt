module LLMContext
  module Activities
    module Hyrox
      SLUG = "hyrox"
      NAME = "Hyrox"

      CONTRACT = {
        purity: "Hyrox race training — 1 km runs between 8 functional stations. " \
                "Treadmill running is the backbone of every session. Assault Bike is NOT " \
                "a Hyrox machine and must never appear.",
        allowed_equipment: %w[treadmill rowing_machine ski_erg sled wall_ball kettlebells barbell dumbbells pull_up_bar],
        banned_equipment:  %w[resistance_bands jump_rope assault_bike],
        banned_exercise_patterns: [
          /\bassault bike\b/i, /\bair bike\b/i, /\becho bike\b/i
        ].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "MANDATORY: every session must include at least 2 treadmill running " \
               "intervals (500m–1km each) placed between station blocks. Stations " \
               "mirror the race: SkiErg, Sled Push/Pull, Burpee Broad Jumps, Rowing, " \
               "Farmer's Carry, Sandbag Lunges, Wall Balls. Every section must be " \
               "meaningfully different — do not create two sections with the same " \
               "exercises and structure but different names. The race stations remain " \
               "the headline movements, but workouts cannot be ONLY stations — every " \
               "session also needs supplementary work. " \
               "SUPPLEMENTARY MOVEMENTS (most sessions): weave KB Swings, Med Ball Slams, " \
               "KB Thrusters, Walking Lunges, Push-ups, or burpee variations into station " \
               "blocks or as their own conditioning piece. These build the strength and " \
               "engine that race stations alone don't cover — sessions with no supplementary " \
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
               "good optional close-out before the cool-down."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Running:           Treadmill 500m, 1km, 400m repeats
        Stations:          SkiErg, Sled Push, Sled Pull, Rowing Machine, Farmer's Carry, Wall Ball, Sandbag Lunges
        Bodyweight:        Burpee Broad Jumps
        Supplementary:     KB Swings, KB Thrusters, KB High Pull, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press (feature in most sessions alongside race stations)
        Strength accessory: Bench Press, Deadlift, Romanian Deadlift, Sumo Deadlift, Single-Leg Deadlift, Split Squat, Bulgarian Split Squat, B-stance Squat, B-stance Deadlift, Landmine Press, Landmine Row, Push Press, Bent-Over Row, Pull-ups, Chin-ups, Dips, Toes-to-bar (most non-race-simulation sessions — max 1 strength round, never the main work)
        Burpee variations: Box Jump Burpees, Wall Ball Burpees, KB Burpees (in addition to the standard Burpee Broad Jumps)
        Abs finisher:      Sit-ups, Leg Raises, Plank, V-ups, Russian Twists, Hollow Holds
      VOCAB

      EXAMPLES = [
        {
          name: "Half Race",
          goal: "Heavy press-and-pull, run-station repeats, and a 1km closer at race pace.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Push Press", reps: 5, equipment: "barbell" },
                { name: "Bent-Over Row", reps: 5, equipment: "barbell" }
              ] },
            { name: "Last Mile", format: "rounds", rounds: 4, rest_secs: 30,
              exercises: [
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "SkiErg", distance_m: 250, equipment: "ski_erg" },
                { name: "Med Ball Slams", reps: 20, equipment: "wall_ball" }
              ] },
            { name: "Run to Victory", format: "for_time",
              exercises: [ { name: "Run", distance_m: 1000, equipment: "treadmill" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Station Sprint",
          goal: "Keep the legs turning over between runs and stations.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "ski_erg" } ] },
            { name: "Lung Buster", format: "rounds", rest_secs: 45,
              exercises: [ { name: "Run", distance_m: 500, equipment: "treadmill" } ] },
            { name: "Cooked", format: "for_time",
              exercises: [
                { name: "Sled Push", distance_m: 20, equipment: "sled" },
                { name: "Farmer's Carry", distance_m: 40, equipment: "kettlebells" },
                { name: "KB Swings", reps: 30, equipment: "kettlebells" },
                { name: "Wall Balls", reps: 30, equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Engine & Stations",
          goal: "Build the engine with runs, heavy lifting, and supplementary station work.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Engine Builder", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [ { name: "Run", distance_m: 400, notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, equipment: "barbell" },
                { name: "Pull-ups", reps: 5, equipment: "pull_up_bar" }
              ] },
            { name: "Heavy Hands", format: "rounds", rounds: 4, rest_secs: 90,
              exercises: [
                { name: "SkiErg", distance_m: 250, equipment: "ski_erg" },
                { name: "Sandbag Lunges", distance_m: 20, equipment: "sled" },
                { name: "KB Swings", reps: 20, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
