module LLMContext
  module Activities
    module DekaMile
      SLUG = "deka-mile"
      NAME = "Deka Mile"

      CONTRACT = {
        purity: "Deka Mile race training — running-heavy Deka variant. Treadmill mileage " \
                "is the backbone of every session.",
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
        notes: "MANDATORY: every session includes at least 2 treadmill intervals, and " \
               "runs are usually longer than the 500m Deka Fit zone (800m–mile repeats " \
               "are common). Engine-building blocks on treadmill should appear regularly " \
               "(400m repeats, mile repeats, 4min hard efforts). The race stations remain " \
               "the primary functional movements; supplementary exercises (see vocabulary) " \
               "can appear occasionally for variety but stations should still dominate. An " \
               "abs finisher (sit-ups, leg raises, planks, V-ups, Russian twists) is a good " \
               "optional close-out."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run blocks:        Treadmill 400m–mile repeats, 4min hard efforts, tempo runs
        Stations:          RAM Reverse Lunges, Row, Box Jump, SkiErg, Farmer's Carry, Air Bike,
                           Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
        Supplementary:     KB Swings, KB Thrusters, KB High Pull, Wall Balls, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press (use sparingly — stations remain primary)
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
                { name: "Run", reps: "1 mile", notes: "steady-hard", equipment: "treadmill" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" }
              ] },
            { name: "Station Finisher", format: "for_time",
              exercises: [
                { name: "Row", reps: "500m", equipment: "rowing_machine" },
                { name: "Farmer's Carry", reps: "100m", equipment: "kettlebells" }
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
              exercises: [ { name: "Run", reps: "400m", notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Station Block", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "SkiErg", reps: "15 cal", equipment: "ski_erg" },
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
                { name: "Run", reps: "1 mile", equipment: "treadmill" },
                { name: "RAM Reverse Lunges", reps: 30 },
                { name: "Run", reps: "800m", equipment: "treadmill" },
                { name: "Row", reps: "500m", equipment: "rowing_machine" },
                { name: "Run", reps: "800m", equipment: "treadmill" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" },
                { name: "Run", reps: "800m", equipment: "treadmill" },
                { name: "SkiErg", reps: "500m", equipment: "ski_erg" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
