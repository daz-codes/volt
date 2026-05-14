# Hybrid race-family style

## 1. Headline modalities — push these to the front

Hybrid sessions must lean heavily on these four shapes. Most sessions use 2-3 of them. A long for_time chipper is allowed occasionally (roughly 1 in 8-10 sessions) — never the default.

- **EMOM family** (`format: emom`) — 8-15 min blocks.
  - 1 or 2 exercises render as **EMOM** (every 1 min). Both exercises share each minute when 2 are listed. Alternatively more exercises can be given on a rotating basis, so each exercise is completed every round. The LLM may program these as "all exercises each minute" OR "exercises rotate across rounds" — both are valid.
  - 3+ exercises render as **E2MOM** (every 2 min, all exercises in the cycle).
  - Canonical EMOM movements (priority should be given to the movements that are in the event, if known): **wall balls, lunges, burpees, dead ball yoke over, sit-ups, box step-overs, KB swings, med ball slams, KB thrusters, shoulder press, floor-to-ceilings.**
- **30s hard / 30s rest cardio blocks** (`format: rounds`, `duration_s: 30`, `rest_secs: 30`):
  - Single-machine: 10-20 min on one cardio modality (~10-20 rounds).
  - Multi-machine: ~5 min per machine across 2-4 machines (e.g. row 5 min → ski 5 min → bike 5 min, 30/30 throughout).
  - Use any cardio modality the activity allows — row, ski, bike, treadmill, OR jump rope for activities that allow it. The activity contract's `allowed_equipment` filters down.
- **Compromised-running rounds** (`format: rounds`):
  - 3-4 rounds of `Compromised Run` (400-800m) + 2-3 exercises from the event.
  - Canonical (for Hyrox): `3 rounds: 800m Compromised Run + 30 Wall Balls + 20 Burpee Broad Jumps + 40m Farmer's Carry`.
  - Pushes the global_rules baseline of 3-4 rounds × 400-800m run × 30+ partner reps; this is the headline shape for race-day specificity.
- **Continuous circuits** (`format: continuous_circuit`):
  - 1 min straight per exercise, no reps, rotate through the list. `duration_mins` must be a multiple of the exercise count.
  - Use for variety alongside the rep-then-rest EMOM family.

## 2. Your-call reps cueing

For canonical EMOM movements (the list in section 1) when they appear inside an EMOM / E2MOM:

- Leave `reps` blank on the exercise.
- Write the per-exercise `notes` cue as: **`~50% of your 1-min max (leaves ~20s rest)`**.

The athlete supplies the actual rep number. Distance-based movements (Farmer's Carry, Sled, Bear Crawl) keep `distance_m`. Duration-holds keep `duration_s`.

The same cue is NOT used outside the EMOM family — a `rounds` or `for_time` section with wall balls still prescribes a concrete rep count.

## 3. Volume targets

- Most sessions include 1 EMOM block (10 min typical) AND a cardio block (30/30 or compromised running).
- A session with only an EMOM and no cardio block — or only cardio and no EMOM — is fine occasionally but should not be the default.
- One long for_time chipper is allowed roughly 1 in 8-10 sessions.
- Other modalities such as ladders, up-and-down ladders, mountains, etc. can be used, but the bread and butter should be EMOMs.
- It's also fine to use other cardio rounds (such as 4 rounds of 250m row), but the 30/30 pattern should be used often, especially if intensity is set to `high`.
- Do NOT use 30/30 sets if intensity is set to `low`.

## 4. Race stations remain race stations

Race-day stations (Hyrox's 8, Deka's 10, Atlas's strongman stations) stay the **headline movements** for their respective contracts. The shared file *adds* prominence to EMOMs and 30/30 cardio; it doesn't replace stations.

## 5. What to avoid

- Defaulting to a long for_time chipper every session — fine occasionally, not the norm.
- Prescribing a numeric `reps` value on canonical EMOM movements *inside* an EMOM (let the cue do it).
- Pairing a cardio machine with a floor or carry station inside a single-minute EMOM. For an E2MOM (3+ exercises, 2-min cycle) this is fine — the 2-min frame leaves room.

## 6. Shared movement vocabulary

- **Supplementary movements** (most sessions weave 1-2): KB Swings, KB Thrusters, KB High Pull, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press.
- **Strength accessory** (most non-race-simulation sessions — max 1 strength block, never the centrepiece): Bench Press, Deadlift, Romanian Deadlift, Sumo Deadlift, Single-Leg Deadlift, Split Squat, Bulgarian Split Squat, B-stance Squat, B-stance Deadlift, Landmine Press, Landmine Row, Push Press, Bent-Over Row, Pull-ups, Chin-ups, Dips, Toes-to-bar.
- **Burpee variations**: Box Jump Burpees, Plate Burpees, Wall Ball Burpees, KB Burpees.
- **Abs finisher** (optional close-out): Sit-ups, Leg Raises, Plank, V-ups, Russian Twists, Hollow Holds.

Activities with their own variant-specific vocabulary additions keep those in their own contract.

## 7. Strength accessory rules

- Most non-race-simulation sessions include one strength accessory block.
- `format: rounds`, 3-6 reps heavy at 120s rest with `intensity_style: high`, OR 8-10 reps moderate at 90s rest.
- Never more than one strength block per session, never the centrepiece, never replaces a run or a station.

## 8. Duration-interval pattern

- A 3-4 round work-rest block on a single conditioning movement (Wall Balls, Burpees, Walking Lunges, KB Swings, Med Ball Slams) is a valid alternative to rep-based rounds.
- Use `format: rounds` with `duration_s: 120` and `rest_secs: 120` for the canonical 2-min work / 2-min rest shape.
- The clean-minute rule (work + rest = 60s) applies only to cardio machines, not to these functional movements.
