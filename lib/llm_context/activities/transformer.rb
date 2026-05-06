module LLMContext
  module Activities
    module Transformer
      SLUG = "transformer"
      NAME = "Volt Strong"

      CONTRACT = {
        purity: "Strength-only functional training — heavy compound lifts built around " \
                "sets-and-reps, paired with accessory work and bodyweight or duration-" \
                "interval finishers. No cardio machines, no metabolic conditioning circuits.",
        allowed_equipment: %w[barbell dumbbells kettlebells pull_up_bar resistance_bands],
        banned_equipment:  %w[rowing_machine assault_bike ski_erg treadmill wall_ball sled jump_rope],
        banned_exercise_patterns: [
          /\bski erg\b/i, /\bassault bike\b/i, /\bair bike\b/i, /\becho bike\b/i, /\btreadmill\b/i
        ].freeze,
        allowed_formats:   %w[rounds straight emom ladder],
        primary_formats:   %w[rounds straight],
        warm_up:           :bodyweight_activation,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "PURE STRENGTH: no cardio machines (rower, ski erg, assault bike, treadmill) " \
               "anywhere in the session. Use rounds and straight sets as the main structure. " \
               "Rep ranges: 3-5 heavy, 6-10 hypertrophy, 10-15 accessories only. Plan 60-120s " \
               "rest between heavy sets. NO CONTINUOUS CIRCUITS: do not chain back-to-back " \
               "heavy lifts with no rest; every strength section gives clear rest between " \
               "exercises. Lifts are the centrepiece — finishers can be bodyweight (push-ups, " \
               "walking lunges, pull-ups, dips, burpees) or a duration-interval block " \
               "(e.g. 3 rounds: 2 min walking lunges / 2 min rest). Think strength coach, " \
               "not CrossFit."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Heavy compound:  Back Squat, Front Squat, Deadlift, Bench Press, Overhead Press, Bent-Over Row
        Hypertrophy:     DB Bench Press, DB Row, Goblet Squat, Romanian Deadlift, Sumo Deadlift, Single-Leg Deadlift, Bulgarian Split Squat, Split Squat, B-stance Squat, B-stance Deadlift, Lunges, Walking Lunges
        Accessory:       Biceps Curl, Triceps Extension, Face Pull, Lateral Raise, Landmine Press, Landmine Row
        Bodyweight:      Pull-ups, Chin-ups, Dips, Push-ups, Toes-to-bar, Burpees
      VOCAB

      EXAMPLES = [
        {
          name: "Squat & Row",
          goal: "Heavy squats, strong pulls, and a posterior-chain accessory finisher.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Bodyweight activation + Dynamic stretches", duration_s: 300, equipment: "bodyweight" } ] },
            { name: "Back Squat", format: "straight", rest_secs: 120,
              exercises: [ { name: "Back Squat", reps: "5 × 5", equipment: "barbell" } ] },
            { name: "DB Row", format: "rounds", rounds: 4, rest_secs: 90,
              exercises: [ { name: "DB Row each side", reps: 10, equipment: "dumbbells" } ] },
            { name: "Romanian Deadlift", format: "rounds", rounds: 3, rest_secs: 90,
              exercises: [ { name: "Romanian Deadlift", reps: 8, equipment: "barbell" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Push Day",
          goal: "Build the press with focused accessory work to follow.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Bodyweight activation + Dynamic stretches", duration_s: 300, equipment: "bodyweight" } ] },
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
          goal: "Heavy deadlifts and pulling strength with a duration-interval bodyweight finisher.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Bodyweight activation + Dynamic stretches", duration_s: 300, equipment: "bodyweight" } ] },
            { name: "Deadlift", format: "straight", intensity_style: "max_effort", rest_secs: 120,
              exercises: [ { name: "Deadlift", reps: "5 × 3", equipment: "barbell" } ] },
            { name: "Pull-up Block", format: "rounds", intensity_style: "max_effort", rounds: 5, rest_secs: 90,
              exercises: [ { name: "Pull-ups", reps: 5, equipment: "pull_up_bar" } ] },
            { name: "Walking Lunge Burner", format: "rounds", intensity_style: "conditioning", rounds: 3, rest_secs: 120,
              exercises: [ { name: "Walking Lunges", duration_s: 120, equipment: "bodyweight" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
