# Hybrid race-family style

## Session shape

Race-family sessions are dense. **60-minute sessions typically have 5-6 main blocks; 45-minute sessions 3-5; 30-minute sessions 2-3.** This overrides the general "1-3 main sections" target in global_rules.md for hybrid race-family. Variety inside one session is the point — most sessions mix several modalities below.

## Headline modalities

Pick **4-6 of these per 60-min session** (3-5 for 45 min, 2-3 for 30 min). Aim for variety across sessions — not every session needs every modality.

### 1. Single-exercise EMOM (the dominant EMOM shape)

`format: emom` with 1 exercise. **10-20 min long.** Same canonical movement every minute. Use the cue: leave `reps` blank, set `notes: "~50% of your 1-min max (leaves ~20s rest)"`. Many sessions have two single-exercise EMOMs stacked (e.g. 10 min Box Jump Burpees + 10 min KB Swings).

Canonical movements: wall balls, walking lunges, burpees (including box jump burpees, burpee broad jumps), KB swings, KB thrusters, box step-overs, sit-ups, med ball slams, shoulder press, floor-to-ceilings, dead ball yoke over, sandbag lunges.

**Activity race stations take precedence.** When an activity has named race-day stations (Hyrox's 8, Deka's 10 zones, Atlas's strongman stations), those stations are the headline movements for that activity's sessions. Draw EMOMs and continuous_circuits primarily from the race-station list before reaching for the generic canonical list above. Hyrox-leaning movements like Wall Balls, Walking Lunges, Burpee Broad Jumps belong in Hyrox sessions — they can appear occasionally in Deka sessions as supplementary work but should NOT dominate main blocks. For Deka variants, prefer: RAM Reverse Lunges, Box Jump / Step Over, Med Ball Sit-up Throw, Farmer's Carry, Dead Ball Yoke Over, RAM Weighted Burpees, plus the machine zones (Row, SkiErg, Air Bike) and Sled Push/Pull.

### 2. Alternating EMOM (2-exercise EMOM with `alternating: true`)

`format: emom`, 2 exercises, **`alternating: true`**. Each exercise gets its own minute (M1 = A, M2 = B, M3 = A, …). 10-20 min long. Each exercise uses the cue with blank reps. Use this when each exercise needs ~30-45s on its own — typically pairing two demanding floor movements (e.g. Burpee Broad Jumps alternating Walking Lunges).

### 3. Continuous circuit (multi-exercise minute rotation, no rest)

`format: continuous_circuit`, 3-4 exercises, `duration_mins` MUST be a multiple of the exercise count (12, 15, 18, 20 min are common). Each minute the athlete works on one exercise for the full 60 seconds — no rest — then rotates to the next exercise next minute. Exercises rotate continuously through the full block. Distinct from EMOM (which has rest-within-minute) — continuous circuit fills every minute with work.

Exercises do NOT carry `reps` or the cue — the prescription is "fill the minute". Pair a cardio movement with 1-2 functional movements for variety: e.g. `Row` + `Box Jump Burpees` + `KB Swings` over 18 min = 6 rounds each. Excellent substitute for two stacked single-exercise EMOMs when you want continuous work without the rest-each-minute pattern.

Canonical pattern: 3 exercises × 6 rounds = 18 min, OR 3 exercises × 5 rounds = 15 min, OR 4 exercises × 3 rounds = 12 min. **This is a core hybrid modality — use it as often as you reach for EMOMs.**

### 4. 30s hard / 30s rest cardio

`format: rounds`, each exercise `duration_s: 30`, section `rest_secs: 30`. 1:1 work-rest is the fixed pattern — `rest_secs` is ALWAYS 30 here. Leave `intensity_style` unset or use `medium`; the hard work is intrinsic to the 30/30 structure. Variants:
- **Single-machine long**: 10-20 rounds (10-20 min) on one cardio modality.
- **Multi-machine split**: 2-3 SEPARATE sections back-to-back, ~5-min each, different machines (e.g. 5 min SkiErg, then 5 min Rower).

Modalities: row, ski, bike, treadmill (and jump rope for activities that allow it). Filtered by each activity's `allowed_equipment`.

This is the headline cardio shape. Use it in most sessions.

### 5. Compromised running rounds

`format: rounds`, 3-4 rounds, each round mixes run (400-800m) with 1-3 functional movements. Name the running movement `Compromised Run` per global_rules. Canonical: `4 rounds × 500m run + 20 wall balls + 30m farmer's carry`. Variants include compromised cardio (no run available) — substitute machine work for the run.

### 6. Hyrox couplets and carry combos

Simple `format: rounds` blocks with 2-3 exercises in each round, NOT mixed with running. Two classic shapes:
- **Couplet**: 5 rounds × `Row 20 cal + Wall Balls 20` (cardio paired with one functional movement). `rest_secs: 60` typical.
- **Carry combo (triplet)**: 4 rounds × `Farmer's Carry 60m + Sled Push 40m + Sled Pull 20m` (carries and sled work stacked). `rest_secs: 60` typical.

Use these for variety alongside compromised running. Keep rep counts uniform across rep-based exercises in a round (e.g. 20 cal row + 20 wall balls).

### 7. Run intervals with active rest

For pure run-repeat sections (not paired with floor work), use `format: rounds` with longer `rest_secs` (60-120s) and a notes hint about active rest. Canonical: `5 rounds × Run 1km, rest_secs: 90` with notes `race pace — 90s easy jog rest between rounds`. Also valid: `6 rounds × Run 400m, rest_secs: 60`, `3 rounds × Run 1600m (mile), rest_secs: 120`. This is DIFFERENT from the 30/30 pattern — longer work, longer rest, intervals at race pace.

### 8. Tabata finisher

`format: tabata` — 8 rounds × 20s work / 10s rest (the schema bakes this in). 1 exercise (single-movement tabata) OR 2 genuinely different exercises alternating. Canonical for hybrid: `Box Jump Burpees alt Shoulder Press`, `Thrusters alt Med Ball Slams`, `KB Swings`, `Burpees alt Sit-ups`. Excellent 4-min close-out alongside (or instead of) a hundred finisher.

### 9. Compromised run ladder

A chipper-shaped descending-run / ascending-rep ladder. Express as `format: for_time` with the full alternating sequence in the exercise list. Canonical: `1000m run / 10 wall balls / 800m run / 20 WB / 600m run / 30 WB / 400m run / 40 WB / 200m run / 50 WB`. Counts as a chipper but is also a hybrid headline shape; it's NOT subject to the "1 in 8-10 chippers" rule that limits typical full-race chippers.

### 10. Descending pyramid chipper

A single-block descending pyramid: a 1km run before each tier of 3 movements (typically cardio + sled + functional), 4 tiers of descending volume. `format: for_time` with 16 exercises listed (4 tiers × (Run + 3 movements)). Canonical: `1000m Run / 80 cal Ski / 80m Sled Push / 80 Wall Balls / 1000m Run / 60 cal Ski / 60m Sled Push / 60 Wall Balls / 1000m Run / 40 cal Ski / 40m Sled Push / 40 Wall Balls / 1000m Run / 20 cal Ski / 20m Sled Push / 20 Wall Balls`. ONE main block, ~45-60 min of work. Use rarely (1 in 6 sessions or so) — when you do, the session is just warm-up + this + cool-down. The 1km runs between tiers are essential to the pattern; do NOT omit them. For activities without running, substitute another cardio (Row 1000m or SkiErg 1000m) between tiers.

### 11. Strength accessory

`format: rounds`, 4-5 rounds, 1-2 heavy compound exercises (Deadlift, Bench Press, Push Press, Bent-Over Row, Pull-ups, Bulgarian Split Squat, etc.), **3-6 reps**, `rest_secs: 120`, `intensity_style: high`. **Include in MOST sessions** (~4 of 5). Never replaces a conditioning block; sits alongside one.

### 12. Hundred finisher

`format: hundred`, single bodyweight or light movement, 100 reps for time. "The Centurion." Movements: Wall Balls 100, Burpees 100, KB Swings 100, Sit-ups 100, Burpee Broad Jumps 100, Box Jumps 100. **Use in most sessions as the close-out** — alternative is an abs finisher.

### 13. Abs finisher

`format: rounds`, 3 rounds × Sit-ups + V-ups + Plank (or similar). Alternative close-out to the hundred. 20 reps + 20 reps + 45s plank is the standard mix.

### 14. Buy in / Cash out bookends

A pair of single-effort sections that frame the main work of the session — a CrossFit-style "buy in" before the main work and a "cash out" after. **Use this pattern roughly 1 in 3 sessions** — it's a key variety mechanism, not a rare special case. The bookends pre-fatigue and post-fatigue around the main piece, adding a distinct test of pacing.

**Schema**: each bookend is its own section, `format: "for_time"` (timed effort). **The Buy In section MUST be named exactly "Buy In"** and **the Cash Out section MUST be named exactly "Cash Out"** so the pattern renders correctly. Buy In comes immediately after the warm-up; Cash Out comes immediately before the cool-down.

**HARD RULE — bookends come in pairs.** If a session includes a Buy In section, it MUST also include a Cash Out section, and vice versa. Never emit one without the other. A workout with just a Buy In and no Cash Out (or just a Cash Out and no Buy In) is broken — the bookend is the whole point.

**Three canonical pairings** — rotate across sessions:
- **Matched cardio**: `Buy In: 1000m Row for time` + `Cash Out: 1000m SkiErg for time`. Different machines bookending the session.
- **Same movement bookend**: `Buy In: 50 Wall Balls for time` + `Cash Out: 50 Wall Balls for time`. Same movement, see how much slower the cash out feels.
- **Different movements**: `Buy In: 50 Box Jumps for time` + `Cash Out: 50 Burpees for time`. Two distinct tests.

A session using bookends keeps the main work tight (1-2 main blocks between the bookends). Total session length stays around 60 min.

When you build a session, ask yourself: should this one use bookends? If it's been a few sessions without them, YES — pick a pairing and use them.

## Intensity guidance

When the request carries an `intensity_style` (low / medium / high), adjust the session shape accordingly. The headline modalities above are mostly tuned for medium — low and high need different choices.

### Low intensity (zone 2, conversational, RPE 4-5)

**Session shape (60 min)**: 5 min warm-up + ONE 22-28 min continuous cardio block + 1-2 short mobility flow sections (3-5 min each) woven into the main session + 8-12 min light technique stations + 8-12 min cool-down. Around 4-6 main blocks total — mobility flows count as their own blocks.

**Cardio — the hard rule**:
- **Long zone 2 cardio (≥10 min on one machine) MUST use `format: straight`** with `duration_mins` set to a round number — typically **15, 20, or 25 min**. Use 12 min only when the rest of the session is dense. NEVER use `format: rounds` for a long single-cardio block at low intensity. Omit the `rounds:` field entirely on these sections.
- **Short cardio intervals are still valid in `format: rounds`** — e.g. `4 rounds × Row 5 min easy` (`duration_s: 300, rest_secs: 60`). The rule is per-round duration: if each round is ≤ 5 min of cardio work, `rounds` is fine. If each round is ≥ 10 min of cardio, it MUST be `straight`.

**Rotate the cardio modality across sessions.** The long zone 2 block can be Run (treadmill), Row (rowing_machine), or SkiErg (ski_erg) — and Air Bike for contracts that allow it. **Don't default to Run every session.** Pick a different modality each time so a week of low-intensity sessions covers all three: one easy run, one easy row, one easy ski. The "treadmill is the backbone" rule for race-prep applies to interval and compromised-running work; for the long zone 2 block specifically, all three machines are equally valid.

BAD (a `rounds` block — wrong format, multiplies the duration):
```
{ "format": "rounds", "rounds": 3, "exercises": [{ "name": "Run", "duration_s": 1440 }] }
```
That renders as `3 rounds × 24min Run = 72 min of cardio`. Wrong.

GOOD (a single `straight` block):
```
{ "format": "straight", "duration_mins": 24, "exercises": [{ "name": "Run", "duration_s": 1440, "notes": "conversational pace — nose-breathing where possible, building aerobic engine" }] }
```
That renders as `Long Run · 24 min`. Correct.

The Long Run / Steady Row pattern is always one `straight` block, regardless of how long the run is.

**Mobility woven into the main session — LOW INTENSITY ONLY.** Mobility is part of the prescribed work alongside the cardio, not just an end-of-session add-on. Two valid shapes:

1. **Standalone mobility flow sections** between cardio and stations, or between stations and cool-down. **MUST use `format: "straight"`, NEVER `format: "rounds"`** — a mobility flow is ONE block that lists multiple drills, each with its own `duration_s`. Set the section's `duration_mins` to the total. Name the section after the area (e.g. "Hip Mobility", "T-spine Flow", "Ankle Prep") — NOT "recovery" or "reset" (those are banned by the global mid-workout recovery rule, which applies to medium/high; LOW intensity is exempt because mobility IS the work).

BAD (`format: rounds` — wrong, multiplies the durations):
```
{ "format": "rounds", "rounds": 3, "exercises": [
  { "name": "90/90 Hip Switches", "duration_s": 90 },
  { "name": "Couch Stretch", "duration_s": 120 }
] }
```

GOOD (`format: straight` — one block, drills run in sequence):
```
{ "format": "straight", "duration_mins": 4, "exercises": [
  { "name": "90/90 Hip Switches", "duration_s": 90, "notes": "45s per side" },
  { "name": "Couch Stretch", "duration_s": 120, "notes": "60s per side" },
  { "name": "Hip CARs", "duration_s": 90, "notes": "both legs" }
] }
```

2. **Mobility moves WITHIN station rounds**: include one duration-based mobility exercise alongside the rep-based functional movements. Duration holds are exempt from the same-rep rule. Example: `4 rounds × Wall Balls 20 (light) + 90/90 Hip Switch 60s + KB Swings 20 (light)`.

**Stations**: Light load, 15-25 reps, technique-focused. 20-30s rest between rounds — "keep moving". Notes on every exercise about form (3-sec eccentric, hip hinge mechanics, knee tracking, full range, controlled tempo).

**Weight prescription (low)**: LIGHT loads, well below the athlete's race/competition weight. If race-day wall ball is 9kg, low intensity is 5-6kg. If race-day sled push uses 1.5× bodyweight, low intensity is 0.5-0.75× bodyweight. The point is form rehearsal and base building — load is incidental. Notes should explicitly call out "light" or "well below race weight" so the athlete knows not to chase weight.

**Avoid for low intensity**: 30/30 cardio, EMOMs, tabata, hundred finishers, heavy strength at 3-6 reps, sprint repeats, compromised running, compromised run ladders, descending pyramids. These are medium/high modalities.

**Cool-down**: 5 min active recovery on a cardio modality (easy ski / row at conversational pace) + 3-5 longer-hold stretches. Different from the woven mobility flows — these are static end-of-session stretches.

**Rotate the mobility focus across sessions.** Each low-intensity session should feature a DIFFERENT primary mobility area — don't default to hip mobility every time. The four areas to rotate through:
- **Hip mobility**: 90/90 Hip Switches, Couch Stretch, Hip CARs, Kneeling Hip Flexor Stretch, Dynamic Lunge Variations
- **Thoracic spine mobility**: Foam Roller Thoracic Extensions, Thoracic Open Books, Cat-Cow, Wall Slides
- **Ankle mobility**: Ankle Circles, Calf Stretch (gastrocnemius + soleus), Ankle Banded Mobilizations, Eccentric Calf Raises
- **Full-body / posterior chain**: World's Greatest Stretch, Pigeon, Down Dog to Cobra, Spinal Twist

A session can have one or two mobility flow sections — if two, pick from DIFFERENT areas (e.g. T-spine flow + ankle flow, NOT two hip flows).

Warm-up can also mention mobility prep in its notes — rotate the focus the same way.

### High intensity (near max, RPE 9-10)

**Session shape (~45 min, shorter than standard)**: 5 min warm-up + 3-4 short heavy/sprint blocks + 5 min cool-down.

**Movements**: heavy compound at 3-5 reps with 180s rest, sprint repeats (15-45s work, 90s+ rest), heavy sled (max load), all-out tabata. Sprint repeats can be 200m runs, 30s machine sprints, 15m heavy sled sprints — full recovery between.

**Weight prescription (high)**: HEAVIER than race/competition weight. Heavy compound accessories (deadlift, bench, push press) use proper strength-training loads — 3-5 reps at near-max, well above race-day fatigue loads. Sled push, heavy carries, and weighted-station work go ABOVE competition weight to train over-tolerance — if Hyrox race sled is 152kg/men, high-intensity sled training is 180kg+. The athlete should feel race weights are easy on race day because they've handled heavier. Notes should explicitly say "heavier than race weight" or "above competition load".

**Avoid for high intensity**: continuous easy cardio, technique-focused light work, slow tempo training, 30/30 (that's threshold, not high), low-rep high-volume rounds.

### Medium intensity (the default)

Most race-family sessions land here. Mix EMOMs, 30/30 cardio, compromised running, strength accessory, hundreds, tabatas, continuous circuits — the full menu. 60 min, 4-6 main blocks.

**Weight prescription (medium)**: RACE / COMPETITION weights — exactly what the athlete would use on race day. For Hyrox men: 9kg wall ball, 24kg-per-hand farmer's carry, full race sled. For Deka: the prescribed zone weights. Medium intensity sessions REHEARSE race-day load — that's what makes them race-prep. Notes can call this out: "race weight", "competition load", or "the load you'll lift on race day".

## Reps cueing

The cue `~50% of your 1-min max (leaves ~20s rest)` is for **single-exercise EMOMs AND alternating EMOMs** (each exercise gets its own minute). In those cases, the athlete picks the volume — so on those exercises:

- Leave `reps` blank.
- Leave `distance_m` blank — even for Sled Push, Farmer's Carry, Bear Crawl, Atlas Carry. The athlete picks the distance just like they pick the reps.
- Leave `calories` blank for cardio machines.
- Set the cue in `notes` only.

**Never combine a fixed metric with the cue** on a single-ex / alternating EMOM exercise. `Sled Push, distance_m: 10, notes: "~50% of your 1-min max"` is contradictory — the cue says "you decide" but the 10m prescribes it. Pick one: either the cue (blank metric) OR a fixed metric (no cue).

EVERYWHERE ELSE — rounds, for_time, hundred, strength, abs, and multi-exercise EMOMs (2-ex "both each minute" / 3+-ex E2MOM) — use plain numeric metrics (integer reps, distance_m, calories) and DROP the cue. Distance-based movements there always carry `distance_m`.

## What to avoid

- Defaulting to long for_time chippers. The compromised-run ladder (modality 5) is a chipper-shaped exception; standard full-race chippers are rare (~1 in 8-10).
- 2-exercise EMOMs that pack both into one minute when neither fits. If you want two movements alongside cardio, use `alternating: true`, split into two separate single-exercise EMOMs, or use a 3+ exercise E2MOM.
- Sessions that only do one type of work. Hybrid means hybrid — most sessions mix EMOM + cardio + strength + finisher.
