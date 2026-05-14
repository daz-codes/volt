# Hybrid race-family style

## Session shape

Race-family sessions are dense. **60-minute sessions typically have 5-6 main blocks; 45-minute sessions 3-5; 30-minute sessions 2-3.** This overrides the general "1-3 main sections" target in global_rules.md for hybrid race-family. Variety inside one session is the point — most sessions mix several modalities below.

## Headline modalities

Pick **4-6 of these per 60-min session** (3-5 for 45 min, 2-3 for 30 min). Aim for variety across sessions — not every session needs every modality.

### 1. Single-exercise EMOM (the dominant EMOM shape)

`format: emom` with 1 exercise. **10-20 min long.** Same canonical movement every minute. Use the cue: leave `reps` blank, set `notes: "~50% of your 1-min max (leaves ~20s rest)"`. Many sessions have two single-exercise EMOMs stacked (e.g. 10 min Box Jump Burpees + 10 min KB Swings).

Canonical movements: wall balls, walking lunges, burpees (including box jump burpees, burpee broad jumps), KB swings, KB thrusters, box step-overs, sit-ups, med ball slams, shoulder press, floor-to-ceilings, dead ball yoke over, sandbag lunges.

### 2. Alternating EMOM (2-exercise EMOM with `alternating: true`)

`format: emom`, 2 exercises, **`alternating: true`**. Each exercise gets its own minute (M1 = A, M2 = B, M3 = A, …). 10-20 min long. Each exercise uses the cue with blank reps. Use this when each exercise needs ~30-45s on its own — typically pairing two demanding floor movements (e.g. Burpee Broad Jumps alternating Walking Lunges).

### 3. 30s hard / 30s rest cardio

`format: rounds`, each exercise `duration_s: 30`, section `rest_secs: 30`. 1:1 work-rest is the fixed pattern — `rest_secs` is ALWAYS 30 here. Leave `intensity_style` unset or use `medium`; the hard work is intrinsic to the 30/30 structure. Variants:
- **Single-machine long**: 10-20 rounds (10-20 min) on one cardio modality.
- **Multi-machine split**: 2-3 SEPARATE sections back-to-back, ~5-min each, different machines (e.g. 5 min SkiErg, then 5 min Rower).

Modalities: row, ski, bike, treadmill (and jump rope for activities that allow it). Filtered by each activity's `allowed_equipment`.

This is the headline cardio shape. Use it in most sessions.

### 4. Compromised running rounds

`format: rounds`, 3-4 rounds, each round mixes run (400-800m) with 1-3 functional movements. Name the running movement `Compromised Run` per global_rules. Canonical: `4 rounds × 500m run + 20 wall balls + 30m farmer's carry`. Variants include compromised cardio (no run available) — substitute machine work for the run.

### 5. Compromised run ladder

A chipper-shaped descending-run / ascending-rep ladder. Express as `format: for_time` with the full alternating sequence in the exercise list. Canonical: `1000m run / 10 wall balls / 800m run / 20 WB / 600m run / 30 WB / 400m run / 40 WB / 200m run / 50 WB`. Counts as a chipper but is also a hybrid headline shape; it's NOT subject to the "1 in 8-10 chippers" rule that limits typical full-race chippers.

### 6. Strength accessory

`format: rounds`, 4-5 rounds, 1-2 heavy compound exercises (Deadlift, Bench Press, Push Press, Bent-Over Row, Pull-ups, Bulgarian Split Squat, etc.), **3-6 reps**, `rest_secs: 120`, `intensity_style: high`. **Include in MOST sessions** (~4 of 5). Never replaces a conditioning block; sits alongside one.

### 7. Hundred finisher

`format: hundred`, single bodyweight or light movement, 100 reps for time. "The Centurion." Movements: Wall Balls 100, Burpees 100, KB Swings 100, Sit-ups 100, Burpee Broad Jumps 100, Box Jumps 100. **Use in most sessions as the close-out** — alternative is an abs finisher.

### 8. Abs finisher

`format: rounds`, 3 rounds × Sit-ups + V-ups + Plank (or similar). Alternative close-out to the hundred. 20 reps + 20 reps + 45s plank is the standard mix.

## Reps cueing

The cue `~50% of your 1-min max (leaves ~20s rest)` is for **single-exercise EMOMs AND alternating EMOMs** (each exercise gets its own minute). In those cases, leave `reps` blank and set the cue in `notes`.

EVERYTHERE ELSE — rounds, for_time, hundred, strength, abs — use plain integer reps.

Distance-based movements (Farmer's Carry, Sled, Bear Crawl) always use `distance_m`.

## What to avoid

- Defaulting to long for_time chippers. The compromised-run ladder (modality 5) is a chipper-shaped exception; standard full-race chippers are rare (~1 in 8-10).
- 2-exercise EMOMs that pack both into one minute when neither fits. If you want two movements alongside cardio, use `alternating: true`, split into two separate single-exercise EMOMs, or use a 3+ exercise E2MOM.
- Sessions that only do one type of work. Hybrid means hybrid — most sessions mix EMOM + cardio + strength + finisher.
