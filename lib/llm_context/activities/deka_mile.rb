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
               "(400m repeats, mile repeats, 4min hard efforts)."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run blocks:        Treadmill 400m–mile repeats, 4min hard efforts, tempo runs
        Stations:          RAM Reverse Lunges, Row, Box Jump, SkiErg, Farmer's Carry, Air Bike,
                           Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
      VOCAB

      EXAMPLES = [
        {
          name: "Quick One",
          goal: "6 × 400m treadmill repeats then a single-exercise walking-lunge EMOM to cook the legs.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "treadmill" } ] },
            { name: "Mile High", format: "rounds", rounds: 6, rest_secs: 60,
              exercises: [
                { name: "Run", distance_m: 400, notes: "hard pace", equipment: "treadmill" }
              ] },
            { name: "Walking Death", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Walking Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Death by Threes",
          goal: "Three mile-repeat treadmill rounds, a single-exercise wall-ball EMOM, then a heavy deadlift accessory.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "The Long Way Round", format: "rounds", rounds: 3, rest_secs: 120,
              exercises: [
                { name: "Run", distance_m: 1600, notes: "hard pace", equipment: "treadmill" }
              ] },
            { name: "Wall Builder", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Wall Balls", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, equipment: "barbell" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Tuesday's Regret",
          goal: "30/30 treadmill engine, compromised 800m runs, a swing EMOM grind, then a hundred burpee finisher.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Tread the Line", format: "rounds", rounds: 24, rest_secs: 30,
              exercises: [
                { name: "Run", duration_s: 30, notes: "hard pace", equipment: "treadmill" }
              ] },
            { name: "Pavement Pounder", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 800, equipment: "treadmill" },
                { name: "Wall Balls", reps: 30, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 30, equipment: "kettlebells" }
              ] },
            { name: "Swing Time", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "KB Swings", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" }
              ] },
            { name: "The Centurion", format: "hundred",
              exercises: [
                { name: "Burpees", reps: 100, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
