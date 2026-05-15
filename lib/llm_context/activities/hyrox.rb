module LLMContext
  module Activities
    module Hyrox
      SLUG = "hyrox"
      NAME = "Hyrox"

      CONTRACT = {
        purity: "Hyrox race training — 1 km runs between 8 functional stations. " \
                "Treadmill running is the backbone of every session. Assault Bike is NOT " \
                "a Hyrox machine and must never appear.",
        hybrid_family: true,
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
               "session also needs supplementary work."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Running:           Treadmill 500m, 1km, 400m repeats
        Stations:          SkiErg, Sled Push, Sled Pull, Rowing Machine, Farmer's Carry, Wall Ball, Sandbag Lunges
      VOCAB

      EXAMPLES = [
        {
          name: "Mixed Hybrid",
          goal: "Race-pace stations, a 30/30 engine split, a heavy lift, and a single-exercise EMOM grind.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Compromised Stations", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 30, equipment: "kettlebells" }
              ] },
            { name: "Ski Sprint", format: "rounds", rounds: 5, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Row Sprint", format: "rounds", rounds: 5, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, equipment: "barbell" }
              ] },
            { name: "Walking Death", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "Walking Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Gut Check", format: "rounds", rounds: 3, rest_secs: 30,
              exercises: [
                { name: "Sit-ups", reps: 20, equipment: "bodyweight" },
                { name: "V-ups", reps: 20, equipment: "bodyweight" },
                { name: "Plank", duration_s: 45, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Two Engines",
          goal: "Compromised cardio, a long 30/30 treadmill grinder, a rotating continuous circuit, and a hundred to finish.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Cooked", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "SkiErg", distance_m: 500, equipment: "ski_erg" },
                { name: "Walking Lunges", reps: 20, equipment: "bodyweight" },
                { name: "SkiErg", distance_m: 500, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 30, equipment: "sled" }
              ] },
            { name: "Tread the Line", format: "rounds", rounds: 16, rest_secs: 30,
              exercises: [
                { name: "Run", duration_s: 30, notes: "hard pace", equipment: "treadmill" }
              ] },
            { name: "Engine Room", format: "continuous_circuit", duration_mins: 18,
              exercises: [
                { name: "Rowing Machine", equipment: "rowing_machine" },
                { name: "Box Jump Burpees", equipment: "bodyweight" },
                { name: "KB Swings", equipment: "kettlebells" }
              ] },
            { name: "The Centurion", format: "hundred",
              exercises: [
                { name: "Wall Balls", reps: 100, equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Ladder Day",
          goal: "30/30 opener, alternating EMOM grind, a compromised run-up-and-down ladder, then strength and a hundred.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Lung Buster", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Final Boss", format: "emom", duration_mins: 20, rest_secs: 0, alternating: true,
              exercises: [
                { name: "Burpee Broad Jumps", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" },
                { name: "Walking Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Up & Down", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Wall Balls", reps: 10, equipment: "wall_ball" },
                { name: "Run", distance_m: 800, equipment: "treadmill" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" },
                { name: "Run", distance_m: 600, equipment: "treadmill" },
                { name: "Wall Balls", reps: 30, equipment: "wall_ball" },
                { name: "Run", distance_m: 400, equipment: "treadmill" },
                { name: "Wall Balls", reps: 40, equipment: "wall_ball" },
                { name: "Run", distance_m: 200, equipment: "treadmill" },
                { name: "Wall Balls", reps: 50, equipment: "wall_ball" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, equipment: "barbell" }
              ] },
            { name: "Swing Time", format: "hundred",
              exercises: [
                { name: "KB Swings", reps: 100, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "The Workshop",
          goal: "Continuous circuit opener, a carry-and-sled triplet, heavy goblet squats, 1km repeats, then a tabata finisher.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Rotation Room", format: "continuous_circuit", duration_mins: 12,
              exercises: [
                { name: "SkiErg", equipment: "ski_erg" },
                { name: "Walking Lunges", equipment: "bodyweight" },
                { name: "Wall Balls", equipment: "wall_ball" }
              ] },
            { name: "Hardware", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Farmer's Carry", distance_m: 60, equipment: "kettlebells" },
                { name: "Sled Push", distance_m: 40, equipment: "sled" },
                { name: "Sled Pull", distance_m: 20, equipment: "sled" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Goblet Squats", reps: 5, equipment: "kettlebells" }
              ] },
            { name: "Race Pace", format: "rounds", rounds: 5, rest_secs: 90,
              exercises: [
                { name: "Run", distance_m: 1000, notes: "race pace — 90s easy jog rest between rounds", equipment: "treadmill" }
              ] },
            { name: "Tabata Cooker", format: "tabata",
              exercises: [
                { name: "Box Jump Burpees", equipment: "bodyweight" },
                { name: "Shoulder Press", equipment: "barbell" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Mixed Methods",
          goal: "An E2MOM triplet, a classic row-and-wall-ball couplet, 30/30 treadmill, then a thruster-and-slam tabata.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Triple Trouble", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "Burpees", reps: 5, equipment: "bodyweight" },
                { name: "Walking Lunges", reps: 10, equipment: "bodyweight" },
                { name: "Farmer's Carry", distance_m: 20, equipment: "kettlebells" }
              ] },
            { name: "Couplet Crunch", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "Row", calories: 20, equipment: "rowing_machine" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" }
              ] },
            { name: "Tread the Line", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Run", duration_s: 30, notes: "hard pace", equipment: "treadmill" }
              ] },
            { name: "Tabata Cooker", format: "tabata",
              exercises: [
                { name: "Thrusters", equipment: "kettlebells" },
                { name: "Med Ball Slams", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Descent",
          goal: "One long run-broken pyramid — 1km repeats interleaved with ski-sled-wall ball tiers, descending 80 → 20. Pace the start, race the finish.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Down the Stairs", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "SkiErg", calories: 80, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 80, equipment: "sled" },
                { name: "Wall Balls", reps: 80, equipment: "wall_ball" },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "SkiErg", calories: 60, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 60, equipment: "sled" },
                { name: "Wall Balls", reps: 60, equipment: "wall_ball" },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "SkiErg", calories: 40, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 40, equipment: "sled" },
                { name: "Wall Balls", reps: 40, equipment: "wall_ball" },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "SkiErg", calories: 20, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 20, equipment: "sled" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
