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
               "REP & REST SCHEMES (match the work to the rest): " \
               "heavy compound 3-5 reps → 120-180s rest (2-3 min, intensity_style: max_effort); " \
               "hypertrophy 6-10 reps → 90-120s rest; " \
               "accessory/finisher 10-15 reps → 60-90s rest. " \
               "60s rest is for accessories, never for heavy bench/squat/deadlift. " \
               "SET COUNT VIA ROUNDS, NOT STRINGS: a `5×5` block is `format: \"rounds\", " \
               "rounds: 5, rest_secs: 120, exercises: [{ name: \"Back Squat\", reps: 5 }]`. " \
               "NEVER put the set count into the reps field as a string (`reps: \"5 × 5\"`, " \
               "`reps: \"5x3\"`, `reps: \"3 sets of 8\"`). Strings render as `5 × 5 reps` " \
               "alongside the rounds count and produce nonsense like `3 rounds · 5 × 5 reps`. " \
               "VARY REP SCHEMES across sessions — not every workout is 5×5. Mix in 5×3 " \
               "(top-end strength, 180s rest), 4×6 or 4×8 (hypertrophy, 120s rest), 3×10-12 " \
               "(volume/accessory, 90s rest). Pick the scheme that matches the lift's intent. " \
               "NO CONTINUOUS CIRCUITS: do not chain back-to-back heavy lifts with no rest; " \
               "every strength section gives clear rest between exercises. Lifts are the " \
               "centrepiece — finishers can be bodyweight (push-ups, walking lunges, pull-ups, " \
               "dips, burpees) or a duration-interval block (e.g. 3 rounds: 2 min walking " \
               "lunges / 2 min rest). Think strength coach, not CrossFit."
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
            { name: "Back Squat", format: "rounds", intensity_style: "max_effort", rounds: 5, rest_secs: 120,
              exercises: [ { name: "Back Squat", reps: 5, equipment: "barbell", notes: "heavy load — last rep should be near failure" } ] },
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
            { name: "Overhead Press", format: "rounds", rounds: 4, rest_secs: 120,
              exercises: [ { name: "Overhead Press", reps: 6, equipment: "barbell", notes: "controlled descent, explosive drive" } ] },
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
            { name: "Deadlift", format: "rounds", intensity_style: "max_effort", rounds: 5, rest_secs: 180,
              exercises: [ { name: "Deadlift", reps: 3, equipment: "barbell", notes: "top-end strength — go heavy, full reset between reps" } ] },
            { name: "Pull-up Block", format: "rounds", rounds: 4, rest_secs: 90,
              exercises: [ { name: "Pull-ups", reps: 8, equipment: "pull_up_bar" } ] },
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
