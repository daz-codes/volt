module LLMContext
  module Activities
    module DekaFit
      SLUG = "deka-fit"
      NAME = "Deka Fit"

      CONTRACT = {
        purity: "Deka Fit race training — 10-zone event, 5 run zones alternating with " \
                "5 functional zones. Running is half the race (10 × 500m).",
        hybrid_family: true,
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike wall_ball sled kettlebells barbell dumbbells pull_up_bar resistance_bands],
        banned_equipment:  %w[jump_rope],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred matrix mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        intensity_guide: {
          low:    "Zone-2 day for Deka Fit prep. Rotate between FOUR shapes: (1) one long 20+ min " \
                  "single-modality block (Row / Ski / Bike / easy-pace treadmill), (2) stacked 10-min " \
                  "blocks across the race machines (Row + Ski + Bike), (3) long continuous circuit " \
                  "(format: continuous_circuit, 4-6 movements rotating 1 min each for 20-40 min, no " \
                  "rest — engine builder, REACH FOR IT OFTEN), (4) long-interval cardio rounds (4 × 6 " \
                  "min Row, 30s rest). NO weights, NO EMOMs, NO Tabatas, NO sprints. Bookends fit at " \
                  "easy pace (10-min Row buy-in → main → 10-min Ski cash-out). duration_mins on every " \
                  "main/finisher section must be a multiple of 5. Effort cue: easy, conversational, " \
                  "nose-breathing pace.",
          medium: "Race-prep working pace — most Deka Fit training lives here. Mix 500m treadmill runs " \
                  "with zone-station blocks at ~RPE 7-8. Reach for `format: emom` and `format: " \
                  "continuous_circuit` often. Bookends, AMRAPs, for-time chippers all fit. Strength is " \
                  "OPTIONAL — many medium sessions are pure zone-station metcon. When strength is " \
                  "included, placement can vary.",
          high:   "Race-day energy — strength block goes FIRST after warm-up (heavy 3-5 rep lifts, " \
                  "120-180s rest). Rotate the lift each session — do NOT default to Bench Press. " \
                  "After that, max-pace work with long recovery. Prefer EMOMs over continuous_circuit. " \
                  "Use the 30s hard / 30s rest pattern for hard cardio. Pack LESS total work — one main " \
                  "block fewer than medium — so transitions are unhurried."
        },
        notes: "MOST sessions include treadmill running intervals (200m–500m each) placed " \
               "between station blocks. **Compromised runs are STRICTLY ≤ 500m** — never " \
               "longer, because race-day Deka Fit run zones are 500m. Stations mirror the " \
               "race: RAM Reverse Lunges, Row, Box Jump, Med Ball Sit-up Throw, SkiErg, " \
               "Farmer's Carry, Air Bike, Dead Ball Yoke Over, Sled Push/Pull, Weighted " \
               "Burpees. When race_simulation? is true the builder sets finisher: :required " \
               "and the session covers all ten zones. The race stations remain the headline " \
               "movements, but workouts cannot be ONLY stations — every session also needs " \
               "supplementary work."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run zones:         Treadmill 500m
        Functional:        RAM Reverse Lunges, Row 500m, Box Jump / Step Over, Med Ball Sit-up Throw,
                           SkiErg 500m, Farmer's Carry, Air Bike 25 cal, Dead Ball Yoke Over,
                           Sled Push/Pull, RAM Weighted Burpees
      VOCAB

      # Canonical race-station exercises. Used by the validator to scope
      # race-relative wording ("race weight", "competition load") to actual
      # race movements — strength accessories like Deadlift get absolute
      # phrasing instead. Loose substring match, case-insensitive.
      RACE_STATIONS = [
        "Treadmill", "Run",
        "RAM Reverse Lunges", "Row", "Box Jump", "Step Over", "Med Ball Sit-up Throw",
        "SkiErg", "Farmer's Carry", "Air Bike", "Dead Ball Yoke Over",
        "Sled Push", "Sled Pull", "RAM Weighted Burpees"
      ].freeze

      EXAMPLES = [
        {
          name: "Wake the Dead",
          goal: "Alternating EMOM of box jumps and RAM lunges then a 30/30 ski engine to finish.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "The Anvil", format: "emom", duration_mins: 10, period_mins: 2, rest_secs: 0,
              exercises: [
                { name: "Box Jump",            reps: 10, equipment: "bodyweight" },
                { name: "RAM Reverse Lunges",  reps: 16, equipment: "bodyweight" },
                { name: "Med Ball Sit-up Throw", reps: 12, notes: "explosive throw at the top", equipment: "wall_ball" }
              ] },
            { name: "Ski Sprint", format: "rounds", rounds: 12, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Death March",
          goal: "Compromised running, a rotating continuous circuit on row, wall balls and box jumps, then a heavy deadlift accessory.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "The Crucible", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "RAM Reverse Lunges", reps: 20 },
                { name: "Med Ball Sit-up Throw", reps: 25, equipment: "wall_ball" }
              ] },
            { name: "Rotation Room", format: "continuous_circuit", duration_mins: 12,
              exercises: [
                { name: "Rowing Machine", equipment: "rowing_machine" },
                { name: "Med Ball Sit-up Throw", equipment: "wall_ball" },
                { name: "Box Jump", equipment: "bodyweight" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, notes: "heavy strength load — last rep should be a fight", equipment: "barbell" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Full Race",
          goal: "Simulate the full 10-zone Deka Fit race in one session.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Race Simulation", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "RAM Reverse Lunges", reps: 30 },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Row", distance_m: 500, equipment: "rowing_machine" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Box Jump / Step Over", reps: 20, equipment: "bodyweight" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 25 },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "SkiErg", distance_m: 500, equipment: "ski_erg" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Farmer's Carry", distance_m: 100, equipment: "kettlebells" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Air Bike", calories: 25, equipment: "assault_bike" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Dead Ball Yoke Over", reps: 20 },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "Sled Push / Pull", distance_m: 100, equipment: "sled" },
                { name: "Run", distance_m: 500, equipment: "treadmill" },
                { name: "RAM Weighted Burpees", reps: 20 }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Stations Stacked",
          goal: "Compromised running, an alternating EMOM of Box Jump and RAM Reverse Lunges, and a tabata burner to close.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Race Repeats", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 20, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 30, equipment: "kettlebells" }
              ] },
            { name: "Box Cycle", format: "emom", duration_mins: 16, rest_secs: 0, alternating: true,
              exercises: [
                { name: "Box Jump", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" },
                { name: "RAM Reverse Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)" }
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
          goal: "One long run-broken descending pyramid — 1km runs interleaved with Med Ball Sit-up Throw, Sled Push and RAM Reverse Lunges, four tiers down.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Down the Zones", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 80, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 80, notes: "race weight — full competition sled across all tiers", equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 80 },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 60, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 60, equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 60 },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 40, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 40, notes: "race weight — full competition sled", equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 40 },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 20, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 20, equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 20 }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Long Ski",
          goal: "A long continuous zone 2 ski, a T-spine mobility flow, light Deka technique stations, then a quiet cool-down — mobility woven through.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy treadmill walk + Deka mobility prep", duration_s: 300, notes: "thoracic open books, cat-cow, world's greatest stretch, ankle circles", equipment: "treadmill" }
              ] },
            { name: "Long SkiErg", format: "straight", duration_mins: 25,
              exercises: [
                { name: "SkiErg", duration_s: 1500, notes: "conversational pace — nose-breathing where possible, building aerobic engine", equipment: "ski_erg" }
              ] },
            { name: "T-spine Flow", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Foam Roller Thoracic Extensions", duration_s: 120, notes: "slow controlled extensions over a foam roller" },
                { name: "Thoracic Open Books", duration_s: 120, notes: "T-spine rotation — 60s per side, breath into each rep" },
                { name: "Cat-Cow", duration_s: 60, notes: "spinal articulation, breath into each phase" }
              ] },
            { name: "Technique Stations", format: "rounds", rounds: 4, rest_secs: 25,
              exercises: [
                { name: "Box Jump / Step Over", reps: 15, notes: "soft landings, full hip extension at the top", equipment: "bodyweight" },
                { name: "Med Ball Sit-up Throw", reps: 20, notes: "light ball — well below race weight, smooth throw mechanics, full sit-up", equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 30, notes: "light load — well below race weight, tall posture, breath stays calm", equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Easy Engine",
          goal: "A steady row, an ankle mobility flow, an easy circuit with mobility woven into each round, then a quiet cool-down.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy row + Deka mobility prep", duration_s: 300, notes: "ankle circles, calf stretches, dynamic lunges", equipment: "rowing_machine" }
              ] },
            { name: "Steady Row", format: "straight", duration_mins: 22,
              exercises: [
                { name: "Row", duration_s: 1320, notes: "easy aerobic pace — sustain the same effort the whole way, breath stays calm", equipment: "rowing_machine" }
              ] },
            { name: "Ankle Flow", format: "straight", duration_mins: 4,
              exercises: [
                { name: "Ankle Circles", duration_s: 60, notes: "both ankles, full range in both directions" },
                { name: "Calf Stretch", duration_s: 120, notes: "gastrocnemius and soleus — 60s per side" },
                { name: "Eccentric Calf Raises", duration_s: 60, notes: "controlled 3-second descent, bodyweight" }
              ] },
            { name: "Easy Circuit", format: "rounds", rounds: 4, rest_secs: 30,
              exercises: [
                { name: "RAM Reverse Lunges", reps: 20, notes: "deliberate steps, focus on knee tracking" },
                { name: "90/90 Hip Switches", duration_s: 60, notes: "smooth controlled transitions — 30s per side" },
                { name: "Med Ball Sit-up Throw", reps: 20, notes: "light ball — well below race weight, smooth throw mechanics, full sit-up", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Race Day Sharpener",
          goal: "Heavy deadlift triples, all-out 500m race-distance sprint repeats, heavy sled work, then a tabata finisher.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Heavy Pull", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Deadlift", reps: 3, notes: "near-max strength load — last rep should be a fight", equipment: "barbell" }
              ] },
            { name: "500m Sprints", format: "rounds", rounds: 5, rest_secs: 90,
              exercises: [
                { name: "Run", distance_m: 500, notes: "all-out at race distance — every rep is maximum effort", equipment: "treadmill" }
              ] },
            { name: "Heavy Sled", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Sled Push", distance_m: 25, notes: "heavier than race weight — above competition load, drive 25m without breaking", equipment: "sled" }
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
          name: "Power Hour",
          goal: "Heavy bench press, all-out air bike sprint repeats, heavy farmer's carries, then a tabata burner. Short, sharp, full-recovery work.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Heavy Press", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Bench Press", reps: 3, notes: "near-max strength load — full recovery between sets", equipment: "barbell" }
              ] },
            { name: "Air Bike Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "Air Bike", calories: 15, notes: "all-out — every rep is maximum, full recovery between", equipment: "assault_bike" }
              ] },
            { name: "Heavy Carry", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Farmer's Carry", distance_m: 40, notes: "heaviest load you can carry the full distance unbroken", equipment: "kettlebells" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "Box Jump", equipment: "bodyweight" },
                { name: "Med Ball Sit-up Throw", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Deka Fit Murph",
          goal: "Deka Fit-flavoured Murph — matched-cardio bookends around a chipper of 100 med ball sit-up throws, 200 RAM weighted burpees, and 300 RAM reverse lunges. One brutal effort.",
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
          goal: "Row buy-in, five rotating triple-cardio rounds with burpees between machines, a descending sled ladder, then a SkiErg cash-out. Three engines, two bookends.",
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
                { name: "Run", distance_m: 300, equipment: "treadmill" },
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
          goal: "Five rotating triple-cardio rounds with burpees between machines, then a med ball sit-up throw mountain — 250 reps up and down. Compromised cardio into a single grinder.",
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
                { name: "Run", distance_m: 300, equipment: "treadmill" },
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
          name: "Race-Pace Heavy",
          goal: "Three rounds of 500m race-pace runs paired with sleds, a 12-min med ball sit-up throw EMOM, a 30/30 SkiErg engine, then 100 RAM reverse lunges to close.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Long Loops", format: "rounds", rounds: 3, rest_secs: 60,
              exercises: [
                { name: "Run", distance_m: 500, notes: "race pace — Deka Fit run-zone distance", equipment: "treadmill" },
                { name: "Sled Push", distance_m: 25, notes: "race weight — full Deka competition sled", equipment: "sled" },
                { name: "Run", distance_m: 500, notes: "race pace — Deka Fit run-zone distance", equipment: "treadmill" },
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
          goal: "A long zone 2 chipper — two rounds of compromised run / long row / med ball sit-up throws / compromised run / long ski / RAM reverse lunges. Conversational pace throughout.",
          duration_mins: 90,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy cardio + Deka mobility prep", duration_s: 300, notes: "90/90 hip switches, ankle circles, thoracic open books, world's greatest stretch", equipment: "ski_erg" }
              ] },
            { name: "Two Loops", format: "rounds", rounds: 2, rest_secs: 300,
              exercises: [
                { name: "Run", distance_m: 500, notes: "conversational pace — Deka Fit run-zone distance, nose-breathing where possible", equipment: "treadmill" },
                { name: "Row", distance_m: 1000, notes: "easy aerobic pace — sustain the same effort the whole way", equipment: "rowing_machine" },
                { name: "Med Ball Sit-up Throw", reps: 50, notes: "light ball — well below race weight, controlled tempo, full range", equipment: "wall_ball" },
                { name: "Run", distance_m: 500, notes: "conversational pace — breath stays calm", equipment: "treadmill" },
                { name: "SkiErg", distance_m: 1000, notes: "easy aerobic pace", equipment: "ski_erg" },
                { name: "RAM Reverse Lunges", reps: 50, notes: "deliberate steps, focus on knee tracking", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Living in America",
          goal: "A descending run ladder, a 20-min AMRAP on ski / med ball sit-up throws / row / RAM reverse lunges, accessory strength on bench and split squats, then a RAM weighted burpee tabata to close.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Run Stairs", format: "ladder",
              varies: "distance_m", start: 500, end: 100, step: 100, rest_between_rungs: 30,
              exercises: [ { name: "Run", notes: "hard pace", equipment: "treadmill" } ] },
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
