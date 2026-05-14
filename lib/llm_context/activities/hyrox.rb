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
          name: "Station Sprint",
          goal: "Short and sharp — your-call EMOM reps then race the legs over compromised runs.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "treadmill" } ] },
            { name: "Hammer Time", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Wall Balls", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" },
                { name: "KB Swings", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" }
              ] },
            { name: "Lung Buster", format: "rounds", rounds: 3, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "Burpee Broad Jumps", reps: 15, equipment: "bodyweight" },
                { name: "Farmer's Carry", distance_m: 40, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Engine Builder",
          goal: "Open the lungs with 30/30s, drop into a heavy lift, then race-pace the stations.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Tread the Line", format: "rounds", intensity_style: "high", rounds: 12, rest_secs: 30,
              exercises: [
                { name: "Run", duration_s: 30, notes: "hard pace", equipment: "treadmill" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, equipment: "barbell" }
              ] },
            { name: "Heavy Hands", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "Sled Push", distance_m: 20, equipment: "sled" },
                { name: "Sandbag Lunges", distance_m: 20, equipment: "sled" },
                { name: "Wall Balls", reps: 30, equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Race Day Rehearsal",
          goal: "Race-prep mix — compromised running, your-call EMOM cycles, then an abs close-out.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Last Mile", format: "rounds", rounds: 4, rest_secs: 90,
              exercises: [
                { name: "Compromised Run", distance_m: 800, equipment: "treadmill" },
                { name: "Wall Balls", reps: 30, equipment: "wall_ball" },
                { name: "Burpee Broad Jumps", reps: 20, equipment: "bodyweight" },
                { name: "Farmer's Carry", distance_m: 40, equipment: "kettlebells" }
              ] },
            { name: "Final Boss", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Thrusters", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" },
                { name: "Box Step-overs", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" },
                { name: "Med Ball Slams", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" }
              ] },
            { name: "Gut Check", format: "rounds", rounds: 3, rest_secs: 30,
              exercises: [
                { name: "Sit-ups", reps: 20, equipment: "bodyweight" },
                { name: "V-ups", reps: 15, equipment: "bodyweight" },
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
