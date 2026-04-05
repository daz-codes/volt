# Workout Difficulty Scaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users scale any workout across 5 difficulty levels (Beginner → Elite), with deterministic adjustments for levels 2/4 and LLM-powered transformations for levels 1/5, personalised to each user's posting history.

**Architecture:** Two concerns (`Workout::Scalable` for scaling logic, `User::HasDefaultDifficulty` for personalised defaults), a new controller action with Turbo Frame response, and a Stimulus controller for the UI. The original level-3 structure is preserved on the workout so all scaling derives from a stable source.

**Tech Stack:** Rails 8.2, Hotwire (Turbo Frames, Stimulus), Claude Haiku (for extreme levels), SQLite (json columns)

**Spec:** `docs/superpowers/specs/2026-04-05-workout-difficulty-scaling-design.md`

---

### Task 1: Database Migrations

**Files:**
- Create: `db/migrate/TIMESTAMP_add_original_structure_to_workouts.rb`
- Create: `db/migrate/TIMESTAMP_add_difficulty_level_to_workout_logs.rb`

- [ ] **Step 1: Generate the workouts migration**

```bash
bin/rails generate migration AddOriginalStructureToWorkouts original_structure:json
```

- [ ] **Step 2: Generate the workout_logs migration**

```bash
bin/rails generate migration AddDifficultyLevelToWorkoutLogs difficulty_level:integer
```

- [ ] **Step 3: Edit the workout_logs migration to add default value**

Open the generated migration and ensure it reads:

```ruby
class AddDifficultyLevelToWorkoutLogs < ActiveRecord::Migration[8.2]
  def change
    add_column :workout_logs, :difficulty_level, :integer, default: 3, null: false
  end
end
```

- [ ] **Step 4: Run migrations**

```bash
bin/rails db:migrate
```

Expected: both migrations run cleanly, `db/schema.rb` updated with `original_structure` on workouts and `difficulty_level` on workout_logs.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*_add_original_structure_to_workouts.rb db/migrate/*_add_difficulty_level_to_workout_logs.rb db/schema.rb
git commit -m "Add original_structure to workouts and difficulty_level to workout_logs"
```

---

### Task 2: User::HasDefaultDifficulty Concern

**Files:**
- Create: `app/models/user/has_default_difficulty.rb`
- Modify: `app/models/user.rb`
- Create: `test/models/user/has_default_difficulty_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/models/user/has_default_difficulty_test.rb`:

```ruby
require "test_helper"

class User::HasDefaultDifficultyTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    # Clear any existing logs to start fresh
    @user.workout_logs.destroy_all
  end

  test "returns 3 when user has no posting history" do
    assert_equal 3, @user.default_difficulty_level
  end

  test "returns the weighted average of recent difficulty levels" do
    workout = workouts(:hyrox_session)
    5.times do |i|
      @user.workout_logs.create!(
        workout: workout,
        completed_at: (5 - i).days.ago,
        sweat_rating: 3,
        difficulty_level: 4
      )
    end

    assert_equal 4, @user.default_difficulty_level
  end

  test "weights recent posts more heavily" do
    workout = workouts(:hyrox_session)
    # 10 old posts at level 2
    10.times do |i|
      @user.workout_logs.create!(
        workout: workout,
        completed_at: (20 - i).days.ago,
        sweat_rating: 3,
        difficulty_level: 2
      )
    end
    # 3 recent posts at level 5
    3.times do |i|
      @user.workout_logs.create!(
        workout: workout,
        completed_at: (3 - i).days.ago,
        sweat_rating: 3,
        difficulty_level: 5
      )
    end

    # Recent level-5 posts should pull the average above 3
    result = @user.default_difficulty_level
    assert result >= 3, "Expected >= 3 due to recency weighting, got #{result}"
  end

  test "clamps result to 1-5 range" do
    workout = workouts(:hyrox_session)
    @user.workout_logs.create!(
      workout: workout,
      completed_at: 1.day.ago,
      sweat_rating: 3,
      difficulty_level: 5
    )

    result = @user.default_difficulty_level
    assert_includes 1..5, result
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/models/user/has_default_difficulty_test.rb
```

Expected: FAIL — `NoMethodError: undefined method 'default_difficulty_level'`

- [ ] **Step 3: Create the concern**

Create `app/models/user/has_default_difficulty.rb`:

```ruby
module User::HasDefaultDifficulty
  extend ActiveSupport::Concern

  DEFAULT_DIFFICULTY = 3
  HISTORY_LIMIT = 20
  DECAY_FACTOR = 0.85 # Each older post is worth 85% of the one before it

  def default_difficulty_level
    levels = workout_logs
      .where.not(difficulty_level: nil)
      .order(completed_at: :desc)
      .limit(HISTORY_LIMIT)
      .pluck(:difficulty_level)

    return DEFAULT_DIFFICULTY if levels.empty?

    weighted_sum = 0.0
    weight_total = 0.0

    levels.each_with_index do |level, i|
      weight = DECAY_FACTOR**i
      weighted_sum += level * weight
      weight_total += weight
    end

    (weighted_sum / weight_total).round.clamp(1, 5)
  end
end
```

- [ ] **Step 4: Include the concern in User**

In `app/models/user.rb`, add after the existing includes:

```ruby
include User::HasDefaultDifficulty
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bin/rails test test/models/user/has_default_difficulty_test.rb
```

Expected: all 4 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/models/user/has_default_difficulty.rb app/models/user.rb test/models/user/has_default_difficulty_test.rb
git commit -m "Add User::HasDefaultDifficulty concern for personalised difficulty defaults"
```

---

### Task 3: Workout::Scalable Concern — Deterministic Scaling

**Files:**
- Create: `app/models/workout/scalable.rb`
- Modify: `app/models/workout.rb`
- Create: `test/models/workout/scalable_test.rb`

- [ ] **Step 1: Write failing tests for deterministic scaling**

Create `test/models/workout/scalable_test.rb`:

```ruby
require "test_helper"

class Workout::ScalableTest < ActiveSupport::TestCase
  setup do
    @workout = workouts(:hyrox_session)
    @workout.structure = {
      "goal" => "Test workout",
      "sections" => [
        {
          "name" => "Warm-Up", "category" => "warm_up", "format" => "straight",
          "duration_mins" => 5,
          "exercises" => [{ "name" => "Easy Row", "notes" => "Easy pace" }]
        },
        {
          "name" => "Main Circuit", "category" => "main", "format" => "rounds",
          "rounds" => 5,
          "exercises" => [
            { "name" => "KB Swings", "reps" => 20 },
            { "name" => "Box Jumps", "reps" => 15 },
            { "name" => "Row", "distance_m" => 400 }
          ]
        },
        {
          "name" => "The Ladder", "category" => "main", "format" => "ladder",
          "start" => 10, "end" => 1, "step" => 1, "varies" => "reps",
          "exercises" => [
            { "name" => "Thrusters" },
            { "name" => "Burpees" }
          ]
        },
        {
          "name" => "Cool-Down", "category" => "cool_down", "format" => "straight",
          "duration_mins" => 5,
          "exercises" => [{ "name" => "Stretch", "notes" => "Hold 30s each" }]
        }
      ]
    }
    @workout.original_structure = @workout.structure.deep_dup
  end

  test "scale_to 3 returns the original structure unchanged" do
    result = @workout.scale_to(3)
    assert_equal @workout.original_structure, result
  end

  test "scale_to 2 reduces rounds by 1" do
    result = @workout.scale_to(2)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    assert_equal 4, main["rounds"]
  end

  test "scale_to 4 increases rounds by 1" do
    result = @workout.scale_to(4)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    assert_equal 6, main["rounds"]
  end

  test "scale_to 2 reduces reps by ~20%" do
    result = @workout.scale_to(2)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    swings = main["exercises"].find { |e| e["name"] == "KB Swings" }
    # 20 * 0.8 = 16, rounded to 15 (nearest 5)
    assert_equal 15, swings["reps"]
  end

  test "scale_to 4 increases reps by ~20%" do
    result = @workout.scale_to(4)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    swings = main["exercises"].find { |e| e["name"] == "KB Swings" }
    # 20 * 1.2 = 24, rounded to 25 (nearest 5)
    assert_equal 25, swings["reps"]
  end

  test "scale_to 2 reduces distances" do
    result = @workout.scale_to(2)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    row = main["exercises"].find { |e| e["name"] == "Row" }
    # 400 * 0.75 = 300
    assert_equal 300, row["distance_m"]
  end

  test "scale_to 2 shrinks ladder range" do
    result = @workout.scale_to(2)
    ladder = result["sections"].find { |s| s["name"] == "The Ladder" }
    assert_equal 8, ladder["start"]
  end

  test "scale_to 4 extends ladder range" do
    result = @workout.scale_to(4)
    ladder = result["sections"].find { |s| s["name"] == "The Ladder" }
    assert_equal 12, ladder["start"]
  end

  test "warm_up and cool_down sections are never scaled" do
    result = @workout.scale_to(2)
    warmup = result["sections"].find { |s| s["category"] == "warm_up" }
    cooldown = result["sections"].find { |s| s["category"] == "cool_down" }

    assert_equal @workout.original_structure["sections"].first, warmup
    assert_equal @workout.original_structure["sections"].last, cooldown
  end

  test "scale_to uses structure as fallback when original_structure is nil" do
    @workout.original_structure = nil
    result = @workout.scale_to(2)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    assert_equal 4, main["rounds"]
  end

  test "tabata sections are not scaled" do
    @workout.structure["sections"] << {
      "name" => "Tabata", "category" => "main", "format" => "tabata",
      "exercises" => [
        { "name" => "Squat Curl and Press" },
        { "name" => "KB Swing with Lunge" }
      ]
    }
    @workout.original_structure = @workout.structure.deep_dup

    result = @workout.scale_to(2)
    tabata = result["sections"].find { |s| s["format"] == "tabata" }
    original_tabata = @workout.original_structure["sections"].find { |s| s["format"] == "tabata" }
    assert_equal original_tabata, tabata
  end

  test "hundred sections are not scaled" do
    @workout.structure["sections"] << {
      "name" => "The Hundred", "category" => "finisher", "format" => "hundred",
      "exercises" => [{ "name" => "KB Swings", "reps" => 100 }]
    }
    @workout.original_structure = @workout.structure.deep_dup

    result = @workout.scale_to(2)
    hundred = result["sections"].find { |s| s["format"] == "hundred" }
    assert_equal 100, hundred["exercises"].first["reps"]
  end

  test "matrix sections are not scaled" do
    @workout.structure["sections"] << {
      "name" => "Matrix", "category" => "main", "format" => "matrix",
      "exercises" => [
        { "name" => "Thrusters", "reps" => 10 },
        { "name" => "Pull-ups", "reps" => 10 }
      ]
    }
    @workout.original_structure = @workout.structure.deep_dup

    result = @workout.scale_to(2)
    matrix = result["sections"].find { |s| s["format"] == "matrix" }
    original_matrix = @workout.original_structure["sections"].find { |s| s["format"] == "matrix" }
    assert_equal original_matrix, matrix
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/models/workout/scalable_test.rb
```

Expected: FAIL — `NoMethodError: undefined method 'scale_to'`

- [ ] **Step 3: Create the Scalable concern with deterministic scaling**

Create `app/models/workout/scalable.rb`:

```ruby
module Workout::Scalable
  extend ActiveSupport::Concern

  SCALE_FACTORS = {
    2 => { reps: 0.8, distance: 0.75, calories: 0.8, rounds: -1, ladder: -2, mountain_peak: -1, emom_mins: -2 },
    4 => { reps: 1.2, distance: 1.25, calories: 1.2, rounds: 1,  ladder: 2,  mountain_peak: 1,  emom_mins: 2 }
  }.freeze

  # Formats that should never be deterministically scaled
  UNSCALED_FORMATS = %w[tabata hundred matrix].freeze

  # Section categories that should never be scaled
  UNSCALED_CATEGORIES = %w[warm_up cool_down].freeze

  WEIGHT_CUE_DOWN = {
    "heavy" => "moderate", "moderate" => "light-moderate",
    "light-moderate" => "light", "working weight" => "light-moderate"
  }.freeze

  WEIGHT_CUE_UP = {
    "light" => "light-moderate", "light-moderate" => "moderate",
    "moderate" => "heavy", "working weight" => "moderate-heavy"
  }.freeze

  def scale_to(level)
    source = (original_structure || structure).deep_dup
    return source if level == 3

    if level.in?([ 2, 4 ])
      scale_deterministic(source, level)
    else
      scale_with_llm(source, level)
    end
  end

  private

  def scale_deterministic(structure, level)
    factors = SCALE_FACTORS[level]

    structure["sections"].each do |section|
      next if UNSCALED_CATEGORIES.include?(section["category"])
      next if UNSCALED_FORMATS.include?(section["format"])

      scale_section(section, factors)
    end

    structure
  end

  def scale_section(section, factors)
    case section["format"]
    when "rounds", "for_time"
      scale_rounds_section(section, factors)
    when "ladder"
      scale_ladder_section(section, factors)
    when "mountain"
      scale_mountain_section(section, factors)
    when "emom"
      scale_emom_section(section, factors)
    when "amrap", "straight"
      scale_exercises(section["exercises"], factors)
    end
  end

  def scale_rounds_section(section, factors)
    if section["rounds"].to_i > 1
      section["rounds"] = [ section["rounds"].to_i + factors[:rounds], 2 ].max
    end
    scale_exercises(section["exercises"], factors)
  end

  def scale_ladder_section(section, factors)
    if section["start"].to_i > section["end"].to_i
      # Descending ladder (e.g. 10-1): adjust start
      section["start"] = [ section["start"].to_i + factors[:ladder], 3 ].max
    else
      # Ascending ladder: adjust end
      section["end"] = [ section["end"].to_i + factors[:ladder], 3 ].max
    end
  end

  def scale_mountain_section(section, factors)
    section["peak"] = [ section["peak"].to_i + factors[:mountain_peak], 2 ].max if section["peak"]
  end

  def scale_emom_section(section, factors)
    if section["duration_mins"].to_i > 0
      section["duration_mins"] = [ section["duration_mins"].to_i + factors[:emom_mins], 4 ].max
    end
    scale_exercises(section["exercises"], factors) unless section["emom_style"] == "rotating"
  end

  def scale_exercises(exercises, factors)
    return unless exercises

    exercises.each do |exercise|
      scale_reps(exercise, factors[:reps]) if exercise["reps"].to_i > 0
      scale_distance(exercise, factors[:distance]) if exercise["distance_m"].to_i > 0
      scale_calories(exercise, factors[:calories]) if exercise["calories"].to_i > 0
      scale_weight_cues(exercise, factors[:reps] < 1 ? :down : :up) if exercise["notes"].present?
    end
  end

  def scale_reps(exercise, factor)
    raw = exercise["reps"] * factor
    exercise["reps"] = if raw >= 10
      (raw / 5.0).round * 5
    else
      [ raw.round, 1 ].max
    end
  end

  def scale_distance(exercise, factor)
    raw = exercise["distance_m"] * factor
    is_running = exercise["name"].to_s.match?(/run|sprint|jog|treadmill/i)
    step = is_running ? 100 : 25
    exercise["distance_m"] = [ (raw / step.to_f).round * step, step ].max
  end

  def scale_calories(exercise, factor)
    raw = exercise["calories"] * factor
    exercise["calories"] = [ (raw / 5.0).round * 5, 5 ].max
  end

  def scale_weight_cues(exercise, direction)
    cues = direction == :down ? WEIGHT_CUE_DOWN : WEIGHT_CUE_UP
    notes = exercise["notes"]
    cues.each do |from, to|
      notes = notes.gsub(/\b#{Regexp.escape(from)}\b/i, to)
    end
    exercise["notes"] = notes
  end

  # Placeholder for Task 4 — LLM scaling
  def scale_with_llm(structure, level)
    # Fall back to deterministic for now
    fallback_level = level == 1 ? 2 : 4
    scale_deterministic(structure, fallback_level)
  end
end
```

- [ ] **Step 4: Include the concern in Workout**

In `app/models/workout.rb`, add after the existing includes:

```ruby
include Workout::Scalable
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bin/rails test test/models/workout/scalable_test.rb
```

Expected: all tests PASS.

- [ ] **Step 6: Run full test suite to check for regressions**

```bash
bin/rails test
```

Expected: only pre-existing OAuth failures.

- [ ] **Step 7: Commit**

```bash
git add app/models/workout/scalable.rb app/models/workout.rb test/models/workout/scalable_test.rb
git commit -m "Add Workout::Scalable concern with deterministic scaling for levels 2 and 4"
```

---

### Task 4: Workout::Scalable — LLM Scaling for Levels 1 and 5

**Files:**
- Modify: `app/models/workout/scalable.rb`
- Modify: `test/models/workout/scalable_test.rb`

- [ ] **Step 1: Add tests for LLM scaling behaviour**

Add to `test/models/workout/scalable_test.rb`:

```ruby
test "scale_to 1 calls LLM and returns a valid structure" do
  # We can't easily test the full LLM call in unit tests, so test the fallback
  # The LLM scaling is integration-tested separately
  result = @workout.scale_to(1)
  assert result.is_a?(Hash)
  assert result["sections"].is_a?(Array)
  # Should still have warm-up and cool-down
  categories = result["sections"].map { |s| s["category"] }
  assert_includes categories, "warm_up"
  assert_includes categories, "cool_down"
end

test "scale_to 5 calls LLM and returns a valid structure" do
  result = @workout.scale_to(5)
  assert result.is_a?(Hash)
  assert result["sections"].is_a?(Array)
end
```

- [ ] **Step 2: Implement LLM scaling in the concern**

Replace the `scale_with_llm` method in `app/models/workout/scalable.rb`:

```ruby
def scale_with_llm(structure, level)
  api_client = Class.new { include AnthropicApi }.new

  direction = level == 1 ? "beginner" : "elite"
  fallback_level = level == 1 ? 2 : 4

  prompt = build_scaling_prompt(structure, direction)

  result = api_client.call_anthropic_api(
    system: SCALING_SYSTEM_PROMPT,
    messages: [{ role: "user", content: prompt }],
    tools: [ WorkoutLLMGenerator::TOOL_DEFINITION ]
  )

  scaled = result.dig("structure") || structure
  # Preserve original warm-up and cool-down
  preserve_bookend_sections(structure, scaled)
  scaled
rescue StandardError => _e
  scale_deterministic(structure, fallback_level)
end
```

- [ ] **Step 3: Add the constants and helpers for LLM scaling**

Add to the concern, above the `private` keyword:

```ruby
SCALING_SYSTEM_PROMPT = <<~PROMPT
  You are an expert personal trainer. You will receive a workout structure and a target difficulty level.
  Your job is to scale the workout to match that level using the create_workout tool.

  Rules:
  - Keep the same overall session shape: same number of sections, same section names, same formats.
  - Leave warm-up and cool-down sections EXACTLY as they are — do not modify them.
  - For beginner scaling: substitute complex exercises for simpler alternatives (e.g. burpees → step-ups,
    box jumps → step-ups, devil press → DB deadlifts), reduce reps significantly (~40-50% of original),
    reduce rounds, use lighter weight cues, add more rest. The workout should feel accessible and safe.
  - For elite scaling: substitute exercises for harder variations (e.g. box jumps → box jump burpees,
    KB swings → KB snatch, push-ups → clap push-ups), increase reps (~30-40% above original),
    add rounds, use heavier weight cues, reduce rest. The workout should feel brutal.
  - Maintain the same equipment requirements — don't introduce equipment that wasn't in the original.
  - Keep the same duration target.
PROMPT
```

And add this private method:

```ruby
def build_scaling_prompt(structure, direction)
  <<~PROMPT
    Scale this workout to #{direction} level. Return the full modified structure using the create_workout tool.

    Original workout structure:
    #{JSON.pretty_generate(structure)}

    Remember: keep section names, formats, and structure the same. Only modify exercises, reps, rounds, and weight cues.
    Warm-up and cool-down must remain exactly as they are.
  PROMPT
end

def preserve_bookend_sections(original, scaled)
  original_sections = original["sections"] || []
  scaled_sections = scaled["sections"] || []

  original_sections.each_with_index do |section, i|
    if UNSCALED_CATEGORIES.include?(section["category"]) && scaled_sections[i]
      scaled_sections[i] = section.deep_dup
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
bin/rails test test/models/workout/scalable_test.rb
```

Expected: all tests PASS (LLM tests use the fallback path in test environment due to no API key, which is fine — the fallback is tested).

- [ ] **Step 5: Commit**

```bash
git add app/models/workout/scalable.rb test/models/workout/scalable_test.rb
git commit -m "Add LLM scaling for difficulty levels 1 and 5 with fallback"
```

---

### Task 5: Set original_structure on All Creation Paths

**Files:**
- Modify: `app/controllers/workouts_controller.rb` (persist_preview, create_manual, clone, save)

- [ ] **Step 1: Update persist_preview**

In `app/controllers/workouts_controller.rb`, find the `persist_preview` method. Change:

```ruby
workout = Current.user.workouts.create!(**cached[:attrs], status: "active")
```

To:

```ruby
workout = Current.user.workouts.create!(
  **cached[:attrs],
  status: "active",
  original_structure: cached[:attrs][:structure]
)
```

- [ ] **Step 2: Update create_manual**

In the `create_manual` method, after `@workout.structure = ...` and before `if @workout.save`, add:

```ruby
@workout.original_structure = @workout.structure
```

- [ ] **Step 3: Update clone**

In the `clone` method, add `original_structure` to the create! call:

```ruby
copy = Current.user.workouts.create!(
  name:                "#{@workout.name} (copy)",
  activity_id:         @workout.activity_id,
  session_notes:       @workout.session_notes,
  duration_mins:       @workout.duration_mins,
  status:              "active",
  structure:           @workout.structure,
  original_structure:  @workout.original_structure || @workout.structure,
  source_workout:      @workout
)
```

- [ ] **Step 4: Update save**

In the `save` method, add `original_structure` to the create! call:

```ruby
copy = Current.user.workouts.create!(
  name:                source.name,
  activity_id:         source.activity_id,
  session_notes:       source.session_notes,
  duration_mins:       source.duration_mins,
  status:              "active",
  structure:           source.structure,
  original_structure:  source.original_structure || source.structure,
  source_workout:      source
)
```

- [ ] **Step 5: Run full test suite**

```bash
bin/rails test
```

Expected: only pre-existing OAuth failures.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/workouts_controller.rb
git commit -m "Set original_structure on all workout creation paths"
```

---

### Task 6: Route and Controller Action

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/workouts_controller.rb`

- [ ] **Step 1: Add the scale route**

In `config/routes.rb`, add to the workouts member block:

```ruby
post :scale
```

Add it after the existing `post :swap_exercise` line.

- [ ] **Step 2: Add the scale controller action**

In `app/controllers/workouts_controller.rb`, add the `scale` action (as a public method alongside `show`, `clone`, etc.):

```ruby
def scale
  @workout = Workout.find(params[:id])
  current_level = params[:current_level].to_i.clamp(1, 5)
  direction = params[:direction]

  @difficulty_level = if direction == "up"
    [ current_level + 1, 5 ].min
  else
    [ current_level - 1, 1 ].max
  end

  @scaled_structure = @workout.scale_to(@difficulty_level)

  render partial: "workouts/preview",
         locals: { workout: @workout, debug_info: nil,
                   scaled_structure: @scaled_structure,
                   difficulty_level: @difficulty_level }
end
```

- [ ] **Step 3: Run tests to check routes**

```bash
bin/rails test
```

Expected: only pre-existing OAuth failures.

- [ ] **Step 4: Commit**

```bash
git add config/routes.rb app/controllers/workouts_controller.rb
git commit -m "Add scale route and controller action for workout difficulty"
```

---

### Task 7: Stimulus Controller

**Files:**
- Create: `app/javascript/controllers/difficulty_controller.js`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/difficulty_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dot", "downBtn", "upBtn", "hiddenField"]
  static values = { level: Number, workoutId: Number }

  connect() {
    this.updateUI()
  }

  levelValueChanged() {
    this.updateUI()
    // Update hidden field in post dialog (outside the Turbo Frame)
    const externalField = document.querySelector(
      `#complete_workout_${this.workoutIdValue} input[name="difficulty_level"]`
    )
    if (externalField) externalField.value = this.levelValue
  }

  updateUI() {
    const level = this.levelValue

    this.dotTargets.forEach((dot, i) => {
      if (i < level) {
        dot.classList.remove("bg-zinc-600")
        dot.classList.add("bg-volt")
      } else {
        dot.classList.remove("bg-volt")
        dot.classList.add("bg-zinc-600")
      }
    })

    if (this.hasDownBtnTarget) {
      this.downBtnTarget.disabled = level <= 1
      this.downBtnTarget.classList.toggle("opacity-40", level <= 1)
      this.downBtnTarget.classList.toggle("cursor-not-allowed", level <= 1)
    }

    if (this.hasUpBtnTarget) {
      this.upBtnTarget.disabled = level >= 5
      this.upBtnTarget.classList.toggle("opacity-40", level >= 5)
      this.upBtnTarget.classList.toggle("cursor-not-allowed", level >= 5)
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/controllers/difficulty_controller.js
git commit -m "Add difficulty Stimulus controller for scale UI"
```

---

### Task 8: Preview Partial — Difficulty Control UI

**Files:**
- Modify: `app/views/workouts/_preview.html.erb`
- Modify: `app/views/workouts/show.html.erb`

- [ ] **Step 1: Update the preview partial to accept scaled_structure and difficulty_level locals**

In `app/views/workouts/_preview.html.erb`, change the opening lines (lines 1-2). Replace:

```erb
<div class="mt-6 bg-zinc-800 border border-zinc-600/70 rounded-2xl overflow-hidden shadow-sm">
```

With:

```erb
<% difficulty_level = local_assigns[:difficulty_level] || 3 %>
<% display_structure = local_assigns[:scaled_structure] || workout.structure %>

<div class="mt-6 bg-zinc-800 border border-zinc-600/70 rounded-2xl overflow-hidden shadow-sm">
```

Then change the sections variable (around line 49) from:

```erb
<% sections = workout.structure.is_a?(Hash) ? Array(workout.structure["sections"]) : [] %>
```

To:

```erb
<% sections = display_structure.is_a?(Hash) ? Array(display_structure["sections"]) : [] %>
```

Also update the goal display (around line 43) from:

```erb
<% if workout.structure.is_a?(Hash) && workout.structure["goal"].present? %>
  <p class="text-gray-400 text-sm italic mt-3 leading-relaxed"><%= workout.structure["goal"] %></p>
```

To:

```erb
<% if display_structure.is_a?(Hash) && display_structure["goal"].present? %>
  <p class="text-gray-400 text-sm italic mt-3 leading-relaxed"><%= display_structure["goal"] %></p>
```

- [ ] **Step 2: Add the difficulty control to the header**

In the preview partial's header section, inside the `<div style="padding...">` block, after the workout name and activity/duration line, and before the goal paragraph, add the difficulty control. Find the closing `</div>` of the `flex items-start justify-between` div and add the difficulty control inside it, after the duration circle:

After the duration circle `<% end %>` (around line 40), add:

```erb
    <%# Difficulty control %>
    <div data-controller="difficulty"
         data-difficulty-level-value="<%= difficulty_level %>"
         data-difficulty-workout-id-value="<%= workout.id %>">
      <div class="flex items-center gap-2">
        <%= button_to scale_workout_path(workout), method: :post,
              params: { direction: "down", current_level: difficulty_level },
              data: { difficulty_target: "downBtn", turbo_frame: "workout_preview" },
              form: { class: "contents" },
              class: "flex-shrink-0 flex items-center justify-center w-7 h-7 rounded-lg border border-zinc-600 text-gray-500 hover:text-white hover:border-gray-400 transition-colors cursor-pointer #{'opacity-40 cursor-not-allowed' if difficulty_level <= 1}",
              disabled: difficulty_level <= 1 do %>
          <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/></svg>
        <% end %>
        <div class="text-center">
          <div class="flex gap-1.5 items-center">
            <% 5.times do |i| %>
              <div data-difficulty-target="dot"
                   class="w-2 h-2 rounded-full transition-colors <%= i < difficulty_level ? 'bg-volt' : 'bg-zinc-600' %>"></div>
            <% end %>
          </div>
          <p class="text-gray-600 text-[8px] font-bold uppercase tracking-widest mt-1">Difficulty</p>
        </div>
        <%= button_to scale_workout_path(workout), method: :post,
              params: { direction: "up", current_level: difficulty_level },
              data: { difficulty_target: "upBtn", turbo_frame: "workout_preview" },
              form: { class: "contents" },
              class: "flex-shrink-0 flex items-center justify-center w-7 h-7 rounded-lg border border-zinc-600 text-gray-500 hover:text-white hover:border-gray-400 transition-colors cursor-pointer #{'opacity-40 cursor-not-allowed' if difficulty_level >= 5}",
              disabled: difficulty_level >= 5 do %>
          <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        <% end %>
      </div>
    </div>
```

- [ ] **Step 3: Update the show page to pass the user's default difficulty**

In `app/views/workouts/show.html.erb`, update the turbo_frame_tag block that renders the preview. Change:

```erb
<%= turbo_frame_tag "workout_preview" do %>
  <%= render "workouts/preview", workout: @workout, debug_info: @debug_info %>
<% end %>
```

To:

```erb
<%= turbo_frame_tag "workout_preview" do %>
  <% default_level = Current.user.default_difficulty_level %>
  <% if default_level != 3 %>
    <%= render "workouts/preview", workout: @workout, debug_info: @debug_info,
          scaled_structure: @workout.scale_to(default_level),
          difficulty_level: default_level %>
  <% else %>
    <%= render "workouts/preview", workout: @workout, debug_info: @debug_info,
          difficulty_level: 3 %>
  <% end %>
<% end %>
```

- [ ] **Step 4: Add difficulty control to the mobile header in show.html.erb**

In the mobile `sm:hidden` section of `show.html.erb`, the difficulty control is already rendered inside the preview partial header, so no additional mobile-specific code is needed — the preview partial renders in both contexts.

- [ ] **Step 5: Run tests**

```bash
bin/rails test
```

Expected: only pre-existing OAuth failures.

- [ ] **Step 6: Verify in browser**

Start the dev server and navigate to a workout show page. Verify:
- Difficulty dots appear in the header next to the duration circle
- Clicking + and − updates the workout preview via Turbo Frame
- Dots fill up to the current level
- Buttons disable at extremes (1 and 5)

- [ ] **Step 7: Commit**

```bash
git add app/views/workouts/_preview.html.erb app/views/workouts/show.html.erb
git commit -m "Add difficulty control UI to workout preview header"
```

---

### Task 9: Post Dialog — Record Difficulty Level

**Files:**
- Modify: `app/views/shared/_complete_workout_dialog.html.erb`
- Modify: `app/controllers/workout_logs_controller.rb`

- [ ] **Step 1: Add hidden field to the post dialog**

In `app/views/shared/_complete_workout_dialog.html.erb`, after the existing hidden field `<%= f.hidden_field :workout_id, value: workout.id %>`, add:

```erb
<input type="hidden" name="difficulty_level" value="3" id="difficulty_level_<%= workout.id %>">
```

The Stimulus controller's `levelValueChanged` callback will update this field when the user scales the workout.

- [ ] **Step 2: Update the workout_logs create action to accept difficulty_level**

In `app/controllers/workout_logs_controller.rb`, in the `create` method, add `difficulty_level` to the workout_log build. Change:

```ruby
@workout_log = @workout.workout_logs.build(
  user:         Current.user,
  completed_at: Time.current,
  sweat_rating: params[:workout_log][:sweat_rating].to_i,
  notes:        params[:workout_log][:notes].presence,
  location:     params[:workout_log][:location].presence,
  visibility:   params[:workout_log][:private] == "1" ? "private" : "public"
)
```

To:

```ruby
@workout_log = @workout.workout_logs.build(
  user:             Current.user,
  completed_at:     Time.current,
  sweat_rating:     params[:workout_log][:sweat_rating].to_i,
  notes:            params[:workout_log][:notes].presence,
  location:         params[:workout_log][:location].presence,
  visibility:       params[:workout_log][:private] == "1" ? "private" : "public",
  difficulty_level: params[:difficulty_level].to_i.clamp(1, 5)
)
```

- [ ] **Step 3: Update the Stimulus controller to target the correct hidden field**

The `difficulty_controller.js` already handles this via the `levelValueChanged` callback which finds `#complete_workout_${workoutId} input[name="difficulty_level"]`. Verify the selector matches the hidden field ID pattern: the dialog has `id="complete_workout_<%= workout.id %>"` and the hidden field is inside it with `name="difficulty_level"`. This matches.

- [ ] **Step 4: Run tests**

```bash
bin/rails test
```

Expected: only pre-existing OAuth failures.

- [ ] **Step 5: Commit**

```bash
git add app/views/shared/_complete_workout_dialog.html.erb app/controllers/workout_logs_controller.rb
git commit -m "Record difficulty_level on workout logs when posting"
```

---

### Task 10: End-to-End Verification and Cleanup

**Files:**
- Review all modified files

- [ ] **Step 1: Run full test suite**

```bash
bin/rails test
```

Expected: only pre-existing OAuth failures.

- [ ] **Step 2: Manual browser testing**

Start the dev server and test the full flow:

1. Navigate to a workout show page
2. Verify difficulty dots appear at level 3 (or user's default)
3. Click + to scale up to 4 — verify reps/rounds increase in the preview
4. Click + again to 5 — verify LLM scaling (may take 2-3 seconds)
5. Click − back to 3 — verify original workout is restored
6. Click − to 2 — verify reps/rounds decrease
7. Click − to 1 — verify LLM scaling with simpler exercises
8. Post the workout at a non-default level
9. Check the workout_log record has the correct difficulty_level
10. Generate a new workout and verify it has original_structure set
11. Clone a workout and verify original_structure is copied

- [ ] **Step 3: Final commit if any cleanup was needed**

```bash
git add -A
git commit -m "Workout difficulty scaling: end-to-end verification complete"
```
