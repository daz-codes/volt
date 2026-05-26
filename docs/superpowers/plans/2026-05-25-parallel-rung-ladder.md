# Parallel-rung ladder support (PR 2) — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach `format: ladder` and `format: mountain` sections to carry per-exercise rung scales so mixed-unit ladders (e.g. 500/400/300/200/100m Run paired with 50/40/30/20/10 Box Jumps) become first-class rather than being dropped, swapped, or smashed into a single shared sequence.

**Architecture:** Section keeps the existing `varies` / `start` / `end` / `step` (/ `peak`) fields as defaults. Each exercise *may* override with its own copy of any subset of those keys. A new helper module (`Workout::LadderSequence`) becomes the single source of truth for "what numeric sequence does this exercise see?" — section-default ladders keep working unchanged because the helper falls through to the section's keys when overrides are absent. The validator gets one new pass (rung-count parity) and four existing fixers learn to read the helper instead of bare section/exercise fields. The renderer gains a second display mode: when any exercise overrides the section scale, the shared header sequence is suppressed and each exercise gets its own rung row (the same shape switchback already uses).

**Tech Stack:** Rails 8, Minitest, Anthropic SDK (tool-use). The design lives in the project memory at `~/.claude/projects/-Users-daz-Library-CloudStorage-ProtonDrive-daz-codes-pm-me-folder-volt/memory/project_parallel_rung_ladder.md` (no separate spec doc — the memory entry is the spec).

**Reference skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:verification-before-completion, @superpowers-ruby:ruby-commit-message, @superpowers-ruby:37signals-style, @superpowers-ruby:sandi-metz-rules.

---

## Key decisions (locked before implementation)

1. **The existing exercise-level `metric` field stays as legacy shorthand.** It continues to mean "same numeric sequence as the section, different unit label only." The new `varies/start/end/step/peak` overrides take precedence when present. No migration of existing examples or persisted workouts.
2. **Parity rule: when per-exercise rung counts mismatch, strip ALL overrides and fall back to section defaults.** Log a warning. The section becomes a single-scale ladder. This is the simplest rule to reason about and matches the memory's "no drop mismatched exercise" constraint by enforcing parity at the override layer rather than the exercise layer.
3. **Scope: LLM-generated path only.** The manual builder form (`app/views/workouts/_builder_form.html.erb`, `structure_builder.rb`) does NOT learn the new overrides in this PR. That's a separate follow-up — users editing workouts by hand won't see per-exercise scale fields. The render path *does* show parallel-rung ladders correctly because that's required to display LLM-generated workouts.
4. **Backward compatibility: total.** A ladder with no per-exercise overrides renders, validates, and persists exactly as it does today. No data migration. No example rewriting.

---

## File map

**New:**
- `app/models/workout/ladder_sequence.rb` — module with pure functions for resolving per-exercise rung sequences. Used by the validator, the view templates (via a Rails helper), and `Workout::Exportable`.
- `app/helpers/ladder_sequence_helper.rb` — thin Rails helper that re-exposes `Workout::LadderSequence` to ERB templates.
- `test/models/workout/ladder_sequence_test.rb` — unit tests for the helper module.

**Modified — generator path:**
- `app/services/workout_llm_generator.rb` — tool schema: add optional `varies/start/end/step/peak` to the exercise object.
- `app/services/workout_validator.rb` — add `fix_ladder_rung_count_parity`; teach `fix_ladder_step`, `fix_deka_mile_compromised_run_cap`, and `fix_treadmill_ladder` to read effective rungs via the helper.
- `app/llm_context/shared/global_rules.md` — rewrite the ladder/mountain bullets to document per-exercise overrides.

**Modified — render path:**
- `app/views/shared/_workout_section.html.erb` — suppress the shared header sequence when any exercise overrides; delegate to the helper.
- `app/views/shared/_exercise_row.html.erb` — render a per-exercise rung row when overrides are present.
- `app/models/workout/exportable.rb` — `format_label_and_description` and `export_sections` use the helper; share-card label switches to "Mixed Ladder" / "Mixed Mountain" when overrides are present.

**Modified — examples:**
- `lib/llm_context/activities/deka_mile.rb` — add one parallel-rung exemplar (Compromised Run + Box Jump).
- `lib/llm_context/activities/hyrox.rb` — add one parallel-rung exemplar (Run + Wall Balls or similar).

**Modified — tests:**
- `test/services/workout_validator_test.rb` — new tests for each updated fixer.
- `test/services/workout_llm_generator_test.rb` (or wherever the tool-schema sanity tests live) — schema accepts per-exercise overrides.
- `test/llm_context/contract_integrity_test.rb` — assert examples still parse.

---

## Out of scope (do NOT add to this PR)

- Manual builder form / `structure_builder.rb` — users editing by hand still see only the section-level fields.
- Migration of persisted workouts — they keep working as-is via section defaults.
- Side bug "Deka Mile cap also needs to read ladder rungs" — handled here because it's listed in the memory and falls naturally out of the helper rewrite, but is fixed once and not re-engineered.
- Switchback parallel-rung — switchback already has a 2-exercise + cardio/floor unit asymmetry pattern; PR 2 does NOT extend overrides to switchback.
- Brand-new helper documentation in shared/hybrid_style.md — `global_rules.md` is the canonical place for ladder rules; hybrid_style.md does not duplicate.

---

## Task 1: Add the rung-resolver module (foundation, no behavior change yet)

**Files:**
- Create: `app/models/workout/ladder_sequence.rb`
- Create: `test/models/workout/ladder_sequence_test.rb`

This task adds the helper but doesn't wire it into anything yet. That keeps the diff small and the helper unit-testable in isolation.

- [ ] **Step 1: Write the failing tests**

Create `test/models/workout/ladder_sequence_test.rb`:

```ruby
require "test_helper"

class Workout::LadderSequenceTest < ActiveSupport::TestCase
  # -- section-default ladders (no overrides) --

  test "ladder uses section start/end/step when exercise has no override" do
    section  = { "format" => "ladder", "varies" => "reps",
                 "start" => 10, "end" => 1, "step" => 1, "exercises" => [{ "name" => "KB Swing" }] }
    exercise = section["exercises"].first
    assert_equal [10, 9, 8, 7, 6, 5, 4, 3, 2, 1], Workout::LadderSequence.values_for(section, exercise)
    assert_equal "reps", Workout::LadderSequence.varies_for(section, exercise)
  end

  test "mountain uses section start/peak/end/step" do
    section  = { "format" => "mountain", "varies" => "reps",
                 "start" => 1, "peak" => 5, "end" => 1, "step" => 1,
                 "exercises" => [{ "name" => "Bear" }] }
    exercise = section["exercises"].first
    assert_equal [1, 2, 3, 4, 5, 4, 3, 2, 1], Workout::LadderSequence.values_for(section, exercise)
  end

  test "ascending ladder (start < end)" do
    section  = { "format" => "ladder", "varies" => "reps",
                 "start" => 2, "end" => 10, "step" => 2, "exercises" => [{ "name" => "Burpees" }] }
    assert_equal [2, 4, 6, 8, 10], Workout::LadderSequence.values_for(section, section["exercises"].first)
  end

  # -- per-exercise full overrides --

  test "exercise override of varies/start/end/step takes precedence" do
    section = { "format" => "ladder", "varies" => "reps",
                "start" => 50, "end" => 10, "step" => 10,
                "exercises" => [
                  { "name" => "Box Jump" },
                  { "name" => "Run", "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
                ] }
    box, run = section["exercises"]

    assert_equal [50, 40, 30, 20, 10], Workout::LadderSequence.values_for(section, box)
    assert_equal "reps", Workout::LadderSequence.varies_for(section, box)

    assert_equal [500, 400, 300, 200, 100], Workout::LadderSequence.values_for(section, run)
    assert_equal "distance_m", Workout::LadderSequence.varies_for(section, run)
  end

  test "partial override (varies only) inherits section start/end/step" do
    section  = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 2, "step" => 2,
                 "exercises" => [{ "name" => "Row", "varies" => "calories" }] }
    exercise = section["exercises"].first
    assert_equal [10, 8, 6, 4, 2], Workout::LadderSequence.values_for(section, exercise)
    assert_equal "calories", Workout::LadderSequence.varies_for(section, exercise)
  end

  test "legacy 'metric' field changes unit label only, not values" do
    section  = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
                 "exercises" => [{ "name" => "Row", "metric" => "calories" }] }
    exercise = section["exercises"].first
    assert_equal (1..10).to_a.reverse, Workout::LadderSequence.values_for(section, exercise)
    assert_equal "calories", Workout::LadderSequence.varies_for(section, exercise)
  end

  test "full override beats legacy metric when both are present" do
    section = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
                "exercises" => [{ "name" => "Run", "metric" => "distance_m",
                                  "varies" => "distance_m", "start" => 400, "end" => 100, "step" => 100 }] }
    exercise = section["exercises"].first
    assert_equal [400, 300, 200, 100], Workout::LadderSequence.values_for(section, exercise)
  end

  # -- unit labels --

  test "unit_label_for maps each varies to its short label" do
    section = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
                "exercises" => [{ "name" => "X" }] }
    %w[reps cal m kg].zip(%w[reps calories distance_m kg]).each do |label, varies|
      section["varies"] = varies
      assert_equal label, Workout::LadderSequence.unit_label_for(section, section["exercises"].first)
    end
  end

  # -- per-exercise overrides? helper --

  test "has_per_exercise_overrides? false for plain section ladder" do
    section = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
                "exercises" => [{ "name" => "A" }, { "name" => "B" }] }
    refute Workout::LadderSequence.has_per_exercise_overrides?(section)
  end

  test "has_per_exercise_overrides? false for legacy metric-only override" do
    section = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
                "exercises" => [{ "name" => "Row", "metric" => "calories" }] }
    refute Workout::LadderSequence.has_per_exercise_overrides?(section)
  end

  test "has_per_exercise_overrides? true when any exercise sets varies/start/end/step" do
    section = { "format" => "ladder", "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
                "exercises" => [
                  { "name" => "Box Jump" },
                  { "name" => "Run", "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
                ] }
    assert Workout::LadderSequence.has_per_exercise_overrides?(section)
  end
end
```

- [ ] **Step 2: Run the tests and confirm they fail**

```bash
bin/rails test test/models/workout/ladder_sequence_test.rb
```

Expected: `NameError: uninitialized constant Workout::LadderSequence` or similar.

- [ ] **Step 3: Implement the module**

Create `app/models/workout/ladder_sequence.rb`:

```ruby
module Workout::LadderSequence
  module_function

  UNIT_LABELS = { "reps" => "reps", "calories" => "cal", "distance_m" => "m", "kg" => "kg" }.freeze
  OVERRIDE_KEYS = %w[start end step peak].freeze

  # Returns the numeric rung sequence for this exercise in this section.
  # Falls through to the section defaults when the exercise has no overrides.
  def values_for(section, exercise)
    sv   = (exercise["start"] || section["start"]).to_f
    ev   = (exercise["end"]   || section["end"]).to_f
    step = ((exercise["step"] || section["step"]).to_f).nonzero?&.abs || 1.0

    case section["format"].to_s
    when "mountain"
      pk = (exercise["peak"] || section["peak"]).to_f
      ev = sv if ev.zero?
      up   = sv.step(pk,    step).to_a
      down = (pk - step).step(ev, -step).to_a
      coerce(up + down)
    else # ladder (and anything else falls through to ladder shape)
      seq = sv <= ev ? sv.step(ev, step).to_a : sv.step(ev, -step).to_a
      coerce(seq)
    end
  end

  # Returns the effective `varies` for this exercise — the override, then the
  # legacy `metric` field, then the section default. Used to choose the unit.
  def varies_for(section, exercise)
    exercise["varies"].presence || exercise["metric"].presence || section["varies"].to_s
  end

  # Short label for this exercise's effective metric: "reps", "cal", "m", "kg".
  def unit_label_for(section, exercise)
    UNIT_LABELS[varies_for(section, exercise)] || varies_for(section, exercise)
  end

  # True when at least one exercise carries a real scale override (varies/start/
  # end/step/peak), meaning the renderer must show per-exercise sequences.
  # The legacy `metric`-only field does NOT count — it just relabels the unit.
  def has_per_exercise_overrides?(section)
    Array(section["exercises"]).any? do |ex|
      ex["varies"].present? || OVERRIDE_KEYS.any? { |k| ex[k].present? }
    end
  end

  private_class_method def self.coerce(arr)
    arr.map { |v| v == v.to_i ? v.to_i : v.round(2) }
  end
end
```

- [ ] **Step 4: Run the tests and confirm they pass**

```bash
bin/rails test test/models/workout/ladder_sequence_test.rb
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/models/workout/ladder_sequence.rb test/models/workout/ladder_sequence_test.rb
git commit -m "$(cat <<'EOF'
feat(workout): add Workout::LadderSequence helper for per-exercise rungs

Pure-function module that resolves the per-exercise rung sequence in a
ladder/mountain section, falling through to section defaults when the
exercise has no override. Used as the single source of truth by the
validator, view templates, and share-card exporter in subsequent
commits.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add per-exercise override fields to the LLM tool schema

**Files:**
- Modify: `app/services/workout_llm_generator.rb:54-69` (the `exercises.items.properties` block)
- Test: a new test in `test/services/workout_llm_generator_test.rb` (or wherever the schema is asserted — check first; if no test file exists for the schema, just verify by hand via a manual generator call in the next task's tests)

The tool schema currently lets exercises carry `name`, `reps`, `calories`, `distance_m`, `duration_s`, `weight_kg`, `notes`. We add optional `varies`, `start`, `end`, `step`, `peak`.

- [ ] **Step 1: Look for existing schema tests**

```bash
grep -rn "TOOL_DEFINITION\|input_schema" /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/test --include="*.rb"
```

If a test file already asserts the schema shape, add a new test there. If not, skip Step 2 — the schema change is exercised by Task 4's validator tests (which construct payloads matching the new shape) and the contract_integrity_test pass in Task 11.

- [ ] **Step 2 (if applicable): Write a schema-shape test**

Append to the discovered test file:

```ruby
test "tool schema allows exercise-level varies/start/end/step/peak overrides" do
  exercise_props = WorkoutLLMGenerator::TOOL_DEFINITION
    .dig(:input_schema, :properties, :structure, :properties, :sections, :items, :properties, :exercises, :items, :properties)
  %w[varies start end step peak].each do |key|
    assert exercise_props.key?(key.to_sym), "expected exercise schema to declare #{key}"
  end
end
```

- [ ] **Step 3 (if applicable): Run and confirm it fails**

```bash
bin/rails test <discovered-file> -n /allows exercise-level/
```

Expected: missing key.

- [ ] **Step 4: Update the tool schema**

In `app/services/workout_llm_generator.rb`, find the exercises items.properties hash (currently ends with `notes:` around line 66) and add five new entries before the closing brace:

```ruby
varies:     { type: "string", enum: %w[reps calories kg distance_m], description: "Optional per-exercise override of the section's varies. Use ONLY in a parallel-rung ladder/mountain where this exercise scales on a different metric than the section default — e.g. a section with varies:reps carrying a Run that scales by distance_m. The rung COUNT must match across all exercises in the section (e.g. all 5 rungs). If you set varies here you usually also set start/end/step here. Leave unset whenever every exercise uses the section's metric." },
start:      { type: "number", description: "Optional per-exercise override of the section's start. See `varies` above. Required if you set `varies` and the per-exercise sequence differs from the section's." },
end:        { type: "number", description: "Optional per-exercise override of the section's end. See `varies` above." },
step:       { type: "number", description: "Optional per-exercise override of the section's step. Must match the metric's step rules: reps 1–5, calories 5–10, distance_m ≥ 10, kg 5–10." },
peak:       { type: "number", description: "Optional per-exercise override of the mountain section's peak. Only set for mountain format." }
```

- [ ] **Step 5: Run the schema test (if you wrote one)**

```bash
bin/rails test <discovered-file> -n /allows exercise-level/
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add app/services/workout_llm_generator.rb [test file if changed]
git commit -m "$(cat <<'EOF'
feat(workout): allow per-exercise scale overrides in LLM tool schema

Exercise objects inside a ladder/mountain may now carry their own
varies/start/end/step/peak, enabling parallel-rung ladders such as a
Run (500-100m) paired with Box Jumps (50-10 reps). Section-level keys
remain the default; overrides are optional and backward-compatible.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Validator — enforce rung-count parity

**Files:**
- Modify: `app/services/workout_validator.rb` (add `fix_ladder_rung_count_parity` and wire it into `validate_and_fix`)
- Test: `test/services/workout_validator_test.rb`

When the LLM emits per-exercise overrides whose rung counts disagree, strip ALL overrides on that section and fall back to section defaults. Log a warning.

- [ ] **Step 1: Write the failing tests**

Append to `test/services/workout_validator_test.rb` (in the file, before the final `private` / helper block):

```ruby
# -- fix_ladder_rung_count_parity --

test "fix_ladder_rung_count_parity leaves matching rung counts alone" do
  data = build_workout_with_sections([
    { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
      "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
      "exercises" => [
        { "name" => "Box Jump" },
        { "name" => "Run", "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
      ] }
  ])
  result  = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
  section = result.dig("structure", "sections").first
  run     = section["exercises"].find { |e| e["name"] == "Run" }
  assert_equal "distance_m", run["varies"]
  assert_equal 500, run["start"]
end

test "fix_ladder_rung_count_parity strips all overrides on mismatch" do
  # Box Jump: 50→10 step 10 = 5 rungs. Run: 800→100 step 100 = 8 rungs. Mismatch.
  data = build_workout_with_sections([
    { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
      "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
      "exercises" => [
        { "name" => "Box Jump" },
        { "name" => "Run", "varies" => "distance_m", "start" => 800, "end" => 100, "step" => 100 }
      ] }
  ])
  validator = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "")
  result    = validator.validate_and_fix
  run       = result.dig("structure", "sections").first["exercises"].find { |e| e["name"] == "Run" }
  refute run.key?("varies"),    "override varies should be stripped on mismatch"
  refute run.key?("start"),     "override start should be stripped on mismatch"
  refute run.key?("end"),       "override end should be stripped on mismatch"
  refute run.key?("step"),      "override step should be stripped on mismatch"
  assert validator.warnings.any? { |w| w.match?(/rung count/i) }, "expected a parity warning"
end

test "fix_ladder_rung_count_parity also strips mountain peak override" do
  # Two mountain exercises with mismatched peaks → mismatched rung counts.
  data = build_workout_with_sections([
    { "name" => "Twin Peaks", "category" => "main", "format" => "mountain",
      "varies" => "reps", "start" => 5, "peak" => 15, "end" => 5, "step" => 5,
      "exercises" => [
        { "name" => "Wall Ball" },
        { "name" => "KB Swing", "varies" => "reps", "start" => 5, "peak" => 25, "end" => 5, "step" => 5 }
      ] }
  ])
  result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
  kb = result.dig("structure", "sections").first["exercises"].find { |e| e["name"] == "KB Swing" }
  refute kb.key?("peak"), "override peak should be stripped on mismatch"
end
```

- [ ] **Step 2: Run and confirm failure**

```bash
bin/rails test test/services/workout_validator_test.rb -n /rung_count_parity/
```

Expected: failures — the new method doesn't exist yet.

- [ ] **Step 3: Implement the parity fixer**

In `app/services/workout_validator.rb`:

(a) Add to the top-level requires/uses by ensuring `Workout::LadderSequence` is autoloaded — Rails will autoload `app/models/workout/ladder_sequence.rb`; no explicit `require` needed in production. (For test runs in isolation, `bin/rails test` autoloads it too.)

(b) Add the method (alongside the other `fix_ladder_*` methods — natural home is just above `fix_ladder_step` at line 348):

```ruby
# Per-exercise rung-count parity: when overrides are present, every exercise
# in a ladder/mountain must produce the same number of rungs as the section
# default. Mismatched overrides are stripped (the section falls back to its
# defaults) — the alternative ("drop the offending exercise") loses real
# programming intent and was explicitly ruled out in the design.
def fix_ladder_rung_count_parity(section, idx)
  return unless Workout::LadderSequence.has_per_exercise_overrides?(section)

  exercises  = Array(section["exercises"])
  rung_counts = exercises.map { |ex| Workout::LadderSequence.values_for(section, ex).size }
  return if rung_counts.uniq.size == 1

  exercises.each do |ex|
    %w[varies start end step peak].each { |k| ex.delete(k) }
  end
  @warnings << "Ladder '#{section["name"]}': per-exercise rung counts mismatched (#{rung_counts.join(",")}) — stripped overrides, falling back to section defaults"
end
```

(c) Wire it into the `validate_and_fix` switch at line ~67. Add to the `when "ladder", "mountain"` arm, BEFORE `fix_ladder_step`:

```ruby
when "ladder", "mountain"
  fix_ladder_rung_count_parity(section, idx)
  fix_ladder_step(section, idx)
  fix_mountain_end(section) if section["format"] == "mountain"
```

- [ ] **Step 4: Run and confirm pass**

```bash
bin/rails test test/services/workout_validator_test.rb -n /rung_count_parity/
```

Expected: all three new tests pass.

- [ ] **Step 5: Re-run the full validator suite to confirm no regressions**

```bash
bin/rails test test/services/workout_validator_test.rb
```

Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/services/workout_validator.rb test/services/workout_validator_test.rb
git commit -m "$(cat <<'EOF'
feat(validator): enforce per-exercise rung-count parity for ladders

When per-exercise overrides yield mismatched rung counts, strip all
overrides and warn — the section falls back to its defaults. Aligns
with the design's rejection of a "drop mismatched exercise" safety net.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Validator — `fix_ladder_step` validates each exercise's step

**Files:**
- Modify: `app/services/workout_validator.rb` (the `fix_ladder_step` method around line 348)
- Test: `test/services/workout_validator_test.rb`

- [ ] **Step 1: Write the failing tests**

Append to `test/services/workout_validator_test.rb`:

```ruby
test "fix_ladder_step corrects an out-of-range step on a per-exercise override" do
  # Section step is fine. Run override has step 5 which is below distance_m minimum of 10.
  data = build_workout_with_sections([
    { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
      "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
      "exercises" => [
        { "name" => "Box Jump" },
        { "name" => "Run", "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 5 }
      ] }
  ])
  result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
  run = result.dig("structure", "sections").first["exercises"].find { |e| e["name"] == "Run" }
  assert_equal 10, run["step"], "distance_m step 5 should be raised to minimum 10"
end

test "fix_ladder_step leaves valid per-exercise steps alone" do
  data = build_workout_with_sections([
    { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
      "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
      "exercises" => [
        { "name" => "Box Jump" },
        { "name" => "Run", "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
      ] }
  ])
  result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
  run = result.dig("structure", "sections").first["exercises"].find { |e| e["name"] == "Run" }
  assert_equal 100, run["step"]
end
```

- [ ] **Step 2: Run and confirm failure**

```bash
bin/rails test test/services/workout_validator_test.rb -n /per-exercise_override/
```

Expected: the first test fails — the existing method only checks section-level step.

- [ ] **Step 3: Update `fix_ladder_step`**

Replace the existing `fix_ladder_step` body (around line 348) with:

```ruby
def fix_ladder_step(section, idx)
  fix_ladder_step_for(section, section["name"], section)
  Array(section["exercises"]).each do |ex|
    next unless ex["step"].present? && ex["varies"].present?
    fix_ladder_step_for(section, "#{section["name"]} / #{ex["name"]}", ex)
  end
end

# Snap `target`'s step into bounds for its varies (target is a section or exercise hash).
def fix_ladder_step_for(section, label, target)
  varies = target["varies"]
  step   = target["step"].to_f
  return unless varies && step > 0

  min = LADDER_STEP_MIN[varies]
  max = LADDER_STEP_MAX[varies]
  return unless min

  corrected = if step < min
    min
  elsif max && step > max
    max
  else
    return
  end

  target["step"] = corrected
  @fixes << "#{section["format"].capitalize} '#{label}': step #{step} invalid for #{varies} — corrected to #{corrected}"
end
```

- [ ] **Step 4: Run the targeted tests and the full validator suite**

```bash
bin/rails test test/services/workout_validator_test.rb -n /per-exercise_override/
bin/rails test test/services/workout_validator_test.rb
```

Expected: both green.

- [ ] **Step 5: Commit**

```bash
git add app/services/workout_validator.rb test/services/workout_validator_test.rb
git commit -m "$(cat <<'EOF'
feat(validator): clamp per-exercise ladder steps to metric bounds

fix_ladder_step now walks per-exercise overrides too, so a parallel-rung
ladder with a Run override whose step underflows distance_m bounds gets
snapped just like a section-level violation would.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Validator — Deka Mile cap reads ladder rungs

**Files:**
- Modify: `app/services/workout_validator.rb` (the `fix_deka_mile_compromised_run_cap` method around line 569)
- Test: `test/services/workout_validator_test.rb`

This is the side bug from the memory: today the cap fixer only reads `ex["distance_m"]`, which is missing on ladder exercises (stripped by `fix_ladder_switchback_strip_metrics`). The fix: also walk the effective rungs.

- [ ] **Step 1: Write the failing tests**

Append to `test/services/workout_validator_test.rb`:

```ruby
test "fix_deka_mile_compromised_run_cap clamps section-level ladder rungs over 300m" do
  data = build_workout_with_sections([
    { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5, "category" => "warm_up",
      "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
    { "name" => "Run Stairs", "category" => "main", "format" => "ladder",
      "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100,
      "exercises" => [
        { "name" => "Compromised Run", "equipment" => "treadmill" }
      ] }
  ])
  result  = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "deka-mile").validate_and_fix
  section = result.dig("structure", "sections")[1]
  assert section["start"].to_i <= 300, "section start should be clamped to 300 or below"
  assert_equal 100, section["end"]
end

test "fix_deka_mile_compromised_run_cap clamps per-exercise override rungs over 300m" do
  # Section is reps-based but Compromised Run override is distance_m 500→100.
  data = build_workout_with_sections([
    { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5, "category" => "warm_up",
      "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
    { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
      "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
      "exercises" => [
        { "name" => "Box Jump" },
        { "name" => "Compromised Run", "equipment" => "treadmill",
          "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
      ] }
  ])
  result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "deka-mile").validate_and_fix
  run    = result.dig("structure", "sections")[1]["exercises"].find { |e| e["name"] == "Compromised Run" }
  assert run["start"].to_i <= 300, "override start should be clamped to 300 or below"
end

test "fix_deka_mile_compromised_run_cap leaves a 300m ladder alone" do
  data = build_workout_with_sections([
    { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5, "category" => "warm_up",
      "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
    { "name" => "Run Stairs", "category" => "main", "format" => "ladder",
      "varies" => "distance_m", "start" => 300, "end" => 100, "step" => 100,
      "exercises" => [
        { "name" => "Compromised Run", "equipment" => "treadmill" }
      ] }
  ])
  result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "deka-mile").validate_and_fix
  section = result.dig("structure", "sections")[1]
  assert_equal 300, section["start"]
end
```

- [ ] **Step 2: Run and confirm failure**

```bash
bin/rails test test/services/workout_validator_test.rb -n /compromised_run_cap/
```

Expected: the two new ladder-rung tests fail; the existing rounds-based tests still pass.

- [ ] **Step 3: Update `fix_deka_mile_compromised_run_cap`**

Replace the existing method body (around line 569) with:

```ruby
def fix_deka_mile_compromised_run_cap(sections)
  cap = 300
  sections.each do |section|
    is_ladder = %w[ladder mountain].include?(section["format"])

    Array(section["exercises"]).each do |ex|
      next unless ex["name"].to_s.match?(/\Acompromised run\z/i)

      if is_ladder
        clamp_compromised_run_ladder(section, ex, cap)
      else
        dist = ex["distance_m"].to_i
        next if dist <= cap || dist.zero?
        ex["distance_m"] = cap
        @fixes << "Deka Mile '#{section["name"]}' #{ex["name"]}: #{dist}m → #{cap}m (compromised run cap)"
      end
    end
  end
end

# When the compromised run is inside a ladder, clamp whichever scale owns it
# (section default OR per-exercise override) so the max rung ≤ cap.
def clamp_compromised_run_ladder(section, exercise, cap)
  target =
    if exercise["start"].present? || exercise["end"].present? || exercise["peak"].present?
      exercise
    elsif Workout::LadderSequence.varies_for(section, exercise) == "distance_m"
      section
    else
      return
    end

  values = Workout::LadderSequence.values_for(section, exercise)
  max_value = values.map(&:to_i).max
  return if max_value <= cap

  scale = cap.to_f / max_value
  %w[start end peak].each do |key|
    next unless target[key]
    snapped = ((target[key].to_f * scale) / target["step"].to_f).round * target["step"].to_f
    target[key] = snapped.to_i.clamp(target["step"].to_i, cap)
  end

  label = target.equal?(section) ? section["name"] : "#{section["name"]} / #{exercise["name"]}"
  @fixes << "Deka Mile '#{label}' compromised run ladder: max rung #{max_value}m → ≤#{cap}m (compromised run cap)"
end
```

- [ ] **Step 4: Run the targeted and full suites**

```bash
bin/rails test test/services/workout_validator_test.rb -n /compromised_run_cap/
bin/rails test test/services/workout_validator_test.rb
```

Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/services/workout_validator.rb test/services/workout_validator_test.rb
git commit -m "$(cat <<'EOF'
fix(validator): Deka Mile compromised-run cap honours ladder rungs

The cap used to read only ex["distance_m"], so a section-level distance
ladder of 500→100m slipped past untouched. Now it walks the effective
rungs (via Workout::LadderSequence) and clamps the owning scale —
section or per-exercise override — so the max rung is ≤ 300m.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Validator — `fix_treadmill_ladder` respects per-exercise overrides

**Files:**
- Modify: `app/services/workout_validator.rb` (the `fix_treadmill_ladder` method around line 1015)
- Test: `test/services/workout_validator_test.rb`

The current method kicks in for any ladder whose section `varies` isn't `distance_m` and whose name/exercises match a treadmill pattern. In a parallel-rung ladder where the Run exercise has its own `varies: distance_m` override, the section's `varies` will still be (correctly) `reps` — so today's method would mangle it.

- [ ] **Step 1: Write the failing test**

Append:

```ruby
test "fix_treadmill_ladder leaves a parallel-rung ladder with a Run override alone" do
  data = build_workout_with_sections([
    { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
      "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
      "exercises" => [
        { "name" => "Box Jump" },
        { "name" => "Run", "equipment" => "treadmill",
          "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
      ] }
  ])
  result  = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "").validate_and_fix
  section = result.dig("structure", "sections").first
  assert_equal "reps", section["varies"], "section varies must not flip to distance_m"
  run = section["exercises"].find { |e| e["name"] == "Run" }
  assert_equal "distance_m", run["varies"]
  assert_equal 500, run["start"]
  assert_equal 2, section["exercises"].size, "Box Jump must not be deleted"
end
```

- [ ] **Step 2: Run and confirm failure**

```bash
bin/rails test test/services/workout_validator_test.rb -n /parallel-rung_ladder_with_a_Run_override/
```

Expected: failure — today's treadmill-ladder fixer would rewrite the section.

- [ ] **Step 3: Update `fix_treadmill_ladder`**

In `app/services/workout_validator.rb` near the top of `fix_treadmill_ladder` (line 1016), after the `next unless %w[ladder mountain].include?(section["format"])` and BEFORE the `next if section["varies"].to_s == "distance_m"`, add:

```ruby
# Parallel-rung ladders: if the treadmill exercise already carries its own
# distance_m override, the ladder is correct as-is. Leave the whole section
# alone — the existing rewrite would destroy the parallel-rung shape.
if Array(section["exercises"]).any? { |ex|
  ex["name"].to_s.match?(TREADMILL_PATTERN) && ex["varies"].to_s == "distance_m"
}
  next
end
```

- [ ] **Step 4: Run targeted + full suites**

```bash
bin/rails test test/services/workout_validator_test.rb -n /parallel-rung_ladder/
bin/rails test test/services/workout_validator_test.rb
```

Expected: green, no regressions in the existing `fix_treadmill_ladder converts speed-shaped ladder` family.

- [ ] **Step 5: Commit**

```bash
git add app/services/workout_validator.rb test/services/workout_validator_test.rb
git commit -m "$(cat <<'EOF'
fix(validator): skip treadmill-ladder rewrite when run has distance override

A parallel-rung ladder with a Run override that already specifies
varies:distance_m + start/end/step is intentional, not a speed-ladder
mistake — leave it alone instead of flipping the section's varies and
collapsing the second exercise.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: View helper exposing the rung resolver

**Files:**
- Create: `app/helpers/ladder_sequence_helper.rb`

Trivial wrapper so ERB can call the module's methods without `Workout::LadderSequence::` everywhere.

- [ ] **Step 1: Create the helper**

```ruby
module LadderSequenceHelper
  def ladder_values_for(section, exercise)
    Workout::LadderSequence.values_for(section, exercise)
  end

  def ladder_unit_label_for(section, exercise)
    Workout::LadderSequence.unit_label_for(section, exercise)
  end

  def ladder_has_per_exercise_overrides?(section)
    Workout::LadderSequence.has_per_exercise_overrides?(section)
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/helpers/ladder_sequence_helper.rb
git commit -m "$(cat <<'EOF'
feat(views): add LadderSequenceHelper wrapper for ERB callers

Exposes Workout::LadderSequence to view templates without forcing them
to spell out the module path.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

(No test for this task — it's a one-line passthrough. The view templates in Task 8 exercise it indirectly.)

---

## Task 8: Render per-exercise rungs in the workout view

**Files:**
- Modify: `app/views/shared/_workout_section.html.erb` (the ladder/mountain branch around lines 28-58 and 133-136)
- Modify: `app/views/shared/_exercise_row.html.erb` (the ladder/mountain branch around lines 80-94)
- Test: a new system or rendering test — first check what shape exists in `test/`.

The header sequence (`ladder_seq_str`) should be suppressed when the section has per-exercise overrides. Each exercise row should then render its own rung sequence + unit (matching the visual pattern switchback already uses).

- [ ] **Step 1: Find the right test home**

```bash
ls /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/test/views 2>/dev/null
ls /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/test/system 2>/dev/null
grep -rln "workout_section\|_workout_section" /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/test 2>/dev/null
```

If there's a view/integration test for `_workout_section.html.erb`, add to it. Otherwise create `test/views/shared/workout_section_test.rb` using `ActionView::TestCase`.

- [ ] **Step 2: Write the failing tests**

Pseudocode (adapt to whichever test base class your repo uses):

```ruby
test "ladder with per-exercise override renders each exercise's own rung sequence" do
  section = {
    "name" => "Parallel Descender", "format" => "ladder",
    "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
    "exercises" => [
      { "name" => "Box Jump" },
      { "name" => "Run", "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
    ]
  }
  render partial: "shared/workout_section", locals: { section: section }
  # Box Jump row shows reps sequence; Run row shows metres sequence.
  assert_select "span", text: /50.*40.*30.*20.*10.*reps/
  assert_select "span", text: /500.*400.*300.*200.*100.*m/
end

test "ladder without overrides keeps the shared header sequence (regression check)" do
  section = {
    "name" => "Reps Ladder", "format" => "ladder",
    "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
    "exercises" => [{ "name" => "Burpee" }, { "name" => "Sit-up" }]
  }
  render partial: "shared/workout_section", locals: { section: section }
  assert_select "p", text: /10.*9.*8.*reps/
end
```

- [ ] **Step 3: Run and confirm failure**

```bash
bin/rails test <test file>
```

Expected: failure.

- [ ] **Step 4: Update `_workout_section.html.erb`**

In the ladder/mountain branch (currently around line 32), replace the inline math with helper calls and a per-exercise-override guard. Find the existing block:

```erb
<% if %w[ladder mountain].include?(sec_format)
     step = [section["step"].to_f, 1.0].max
     ladder_metric_unit = { "reps" => "reps", ... }
     ladder_effective_metrics = Array(section["exercises"]).map { |e| e["metric"].presence || section["varies"].to_s }
     ladder_metrics_mixed = ladder_effective_metrics.uniq.size > 1
     ...
     ladder_seq_str = "#{seq} #{varies_lbl}".strip
```

Replace with:

```erb
<% if %w[ladder mountain].include?(sec_format)
     if ladder_has_per_exercise_overrides?(section)
       # Per-exercise sequences render under each exercise — no shared header.
       ladder_seq_str = nil
     else
       # Section-default sequence (existing behaviour, kept verbatim).
       step = [section["step"].to_f, 1.0].max
       ladder_metric_unit = { "reps" => "reps", "calories" => "cal", "kg" => "kg", "distance_m" => "m" }
       ladder_effective_metrics = Array(section["exercises"]).map { |e| e["metric"].presence || section["varies"].to_s }
       ladder_metrics_mixed = ladder_effective_metrics.uniq.size > 1
       varies_lbl = ladder_metrics_mixed ? "" : ladder_metric_unit.fetch(section["varies"].to_s, section["varies"].to_s)
       if sec_format == "ladder"
         sv = section["start"].to_f; ev = section["end"].to_f
         vals = []
         if sv <= ev
           v = sv; while v <= ev + 0.001; vals << v; v += step; end
         else
           v = sv; while v >= ev - 0.001; vals << v; v -= step; end
         end
       else
         sv = section["start"].to_f; pk = section["peak"].to_f; ev = section["end"].to_f.nonzero? || sv
         up = []; v = sv; while v <= pk + 0.001; up << v; v += step; end
         dn = []; v = pk - step; while v >= ev - 0.001; dn << v; v -= step; end
         vals = up + dn
       end
       vals = vals.map { |v| v == v.to_i ? v.to_i : v }
       seq = vals.size <= 10 ? vals.join(" · ") : "#{vals.first(3).join(" · ")} · … · #{vals.last}"
       ladder_seq_str = "#{seq} #{varies_lbl}".strip
     end
```

The `fmt_label, fmt_detail` `when "ladder", "mountain"` arm (around line 133) is unchanged — when `ladder_seq_str` is `nil`, the description simply omits the sequence string and might only show "45s rest between rungs".

Even cleaner: that arm's `parts = [ ladder_seq_str ]` already filters nil via `parts.compact.join(...)` — so no change needed.

- [ ] **Step 5: Update `_exercise_row.html.erb`**

The current ladder branch (lines 80-94) shows only a unit chip when metrics are mixed via the legacy `metric` field. Replace its body to also show the rung sequence when section-level overrides are present:

Find:

```erb
<% elsif %w[ladder mountain].include?(section["format"].to_s) %>
  <% all_metrics = Array(section["exercises"]).map { |e| e["metric"].presence || section["varies"].to_s }
     mixed = all_metrics.uniq.size > 1
     this_metric = exercise["metric"].presence || section["varies"].to_s
     unit_lbl = ladder_unit_lbl_map[this_metric] %>
  <% if (mixed && unit_lbl) || exercise["notes"].present? %>
    <div class="flex items-center gap-1.5 mt-1 flex-wrap">
      <% if mixed && unit_lbl %>
        <span class="text-xs font-bold text-sky-200"><%= unit_lbl %></span>
      <% end %>
      <% if exercise["notes"].present? %>
        <span class="text-gray-400 text-xs italic"><%= exercise["notes"] %></span>
      <% end %>
    </div>
  <% end %>
```

Replace with:

```erb
<% elsif %w[ladder mountain].include?(section["format"].to_s) %>
  <% has_overrides = ladder_has_per_exercise_overrides?(section)
     all_metrics = Array(section["exercises"]).map { |e| e["metric"].presence || section["varies"].to_s }
     mixed = all_metrics.uniq.size > 1
     this_metric = exercise["metric"].presence || section["varies"].to_s
     unit_lbl = ladder_unit_lbl_map[this_metric] %>
  <% if has_overrides %>
    <% vals = ladder_values_for(section, exercise)
       lbl  = ladder_unit_label_for(section, exercise)
       seq  = vals.size <= 10 ? vals.join(" · ") : "#{vals.first(3).join(" · ")} · … · #{vals.last}" %>
    <div class="flex items-center gap-1.5 mt-1 flex-wrap">
      <span class="text-xs font-bold text-sky-200"><%= seq %> <%= lbl %></span>
      <% if exercise["notes"].present? %>
        <span class="text-gray-400 text-xs italic"><%= exercise["notes"] %></span>
      <% end %>
    </div>
  <% elsif (mixed && unit_lbl) || exercise["notes"].present? %>
    <div class="flex items-center gap-1.5 mt-1 flex-wrap">
      <% if mixed && unit_lbl %>
        <span class="text-xs font-bold text-sky-200"><%= unit_lbl %></span>
      <% end %>
      <% if exercise["notes"].present? %>
        <span class="text-gray-400 text-xs italic"><%= exercise["notes"] %></span>
      <% end %>
    </div>
  <% end %>
```

- [ ] **Step 6: Run tests and confirm pass**

```bash
bin/rails test <test file>
```

- [ ] **Step 7: Manual visual smoke test**

```bash
bin/rails server
```

Generate a workout for Deka Mile (or load a fixture) that has the example from Task 11 baked in, then navigate to it in the browser. Confirm: the ladder header shows just "Ladder · 45s rest between rungs" (no shared sequence), and each exercise row shows its own sequence + unit ("500 · 400 · 300 · 200 · 100 m" and "50 · 40 · 30 · 20 · 10 reps"). Take a screenshot and attach to the PR description.

State explicitly in the final report if you could not manually verify the UI (CI environment, no server access, etc.) — per the project's "test the UI" rule, an unverified UI claim is not a success.

- [ ] **Step 8: Commit**

```bash
git add app/views/shared/_workout_section.html.erb app/views/shared/_exercise_row.html.erb test/views/shared/workout_section_test.rb
git commit -m "$(cat <<'EOF'
feat(views): render per-exercise rungs when ladder has overrides

When a ladder/mountain section has per-exercise scale overrides the
shared header sequence is suppressed and each exercise row shows its
own sequence with the right unit label. Section-default ladders are
visually unchanged.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Share-card export reflects per-exercise rungs

**Files:**
- Modify: `app/models/workout/exportable.rb` — `format_label_and_description` (around line 244) and the per-exercise loop in `export_sections` (line 132).
- Test: existing `test/models/workout/exportable_test.rb` (or wherever share-card tests live — look first).

- [ ] **Step 1: Find the right test home**

```bash
ls /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/test/models/workout/ 2>/dev/null
grep -rln "export_sections\|Exportable" /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/test 2>/dev/null
```

- [ ] **Step 2: Write failing tests**

```ruby
test "export_sections shows shared sequence in description for section-default ladder" do
  workout = workouts(:fixture_with_section_default_ladder)  # adapt
  section = workout.export_sections.first
  assert_match /reps of each exercise/, section[:description]
end

test "export_sections shows per-exercise sequences when overrides are present" do
  data = { "structure" => { "sections" => [
    { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
      "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
      "exercises" => [
        { "name" => "Box Jump" },
        { "name" => "Run", "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
      ] }
  ] } }
  workout = Workout.new(structure: data["structure"], duration_mins: 30, name: "Test")
  section = workout.export_sections.first
  assert_match /Mixed Ladder/, section[:label]
  refute_match /50.*40.*30/, section[:description].to_s  # no shared sequence in header
  assert section[:exercises].any? { |line| line.match?(/50.*40.*30.*20.*10.*reps/) }
  assert section[:exercises].any? { |line| line.match?(/500.*400.*300.*200.*100.*m/) }
end
```

- [ ] **Step 3: Run and confirm failure**

- [ ] **Step 4: Update `format_label_and_description`**

In `app/models/workout/exportable.rb` around line 244-249, replace:

```ruby
when "ladder"
  seq = ladder_sequence(section["start"], section["end"], section["step"])
  [ "Ladder", "#{seq} reps of each exercise" ]
when "mountain"
  seq = mountain_sequence(section["start"], section["peak"], section["end"], section["step"])
  [ "Mountain", "#{seq} reps of each exercise" ]
```

with:

```ruby
when "ladder", "mountain"
  if Workout::LadderSequence.has_per_exercise_overrides?(section)
    [ fmt == "mountain" ? "Mixed Mountain" : "Mixed Ladder", nil ]
  elsif fmt == "ladder"
    seq = ladder_sequence(section["start"], section["end"], section["step"])
    [ "Ladder", "#{seq} reps of each exercise" ]
  else
    seq = mountain_sequence(section["start"], section["peak"], section["end"], section["step"])
    [ "Mountain", "#{seq} reps of each exercise" ]
  end
```

Note the case-statement merge — both `ladder` and `mountain` now share an arm. Confirm by re-reading the file that no other arm of the case touched these.

- [ ] **Step 5: Update the per-exercise line builder**

In the `export_sections` exercise loop (around line 149), replace:

```ruby
if is_ladder
  ex_name
elsif metric.present?
  ...
```

with:

```ruby
if is_ladder
  if Workout::LadderSequence.has_per_exercise_overrides?(section) && %w[ladder mountain].include?(fmt)
    vals = Workout::LadderSequence.values_for(section, ex)
    unit = Workout::LadderSequence.unit_label_for(section, ex)
    "#{vals.join(" · ")} #{unit} #{ex_name}".strip
  else
    ex_name
  end
elsif metric.present?
  ...
```

- [ ] **Step 6: Run tests, confirm pass**

```bash
bin/rails test <discovered test file>
```

- [ ] **Step 7: Commit**

```bash
git add app/models/workout/exportable.rb test/models/workout/exportable_test.rb
git commit -m "$(cat <<'EOF'
feat(exportable): share card shows per-exercise rungs for mixed ladders

The label becomes 'Mixed Ladder' (or 'Mixed Mountain') with no shared
header sequence; each exercise line carries its own sequence and unit.
Section-default ladders look unchanged.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Update prompt context — `global_rules.md`

**Files:**
- Modify: `app/llm_context/shared/global_rules.md` (the ladder bullets around lines 27-29)

The current bullet at line 27 says "Exercise objects inside a ladder/mountain do NOT carry `reps`, `calories`, `distance_m`, or `weight_kg`." It does not mention the new override fields. Update to teach the parallel-rung pattern.

- [ ] **Step 1: Find the ladder bullets and read them in full**

```bash
sed -n '25,32p' /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/app/llm_context/shared/global_rules.md
```

(Use this purely to read; don't sed-edit it — use the Edit tool.)

- [ ] **Step 2: Insert a new bullet between the existing ladder/mountain rules and the `step` rule (between lines 28 and 29 in the current file).** The new bullet:

```markdown
- Ladder/mountain **parallel-rung overrides** (advanced — use when one exercise in a rung naturally takes a *different scale* than the others, e.g. a Run that descends 500→100m paired with Box Jumps that descend 50→10 reps): any exercise may carry its own `varies`/`start`/`end`/`step` (and `peak` for mountains) which override the section defaults for that exercise only. The rung COUNT must match — every exercise in the section produces the same number of rungs (the validator strips overrides if they disagree). The section's `varies` is still required (and applies to any exercise that doesn't override). Canonical: `{"format":"ladder","varies":"reps","start":50,"end":10,"step":10,"rest_between_rungs":45,"exercises":[{"name":"Box Jump"},{"name":"Run","equipment":"treadmill","varies":"distance_m","start":500,"end":100,"step":100}]}` — both produce 5 rungs (50,40,30,20,10 reps / 500,400,300,200,100 m). BAD: setting `varies` on an exercise without matching `start`/`end`/`step` (rung count will diverge from the section). BAD: per-exercise overrides whose rung counts disagree (5 vs 8) — the LLM should pick one rung count and design both scales to match it.
```

- [ ] **Step 3: Confirm the change reads well**

Open `app/llm_context/shared/global_rules.md` and read the three bullets in sequence (existing 27 unchanged, new bullet about parallel-rung, existing `step` bullet at the bottom). They should read as a logical progression: section defaults → metric-only override (legacy) → full parallel-rung override → step rules.

- [ ] **Step 4: Run any tests that snapshot the prompt**

```bash
grep -rln "global_rules\|ladder.*override" /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/test --include="*.rb"
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb
```

If a test asserts the prompt contains specific ladder language, you may need to update its assertion to keep matching the new prose.

- [ ] **Step 5: Commit**

```bash
git add app/llm_context/shared/global_rules.md
git commit -m "$(cat <<'EOF'
docs(prompt): teach LLM the parallel-rung ladder override pattern

Adds a new bullet describing per-exercise varies/start/end/step
overrides for ladder/mountain sections, with a canonical example
(Run + Box Jump descender) and the parity constraint.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Add parallel-rung exemplars to activity examples

**Files:**
- Modify: `lib/llm_context/activities/deka_mile.rb` — add one example.
- Modify: `lib/llm_context/activities/hyrox.rb` — add one example.
- Test: existing `test/llm_context/contract_integrity_test.rb` continues to parse.

- [ ] **Step 1: Inspect the existing example shape**

```bash
sed -n '370,405p' /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/lib/llm_context/activities/deka_mile.rb
```

- [ ] **Step 2: Add a Deka Mile example using the parallel-rung pattern**

Add a new section to one of the existing examples (pick the one where it best fits — likely the Sprint Heavy variant) OR add it as a new example object. Example body:

```ruby
{ name: "Compromised Descender", format: "ladder",
  varies: "distance_m", start: 300, end: 100, step: 50, rest_between_rungs: 45,
  exercises: [
    { name: "Compromised Run", equipment: "treadmill", notes: "race pace — Deka Mile distance" },
    { name: "Box Jump", equipment: "bodyweight",
      varies: "reps", start: 25, end: 5, step: 5,
      notes: "rebound off the box, soft landings" }
  ] }
```

(Both produce 5 rungs: 300/250/200/150/100m run and 25/20/15/10/5 box jumps. The section's `varies` is `distance_m` because the Run uses it directly; Box Jump overrides with its own reps scale.)

- [ ] **Step 3: Add a Hyrox example using a different metric pairing**

In `lib/llm_context/activities/hyrox.rb`, add a section like:

```ruby
{ name: "Wall Ball Tower", format: "ladder",
  varies: "reps", start: 50, end: 10, step: 10, rest_between_rungs: 45,
  exercises: [
    { name: "Wall Balls", equipment: "wall_ball" },
    { name: "Row", equipment: "rowing_machine",
      varies: "calories", start: 25, end: 5, step: 5 }
  ] }
```

(Both produce 5 rungs: 50/40/30/20/10 wall balls and 25/20/15/10/5 cal row.)

- [ ] **Step 4: Run the integrity test**

```bash
bin/rails test test/llm_context/contract_integrity_test.rb
```

Expected: green.

- [ ] **Step 5: End-to-end sanity check (no LLM call needed — pure validation)**

```bash
bin/rails runner '
  example = LLMContext::Activities::DekaMile::EXAMPLES.find { |e| e.dig(:sections)&.any? { |s| s[:name] == "Compromised Descender" } }
  data = { "name" => example[:name], "duration_mins" => example[:duration_mins], "structure" => { "sections" => example[:sections].map(&:deep_stringify_keys) } }
  result = WorkoutValidator.new(data, duration_mins: example[:duration_mins], main_tag_slug: "deka-mile").validate_and_fix
  pp result["structure"]["sections"].find { |s| s["name"] == "Compromised Descender" }
'
```

Expected output: both exercises retain their overrides; rung counts are equal; no warnings fired.

- [ ] **Step 6: Commit**

```bash
git add lib/llm_context/activities/deka_mile.rb lib/llm_context/activities/hyrox.rb
git commit -m "$(cat <<'EOF'
feat(examples): add parallel-rung ladder exemplars

Deka Mile gains a Compromised Run + Box Jump descender; Hyrox gains a
Wall Ball + Row descender. Both showcase the per-exercise varies/start/
end/step override and exercise the validator's rung-count parity check.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Final verification

- [ ] **Step 1: Run the entire test suite**

```bash
bin/rails test
```

Expected: green across the board. No skipped tests.

- [ ] **Step 2: Lint**

```bash
bin/rubocop -A --no-server $(git diff --name-only main -- '*.rb' '*.erb' | tr '\n' ' ')
```

(Run only on changed files to avoid noise from the rest of the repo.)

- [ ] **Step 3: Manual generator smoke test (optional but recommended)**

```bash
bin/rails console
```

```ruby
user = User.first
workout = WorkoutLLMGenerator.call(user: user, activity: "Deka Mile", duration_mins: 45, session_notes: "include a mixed ladder with box jumps and compromised runs")
puts workout.structure.to_json
```

Confirm the structure contains a ladder/mountain section with per-exercise overrides, and the section renders correctly when you open `/workouts/:id` in the browser.

- [ ] **Step 4: Update the project memory**

After verifying the PR is ready (tests green + manual smoke test passed), update `~/.claude/projects/-Users-daz-Library-CloudStorage-ProtonDrive-daz-codes-pm-me-folder-volt/memory/project_parallel_rung_ladder.md` to mark PR 2 as completed (or remove it if it's no longer needed as an open project).

- [ ] **Step 5: Write a final report**

Summarize:
- What changed (the architecture lever — section defaults + overrides via `Workout::LadderSequence`)
- Where the screenshots from Task 8 live
- Anything that surprised you, partial verifications, or things you couldn't test (e.g. UI not verified because no browser)

---

## Risks and mitigations

- **Risk:** The LLM may emit overrides whose rung counts disagree often. **Mitigation:** Task 3 strips overrides silently with a warning rather than failing — the workout still renders.
- **Risk:** Existing share-card tests might assume the ladder description always carries the sequence. **Mitigation:** Task 9 adds tests for both shapes (default + mixed) before changing the implementation.
- **Risk:** The render path's switch from "always shared header" to "shared header only when no overrides" might surprise users of the manual builder. **Mitigation:** The manual builder cannot produce per-exercise overrides (Task 3 / out-of-scope), so manually-edited workouts always hit the shared-header path.
- **Risk:** `fix_deka_mile_compromised_run_cap` rewrite has the most novel logic. **Mitigation:** Task 5 has three explicit tests covering section-level, per-exercise, and no-op cases. Run the full validator suite after that task.

## Done criteria

- All tasks complete with their tests green.
- `bin/rails test` is green.
- A workout generated with parallel-rung ladders renders correctly in the browser (Task 8 + Task 12 smoke test).
- The Deka Mile cap side bug fix is verified by Task 5's first test.
- `app/llm_context/shared/global_rules.md` documents the new pattern.
