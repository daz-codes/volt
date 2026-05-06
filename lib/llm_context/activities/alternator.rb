module LLMContext
  module Activities
    module Alternator
      SLUG = "alternator"
      NAME = "Pump & Grind"

      CONTRACT = {
        purity: "Alternator sessions alternate DIFFERENT cardio machines with floor " \
                "strength blocks. Each cardio block uses a new machine, and each floor " \
                "block pairs with the previous machine (push/pull balance).",
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike barbell dumbbells kettlebells wall_ball sled pull_up_bar jump_rope resistance_bands],
        banned_equipment:  %w[],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[rounds emom for_time amrap tabata ladder matrix mountain],
        primary_formats:   %w[rounds emom for_time],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "Structure: easy-cardio warm-up → alternating cardio/floor blocks → stretch " \
               "cool-down. Cardio blocks rotate machines (never the same machine twice in " \
               "a row). Floor blocks pair deliberately with the preceding cardio — after " \
               "ski erg (pull) do a push-focused floor, after rowing do lower body, after " \
               "assault bike do upper body, after treadmill do core or full body. No " \
               "separate activation or abs section. Treadmill-focused variants (formerly " \
               "Tread & Shred) stay within this structure — treadmill is one of the " \
               "rotating machines, not a whole-session dominant. " \
               "FORMAT VARIETY: do not make every section a rep-based rounds block. Floor " \
               "strength uses rounds, but conditioning and finishers should rotate through " \
               "tabatas, ladders, matrices, mountains, AMRAPs, and EMOMs across sessions. " \
               "STRENGTH SPICE: floor blocks should regularly feature heavy compound lifts " \
               "(Back Squat, Front Squat, Deadlift, Bench Press, Push Press, Overhead Press, " \
               "Bent-Over Row) at 5-8 reps with 90-120s rest, not just light DB pairs. " \
               "CONDITIONING SPICE: Wall Balls, KB Swings, Med Ball Slams, Burpees, and Box " \
               "Jumps belong in finishers and high-intensity floor blocks — work them in " \
               "regularly. " \
               "DURATION INTERVALS: a 3-round work-rest block on a single conditioning " \
               "movement (Wall Balls, KB Swings, Med Ball Slams, Burpees, Walking Lunges) " \
               "using rounds with duration_s: 120 and rest_secs: 120 is a valid finisher " \
               "shape. The clean-minute rule applies only to cardio machines."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Cardio:             Row, Ski Erg, Assault Bike, Treadmill
        Push (heavy):       Bench Press, Push Press, Overhead Press, Landmine Press
        Push (accessory):   DB Bench Press, DB Shoulder Press, Push-ups, Dips
        Pull (heavy):       Bent-Over Row, Pull-ups, Chin-ups
        Pull (accessory):   DB Row, Inverted Row, Landmine Row, Face Pulls
        Lower (heavy):      Back Squat, Front Squat, Deadlift, Romanian Deadlift
        Lower (accessory):  Goblet Squat, Bulgarian Split Squat, B-stance Squat, B-stance Deadlift, DB Lunges, Walking Lunges, DB RDL, Step-ups
        Full body:          Thrusters, Man Makers, Burpees, Clean, KB Swings, KB Thrusters, KB High Pull
        Conditioning spice: Wall Balls, Med Ball Slams, Box Jumps, Burpee Broad Jumps, Box Jump Burpees
        Core:               Plank, Sit-ups, Russian Twists, V-ups, Toes-to-bar, Hollow Holds
      VOCAB

      EXAMPLES = [
        {
          name: "Short Switch",
          goal: "Two cardio machines, two floor blocks, one tight session.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Row Intervals", format: "rounds", rounds: 6, rest_secs: 30,
              exercises: [ { name: "Row", reps: "250m", equipment: "rowing_machine" } ] },
            { name: "Upper Body Floor", format: "rounds", intensity_style: "max_effort", rounds: 4, rest_secs: 90,
              exercises: [
                { name: "Bench Press", reps: 6, equipment: "barbell" },
                { name: "Pull-ups", reps: 8, equipment: "pull_up_bar" }
              ] },
            { name: "Assault Bike Sprints", format: "emom", duration_mins: 8, rest_secs: 0,
              exercises: [ { name: "Assault Bike", reps: "10 cal", equipment: "assault_bike" } ] },
            { name: "Wall Ball Tabata", format: "tabata", intensity_style: "conditioning", rounds: 8, rest_secs: 10,
              exercises: [ { name: "Wall Balls", duration_s: 20, equipment: "wall_ball" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Three-Machine Alternator",
          goal: "Rotate three machines with balanced floor pairs between them.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Ski Erg Intervals", format: "rounds", rounds: 5, rest_secs: 30,
              exercises: [ { name: "SkiErg", reps: "250m", equipment: "ski_erg" } ] },
            { name: "Push Floor", format: "rounds", intensity_style: "max_effort", rounds: 4, rest_secs: 90,
              exercises: [
                { name: "Push Press", reps: 6, equipment: "barbell" },
                { name: "Chin-ups", reps: 6, equipment: "pull_up_bar" }
              ] },
            { name: "Row Intervals", format: "rounds", rounds: 5, rest_secs: 30,
              exercises: [ { name: "Row", reps: "250m", equipment: "rowing_machine" } ] },
            { name: "KB Swing Ladder", format: "ladder",
              varies: "reps", start: 20, end: 4, step: 4, rest_between_rungs: 30,
              exercises: [
                { name: "KB Swings", equipment: "kettlebells" },
                { name: "Goblet Squat", equipment: "kettlebells" }
              ] },
            { name: "Assault Bike Sprints", format: "emom", duration_mins: 8, rest_secs: 0,
              exercises: [ { name: "Assault Bike", reps: "10 cal", equipment: "assault_bike" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Treadmill Focus",
          goal: "A treadmill-led alternator — runs bookend the floor strength work.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Treadmill Intervals", format: "rounds", rounds: 5, rest_secs: 45,
              exercises: [ { name: "Run", reps: "400m", notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Upper Body Matrix", format: "matrix",
              exercises: [
                { name: "Bench Press", reps: 8, equipment: "barbell" },
                { name: "Bent-Over Row", reps: 8, equipment: "barbell" },
                { name: "Push-ups", reps: 12, equipment: "bodyweight" }
              ] },
            { name: "Treadmill Finisher", format: "for_time",
              exercises: [ { name: "Run", reps: "1km", equipment: "treadmill" } ] },
            { name: "Med Ball Slam Burner", format: "rounds", intensity_style: "conditioning", rounds: 3, rest_secs: 120,
              exercises: [ { name: "Med Ball Slams", duration_s: 120, equipment: "wall_ball" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
