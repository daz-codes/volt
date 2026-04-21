module LLMContext
  module Activities
    module CircuitBreaker
      SLUG = "circuit-breaker"
      NAME = "Circuit Breaker"

      CONTRACT = {
        purity: "F45 / functional-fitness group training — high variety, fast transitions, " \
                "minimal rest. Stations, circuits, and tabatas are the bread and butter.",
        allowed_equipment: %w[barbell dumbbells kettlebells pull_up_bar wall_ball sled resistance_bands jump_rope rowing_machine assault_bike ski_erg treadmill],
        banned_equipment:  %w[],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[amrap emom tabata for_time rounds ladder matrix hundred mountain],
        primary_formats:   %w[amrap emom tabata for_time rounds],
        signature_formats: %w[switchback matrix],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "Mix AMRAPs, EMOMs, tabatas, and for_time efforts. Mix strength (rounds) " \
               "with conditioning (amrap/emom) in the same session. Ladders, matrices, and " \
               "hundreds make great finishers. Switchback ladders pairing a calorie-cardio " \
               "machine (assault bike, rower, ski erg — never jump rope or treadmill) with " \
               "a functional movement are a signature format. Keep rest short and " \
               "transitions fast — think F45, not a powerlifting session."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Strength:      DB Thrusters, Goblet Squats, Deadlifts, Push Press, KB Swings
        Conditioning:  Burpees, Box Jumps, Wall Balls, Row, SkiErg, Assault Bike
        Bodyweight:    Push-ups, Sit-ups, Mountain Climbers, Jumping Lunges
      VOCAB

      EXAMPLES = [
        {
          name: "Station Sprint",
          goal: "Fast stations, short rest, classic circuit-training energy.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "AMRAP Circuit", format: "amrap", duration_mins: 12, rest_secs: 15,
              exercises: [
                { name: "DB Thrusters", reps: 10, equipment: "dumbbells" },
                { name: "Wall Balls", reps: 15, equipment: "wall_ball" },
                { name: "Row", reps: "15 cal", equipment: "rowing_machine" }
              ] },
            { name: "Tabata Finisher", format: "tabata", rounds: 8, rest_secs: 10,
              exercises: [ { name: "Burpees", duration_s: 20, equipment: "bodyweight" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Switchback Special",
          goal: "Ride the switchback up-and-down ladder to a clean finish.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Strength Rounds", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Deadlift", reps: 5, equipment: "barbell" },
                { name: "Pull-ups", reps: 5, equipment: "pull_up_bar" }
              ] },
            { name: "Switchback Ladder", format: "rounds", rounds: 4, rest_secs: 0,
              exercises: [
                { name: "Assault Bike", reps: "40/30/20/10 cal", equipment: "assault_bike" },
                { name: "KB Swings", reps: "10/20/30/40", equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "EMOM Stacks",
          goal: "Stacked EMOMs hit every system in one tight hour.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "assault_bike" } ] },
            { name: "Strength EMOM", format: "emom", duration_mins: 15, rest_secs: 0,
              exercises: [
                { name: "DB Push Press", reps: 10, equipment: "dumbbells" },
                { name: "Goblet Squat", reps: 10, equipment: "kettlebells" },
                { name: "Row", reps: "15 cal", equipment: "rowing_machine" }
              ] },
            { name: "Conditioning AMRAP", format: "amrap", duration_mins: 12, rest_secs: 15,
              exercises: [
                { name: "Wall Balls", reps: 15, equipment: "wall_ball" },
                { name: "Burpees", reps: 10, equipment: "bodyweight" },
                { name: "Box Jumps", reps: 10, equipment: "bodyweight" }
              ] },
            { name: "Matrix Finisher", format: "matrix",
              exercises: [
                { name: "Jumping Lunges", reps: 10, equipment: "bodyweight" },
                { name: "Push-ups", reps: 10, equipment: "bodyweight" },
                { name: "Sit-ups", reps: 10, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
