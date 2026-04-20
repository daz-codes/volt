module LLMContext
  module Activities
    module IronEngine
      SLUG = "kettlebell"
      NAME = "Iron Engine"

      CONTRACT = {
        purity: "KETTLEBELL ONLY. Every main and finisher exercise must use a kettlebell. " \
                "No cardio machines, barbells, dumbbells, bodyweight conditioning, or jump rope " \
                "in main sections. Warm-up is KB + activation only.",
        allowed_equipment: %w[kettlebells],
        banned_equipment:  %w[barbell dumbbells assault_bike rowing_machine treadmill ski_erg jump_rope sled wall_ball],
        banned_exercise_patterns: [
          /\bassault bike\b/i, /\becho bike\b/i, /\btreadmill\b/i,
          /\brower?\b/i, /\bski erg\b/i, /\bjump ?rope\b/i, /\bbarbell\b/i, /\bdumbbell\b/i
        ].freeze,
        allowed_formats:   %w[rounds emom for_time amrap ladder tabata hundred mountain],
        primary_formats:   %w[rounds emom for_time amrap],
        signature_formats: %w[complex flow carry],
        warm_up:           :kb_activation,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :never,
        notes: "Complexes, flows, and carries are Iron Engine's signature formats — " \
               "at least one should appear in most sessions. " \
               "REP COUNTS: kettlebells are heavy, so keep reps low. Grinds " \
               "(press, squat, row, deadlift) sit at 6-10 reps per set. " \
               "Ballistics (swings, snatches, cleans) sit at 10-15 reps per set; " \
               "20 is an absolute ceiling, only for light swings as a short burst, " \
               "never for grinds. Do NOT prescribe 20+ reps on any grind. " \
               "NO CONTINUOUS CIRCUITS: do not structure main sections as back-to-back " \
               "KB stations with no rest between exercises, and do not use 1-minute " \
               "EMOM slots that chain heavy KB grinds with no break. Include 15-45s " \
               "rest between exercises inside rounds — unbroken KB work under load " \
               "burns out grip and cardio fast."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Ballistic: KB Swing, KB Snatch, KB Clean, KB Long Cycle, Double KB Swing, KB SDHP
        Grind:    KB Goblet Squat, KB Front Squat, KB Press, KB Push Press, KB Row, KB Deadlift, KB Windmill, KB TGU
        Complex:  Clean → Press → Front Squat → Row → Swing (and similar chained flows)
        Carry:    KB Farmer's Carry, KB Rack Carry, KB Overhead Carry, KB Waiter Walk
      VOCAB

      EXAMPLES = [
        {
          name: "The Blacksmith",
          goal: "Forge strength under load with heavy grinds bookended by ballistic bursts.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up",  format: "straight", duration_mins: 5,
              exercises: [ { name: "KB activation flow (halos, goblet squats, light swings)", duration_s: 300, equipment: "kettlebells" } ] },
            { name: "Grind Ladder", format: "ladder", rest_secs: 60,
              exercises: [
                { name: "KB Front Squat", reps: "5-4-3-2-1", equipment: "kettlebells" },
                { name: "KB Press",       reps: "5-4-3-2-1", equipment: "kettlebells" }
              ] },
            { name: "Ballistic Finisher", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Swing",  reps: 15, equipment: "kettlebells" },
                { name: "KB Snatch", reps: "5/side", equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Iron Flow",
          goal: "Chain movements into one continuous signature complex.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "KB activation (halos, goblet squats, deadlifts)", duration_s: 180, equipment: "kettlebells" } ] },
            { name: "The Complex", format: "complex", rest_secs: 90,
              exercises: [ { name: "KB Clean → Press → Front Squat → Row → Swing", reps: "6 rounds", equipment: "kettlebells" } ] },
            { name: "Carry Finisher", format: "for_time", rest_secs: 0,
              exercises: [ { name: "KB Farmer's Carry", reps: "4 x 40m", equipment: "kettlebells" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Anvil",
          goal: "Short, dense kettlebell hit — ballistic power with carry grit.",
          duration_mins: 25,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "KB activation", duration_s: 180, equipment: "kettlebells" } ] },
            { name: "Ballistic AMRAP", format: "amrap", duration_mins: 10, rest_secs: 15,
              exercises: [
                { name: "KB Swing",    reps: 15, equipment: "kettlebells" },
                { name: "Goblet Squat", reps: 8, equipment: "kettlebells" }
              ] },
            { name: "Carry Finisher", format: "for_time", rest_secs: 0,
              exercises: [ { name: "KB Rack Carry", reps: "3 x 30m", equipment: "kettlebells" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
