module LLMContext
  module Activities
    module IronEngine
      SLUG = "kettlebell"
      NAME = "Kettlebell Hell"

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
        intensity_guide: {
          low:    "Light bell, high-volume conditioning day — ballistics at 15-20 reps with a " \
                  "lighter kettlebell and short rest (30s), OR long unbroken flows / carries at " \
                  "conversational pace. NEVER running, rowing, or sprints — this activity is " \
                  "kettlebell-only. Effort cue: easy, sustainable, breath stays smooth.",
          medium: "Standard kettlebell conditioning — 10-rep ballistics or 8-10 rep grinds, " \
                  "60-90s rest between rounds, working hard but in control. The default texture.",
          high:   "Heavy bell, low reps, long rest — grinds at 5 reps (presses, squats, " \
                  "deadlifts) with 120-180s rest, OR short ballistic bursts (10 heavy snatches " \
                  "or swings) with full recovery between rounds. NO sprints (no cardio machines " \
                  "exist here) — high intensity is heavy load, not heart rate."
        },
        notes: "Complexes, flows, and carries are Iron Engine's signature formats — " \
               "at least one should appear in most sessions. " \
               "REP COUNTS: kettlebells are heavy, so keep reps low. Grinds " \
               "(press, squat, row, deadlift) use 5 reps (heavy) or 10 reps (moderate). " \
               "Ballistics (swings, snatches, cleans) use 10 (standard) or 15 (lighter conditioning). " \
               "20 is the ceiling, only for light swings as a short burst — never for grinds. " \
               "Follow the global rule: same rep count across all exercises in a round. " \
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
            { name: "Grind Ladder", format: "ladder", intensity_style: "high",
              varies: "reps", start: 5, end: 1, step: 1, rest_between_rungs: 120,
              exercises: [
                { name: "KB Front Squat", equipment: "kettlebells" },
                { name: "KB Press",       equipment: "kettlebells" }
              ] },
            { name: "Ballistic Finisher", format: "emom", intensity_style: "medium", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Swing",  reps: 15, equipment: "kettlebells" },
                { name: "KB Snatch", reps: "5 each side", equipment: "kettlebells" }
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
                { name: "KB Swing",    reps: 10, equipment: "kettlebells" },
                { name: "Goblet Squat", reps: 10, equipment: "kettlebells" }
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
