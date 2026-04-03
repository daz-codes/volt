# Section Categories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an explicit `category` field (`warm_up`, `main`, `finisher`, `cool_down`) to workout structure sections, replacing name-based regex filtering.

**Architecture:** Add `category` to the JSON structure schema, update the LLM tool definition and prompt, migrate all validator regex checks to use `category`, update the manual builder, fix `export_sections`, and backfill existing data.

**Tech Stack:** Rails 8, Ruby 3.4, MiniTest, Stimulus JS

**Spec:** `docs/superpowers/specs/2026-04-03-section-categories-design.md`

---

### Task 1: Add CATEGORIES constant and inference patterns to Workout model

**Files:**
- Modify: `app/models/workout.rb:16-17`

- [ ] **Step 1: Add constants**

```ruby
# Add after FORMATS on line 17
CATEGORIES = %w[warm_up main finisher cool_down].freeze

WARMUP_NAME_PATTERN  = /\bwarm|wake.?up|ease.?in|activation|loosen|mobilit|primer/i.freeze
COOLDOWN_NAME_PATTERN = /\bcool|stretch|recovery\s*flow|wind.?down|decompress|melt|reset|ease.?down|unwind/i.freeze
```

- [ ] **Step 2: Verify app boots**

Run: `bin/rails runner "puts Workout::CATEGORIES.inspect"`
Expected: `["warm_up", "main", "finisher", "cool_down"]`

- [ ] **Step 3: Commit**

```bash
git add app/models/workout.rb
git commit -m "feat: add CATEGORIES constant and name inference patterns to Workout"
```

---

### Task 2: Add `ensure_section_categories` to WorkoutValidator

**Files:**
- Modify: `app/services/workout_validator.rb:46-103` (validate_and_fix) and add new method

**Context:** This must run as the **first step** in `validate_and_fix` so all downstream methods can use `category` instead of name regex.

- [ ] **Step 1: Write failing test**

Add to `test/services/workout_validator_test.rb`:

```ruby
# -- Section category inference --

test "ensure_section_categories infers warm_up from name" do
  data = build_workout_with_sections([
    { "name" => "Gas Pedal", "format" => "straight", "exercises" => [{ "name" => "Jog" }] },
    { "name" => "Main Block", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] }
  ])
  # "Gas Pedal" doesn't match any pattern, should default to "main"
  result = WorkoutValidator.new(data, difficulty: "intermediate", duration_mins: 60, main_tag_slug: "").validate_and_fix
  sections = result.dig("structure", "sections")
  assert_equal "main", sections[0]["category"]
  assert_equal "main", sections[1]["category"]
end

test "ensure_section_categories infers warm_up from warm-up name" do
  data = build_workout_with_sections([
    { "name" => "Warm-Up", "format" => "straight", "exercises" => [{ "name" => "Jog" }] },
    { "name" => "Main Block", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] }
  ])
  result = WorkoutValidator.new(data, difficulty: "intermediate", duration_mins: 60, main_tag_slug: "").validate_and_fix
  sections = result.dig("structure", "sections")
  assert_equal "warm_up", sections[0]["category"]
  assert_equal "main", sections[1]["category"]
end

test "ensure_section_categories infers cool_down from name" do
  data = build_workout_with_sections([
    { "name" => "Main Block", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] },
    { "name" => "Decompress", "format" => "straight", "exercises" => [{ "name" => "Stretch" }] }
  ])
  result = WorkoutValidator.new(data, difficulty: "intermediate", duration_mins: 60, main_tag_slug: "").validate_and_fix
  sections = result.dig("structure", "sections")
  assert_equal "main", sections[0]["category"]
  assert_equal "cool_down", sections[1]["category"]
end

test "ensure_section_categories infers finisher for last tabata before cool-down" do
  data = build_workout_with_sections([
    { "name" => "Main Block", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] },
    { "name" => "Final Push", "format" => "tabata", "duration_mins" => 4, "exercises" => [{ "name" => "Row" }] },
    { "name" => "Cool-Down", "format" => "straight", "exercises" => [{ "name" => "Stretch" }] }
  ])
  result = WorkoutValidator.new(data, difficulty: "intermediate", duration_mins: 60, main_tag_slug: "").validate_and_fix
  sections = result.dig("structure", "sections")
  assert_equal "main", sections[0]["category"]
  assert_equal "finisher", sections[1]["category"]
  assert_equal "cool_down", sections[2]["category"]
end

test "ensure_section_categories preserves valid existing category" do
  data = build_workout_with_sections([
    { "name" => "Gas Pedal", "category" => "warm_up", "format" => "straight", "exercises" => [{ "name" => "Jog" }] },
    { "name" => "Main Block", "category" => "main", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] }
  ])
  result = WorkoutValidator.new(data, difficulty: "intermediate", duration_mins: 60, main_tag_slug: "").validate_and_fix
  sections = result.dig("structure", "sections")
  assert_equal "warm_up", sections[0]["category"]
  assert_equal "main", sections[1]["category"]
end

test "ensure_section_categories replaces invalid category" do
  data = build_workout_with_sections([
    { "name" => "Warm-Up", "category" => "bogus", "format" => "straight", "exercises" => [{ "name" => "Jog" }] }
  ])
  result = WorkoutValidator.new(data, difficulty: "intermediate", duration_mins: 60, main_tag_slug: "").validate_and_fix
  sections = result.dig("structure", "sections")
  assert_equal "warm_up", sections[0]["category"]
end
```

Add helper to the private section:

```ruby
def build_workout_with_sections(sections)
  { "structure" => { "sections" => sections } }
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/workout_validator_test.rb`
Expected: FAIL — `category` key not set on sections

- [ ] **Step 3: Implement `ensure_section_categories`**

Add to `app/services/workout_validator.rb` in the private section:

```ruby
def ensure_section_categories(sections)
  # First pass: infer from name patterns
  sections.each do |section|
    next if Workout::CATEGORIES.include?(section["category"])

    name = section["name"].to_s
    section["category"] = if name.match?(Workout::WARMUP_NAME_PATTERN)
      "warm_up"
    elsif name.match?(Workout::COOLDOWN_NAME_PATTERN)
      "cool_down"
    else
      "main"
    end
  end

  # Second pass: detect finisher (last non-cool-down section with tabata/hundred/for_time format)
  last_main_idx = sections.rindex { |s| s["category"] != "cool_down" }
  if last_main_idx
    candidate = sections[last_main_idx]
    if %w[tabata hundred for_time].include?(candidate["format"]) && candidate["category"] == "main"
      # Only mark as finisher if there's at least one other main section before it
      has_prior_main = sections[0...last_main_idx].any? { |s| s["category"] == "main" }
      candidate["category"] = "finisher" if has_prior_main
    end
  end
end
```

Call it as the first line in `validate_and_fix` (line 47, after `sections = ...`):

```ruby
def validate_and_fix
  sections = Array(@data.dig("structure", "sections"))

  ensure_section_categories(sections)

  sections.each_with_index do |section, idx|
  # ... rest unchanged
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/workout_validator_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/workout_validator.rb test/services/workout_validator_test.rb
git commit -m "feat: add ensure_section_categories to WorkoutValidator"
```

---

### Task 3: Migrate validator regex checks to use `category`

**Files:**
- Modify: `app/services/workout_validator.rb`

**Context:** Now that `ensure_section_categories` runs first and guarantees every section has a valid `category`, replace all name-regex checks with `category` lookups.

- [ ] **Step 1: Replace `WARMUP_COOLDOWN_PATTERN` checks**

In `fix_single_set_sections` (line 269):
```ruby
# Before
next if section["name"].to_s.match?(WARMUP_COOLDOWN_PATTERN)
# After
next if %w[warm_up cool_down].include?(section["category"])
```

In `fix_notes_as_programming` (line 322):
```ruby
# Before
next if section["name"].to_s.match?(WARMUP_COOLDOWN_PATTERN)
# After
next if %w[warm_up cool_down].include?(section["category"])
```

In `fix_fm_strength_sets` (line 758):
```ruby
# Before
next if section["name"].to_s.match?(WARMUP_COOLDOWN_PATTERN)
# After
next if %w[warm_up cool_down].include?(section["category"])
```

In `fix_fm_trim_metabolic_blocks` (lines 961-963):
```ruby
# Before
metabolic = sections.reject do |s|
  name = s["name"].to_s
  name.match?(WARMUP_COOLDOWN_PATTERN) ||
    name.match?(ABS_PILATES_PATTERN) ||
    name.match?(/strength/i)
end
# After
metabolic = sections.reject do |s|
  %w[warm_up cool_down].include?(s["category"]) ||
    s["name"].to_s.match?(ABS_PILATES_PATTERN) ||
    s["name"].to_s.match?(/strength/i)
end
```

- [ ] **Step 2: Replace `WARMUP_NAME_PATTERN` / `COOLDOWN_NAME_PATTERN` checks**

In `dedup_warmup_sections` (line 1037):
```ruby
# Before
break unless s["name"].to_s.match?(WARMUP_NAME_PATTERN)
# After
break unless s["category"] == "warm_up"
```

In `dedup_cooldown_sections` (line 1057):
```ruby
# Before
break unless s["name"].to_s.match?(COOLDOWN_NAME_PATTERN)
# After
break unless s["category"] == "cool_down"
```

In `check_cooldown` (line 1078):
```ruby
# Before
return unless last["name"].to_s.match?(COOLDOWN_NAME_PATTERN)
# After
return unless last["category"] == "cool_down"
```

In `fix_warmup_format` (line 1108):
```ruby
# Before
warmup = sections.first
# After
warmup = sections.find { |s| s["category"] == "warm_up" }
```

- [ ] **Step 3: Replace FM method regex checks**

In `fix_fm_warmup` (line 785):
```ruby
# Before
warmup = sections.find { |s| s["name"].to_s.match?(/warm/i) }
# After
warmup = sections.find { |s| s["category"] == "warm_up" }
```

When injecting a new warmup in `fix_fm_warmup`, add `"category" => "warm_up"` to the hash.

In `fix_fm_cooldown` (line 820):
```ruby
# Before
has_cooldown = last && last["name"].to_s.match?(/cool|stretch|melt|wind.?down|fade|decompress|reset|unwind/i)
# After
has_cooldown = last && last["category"] == "cool_down"
```

When injecting a new cooldown in `fix_fm_cooldown`, add `"category" => "cool_down"` to the hash.

In `fix_fm_section_order` (line 1010):
```ruby
# Before
cooldown_idx = sections.index { |s| s["name"].to_s.match?(/cool|stretch/i) }
# After
cooldown_idx = sections.index { |s| s["category"] == "cool_down" }
```

And line 1020:
```ruby
# Before
new_target = sections.index { |s| s["name"].to_s.match?(/cool|stretch/i) } || sections.size
# After
new_target = sections.index { |s| s["category"] == "cool_down" } || sections.size
```

- [ ] **Step 4: Remove old regex constants from validator**

Delete these lines from `workout_validator.rb`:
- Line 263: `WARMUP_COOLDOWN_PATTERN = ...`
- Line 264: `WARMUP_NAME_PATTERN = ...`
- Line 1028: `COOLDOWN_NAME_PATTERN = ...`

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add app/services/workout_validator.rb
git commit -m "refactor: migrate validator regex checks to use section category"
```

---

### Task 4: Update `export_sections` and its tests

**Files:**
- Modify: `app/models/workout/exportable.rb:99-103`
- Modify: `test/models/workout/exportable_test.rb`

- [ ] **Step 1: Update existing tests to include `category`**

In `test/models/workout/exportable_test.rb`, add `"category" => "..."` to every test section hash. For example the first test becomes:

```ruby
test "export_sections filters out warm_up and cool_down categories" do
  @workout.structure = {
    "sections" => [
      { "name" => "Gas Pedal", "category" => "warm_up", "format" => "straight", "exercises" => [{ "name" => "Jog" }] },
      { "name" => "Main", "category" => "main", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] }
    ]
  }

  sections = @workout.export_sections
  assert_equal 1, sections.length
  assert_equal "3 Rounds", sections.first[:label]
end
```

Apply `"category" => "main"` to all other test sections (they are all main-set exercises). Update the cool-down filtering test similarly with `"category" => "cool_down"`.

Add a new test:

```ruby
test "export_sections includes finisher sections" do
  @workout.structure = {
    "sections" => [
      { "name" => "Main Block", "category" => "main", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] },
      { "name" => "Final Push", "category" => "finisher", "format" => "tabata", "exercises" => [{ "name" => "Row" }] }
    ]
  }

  sections = @workout.export_sections
  assert_equal 2, sections.length
  assert_equal "Tabata", sections.last[:label]
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/workout/exportable_test.rb`
Expected: Some tests FAIL (the warm-up/cool-down filtering tests will fail because `export_sections` still uses name regex, not `category`)

- [ ] **Step 3: Update `export_sections`**

In `app/models/workout/exportable.rb`, replace lines 100-103:

```ruby
# Before
main = raw.reject { |s|
  s["name"].to_s.match?(/warm.?up|cool.?down|stretch|recovery|primer|activation|mobility/i)
}

# After
main = raw.select { |s| %w[main finisher].include?(s["category"]) }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/workout/exportable_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/workout/exportable.rb test/models/workout/exportable_test.rb
git commit -m "feat: filter export_sections by category instead of name regex"
```

---

### Task 5: Update LLM generator tool definition and prompt

**Files:**
- Modify: `app/services/workout_llm_generator.rb:408` (required array) and `~410` (properties) and `~1049` (prompt rules)

- [ ] **Step 1: Add `category` to tool schema**

In `TOOL_DEFINITION`, add `category` to the section properties (after `name` on line 410):

```ruby
category: { type: "string", enum: %w[warm_up main finisher cool_down], description: "Section purpose: warm_up for warm-up/activation/mobility, main for primary working blocks, finisher for short burners at the end (tabata, hundred), cool_down for stretching/recovery/decompression" },
```

Update the `required` array on line 408:

```ruby
required: %w[name category format],
```

- [ ] **Step 2: Add prompt rule**

After the format selection rules (around line 1049), add:

```
- SECTION CATEGORY — every section MUST include a `category` field: `warm_up` for warm-up/activation/mobility sections, `main` for primary working blocks, `finisher` for short burners at the end (e.g. tabata, hundred, for_time finisher), `cool_down` for stretching/recovery/decompression. This field is required and must match the section's purpose regardless of what creative name you give it.
```

- [ ] **Step 3: Verify app boots**

Run: `bin/rails runner "puts WorkoutLLMGenerator::TOOL_DEFINITION[:input_schema][:properties][:structure][:properties][:sections][:items][:required].inspect"`
Expected: `["name", "category", "format"]`

- [ ] **Step 4: Commit**

```bash
git add app/services/workout_llm_generator.rb
git commit -m "feat: add category to LLM workout generator tool schema and prompt"
```

---

### Task 6: Update manual builder (form, JS, StructureBuilder)

**Files:**
- Modify: `app/views/workouts/_builder_form.html.erb:67-76`
- Modify: `app/javascript/controllers/builder_controller.js:48-63`
- Modify: `app/models/workout/structure_builder.rb:18-22`

- [ ] **Step 1: Add category dropdown to builder form**

In `app/views/workouts/_builder_form.html.erb`, add a category select before the format select (between lines 70 and 71):

```erb
<select name="sections[<%= si %>][category]"
  class="bg-zinc-800 border border-zinc-600 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-lime-400 transition-colors">
  <% [["warm_up", "Warm-up"], ["main", "Main"], ["finisher", "Finisher"], ["cool_down", "Cool-down"]].each do |val, label| %>
    <option value="<%= val %>" <%= "selected" if section["category"] == val %>><%= label %></option>
  <% end %>
</select>
```

- [ ] **Step 2: Add category dropdown to JS section template**

In `app/javascript/controllers/builder_controller.js`, add a category select inside the `sectionTemplate` method (after the name input, before the format select around line 54):

```javascript
<select name="sections[${id}][category]"
  class="bg-zinc-800 border border-zinc-600 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-lime-400 transition-colors">
  <option value="warm_up">Warm-up</option>
  <option value="main" selected>Main</option>
  <option value="finisher">Finisher</option>
  <option value="cool_down">Cool-down</option>
</select>
```

- [ ] **Step 3: Include category in StructureBuilder**

In `app/models/workout/structure_builder.rb`, update `build_section_from_params` (line 19):

```ruby
def build_section_from_params(s)
  section = {
    "name"     => s[:name].to_s.strip,
    "category" => Workout::CATEGORIES.include?(s[:category]) ? s[:category] : "main",
    "format"   => valid_formats.include?(s[:format]) ? s[:format] : "straight"
  }
```

- [ ] **Step 4: Verify form renders**

Run: `bin/rails server` and visit `/workouts/new`
Expected: Category dropdown visible in each section

- [ ] **Step 5: Commit**

```bash
git add app/views/workouts/_builder_form.html.erb app/javascript/controllers/builder_controller.js app/models/workout/structure_builder.rb
git commit -m "feat: add category dropdown to manual workout builder"
```

---

### Task 7: Create backfill rake task

**Files:**
- Create: `lib/tasks/backfill_section_categories.rake`

- [ ] **Step 1: Write the rake task**

```ruby
namespace :workouts do
  desc "Backfill section categories on existing workouts"
  task backfill_categories: :environment do
    updated = 0
    Workout.find_each do |workout|
      next unless workout.structure.is_a?(Hash)
      sections = Array(workout.structure["sections"])
      next if sections.empty?

      changed = false
      sections.each_with_index do |section, i|
        next if Workout::CATEGORIES.include?(section["category"])

        section["category"] = infer_category(section, sections, i)
        changed = true
      end

      if changed
        workout.update_column(:structure, workout.structure)
        updated += 1
      end
    end
    puts "Backfilled #{updated} workouts"
  end

  private

  def infer_category(section, all_sections, index)
    name = section["name"].to_s
    fmt = section["format"].to_s

    if name.match?(Workout::WARMUP_NAME_PATTERN)
      "warm_up"
    elsif name.match?(Workout::COOLDOWN_NAME_PATTERN)
      "cool_down"
    elsif %w[tabata hundred for_time].include?(fmt) && index == last_non_cooldown_index(all_sections)
      has_prior_main = all_sections[0...index].any? { |s| !s["name"].to_s.match?(Workout::WARMUP_NAME_PATTERN) && !s["name"].to_s.match?(Workout::COOLDOWN_NAME_PATTERN) }
      has_prior_main ? "finisher" : "main"
    else
      "main"
    end
  end

  def last_non_cooldown_index(sections)
    sections.rindex { |s| !s["name"].to_s.match?(Workout::COOLDOWN_NAME_PATTERN) }
  end
end
```

- [ ] **Step 2: Verify task is listed**

Run: `bin/rails -T | grep backfill`
Expected: `rake workouts:backfill_categories`

- [ ] **Step 3: Run the backfill locally**

Run: `bin/rails workouts:backfill_categories`
Expected: `Backfilled N workouts`

- [ ] **Step 4: Verify a backfilled workout**

Run: `bin/rails runner "w = Workout.first; puts w.structure['sections'].map { |s| [s['name'], s['category']].inspect }"`
Expected: Each section has a category

- [ ] **Step 5: Commit**

```bash
git add lib/tasks/backfill_section_categories.rake
git commit -m "feat: add rake task to backfill section categories on existing workouts"
```

---

### Task 8: Run full test suite and final verification

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests PASS

- [ ] **Step 2: Verify export_sections filters by category**

Run: `bin/rails runner "w = Workout.first; puts w.export_sections.map { |s| s[:label] }.inspect"`
Expected: Only main/finisher sections appear, no warm-up or cool-down

- [ ] **Step 3: Commit all (if any unstaged changes)**

```bash
git status
```

---

### Post-deploy

After deploying, run the backfill on production:

```bash
bin/kamal app exec "bin/rails workouts:backfill_categories"
```
