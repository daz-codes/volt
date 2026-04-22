module LLMContext
  module Activities
    module VoltOctathlon
      SLUG = "volt-octathlon"
      NAME = "Volt Octathlon"

      CONTRACT = {
        purity: "Volt's in-house 8-station race: machines and functional movements " \
                "back-to-back with no rest. Trains the ability to keep moving under " \
                "accumulated fatigue.",
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike kettlebells dumbbells wall_ball],
        banned_equipment:  %w[barbell sled pull_up_bar resistance_bands jump_rope],
        banned_exercise_patterns: [
          /\bbarbell\b/i
        ].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred mountain],
        primary_formats:   %w[for_time rounds emom amrap],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "The 8 stations are: Thrusters (DB), Rowing, Slams, SkiErg, KB Swings, " \
               "Assault Bike, Devil Press (DB), Running (treadmill). Pair machines with " \
               "functional movements. Switchback ladders (Row cals + KB Swings, Assault " \
               "Bike cals + Slams) are a great training tool. When race_simulation? is " \
               "true the session covers all eight stations."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Machines:   Rowing, SkiErg, Assault Bike, Treadmill
        Functional: DB Thrusters, Ball Slams, KB Swings, DB Devil Press
      VOCAB

      EXAMPLES = [
        {
          name: "Half Octathlon",
          goal: "Practise four stations with short transitions.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Four-Station Block", format: "for_time",
              exercises: [
                { name: "DB Thrusters", reps: 25, equipment: "dumbbells" },
                { name: "Row", reps: "500m", equipment: "rowing_machine" },
                { name: "Slams", reps: 25, equipment: "wall_ball" },
                { name: "SkiErg", reps: "500m", equipment: "ski_erg" }
              ] },
            { name: "Switchback Finisher", format: "rounds", rounds: 4, rest_secs: 0,
              exercises: [
                { name: "Row", reps: "15 cal", equipment: "rowing_machine" },
                { name: "KB Swings", reps: 15, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Engine Octathlon",
          goal: "Build station endurance with EMOM station rotations.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Station EMOM", format: "emom", duration_mins: 20, rest_secs: 0,
              exercises: [
                { name: "DB Thrusters", reps: 10, equipment: "dumbbells" },
                { name: "Assault Bike", reps: "12 cal", equipment: "assault_bike" },
                { name: "Slams", reps: 15, equipment: "wall_ball" },
                { name: "KB Swings", reps: 15, equipment: "kettlebells" }
              ] },
            { name: "Run Finisher", format: "for_time",
              exercises: [ { name: "Run", reps: "1km", equipment: "treadmill" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Full Octathlon",
          goal: "Full 8-station race — all the machines, all the tools, one hit.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Race Simulation", format: "for_time",
              exercises: [
                { name: "DB Thrusters", reps: 50, equipment: "dumbbells" },
                { name: "Row", reps: "1km", equipment: "rowing_machine" },
                { name: "Slams", reps: 50, equipment: "wall_ball" },
                { name: "SkiErg", reps: "1km", equipment: "ski_erg" },
                { name: "KB Swings", reps: 50, equipment: "kettlebells" },
                { name: "Assault Bike", reps: "50 cal", equipment: "assault_bike" },
                { name: "DB Devil Press", reps: 50, equipment: "dumbbells" },
                { name: "Run", reps: "1km", equipment: "treadmill" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
