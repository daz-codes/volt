module LLMContext
  module Activities
    module CrossFit
      SLUG = "crossfit"
      NAME = "CrossFit"

      CONTRACT = {
        purity: "CrossFit sessions are classic box-class WODs — varied, intense, " \
                "competitive. Strength, gymnastics, and metabolic conditioning all " \
                "appear across the week.",
        allowed_equipment: %w[barbell dumbbells kettlebells pull_up_bar wall_ball sled jump_rope rowing_machine assault_bike ski_erg treadmill],
        banned_equipment:  %w[resistance_bands],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[amrap emom for_time rounds tabata ladder hundred mountain matrix],
        primary_formats:   %w[amrap emom for_time rounds],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "Classic WOD shapes: AMRAP-20, EMOM-12, For Time chippers, rounds-for-strength. " \
               "Switchback ladders and descending clusters belong here. Vary the modality " \
               "(barbell, gymnastics, cardio) each session. Sessions should feel like a box " \
               "class — short, intense, and measurable. " \
               "DURATION INTERVALS: a 3-4 round work-rest block on a single movement " \
               "(Wall Balls, Burpees, Walking Lunges, KB Swings, Thrusters) — rounds " \
               "format with duration_s: 120 and rest_secs: 120 — is a valid alternative " \
               "to rep-based rounds. The clean-minute rule applies only to cardio machines."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Barbell:     Squat, Front Squat, Back Squat, Overhead Squat, Deadlift, Romanian Deadlift, Sumo Deadlift, Single-Leg Deadlift, Clean, Snatch, Thruster, Press, Bench Press, Push Press, Landmine Press, Landmine Row, Landmine Squat
        Accessory:   Split Squat, Bulgarian Split Squat, B-stance Squat, B-stance Deadlift, DB Romanian Deadlift, DB Bench Press, DB Press
        Gymnastics:  Pull-ups, Chin-ups, Toes-to-bar, Dips, Ring Dips, Handstand Push-ups, Muscle-ups, Ring Rows
        Conditioning: Double-unders, Burpees, Box Jumps, Wall Balls, Rower, SkiErg, Assault Bike
      VOCAB

      EXAMPLES = [
        {
          name: "Fran Energy",
          goal: "A classic couplet that'll leave the lungs burning in under ten minutes.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Fran-Style Couplet", format: "for_time",
              exercises: [
                { name: "Thrusters", reps: "21-15-9", equipment: "barbell" },
                { name: "Pull-ups", reps: "21-15-9", equipment: "pull_up_bar" }
              ] },
            { name: "Bike Finisher", format: "rounds", rounds: 5, rest_secs: 30,
              exercises: [ { name: "Assault Bike", calories: 10, equipment: "assault_bike" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Strength + Metcon",
          goal: "Back squat heavy, then burn it off with a short metcon.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "assault_bike" } ] },
            { name: "Back Squat", format: "rounds", intensity_style: "max_effort", rounds: 5, rest_secs: 120,
              exercises: [ { name: "Back Squat", reps: 5, equipment: "barbell" } ] },
            { name: "Metcon", format: "amrap", intensity_style: "conditioning", duration_mins: 12, rest_secs: 0,
              exercises: [
                { name: "Box Jumps", reps: 15, equipment: "bodyweight" },
                { name: "KB Swings", reps: 20, equipment: "kettlebells" },
                { name: "Burpees", reps: 10, equipment: "bodyweight" }
              ] },
            { name: "Wall Ball Burner", format: "rounds", intensity_style: "conditioning", rounds: 3, rest_secs: 120,
              exercises: [ { name: "Wall Balls", duration_s: 120, equipment: "wall_ball" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "EMOM Chipper",
          goal: "Twenty minutes of EMOM plus a chipper to cap the hour.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Skill EMOM", format: "emom", duration_mins: 20, rest_secs: 0,
              exercises: [
                { name: "Hang Power Clean", reps: 5, equipment: "barbell" },
                { name: "Wall Balls", reps: 15, equipment: "wall_ball" },
                { name: "Row", calories: 12, equipment: "rowing_machine" },
                { name: "Toes-to-bar", reps: 10, equipment: "pull_up_bar" }
              ] },
            { name: "For Time Chipper", format: "for_time",
              exercises: [
                { name: "Double-unders", reps: 100, equipment: "jump_rope" },
                { name: "KB Swings", reps: 50, equipment: "kettlebells" },
                { name: "Burpees", reps: 30, equipment: "bodyweight" },
                { name: "Pull-ups", reps: 20, equipment: "pull_up_bar" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
