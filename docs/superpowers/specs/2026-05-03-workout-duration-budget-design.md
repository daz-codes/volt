# Workout Duration Budget

> **Status:** DRAFT — design approved through brainstorming; spec reviewer not yet run.

## Goal

Make generated workouts reliably fit the requested duration. Today the LLM is told the budget but has no concrete pace data and no automated feedback when it overshoots, so workouts can come back well outside the requested window (a recent 60-min "Smooth Engine" zone-2 session contained ~70+ min of cardio sets alone). Add a duration estimator that walks the workout structure, totals minutes against per-machine pace constants, and (a) feeds those numbers into the generation prompt up-front, and (b) catches misses post-generation and retries the LLM once with concrete feedback.

## Background

Phases 1-3 of the intensity_style work (commit `e3df242`) wired three intensity styles into the schema, prompt, and validator. Phase 4 (commit set ending `196ebe9`, PR #40) added the session-wide selector to the generate modal. With intensity now a first-class dial, paces tied to intensity become available as a single source of truth for both prompt rendering and the new duration estimator.

The existing prompt's session-shape block (`contract_prompt_builder.rb:113-125`) already mentions the working budget but is miscalibrated in two ways: the line *"workouts consistently run long, so cut a section if in doubt"* doesn't match observed behaviour (workouts are usually about right, occasionally a bit short), and there are no concrete pace numbers anywhere in the prompt. The validator (`workout_validator.rb`, ~1950 lines) handles per-section/per-exercise rules but knows nothing about session-level total time.

## Scope

**In scope:**
- New `Workout::PaceTable` constants module (cardio paces by machine × intensity, rep timings by movement category, carry pace).
- New `Workout::DurationEstimator` PORO that totals minutes from the workout structure plus warm-up/cool-down/transitions, with a `fits?` predicate using a +10%/−15% tolerance.
- `WorkoutLLMGenerator` retry loop: max 2 LLM attempts, second triggered only on duration miss, persist whichever attempt is closer to budget.
- `ContractPromptBuilder` renders a new `<pace_reference>` block on every prompt and a `<retry_feedback>` block on retry attempts.
- Remove the miscalibrated *"workouts consistently run long"* line from the prompt.
- Tests for pace table, estimator (every section format), prompt builder (new tags), and generator retry loop.

**Out of scope:**
- Per-user pace calibration (athlete profile-driven paces; interactive calibration tool).
- User-facing display of estimated duration on workout cards or share images.
- Persisting `estimated_min` on the `Workout` model.
- Telemetry / dashboard for duration-accuracy stats.
- More than one retry attempt.
- Tuning pace constants from real-world data (v1 ships with sane defaults; tune later).

## UI

No UI changes in this phase. Estimates are transient (used for retry decision and logging only).

## Architecture

### Components and data flow

```
WorkoutLLMGenerator#generate (retry loop, max 2 attempts)
  ├─ ContractPromptBuilder.build           (reads PaceTable for <pace_reference>)
  ├─ LLM call → workout JSON
  ├─ WorkoutValidator.validate_and_fix     (unchanged — per-section/per-exercise rules only)
  ├─ Workout::DurationEstimator.estimate   (reads PaceTable; returns Result with total_min, breakdown, fits?)
  ├─ if fits? → finalize + log
  └─ else if attempts < 2 → build retry feedback, loop
       else → pick closer-to-budget attempt, finalize + warn
```

### Boundaries

- `PaceTable` knows numbers. Nothing else.
- `DurationEstimator` knows the workout/section schema and how to sum minutes. Knows nothing about prompts or generators.
- `ContractPromptBuilder` reads `PaceTable` for prompt rendering. Doesn't know about the estimator.
- `WorkoutLLMGenerator` orchestrates the retry loop. Knows about all three.

### Files

**New:**
- `app/services/workout/pace_table.rb`
- `app/services/workout/duration_estimator.rb`
- `test/services/workout/pace_table_test.rb`
- `test/services/workout/duration_estimator_test.rb`

**Modified:**
- `app/services/workout_llm_generator.rb` (retry loop)
- `app/services/workout_llm_generator/contract_prompt_builder.rb` (pace + retry tags, remove miscalibrated line)
- `test/services/workout_llm_generator/contract_prompt_builder_test.rb` (new tag tests)
- New or extended retry-loop test under `test/services/workout_llm_generator_test.rb`

## Pace Table

`Workout::PaceTable` is a module of frozen constants. Two consumers: the estimator (lookups) and the prompt builder (`summary_for_prompt` text).

```ruby
ROW_SEC_PER_500M  = { zone_2: 150, conditioning: 130, max_effort: 100, default: 140 }.freeze
SKI_SEC_PER_500M  = { zone_2: 165, conditioning: 145, max_effort: 110, default: 155 }.freeze
RUN_SEC_PER_KM    = { zone_2: 390, conditioning: 330, max_effort: 270, default: 360 }.freeze
BIKE_SEC_PER_CAL  = { zone_2: 4.5, conditioning: 3.0, max_effort: 2.3, default: 3.5 }.freeze
ROW_SEC_PER_CAL   = { zone_2: 4.0, conditioning: 2.8, max_effort: 2.2, default: 3.2 }.freeze
SKI_SEC_PER_CAL   = { zone_2: 4.5, conditioning: 3.2, max_effort: 2.5, default: 3.5 }.freeze

REP_SEC = {
  bodyweight: 3.0, burpee: 4.0, kb_or_db: 3.0, compound_lift: 5.0,
  wall_ball: 3.0, box_jump: 3.0, pull_up: 3.0, default: 3.0
}.freeze

CARRY_SEC_PER_10M = { farmer: 5.0, sled: 7.0, default: 6.0 }.freeze
```

**Calibration intent:** v1 numbers are recreational defaults (row zone 2 ~2:30/500m, ski ~10% slower than row at every intensity, bike zone 2 ~13 cal/min, run zone 2 ~6:30/km, compound lifts 5s/rep). If estimates drift consistently in one direction post-launch, tune. Per-user calibration is a future feature.

## Duration Estimator

```ruby
class Workout::DurationEstimator
  Result = Data.define(:total_min, :breakdown, :requested_min) do
    def fits?(over: 0.10, under: 0.15)
      total_min <= requested_min * (1 + over) &&
        total_min >= requested_min * (1 - under)
    end
    def overshoot_min;  [total_min - requested_min, 0].max; end
    def undershoot_min; [requested_min - total_min, 0].max; end
  end

  def initialize(workout_data, requested_min:); ... end
  def estimate # → Result
end
```

`breakdown` is `[{ name:, min: }, ...]`, one entry per section plus a final `Transitions` entry — used both for logging and for retry feedback.

### Section dispatch

| `kind` / `format` | Calculation |
|---|---|
| `kind: :warm_up` | Flat: 3 min if requested ≤ 30, else 5 min |
| `kind: :cool_down` | Same: 3 / 5 min |
| `format: :rounds` | `(sum exercise times in one round) × rounds + rest_secs × (rounds - 1)` |
| `format: :straight` | `sum exercise times` |
| `format: :emom` | `rounds × 60s` |
| `format: :amrap` | `duration_s` |
| `format: :for_time` | `sum exercise times` (chipper, no rest unless specified) |
| `format: :tabata` | `rounds × 30s` (default 8 rounds = 4 min) |
| `format: :hundred` | `reps × sec_per_rep` (default 100) |
| `format: :ladder` | `sum work_per_rung × exercises + rest_between_rungs × (rungs - 1)`. Walks `start→end` by `step`. |
| `format: :mountain` | Same as ladder, sequence is `start→peak→end`. |
| `format: :switchback` | Pair `start→end` with `end→start` rungs; sum work + rest. |
| Unknown format | Log warning, contribute 0 min. |

### Per-exercise single-set time

```ruby
def exercise_time(ex, intensity_style:)
  return ex[:duration_s] if ex[:duration_s]
  if (machine = cardio_machine(ex[:name]))
    return cardio_time(machine, ex, intensity_style)
  end
  if (carry = carry_type(ex[:name]))
    return CARRY_SEC_PER_10M[carry] * (ex[:distance_m] / 10.0)
  end
  reps = ex[:reps].to_i
  reps * REP_SEC[rep_category(ex[:name])]
end
```

### Movement categorizers (name pattern matching, hardcoded)

```ruby
def cardio_machine(name)
  n = name.downcase
  return :row  if n.match?(/\b(row|rower|rowing machine)\b/)
  return :ski  if n.match?(/\bski/)
  return :bike if n.match?(/\b(assault|echo|air|fan)?\s*bike\b/)
  return :run  if n.match?(/\b(run|treadmill)\b/)
  nil
end

def rep_category(name)
  n = name.downcase
  return :burpee        if n.include?("burpee")
  return :wall_ball     if n.include?("wall ball")
  return :box_jump      if n.include?("box jump")
  return :pull_up       if n.match?(/pull[- ]?up|chin[- ]?up/)
  return :kb_or_db      if n.match?(/^(db |kb |dumbbell |kettlebell |goblet )/)
  return :compound_lift if n.match?(/^(back squat|front squat|deadlift|bench press|overhead press|push press|clean|snatch)\b/)
  :bodyweight
end
```

(Schema-tagged categorisation — adding a `rep_category` field to the exercise schema — is a possible future migration if the pattern matching gets unwieldy.)

### Transitions

`(sections.count - 1) × 180s` (3 min per gap). Aligns with the prompt's "~3-5 min per transition" — using 3 as the base.

### Intensity resolution per section

1. Section's own `intensity_style` if set.
2. Else the workout's session-wide `intensity_style` (from the just-shipped selector).
3. Else `:default`.

### Edge cases

| Case | Behaviour |
|---|---|
| Flow sessions (`contract[:warm_up] == :flow`) | One continuous block, no warm-up/cool-down adders, no transitions. Sum section content directly. |
| Movement name doesn't match any pattern | Falls through to `:bodyweight` (3s/rep). Acceptable degradation. |
| Cardio section with no distance/calories/duration_s | Defensive — log a warning, 0 min for that exercise. |
| `format: nil` or unrecognised | Log warning, 0 min. Don't blow up generation. |
| Workout with no sections | Total = 0. `fits?` false → retry → if still 0 → persist with loud warning. |
| Programs (multi-day, `Program::WorkoutBuilder`) | Inherit retry-and-estimate for free; same generator. |
| Existing fixtures / seed workouts | Not regenerated. Estimator only runs at generation time. |

## Plumbing

### Generator retry loop

```ruby
def generate
  attempts = []
  retry_feedback = nil

  2.times do
    prompt = build_contract_prompt(retry_feedback: retry_feedback)
    workout_data = call_llm(prompt)
    workout_data = validate_and_fix(workout_data)
    estimate = Workout::DurationEstimator.new(workout_data, requested_min: @duration_mins).estimate

    attempts << { workout: workout_data, estimate: estimate }
    log_duration_estimate(estimate)

    break if estimate.fits?
    retry_feedback = build_retry_feedback(estimate)
  end

  chosen = attempts.min_by { |a| (a[:estimate].total_min - @duration_mins).abs }
  log_duration_miss(chosen[:estimate]) unless chosen[:estimate].fits?
  finalize(chosen[:workout], chosen[:estimate])
end
```

### Retry feedback shape

**Overshoot:**
> Previous attempt was estimated at 78 min, but the requested duration is 60 min (acceptable window: 51-66 min). Section breakdown: Warm-up 5, Row Steady 33, Push & Pull 11, Ski Erg Cruise 36, Lower Body Grind 11, Cool-down 5, Transitions 12. Reduce work to fit — the largest sections are the easiest places to cut.

**Undershoot:**
> Previous attempt was estimated at 42 min, but the requested duration is 60 min (acceptable window: 51-66 min). Section breakdown: ... Add work — extend a main section, add a finisher, or increase round counts.

### Prompt changes (`ContractPromptBuilder`)

**Add `<pace_reference>` block** — always rendered, near `session_shape_block`:

```
<pace_reference>
Use these pace estimates when sizing cardio so the workout fits the requested duration.

Row (per 500m): zone_2 ~2:30 / conditioning ~2:10 / max_effort ~1:40
Ski erg (per 500m): zone_2 ~2:45 / conditioning ~2:25 / max_effort ~1:50
Run (per km): zone_2 ~6:30 / conditioning ~5:30 / max_effort ~4:30
Bike (cal/min): zone_2 ~13 / conditioning ~20 / max_effort ~26
Reps: bodyweight/KB/DB ~3s, compound lifts ~5s, burpees ~4s.

Per section: (work × rounds) + (rest × (rounds - 1)).
Total: sum sections + warm-up (3-5 min) + cool-down (3-5 min) + ~3 min per transition.
The total MUST fit the requested duration.
</pace_reference>
```

Body text rendered from `Workout::PaceTable.summary_for_prompt` so prompt and estimator share constants.

**Add `<retry_feedback>` tag** — only rendered when the new `retry_feedback:` kwarg is set. Placed at the top of the prompt body so the LLM reads the correction first.

**Remove/replace** in `session_shape_block` (`contract_prompt_builder.rb:122-123`):

```diff
- Pick the count the workout calls for, not the upper end of the range.
- Err on the side of fewer, tighter sections — workouts consistently run long,
- so cut a section if in doubt.
+ Pick the count the workout calls for, not the upper end of the range.
+ Use the pace_reference above to size each section, then sum the totals
+ — the workout must fit the requested duration.
```

### Logging

- **Always** on every generation: `[duration_estimator] activity=X requested=60 estimated=58 fits=true attempts=1`
- **Warning** when chosen attempt still misses: `[duration_estimator] miss requested=60 estimated=72 attempts=2 best_overshoot=12`

### What does NOT change

- `WorkoutValidator` — untouched. Duration is session-level; validator stays focused on per-section/per-exercise rules.
- Public API of `WorkoutLLMGenerator.call` / `generate` — same signature, same return shape.
- All existing call sites (controller, programs) — keep working unchanged.

## Testing

### `test/services/workout/pace_table_test.rb`
- Lookup helpers return correct numbers for known intensities.
- Default intensity used when style is missing/unknown.
- `summary_for_prompt` non-empty and contains all four cardio machines.

### `test/services/workout/duration_estimator_test.rb` (the bulk)
- One test per format: `rounds`, `straight`, `emom`, `amrap`, `for_time`, `tabata`, `hundred`, `ladder`, `mountain`, `switchback`.
- Cardio per machine + intensity: row distance/calories, ski distance/calories, bike calories, run distance — totals match hand-computed expectations.
- Rep categorisation: bodyweight, KB/DB, compound lift, burpee — each lands in the right bucket and produces the right per-rep time.
- Warm-up/cool-down: flat 3 min for ≤30 min total, 5 min for >30 min.
- Transitions: `(sections - 1) × 3 min` added.
- Intensity resolution: section overrides workout-level; missing falls back to default.
- `fits?` boundary tests: overshoot at +10% (fit), +11% (miss); undershoot at −15% (fit), −16% (miss).
- Edge cases: empty workout (0 min), missing rounds (treated as 1), unknown format (logged, 0 min), flow session (no adders).

### `test/services/workout_llm_generator/contract_prompt_builder_test.rb` — extend
- `<pace_reference>` rendered in every prompt.
- `<retry_feedback>` rendered only when `retry_feedback:` kwarg set (closing-tag refute pattern).
- Removed line *"workouts consistently run long"* no longer appears.

### Retry loop integration
- One LLM call when first attempt fits → no retry.
- Two LLM calls when first misses, second fits → second persisted.
- Two LLM calls when both miss → closer-to-budget persisted, warning logged.
- Same `define_singleton_method` stub pattern used in the intensity branch.

## Risks and non-obvious bits

- **Pace constants are defaults, not truths.** Real athlete pace varies wildly. v1 numbers reflect a typical recreational athlete — they will be wrong for slower/faster users. The retry loop is the safety net while the prompt-side numbers do the heavy lifting on the first attempt. Calibration is post-launch.
- **The estimator and the LLM must agree on warm-up/cool-down/transition budgets.** Both use 3 min (≤30 min total) / 5 min (>30 min total) for warm-up/cool-down and 3 min per transition. If those constants drift between estimator and prompt, retries become inconsistent.
- **`for_time` and chipper estimates are athlete-pace-dependent** more than other formats. We estimate using rep-based timings, which can be off for elite or beginner athletes. Acceptable margin given the +10%/-15% tolerance.
- **EMOM is always rounds × 60s in the estimator.** This is correct by definition (each minute consumed) but means a poorly-sized EMOM (work too short) won't be caught by the duration estimator — the validator's existing EMOM rules are the right place for that.
- **Programs inherit the retry behaviour automatically.** A 5-day program will pay 5× the retry cost in the worst case. Acceptable for now; revisit if program generation becomes slow.
- **Movement categorizer fallback to `:bodyweight`.** A novel movement (something not yet in the patterns) costs 3s/rep. If we add a new movement category in REP_SEC without updating the categorizer, the estimator silently uses default. Tests guard against the existing categories drifting.
- **Single source of truth, two readers.** `PaceTable` is read by both the estimator and the prompt builder. Refactoring the table should regenerate the prompt summary; testing both consumers catches drift.

## Future phases (not part of this spec)

- **Per-user pace calibration.** Profile-driven pace tables; an interactive "do a 3-min row test" calibration flow. Substantial design work — defer.
- **Estimated-duration display.** Show `est. 58 min` next to `60 min` on workout cards. Requires a small UI decision (prefix vs suffix; tooltip explanation).
- **Persist `estimated_min` on `Workout`.** Add a column. Useful once display lands or for telemetry.
- **Telemetry / accuracy dashboard.** Aggregate estimated-vs-completed deltas across all workouts to tune pace constants.
- **Schema-tagged movement categorisation.** If pattern matching gets unwieldy, add `rep_category` to the exercise schema and have the LLM tag it directly.
- **More retries.** If data shows two attempts isn't enough, raise the cap.
