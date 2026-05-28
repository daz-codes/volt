module LLMContext
  module Activities
    module DekaAtlas
      SLUG = "deka-atlas"
      NAME = "Deka Atlas"

      CONTRACT = {
        purity: "Deka Atlas race training — ten strongman-style weighted stations, no " \
                "running. Barbell and dumbbell work feature alongside classic carries.",
        hybrid_family: true,
        allowed_equipment: %w[barbell dumbbells kettlebells sled jump_rope rowing_machine ski_erg assault_bike resistance_bands],
        banned_equipment:  %w[treadmill wall_ball pull_up_bar],
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
          low:    "Zone-2 day for Deka Atlas (no running; loaded stations are by definition not easy). " \
                  "Rotate between FOUR shapes: (1) one long 20+ min easy-pace Row, Ski, or Bike block, " \
                  "(2) stacked 10-min blocks (10 Row + 10 Ski + 10 Bike at easy pace), (3) long " \
                  "continuous circuit (format: continuous_circuit, 4-6 BODYWEIGHT/light movements " \
                  "rotating 1 min each for 20-40 min, no rest — REACH FOR IT OFTEN), (4) long-interval " \
                  "cardio rounds (4 × 6 min Row, 30s rest). NO weights, NO EMOMs, NO Tabatas, NO " \
                  "sprints, NO loaded station work (the heavy strongman movements are NEVER zone-2). " \
                  "Bookends at easy pace fit (10-min Row buy-in → main → 10-min Ski cash-out). " \
                  "duration_mins on every main/finisher section must be a multiple of 5. Effort cue: " \
                  "easy, conversational, nose-breathing pace.",
          medium: "Working pace — strongman stations + jump rope conditioning. Reach for `format: emom` " \
                  "and `format: continuous_circuit` often. Bookends fit (DB or barbell movement as buy-" \
                  "in/cash-out works too — '50 Barbell Thrusters' bookends). Strength is more central " \
                  "to Deka Atlas than to other Deka variants (everything is loaded), but it's still " \
                  "not mandatory in every session — pure metcon sessions are fine. When strength is " \
                  "included, placement can vary.",
          high:   "Race-day energy — strength block goes FIRST after warm-up (heavy 3-5 rep Barbell " \
                  "Thrusters, Deadlift, DB Push Press, or other compound lifts; 120-180s rest). " \
                  "Rotate the lift each session — do NOT default to Bench. After the strength block, " \
                  "max-pace station work with long recovery. Prefer EMOMs over continuous_circuit. " \
                  "Jump Rope is the canonical cardio modality (Single or Double Unders) — sprint " \
                  "intervals on the machines are not for Atlas at high intensity. Pack LESS total " \
                  "work — one main block fewer than medium — so transitions are unhurried."
        },
        notes: "Stations: Barbell Thrusters, Bar-Facing Burpees Over Bar, Surrender " \
               "Lunges (weighted), Single Arm DB Ground to Overhead, Dumbbell Bear Crawl, " \
               "Weighted Sit-ups, Farmer's Carry, DB Shoulder to Overhead Press, Jump Rope " \
               "Single Unders, Atlas Shoulder to Carry. No running. **Jump rope is the ONLY " \
               "main-block cardio modality for medium and high intensity sessions** — never " \
               "row/ski/bike sprint sets at those intensities, only Jump Rope (Single or " \
               "Double Unders). Machines (row/ski/bike) appear in warm-ups and the long " \
               "continuous zone 2 cardio block at LOW intensity — that is the ONE exception, " \
               "because zone 2 base building benefits from machine variety. Pair heavy " \
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

      # Canonical race-station exercises. Used by the validator to scope
      # race-relative wording ("race weight", "competition load") to actual
      # race movements — accessories get absolute phrasing instead.
      # Loose substring match, case-insensitive.
      RACE_STATIONS = [
        "Thruster", "Bar-Facing Burpee", "Burpee Over Bar",
        "Single Arm DB Ground to Overhead", "DB Ground to Overhead",
        "DB Shoulder to Overhead", "Shoulder to Overhead Press",
        "Bear Crawl", "Farmer's Carry", "Atlas Shoulder to Carry",
        "Surrender Lunges", "Weighted Sit-ups", "Jump Rope", "Single Under"
      ].freeze

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
            { name: "Strongman Cycle", format: "emom", duration_mins: 16, period_mins: 2, rest_secs: 0,
              exercises: [
                { name: "Surrender Lunges", reps: 12, notes: "race weight DB — 6 per leg", equipment: "dumbbells" },
                { name: "Single Arm DB Ground to Overhead", reps: 10, notes: "5 per side, race weight DB", equipment: "dumbbells" },
                { name: "Weighted Sit-ups", reps: 15, equipment: "dumbbells" }
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
                { name: "Sled Push", distance_m: 40, notes: "race weight — full competition sled", equipment: "sled" },
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
                { name: "Surrender Lunges", reps: 12, notes: "light DB or unweighted — well below race weight, slow descent, full ground contact, drive through the front foot, focus on knee tracking", equipment: "dumbbells" },
                { name: "Weighted Sit-ups", reps: 15, notes: "light load — well below race weight, controlled tempo, full range, anchor the feet, smooth transition", equipment: "dumbbells" },
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
                { name: "Goblet Squat", reps: 10, notes: "light KB — well below race weight, 3-second eccentric, full depth, knees track over toes, no rushing", equipment: "kettlebells" },
                { name: "Wall Slides", duration_s: 60, notes: "shoulder and T-spine mobility — slow controlled overhead reach, ribs stay down" },
                { name: "DB Shoulder to Overhead Press", reps: 10, notes: "light DBs — well below race weight, strict press, no leg drive, focus on lockout and controlled descent", equipment: "dumbbells" }
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
                { name: "Sled Push", distance_m: 20, notes: "heavier than race weight — above competition load, drive 20m without breaking", equipment: "sled" }
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
          goal: "Heavy DB shoulder-to-overhead press, all-out jump rope sprints, heavy atlas carry sprints, then a tabata burner. Short, sharp, full-recovery work.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Heavy Press", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "DB Shoulder to Overhead Press", reps: 5, notes: "near-max heavy DBs — full recovery between sets", equipment: "dumbbells" }
              ] },
            { name: "Rope Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 30, notes: "max speed — every 30s is maximum, full recovery between", equipment: "jump_rope" }
              ] },
            { name: "Atlas Carry Sprints", format: "rounds", rounds: 5, rest_secs: 90,
              exercises: [
                { name: "Atlas Shoulder to Carry", distance_m: 25, notes: "heavier than race weight — sprint with the carry, no walking", equipment: "sled" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "Surrender Lunges", equipment: "dumbbells" },
                { name: "Weighted Sit-ups", equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Atlas Murph",
          goal: "Strongman Murph — jump rope bookends around a chipper of 100 weighted sit-ups, 200 bar-facing burpees, and 300 surrender lunges. Pure stations, brutal volume.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Buy In", format: "for_time",
              exercises: [
                { name: "Jump Rope Single Unders", reps: 200, notes: "race pace — set the tone for the work ahead", equipment: "jump_rope" }
              ] },
            { name: "Heart of Steel", format: "for_time",
              exercises: [
                { name: "Weighted Sit-ups", reps: 100, equipment: "dumbbells" },
                { name: "Bar-Facing Burpees Over Bar", reps: 200, equipment: "barbell" },
                { name: "Surrender Lunges", reps: 300, equipment: "dumbbells" }
              ] },
            { name: "Cash Out", format: "for_time",
              exercises: [
                { name: "Jump Rope Single Unders", reps: 200, notes: "everything left in the tank — race the clock home", equipment: "jump_rope" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Triple Engine",
          goal: "Jump rope buy-in, five rotating jump-rope-and-carry rounds with bar-facing burpees between movements, a descending sled ladder, then a jump rope cash-out. Strongman station capacity.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Buy In", format: "for_time",
              exercises: [
                { name: "Jump Rope Single Unders", reps: 200, notes: "race pace — set the tone, don't sandbag", equipment: "jump_rope" }
              ] },
            { name: "Engine Block", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 60, equipment: "jump_rope" },
                { name: "Bar-Facing Burpees Over Bar", reps: 5, equipment: "barbell" },
                { name: "Farmer's Carry", distance_m: 30, notes: "race weight — Deka Atlas competition load", equipment: "dumbbells" },
                { name: "Bar-Facing Burpees Over Bar", reps: 5, equipment: "barbell" },
                { name: "Atlas Shoulder to Carry", distance_m: 30, notes: "race weight — competition load", equipment: "sled" },
                { name: "Bar-Facing Burpees Over Bar", reps: 5, equipment: "barbell" }
              ] },
            { name: "Sled Stairs", format: "ladder",
              varies: "distance_m", start: 50, end: 10, step: 10, rest_between_rungs: 30,
              exercises: [
                { name: "Sled Push", notes: "race weight — full Deka Atlas competition sled", equipment: "sled" },
                { name: "Sled Pull", notes: "race weight — full Deka Atlas competition sled", equipment: "sled" }
              ] },
            { name: "Cash Out", format: "for_time",
              exercises: [
                { name: "Jump Rope Single Unders", reps: 200, notes: "everything left in the tank — race the clock home", equipment: "jump_rope" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Sit-up Mountain",
          goal: "Five rotating jump-rope-and-carry rounds with bar-facing burpees between movements, then a weighted sit-up mountain — 250 reps up and down.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Engine Block", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 60, equipment: "jump_rope" },
                { name: "Bar-Facing Burpees Over Bar", reps: 5, equipment: "barbell" },
                { name: "Farmer's Carry", distance_m: 30, notes: "race weight — Deka Atlas competition load", equipment: "dumbbells" },
                { name: "Bar-Facing Burpees Over Bar", reps: 5, equipment: "barbell" },
                { name: "Atlas Shoulder to Carry", distance_m: 30, notes: "race weight — competition load", equipment: "sled" },
                { name: "Bar-Facing Burpees Over Bar", reps: 5, equipment: "barbell" }
              ] },
            { name: "Mountain Climb", format: "mountain",
              varies: "reps", start: 10, peak: 50, end: 10, step: 10, rest_between_rungs: 10,
              exercises: [ { name: "Weighted Sit-ups", equipment: "dumbbells" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Carry Heavy",
          goal: "Three rounds of carry-sled-carry-sled, a 12-min weighted sit-up EMOM, a 30/30 jump rope engine, then 100 surrender lunges to close. Strongman density.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Long Loops", format: "rounds", rounds: 3, rest_secs: 60,
              exercises: [
                { name: "Farmer's Carry", distance_m: 100, notes: "race weight — Deka Atlas competition load", equipment: "dumbbells" },
                { name: "Sled Push", distance_m: 25, notes: "race weight — full Deka Atlas competition sled", equipment: "sled" },
                { name: "Atlas Shoulder to Carry", distance_m: 100, notes: "race weight — competition load", equipment: "sled" },
                { name: "Sled Pull", distance_m: 25, notes: "race weight — full Deka Atlas competition sled", equipment: "sled" }
              ] },
            { name: "Sit-up Window", format: "emom", duration_mins: 12, rest_secs: 0,
              exercises: [
                { name: "Weighted Sit-ups", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "dumbbells" }
              ] },
            { name: "Rope Engine", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Jump Rope Single Unders", duration_s: 30, notes: "hard pace", equipment: "jump_rope" }
              ] },
            { name: "The Long Walk", format: "hundred",
              exercises: [
                { name: "Surrender Lunges", reps: 100, equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Engine Builder",
          goal: "A long zone 2 chipper — two rounds of long row / long ski / weighted sit-ups / bike / row / surrender lunges. Conversational pace throughout, machine cardio (allowed at low intensity).",
          duration_mins: 90,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy cardio + Deka mobility prep", duration_s: 300, notes: "90/90 hip switches, ankle circles, thoracic open books, world's greatest stretch", equipment: "rowing_machine" }
              ] },
            { name: "Two Loops", format: "rounds", rounds: 2, rest_secs: 300,
              exercises: [
                { name: "Row", distance_m: 2000, notes: "conversational pace — nose-breathing where possible, building aerobic engine", equipment: "rowing_machine" },
                { name: "SkiErg", distance_m: 1000, notes: "easy aerobic pace — sustain the same effort the whole way", equipment: "ski_erg" },
                { name: "Weighted Sit-ups", reps: 50, notes: "light load — well below race weight, controlled tempo, full range", equipment: "dumbbells" },
                { name: "Air Bike", calories: 50, notes: "conversational pace — breath stays calm", equipment: "assault_bike" },
                { name: "Row", distance_m: 1000, notes: "easy aerobic pace", equipment: "rowing_machine" },
                { name: "Surrender Lunges", reps: 50, notes: "deliberate steps, focus on knee tracking", equipment: "dumbbells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Living in America",
          goal: "A descending jump rope ladder, a 20-min AMRAP on jump rope / weighted sit-ups / bar-facing burpees / surrender lunges, accessory strength on bench and split squats, then a bar-facing burpee tabata.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Rope Stairs", format: "ladder",
              varies: "reps", start: 200, end: 50, step: 50, rest_between_rungs: 30,
              exercises: [ { name: "Jump Rope Single Unders", notes: "hard pace", equipment: "jump_rope" } ] },
            { name: "Engine Hunt", format: "amrap", duration_mins: 20, rest_secs: 0,
              exercises: [
                { name: "Jump Rope Single Unders", reps: 100, equipment: "jump_rope" },
                { name: "Weighted Sit-ups", reps: 20, equipment: "dumbbells" },
                { name: "Bar-Facing Burpees Over Bar", reps: 10, equipment: "barbell" },
                { name: "Surrender Lunges", reps: 20, equipment: "dumbbells" }
              ] },
            { name: "Strength Block", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "DB Bench Press", reps: 8, notes: "working weight — last 2 reps should be a fight", equipment: "dumbbells" },
                { name: "Split Squat", reps: 8, notes: "8 per leg — controlled tempo, knee tracks toe", equipment: "dumbbells" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "Bar-Facing Burpees Over Bar", equipment: "barbell" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
