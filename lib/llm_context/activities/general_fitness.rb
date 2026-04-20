module LLMContext
  module Activities
    module GeneralFitness
      SLUG = "general-fitness"
      NAME = "General Fitness"

      CONTRACT = {
        purity: "A well-rounded general-fitness session — mix strength, conditioning, " \
                "and a finisher. Permissive by default: any equipment the athlete has " \
                "is fair game.",
        allowed_equipment: %w[barbell dumbbells kettlebells pull_up_bar wall_ball sled resistance_bands jump_rope rowing_machine assault_bike ski_erg treadmill],
        banned_equipment:  %w[],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[rounds amrap emom for_time tabata ladder hundred matrix mountain],
        primary_formats:   %w[rounds amrap emom for_time],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "Mix formats — rounds for strength, AMRAP/EMOM for conditioning, tabata or " \
               "hundred as a finisher. Use whatever equipment the athlete has available. " \
               "Variety keeps sessions interesting."
      }.freeze

      EXAMPLES = [
        {
          name: "Full Body Short",
          goal: "One strength block, one conditioning block, done in thirty minutes.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Strength Rounds", format: "rounds", rounds: 4, rest_secs: 90,
              exercises: [
                { name: "Goblet Squat", reps: 10, equipment: "kettlebells" },
                { name: "DB Row each side", reps: 10, equipment: "dumbbells" }
              ] },
            { name: "Conditioning AMRAP", format: "amrap", duration_mins: 12, rest_secs: 15,
              exercises: [
                { name: "KB Swings", reps: 20, equipment: "kettlebells" },
                { name: "Push-ups", reps: 10, equipment: "bodyweight" },
                { name: "Row", reps: "15 cal", equipment: "rowing_machine" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Classic Mix",
          goal: "Balanced hour — strength, conditioning, and a short finisher.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "assault_bike" } ] },
            { name: "Strength", format: "rounds", rounds: 5, rest_secs: 90,
              exercises: [
                { name: "DB Thrusters", reps: 10, equipment: "dumbbells" },
                { name: "Pull-ups", reps: 6, equipment: "pull_up_bar" }
              ] },
            { name: "Conditioning EMOM", format: "emom", duration_mins: 12, rest_secs: 0,
              exercises: [
                { name: "Row", reps: "15 cal", equipment: "rowing_machine" },
                { name: "Burpees", reps: 10, equipment: "bodyweight" }
              ] },
            { name: "Tabata Finisher", format: "tabata", rounds: 8, rest_secs: 10,
              exercises: [ { name: "Mountain Climbers", duration_s: 20, equipment: "bodyweight" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Long Hit",
          goal: "Full hour — hit every energy system with a tight close.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Strength Block", format: "rounds", rounds: 5, rest_secs: 90,
              exercises: [
                { name: "Back Squat", reps: 8, equipment: "barbell" },
                { name: "DB Bench Press", reps: 10, equipment: "dumbbells" }
              ] },
            { name: "Conditioning For Time", format: "for_time",
              exercises: [
                { name: "KB Swings", reps: 50, equipment: "kettlebells" },
                { name: "Wall Balls", reps: 50, equipment: "wall_ball" },
                { name: "Row", reps: "500m", equipment: "rowing_machine" }
              ] },
            { name: "The Hundred", format: "hundred",
              exercises: [ { name: "Sit-ups", reps: 100, equipment: "bodyweight" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
