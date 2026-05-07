module LLMContext
  module Activities
    module HybridRace
      SLUG = "hybrid-race"
      NAME = "Hybrid Race"

      CONTRACT = {
        purity: "Hybrid race-prep training — treadmill running intervals alternating with " \
                "weighted functional stations. Builds the engine and station capacity for " \
                "any run-and-stations race format. Each session draws freely from a wide " \
                "library of stations rather than locking into a fixed event shape.",
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike sled wall_ball kettlebells barbell dumbbells pull_up_bar],
        banned_equipment:  %w[resistance_bands jump_rope],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred matrix mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "Every session should include at least 2 treadmill running intervals " \
               "(400m–1km each) placed between station blocks. Stations draw from a wide " \
               "library: Sled Push/Pull, SkiErg, Rowing, Air Bike, Farmer's Carry, Wall " \
               "Balls, Sandbag Lunges, RAM Reverse Lunges, Box Jump, Med Ball Sit-up Throw, " \
               "Dead Ball Yoke Over, Burpee Broad Jumps, Weighted Burpees. Mix freely — " \
               "most sessions use 4-6 stations, not all of them. **Include 1-2 supplementary " \
               "movements** (KB Swings, KB Thrusters, Walking Lunges, Jump Squats, Push-ups, " \
               "Med Ball Slams, KB Shoulder Press, burpee variations like Box Jump Burpees) " \
               "for variety. " \
               "STRENGTH ACCESSORY (most sessions): include one strength accessory block — " \
               "rounds format, 3-6 reps heavy at 120s rest with intensity_style: high, " \
               "OR 8-10 reps moderate at 90s rest. Draw from the Strength accessory line " \
               "(Deadlift, Bench Press, Push Press, Bent-Over Row, Pull-ups, Bulgarian Split " \
               "Squat). Heavy compound work alongside the run-and-station shape is what " \
               "makes hybrid training. Never more than one strength block per session, " \
               "never the centrepiece, and never replaces a run or a station. " \
               "DURATION INTERVALS: a 3-4 round work-rest block on a single conditioning " \
               "movement (Wall Balls, Burpees, Walking Lunges, KB Swings, Med Ball Slams) " \
               "is a valid alternative to rep-based rounds — use rounds format with " \
               "duration_s: 120 and rest_secs: 120 for the canonical 2-min work / 2-min " \
               "rest shape. The clean-minute rule applies only to cardio machines, not " \
               "to these functional movements. " \
               "An abs finisher (sit-ups, leg raises, planks, V-ups, Russian twists) is a " \
               "good optional close-out."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Running:           Treadmill 400m, 500m, 1km repeats
        Stations:          Sled Push/Pull, SkiErg, Rowing Machine, Air Bike, Farmer's Carry,
                           Wall Balls, Sandbag Lunges, RAM Reverse Lunges, Box Jump,
                           Med Ball Sit-up Throw, Dead Ball Yoke Over, Burpee Broad Jumps,
                           Weighted Burpees
        Supplementary:     KB Swings, KB Thrusters, KB High Pull, Walking Lunges, Jump Squats,
                           Push-ups, Med Ball Slams, KB Shoulder Press
        Strength accessory: Bench Press, Deadlift, Romanian Deadlift, Sumo Deadlift, Single-Leg Deadlift, Split Squat, Bulgarian Split Squat, B-stance Squat, B-stance Deadlift, Landmine Press, Landmine Row, Push Press, Bent-Over Row, Pull-ups, Chin-ups, Dips, Toes-to-bar (most sessions — max 1 strength round, never the main work)
        Burpee variations: Box Jump Burpees, Wall Ball Burpees, KB Burpees, Burpee Broad Jumps
        Abs finisher:      Sit-ups, Leg Raises, Plank, V-ups, Russian Twists, Hollow Holds
      VOCAB

      EXAMPLES = [
        {
          name: "Sprint & Stations",
          goal: "Short and sharp — alternating runs with two functional stations.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Hammer Time", format: "rounds", rounds: 4, rest_secs: 30,
              exercises: [
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Sled Push", distance_m: 15, equipment: "sled" },
                { name: "Wall Balls", reps: 15, equipment: "wall_ball" }
              ] },
            { name: "Cooked", format: "for_time",
              exercises: [ { name: "Burpee Broad Jumps", reps: 75, equipment: "bodyweight" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Run + Mixed Stations",
          goal: "Run repeats followed by a mixed station circuit — three movements drawn from across the race library.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Engine Builder", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [ { name: "Run", distance_m: 500, notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Heavy Hands", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "RAM Reverse Lunges", reps: 12 },
                { name: "KB Thrusters", reps: 12, equipment: "kettlebells" },
                { name: "Wall Balls", reps: 12, equipment: "wall_ball" }
              ] },
            { name: "Walking Lunge Burner", format: "rounds", intensity_style: "medium", rounds: 3, rest_secs: 120,
              exercises: [ { name: "Walking Lunges", duration_s: 120, equipment: "bodyweight" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Long Hybrid",
          goal: "Run-station circuit, mixed strength stations, and an abs close — full hybrid feel.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Tip of the Spear", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Sled Push", distance_m: 15, equipment: "sled" },
                { name: "Sandbag Lunges", distance_m: 20, equipment: "sled" }
              ] },
            { name: "Iron Storm", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "RAM Reverse Lunges", reps: 12 },
                { name: "KB Thrusters", reps: 12, equipment: "kettlebells" },
                { name: "Box Jump Burpees", reps: 12, equipment: "bodyweight" }
              ] },
            { name: "Gut Check", format: "rounds", rounds: 3, rest_secs: 30,
              exercises: [
                { name: "V-ups", reps: 20, equipment: "bodyweight" },
                { name: "Russian Twists", reps: 20, equipment: "bodyweight" },
                { name: "Plank", duration_s: 45, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
