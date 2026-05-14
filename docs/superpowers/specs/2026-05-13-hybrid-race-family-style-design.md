# Hybrid race-family shared style — design

## Problem

The 7 race-family activity contracts — Hyrox, Hybrid Race, Deka, Deka Fit, Deka Strong, Deka Mile, Deka Atlas — duplicate roughly 70% of their `notes:` strings and most of their `MOVEMENT_VOCABULARY` blocks word-for-word. The "Supplementary movements", "Strength accessory", "Duration intervals", and "Abs finisher" paragraphs are copy-pasted across files. Maintenance cost is 7×.

More importantly, the contracts don't put hybrid-style modalities at the forefront. The user wants race-family workouts to lean heavily on:

- EMOM / E2MOM blocks (canonical movements: wall balls, lunges, burpees, dead ball yoke over, sit-ups, box step-overs, KB swings, med ball slams, KB thrusters, shoulder press, floor-to-ceilings).
- 30s hard / 30s rest cardio blocks (10-20 min on one machine, OR ~5 min per machine across multiple).
- Compromised-running rounds (3-4 rounds of run + heavy partner movement + carry).
- Athlete-calibrated "your-call reps" cueing on the EMOM movements: `~50% of your 1-min max (leaves ~20s rest)`.

Today these modalities are technically supported but receive no prominence; race-family workouts default to long for_time chippers and run-station pairings.

## Goal

One shared style file describes hybrid race-family training. All 7 race contracts opt in via a flag. Each contract's own `notes:` and `MOVEMENT_VOCABULARY` shrink to only what's genuinely unique to that activity. All 21 example workouts (3 per contract) are rewritten so the EMOM / 30-30 / compromised-running shapes are visibly the default.

## Architecture

### Shared file

New file `app/llm_context/shared/hybrid_style.md`. Sits alongside the existing `global_rules.md` and `warm_up_cool_down.md`.

### Opt-in flag

Each race-family contract adds:

```ruby
hybrid_family: true
```

### Prompt builder injection

`app/services/workout_llm_generator/contract_prompt_builder.rb`:

- New constant `HYBRID_STYLE_PATH = Rails.root.join("app/llm_context/shared/hybrid_style.md").freeze`.
- New class method `self.hybrid_style` (memoized; mirrors `global_rules` at lines 19, 45-47).
- In `build`, after the `<global_rules>` tag (line 37), inject:

  ```ruby
  tags << xml(:hybrid_style, self.class.hybrid_style) if contract[:hybrid_family]
  ```

`<hybrid_style>` sits as a sibling to `<global_rules>` — same authority level, race-family-scoped.

When the flag is absent (the other 10 activities), nothing changes.

## Content of `hybrid_style.md`

Five labelled sections. The file uses concrete schema-field references so the LLM knows exactly what to emit.

### 1. Headline modalities — push these to the front

> Hybrid sessions must lean heavily on these four shapes. Most sessions use 2-3 of them. A long for_time chipper is allowed occasionally (roughly 1 in 8-10 sessions) — never the default.

- **EMOM family** (`format: emom`) — 8-15 min blocks.
  - 1 or 2 exercises render as **EMOM** (every 1 min). Both exercises share each minute when 2 are listed. Alternatively more exercises can be given on a rotating basis, so each exercise is completed every round.The LLM may program these as "all exercises each minute" OR "exercises rotate across rounds" — both are valid.
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

### 2. Your-call reps cueing

For canonical EMOM movements (the list in section 1) when they appear inside an EMOM / E2MOM:

- Leave `reps` blank on the exercise.
- Write the per-exercise `notes` cue as: **`~50% of your 1-min max (leaves ~20s rest)`**.

The athlete supplies the actual rep number. Distance-based movements (Farmer's Carry, Sled, Bear Crawl) keep `distance_m`. Duration-holds keep `duration_s`.

The same cue is NOT used outside the EMOM family — a `rounds` or `for_time` section with wall balls still prescribes a concrete rep count.

### 3. Volume targets

- Most sessions include 1 EMOM block (10 min typical) AND a cardio block (30/30 or compromised running).
- A session with only an EMOM and no cardio block — or only cardio and no EMOM — is fine occasionally but should not be the default.
- One long for_time chipper is allowed roughly 1 in 8-10 sessions (2 examples across the 21).
- Other modalities such as ladders, up and down ladders, mountains etc can be used, but the bread and butter should be EMOMs
- It's also fine to use other cardio rounds (such as 4 rounds of 250m row), but the 30/30 pattern should be used often, especially if intensity is set to high
- Do NOT use 30/30 sets if intensity is set to low

### 4. Race stations remain race stations

Race-day stations (Hyrox's 8, Deka's 10, Atlas's strongman stations) stay the **headline movements** for their respective contracts. The shared file *adds* prominence to EMOMs and 30/30 cardio; it doesn't replace stations.

### 5. What to avoid

- Defaulting to a long for_time chipper every session — fine occasionally, not the norm.
- Prescribing a numeric `reps` value on canonical EMOM movements *inside* an EMOM (let the cue do it).
- Pairing a cardio machine with a floor or carry station inside a single-minute EMOM (per global_rules line 43). E2MOM (3+ exercises, 2-min cycle) is exempt — the 2-min frame leaves room.

### 6. Shared movement vocabulary

Pulled out of each contract's MOVEMENT_VOCABULARY so it lives once:

- **Supplementary movements** (most sessions weave 1-2): KB Swings, KB Thrusters, KB High Pull, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press.
- **Strength accessory** (most non-race-simulation sessions — max 1 strength block, never the centrepiece): Bench Press, Deadlift, Romanian Deadlift, Sumo Deadlift, Single-Leg Deadlift, Split Squat, Bulgarian Split Squat, B-stance Squat, B-stance Deadlift, Landmine Press, Landmine Row, Push Press, Bent-Over Row, Pull-ups, Chin-ups, Dips, Toes-to-bar.
- **Burpee variations**: Box Jump Burpees, Plate Burpees, Wall Ball Burpees, KB Burpees.
- **Abs finisher** (optional close-out): Sit-ups, Leg Raises, Plank, V-ups, Russian Twists, Hollow Holds.

Activities with their own variant-specific vocabulary additions (e.g. Atlas's DB Devil Press, Deka Atlas's Surrender Lunges) keep those in their own contract.

### 7. Strength accessory rules

(Moved from per-contract notes; identical across the family.)

- Most non-race-simulation sessions include one strength accessory block.
- `format: rounds`, 3-6 reps heavy at 120s rest with `intensity_style: high`, OR 8-10 reps moderate at 90s rest.
- Never more than one strength block per session, never the centrepiece, never replaces a run or a station.

### 8. Duration-interval pattern

(Moved from per-contract notes; identical across the family.)

- A 3-4 round work-rest block on a single conditioning movement (Wall Balls, Burpees, Walking Lunges, KB Swings, Med Ball Slams) is a valid alternative to rep-based rounds.
- Use `format: rounds` with `duration_s: 120` and `rest_secs: 120` for the canonical 2-min work / 2-min rest shape.
- The clean-minute rule (work + rest = 60s) applies only to cardio machines, not to these functional movements.

## Per-contract changes

Each of the 7 race contracts changes in three ways:

### 1. Add the flag

```ruby
hybrid_family: true,
```

### 2. Strip duplicated paragraphs from `notes:` and `MOVEMENT_VOCABULARY`

Remove the Supplementary / Strength accessory / Duration intervals / Abs finisher paragraphs from `notes:` — they live in `hybrid_style.md` now.

Remove the corresponding lines from `MOVEMENT_VOCABULARY`.

Keep only the **unique** bits per contract:

| Contract | Kept in own notes / vocabulary |
|---|---|
| **Hyrox** | Air Bike is banned. 1 km × 8 stations is the race shape. Treadmill is the backbone. Existing `banned_exercise_patterns` for assault/air/echo bike. |
| **Hybrid Race** | Wide station library — most sessions use 4-6 stations, not all of them. |
| **Deka Fit** | 10-zone names + `race_simulation` finisher behaviour (10-zone full-race). |
| **Deka** | 10-zone (generic) + `race_simulation` behaviour. |
| **Deka Strong** | No running. 30/30 machine intervals or 400m machine repeats substitute for runs. |
| **Deka Mile** | Running-heavy variant — 800m–mile repeats are the backbone; tempo runs and mile-rep engine blocks. |
| **Deka Atlas** | No running. Jump rope is the only race-relevant cardio — machines exist for warm-up and engine work but the race-station cardio is jump rope. Strongman-style barbell + DB stations. Wall ball and pull-up bar banned (as today). Atlas-specific stations: Atlas Shoulder to Carry, Surrender Lunges, DB Bear Crawl, Bar-Facing Burpees Over Bar, etc. |

### 3. Rewrite all 3 EXAMPLES

Each contract has exactly 3 examples (enforced by `contract_integrity_test.rb`). All 21 get rewritten so:

- At minimum 2 of 3 examples per contract feature an EMOM or 30/30 cardio or compromised-running block (i.e. one of the headline shapes).
- Across all 21 examples, exactly **2 are long for_time chippers** (the "1 in 8-10" rate, ~9.5%).
- All canonical EMOM movements inside EMOM blocks use the `~50% of your 1-min max (leaves ~20s rest)` notes cue with `reps` blank.
- Per-contract uniqueness still shows up: Hyrox examples feature treadmill 500m–1km runs; Deka Mile examples feature 800m–mile repeats; Atlas examples use jump rope (Single/Double Unders) for any cardio block, not machine intervals; Deka Strong examples use no runs.

Each contract's example bodies shrink only slightly — most of the change is which formats appear, not size.

## Schema & builder tweaks

### A. Tool schema `notes` description

`app/services/workout_llm_generator.rb` line 63. Append to the existing description:

> Athlete-relative effort cues that reference rep targets are allowed (e.g. `~50% of your 1-min max`). The 'never put reps in notes' rule applies to numeric rep counts that duplicate the `reps` field — not to athlete-calibrated cues.

### B. Tool schema `emom` description

`workout_llm_generator.rb` line 39. Replace the misleading clause `"all listed exercises share each minute, max 2 — usually 1"` with what the renderer actually does:

> 1-2 exercises render as EMOM (every 1 min); 3+ exercises render as E2MOM (every 2 min, all exercises in the cycle). Multi-exercise EMOMs may do all exercises each minute OR rotate exercises across rounds — programming choice.

### C. `global_rules.md` line 43

The current rule bans cardio + floor pairings inside an EMOM section. Soften so it applies only to single-minute multi-exercise EMOMs (1-2 exercises). For the 3+ exercise (E2MOM) case, cardio + floor inside the 2-min cycle is fine — the per-exercise 30-45s work guideline still applies.

### D. `contract_integrity_test.rb`

Add a positive assertion that all 7 race-family contracts have `hybrid_family: true`. The test today doesn't reject extra contract keys, so the existing assertions continue to pass without further change.

## Testing

- New unit test: `ContractPromptBuilder` injects `<hybrid_style>...</hybrid_style>` for contracts with `hybrid_family: true`, omits it for contracts without.
- Existing `contract_integrity_test.rb` re-runs against all 21 rewritten examples — verifies equipment validity (each exercise's `equipment` is in the activity's `allowed_equipment`), banned-pattern violations, and 3-example count.
- Manual smoke: generate one workout for each of the 7 race activities post-change and confirm the EMOM / 30-30 / compromised-running prominence shows up.

## Out of scope

- **E3MOM (every 3 min cycle).** The renderer hardcodes `duration_mins / 2 = rounds` for 3+ exercise EMOMs, so genuine E3MOM is not in the schema today. Tracked as a separate follow-up; this work accepts current E2MOM behaviour for 3+ exercise blocks.
- **Schema field for explicit `emom_cycle_secs`.** Not needed — the exercise-count convention already encodes the cycle.
- **Sharing this style with adjacent non-race activities** (CrossFit, Functional Muscle). The flag would let them opt in later if desired.

## Files touched

**New**:

- `app/llm_context/shared/hybrid_style.md`

**Modified**:

- `app/services/workout_llm_generator/contract_prompt_builder.rb` — load + inject the shared file.
- `app/services/workout_llm_generator.rb` — tweak `notes` and `emom` descriptions in the tool schema.
- `app/llm_context/shared/global_rules.md` — soften the EMOM cardio + floor rule for E2MOM.
- `lib/llm_context/activities/hyrox.rb`
- `lib/llm_context/activities/hybrid_race.rb`
- `lib/llm_context/activities/deka.rb`
- `lib/llm_context/activities/deka_fit.rb`
- `lib/llm_context/activities/deka_strong.rb`
- `lib/llm_context/activities/deka_mile.rb`
- `lib/llm_context/activities/deka_atlas.rb`
- `test/llm_context/contract_integrity_test.rb` — add `hybrid_family` positive assertion.

**New tests**:

- `test/services/workout_llm_generator/contract_prompt_builder_test.rb` — covers the `<hybrid_style>` injection (or expand if one already exists).
