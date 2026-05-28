module LLMContext
  module Activities
    module DekaStrong
      SLUG = "deka-strong"
      NAME = "Deka Strong"

      CONTRACT = {
        purity: "Deka Strong training — no running. Strength-endurance and station capacity " \
                "via the 10 weighted functional zones. Most sessions use 4-6 stations with " \
                "supplementary movement work; full 10-zone sessions are valid but uncommon.",
        hybrid_family: true,
        allowed_equipment: %w[rowing_machine ski_erg assault_bike wall_ball sled kettlebells barbell dumbbells pull_up_bar resistance_bands],
        banned_equipment:  %w[treadmill jump_rope],
        banned_exercise_patterns: [
          /\btreadmill\b/i, /\brun(ning)?\b/i
        ].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred matrix mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        intensity_guide: {
          low:    "Zone-2 day for Deka Strong (no running). Rotate between FOUR shapes: (1) one long " \
                  "20+ min single-modality cardio block on Row / Ski / Bike, (2) stacked 10-min blocks " \
                  "(10 Row + 10 Ski + 10 Bike), (3) long continuous circuit (format: continuous_circuit, " \
                  "4-6 movements rotating 1 min each for 20-40 min — REACH FOR IT OFTEN, the engine " \
                  "builder), (4) long-interval cardio rounds (4 × 6 min Row, 30s rest). NO weights, NO " \
                  "EMOMs, NO Tabatas, NO sprints. Bookends at easy pace fit (10-min Row buy-in → main " \
                  "→ 10-min Ski cash-out). duration_mins on every main/finisher section must be a " \
                  "multiple of 5. Effort cue: easy, conversational, nose-breathing pace.",
          medium: "Working pace — strength + stations is the bread-and-butter Deka Strong session. " \
                  "Mix 30s/30s machine work with zone-station blocks at ~RPE 7-8. Reach for `format: " \
                  "emom` and `format: continuous_circuit` often. Strength is more common here than in " \
                  "the runnable Deka variants (this IS the strength-leaning event), but it's still not " \
                  "mandatory every session. When strength is included, placement can vary.",
          high:   "Race-day energy — strength block goes FIRST after warm-up (heavy 3-5 rep lifts, " \
                  "120-180s rest). Rotate the lift each session — Deadlift, Back Squat, Front Squat, " \
                  "Bench Press, Push Press, Clean & Jerk variants. Do NOT default to Bench. After the " \
                  "strength block, max-pace station work with long recovery. Prefer EMOMs over " \
                  "continuous_circuit. Use the 30s hard / 30s rest pattern for hard cardio. Pack LESS " \
                  "work — one main block fewer than medium."
        },
        notes: "No running. Build anaerobic capacity on ski erg, assault bike, or rower " \
               "instead — 30s hard/30s easy or 400m repeats. Stations: RAM Reverse Lunges, " \
               "Row, Box Jump, Med Ball Sit-up Throw, SkiErg, Farmer's Carry, Air Bike, " \
               "Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees. **Most sessions " \
               "use 4-6 stations** with supplementary movement work; full 10-zone sessions " \
               "are valid but uncommon — roughly 1 in 5 workouts."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Stations:          RAM Reverse Lunges, Row 500m, Box Jump, Med Ball Sit-up Throw, SkiErg 500m,
                           Farmer's Carry, Air Bike 25 cal, Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
        Engine:            Ski Erg 500m repeats, Rower 500m repeats, Assault Bike 30s/30s
      VOCAB

      # Canonical race-station exercises. Used by the validator to scope
      # race-relative wording ("race weight", "competition load") to actual
      # race movements — strength accessories like Deadlift get absolute
      # phrasing instead. Loose substring match, case-insensitive.
      RACE_STATIONS = [
        "RAM Reverse Lunges", "Row", "Box Jump", "Med Ball Sit-up Throw",
        "SkiErg", "Farmer's Carry", "Air Bike", "Dead Ball Yoke Over",
        "Sled Push", "Sled Pull", "RAM Weighted Burpees"
      ].freeze

      EXAMPLES = [
        {
          name: "Station Capacity",
          goal: "Single-exercise KB swing EMOM then a 30/30 row engine to finish.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "The Forge", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Swings", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" }
              ] },
            { name: "Row Sprint", format: "rounds", rounds: 12, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Engine & Iron",
          goal: "Triple-machine 30/30 engine block, a thruster EMOM, then a heavy deadlift accessory.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Row Sprint", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "Ski Sprint", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Bike Sprint", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Air Bike", duration_s: 30, notes: "hard pace", equipment: "assault_bike" }
              ] },
            { name: "The Minotaur", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Thrusters", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" }
              ] },
            { name: "Last Stand", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, notes: "heavy strength load — last rep should be a fight", equipment: "barbell" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Triple Machine Grind",
          goal: "Compromised cardio rounds, a med-ball sit-up throw EMOM grind, a rotating continuous circuit on row, KB swings and box step-overs, then a hundred to close.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Desert Rain", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Row", distance_m: 250, equipment: "rowing_machine" },
                { name: "RAM Reverse Lunges", reps: 20 },
                { name: "SkiErg", distance_m: 250, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 30, equipment: "sled" }
              ] },
            { name: "Throw Down", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "Med Ball Sit-up Throw", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" }
              ] },
            { name: "Strong Rotation", format: "continuous_circuit", duration_mins: 12,
              exercises: [
                { name: "Rowing Machine", equipment: "rowing_machine" },
                { name: "KB Swings", equipment: "kettlebells" },
                { name: "Box Step-overs", equipment: "bodyweight" }
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
          goal: "Compromised cardio on the rower, an alternating EMOM of Box Jump and RAM Reverse Lunges, and a tabata burner to close.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Row Repeats", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Row", distance_m: 500, equipment: "rowing_machine" },
                { name: "Med Ball Sit-up Throw", reps: 20, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 30, equipment: "kettlebells" }
              ] },
            { name: "Box Cycle", format: "emom", duration_mins: 16, period_mins: 2, rest_secs: 0,
              exercises: [
                { name: "Box Jump",            reps: 12, equipment: "bodyweight" },
                { name: "RAM Reverse Lunges",  reps: 20, equipment: "bodyweight" },
                { name: "KB Swings",           reps: 15, equipment: "kettlebells" }
              ] },
            { name: "Burpee Bash", format: "tabata",
              exercises: [
                { name: "RAM Weighted Burpees", equipment: "bodyweight" },
                { name: "Sit-ups", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Carry Day",
          goal: "30/30 ski engine, a heavy carry-and-sled triplet, a single-exercise Med Ball Sit-up Throw grind, and a hundred Box Jumps to finish.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Engine Build", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Three Carries", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Farmer's Carry", distance_m: 60, equipment: "kettlebells" },
                { name: "Sled Push", distance_m: 40, notes: "race weight — full competition sled", equipment: "sled" },
                { name: "Sled Pull", distance_m: 20, notes: "race weight — full competition sled", equipment: "sled" }
              ] },
            { name: "Throw Down", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "Med Ball Sit-up Throw", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" }
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
          name: "Zone Descent",
          goal: "One long machine-broken descending pyramid — rower, SkiErg and Air Bike between tiers of Med Ball Sit-up Throw, Sled Push and RAM Reverse Lunges, four tiers down.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Down the Zones", format: "for_time",
              exercises: [
                { name: "Row", distance_m: 500, equipment: "rowing_machine" },
                { name: "Med Ball Sit-up Throw", reps: 80, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 80, notes: "race weight — full competition sled across all tiers", equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 80 },
                { name: "SkiErg", distance_m: 500, equipment: "ski_erg" },
                { name: "Med Ball Sit-up Throw", reps: 60, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 60, equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 60 },
                { name: "Air Bike", calories: 25, equipment: "assault_bike" },
                { name: "Med Ball Sit-up Throw", reps: 40, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 40, notes: "race weight — full competition sled", equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 40 },
                { name: "Row", distance_m: 500, equipment: "rowing_machine" },
                { name: "Med Ball Sit-up Throw", reps: 20, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 20, equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 20 }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Steady Ski",
          goal: "A long continuous zone 2 ski, a hip mobility flow, light Deka technique stations, then a quiet cool-down — mobility woven into the main session.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy bike + Deka mobility prep", duration_s: 300, notes: "90/90 hip switches, ankle circles, dynamic lunges, thoracic open books", equipment: "assault_bike" }
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
                { name: "RAM Reverse Lunges", reps: 20, notes: "deliberate, controlled descent, focus on knee tracking" },
                { name: "Box Jump", reps: 15, notes: "soft landings, full hip extension at the top", equipment: "bodyweight" },
                { name: "Farmer's Carry", distance_m: 30, notes: "light load — well below race weight, tall posture, breath stays calm", equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Row Day",
          goal: "A steady row, a T-spine mobility flow, an easy circuit with mobility woven into each round, then a quiet cool-down.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy ski + Deka mobility prep", duration_s: 300, notes: "thoracic open books, cat-cow, world's greatest stretch", equipment: "ski_erg" }
              ] },
            { name: "Steady Row", format: "straight", duration_mins: 25,
              exercises: [
                { name: "Row", duration_s: 1500, notes: "easy aerobic pace — sustain the same effort the whole way, breath stays calm", equipment: "rowing_machine" }
              ] },
            { name: "T-spine Flow", format: "straight", duration_mins: 4,
              exercises: [
                { name: "Foam Roller Thoracic Extensions", duration_s: 120, notes: "slow controlled extensions over a foam roller" },
                { name: "Thoracic Open Books", duration_s: 60, notes: "T-spine rotation — 30s per side, breath into each rep" },
                { name: "Cat-Cow", duration_s: 60, notes: "spinal articulation, breath into each phase" }
              ] },
            { name: "Easy Circuit", format: "rounds", rounds: 4, rest_secs: 30,
              exercises: [
                { name: "Med Ball Sit-up Throw", reps: 20, notes: "light ball — well below race weight, smooth throw mechanics, full sit-up", equipment: "wall_ball" },
                { name: "World's Greatest Stretch", duration_s: 60, notes: "30s per side, full breath into the rotation" },
                { name: "Wall Balls", reps: 20, notes: "light ball — well below race weight, controlled tempo, full range", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Strong Engine",
          goal: "Heavy deadlift triples, all-out row sprint repeats, heavy sled work, then a tabata finisher. Full recovery between every set.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Heavy Pull", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Deadlift", reps: 3, notes: "near-max strength load — last rep should be a fight", equipment: "barbell" }
              ] },
            { name: "Row Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "Row", calories: 15, notes: "all-out — every rep is maximum effort, full recovery between", equipment: "rowing_machine" }
              ] },
            { name: "Heavy Sled", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Sled Push", distance_m: 20, notes: "heavier than race weight — above competition load, drive 20m without breaking", equipment: "sled" }
              ] },
            { name: "Tabata Cooker", format: "tabata",
              exercises: [
                { name: "RAM Weighted Burpees", equipment: "bodyweight" },
                { name: "Sit-ups", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Iron Strong",
          goal: "Heavy push press, all-out air bike sprints, sled sprints, then a tabata burner. Short, sharp, full-recovery work.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Heavy Press", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Push Press", reps: 3, notes: "near-max strength load — full recovery between sets", equipment: "barbell" }
              ] },
            { name: "Bike Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "Air Bike", calories: 15, notes: "all-out — every rep is maximum, full recovery between", equipment: "assault_bike" }
              ] },
            { name: "Sled Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "Sled Push", distance_m: 15, notes: "heavier than race weight — sprint with the sled, heavy but fast", equipment: "sled" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "Box Jump", equipment: "bodyweight" },
                { name: "Med Ball Slams", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Strong Murph",
          goal: "Deka Strong-flavoured Murph — matched-cardio bookends around a chipper of 100 med ball sit-up throws, 200 RAM weighted burpees, and 300 RAM reverse lunges. No running, all stations.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Buy In", format: "for_time",
              exercises: [
                { name: "Row", distance_m: 1000, notes: "race pace — set the tone for the work ahead", equipment: "rowing_machine" }
              ] },
            { name: "Heart of Steel", format: "for_time",
              exercises: [
                { name: "Med Ball Sit-up Throw", reps: 100, equipment: "wall_ball" },
                { name: "RAM Weighted Burpees", reps: 200, equipment: "wall_ball" },
                { name: "RAM Reverse Lunges", reps: 300, equipment: "wall_ball" }
              ] },
            { name: "Cash Out", format: "for_time",
              exercises: [
                { name: "SkiErg", distance_m: 1000, notes: "everything left in the tank — race the clock home", equipment: "ski_erg" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Triple Engine",
          goal: "Row buy-in, five rotating triple-machine rounds with burpees between machines, a descending sled ladder, then a SkiErg cash-out. Three engines, two bookends — no running.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Buy In", format: "for_time",
              exercises: [
                { name: "Row", distance_m: 1000, notes: "race pace — set the tone, don't sandbag", equipment: "rowing_machine" }
              ] },
            { name: "Engine Block", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "SkiErg", distance_m: 100, equipment: "ski_erg" },
                { name: "Burpees", reps: 10, equipment: "bodyweight" },
                { name: "Row", distance_m: 200, equipment: "rowing_machine" },
                { name: "Burpees", reps: 10, equipment: "bodyweight" },
                { name: "Air Bike", calories: 15, equipment: "assault_bike" },
                { name: "Burpees", reps: 10, equipment: "bodyweight" }
              ] },
            { name: "Sled Stairs", format: "ladder",
              varies: "distance_m", start: 50, end: 10, step: 10, rest_between_rungs: 30,
              exercises: [
                { name: "Sled Push", notes: "race weight — full Deka competition sled", equipment: "sled" },
                { name: "Sled Pull", notes: "race weight — full Deka competition sled", equipment: "sled" }
              ] },
            { name: "Cash Out", format: "for_time",
              exercises: [
                { name: "SkiErg", distance_m: 1000, notes: "everything left in the tank — race the clock home", equipment: "ski_erg" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Med Ball Mountain",
          goal: "Five rotating triple-machine rounds with burpees between machines, then a med ball sit-up throw mountain — 250 reps up and down. Compromised cardio into a single grinder.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Engine Block", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "SkiErg", distance_m: 100, equipment: "ski_erg" },
                { name: "Burpees", reps: 10, equipment: "bodyweight" },
                { name: "Row", distance_m: 200, equipment: "rowing_machine" },
                { name: "Burpees", reps: 10, equipment: "bodyweight" },
                { name: "Air Bike", calories: 15, equipment: "assault_bike" },
                { name: "Burpees", reps: 10, equipment: "bodyweight" }
              ] },
            { name: "Mountain Climb", format: "mountain",
              varies: "reps", start: 10, peak: 50, end: 10, step: 10, rest_between_rungs: 10,
              exercises: [ { name: "Med Ball Sit-up Throw", equipment: "wall_ball" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Machine Heavy",
          goal: "Three rounds of row-sled-row-sled, a 12-min med ball sit-up throw EMOM, a 30/30 SkiErg engine, then 100 RAM reverse lunges to close. No running, all machines and stations.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Long Loops", format: "rounds", rounds: 3, rest_secs: 60,
              exercises: [
                { name: "Row", distance_m: 500, equipment: "rowing_machine" },
                { name: "Sled Push", distance_m: 25, notes: "race weight — full Deka competition sled", equipment: "sled" },
                { name: "Row", distance_m: 500, equipment: "rowing_machine" },
                { name: "Sled Pull", distance_m: 25, notes: "race weight — full Deka competition sled", equipment: "sled" }
              ] },
            { name: "Med Ball Window", format: "emom", duration_mins: 12, rest_secs: 0,
              exercises: [
                { name: "Med Ball Sit-up Throw", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" }
              ] },
            { name: "Ski Engine", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "The Long Walk", format: "hundred",
              exercises: [
                { name: "RAM Reverse Lunges", reps: 100, equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Engine Builder",
          goal: "A long zone 2 chipper — two rounds of long row / long ski / med ball sit-up throws / bike / row / RAM reverse lunges. Conversational pace throughout, all machine cardio.",
          duration_mins: 90,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy cardio + Deka mobility prep", duration_s: 300, notes: "90/90 hip switches, ankle circles, thoracic open books, world's greatest stretch", equipment: "ski_erg" }
              ] },
            { name: "Two Loops", format: "rounds", rounds: 2, rest_secs: 300,
              exercises: [
                { name: "Row", distance_m: 2000, notes: "conversational pace — nose-breathing where possible, building aerobic engine", equipment: "rowing_machine" },
                { name: "SkiErg", distance_m: 1000, notes: "easy aerobic pace — sustain the same effort the whole way", equipment: "ski_erg" },
                { name: "Med Ball Sit-up Throw", reps: 50, notes: "light ball — well below race weight, controlled tempo, full range", equipment: "wall_ball" },
                { name: "Air Bike", calories: 50, notes: "conversational pace — breath stays calm", equipment: "assault_bike" },
                { name: "Row", distance_m: 1000, notes: "easy aerobic pace", equipment: "rowing_machine" },
                { name: "RAM Reverse Lunges", reps: 50, notes: "deliberate steps, focus on knee tracking", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Living in America",
          goal: "A descending row ladder, a 20-min AMRAP on ski / med ball sit-up throws / row / RAM reverse lunges, accessory strength on bench and split squats, then a RAM weighted burpee tabata to close.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Row Stairs", format: "ladder",
              varies: "distance_m", start: 1000, end: 200, step: 200, rest_between_rungs: 30,
              exercises: [ { name: "Row", notes: "hard pace", equipment: "rowing_machine" } ] },
            { name: "Engine Hunt", format: "amrap", duration_mins: 20, rest_secs: 0,
              exercises: [
                { name: "SkiErg", distance_m: 400, equipment: "ski_erg" },
                { name: "Med Ball Sit-up Throw", reps: 20, equipment: "wall_ball" },
                { name: "Row", distance_m: 400, equipment: "rowing_machine" },
                { name: "RAM Reverse Lunges", reps: 20, equipment: "wall_ball" }
              ] },
            { name: "Strength Block", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "DB Bench Press", reps: 8, notes: "working weight — last 2 reps should be a fight", equipment: "dumbbells" },
                { name: "Split Squat", reps: 8, notes: "8 per leg — controlled tempo, knee tracks toe", equipment: "dumbbells" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "RAM Weighted Burpees", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
