module LLMContext
  module Activities
    module DekaMile
      SLUG = "deka-mile"
      NAME = "Deka Mile"

      CONTRACT = {
        purity: "Deka Mile race training — running-heavy Deka variant. Treadmill mileage " \
                "is the backbone of every session.",
        hybrid_family: true,
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike wall_ball sled kettlebells barbell dumbbells pull_up_bar],
        banned_equipment:  %w[resistance_bands jump_rope],
        banned_exercise_patterns: [].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred matrix mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        notes: "The Deka Mile race is 10 × 160m runs alternating with 10 functional zones. " \
               "**COMPROMISED RUNNING IS THE HEADLINE SHAPE** — even short race-pace runs " \
               "(160m / 200m / 400m) should usually be paired with 1-2 functional exercises " \
               "AFTER each run, making the round compromised (e.g. `10 rounds: 200m Run + " \
               "10 Med Ball Sit-up Throws + 10 RAM Reverse Lunges`). Bare run repeats with " \
               "nothing after are the exception, not the default — reserve them for ONE " \
               "session out of 4-5 (the pure race-pace test). " \
               "Run shapes: (a) RACE-PACE compromised — 8-12 rounds × 160m/200m run + 2 " \
               "short functional exercises (the primary shape); (b) THRESHOLD compromised — " \
               "3-4 rounds × 500m run + 2-3 functional exercises (occasional, for distance); " \
               "(c) MIXED compromised — 5-6 rounds × 400m run + 2-3 exercises. MAXIMUM " \
               "individual run distance is 500m. " \
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
               "Don't default to 10 × 200m every session — vary round count, distance, " \
               "exercise pairings, position, and sometimes machines only."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Run blocks:        Treadmill 160m / 200m race-pace repeats (10-12 rounds), 400m threshold (6-8 rounds), 500m longer threshold (4-5 rounds) — never longer than 500m per repeat
        Machine engine:    Air Bike + SkiErg + Rower combinations (no run) — occasional alternative to treadmill work
        Stations:          RAM Reverse Lunges, Row, Box Jump, SkiErg, Farmer's Carry, Air Bike,
                           Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees
      VOCAB

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
          name: "Half Mile Compromised",
          goal: "Open with a Med Ball Sit-up Throw EMOM, then three compromised 500m rounds paired with sled and lunges, then heavy deadlifts to close. Occasional longer-run shape.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Throw Down", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "Med Ball Sit-up Throw", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" }
              ] },
            { name: "Long Compromised", format: "rounds", rounds: 3, rest_secs: 90,
              exercises: [
                { name: "Compromised Run", distance_m: 500, notes: "threshold pace — sustained hard but not all-out", equipment: "treadmill" },
                { name: "Sled Push", distance_m: 20, notes: "race weight — full competition sled", equipment: "sled" },
                { name: "RAM Reverse Lunges", reps: 20 }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, notes: "heavier than race weight — strength-training load, last rep should be a fight", equipment: "barbell" }
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
                { name: "Compromised Run", distance_m: 400, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 20, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 30, equipment: "kettlebells" }
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
                { name: "Compromised Run", distance_m: 400, equipment: "treadmill" },
                { name: "Med Ball Sit-up Throw", reps: 15, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 20, equipment: "kettlebells" }
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
                { name: "Deadlift", reps: 3, notes: "near-max — heavier than race weight, last rep should be a fight", equipment: "barbell" }
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
                { name: "Push Press", reps: 3, notes: "near-max — heavier than race weight, full recovery between sets", equipment: "barbell" }
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
        }
      ].freeze
    end
  end
end
