# Hybrid race-family style

## 1. Headline modalities — push these to the front

Hybrid sessions must lean heavily on these four shapes. Most sessions use 2-3 of them. A long for_time chipper is allowed occasionally (roughly 1 in 8-10 sessions) — never the default.

- **EMOM family** (`format: emom`) — 8-15 min blocks.
  - **Single-exercise EMOM** (1 exercise) is the headline shape — every minute, same movement, your-call reps with the cue below. Reach for this MOST often.
  - **Two-exercise EMOM** (2 exercises) renders as "both exercises each minute". The HARD constraint is total work per minute ≤ ~30-45s, leaving ~15-30s rest. **Use SMALL ABSOLUTE rep/cal/distance numbers — typically 5/5, 8/8, 10 cal/5 reps, 100m/5 reps — NOT the `~50% of your 1-min max` cue.** The cue is sized for single-exercise EMOMs where one movement fills the minute; with two movements that math breaks. Examples: `SkiErg 5 cal + Med Ball Sit-up Throw 5 reps` (each ~15s), `Row 100m + Burpees 5`, `Sandbag Lunges 5 + KB Swings 5`, `Wall Balls 8 + KB Swings 8`. AVOID pairings where either exercise needs ≥30s alone (e.g. `KB Swings 15 + SkiErg 10 cal` — both ~25-30s, total ~55s, no room for rest).
  - **For alternating-per-minute feel** (cardio one minute, floor the next): emit as TWO separate single-exercise EMOM sections back-to-back — e.g. `EMOM 5 min · Wall Balls` followed by `EMOM 5 min · SkiErg 10 cal`. The LLM does NOT have a single-section "alternating EMOM" format available; do not try to encode one with a 2-exercise EMOM.
  - **E2MOM** (3+ exercises) renders as "all exercises every 2 minutes". Use SMALL ABSOLUTE numbers (typically 5-10 reps, 5-10 cal, 50-100m per exercise) so the total work across all listed exercises fits ~60-90s of the 2-minute cycle, leaving ~30-60s rest. Do NOT use the `~50% of 1-min max` cue — that's a single-exercise EMOM cue. Cardio + floor in an E2MOM is fine — the 2-min frame leaves room.
  - Canonical EMOM movements (priority should be given to the movements that are in the event, if known): **wall balls, lunges, burpees, dead ball yoke over, sit-ups, box step-overs, KB swings, med ball slams, KB thrusters, shoulder press, floor-to-ceilings.**
- **30s hard / 30s rest cardio blocks** (`format: rounds`, `duration_s: 30`, `rest_secs: 30`):
  - Single-machine: 10-20 min on one cardio modality (~10-20 rounds).
  - Multi-machine: ~5 min per machine across 2-4 machines (e.g. row 5 min → ski 5 min → bike 5 min, 30/30 throughout).
  - Use any cardio modality the activity allows — row, ski, bike, treadmill, OR jump rope for activities that allow it. The activity contract's `allowed_equipment` filters down.
  - **CRITICAL**: `rest_secs: 30` is FIXED. Do NOT use 60s, 90s, or 120s rest — the 1:1 work-rest IS the defining pattern of 30/30. The high-intensity "Cardio sprints: 90-120s rest" rule in `global_rules.md` applies to SEPARATE all-out sprint repeats (e.g. 6 × 20s sprint with 100s rest), NOT to the 30/30 pattern. A 30/30 block stands on its own — neither all-out sprints nor easy cardio.
- **Compromised-running rounds** (`format: rounds`):
  - 3-4 rounds of `Compromised Run` (400-800m) + 2-3 exercises from the event.
  - Canonical (for Hyrox): `3 rounds: 800m Compromised Run + 30 Wall Balls + 20 Burpee Broad Jumps + 40m Farmer's Carry`.
  - Pushes the global_rules baseline of 3-4 rounds × 400-800m run × 30+ partner reps; this is the headline shape for race-day specificity.
- **Continuous circuits** (`format: continuous_circuit`):
  - 1 min straight per exercise, no reps, rotate through the list. `duration_mins` must be a multiple of the exercise count.
  - Use for variety alongside the rep-then-rest EMOM family.

## 2. Your-call reps cueing

For canonical EMOM movements (the list in section 1) when they appear inside a **single-exercise EMOM** (1 exercise, every minute the same movement):

- Leave `reps` blank on the exercise.
- Write the per-exercise `notes` cue as: **`~50% of your 1-min max (leaves ~20s rest)`**.

The athlete supplies the actual rep number. Distance-based movements (Farmer's Carry, Sled, Bear Crawl) keep `distance_m`. Duration-holds keep `duration_s`.

**The cue is ONLY for single-exercise EMOMs.** Multi-exercise EMOMs (2-ex EMOM, 3+-ex E2MOM) use SMALL ABSOLUTE numbers instead — 5 reps, 5 cal, 100m — chosen so the per-minute (or per-2-min for E2MOM) work fits the time budget. The cue assumes one movement fills the minute; with two or more movements that math breaks.

The cue is NOT used outside the EMOM family — a `rounds` or `for_time` section with wall balls still prescribes a concrete rep count.

## 3. Volume targets

- **EMOMs are the bread and butter of hybrid sessions.** Most sessions include AT LEAST 1 EMOM block. **Roughly 1 in 3 sessions feature TWO EMOM blocks** — typically an EMOM main piece (10-12 min) plus a shorter EMOM finisher (5-8 min). Use different canonical movements across the two blocks.
- **30/30 cardio blocks MUST appear in roughly 1 in 3 sessions** — at least once across every 3 generated workouts. This is the headline cardio shape; do not skip it.
- Most sessions also include a cardio block (30/30 or compromised running) alongside the EMOM(s).
- **`hundred` format finishers** (100 reps of one movement for time — "The Centurion") are excellent close-outs for race-prep sessions; use them in **roughly 1 in 5 sessions**. Movements: Wall Balls 100, Burpees 100, KB Swings 100, Sit-ups 100, Burpee Broad Jumps 100, Box Jumps 100 (whatever's in the activity's allowed equipment).
- One long for_time chipper is allowed roughly 1 in 8-10 sessions.
- Other modalities (ladders, up-and-down ladders, mountains, continuous_circuit) can be used for variety, but the bread and butter is EMOMs + 30/30 + compromised running.
- Other cardio rounds (such as 4 rounds of 250m row) are fine but DON'T default to them — pick 30/30 first if cardio is the goal.
- Do NOT use 30/30 sets if intensity is set to `low`.

## 4. Race stations remain race stations

Race-day stations (Hyrox's 8, Deka's 10, Atlas's strongman stations) stay the **headline movements** for their respective contracts. The shared file *adds* prominence to EMOMs and 30/30 cardio; it doesn't replace stations.

## 5. What to avoid

- Defaulting to a long for_time chipper every session — fine occasionally, not the norm.
- Prescribing a numeric `reps` value on canonical EMOM movements *inside* an EMOM (let the cue do it).
- Oversizing the work inside a 2-exercise EMOM. Total work must fit ~30-45s per minute. BAD: `KB Swings 15 + SkiErg 10 cal` — both need ~25-30s, total ~55s, no room for rest. GOOD: `KB Swings 5 + SkiErg 5 cal` — both ~15s, total ~30s. If you want longer cardio + floor work, split into separate single-exercise EMOM sections, use a 3+ exercise E2MOM, or use `format: rounds` with explicit `rest_secs`.

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
