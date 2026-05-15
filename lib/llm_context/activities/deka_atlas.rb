module LLMContext
  module Activities
    module DekaAtlas
      SLUG = "deka-atlas"
      NAME = "Deka Atlas"

      CONTRACT = {
        purity: "Deka Atlas race training — ten strongman-style weighted stations, no " \
                "running. Barbell and dumbbell work feature alongside classic carries.",
        hybrid_family: true,
        allowed_equipment: %w[barbell dumbbells kettlebells sled jump_rope rowing_machine ski_erg assault_bike],
        banned_equipment:  %w[treadmill wall_ball pull_up_bar resistance_bands],
        banned_exercise_patterns: [
          /\btreadmill\b/i, /\brun(ning)?\b/i
        ].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred matrix mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "Stations: Barbell Thrusters, Bar-Facing Burpees Over Bar, Surrender " \
               "Lunges (weighted), Single Arm DB Ground to Overhead, Dumbbell Bear Crawl, " \
               "Weighted Sit-ups, Farmer's Carry, DB Shoulder to Overhead Press, Jump Rope " \
               "Single Unders, Atlas Shoulder to Carry. No running. Jump rope (Single/Double " \
               "Unders) is the race-relevant cardio modality — machines exist for warm-up " \
               "and engine work but the race-station cardio is jump rope. Pair heavy " \
               "stations with machine conditioning to manage fatigue. The race stations " \
               "remain the headline movements, but workouts cannot be ONLY stations — every " \
               "session also needs supplementary work."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Barbell:           Thrusters, Bar-Facing Burpees Over Bar
        Dumbbell:          Single Arm DB Ground to Overhead, DB Shoulder to Overhead Press, Bear Crawl
        Carries:           Farmer's Carry, Atlas Shoulder to Carry
        Bodyweight:        Surrender Lunges (weighted), Weighted Sit-ups, Jump Rope Single Unders
      VOCAB

      EXAMPLES = [
        {
          name: "Atlas Awakens",
          goal: "Single-exercise bar-facing-burpee EMOM then a jump-rope 30/30 engine to finish.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Bar Burner", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Bar-Facing Burpees Over Bar", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "barbell" }
              ] },
            { name: "Skip & Smash", format: "rounds", rounds: 12, rest_secs: 30,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 30, notes: "hard pace", equipment: "jump_rope" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Heavy Metal",
          goal: "Single-exercise barbell thruster EMOM, a jump-rope 30/30 engine block, finished with Atlas carries.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "The Yoke", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Barbell Thrusters", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "barbell" }
              ] },
            { name: "Iron Will", format: "rounds", rounds: 20, rest_secs: 30,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 30, notes: "hard pace", equipment: "jump_rope" }
              ] },
            { name: "Carry the Weight", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Atlas Shoulder to Carry", distance_m: 50, equipment: "sled" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Power Hour",
          goal: "Compromised strongman rounds, a rotating continuous circuit on jump rope, DB press and weighted sit-ups, jump-rope 30/30, strength accessory, and a hundred to close.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "The Boulder", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 60, equipment: "jump_rope" },
                { name: "Atlas Shoulder to Carry", distance_m: 50, equipment: "sled" },
                { name: "DB Devil Press", reps: 12, equipment: "dumbbells" }
              ] },
            { name: "Strongman Rotation", format: "continuous_circuit", duration_mins: 12,
              exercises: [
                { name: "Jump Rope Single Unders", equipment: "jump_rope" },
                { name: "DB Shoulder to Overhead Press", equipment: "dumbbells" },
                { name: "Weighted Sit-ups", equipment: "dumbbells" }
              ] },
            { name: "Skip Sprint", format: "rounds", rounds: 16, rest_secs: 30,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 30, notes: "hard pace", equipment: "jump_rope" }
              ] },
            { name: "Iron Press", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "DB Shoulder to Overhead Press", reps: 5, equipment: "dumbbells" }
              ] },
            { name: "The Centurion", format: "hundred",
              exercises: [
                { name: "KB Swings", reps: 100, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Stations Stacked",
          goal: "Compromised strongman rounds, an alternating EMOM of Surrender Lunges and Single Arm DB Ground to Overhead, and a tabata burner to close.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Rope Repeats", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Jump Rope Single Unders", reps: 50, equipment: "jump_rope" },
                { name: "Bar-Facing Burpees Over Bar", reps: 20, equipment: "barbell" },
                { name: "Atlas Shoulder to Carry", distance_m: 50, equipment: "sled" }
              ] },
            { name: "Strongman Cycle", format: "emom", duration_mins: 16, rest_secs: 0, alternating: true,
              exercises: [
                { name: "Surrender Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "dumbbells" },
                { name: "Single Arm DB Ground to Overhead", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "dumbbells" }
              ] },
            { name: "Devil's Tabata", format: "tabata",
              exercises: [
                { name: "DB Devil Press", equipment: "dumbbells" },
                { name: "Weighted Sit-ups", equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Atlas Carry Day",
          goal: "30/30 jump rope engine, an Atlas carry-and-sled triplet, a single-exercise DB Shoulder to Overhead Press grind, and a hundred Box Jumps to finish.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Rope Build", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 30, notes: "hard pace", equipment: "jump_rope" }
              ] },
            { name: "Three Carries", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Atlas Shoulder to Carry", distance_m: 50, equipment: "sled" },
                { name: "Sled Push", distance_m: 40, equipment: "sled" },
                { name: "Farmer's Carry", distance_m: 60, equipment: "kettlebells" }
              ] },
            { name: "Press On", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "DB Shoulder to Overhead Press", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "dumbbells" }
              ] },
            { name: "Hundred Boxes", format: "hundred",
              exercises: [
                { name: "Box Jump", reps: 100, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Atlas Descent",
          goal: "One long rope-broken descending pyramid — Jump Rope Single Unders between tiers of Atlas Shoulder to Carry, Surrender Lunges and DB Shoulder to Overhead Press, four tiers down.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Down the Stack", format: "for_time",
              exercises: [
                { name: "Jump Rope Single Unders", reps: 50, equipment: "jump_rope" },
                { name: "Atlas Shoulder to Carry", distance_m: 50, equipment: "sled" },
                { name: "Surrender Lunges", reps: 40, equipment: "dumbbells" },
                { name: "DB Shoulder to Overhead Press", reps: 40, equipment: "dumbbells" },
                { name: "Jump Rope Single Unders", reps: 50, equipment: "jump_rope" },
                { name: "Atlas Shoulder to Carry", distance_m: 40, equipment: "sled" },
                { name: "Surrender Lunges", reps: 30, equipment: "dumbbells" },
                { name: "DB Shoulder to Overhead Press", reps: 30, equipment: "dumbbells" },
                { name: "Jump Rope Single Unders", reps: 50, equipment: "jump_rope" },
                { name: "Atlas Shoulder to Carry", distance_m: 30, equipment: "sled" },
                { name: "Surrender Lunges", reps: 20, equipment: "dumbbells" },
                { name: "DB Shoulder to Overhead Press", reps: 20, equipment: "dumbbells" },
                { name: "Jump Rope Single Unders", reps: 50, equipment: "jump_rope" },
                { name: "Atlas Shoulder to Carry", distance_m: 20, equipment: "sled" },
                { name: "Surrender Lunges", reps: 10, equipment: "dumbbells" },
                { name: "DB Shoulder to Overhead Press", reps: 10, equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Strongman Engine",
          goal: "A long zone 2 ski, hip mobility, and a technique-focused circuit with light loads — drill the strongman movement patterns cleanly, no max-effort work.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy row + Atlas mobility prep", duration_s: 300, notes: "90/90 hip switches, ankle circles, thoracic open books, world's greatest stretch", equipment: "rowing_machine" }
              ] },
            { name: "Long SkiErg", format: "straight", duration_mins: 25,
              exercises: [
                { name: "SkiErg", duration_s: 1500, notes: "conversational pace — nose-breathing where possible, building aerobic engine", equipment: "ski_erg" }
              ] },
            { name: "Hip Mobility", format: "straight", duration_mins: 5,
              exercises: [
                { name: "90/90 Hip Switches", duration_s: 120, notes: "60s per side, smooth controlled transitions" },
                { name: "Couch Stretch", duration_s: 120, notes: "60s per side, square hips, breath stays calm" },
                { name: "Hip CARs", duration_s: 60, notes: "both legs, full controlled range of motion" }
              ] },
            { name: "Technique Stations", format: "rounds", rounds: 3, rest_secs: 25,
              exercises: [
                { name: "Surrender Lunges", reps: 12, notes: "light DB or unweighted — slow descent, full ground contact, drive through the front foot, focus on knee tracking", equipment: "dumbbells" },
                { name: "Weighted Sit-ups", reps: 15, notes: "light load — controlled tempo, full range, anchor the feet, smooth transition", equipment: "dumbbells" },
                { name: "Bear Crawl", distance_m: 20, notes: "bodyweight — slow and controlled, hips low and stable, opposite hand-foot, no rotation through the hips", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Easy Strongman",
          goal: "A steady row, T-spine mobility, then a slow circuit of light-load strongman patterns — every rep is technique practice, not a workout.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy bike + Atlas mobility prep", duration_s: 300, notes: "thoracic open books, cat-cow, dynamic lunges", equipment: "assault_bike" }
              ] },
            { name: "Steady Row", format: "straight", duration_mins: 22,
              exercises: [
                { name: "Row", duration_s: 1320, notes: "easy aerobic pace — sustain the same effort the whole way, breath stays calm", equipment: "rowing_machine" }
              ] },
            { name: "T-spine Flow", format: "straight", duration_mins: 4,
              exercises: [
                { name: "Foam Roller Thoracic Extensions", duration_s: 120, notes: "slow controlled extensions over a foam roller" },
                { name: "Thoracic Open Books", duration_s: 60, notes: "T-spine rotation — 30s per side, breath into each rep" },
                { name: "Cat-Cow", duration_s: 60, notes: "spinal articulation, breath into each phase" }
              ] },
            { name: "Easy Circuit", format: "rounds", rounds: 4, rest_secs: 30,
              exercises: [
                { name: "Goblet Squat", reps: 10, notes: "light KB — 3-second eccentric, full depth, knees track over toes, no rushing", equipment: "kettlebells" },
                { name: "Wall Slides", duration_s: 60, notes: "shoulder and T-spine mobility — slow controlled overhead reach, ribs stay down" },
                { name: "DB Shoulder to Overhead Press", reps: 10, notes: "light DBs — strict press, no leg drive, focus on lockout and controlled descent", equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Atlas Power",
          goal: "Heavy barbell thruster triples, all-out jump rope sprints, heavy sled work, then a tabata finisher. Full recovery between every set.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Heavy Thrusters", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Barbell Thrusters", reps: 3, notes: "near-max — last rep should be a fight", equipment: "barbell" }
              ] },
            { name: "Jump Rope Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 30, notes: "max speed — every 30s is maximum, full recovery between", equipment: "jump_rope" }
              ] },
            { name: "Heavy Sled", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Sled Push", distance_m: 20, notes: "heaviest load you can drive 20m without breaking", equipment: "sled" }
              ] },
            { name: "Tabata Cooker", format: "tabata",
              exercises: [
                { name: "Bar-Facing Burpees Over Bar", equipment: "barbell" },
                { name: "DB Devil Press", equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Strongman Fire",
          goal: "Heavy DB shoulder-to-overhead press, all-out ski sprints, heavy atlas carry sprints, then a tabata burner. Short, sharp, full-recovery work.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Heavy Press", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "DB Shoulder to Overhead Press", reps: 5, notes: "near-max heavy DBs — full recovery between sets", equipment: "dumbbells" }
              ] },
            { name: "Ski Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "all-out — every 30s is maximum, full recovery between", equipment: "ski_erg" }
              ] },
            { name: "Atlas Carry Sprints", format: "rounds", rounds: 5, rest_secs: 90,
              exercises: [
                { name: "Atlas Shoulder to Carry", distance_m: 25, notes: "heavy load — sprint with the carry, no walking", equipment: "sled" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "Surrender Lunges", equipment: "dumbbells" },
                { name: "Weighted Sit-ups", equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
