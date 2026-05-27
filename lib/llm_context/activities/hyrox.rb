module LLMContext
  module Activities
    module Hyrox
      SLUG = "hyrox"
      NAME = "Hyrox"

      CONTRACT = {
        purity: "Hyrox race training — 1 km runs between 8 functional stations. " \
                "Treadmill running is the backbone of every session. Assault Bike is NOT " \
                "a Hyrox machine and must never appear.",
        hybrid_family: true,
        allowed_equipment: %w[treadmill rowing_machine ski_erg sled wall_ball kettlebells barbell dumbbells pull_up_bar resistance_bands],
        banned_equipment:  %w[jump_rope assault_bike],
        banned_exercise_patterns: [
          /\bassault bike\b/i, /\bair bike\b/i, /\becho bike\b/i
        ].freeze,
        allowed_formats:   %w[for_time rounds emom amrap tabata ladder hundred mountain],
        primary_formats:   %w[for_time rounds emom],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :optional,
        intensity_guide: {
          low:    "Zone-2 day — rotate between FOUR structural shapes so the athlete doesn't see the " \
                  "same session twice. " \
                  "SHAPE 1 — one long continuous block (e.g. one 25-min Row at conversational pace). " \
                  "SHAPE 2 — stacked single-modality blocks (10 min Row + 10 min Run + 10 min SkiErg, " \
                  "no rest between machines). " \
                  "SHAPE 3 — **long continuous circuit (engine builder, reach for this often)**: " \
                  "`format: continuous_circuit` with 4-6 Hyrox movements rotating 1 min each " \
                  "(Row / Wall Balls / Walking Lunges / SkiErg / Run / Burpee Broad Jumps light) for " \
                  "20-40 min, no rest. Or a 20-min `format: amrap` at light load. Or a long " \
                  "`format: for_time` chipper. This is the most under-used shape — use it explicitly. " \
                  "SHAPE 4 — long-interval cardio rounds (e.g. 4 rounds × 6 min Row, 30s rest). " \
                  "NO weights — no barbell, dumbbell, or kettlebell loaded work; the only rep-based " \
                  "movements allowed are light Wall Balls for form, mobility flows, or bodyweight " \
                  "technique drills. NO EMOMs, NO Tabatas, NO sprints. duration_mins on every " \
                  "main/finisher section must be a multiple of 5. " \
                  "Effort cue: easy, conversational, nose-breathing pace.",
          medium: "Race-prep working pace — the bread-and-butter Hyrox session. Mix run intervals " \
                  "with station blocks at ~RPE 7-8, 60s rest between rounds. **Reach for `format: emom` " \
                  "and `format: continuous_circuit` often — they're the two best-fitting shapes for " \
                  "hybrid race training.** AMRAPs and for-time chippers also fit naturally.",
          high:   "Race-day energy — strength block goes FIRST (heavy 3-5 rep lifts at near-max load, " \
                  "120-180s rest). **Pick a different lift each session — Deadlift, Back Squat, Front " \
                  "Squat, Bench Press, Push Press, Overhead Press, Clean & Jerk. Do NOT default to " \
                  "Bench Press; rotate.** After the strength block, everything else is max-pace with " \
                  "long recovery. **Strongly prefer `format: emom`** (with the ~50% of 1-min max cue " \
                  "or rotating `alternating: true`) over `continuous_circuit` for metcons at high " \
                  "intensity. Use the 30s hard / 30s rest pattern for hard cardio. Run intervals are " \
                  "all-out sprints (200-400m), never threshold pace. Pack LESS total work into the " \
                  "session than you would at medium — typically one main block fewer — so transitions " \
                  "between sections are unhurried."
        },
        notes: "MANDATORY: every session must include at least 2 treadmill running " \
               "intervals (500m–1km each) placed between station blocks. Stations " \
               "mirror the race: SkiErg, Sled Push/Pull, Burpee Broad Jumps, Rowing, " \
               "Farmer's Carry, Sandbag Lunges, Wall Balls. Every section must be " \
               "meaningfully different — do not create two sections with the same " \
               "exercises and structure but different names. The race stations remain " \
               "the headline movements, but workouts cannot be ONLY stations — every " \
               "session also needs supplementary work. " \
               "MOBILITY SECTIONS: Hyrox mobility work is PREP, not cool-down. It must " \
               "FEEL different from the final stretch section — dynamic not static, " \
               "sets-and-reps not long holds. Target the joints Hyrox stresses: " \
               "ankle dorsiflexion (sled push, running stride), shoulder (sled pull, " \
               "ski erg, wall ball overhead), hip (Burpee Broad Jumps, sandbag lunges), " \
               "and T-spine (rowing, wall ball). Reach for resistance bands (Band Pull-Aparts, " \
               "Banded Pass-Throughs, Banded Ankle Mobilizations, Banded Leg Swings), " \
               "controlled active drills (World's Greatest Stretch as a 3-per-side flow, " \
               "Wall Slides, Cossack Squats as reps not holds, Ankle Circles), and joint " \
               "prep done in `format: rounds` with reps (8-15) or short controlled " \
               "duration_s (20-30s). Long static holds (Pigeon 90s+, Cobra hold, Couch " \
               "Stretch 2min) belong in the cool-down, NEVER in a mid-session mobility " \
               "section."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Running:           Treadmill 500m, 1km, 400m repeats
        Stations:          SkiErg, Sled Push, Sled Pull, Burpee Broad Jumps, Rowing Machine, Farmer's Carry, Wall Ball, Sandbag Lunges
        Mobility (dynamic, sets-and-reps — for mid-session mobility blocks, NOT cool-down):
          Bands:           Band Pull-Aparts, Banded Pass-Throughs, Banded Ankle Mobilizations, Banded Leg Swings, Banded Hip Openers
          Shoulder:        Wall Slides, Scapular Push-Ups, Arm Circles, Shoulder Dislocates (PVC), Y-T-W Raises
          Ankle:           Ankle Circles, Banded Ankle Mobilizations, Calf-on-Wall Drives, Eccentric Calf Raises
          Hip:             World's Greatest Stretch (3 per side flow), 90/90 Hip Switches (reps not holds), Cossack Squats, Banded Leg Swings, Hip Flexor Knee Drives
          T-spine:         Thoracic Open Books, Foam Roller Thoracic Extensions, Cat-Cow, Bird-Dog
        Cool-down statics (long holds, breath-led — for the FINAL section only):
                           Pigeon, Couch Stretch, Cobra, Thread the Needle, Forward Fold, Child's Pose, Spinal Twist
      VOCAB

      # Canonical race-station exercises (Hyrox 8 stations + running). Used
      # by the validator to scope race-relative wording ("race weight",
      # "Hyrox competition") to actual race movements — strength accessories
      # like Deadlift get absolute phrasing instead. Loose substring match,
      # case-insensitive.
      RACE_STATIONS = [
        "Treadmill", "Run",
        "SkiErg", "Sled Push", "Sled Pull", "Burpee Broad Jump",
        "Rowing Machine", "Row", "Farmer's Carry", "Wall Ball", "Sandbag Lunge"
      ].freeze

      EXAMPLES = [
        {
          name: "Mixed Hybrid",
          goal: "Race-pace stations, a 30/30 engine split, a heavy lift, and a single-exercise EMOM grind.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Compromised Stations", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 30, notes: "race weight — Hyrox competition load", equipment: "kettlebells" }
              ] },
            { name: "Ski Sprint", format: "rounds", rounds: 5, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Row Sprint", format: "rounds", rounds: 5, rest_secs: 30,
              exercises: [
                { name: "Row", duration_s: 30, notes: "hard pace", equipment: "rowing_machine" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, notes: "heavy strength load — last rep should be a fight", equipment: "barbell" }
              ] },
            { name: "Walking Death", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "Walking Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Gut Check", format: "rounds", rounds: 3, rest_secs: 30,
              exercises: [
                { name: "Sit-ups", reps: 20, equipment: "bodyweight" },
                { name: "V-ups", reps: 20, equipment: "bodyweight" },
                { name: "Plank", duration_s: 45, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Two Engines",
          goal: "Compromised cardio, a long 30/30 treadmill grinder, a rotating continuous circuit, and a hundred to finish.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Cooked", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "SkiErg", distance_m: 500, equipment: "ski_erg" },
                { name: "Walking Lunges", reps: 20, equipment: "bodyweight" },
                { name: "SkiErg", distance_m: 500, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 30, notes: "race weight — full Hyrox competition sled", equipment: "sled" }
              ] },
            { name: "Tread the Line", format: "rounds", rounds: 16, rest_secs: 30,
              exercises: [
                { name: "Run", duration_s: 30, notes: "hard pace", equipment: "treadmill" }
              ] },
            { name: "Engine Room", format: "continuous_circuit", duration_mins: 18,
              exercises: [
                { name: "Rowing Machine", equipment: "rowing_machine" },
                { name: "Box Jump Burpees", equipment: "bodyweight" },
                { name: "KB Swings", equipment: "kettlebells" }
              ] },
            { name: "The Centurion", format: "hundred",
              exercises: [
                { name: "Wall Balls", reps: 100, equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Ladder Day",
          goal: "30/30 opener, alternating EMOM grind, a compromised run-up-and-down ladder, then strength and a hundred.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Lung Buster", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Final Boss", format: "emom", duration_mins: 20, rest_secs: 0, alternating: true,
              exercises: [
                { name: "Burpee Broad Jumps", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" },
                { name: "Walking Lunges", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Up & Down", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Wall Balls", reps: 10, equipment: "wall_ball" },
                { name: "Run", distance_m: 800, equipment: "treadmill" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" },
                { name: "Run", distance_m: 600, equipment: "treadmill" },
                { name: "Wall Balls", reps: 30, equipment: "wall_ball" },
                { name: "Run", distance_m: 400, equipment: "treadmill" },
                { name: "Wall Balls", reps: 40, equipment: "wall_ball" },
                { name: "Run", distance_m: 200, equipment: "treadmill" },
                { name: "Wall Balls", reps: 50, equipment: "wall_ball" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, notes: "heavy strength load — proper strength training, not a race-day-style effort", equipment: "barbell" }
              ] },
            { name: "Swing Time", format: "hundred",
              exercises: [
                { name: "KB Swings", reps: 100, equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "The Workshop",
          goal: "Continuous circuit opener, a carry-and-sled triplet, heavy goblet squats, 1km repeats, then a tabata finisher.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Rotation Room", format: "continuous_circuit", duration_mins: 12,
              exercises: [
                { name: "SkiErg", equipment: "ski_erg" },
                { name: "Walking Lunges", equipment: "bodyweight" },
                { name: "Wall Balls", equipment: "wall_ball" }
              ] },
            { name: "Hardware", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Farmer's Carry", distance_m: 60, notes: "race weight — Hyrox competition load", equipment: "kettlebells" },
                { name: "Sled Push", distance_m: 40, notes: "race weight — full Hyrox sled", equipment: "sled" },
                { name: "Sled Pull", distance_m: 20, notes: "race weight — full Hyrox sled", equipment: "sled" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Goblet Squats", reps: 5, notes: "heavier than race weight — heaviest bell you can rep cleanly for 5", equipment: "kettlebells" }
              ] },
            { name: "Race Pace", format: "rounds", rounds: 5, rest_secs: 90,
              exercises: [
                { name: "Run", distance_m: 1000, notes: "race pace — 90s easy jog rest between rounds", equipment: "treadmill" }
              ] },
            { name: "Tabata Cooker", format: "tabata",
              exercises: [
                { name: "Box Jump Burpees", equipment: "bodyweight" },
                { name: "Shoulder Press", equipment: "barbell" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Mixed Methods",
          goal: "An E2MOM triplet, a classic row-and-wall-ball couplet, 30/30 treadmill, then a thruster-and-slam tabata.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Triple Trouble", format: "emom", duration_mins: 16, rest_secs: 0,
              exercises: [
                { name: "Burpees", reps: 5, equipment: "bodyweight" },
                { name: "Walking Lunges", reps: 10, equipment: "bodyweight" },
                { name: "Farmer's Carry", distance_m: 20, notes: "race weight — Hyrox competition load", equipment: "kettlebells" }
              ] },
            { name: "Couplet Crunch", format: "rounds", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "Row", calories: 20, equipment: "rowing_machine" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" }
              ] },
            { name: "Tread the Line", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "Run", duration_s: 30, notes: "hard pace", equipment: "treadmill" }
              ] },
            { name: "Tabata Cooker", format: "tabata",
              exercises: [
                { name: "Thrusters", equipment: "kettlebells" },
                { name: "Med Ball Slams", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Descent",
          goal: "One long run-broken pyramid — 1km repeats interleaved with ski-sled-wall ball tiers, descending 80 → 20. Pace the start, race the finish.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Down the Stairs", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "SkiErg", calories: 80, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 80, notes: "race weight — full Hyrox competition sled across all tiers", equipment: "sled" },
                { name: "Wall Balls", reps: 80, equipment: "wall_ball" },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "SkiErg", calories: 60, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 60, equipment: "sled" },
                { name: "Wall Balls", reps: 60, equipment: "wall_ball" },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "SkiErg", calories: 40, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 40, equipment: "sled" },
                { name: "Wall Balls", reps: 40, equipment: "wall_ball" },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "SkiErg", calories: 20, equipment: "ski_erg" },
                { name: "Sled Push", distance_m: 20, equipment: "sled" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Zone Two Engine",
          goal: "A long continuous zone 2 ski, banded shoulder + T-spine prep, light Hyrox technique stations, banded ankle + hip prep, then a quiet cool-down — dynamic Hyrox-specific mobility woven through, not just stretches at the end.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy treadmill walk + Hyrox mobility prep", duration_s: 300, notes: "90/90 hip switches, ankle circles, thoracic open books, world's greatest stretch", equipment: "treadmill" }
              ] },
            { name: "The Long Way", format: "straight", duration_mins: 20,
              exercises: [
                { name: "SkiErg", duration_s: 1200, notes: "conversational pace — nose-breathing where possible, building aerobic engine", equipment: "ski_erg" }
              ] },
            { name: "Shoulder & T-Spine Prep", format: "rounds", rounds: 2, rest_secs: 0, duration_mins: 5,
              exercises: [
                { name: "Banded Pass-Throughs",   reps: 12, notes: "light band, slow controlled, keep arms straight, work the end range",   equipment: "resistance_bands" },
                { name: "Band Pull-Aparts",       reps: 15, notes: "scapular retraction, light band, 2-second pause at full pull",          equipment: "resistance_bands" },
                { name: "Wall Slides",            reps: 10, notes: "back flat to wall, slow overhead reach, drive elbows down on return",   equipment: "bodyweight" },
                { name: "Thoracic Open Books",    reps: 10, notes: "5 per side, lying on side, rotate top arm across body to floor",       equipment: "bodyweight" }
              ] },
            { name: "Hyrox Technique Stations", format: "rounds", rounds: 3, rest_secs: 20, duration_mins: 8,
              exercises: [
                { name: "Wall Balls",     reps: 20, notes: "light ball, full squat depth, controlled tempo",          equipment: "wall_ball" },
                { name: "Air Squats",     reps: 20, notes: "deliberate tempo, full depth, knees track over toes",     equipment: "bodyweight" },
                { name: "Walking Lunges", reps: 20, notes: "10 per leg, tall posture, controlled steps",              equipment: "bodyweight" }
              ] },
            { name: "Ankle & Hip Prep", format: "rounds", rounds: 2, rest_secs: 0, duration_mins: 5,
              exercises: [
                { name: "Banded Ankle Mobilizations", reps: 10, notes: "10 per side, knee drives forward over toe, posterior glide",       equipment: "resistance_bands" },
                { name: "Banded Leg Swings",          reps: 10, notes: "10 per side forward-back, then 10 per side side-to-side, controlled", equipment: "resistance_bands" },
                { name: "Cossack Squats",             reps: 8,  notes: "4 per side, shift weight side-to-side, drive knee over toe",         equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Continuous Engine",
          goal: "A 40-min continuous-circuit engine builder — Row / Wall Balls / Walking Lunges / SkiErg, one minute each, no rest. Ten rotations of constant easy-pace work, then a dynamic Hyrox mobility reset (bands + active drills) before the cool-down.",
          duration_mins: 60,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy row + Hyrox mobility prep", duration_s: 300, notes: "cat-cow, ankle circles, kneeling hip flexor stretch, dynamic lunges", equipment: "rowing_machine" }
              ] },
            { name: "The Wheel", format: "continuous_circuit", duration_mins: 40,
              exercises: [
                { name: "Row",            notes: "easy aerobic pace — breath stays calm",                     equipment: "rowing_machine" },
                { name: "Wall Balls",     notes: "light ball, full squat depth, controlled tempo",            equipment: "wall_ball" },
                { name: "Walking Lunges", notes: "tall posture, deliberate steps, controlled tempo",          equipment: "bodyweight" },
                { name: "SkiErg",         notes: "easy aerobic pace — sustain the same effort the whole way", equipment: "ski_erg" }
              ] },
            { name: "Hyrox Mobility Reset", format: "rounds", rounds: 3, rest_secs: 30,
              exercises: [
                { name: "Banded Pass-Throughs",       reps: 12, notes: "light band, slow controlled, shoulder mobility for ski erg + wall ball",     equipment: "resistance_bands" },
                { name: "Banded Ankle Mobilizations", reps: 10, notes: "10 per side, drive knee over toe, sled push + run prep",                     equipment: "resistance_bands" },
                { name: "World's Greatest Stretch",   reps: 6,  notes: "3 per side — lunge, hip drop, T-spine reach, smooth transitions",            equipment: "bodyweight" },
                { name: "Cossack Squats",             reps: 8,  notes: "4 per side, dynamic shift, depth over speed",                                equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Race Day Test",
          goal: "Heavy deadlift triples, all-out 200m sprint repeats, heavy sled work, then a tabata finisher. Full recovery between every set — every effort is maximal.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Heavy Pull", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Deadlift", reps: 3, notes: "near-max strength load — last rep should be a fight", equipment: "barbell" }
              ] },
            { name: "Sprint Repeats", format: "rounds", rounds: 8, rest_secs: 90,
              exercises: [
                { name: "Run", distance_m: 200, notes: "all-out — every rep is maximum effort", equipment: "treadmill" }
              ] },
            { name: "Heavy Sled", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Sled Push", distance_m: 20, notes: "heavier than race weight — load above competition sled to train over-tolerance, drive 20m without breaking", equipment: "sled" }
              ] },
            { name: "Tabata Cooker", format: "tabata",
              exercises: [
                { name: "Burpees", equipment: "bodyweight" },
                { name: "KB Swings", equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Iron & Fire",
          goal: "Heavy push press, ski sprint repeats, all-out sled sprints, then a tabata burner. Short, sharp, full-recovery work.",
          duration_mins: 45,
          intensity_style: "high",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Heavy Press", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 180,
              exercises: [
                { name: "Push Press", reps: 3, notes: "near-max strength load — full recovery between sets", equipment: "barbell" }
              ] },
            { name: "Ski Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "all-out — every 30s is maximum, full recovery between", equipment: "ski_erg" }
              ] },
            { name: "Sled Sprints", format: "rounds", rounds: 6, rest_secs: 90,
              exercises: [
                { name: "Sled Push", distance_m: 15, notes: "heavier than race weight — above competition load, sprint don't walk", equipment: "sled" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "Box Jump Burpees", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "1K Bookends",
          goal: "Buy in with a 1km Row, race the main compromised running, then cash out on a 1km SkiErg. Matched-cardio bookends framing the work.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Buy In", format: "for_time",
              exercises: [
                { name: "Row", distance_m: 1000, notes: "race pace — set the tone, don't sandbag", equipment: "rowing_machine" }
              ] },
            { name: "Compromised Stations", format: "rounds", rounds: 4, rest_secs: 60,
              exercises: [
                { name: "Compromised Run", distance_m: 500, equipment: "treadmill" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" },
                { name: "Farmer's Carry", distance_m: 30, notes: "race weight — Hyrox competition load", equipment: "kettlebells" }
              ] },
            { name: "Iron Lift", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Deadlift", reps: 5, notes: "heavy strength load — last rep should be a fight", equipment: "barbell" }
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
          name: "Wall Ball Sandwich",
          goal: "Buy in with 50 Wall Balls, race a 30/30 engine and an alternating EMOM, then cash out with another 50 Wall Balls. Same-movement bookends — feel the difference.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Buy In", format: "for_time",
              exercises: [
                { name: "Wall Balls", reps: 50, notes: "unbroken if possible — clean reps, full squat depth", equipment: "wall_ball" }
              ] },
            { name: "Ski Engine", format: "rounds", rounds: 12, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "Final Boss", format: "emom", duration_mins: 16, rest_secs: 0, alternating: true,
              exercises: [
                { name: "KB Swings", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "kettlebells" },
                { name: "Box Step-overs", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "bodyweight" }
              ] },
            { name: "Cash Out", format: "for_time",
              exercises: [
                { name: "Wall Balls", reps: 50, notes: "same movement, very different feel — push through the burn", equipment: "wall_ball" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Jump & Burn",
          goal: "Buy in with 50 Box Jumps, work the main compromised circuit, then cash out with 50 Burpees. Different-movement bookends — two distinct tests.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "treadmill" } ] },
            { name: "Buy In", format: "for_time",
              exercises: [
                { name: "Box Jumps", reps: 50, notes: "controlled landings — quality reps, no rebounding past form", equipment: "bodyweight" }
              ] },
            { name: "Last Mile", format: "rounds", rounds: 4, rest_secs: 90,
              exercises: [
                { name: "Compromised Run", distance_m: 800, equipment: "treadmill" },
                { name: "Wall Balls", reps: 30, equipment: "wall_ball" },
                { name: "Burpee Broad Jumps", reps: 20, equipment: "bodyweight" },
                { name: "Farmer's Carry", distance_m: 40, notes: "race weight — Hyrox competition load", equipment: "kettlebells" }
              ] },
            { name: "Cash Out", format: "for_time",
              exercises: [
                { name: "Burpees", reps: 50, notes: "chest to floor each rep — race the clock, breath through the discomfort", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Hyrox Murph",
          goal: "Hyrox-flavoured Murph — 1600m run bookends around a chipper of 100 wall balls, 200 burpees, and 300 walking lunges. One brutal effort, no pacing tricks.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Buy In", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 1600, notes: "race pace — set the tone for the work ahead", equipment: "treadmill" }
              ] },
            { name: "Heart of Steel", format: "for_time",
              exercises: [
                { name: "Wall Balls", reps: 100, equipment: "wall_ball" },
                { name: "Burpees", reps: 200, equipment: "bodyweight" },
                { name: "Walking Lunges", reps: 300, equipment: "bodyweight" }
              ] },
            { name: "Cash Out", format: "for_time",
              exercises: [
                { name: "Run", distance_m: 1600, notes: "race the clock home — everything left in the tank", equipment: "treadmill" }
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
                { name: "Sled Push", notes: "race weight — full Hyrox competition sled", equipment: "sled" },
                { name: "Sled Pull", notes: "race weight — full Hyrox competition sled", equipment: "sled" }
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
          name: "Wall Baller",
          goal: "Five rotating triple-cardio rounds with burpees between machines, then a wall ball mountain — 250 reps up and down. Compromised cardio into a single grinder.",
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
              exercises: [ { name: "Wall Balls", equipment: "wall_ball" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Mile Heavy",
          goal: "Three rounds of run-sled-run-sled, a 12-min wall ball EMOM, a 30/30 SkiErg engine, then 100 walking lunges to close.",
          duration_mins: 75,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Long Loops", format: "rounds", rounds: 3, rest_secs: 60,
              exercises: [
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Sled Push", distance_m: 25, notes: "race weight — full Hyrox competition sled", equipment: "sled" },
                { name: "Run", distance_m: 1000, equipment: "treadmill" },
                { name: "Sled Pull", distance_m: 25, notes: "race weight — full Hyrox competition sled", equipment: "sled" }
              ] },
            { name: "Wall Window", format: "emom", duration_mins: 12, rest_secs: 0,
              exercises: [
                { name: "Wall Balls", notes: "~50% of your 1-min max (leaves ~20s rest)", equipment: "wall_ball" }
              ] },
            { name: "Ski Engine", format: "rounds", rounds: 10, rest_secs: 30,
              exercises: [
                { name: "SkiErg", duration_s: 30, notes: "hard pace", equipment: "ski_erg" }
              ] },
            { name: "The Long Walk", format: "hundred",
              exercises: [
                { name: "Walking Lunges", reps: 100, equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Engine Builder",
          goal: "A long zone 2 chipper — two rounds of run / row / wall balls / run / ski / walking lunges. Conversational pace throughout, building the aerobic engine.",
          duration_mins: 90,
          intensity_style: "low",
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [
                { name: "Easy cardio + Hyrox mobility prep", duration_s: 300, notes: "90/90 hip switches, ankle circles, thoracic open books, world's greatest stretch", equipment: "ski_erg" }
              ] },
            { name: "Two Loops", format: "rounds", rounds: 2, rest_secs: 300,
              exercises: [
                { name: "Run", distance_m: 2000, notes: "conversational pace — nose-breathing where possible, building aerobic engine", equipment: "treadmill" },
                { name: "Row", distance_m: 1000, notes: "easy aerobic pace — sustain the same effort the whole way", equipment: "rowing_machine" },
                { name: "Wall Balls", reps: 50, notes: "light ball — well below race weight, controlled tempo, full range", equipment: "wall_ball" },
                { name: "Run", distance_m: 2000, notes: "conversational pace — breath stays calm", equipment: "treadmill" },
                { name: "SkiErg", distance_m: 1000, notes: "easy aerobic pace", equipment: "ski_erg" },
                { name: "Walking Lunges", reps: 50, notes: "deliberate steps, focus on knee tracking", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Living in America",
          goal: "A descending run ladder, a 20-min AMRAP on ski / wall balls / row / lunges, accessory strength on bench and split squats, then a burpee tabata to close.",
          duration_mins: 60,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "ski_erg" } ] },
            { name: "Run Stairs", format: "ladder",
              varies: "distance_m", start: 1000, end: 200, step: 200, rest_between_rungs: 30,
              exercises: [ { name: "Run", notes: "hard pace", equipment: "treadmill" } ] },
            { name: "Engine Hunt", format: "amrap", duration_mins: 20, rest_secs: 0,
              exercises: [
                { name: "SkiErg", distance_m: 400, equipment: "ski_erg" },
                { name: "Wall Balls", reps: 20, equipment: "wall_ball" },
                { name: "Row", distance_m: 400, equipment: "rowing_machine" },
                { name: "Walking Lunges", reps: 20, equipment: "bodyweight" }
              ] },
            { name: "Strength Block", format: "rounds", intensity_style: "high", rounds: 5, rest_secs: 60,
              exercises: [
                { name: "DB Bench Press", reps: 8, notes: "working weight — last 2 reps should be a fight", equipment: "dumbbells" },
                { name: "Split Squat", reps: 8, notes: "8 per leg — controlled tempo, knee tracks toe", equipment: "dumbbells" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "Box Jump Burpees", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Wall Ball Tower",
          goal: "Wall Balls and Row descending in parallel — both exercises descend on the same rung count but on different scales (25→5 reps of wall balls paired with 25→5 calories of row), then heavy sled work and a tabata finisher.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Wall Ball Tower", format: "ladder",
              varies: "reps", start: 25, end: 5, step: 5, rest_between_rungs: 45,
              exercises: [
                { name: "Wall Balls", equipment: "wall_ball" },
                { name: "Row", equipment: "rowing_machine",
                  varies: "calories", start: 25, end: 5, step: 5 }
              ] },
            { name: "Heavy Sled", format: "rounds", intensity_style: "high", rounds: 4, rest_secs: 120,
              exercises: [
                { name: "Sled Push", distance_m: 20, notes: "heavier than race weight — above competition load", equipment: "sled" }
              ] },
            { name: "Tabata Burner", format: "tabata",
              exercises: [
                { name: "Burpee Broad Jumps", equipment: "bodyweight" },
                { name: "Sandbag Lunges", equipment: "bodyweight" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
