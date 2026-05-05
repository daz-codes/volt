module LLMContext
  module Activities
    module Transformer
      SLUG = "transformer"
      NAME = "Volt Strong"

      CONTRACT = {
        purity: "Strength-leaning functional training — heavy compound lifts built around " \
                "sets-and-reps, but with at least one cardio-machine section in every " \
                "session to keep the engine honest. Not a pure lifting session, not a " \
                "circuit.",
        allowed_equipment: %w[barbell dumbbells kettlebells pull_up_bar resistance_bands rowing_machine assault_bike ski_erg treadmill],
        banned_equipment:  %w[wall_ball sled jump_rope],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[rounds straight emom ladder],
        primary_formats:   %w[rounds straight],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "MANDATORY: every session includes at least one cardio-machine section " \
               "(rower, assault bike, ski erg, or treadmill) as a warm-up, a finisher, or " \
               "woven between strength blocks. This is not a metabolic conditioning session " \
               "— use rounds and straight sets as the main structure. Rep ranges: 3-5 heavy, " \
               "6-10 hypertrophy, 10-15 accessories only. Plan 60-120s rest between heavy " \
               "sets. NO CONTINUOUS CIRCUITS: do not chain back-to-back heavy lifts with " \
               "no rest; every strength section gives clear rest between exercises. Lifts " \
               "come first, the cardio section supports — think strength coach, not CrossFit."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Heavy compound:  Back Squat, Front Squat, Deadlift, Bench Press, Overhead Press, Row
        Hypertrophy:     DB Bench, DB Row, Goblet Squat, RDL, Lunges
        Accessory:       Biceps Curl, Triceps Extension, Face Pull, Lateral Raise
        Cardio machines: Row, Assault Bike, Ski Erg, Treadmill
      VOCAB

      EXAMPLES = [
        {
          name: "Squat & Row",
          goal: "Heavy squats, strong pulls, and a rower engine block to finish.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Back Squat", format: "straight", rest_secs: 120,
              exercises: [ { name: "Back Squat", reps: "5 × 5", equipment: "barbell" } ] },
            { name: "DB Row", format: "rounds", rounds: 4, rest_secs: 90,
              exercises: [ { name: "DB Row each side", reps: 10, equipment: "dumbbells" } ] },
            { name: "Rower Engine", format: "rounds", rounds: 5, rest_secs: 45,
              exercises: [ { name: "Row", reps: "250m", equipment: "rowing_machine" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Push Day",
          goal: "Build the press with a cardio-machine warm-up to wake the system.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "assault_bike" } ] },
            { name: "Overhead Press", format: "straight", rest_secs: 120,
              exercises: [ { name: "Overhead Press", reps: "5 × 5", equipment: "barbell" } ] },
            { name: "DB Bench Press", format: "rounds", rounds: 4, rest_secs: 90,
              exercises: [ { name: "DB Bench Press", reps: 10, equipment: "dumbbells" } ] },
            { name: "Accessory Ladder", format: "ladder",
              varies: "reps", start: 10, end: 2, step: 2, rest_between_rungs: 30,
              exercises: [
                { name: "Push-ups", equipment: "bodyweight" },
                { name: "Lateral Raise", equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Pull Day",
          goal: "Heavy deadlifts and pulling strength with a ski-erg opener.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Deadlift", format: "straight", intensity_style: "max_effort", rest_secs: 120,
              exercises: [ { name: "Deadlift", reps: "5 × 3", equipment: "barbell" } ] },
            { name: "Pull-up Block", format: "rounds", intensity_style: "max_effort", rounds: 5, rest_secs: 90,
              exercises: [ { name: "Pull-ups", reps: 5, equipment: "pull_up_bar" } ] },
            { name: "Ski Erg Finisher", format: "rounds", intensity_style: "conditioning", rounds: 5, rest_secs: 45,
              exercises: [ { name: "SkiErg", reps: "250m", equipment: "ski_erg" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
