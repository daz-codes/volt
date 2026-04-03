# Section Categories — Design Spec

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an explicit `category` field to workout structure sections, replacing unreliable name-based regex filtering with a queryable enum.

**Problem:** Section names are creative and freeform (e.g. "Gas Pedal" for a warm-up, "Decompress" for a cool-down). The current regex filters across `export_sections` and `WorkoutValidator` fail to identify these, causing incorrect filtering in exports and validation.

**Categories:** `warm_up`, `main`, `finisher`, `cool_down`

---

## 1. Structure JSON Schema Change

Add `category` as a required string field on each section object in the workout structure JSON.

**Valid values:** `warm_up`, `main`, `finisher`, `cool_down`

**Example:**
```json
{
  "sections": [
    {
      "name": "Gas Pedal",
      "category": "warm_up",
      "format": "straight",
      "exercises": [...]
    },
    {
      "name": "Run-Station Ladder",
      "category": "main",
      "format": "rounds",
      "rounds": 3,
      "exercises": [...]
    },
    {
      "name": "Final Push",
      "category": "finisher",
      "format": "tabata",
      "exercises": [...]
    },
    {
      "name": "Decompress",
      "category": "cool_down",
      "format": "straight",
      "exercises": [...]
    }
  ]
}
```

**Constants:** Add `CATEGORIES = %w[warm_up main finisher cool_down].freeze` to the `Workout` model alongside the existing `FORMATS` constant.

**Shared inference regex:** Define consolidated patterns on the model for use by both the validator and backfill task:

```ruby
WARMUP_NAME_PATTERN  = /\bwarm|wake.?up|ease.?in|activation|loosen|mobilit|primer/i
COOLDOWN_NAME_PATTERN = /\bcool|stretch|recovery\s*flow|wind.?down|decompress|melt|reset|ease.?down|unwind/i
```

These consolidate all existing regex patterns from the validator (`WARMUP_NAME_PATTERN`, `COOLDOWN_NAME_PATTERN`, `WARMUP_COOLDOWN_PATTERN`) and `export_sections` into a single source of truth.

## 2. LLM Generator Changes

**File:** `app/services/workout_llm_generator.rb`

**Tool definition schema** (around line 400): Add `category` to the section object properties:

```ruby
category: {
  type: "string",
  enum: %w[warm_up main finisher cool_down],
  description: "Section purpose: warm_up, main, finisher, or cool_down"
}
```

Add `category` to the section's `required` array.

**Prompt rules** (around line 1050): Add a rule:

> "Every section must include a `category` field. Use `warm_up` for warm-up/activation/mobility sections, `main` for primary working blocks, `finisher` for short burners at the end (e.g. tabata, hundred), and `cool_down` for stretching/recovery/decompression."

## 3. Validator Changes

**File:** `app/services/workout_validator.rb`

### 3a. New `ensure_section_categories` method

Runs as the **first step** in `validate_and_fix` (before any other method that needs to identify section types). For each section:

1. If `category` is present and valid — keep it
2. If `category` is missing or invalid — infer using `Workout::WARMUP_NAME_PATTERN` / `Workout::COOLDOWN_NAME_PATTERN`, with finisher heuristic (see below)
3. Save the inferred category back to the section

**Finisher inference heuristic:** The last non-cool-down section with format `tabata`, `hundred`, or `for_time` is categorized as `finisher`. Everything else that doesn't match warm-up or cool-down patterns defaults to `main`.

### 3b. Migrate existing regex usage to `category`

The validator currently has ~8 methods that use name-regex patterns (`WARMUP_NAME_PATTERN`, `COOLDOWN_NAME_PATTERN`, `WARMUP_COOLDOWN_PATTERN`) to identify section types. Since `ensure_section_categories` runs first and guarantees every section has a valid `category`, these methods should be updated to use `category` instead:

**Methods to update:**
- `fix_notes_as_programming` — replace `section["name"].to_s.match?(WARMUP_COOLDOWN_PATTERN)` with `%w[warm_up cool_down].include?(section["category"])`
- `fix_single_set_sections` — same replacement
- `fix_fm_strength_sets` — same replacement
- `fix_fm_trim_metabolic_blocks` — same replacement
- `dedup_warmup_sections` — replace `s["name"].to_s.match?(WARMUP_NAME_PATTERN)` with `s["category"] == "warm_up"`
- `dedup_cooldown_sections` — replace `s["name"].to_s.match?(COOLDOWN_NAME_PATTERN)` with `s["category"] == "cool_down"`
- `check_cooldown` — replace `last["name"].to_s.match?(COOLDOWN_NAME_PATTERN)` with `last["category"] == "cool_down"`
- `fix_warmup_format` — replace first-section assumption with `sections.find { |s| s["category"] == "warm_up" }`

**FM-specific methods** (`fix_fm_warmup`, `fix_fm_cooldown`, `fix_fm_section_order`, `fix_fm_ensure_abs`, etc.) also use name-regex. These should be updated with the same pattern.

After all methods are migrated, the old `WARMUP_NAME_PATTERN`, `COOLDOWN_NAME_PATTERN`, and `WARMUP_COOLDOWN_PATTERN` constants can be removed from the validator (the consolidated versions live on the `Workout` model for inference only).

## 4. Manual Builder Changes

**File:** `app/views/workouts/_builder_form.html.erb`

Add a category dropdown to each section in the builder form, before the format dropdown:

```erb
<select name="sections[][category]">
  <option value="warm_up">Warm-up</option>
  <option value="main" selected>Main</option>
  <option value="finisher">Finisher</option>
  <option value="cool_down">Cool-down</option>
</select>
```

Default to `main` for new sections.

**File:** `app/javascript/controllers/builder_controller.js`

Add the same category dropdown to `sectionTemplate` (around line 48) so dynamically-added sections also include it.

**File:** `app/models/workout/structure_builder.rb`

In `build_section_from_params`, include `category` from params with validation:

```ruby
"category" => Workout::CATEGORIES.include?(s[:category]) ? s[:category] : "main"
```

## 5. Export Filtering Changes

**File:** `app/models/workout/exportable.rb`

Replace the name regex filter in `export_sections` (lines 101-103):

```ruby
# Before
main = raw.reject { |s|
  s["name"].to_s.match?(/warm.?up|cool.?down|stretch|recovery|primer|activation|mobility/i)
}

# After
main = raw.select { |s| %w[main finisher].include?(s["category"]) }
```

This is the core fix — export images and share cards will now correctly exclude warm-up and cool-down sections regardless of their creative names.

## 6. Backfill Rake Task

**File:** `lib/tasks/backfill_section_categories.rake`

A one-time rake task that iterates all workouts and sets `category` on each section. Uses `update_column` to skip validations/callbacks (intentional — the backfill does its own inference and we don't want the full validator running on every row).

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
    puts "Updated #{updated} workouts"
  end

  def infer_category(section, all_sections, index)
    name = section["name"].to_s
    fmt = section["format"].to_s

    if name.match?(Workout::WARMUP_NAME_PATTERN)
      "warm_up"
    elsif name.match?(Workout::COOLDOWN_NAME_PATTERN)
      "cool_down"
    elsif %w[tabata hundred for_time].include?(fmt) && index == last_non_cooldown_index(all_sections)
      "finisher"
    else
      "main"
    end
  end

  def last_non_cooldown_index(sections)
    sections.rindex { |s| !s["name"].to_s.match?(Workout::COOLDOWN_NAME_PATTERN) }
  end
end
```

**Run after deploy:** `bin/rails workouts:backfill_categories`

Note: The backfill uses regex as a one-time migration. It won't catch creative names like "Gas Pedal" — those will need manual correction or will be correct on the next LLM regeneration. Going forward, the LLM will always output the category.

## 7. Test Changes

**File:** `test/models/workout/exportable_test.rb`

Update all existing `export_sections` tests to include `category` on test sections. Replace the warm-up/cool-down filtering tests to filter on `category` instead of name:

```ruby
test "export_sections filters out warm_up and cool_down categories" do
  @workout.structure = {
    "sections" => [
      { "name" => "Gas Pedal", "category" => "warm_up", "format" => "straight", "exercises" => [{ "name" => "Jog" }] },
      { "name" => "Engine Block", "category" => "main", "format" => "emom", "duration_mins" => 6, "exercises" => [{ "name" => "Burpee", "reps" => 10 }] },
      { "name" => "Decompress", "category" => "cool_down", "format" => "straight", "exercises" => [{ "name" => "Stretch" }] }
    ]
  }
  sections = @workout.export_sections
  assert_equal 1, sections.length
end

test "export_sections includes finisher sections" do
  @workout.structure = {
    "sections" => [
      { "name" => "Main Block", "category" => "main", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] },
      { "name" => "Final Push", "category" => "finisher", "format" => "tabata", "exercises" => [{ "name" => "Row" }] }
    ]
  }
  sections = @workout.export_sections
  assert_equal 2, sections.length
end
```

**File:** `test/services/workout_validator_test.rb`

Add tests for:
- Category inference when category is missing
- Finisher inference heuristic
- Valid category preserved when already set
- Invalid category replaced with inferred value

## 8. What Stays Unchanged

- `WorkoutPdfGenerator` — shows all sections (no category filtering)
- `shared/_workout_section.html.erb` — displays all sections in workout views
- `export_image` controller action — calls `export_sections` which handles filtering
- `ExerciseSwapService` — finds sections by index, no category awareness needed
- `WorkoutLog::ExerciseLogBuilder` — iterates all sections by index
- Routes — no changes

## Data Flow

```
LLM generates workout → includes category on each section
  → WorkoutValidator.ensure_section_categories runs first
  → Validates/infers category, then all other validator methods use category
  → Structure saved to DB as JSON

Manual builder → user selects category from dropdown
  → StructureBuilder validates and includes category in section hash
  → Structure saved to DB as JSON

Export/share card → export_sections selects main + finisher categories
  → Warm-up and cool-down excluded regardless of section name
```
