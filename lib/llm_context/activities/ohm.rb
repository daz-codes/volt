module LLMContext
  module Activities
    module Ohm
      SLUG = "ohm"
      NAME = "Ohm"

      CONTRACT = {
        purity: "Yoga / pilates / mobility. No machines, no weights, no conditioning. " \
                "The session IS the warm-up and cool-down — there are no separate bookends.",
        allowed_equipment: %w[],
        banned_equipment:  %w[barbell dumbbells kettlebells pull_up_bar wall_ball sled resistance_bands jump_rope rowing_machine assault_bike ski_erg treadmill],
        banned_exercise_patterns: [
          /\btabata\b/i, /\bfor[- ]time\b/i, /\bemom\b/i, /\bamrap\b/i,
          /\bburpee\b/i, /\bsprint\b/i, /\bjump\b/i
        ].freeze,
        allowed_formats:   %w[straight rounds hundred],
        primary_formats:   %w[straight],
        warm_up:           :flow,
        cool_down:         :savasana,
        finisher:          :forbidden,
        core:              :optional,
        notes: "A flowing sequence — transitions between poses carry the rhythm. Open " \
               "with a gentle activation flow, close with savasana. Do NOT emit tabata, " \
               "for_time, emom, amrap, or any conditioning format. Movements are slow, " \
               "controlled, and focused on breath, mobility, and core stability."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Flow:        Sun Salutation A/B, Cat-Cow flow, Vinyasa sequence
        Strength:    Plank hold, Side plank, Boat pose, Bridge, Chair pose
        Pilates:     The Hundred, Roll-ups, Single-leg stretch, Teaser, Leg circles
        Mobility:    Pigeon, Thread-the-needle, Cobra, Child's pose, Downward dog
        Balance:     Tree, Warrior III, Dancer, Half-moon
      VOCAB

      EXAMPLES = [
        {
          name: "Morning Flow",
          goal: "Wake the body with a slow vinyasa and finish resting in stillness.",
          duration_mins: 20,
          sections: [
            { name: "Warm-Up Flow", format: "straight", duration_mins: 3,
              exercises: [ { name: "Cat-Cow + gentle spinal waves", duration_s: 180, equipment: "bodyweight" } ] },
            { name: "Main Flow", format: "straight", duration_mins: 15,
              exercises: [
                { name: "Sun Salutation A", reps: 5, equipment: "bodyweight" },
                { name: "Warrior II hold each side", duration_s: 60, equipment: "bodyweight" },
                { name: "Pigeon each side", duration_s: 60, equipment: "bodyweight" },
                { name: "Bridge hold", duration_s: 45, equipment: "bodyweight" }
              ] },
            { name: "Savasana Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Savasana", duration_s: 120, notes: "5 deep breaths", equipment: "bodyweight" } ] }
          ]
        },
        {
          name: "Core Flow",
          goal: "Build quiet strength through a controlled pilates sequence.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up Flow", format: "straight", duration_mins: 3,
              exercises: [ { name: "Breath work + gentle spinal waves", duration_s: 180, equipment: "bodyweight" } ] },
            { name: "Pilates Core", format: "hundred",
              exercises: [ { name: "The Hundred", reps: 100, equipment: "bodyweight" } ] },
            { name: "Flow Rounds", format: "rounds", rest_secs: 30,
              exercises: [
                { name: "Boat pose", duration_s: 30, equipment: "bodyweight" },
                { name: "Plank hold", duration_s: 45, equipment: "bodyweight" },
                { name: "Side plank each side", duration_s: 30, equipment: "bodyweight" }
              ] },
            { name: "Savasana Cool-Down", format: "straight", duration_mins: 3,
              exercises: [ { name: "Savasana", duration_s: 180, notes: "5 deep breaths", equipment: "bodyweight" } ] }
          ]
        },
        {
          name: "Long Restore",
          goal: "A deep mobility session — open hips, shoulders, and spine, and finish still.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up Flow", format: "straight", duration_mins: 5,
              exercises: [ { name: "Cat-Cow + thoracic opening", duration_s: 300, equipment: "bodyweight" } ] },
            { name: "Hip Opening Flow", format: "straight", duration_mins: 15,
              exercises: [
                { name: "Low lunge each side", duration_s: 60, equipment: "bodyweight" },
                { name: "Pigeon each side", duration_s: 120, equipment: "bodyweight" },
                { name: "Happy Baby", duration_s: 60, equipment: "bodyweight" },
                { name: "Seated forward fold", duration_s: 120, equipment: "bodyweight" }
              ] },
            { name: "Upper Body Flow", format: "straight", duration_mins: 15,
              exercises: [
                { name: "Thread the Needle each side", duration_s: 60, equipment: "bodyweight" },
                { name: "Cobra", duration_s: 60, equipment: "bodyweight" },
                { name: "Child's Pose", duration_s: 60, equipment: "bodyweight" },
                { name: "Sphinx", duration_s: 90, equipment: "bodyweight" }
              ] },
            { name: "Savasana Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Savasana", duration_s: 300, notes: "10 deep breaths", equipment: "bodyweight" } ] }
          ]
        }
      ].freeze
    end
  end
end
