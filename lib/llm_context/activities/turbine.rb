module LLMContext
  module Activities
    module Turbine
      SLUG = "turbine"
      NAME = "Engine Room"

      CONTRACT = {
        purity: "PURE CARDIO. The only equipment allowed in main sections is the four " \
                "cardio machines: treadmill, rowing machine, ski erg, assault bike. " \
                "No resistance training, no kettlebell work, no bodyweight conditioning.",
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike],
        banned_equipment:  %w[barbell dumbbells kettlebells pull_up_bar wall_ball sled resistance_bands jump_rope],
        banned_exercise_patterns: [
          /\bsquat\b/i, /\bdeadlift\b/i, /\bpress\b/i, /\bcurl\b/i,
          /\bkettlebell\b/i, /\bdumbbell\b/i, /\bbarbell\b/i, /\bburpee\b/i,
          /\bpush[- ]?up\b/i, /\bsit[- ]?up\b/i
        ].freeze,
        allowed_formats:   %w[rounds emom for_time amrap ladder tabata],
        primary_formats:   %w[rounds emom for_time tabata],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :never,
        notes: "Never finish with a treadmill tabata (historical bug). Sprint intervals " \
               "use only 20s/10s, 20s/20s, 30s/15s, 30s/30s — rest never exceeds work. " \
               "Rotate machines across sections; do not use the same machine twice in a row."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Steady state: Row @ 2:10 pace, Ski Erg @ 2:15 pace, Easy jog, Zone 2 bike
        Threshold:    Row @ 1:55 pace, 7 mph run, Moderate bike
        VO2:          1:45 row pace, 10 mph run, Hard bike
        Sprint:       20-30s all-out efforts on any machine with equal-or-shorter rest
      VOCAB

      EXAMPLES = [
        {
          name: "Three-Way Pull",
          goal: "Rotate through the three pulling machines at threshold with short rest.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "assault_bike" } ] },
            { name: "Machine Rotation", format: "rounds", rest_secs: 30,
              exercises: [
                { name: "Row",          duration_s: 300, equipment: "rowing_machine" },
                { name: "Ski Erg",      duration_s: 300, equipment: "ski_erg" },
                { name: "Assault Bike", duration_s: 300, equipment: "assault_bike" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Pyramid Intervals",
          goal: "Build and shed intensity with a clean sprint pyramid — rest never exceeds work.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Sprint Pyramid", format: "emom", intensity_style: "max_effort", duration_mins: 20, rest_secs: 0,
              exercises: [
                { name: "Row sprint",     duration_s: 20, notes: "work 20s, rest 10s", equipment: "rowing_machine" },
                { name: "Row moderate",   duration_s: 30, notes: "work 30s, rest 30s", equipment: "rowing_machine" },
                { name: "Ski Erg sprint", duration_s: 30, notes: "work 30s, rest 15s", equipment: "ski_erg" }
              ] },
            { name: "Steady Finisher", format: "for_time", intensity_style: "zone_2",
              exercises: [ { name: "Run", reps: "1.5 km", equipment: "treadmill" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Short Engine",
          goal: "A fast, dense 20-minute cardio hit with no treadmill finish.",
          duration_mins: 20,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "ski_erg" } ] },
            { name: "Sprint Rounds", format: "rounds", rest_secs: 20,
              exercises: [
                { name: "Assault Bike sprint", duration_s: 20, equipment: "assault_bike" },
                { name: "Row moderate",        duration_s: 40, equipment: "rowing_machine" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
