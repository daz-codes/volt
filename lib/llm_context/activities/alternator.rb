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
               "FORMAT VARIETY (non-negotiable): a session that is mostly `rounds` blocks " \
               "is broken — that's the most common failure mode for this activity. Aim for " \
               "AT MOST ONE rep-based rounds block per session (the floor strength block); " \
               "the rest should rotate through ladders (cardio distance ladders are a " \
               "signature shape — Row 500-400-300-200-100m, SkiErg or Treadmill the same), " \
               "mountains (Goblet Squat 5-10-15-10-5), matrices (3-movement triangles), " \
               "tabatas (8 × 20s/10s on a single conditioning movement), EMOMs (single-machine " \
               "calorie efforts), AMRAPs, and for_time efforts (single 1km row/run/ski). " \
               "Cardio blocks especially should NOT default to rounds — pick a ladder or " \
               "for_time effort about half the time. If you find yourself writing a third " \
               "rounds block in one session, stop and convert one to a different format. " \
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
          goal: "Cardio ladder, heavy floor block, sprints, and a tabata to close.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Row Distance Ladder", format: "ladder",
              varies: "distance_m", start: 500, end: 100, step: 100, rest_between_rungs: 30,
              exercises: [ { name: "Row", equipment: "rowing_machine" } ] },
            { name: "Lower Body Strength", format: "rounds", intensity_style: "high", rounds: 3, rest_secs: 120,
              exercises: [
                { name: "Front Squat", reps: 5, equipment: "barbell" },
                { name: "Romanian Deadlift", reps: 5, equipment: "barbell" }
              ] },
            { name: "Assault Bike Sprints", format: "emom", duration_mins: 6, rest_secs: 0,
              exercises: [ { name: "Assault Bike", calories: 10, equipment: "assault_bike" } ] },
            { name: "Upper Body Tabata", format: "tabata", intensity_style: "medium", rounds: 8, rest_secs: 10,
              exercises: [
                { name: "Push-ups", duration_s: 20, equipment: "bodyweight" },
                { name: "KB High Pull", duration_s: 20, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Three-Machine Alternator",
          goal: "Three different machines with three different formats — no two cardio blocks shaped the same.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Ski Erg Distance Ladder", format: "ladder",
              varies: "distance_m", start: 500, end: 100, step: 100, rest_between_rungs: 30,
              exercises: [ { name: "SkiErg", equipment: "ski_erg" } ] },
            { name: "Push Floor", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Push Press", reps: 5, equipment: "barbell" },
                { name: "Chin-ups", reps: 5, equipment: "pull_up_bar" }
              ] },
            { name: "Row 1km", format: "for_time",
              exercises: [ { name: "Row", distance_m: 1000, notes: "all-out — race the clock", equipment: "rowing_machine" } ] },
            { name: "Lower Body Mountain", format: "mountain",
              varies: "reps", start: 5, peak: 15, end: 5, step: 5, rest_between_rungs: 30,
              exercises: [
                { name: "Goblet Squat", equipment: "kettlebells" },
                { name: "KB Swings", equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Treadmill Focus",
          goal: "Distance ladder runs, a core matrix, a 1km closer, and a duration-interval finisher.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Treadmill Distance Ladder", format: "ladder",
              varies: "distance_m", start: 400, end: 100, step: 100, rest_between_rungs: 60,
              exercises: [ { name: "Run", notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Core Matrix", format: "matrix",
              exercises: [
                { name: "Sit-ups", reps: 20, equipment: "bodyweight" },
                { name: "Russian Twists", reps: 20, equipment: "bodyweight" },
                { name: "V-ups", reps: 20, equipment: "bodyweight" }
              ] },
            { name: "Treadmill Finisher", format: "for_time",
              exercises: [ { name: "Run", distance_m: 1000, equipment: "treadmill" } ] },
            { name: "Med Ball Slam Burner", format: "rounds", intensity_style: "medium", rounds: 3, rest_secs: 120,
              exercises: [ { name: "Med Ball Slams", duration_s: 120, equipment: "wall_ball" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
