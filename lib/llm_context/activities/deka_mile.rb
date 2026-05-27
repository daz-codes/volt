module LLMContext
  module Activities
    module DekaMile
      SLUG = "deka-mile"
      NAME = "Deka Mile"

      CONTRACT = {
        purity: "Deka Mile race training — running-heavy Deka variant. Treadmill mileage " \
                "is the backbone of every session.",
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
          low:    "Zone-2 day for Deka Mile (compromised running is mostly a medium/high event). " \
                  "Rotate between FOUR shapes: (1) one long 20+ min easy-pace Row, Ski, Bike, or " \
                  "treadmill block, (2) stacked 10-min blocks (Run + Row + Ski at easy pace), (3) long " \
                  "continuous circuit (format: continuous_circuit, 4-6 movements rotating 1 min each " \
                  "for 20-40 min, no rest — REACH FOR IT OFTEN), (4) long-interval cardio rounds (4 × " \
                  "6 min Row at easy pace, 30s rest). NO weights, NO EMOMs, NO Tabatas, NO sprints, " \
                  "NO compromised running (compromised work is by definition not easy). Bookends at " \
                  "easy pace fit (10-min Row buy-in → main → 10-min Ski cash-out). duration_mins on " \
                  "every main/finisher section must be a multiple of 5. Effort cue: easy, " \
                  "conversational, nose-breathing pace.",
          medium: "Race-prep working pace — Deka Mile's bread-and-butter. **Compromised running is the " \
                  "headline shape here** (8-12 rounds × 160-300m run + 1-2 functional exercises). Also " \
                  "fits: 200m or 300m run intervals as straight sections, station blocks, EMOMs. " \
                  "Reach for `format: emom` and `format: continuous_circuit` often. Bookends fit (Row " \
                  "buy-in → run main → Ski cash-out). Strength is OPTIONAL — many medium sessions are " \
                  "pure run + station metcon. When strength is included, placement can vary.",
          high:   "Race-day energy — strength block (if included) goes FIRST after warm-up (heavy 3-5 " \
                  "rep lifts, 120-180s rest); rotate the lift each session (no Bench default). After " \
                  "that, max-pace work with long recovery: short compromised runs (160-200m, all-out, " \
                  "with full recovery), strength station EMOMs, 30s hard / 30s rest cardio. Pack LESS " \
                  "total work — one main block fewer than medium — so transitions are unhurried."
        },
        notes: "The Deka Mile race is 10 × 160m runs alternating with 10 functional zones. " \
               "**COMPROMISED RUNNING IS THE HEADLINE SHAPE** — compromised runs in Deka " \
               "Mile are STRICTLY ≤ 300m. The race distance is 160m but training a bit " \
               "above race distance (up to 300m) builds the engine for race day. Canonical " \
               "shape: `10 rounds: 200m Run + 1-2 functional exercises` (e.g. `10 rounds: " \
               "200m Run + 10 Med Ball Sit-up Throws + 10 RAM Reverse Lunges`). " \
               "Run shape options: (a) COMPROMISED race-pace — 8-12 rounds × 160m or 200m " \
               "run + 1-2 short functional exercises (the primary shape, ~70% of sessions " \
               "that include running); (b) COMPROMISED above-race — 6-8 rounds × 300m run " \
               "+ 1-2 functional exercises (slightly longer, builds the engine above race " \
               "distance); (c) PURE race-pace test — 10 × 160m bare sprints, no station " \
               "after each (the ONE bare-sprint session out of every 4-5); (d) THRESHOLD " \
               "bare intervals — 4-5 × 500m, NOT compromised, just bare runs with active " \
               "rest (occasional, for distance and tempo). " \
               "**Compromised runs NEVER exceed 300m.** Bare interval runs can go up to 500m " \
               "but they're not the headline shape — they're an occasional change of pace. " \
               "**MACHINE CARDIO IS ALSO COMPROMISED** — Air Bike, SkiErg, and Row blocks " \
               "should pair the machine with 1-2 functional exercises per round, NOT stand " \
               "alone. **Twin Machines** (Air Bike + SkiErg paired in one round) is a great " \
               "occasional shape, but only as ONE cardio block in the session — never " \
               "alongside another big standalone cardio block. " \
               "**Roughly 1 in 3 sessions should skip running entirely** and build the engine " \
               "on machine cardio + functional exercises (compromised cardio). " \
               "**Vary where the run block sits in the session** — not always first. Sometimes " \
               "lead with an EMOM, alt EMOM, or strength accessory, THEN do the compromised " \
               "runs. " \
               "Don't default to the same shape every session — vary round count, exercise " \
               "pairings, position, and sometimes machines only."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run blocks:        Treadmill 160m / 200m race-pace repeats (10-12 rounds), 400m threshold (6-8 rounds), 500m longer threshold (4-5 rounds) — never longer than 500m per repeat
        Machine engine:    Air Bike + SkiErg + Rower combinations (no run) — occasional alternative to treadmill work
        Stations:          RAM Reverse Lunges, Row, Box Jump, SkiErg, Farmer's Carry, Air Bike,
                           Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
      VOCAB

      # Canonical race-station exercises. Used by the validator to scope
      # race-relative wording ("race weight", "competition load") to actual
      # race movements — strength accessories like Deadlift get absolute
      # phrasing instead. Loose substring match, case-insensitive.
      RACE_STATIONS = [
        "Treadmill", "Run",
        "RAM Reverse Lunges", "Row", "Box Jump",
        "SkiErg", "Farmer's Carry", "Air Bike", "Dead Ball Yoke Over",
        "Sled Push", "Sled Pull", "RAM Weighted Burpees"
      ].freeze

      EXAMPLES = [
        {
          name: "Quick One",
          goal: "Open with a RAM Reverse Lunges EMOM to pre-fatigue the legs, then 6 × 400m treadmill repeats on tired legs.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "rowing_machine" } ] },
            { name: "Lunge March", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "RAM Reverse Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Mile High", format: "rounds", rounds: 6, rest_secs: 60,
              exercises: [
                { name: "Run", distance_m: 400, notes: "hard pace — legs are already cooked from the EMOM", equipment: "treadmill" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Half Mile Threshold",
          goal: "Open with a Med Ball Sit-up Throw EMOM, then four bare 500m threshold runs (no stations — occasional longer-run shape, not compromised), then heavy deadlifts to close.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Throw Down", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Med Ball Sit-up Throw", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" }
              ] },
            { name: "Threshold", format: "rounds", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Run", distance_m: 500, notes: "threshold pace — sustained hard but not all-out, 2 min easy jog rest between rounds", equipment: "treadmill" }
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
          name: "Tuesday's Regret",
          goal: "30/30 treadmill engine, compromised 400m runs, a rotating continuous circuit on row, RAM reverse lunges and box jump, then a hundred burpee finisher.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Tread the Line", format: "rounds", rounds: 24, rest_secs: 30,
              exercises: [
                { name: "Run", duration_s: 30, notes: "hard pace", equipment: "treadmill" }
              ] },
            { name: "Pavement Pounder", format: "rounds", rounds: 6, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 200, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 12, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 20, equipment: "kettlebells" }
              ] },
            { name: "Engine Builder", format: "continuous_circuit", duration_mins: 15,
              exercises: [
                { name: "Rowing Machine", equipment: "rowing_machine" },
                { name: "RAM Reverse Lunges", equipment: "bodyweight" },
                { name: "Box Jump", equipment: "bodyweight" }
              ] },
            { name: "The Centurion", format: "hundred",
              exercises: [
                { name: "Burpees", reps: 100, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Stations Stacked",
          goal: "Compromised 400m running across six rounds, an alternating EMOM of Box Jump and RAM Reverse Lunges, and a tabata burner to close.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Race Repeats", format: "rounds", rounds: 6, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 200, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 10, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 15, equipment: "kettlebells" }
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
          name: "Machine Engine",
          goal: "No-run session — compromised Twin Machines (Air Bike + SkiErg paired with a station), a heavy carry-and-sled triplet, a single-exercise RAM Reverse Lunges grind, and a hundred Box Jumps to finish. ONE cardio block, not two stacked.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Twin Engines", format: "rounds", rounds: 6, rest_secs: 60,
              exercises: [
                { name: "Air Bike", calories: 12, notes: "strong sustained effort", equipment: "assault_bike" },
                { name: "SkiErg", calories: 12, notes: "strong sustained effort", equipment: "ski_erg" },
                { name: "RAM Reverse Lunges", reps: 12 }
              ] },
            { name: "Three Carries", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Farmer's Carry", distance_m: 60, notes: "race weight — competition load", equipment: "kettlebells" },
                { name: "Sled Push", distance_m: 40, notes: "race weight — full competition sled", equipment: "sled" },
                { name: "Sled Pull", distance_m: 20, notes: "race weight — full competition sled", equipment: "sled" }
              ] },
            { name: "Lunge March", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "RAM Reverse Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)" }
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
          name: "Sprint Descent",
          goal: "One long sprint-broken descending pyramid — 400m runs between tiers of Med Ball Sit-up Throw, Sled Push and RAM Reverse Lunges, four tiers down.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Down the Sprints", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 400, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 80, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 80, notes: "race weight — full competition sled across all tiers", equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 80 },
                { name: "Run", distance_m: 400, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 60, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 60, equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 60 },
                { name: "Run", distance_m: 400, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 40, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 40, notes: "race weight — full competition sled", equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 40 },
                { name: "Run", distance_m: 400, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 20, equipment: "wall_ball" },
                { name: "Sled Push", distance_m: 20, equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 20 }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Long Easy Run",
          goal: "A long continuous zone 2 treadmill run, a hip mobility flow, light Deka technique stations, then a quiet cool-down — mobility woven through.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy walk + Deka mobility prep", duration_s: 300, notes: "90/90 hip switches, ankle circles, thoracic open books, world's greatest stretch", equipment: "treadmill" }
              ] },
            { name: "Long Run", format: "straight", duration_mins: 25,
              exercises: [
                { name: "Run", duration_s: 1500, notes: "conversational pace — nose-breathing where possible, building aerobic engine", equipment: "treadmill" }
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
                { name: "Med Ball Sit-up Throw", reps: 20, notes: "light ball — well below race weight, smooth throw mechanics, full sit-up", equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 30, notes: "light load — well below race weight, tall posture, breath stays calm", equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Aerobic Mile Build",
          goal: "A steady row, an ankle mobility flow, an easy circuit with mobility woven into each round, then a quiet cool-down.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy ski + Deka mobility prep", duration_s: 300, notes: "ankle circles, calf stretches, dynamic lunges", equipment: "ski_erg" }
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
                { name: "Walking Lunges", reps: 20, notes: "deliberate steps, focus on knee tracking", equipment: "bodyweight" },
                { name: "Foam Roller Thoracic Extensions", duration_s: 60, notes: "slow controlled extensions over a foam roller" },
                { name: "Box Jump", reps: 15, notes: "soft landings, full hip extension at the top", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Sprint Day",
          goal: "Heavy deadlift triples, compromised 200m sprint rounds with Deka stations, heavy sled work, then a tabata finisher. Full recovery between every set.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Heavy Pull", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Deadlift", reps: 3, notes: "near-max strength load — last rep should be a fight", equipment: "barbell" }
              ] },
            { name: "Compromised 200s", format: "rounds", rounds: 8, rest_secs: 90,
              exercises: [
                { name: "Compromised Run", distance_m: 200, notes: "all-out — every rep is maximum effort", equipment: "treadmill" },
                { name: "Box Jump", reps: 10, equipment: "bodyweight" },
                { name: "Farmer's Carry", distance_m: 20, notes: "race weight — competition load", equipment: "kettlebells" }
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
          name: "Race Pace Pyramid",
          goal: "Heavy push press, the pure race-distance test (10 × 160m, no stations — the one bare-sprint session), then a tabata burner. Short, sharp, full-recovery.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Heavy Press", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Push Press", reps: 3, notes: "near-max strength load — full recovery between sets", equipment: "barbell" }
              ] },
            { name: "160m Sprints", format: "rounds", rounds: 10, rest_secs: 90,
              exercises: [
                { name: "Run", distance_m: 160, notes: "max-effort at race distance — pure sprint test, no compromise, every rep is maximum", equipment: "treadmill" }
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
          name: "Mile Murph",
          goal: "Deka Mile-flavoured Murph — matched-cardio bookends around a chipper of 100 med ball sit-up throws, 200 RAM weighted burpees, and 300 RAM reverse lunges.",
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
          goal: "Row buy-in, five rotating triple-cardio rounds with burpees between machines, a descending sled ladder, then a SkiErg cash-out. Three engines, two bookends — short compromised runs throughout.",
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
                { name: "Run", distance_m: 200, notes: "compromised — Deka Mile race-pace distance", equipment: "treadmill" },
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
          goal: "Five rotating triple-cardio rounds with burpees between machines, then a med ball sit-up throw mountain — 250 reps up and down. Short compromised runs into a single grinder.",
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
                { name: "Run", distance_m: 200, notes: "compromised — Deka Mile race-pace distance", equipment: "treadmill" },
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
          name: "Sprint Heavy",
          goal: "Five compromised sprint rounds with sled work, a 12-min med ball sit-up throw EMOM, a 30/30 SkiErg engine, then 100 RAM reverse lunges to close. Race-pace 200m repeats throughout.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Sprint Loops", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "Run", distance_m: 200, notes: "race pace — Deka Mile compromised distance", equipment: "treadmill" },
                { name: "Sled Push", distance_m: 25, notes: "race weight — full Deka competition sled", equipment: "sled" },
                { name: "Run", distance_m: 200, notes: "race pace — Deka Mile compromised distance", equipment: "treadmill" },
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
                { name: "Run", distance_m: 300, notes: "conversational pace — short compromised run, nose-breathing where possible", equipment: "treadmill" },
                { name: "Row", distance_m: 1000, notes: "easy aerobic pace — sustain the same effort the whole way", equipment: "rowing_machine" },
                { name: "Med Ball Sit-up Throw", reps: 50, notes: "light ball — well below race weight, controlled tempo, full range", equipment: "wall_ball" },
                { name: "Run", distance_m: 300, notes: "conversational pace — short compromised run, breath stays calm", equipment: "treadmill" },
                { name: "SkiErg", distance_m: 1000, notes: "easy aerobic pace", equipment: "ski_erg" },
                { name: "RAM Reverse Lunges", reps: 50, notes: "deliberate steps, focus on knee tracking", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Living in America",
          goal: "A descending sprint ladder, a 20-min AMRAP on ski / med ball sit-up throws / row / RAM reverse lunges, accessory strength on bench and split squats, then a RAM weighted burpee tabata to close.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Sprint Stairs", format: "ladder",
              varies: "distance_m", start: 300, end: 100, step: 50, rest_between_rungs: 30,
              exercises: [ { name: "Run", notes: "race pace — Deka Mile sprint distances", equipment: "treadmill" } ] },
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
        },
        {
          name: "Parallel Descender",
          goal: "Compromised Run + Box Jump descending in parallel — both exercises descend on the same rung count but on different scales (300→100m of run paired with 25→5 reps of box jump), then heavy carries and a tabata finisher.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Compromised Descender", format: "ladder",
              varies: "distance_m", start: 300, end: 100, step: 50, rest_between_rungs: 45,
              exercises: [
                { name: "Compromised Run", equipment: "treadmill", notes: "race pace — Deka Mile distance" },
                { name: "Box Jump", equipment: "bodyweight",
                  varies: "reps", start: 25, end: 5, step: 5,
                  notes: "rebound off the box, soft landings" }
              ] },
            { name: "Heavy Carries", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Farmer's Carry", distance_m: 40, notes: "race weight — competition load", equipment: "kettlebells" },
                { name: "Sled Push", distance_m: 20, notes: "race weight — full competition sled", equipment: "sled" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "RAM Weighted Burpees", equipment: "bodyweight" },
                { name: "Sit-ups", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Strike First",
          goal: "A 90-min high-intensity grinder: heavy bench triples, a rotating 3-exercise EMOM, machine sprints, compromised running, then a tabata burner. Race-day energy from the first set.",
          duration_mins: 90,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy cardio + Dynamic stretches", duration_s: 300,
                  notes: "light jog or row to elevate heart rate; arm circles, leg swings, glute activation",
                  equipment: "rowing_machine" }
              ] },
            { name: "Iron Anchor", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Bench Press", reps: 3,
                  notes: "near-max strength load — last rep should be a fight, full reset between sets",
                  equipment: "barbell" }
              ] },
            { name: "Race Day Energy", format: "emom", duration_mins: 15, rest_secs: 0, alternating: true,
              exercises: [
                { name: "Burpees",        notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" },
                { name: "Reverse Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" },
                { name: "Sit Ups",        notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Machine Assault", format: "rounds", rounds: 6, rest_secs: 60,
              exercises: [
                { name: "SkiErg",       calories: 12, notes: "all-out sprint effort — max calories each round", equipment: "ski_erg" },
                { name: "Assault Bike", calories: 12, notes: "hammer the resistance, full recovery between rounds", equipment: "assault_bike" }
              ] },
            { name: "Compromised Gauntlet", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 300,
                  notes: "hard effort — arriving already fatigued from machine work; above-race distance to build the engine",
                  equipment: "treadmill" },
                { name: "Box Jump Step-Overs", reps: 12, equipment: "bodyweight" }
              ] },
            { name: "Final Burn", format: "tabata", duration_mins: 4,
              exercises: [
                { name: "RAM Weighted Burpees", equipment: "bodyweight" },
                { name: "Med Ball Slams",       equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Static stretches",
                  notes: "10 deep breaths each side. Pigeon, forward fold, spinal twist, chest opener, thread the needle, child's pose — 45–60s each" }
              ] }
          ]
        }
      ].freeze
    end
  end
end
