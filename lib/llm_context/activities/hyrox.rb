module LLMContext
  module Activities
    module Hyrox
      SLUG = "hyrox"
      NAME = "Hyrox"

      CONTRACT = {
        purity: "Hyrox race training — 1 km runs between 8 functional stations. " \
                "Treadmill running is the backbone of every session. Assault Bike is NOT " \
                "a Hyrox machine and must never appear.",
        allowed_equipment: %w[treadmill rowing_machine ski_erg sled wall_ball kettlebells],
        banned_equipment:  %w[barbell dumbbells pull_up_bar resistance_bands jump_rope assault_bike],
        banned_exercise_patterns: [
          /\bassault bike\b/i, /\bair bike\b/i, /\becho bike\b/i, /\bbarbell\b/i, /\bdumbbell\b/i
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
               "exercises and structure but different names. The main stations should " \
               "dominate every session; supplementary movements (see vocabulary) can " \
               "appear occasionally for variety but should never displace the race stations. " \
               "An abs finisher (sit-ups, leg raises, planks, V-ups, Russian twists) is a " \
               "good optional close-out before the cool-down."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Running:           Treadmill 500m, 1km, 400m repeats
        Stations:          SkiErg, Sled Push, Sled Pull, Rowing Machine, Farmer's Carry, Wall Ball, Sandbag Lunges
        Bodyweight:        Burpee Broad Jumps
        Supplementary:     KB Swings, KB Thrusters, KB High Pull, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press (use sparingly — race stations remain primary)
        Burpee variations: Box Jump Burpees, Wall Ball Burpees, KB Burpees (in addition to the standard Burpee Broad Jumps)
        Abs finisher:      Sit-ups, Leg Raises, Plank, V-ups, Russian Twists, Hollow Holds
      VOCAB

      EXAMPLES = [
        {
          name: "Half Race",
          goal: "Practise four run-station transitions at race pace.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Last Mile", format: "rounds", rounds: 4, rest_secs: 30,
              exercises: [
                { name: "Run", reps: "500m", equipment: "treadmill" },
                { name: "SkiErg", reps: "250m", equipment: "ski_erg" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" }
              ] },
            { name: "Run to Victory", format: "for_time",
              exercises: [ { name: "Run", reps: "1km", equipment: "treadmill" } ] },
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
              exercises: [ { name: "Run", reps: "500m", equipment: "treadmill" } ] },
            { name: "Cooked", format: "for_time",
              exercises: [
                { name: "Sled Push", reps: "20m", equipment: "sled" },
                { name: "Farmer's Carry", reps: "40m", equipment: "kettlebells" },
                { name: "Wall Balls", reps: 30, equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Engine & Stations",
          goal: "Build the running engine with spaced station work.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Engine Builder", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [ { name: "Run", reps: "400m", notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Heavy Hands", format: "emom", duration_mins: 15, rest_secs: 0,
              exercises: [
                { name: "Row", reps: "15 cal", equipment: "rowing_machine" },
                { name: "Sandbag Lunges", reps: "20m", equipment: "sled" },
                { name: "SkiErg", reps: "15 cal", equipment: "ski_erg" }
              ] },
            { name: "Final Boss", format: "for_time",
              exercises: [
                { name: "Run", reps: "1km", equipment: "treadmill" },
                { name: "Wall Balls", reps: 50, equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
