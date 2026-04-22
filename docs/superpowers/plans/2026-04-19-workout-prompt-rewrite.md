# Workout Prompt Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 2839-line, markdown-stitched prompt in `WorkoutLLMGenerator` with a per-activity "contract block" architecture: one Ruby file per activity (slug, contract hash, movement vocabulary, three hand-authored examples), composed into a short XML-tagged prompt. Remove Tread & Shred as a distinct activity and simplify warm-ups.

**Architecture:** A new `LLMContext::Activities` registry resolves a slug to an activity module. Each module exposes a `CONTRACT` hash, a `MOVEMENT_VOCABULARY` string, and an `EXAMPLES` array. The generator gains a `build_contract_prompt` method that emits XML-tagged sections (`<role>`, `<athlete>`, `<task>`, `<contract>`, `<global_rules>`, `<session_shape>`, `<examples>`, `<session_notes>`). Rollout is phased: scaffold Iron Engine first, cut Iron Engine over behind an env flag, fill out the remaining activities, then delete the old prompt path and the T&S references.

**Tech Stack:** Rails 8 + Zeitwerk autoload, Minitest, Anthropic Ruby SDK (tool use), existing `WorkoutLLMGenerator` + `WorkoutValidator` services.

**Spec:** `docs/superpowers/specs/2026-04-19-workout-prompt-rewrite-design.md`

## Critical facts the plan relies on

These were verified against the live codebase before writing — confirm they still hold before Task 0.

1. **Canonical activity slug for Iron Engine is `"kettlebell"`, not `"iron-engine"`.** `WorkoutLLMGenerator#initialize` line 527 normalises through `ACTIVITY_ALIASES`: `"iron-engine" => "kettlebell"` (line 231). So at runtime `@activity_slug == "kettlebell"`. Every registry key in this plan uses the *canonical DB slug*, and the module's `SLUG` constant matches it (`SLUG = "kettlebell"` for `IronEngine`, `SLUG = "tread-shred"` for whatever T&S routes to, etc.).
2. **Autoload:** Rails 8 treats each direct subdirectory of `app/` as its own autoload root. Dropping a file at `app/llm_context/activities.rb` would therefore resolve as the top-level constant `Activities`, not `LLMContext::Activities`. `app/llm_context/` is also already occupied: it holds the legacy markdown prompt files the new system replaces. The registry and modules therefore live under `lib/llm_context/`. `lib/` is an autoload root via `config.autoload_lib` (`config/application.rb:17`), so `lib/llm_context/activities.rb` resolves as `LLMContext::Activities`, and `lib/llm_context/activities/iron_engine.rb` as `LLMContext::Activities::IronEngine`. Shared `.md` snippets still live in `app/llm_context/shared/` — they are read with `File.read`, not autoloaded, so their location is independent of Zeitwerk.
3. **Equipment vocabulary** comes from `User::EQUIPMENT_SLUGS` (`app/models/user.rb:28`): `%w[barbell dumbbells kettlebells pull_up_bar wall_ball sled resistance_bands jump_rope rowing_machine assault_bike ski_erg treadmill]`. Every `allowed_equipment` / `banned_equipment` value used in activity contracts MUST come from this list (or `"bodyweight"`, which is implicit). Do not invent new slugs like `"rower"` or `"cardio_machines"`.
4. **Slug-direction rule.** `ACTIVITY_ALIASES` in the generator maps *display* slugs to *canonical* slugs. `LLMContext::Activities::ALIASES` in the new registry mirrors that direction (display → canonical). The registry's `MODULES` hash is keyed on canonical slugs only.

---

## File Structure

**New files:**

| Path | Responsibility |
|---|---|
| `lib/llm_context/activities.rb` | Registry: canonical-slug → activity module. Owns `ALIASES` (display-slug → canonical) and `MODULES` (canonical → module constant). |
| `lib/llm_context/activities/iron_engine.rb` | Iron Engine contract + vocab + 3 examples. `SLUG = "kettlebell"`. |
| `lib/llm_context/activities/turbine.rb` | Turbine contract + vocab + 3 examples. |
| `lib/llm_context/activities/alternator.rb` | Alternator contract + examples. Includes T&S treadmill-focus note. |
| `lib/llm_context/activities/circuit_breaker.rb` | Circuit Breaker (F45). |
| `lib/llm_context/activities/dynamo.rb` | Dynamo (HIIT bodyweight). |
| `lib/llm_context/activities/transformer.rb` | Transformer (strength). |
| `lib/llm_context/activities/ohm.rb` | Ohm (yoga/mobility). |
| `lib/llm_context/activities/hyrox.rb` | Hyrox. |
| `lib/llm_context/activities/deka.rb` | Deka parent. |
| `lib/llm_context/activities/deka_fit.rb` | Deka Fit. |
| `lib/llm_context/activities/deka_strong.rb` | Deka Strong. |
| `lib/llm_context/activities/deka_mile.rb` | Deka Mile. |
| `lib/llm_context/activities/deka_atlas.rb` | Deka Atlas. |
| `lib/llm_context/activities/volt_octathlon.rb` | Volt Octathlon. |
| `lib/llm_context/activities/functional_muscle.rb` | Functional Muscle. |
| `lib/llm_context/activities/crossfit.rb` | CrossFit. |
| `lib/llm_context/activities/general_fitness.rb` | General Fitness default. |
| `app/llm_context/shared/global_rules.md` | Global JSON/naming/rest≤work/variety rules. |
| `app/llm_context/shared/warm_up_cool_down.md` | Warm-up and cool-down style vocabulary. |
| `app/services/workout_llm_generator/contract_prompt_builder.rb` | Small PORO: takes activity module + request context, returns the XML-tagged prompt string. Keeps `WorkoutLLMGenerator` thin for the new path without doing a full service split. |
| `test/llm_context/activities_test.rb` | Registry tests: slugs resolve, aliases resolve, T&S routes to Alternator. |
| `test/llm_context/contract_integrity_test.rb` | Every activity's contract + examples satisfy the schema. |
| `test/services/workout_llm_generator/contract_prompt_builder_test.rb` | Prompt shape + regression checks. |

**Modified files:**

| Path | Change |
|---|---|
| `app/services/workout_llm_generator.rb` | Add `build_contract_prompt` dispatch (Phase 2). Delete old methods/constants (Phase 4). |

No changes needed in `config/application.rb` — `lib/` is already autoloaded via `config.autoload_lib(ignore: %w[assets tasks])`, so `lib/llm_context/**/*.rb` is picked up automatically.

**Deleted files (Phase 4):** every `app/llm_context/*.md` except `shared/*.md`.

---

## Phase 0: Pre-flight

### Task 0.1: Create the plan worktree branch and starting point

**Files:** none.

- [ ] **Step 1: Confirm current git state**

```bash
git status
git log --oneline -3
```

Expected: clean working tree or only the spec + earlier surgical-fixes staged/unstaged. If uncommitted work exists outside the spec, pause and ask.

- [ ] **Step 2: Create feature branch**

```bash
git checkout -b prompt-rewrite-contract-blocks
```

- [ ] **Step 3: Commit the spec if it is still unstaged/uncommitted**

```bash
git add docs/superpowers/specs/2026-04-19-workout-prompt-rewrite-design.md
git commit -m "spec: workout prompt rewrite — contract block architecture"
```

---

## Phase 1: Scaffolding (no behaviour change)

Zero impact on running code. Adds the registry, one activity module, the shared vocabulary files, and their tests.

### Task 1.1: Create the activities registry

**Files:**
- Create: `lib/llm_context/activities.rb`
- Create: `test/llm_context/activities_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/llm_context/activities_test.rb
require "test_helper"

class LLMContext::ActivitiesTest < ActiveSupport::TestCase
  test "resolves a display slug through to the module via aliases" do
    skip "Iron Engine module not yet defined" unless defined?(LLMContext::Activities::IronEngine)
    assert_equal LLMContext::Activities::IronEngine, LLMContext::Activities.for("iron-engine")
  end

  test "resolves the canonical slug directly" do
    skip "Iron Engine module not yet defined" unless defined?(LLMContext::Activities::IronEngine)
    assert_equal LLMContext::Activities::IronEngine, LLMContext::Activities.for("kettlebell")
  end

  test "canonical_slug collapses aliases to canonical form" do
    assert_equal "kettlebell", LLMContext::Activities.canonical_slug("iron-engine")
    assert_equal "kettlebell", LLMContext::Activities.canonical_slug("kettlebell")
  end

  test "canonical_slug is cycle-safe" do
    # Defensive — the ALIASES hash is hand-maintained; make sure a future bad entry
    # can't hang the app. canonical_slug must terminate even on a self-loop.
    LLMContext::Activities.stub_const(:ALIASES, { "a" => "b", "b" => "a" }) do
      assert_equal "a", LLMContext::Activities.canonical_slug("a") # returns first-seen value
    end
  end

  test "returns nil for an unknown slug" do
    assert_nil LLMContext::Activities.for("does-not-exist")
  end

  test "for! raises on unknown slug" do
    assert_raises(LLMContext::Activities::UnknownActivity) do
      LLMContext::Activities.for!("does-not-exist")
    end
  end
end
```

Note on `stub_const`: if the project doesn't already have a helper for this, inline it with `silence_warnings { LLMContext::Activities.const_set(:ALIASES, ...) }` plus a teardown that restores the original. Keep it simple.

- [ ] **Step 2: Run it to confirm it fails**

```bash
bin/rails test test/llm_context/activities_test.rb
```

Expected: FAIL — uninitialized constant `LLMContext::Activities`.

- [ ] **Step 3: Implement the registry**

`ALIASES` must mirror the direction of the generator's existing `ACTIVITY_ALIASES` (lines 207–242): display-slug → canonical-slug. In Phase 4 we delete `ACTIVITY_ALIASES` from the generator and this becomes the single source of truth, so port every entry — do not skip any.

```ruby
# lib/llm_context/activities.rb
module LLMContext
  module Activities
    class UnknownActivity < StandardError; end

    # Display slug → canonical slug. Mirrors the direction of
    # WorkoutLLMGenerator::ACTIVITY_ALIASES (lines 207–242, canonical form on the right).
    # Port every entry verbatim so the registry is a drop-in replacement in Phase 4.
    ALIASES = {
      "hybrid-training"     => "alternator",
      "cardio-strength"     => "alternator",
      "cardio-and-strength" => "alternator",
      "barry-s"             => "alternator",   # was "tread-shred"; T&S now routes to alternator (spec §5)
      "barry-s-bootcamp"    => "alternator",   # was "tread-shred"
      "barrys"              => "alternator",   # was "tread-shred"
      "tread-shred"         => "alternator",   # folded into alternator
      "functional-fitness"  => "circuit-breaker",
      "f45"                 => "circuit-breaker",
      "functional-workout"  => "circuit-breaker",
      "hiit"                => "dynamo",
      "meta-fit"            => "dynamo",
      "metafit"             => "dynamo",
      "strength"            => "transformer",
      "strength-training"   => "transformer",
      "pilates"             => "ohm",
      "yoga"                => "ohm",
      "mobility"            => "ohm",
      "iron-engine"         => "kettlebell",
      "sunday-workout"      => "functional-muscle",
      "maximum-voltage"     => "functional-muscle",
      "cardio"              => "turbine",
      "pure-cardio"         => "turbine",
      "cardio-session"      => "turbine",
      "cardio-only"         => "turbine",
      "full-body-training"  => "general-fitness"
    }.freeze

    # Canonical slug (as stored in the DB and seen in @activity_slug at runtime)
    # → module constant under LLMContext::Activities.
    MODULES = {
      "kettlebell"        => :IronEngine,
      "turbine"           => :Turbine,
      "alternator"        => :Alternator,
      "circuit-breaker"   => :CircuitBreaker,
      "dynamo"            => :Dynamo,
      "transformer"       => :Transformer,
      "ohm"               => :Ohm,
      "hyrox"             => :Hyrox,
      "deka"              => :Deka,
      "deka-fit"          => :DekaFit,
      "deka-strong"       => :DekaStrong,
      "deka-mile"         => :DekaMile,
      "deka-atlas"        => :DekaAtlas,
      "volt-octathlon"    => :VoltOctathlon,
      "functional-muscle" => :FunctionalMuscle,
      "crossfit"          => :CrossFit,
      "general-fitness"   => :GeneralFitness
    }.freeze

    # One-hop resolution. The current ALIASES set has no chains; keep it flat on
    # purpose so a future buggy edit that introduces a cycle can't hang callers.
    def self.canonical_slug(slug)
      s = slug.to_s
      ALIASES.fetch(s, s)
    end

    def self.for(slug)
      constant = MODULES[canonical_slug(slug)]
      return nil unless constant
      return nil unless const_defined?(constant)
      const_get(constant)
    end

    def self.for!(slug)
      self.for(slug) || raise(UnknownActivity, "no activity module for slug #{slug.inspect}")
    end
  end
end
```

- [ ] **Step 4: Run the test**

```bash
bin/rails test test/llm_context/activities_test.rb
```

Expected: unknown-slug + `canonical_slug` + cycle-safety tests pass; the two Iron Engine tests skip until Task 1.2.

- [ ] **Step 5: Commit**

```bash
git add lib/llm_context/activities.rb test/llm_context/activities_test.rb
git commit -m "feat(llm_context): add Activities registry with slug/alias resolution"
```

### Task 1.2: Create Iron Engine activity module

**Files:**
- Create: `lib/llm_context/activities/iron_engine.rb`

- [ ] **Step 1: Write the failing contract integrity test file**

```ruby
# test/llm_context/contract_integrity_test.rb
require "test_helper"

class LLMContext::ContractIntegrityTest < ActiveSupport::TestCase
  REQUIRED_CONTRACT_KEYS = %i[
    purity allowed_equipment banned_equipment allowed_formats primary_formats
    warm_up cool_down finisher core
  ].freeze

  WARM_UP_KEYS = %i[easy_cardio kb_activation bodyweight_activation flow].freeze
  COOL_DOWN_KEYS = %i[full_body_stretch lower_focus upper_focus savasana].freeze
  FINISHER_VALUES = %i[optional required forbidden].freeze
  CORE_VALUES = %i[optional required never].freeze

  # Allowed equipment terms. Every value used in allowed_equipment/banned_equipment
  # must come from User::EQUIPMENT_SLUGS — OR be the implicit "bodyweight" token.
  VALID_EQUIPMENT_TERMS = (User::EQUIPMENT_SLUGS + %w[bodyweight]).freeze

  def assert_activity_valid(mod)
    contract = mod::CONTRACT
    REQUIRED_CONTRACT_KEYS.each do |k|
      assert contract.key?(k), "#{mod}::CONTRACT missing key #{k}"
    end

    assert_includes WARM_UP_KEYS, contract[:warm_up], "#{mod}: warm_up key not in shared vocabulary"
    assert_includes COOL_DOWN_KEYS, contract[:cool_down], "#{mod}: cool_down key not in shared vocabulary"
    assert_includes FINISHER_VALUES, contract[:finisher], "#{mod}: finisher must be optional/required/forbidden"
    assert_includes CORE_VALUES, contract[:core], "#{mod}: core must be optional/required/never"

    # Vocabulary check — both allowed and banned must use canonical equipment slugs
    # so profile composition in the generator can line up.
    (Array(contract[:allowed_equipment]) + Array(contract[:banned_equipment])).each do |term|
      assert_includes VALID_EQUIPMENT_TERMS, term,
        "#{mod}: equipment term #{term.inspect} is not a User::EQUIPMENT_SLUG or 'bodyweight'"
    end

    examples = mod::EXAMPLES
    assert_equal 3, examples.length, "#{mod}: need exactly 3 EXAMPLES"
    examples.each_with_index do |ex, i|
      assert ex[:name].present?, "#{mod}: example #{i} missing :name"
      assert ex[:goal].present?, "#{mod}: example #{i} missing :goal"
      assert ex[:duration_mins].is_a?(Integer), "#{mod}: example #{i} missing :duration_mins"
      sections = Array(ex[:sections])
      assert sections.length >= 3, "#{mod}: example #{i} needs warm-up + main + cool-down"
      assert_match(/warm/i, sections.first[:name].to_s, "#{mod}: example #{i} first section must be warm-up")
      assert_match(/cool/i, sections.last[:name].to_s,  "#{mod}: example #{i} last section must be cool-down")
    end

    banned   = Array(contract[:banned_equipment])
    allowed  = Array(contract[:allowed_equipment]) + %w[bodyweight]
    patterns = Array(contract[:banned_exercise_patterns])

    examples.each_with_index do |ex, i|
      ex[:sections].each do |section|
        next if section[:name].to_s.match?(/warm|cool/i) # warm/cool-down gets latitude
        Array(section[:exercises]).each do |exercise|
          equipment = exercise[:equipment]
          if equipment
            # CATEGORY CHECK (spec testing §1, part 1): positive + negative.
            assert_not_includes banned,  equipment.to_s,
              "#{mod}: example #{i} section #{section[:name].inspect} uses banned equipment #{equipment}"
            assert_includes     allowed, equipment.to_s,
              "#{mod}: example #{i} section #{section[:name].inspect} uses equipment #{equipment.inspect} that is not in allowed_equipment"
          end
          # NAME-PATTERN CHECK (spec testing §1, part 2).
          patterns.each do |pattern|
            refute_match pattern, exercise[:name].to_s,
              "#{mod}: example #{i} exercise name #{exercise[:name].inspect} matches banned pattern #{pattern.inspect}"
          end
        end
      end
    end
  end

  test "Iron Engine contract is valid" do
    assert_activity_valid(LLMContext::Activities::IronEngine)
  end
end
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
bin/rails test test/llm_context/contract_integrity_test.rb
```

Expected: FAIL — uninitialized constant `LLMContext::Activities::IronEngine`.

- [ ] **Step 3: Write the module**

All equipment slugs below come from `User::EQUIPMENT_SLUGS` (`app/models/user.rb:28`): `barbell`, `dumbbells`, `kettlebells`, `pull_up_bar`, `wall_ball`, `sled`, `resistance_bands`, `jump_rope`, `rowing_machine`, `assault_bike`, `ski_erg`, `treadmill`. The canonical DB slug for Iron Engine is `"kettlebell"` (not `"iron-engine"`).

Create `lib/llm_context/activities/iron_engine.rb`:

```ruby
module LLMContext
  module Activities
    module IronEngine
      SLUG = "kettlebell"
      NAME = "Iron Engine"

      CONTRACT = {
        purity: "KETTLEBELL ONLY. Every main and finisher exercise must use a kettlebell. " \
                "No cardio machines, barbells, dumbbells, bodyweight conditioning, or jump rope " \
                "in main sections. Warm-up is KB + activation only.",
        allowed_equipment: %w[kettlebells],
        banned_equipment:  %w[barbell dumbbells assault_bike rowing_machine treadmill ski_erg jump_rope sled wall_ball],
        banned_exercise_patterns: [
          /\bassault bike\b/i, /\becho bike\b/i, /\btreadmill\b/i,
          /\brower?\b/i, /\bski erg\b/i, /\bjump ?rope\b/i, /\bbarbell\b/i, /\bdumbbell\b/i
        ].freeze,
        allowed_formats:   %w[rounds emom for_time amrap ladder tabata hundred mountain],
        primary_formats:   %w[rounds emom for_time amrap],
        signature_formats: %w[complex flow carry],
        warm_up:           :kb_activation,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :never,
        notes: "Complexes, flows, and carries are Iron Engine's signature formats — " \
               "at least one should appear in most sessions."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Ballistic: KB Swing, KB Snatch, KB Clean, KB Long Cycle, Double KB Swing, KB SDHP
        Grind:    KB Goblet Squat, KB Front Squat, KB Press, KB Push Press, KB Row, KB Deadlift, KB Windmill, KB TGU
        Complex:  Clean → Press → Front Squat → Row → Swing (and similar chained flows)
        Carry:    KB Farmer's Carry, KB Rack Carry, KB Overhead Carry, KB Waiter Walk
      VOCAB

      EXAMPLES = [
        {
          name: "The Blacksmith",
          goal: "Forge strength under load with heavy grinds bookended by ballistic bursts.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up",  format: "straight", duration_mins: 5,
              exercises: [ { name: "KB activation flow (halos, goblet squats, light swings)", duration_s: 300, equipment: "kettlebells" } ] },
            { name: "Grind Ladder", format: "ladder", rest_secs: 60,
              exercises: [
                { name: "KB Front Squat", reps: "5-4-3-2-1", equipment: "kettlebells" },
                { name: "KB Press",       reps: "5-4-3-2-1", equipment: "kettlebells" }
              ] },
            { name: "Ballistic Finisher", format: "emom", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Swing",  reps: 15, equipment: "kettlebells" },
                { name: "KB Snatch", reps: "5/side", equipment: "kettlebells" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Iron Flow",
          goal: "Chain movements into one continuous signature complex.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "KB activation (halos, goblet squats, deadlifts)", duration_s: 180, equipment: "kettlebells" } ] },
            { name: "The Complex", format: "complex", rest_secs: 90,
              exercises: [ { name: "KB Clean → Press → Front Squat → Row → Swing", reps: "6 rounds", equipment: "kettlebells" } ] },
            { name: "Carry Finisher", format: "for_time", rest_secs: 0,
              exercises: [ { name: "KB Farmer's Carry", reps: "4 x 40m", equipment: "kettlebells" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Anvil",
          goal: "Short, dense kettlebell hit — ballistic power with carry grit.",
          duration_mins: 25,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "KB activation", duration_s: 180, equipment: "kettlebells" } ] },
            { name: "Ballistic AMRAP", format: "amrap", duration_mins: 10, rest_secs: 0,
              exercises: [
                { name: "KB Swing",    reps: 20, equipment: "kettlebells" },
                { name: "Goblet Squat", reps: 10, equipment: "kettlebells" }
              ] },
            { name: "Carry Finisher", format: "for_time", rest_secs: 0,
              exercises: [ { name: "KB Rack Carry", reps: "3 x 30m", equipment: "kettlebells" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
```

- [ ] **Step 4: Run the contract integrity test**

```bash
bin/rails test test/llm_context/contract_integrity_test.rb
bin/rails test test/llm_context/activities_test.rb
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/llm_context/activities.rb \
        lib/llm_context/activities/iron_engine.rb \
        test/llm_context/activities_test.rb \
        test/llm_context/contract_integrity_test.rb
git commit -m "feat(llm_context): scaffold Iron Engine contract + vocabulary + 3 examples"
```

### Task 1.3: Add shared global_rules and warm_up_cool_down vocabulary

**Files:**
- Create: `app/llm_context/shared/global_rules.md`
- Create: `app/llm_context/shared/warm_up_cool_down.md`

- [ ] **Step 1: Write `global_rules.md`**

```markdown
# Global rules (every workout)

- `rest_secs` must never exceed the working duration of any set. Rest ≤ work, always. (Tabata rest is the fixed 10s work / 20s rest pattern — it does not count against this rule.)
- At least three different section formats across the session. No two adjacent sections share a format.
- Exercise `name` fields contain the movement only — no embedded reps, durations, loads, or descriptors. Reps and durations go in their own fields.
- Rep counts use clean numbers: even numbers or multiples of 5. Avoid 7, 11, 13, etc.
- Give the workout a punchy, memorable, original name. Do not use gym-brand words (Barry's, F45, CrossFit, Hyrox, Deka, Tread & Shred, Metafit) in the name.
- The `goal` field is one short motivational sentence about energy and training effect — not a description of the workout's structure.
```

- [ ] **Step 2: Write `warm_up_cool_down.md`**

```markdown
# Shared warm-up and cool-down vocabulary

Warm-up length: 3 min for sessions of 30 min or less, 5 min otherwise.
Cool-down length: 2 min for short sessions, 5 min otherwise.
Warm-up content defaults to easy cardio + a single exercise named "Dynamic stretches". Do not list individual stretches.
Cool-down notes: 5 deep breaths for short sessions, 10 for long sessions.

## Warm-up styles

- `:easy_cardio` — Easy cardio at conversational pace + dynamic stretches. Pick a different machine from the main session's machine where possible.
- `:kb_activation` — Kettlebell halos, light swings, and goblet squats + dynamic stretches. No cardio machines ever.
- `:bodyweight_activation` — Easy bodyweight cardio + dynamic stretches. No equipment.
- `:flow` — Yoga/pilates activation flow, delivered as part of the main session content rather than a distinct warm-up block.

## Cool-down styles

- `:full_body_stretch` — Dynamic stretches covering hips, hamstrings, chest, shoulders, and spine. Default.
- `:lower_focus` — Hip flexors, pigeon, quads, hamstrings, spinal twist.
- `:upper_focus` — Chest opener, cross-body shoulder, thread the needle, lat stretch.
- `:savasana` — Longer holds, quiet. For Ohm.
```

- [ ] **Step 3: Commit**

```bash
git add app/llm_context/shared/global_rules.md app/llm_context/shared/warm_up_cool_down.md
git commit -m "feat(llm_context): add shared global_rules and warm_up_cool_down vocabulary"
```

---

## Phase 2: Iron Engine cutover (dual-path behind env flag)

Adds `ContractPromptBuilder`, routes Iron Engine through it when `WORKOUT_PROMPT_CONTRACT_ACTIVITIES` includes `iron-engine`. Leaves everything else untouched.

### Task 2.1: Build ContractPromptBuilder PORO with shape tests

**Files:**
- Create: `app/services/workout_llm_generator/contract_prompt_builder.rb`
- Create: `test/services/workout_llm_generator/contract_prompt_builder_test.rb`

- [ ] **Step 1: Write the failing prompt-shape test**

```ruby
# test/services/workout_llm_generator/contract_prompt_builder_test.rb
require "test_helper"

class WorkoutLLMGenerator::ContractPromptBuilderTest < ActiveSupport::TestCase
  def build(activity_slug: "kettlebell", duration_mins: 45, athlete: "test athlete", session_notes: nil, banned_override: [])
    WorkoutLLMGenerator::ContractPromptBuilder.new(
      activity: LLMContext::Activities.for!(activity_slug),
      duration_mins: duration_mins,
      athlete_block: athlete,
      session_notes: session_notes,
      banned_equipment_override: banned_override
    ).build
  end

  test "contains all required XML tags in order" do
    prompt = build
    expected_order = %w[<role> <athlete> <task> <contract> <global_rules> <session_shape> <examples>]
    positions = expected_order.map { |tag| prompt.index(tag) }
    assert positions.none?(&:nil?), "missing tags: #{expected_order.zip(positions).reject { |_, p| p }.map(&:first)}"
    assert_equal positions, positions.sort, "tags must appear in order"
  end

  test "omits session_notes tag when no notes given" do
    refute_includes build, "<session_notes>"
  end

  test "includes session_notes tag when notes given" do
    assert_includes build(session_notes: "no running please"), "<session_notes>"
  end

  test "iron-engine prompt includes KETTLEBELL ONLY purity statement" do
    assert_includes build, "KETTLEBELL ONLY"
  end

  test "iron-engine prompt does not mention cardio machines as allowed or in examples" do
    # Note: the contract's BANNED EQUIPMENT line intentionally lists "treadmill" etc.
    # to tell the LLM what NOT to use — that's correct behaviour, not bleed. The
    # bleed we care about is cardio machines appearing as allowed equipment or as
    # an exercise inside an example.
    prompt = build
    allowed_line = prompt[/ALLOWED EQUIPMENT:([^\n]+)/, 1]
    refute_nil allowed_line
    refute_match(/treadmill|assault.?bike|rower|ski.?erg/i, allowed_line)

    examples_block = prompt[/<examples>(.*?)<\/examples>/m, 1]
    refute_nil examples_block
    refute_match(/"equipment"\s*:\s*"(treadmill|assault_bike|rowing_machine|ski_erg)"/, examples_block)
    refute_match(/"name"\s*:\s*"[^"]*(treadmill|assault bike|rower|ski erg)/i, examples_block)
  end

  test "examples tag contains three serialised workouts" do
    prompt = build
    examples_block = prompt[/\<examples\>(.*?)\<\/examples\>/m, 1]
    refute_nil examples_block
    # Count `"goal":` — it appears exactly once per example (sections/exercises
    # don't have a goal field). `"name"` would over-count because sections and
    # exercises both carry a name.
    assert_equal 3, examples_block.scan(/"goal"\s*:/).length
  end

  test "global_rules block contains the rest-work rule" do
    assert_match(/rest.*never.*exceed/i, build[/\<global_rules\>(.*?)\<\/global_rules\>/m, 1])
  end

  test "banned_equipment_override merges into contract banned list" do
    prompt = build(banned_override: %w[pull_up_bar])
    banned = prompt[/BANNED EQUIPMENT:([^\n]+)/, 1]
    refute_nil banned
    assert_includes banned, "pull_up_bar"
  end
end
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb
```

Expected: FAIL — uninitialized constant.

- [ ] **Step 3: Implement the builder**

Create `app/services/workout_llm_generator/contract_prompt_builder.rb`:

```ruby
class WorkoutLLMGenerator
  class ContractPromptBuilder
    ROLE_TEXT = "You are an expert personal trainer who writes creative, effective gym workouts."

    WARM_UP_VOCAB = {
      easy_cardio:            "Easy cardio at conversational pace plus \"Dynamic stretches\". Do not list individual stretches.",
      kb_activation:          "Kettlebell halos, light swings, and goblet squats plus \"Dynamic stretches\". No cardio machines.",
      bodyweight_activation:  "Easy bodyweight cardio plus \"Dynamic stretches\". No equipment.",
      flow:                   "Yoga/pilates activation flow woven into the main session."
    }.freeze

    COOL_DOWN_VOCAB = {
      full_body_stretch: "Dynamic stretches covering hips, hamstrings, chest, shoulders, spine.",
      lower_focus:       "Hip flexors, pigeon, quads, hamstrings, spinal twist.",
      upper_focus:       "Chest opener, cross-body shoulder, thread the needle, lat stretch.",
      savasana:          "Longer holds, quiet."
    }.freeze

    GLOBAL_RULES = <<~RULES.strip.freeze
      - rest_secs must never exceed the working duration of any set (tabata's 10s/20s pattern is the only exception).
      - At least 3 different section formats across the session. No two adjacent sections share a format.
      - Exercise `name` fields contain the movement only — no reps, durations, loads, or descriptors.
      - Rep counts are clean numbers (even or multiples of 5).
      - Workout name: punchy, memorable, original. Banned words: Barry's, F45, CrossFit, Hyrox, Deka, Tread & Shred, Metafit.
      - `goal` is one motivational sentence about energy and training effect.
    RULES

    def initialize(activity:, duration_mins:, athlete_block:, session_notes: nil, banned_equipment_override: [], contract_override: nil)
      @activity = activity
      @duration_mins = duration_mins
      @athlete_block = athlete_block
      @session_notes = session_notes
      @banned_override = Array(banned_equipment_override)
      @contract_override = contract_override
    end

    def build
      tags = []
      tags << xml(:role, ROLE_TEXT)
      tags << xml(:athlete, @athlete_block)
      tags << xml(:task, "Generate a #{@duration_mins}-minute #{@activity::NAME} session.")
      tags << xml(:contract, contract_block)
      tags << xml(:global_rules, GLOBAL_RULES)
      tags << xml(:session_shape, session_shape_block)
      tags << xml(:examples, examples_block)
      tags << xml(:session_notes, @session_notes) if @session_notes.present?
      tags.join("\n\n")
    end

    private

    def contract
      @contract_override || @activity::CONTRACT
    end

    def banned_equipment
      (Array(contract[:banned_equipment]) + @banned_override).uniq
    end

    def contract_block
      vocab = defined?(@activity::MOVEMENT_VOCABULARY) ? @activity::MOVEMENT_VOCABULARY : nil
      lines = []
      lines << "Activity: #{@activity::NAME} (#{@activity::SLUG})"
      lines << ""
      lines << "PURITY: #{contract[:purity]}"
      lines << "ALLOWED EQUIPMENT: #{Array(contract[:allowed_equipment]).join(', ')}"
      lines << "BANNED EQUIPMENT: #{banned_equipment.join(', ')}"
      lines << "ALLOWED FORMATS: #{Array(contract[:allowed_formats]).join(', ')}"
      lines << "PRIMARY FORMATS: #{Array(contract[:primary_formats]).join(', ')}"
      if contract[:signature_formats].present?
        lines << "SIGNATURE FORMATS (use at least one in most sessions): #{Array(contract[:signature_formats]).join(', ')}"
      end
      lines << "WARM-UP STYLE: #{WARM_UP_VOCAB.fetch(contract[:warm_up])}"
      lines << "COOL-DOWN STYLE: #{COOL_DOWN_VOCAB.fetch(contract[:cool_down])}"
      lines << "FINISHER: #{contract[:finisher]}"
      lines << "CORE SECTION: #{contract[:core]}"
      if vocab
        lines << ""
        lines << "Movement vocabulary:"
        lines << vocab.strip
      end
      if contract[:notes].present?
        lines << ""
        lines << contract[:notes]
      end
      lines.join("\n")
    end

    def session_shape_block
      warm_up_min = @duration_mins <= 30 ? 3 : 5
      cool_down_min = @duration_mins <= 30 ? 2 : 5
      working = @duration_mins - warm_up_min - cool_down_min
      <<~SHAPE.strip
        Warm-up (#{warm_up_min} min) → main sections → Cool-down (#{cool_down_min} min).
        Working time: #{working} min. Do NOT set duration_mins on main sets.
      SHAPE
    end

    def examples_block
      json = JSON.pretty_generate(@activity::EXAMPLES.map { |ex| ex.deep_stringify_keys })
      <<~EX.strip
        Three #{@activity::NAME} workouts that show the quality bar and style. Study structure,
        exercise selection, format variety, and naming. Create something fresh in the same
        spirit — do not copy.

        #{json}
      EX
    end

    def xml(tag, body)
      "<#{tag}>\n#{body.to_s.strip}\n</#{tag}>"
    end
  end
end
```

- [ ] **Step 4: Run the test**

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/workout_llm_generator/contract_prompt_builder.rb \
        test/services/workout_llm_generator/contract_prompt_builder_test.rb
git commit -m "feat(workout_llm_generator): add ContractPromptBuilder PORO for new prompt path"
```

### Task 2.2: Route Iron Engine through the new builder behind an env flag

**Files:**
- Modify: `app/services/workout_llm_generator.rb` (method `generate_data` at line 561–578; add a new private method)

- [ ] **Step 1: Write the failing routing test**

Append to `test/services/workout_llm_generator/contract_prompt_builder_test.rb`:

```ruby
class WorkoutLLMGenerator::RoutingTest < ActiveSupport::TestCase
  setup do
    @original = ENV["WORKOUT_PROMPT_CONTRACT_ACTIVITIES"]
  end

  teardown do
    ENV["WORKOUT_PROMPT_CONTRACT_ACTIVITIES"] = @original
  end

  # @activity_slug at runtime is the canonical slug ("kettlebell" for Iron Engine),
  # because WorkoutLLMGenerator#initialize normalises display slugs through
  # ACTIVITY_ALIASES before storing. Set it to "kettlebell" in these tests.

  test "contract_path? returns true when canonical slug is enabled directly" do
    ENV["WORKOUT_PROMPT_CONTRACT_ACTIVITIES"] = "kettlebell,turbine"
    gen = WorkoutLLMGenerator.allocate
    gen.instance_variable_set(:@activity_slug, "kettlebell")
    assert gen.send(:contract_path?)
  end

  test "contract_path? returns true when the flag uses a display slug that aliases to the canonical" do
    ENV["WORKOUT_PROMPT_CONTRACT_ACTIVITIES"] = "iron-engine"
    gen = WorkoutLLMGenerator.allocate
    gen.instance_variable_set(:@activity_slug, "kettlebell")
    assert gen.send(:contract_path?)
  end

  test "contract_path? returns false when slug missing from flag" do
    ENV["WORKOUT_PROMPT_CONTRACT_ACTIVITIES"] = "turbine"
    gen = WorkoutLLMGenerator.allocate
    gen.instance_variable_set(:@activity_slug, "kettlebell")
    refute gen.send(:contract_path?)
  end

  test "contract_path? returns false when env flag unset" do
    ENV.delete("WORKOUT_PROMPT_CONTRACT_ACTIVITIES")
    gen = WorkoutLLMGenerator.allocate
    gen.instance_variable_set(:@activity_slug, "kettlebell")
    refute gen.send(:contract_path?)
  end
end
```

- [ ] **Step 2: Run to confirm it fails**

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb
```

Expected: FAIL — `contract_path?` not defined.

- [ ] **Step 3: Add `contract_path?`, `build_contract_prompt`, and routing**

The remix branch (`if @source_workout` at line 562) is untouched — `build_remix_prompt` keeps working as-is through Phase 4. Only the non-remix `else` branch changes.

In `app/services/workout_llm_generator.rb`, modify `generate_data` around lines 568–576 so the non-remix branch becomes:

```ruby
else
  if contract_path?
    prompt           = build_contract_prompt
    log_prompt_path(:contract, prompt)
    workout_data     = call_llm(prompt)
  else
    example_workouts = fetch_top_liked_examples
    prompt           = build_example_prompt(example_workouts)
    log_prompt_path(:example, prompt)
    workout_data     = call_llm(prompt)
  end
  workout_data = validate_and_fix(workout_data)
  workout_data = collapse_duplicate_exercises(workout_data)
  workout_data = fm_enforce_blocks(workout_data)
  workout_data = general_enforce_formats(workout_data)
  collapse_set_notation(workout_data)
end
```

Then add the three new private methods near the bottom of the class (above `call_llm`):

```ruby
def contract_path?
  enabled = ENV["WORKOUT_PROMPT_CONTRACT_ACTIVITIES"].to_s.split(",").map(&:strip)
  return false if enabled.empty?
  # Accept either direction — user may set the env var to the display slug they
  # know ("iron-engine") or the canonical slug stored on the record ("kettlebell").
  # canonical_slug normalises display slugs; we also check the raw @activity_slug
  # for the case where someone opts in by canonical form.
  canonical = LLMContext::Activities.canonical_slug(@activity_slug)
  enabled_canonicals = enabled.map { |s| LLMContext::Activities.canonical_slug(s) }
  enabled_canonicals.include?(canonical)
end

def build_contract_prompt
  activity = LLMContext::Activities.for!(@activity_slug)
  ContractPromptBuilder.new(
    activity:                  activity,
    duration_mins:             @duration_mins,
    athlete_block:             build_athlete_block_for_contract,
    session_notes:             sanitized_session_notes,
    banned_equipment_override: profile_banned_equipment + session_note_banned_equipment
  ).build
end

def log_prompt_path(path, prompt)
  Rails.logger.info(
    "[workout_llm_generator] activity=#{@activity_slug} " \
    "path=#{path} " \
    "prompt_chars=#{prompt.length} " \
    "prompt_tokens_est=#{(prompt.length / 4.0).round}"
  )
end
```

Three small helpers plumb existing behaviour into contract-friendly shape. Each reuses code that already exists in `workout_llm_generator.rb` — no new logic, only extraction. Cite the source line in a short comment on each so future readers can find the origin if behaviour drifts.

```ruby
# Reuses build_user_context (line 2343) which already produces the athlete section
# used inside build_example_prompt. No new logic — just a clear entry point.
def build_athlete_block_for_contract
  build_user_context.to_s.strip
end

# Mirrors build_profile_equipment_rule (line 1216) but returns canonical slugs,
# not prose. Only limits when the user profile is a genuine constraint — same
# guard as build_equipment_rule (line 1240).
def profile_banned_equipment
  return [] unless @equipment.present? && (User::EQUIPMENT_SLUGS - @equipment).any?
  (User::EQUIPMENT_SLUGS - @equipment)
end

# Session-note behaviour flags that translate into equipment bans.
# no_run?, no_core?, race_simulation? already exist (lines 1362–1372).
def session_note_banned_equipment
  banned = []
  banned << "treadmill" if no_run?
  banned
end
```

`no_core?` and `race_simulation?` are read by `build_contract_prompt` itself (not added as equipment bans) — they flip `CORE` and `FINISHER` on the contract copy before it goes into the prompt. Extend `build_contract_prompt` as follows to apply them:

```ruby
def build_contract_prompt
  activity = LLMContext::Activities.for!(@activity_slug)
  contract = activity::CONTRACT.dup
  contract[:core]     = :never    if no_core?
  contract[:finisher] = :required if race_simulation?
  ContractPromptBuilder.new(
    activity:                  activity,
    duration_mins:             @duration_mins,
    athlete_block:             build_athlete_block_for_contract,
    session_notes:             sanitized_session_notes,
    banned_equipment_override: profile_banned_equipment + session_note_banned_equipment,
    contract_override:         contract
  ).build
end
```

`ContractPromptBuilder#initialize` grows a `contract_override:` keyword that defaults to `nil`; when present, the builder uses it in place of `@activity::CONTRACT`. Add the corresponding test case to `contract_prompt_builder_test.rb`:

```ruby
test "contract_override replaces the activity contract" do
  activity = LLMContext::Activities.for!("kettlebell")
  override = activity::CONTRACT.merge(finisher: :required, core: :never)
  prompt = WorkoutLLMGenerator::ContractPromptBuilder.new(
    activity: activity, duration_mins: 45, athlete_block: "x",
    contract_override: override
  ).build
  assert_match(/FINISHER: required/, prompt)
  assert_match(/CORE SECTION: never/, prompt)
end
```

`sanitized_session_notes` should already exist as the input-sanitisation helper used by the legacy prompt path; if it doesn't, add a one-liner: `def sanitized_session_notes; @session_notes.to_s.gsub(/<[^>]+>/, "").strip.presence; end`.

- [ ] **Step 4: Run the routing tests and the whole validator + builder suite**

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb \
              test/services/workout_validator_test.rb \
              test/llm_context
```

Expected: all pass.

- [ ] **Step 5: Smoke-check with the env flag off (regression guard)**

```bash
bin/rails test test/services
```

Expected: every existing test still passes — the `else` branch must behave exactly as before when the flag is unset.

- [ ] **Step 6: Commit**

```bash
git add app/services/workout_llm_generator.rb \
        test/services/workout_llm_generator/contract_prompt_builder_test.rb
git commit -m "feat(workout_llm_generator): route Iron Engine through contract prompt behind env flag"
```

### Task 2.3: Manual staging check

**Files:** none.

- [ ] **Step 1: Enable the flag locally**

```bash
export WORKOUT_PROMPT_CONTRACT_ACTIVITIES=kettlebell
bin/rails console
```

(Either `kettlebell` or `iron-engine` works; `contract_path?` normalises through `canonical_slug`. Using the canonical form is clearer.)

- [ ] **Step 2: Generate three Iron Engine workouts at 30, 45, 60 minutes**

In the console, call your preferred generation entry point for a test user with three durations. Copy each generated workout.

- [ ] **Step 3: Eyeball for bleed**

Look for:
- Any cardio-machine exercises in main sections (MUST NOT appear).
- Running tabata finishers (MUST NOT appear).
- Sprint ratios where rest exceeds work (MUST NOT appear).
- Signature formats (complex / flow / carry) present in at least two of three.
- Warm-up uses "Dynamic stretches" as the exercise name.

- [ ] **Step 4: If bleed appears, return to Task 2.1 and tighten the contract block prose**

Before going wider, the contract shape must be trustworthy on Iron Engine. Do not start Phase 3 with known bleed.

- [ ] **Step 5: Turn the flag off again**

```bash
unset WORKOUT_PROMPT_CONTRACT_ACTIVITIES
```

- [ ] **Step 6: Commit any tuning you made**

```bash
git add -A
git commit -m "tune(iron_engine): adjust contract prose after staging check"
```

---

## Phase 3: Fill out remaining activity files

Order matters. Purity-sensitive activities go first because bleed is most visible there.

### Task 3.1: Author Turbine

**Files:**
- Create: `lib/llm_context/activities/turbine.rb`
- Modify: `test/llm_context/contract_integrity_test.rb` (add `test "Turbine contract is valid"`)

- [ ] **Step 1: Add the contract-integrity test for Turbine**

```ruby
test "Turbine contract is valid" do
  assert_activity_valid(LLMContext::Activities::Turbine)
end
```

- [ ] **Step 2: Run to confirm fail**

```bash
bin/rails test test/llm_context/contract_integrity_test.rb -n /Turbine/
```

- [ ] **Step 3: Write `lib/llm_context/activities/turbine.rb`**

Use `User::EQUIPMENT_SLUGS` vocabulary. Source material: the existing Turbine block in `FORMAT_AFFINITY["turbine"]` (line 388+ of the generator) and any Turbine-specific guidance in `WorkoutLLMGenerator` around lines 1407 and 2285.

```ruby
module LLMContext
  module Activities
    module Turbine
      SLUG = "turbine"
      NAME = "Turbine"

      CONTRACT = {
        purity: "PURE CARDIO. The only equipment allowed in main sections is the four " \
                "cardio machines: treadmill, rowing machine, ski erg, assault bike. " \
                "No resistance training, no kettlebell work, no bodyweight conditioning.",
        allowed_equipment: %w[treadmill rowing_machine ski_erg assault_bike],
        banned_equipment:  %w[barbell dumbbells kettlebells pull_up_bar wall_ball sled resistance_bands jump_rope],
        banned_exercise_patterns: [
          /\bsquat\b/i, /\bdeadlift\b/i, /\bpress\b/i, /\bcurl\b/i,
          /\bkettlebell\b/i, /\bdumbbell\b/i, /\bbarbell\b/i, /\bburpee\b/i,
          /\bpush[- ]?up\b/i, /\bsit[- ]?up\b/i
        ].freeze,
        allowed_formats:   %w[rounds emom for_time amrap ladder tabata],
        primary_formats:   %w[rounds emom for_time tabata],
        warm_up:           :easy_cardio,
        cool_down:         :full_body_stretch,
        finisher:          :optional,
        core:              :never,
        notes: "Never finish with a treadmill tabata (historical bug). Sprint intervals " \
               "use only 20s/10s, 20s/20s, 30s/15s, 30s/30s — rest never exceeds work. " \
               "Rotate machines across sections; do not use the same machine twice in a row."
      }.freeze

      MOVEMENT_VOCABULARY = <<~VOCAB.freeze
        Steady state: Row @ 2:10 pace, Ski Erg @ 2:15 pace, Easy jog, Zone 2 bike
        Threshold:    Row @ 1:55 pace, 7 mph run, Moderate bike
        VO2:          1:45 row pace, 10 mph run, Hard bike
        Sprint:       20–30s all-out efforts on any machine with equal-or-shorter rest
      VOCAB

      EXAMPLES = [
        {
          name: "Three-Way Pull",
          goal: "Rotate through the three pulling machines at threshold with short rest.",
          duration_mins: 30,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "assault_bike" } ] },
            { name: "Machine Rotation", format: "rounds", rest_secs: 30,
              exercises: [
                { name: "Row",      duration_s: 300, equipment: "rowing_machine" },
                { name: "Ski Erg",  duration_s: 300, equipment: "ski_erg" },
                { name: "Assault Bike", duration_s: 300, equipment: "assault_bike" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        },
        {
          name: "Pyramid Intervals",
          goal: "Build and shed intensity with a clean sprint pyramid — rest ≤ work always.",
          duration_mins: 45,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 5,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 300, equipment: "rowing_machine" } ] },
            { name: "Sprint Pyramid", format: "emom", duration_mins: 20, rest_secs: 0,
              exercises: [
                { name: "Row sprint",       duration_s: 20, notes: "work 20s, rest 10s" },
                { name: "Row moderate",     duration_s: 30, notes: "work 30s, rest 30s" },
                { name: "Ski Erg sprint",   duration_s: 30, notes: "work 30s, rest 15s" }
              ] },
            { name: "Steady Finisher", format: "for_time",
              exercises: [ { name: "Run", reps: "1.5 km", equipment: "treadmill" } ] },
            { name: "Cool-Down", format: "straight", duration_mins: 5,
              exercises: [ { name: "Dynamic stretches", notes: "10 deep breaths" } ] }
          ]
        },
        {
          name: "Short Engine",
          goal: "A fast, dense 20-minute cardio hit with no treadmill finish.",
          duration_mins: 20,
          sections: [
            { name: "Warm-Up", format: "straight", duration_mins: 3,
              exercises: [ { name: "Easy cardio + Dynamic stretches", duration_s: 180, equipment: "ski_erg" } ] },
            { name: "Sprint Rounds", format: "rounds", rest_secs: 20,
              exercises: [
                { name: "Assault Bike sprint", duration_s: 20, equipment: "assault_bike" },
                { name: "Row moderate",         duration_s: 40, equipment: "rowing_machine" }
              ] },
            { name: "Cool-Down", format: "straight", duration_mins: 2,
              exercises: [ { name: "Dynamic stretches", notes: "5 deep breaths" } ] }
          ]
        }
      ].freeze
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
bin/rails test test/llm_context/
```

- [ ] **Step 5: Enable Turbine through the env flag locally and eyeball 3 generations**

```bash
export WORKOUT_PROMPT_CONTRACT_ACTIVITIES=kettlebell,turbine
```

- [ ] **Step 6: Commit**

```bash
git add lib/llm_context/activities/turbine.rb test/llm_context/contract_integrity_test.rb
git commit -m "feat(llm_context): add Turbine contract + vocabulary + 3 examples"
```

### Task 3.2: Author Ohm

Ohm is the second exemplar because it has the most unusual contract — warm-up is the session, cool-down is savasana. Follow the Iron Engine/Turbine shape with these differences:

- `SLUG = "ohm"`, `NAME = "Ohm"`.
- `purity`: yoga / pilates / mobility. No machines, no weights, no conditioning.
- `allowed_equipment: %w[]` (bodyweight only — the empty array is valid because the integrity check treats `"bodyweight"` as implicit).
- `banned_equipment`: every `User::EQUIPMENT_SLUGS` entry.
- `allowed_formats: %w[straight rounds]`, `primary_formats: %w[straight]`.
- `warm_up: :flow`, `cool_down: :savasana`.
- `finisher: :forbidden`, `core: :optional`.
- `notes`: "A flowing sequence — transitions between poses carry the rhythm. Do not emit tabata, for_time, emom, or any conditioning format."
- Three examples at 20/30/45 min, each with a single main flow section plus the savasana cool-down.

Source material: `app/llm_context/*.md` does not have an Ohm-specific file; use the existing behaviour encoded in `NO_WARMUP_COOLDOWN_SLUGS` (line 2654) and the pilates/yoga aliases in the generator.

Commit message: `feat(llm_context): add Ohm contract — flow + savasana`.

### Task 3.3: Author Deka Fit (exemplar for Deka variants)

Deka Fit stands in for the whole Deka family; fill the other variants (3.4–3.7) in the same shape but with each variant's specific station pool.

- `SLUG = "deka-fit"`, `NAME = "Deka Fit"`.
- `purity`: ten-zone race format — five run zones alternate with five functional zones. Every session practises race-shape pacing and transitions.
- `allowed_equipment`: mirror the Deka Fit stations (row, ski erg, assault bike, wall ball, sled, kettlebells, etc. — consult `FORMAT_AFFINITY["deka-fit"]` and any existing `app/llm_context/deka_fit.md` constants).
- `banned_equipment`: barbell, anything outside the ten-station toolkit.
- `allowed_formats: %w[for_time rounds emom ladder]`, `primary_formats: %w[for_time rounds]`.
- `warm_up: :easy_cardio`, `cool_down: :full_body_stretch`.
- `finisher: :optional`, `core: :optional`.
- `notes`: "Sessions practise the 1-zone run → 1-zone station alternation. When `race_simulation?` is true, the prompt builder sets `finisher: :required` and the session covers all ten zones."
- Three examples: one 30-min "single rotation" practice, one 45-min "half race" simulation, one 60-min "full race" with all ten zones.

Source material: `app/llm_context/deka_fit.md` (existing), plus any station constants in `WorkoutLLMGenerator` (search for `DEKA_FIT_STATIONS` or `EVENT_STATIONS["deka-fit"]`).

### Task 3.4–3.15: Remaining activities

One commit per activity. Each follows Task 3.1's structure: add integrity test → run-fail → write module → run-pass → enable via env flag → eyeball 3 generations → commit.

| # | Activity | Canonical slug | Source to lift from | Key values |
|---|---|---|---|---|
| 3.4  | Dynamo           | `dynamo`            | `FORMAT_AFFINITY["dynamo"]`, `app/llm_context/hiit.md`, `app/llm_context/bodyweight.md` | `allowed_equipment: []` (bodyweight only), `banned_equipment`: all of `User::EQUIPMENT_SLUGS`, `warm_up: :bodyweight_activation`, `finisher: :optional`. |
| 3.5  | Hyrox            | `hyrox`             | `FORMAT_AFFINITY["hyrox"]`, `app/llm_context/hyrox.md`, any `HYROX_STATIONS` | `allowed_equipment: %w[rowing_machine ski_erg sled wall_ball kettlebells]` + bodyweight, `warm_up: :easy_cardio`, `finisher: :optional`. |
| 3.6  | Deka             | `deka`              | Same family as 3.3 | Generic Deka — covers all events. |
| 3.7  | Deka Strong      | `deka-strong`       | `app/llm_context/deka_strong.md` | Heavier kit: sled, wall ball, farmer carry. |
| 3.8  | Deka Mile        | `deka-mile`         | `app/llm_context/deka_mile.md` | Running-heavy variant. |
| 3.9  | Deka Atlas       | `deka-atlas`        | `app/llm_context/deka_atlas.md` | Strongman-style stations. |
| 3.10 | Volt Octathlon   | `volt-octathlon`    | `app/llm_context/volt_octathlon.md` | Volt's in-house event; 8 stations. |
| 3.11 | Alternator       | `alternator`        | `FORMAT_AFFINITY["alternator"]` (existing hybrid block, line 296+); absorbs T&S treadmill focus per spec §5 | `allowed_equipment`: everything; `notes`: the treadmill-focus sentence from spec §5. |
| 3.12 | Transformer      | `transformer`       | `FORMAT_AFFINITY["transformer"]` (line 250), `app/llm_context/transformer.md` | Strength-leaning functional, not pure lifting: `allowed_formats: %w[rounds straight emom ladder]` plus a cardio-machine warmup/finisher slot — `notes` should require at least one cardio-machine section (rower / assault bike / ski erg / treadmill) somewhere in the session. Bar continuous-circuit structures the same way Iron Engine does (no back-to-back heavy work with no rest inside rounds). Staging feedback 2026-04-20. |
| 3.13 | Circuit Breaker  | `circuit-breaker`   | `FORMAT_AFFINITY["circuit-breaker"]`, `app/llm_context/f45.md`, `app/llm_context/functional.md` | Station-based circuit training. |
| 3.14 | CrossFit         | `crossfit`          | `app/llm_context/crossfit.md` | Classic CrossFit WOD shape. |
| 3.15 | Functional Muscle | `functional-muscle` | `app/llm_context/functional_muscle.md` + FM-specific methods | FM has its own warm-up baked into `functional_muscle_rule`; preserve that behaviour via `notes`. |
| 3.16 | General Fitness  | `general-fitness`   | Fallback default | Permissive defaults: all equipment allowed, warm_up `:easy_cardio`, finisher `:optional`. |

### Task 3.17: Enable every activity on the env flag

**Files:** none.

- [ ] **Step 1: Set the flag to cover every activity**

```bash
export WORKOUT_PROMPT_CONTRACT_ACTIVITIES="iron-engine,turbine,alternator,circuit-breaker,dynamo,transformer,ohm,hyrox,deka,deka-fit,deka-strong,deka-mile,deka-atlas,volt-octathlon,functional-muscle,crossfit,general-fitness"
```

- [ ] **Step 2: Run the full test suite**

```bash
bin/rails test
```

Expected: green.

- [ ] **Step 3: Generate one session per activity in the console and skim logs for the `path=contract` log line**

- [ ] **Step 4: Commit any final tuning**

```bash
git add -A
git commit -m "tune: final adjustments after full-activity dual-path run"
```

---

## Phase 4: Collapse the old path and remove Tread & Shred

The new path is now authoritative. Delete the old path and the T&S-specific code.

### Task 4.1: Flip the default to contract path for all activities

**Files:**
- Modify: `app/services/workout_llm_generator.rb` (`contract_path?`)

- [ ] **Step 1: Make `contract_path?` default to true**

Change `contract_path?` to return true whenever the activity resolves through the registry, and honour an opt-out env var for emergency fallback:

```ruby
def contract_path?
  legacy = ENV["WORKOUT_PROMPT_LEGACY_ACTIVITIES"].to_s.split(",").map { |s|
    LLMContext::Activities.canonical_slug(s.strip)
  }
  return false if legacy.include?(LLMContext::Activities.canonical_slug(@activity_slug))
  LLMContext::Activities.for(@activity_slug).present?
end
```

- [ ] **Step 2: Run the full test suite**

```bash
bin/rails test
```

- [ ] **Step 3: Commit**

```bash
git add app/services/workout_llm_generator.rb
git commit -m "refactor(workout_llm_generator): contract path becomes the default"
```

### Task 4.2: Delete the old prompt-path methods

**Files:**
- Modify: `app/services/workout_llm_generator.rb`

- [ ] **Step 1: Delete these methods**

- `build_example_prompt` (line 649)
- `build_prompt` (line 990)
- `fetch_top_liked_examples` (line 617)
- `fetch_context` (line 580)
- `load_sport_context` (line 2676)
- `build_research_context` (search for it and delete)
- `build_warmup_cooldown` (line 939)
- `warmup_cooldown_rule` (line 2229)
- `core_section_rule` (line 1448)
- `sport_purity_rule` (line 1434)
- `select_section_formats` (line 1676) — replace all call sites with `contract[:allowed_formats]` / `contract[:primary_formats]` selection
- `skip_warmup_cooldown?` (line 1374) — Ohm's behaviour is now expressed by `warm_up: :flow, cool_down: :savasana`

And tighten `build_session_structure` (line 2258) into `build_session_shape`, driven by `contract[:finisher]` and `contract[:core]`.

- [ ] **Step 2: Delete these constants**

- `FORMAT_AFFINITY` (line 246)
- `WARMUP_OPTIONS` (line 139)
- `COOLDOWN_OPTIONS` (line 169)
- `TRAINING_EMPHASES` (line 182)
- `NO_WARMUP_COOLDOWN_SLUGS` (line 2654)
- `BODYWEIGHT_ONLY_SLUGS` (line 2650)
- `SKIP_FORMAT_SELECTION_SLUGS` (line 1653)
- `CONTEXT_TAG_MAP` (line 16)

`ACTIVITY_ALIASES` moves wholesale into `LLMContext::Activities::ALIASES` and deletes from the generator.

- [ ] **Step 3: Run the full test suite**

```bash
bin/rails test
```

Expected: green. Fix any callers of deleted methods/constants by routing through `LLMContext::Activities.for(@activity_slug)::CONTRACT`.

- [ ] **Step 4: Run `rg` to confirm no stragglers**

```bash
git grep -n "WARMUP_OPTIONS\|COOLDOWN_OPTIONS\|FORMAT_AFFINITY\|TRAINING_EMPHASES\|NO_WARMUP_COOLDOWN_SLUGS\|BODYWEIGHT_ONLY_SLUGS\|SKIP_FORMAT_SELECTION_SLUGS\|CONTEXT_TAG_MAP\|build_example_prompt\|fetch_top_liked_examples\|build_warmup_cooldown" || echo "clean"
```

Expected: `clean`.

- [ ] **Step 5: Commit**

```bash
git add app/services/workout_llm_generator.rb
git commit -m "refactor(workout_llm_generator): delete old prompt path methods and constants"
```

### Task 4.3: Delete absorbed markdown context files

**Files:**
- Delete: every `app/llm_context/*.md` except `shared/*.md` and `activities/*.rb`

- [ ] **Step 1: List them**

```bash
ls app/llm_context/*.md
```

- [ ] **Step 2: Delete**

Delete every top-level `app/llm_context/*.md`. The `shared/` and `activities/` subdirectories are unaffected because `git rm` on a glob only matches files in the specified directory.

```bash
git rm app/llm_context/*.md
```

If any file has already been removed, `git rm` will error on that path — remove the offender from the glob or use `git rm --ignore-unmatch app/llm_context/*.md`. Check the resulting staged diff with `git status` before committing.

- [ ] **Step 3: Run tests**

```bash
bin/rails test
```

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(llm_context): remove markdown files absorbed into activity modules"
```

### Task 4.4: Execute T&S removal and grep audit

**Files:**
- Modify: `app/services/workout_llm_generator.rb`

- [ ] **Step 1: Run the grep audit from the spec**

```bash
rg -i 'tread.?shred|barry' app/ config/ db/seeds/ test/
```

Every hit must be one of:
- An alias entry pointing at `alternator` in `LLMContext::Activities::ALIASES`.
- A DB seed row that represents existing user workouts (leave these alone).
- A banned-words list entry (naming rule).

- [ ] **Step 2: Remove or reroute everything else**

Any method branch, view string, or fixture referring to `tread-shred` or `barry-s` as a live activity must be removed or pointed at Alternator.

- [ ] **Step 3: Re-run grep audit**

```bash
rg -i 'tread.?shred|barry' app/ config/ test/
```

Only aliases and intentional naming-ban references should remain.

- [ ] **Step 4: Add a test asserting T&S routes to Alternator**

Append to `test/llm_context/activities_test.rb`:

```ruby
test "tread-shred slug routes to Alternator" do
  assert_equal "alternator", LLMContext::Activities.canonical_slug("tread-shred")
  assert_equal LLMContext::Activities::Alternator, LLMContext::Activities.for("tread-shred")
end

test "barry-s slug routes to Alternator" do
  assert_equal LLMContext::Activities::Alternator, LLMContext::Activities.for("barry-s")
end
```

- [ ] **Step 5: Run tests**

```bash
bin/rails test
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: remove Tread & Shred as a distinct activity; route aliases to Alternator"
```

### Task 4.5: Remove the `WORKOUT_PROMPT_CONTRACT_ACTIVITIES` env flag

**Files:**
- Modify: `app/services/workout_llm_generator.rb`

- [ ] **Step 1: Drop the env check**

`contract_path?` becomes:

```ruby
def contract_path?
  legacy = ENV["WORKOUT_PROMPT_LEGACY_ACTIVITIES"].to_s.split(",").map { |s|
    LLMContext::Activities.canonical_slug(s.strip)
  }
  !legacy.include?(LLMContext::Activities.canonical_slug(@activity_slug))
end
```

(Keep the `LEGACY_ACTIVITIES` emergency hatch for one release. It does nothing unless set.)

- [ ] **Step 2: Run tests**

```bash
bin/rails test
```

- [ ] **Step 3: Commit**

```bash
git add app/services/workout_llm_generator.rb
git commit -m "refactor(workout_llm_generator): retire contract-path feature flag; legacy hatch remains"
```

---

## Phase 5: Service refactor (OUT OF SCOPE)

Splitting `WorkoutLLMGenerator` into `PromptBuilder` / `FormatPicker` / `ContractLoader` is a separate future spec. Do not do it in this plan.

---

## Testing strategy summary

| Test | Phase | Purpose |
|---|---|---|
| `test/llm_context/activities_test.rb` | 1, 4 | Registry and alias resolution. |
| `test/llm_context/contract_integrity_test.rb` | 1, 3 | One test per activity: schema, warm-up/cool-down keys, 3 examples, no banned equipment. |
| `test/services/workout_llm_generator/contract_prompt_builder_test.rb` | 2 | XML-tag order, per-activity regression strings, banned_equipment override, routing. |
| `test/services/workout_validator_test.rb` (existing) | all | `fix_rest_ratio` already landed; keep it green. |
| Manual eyeball | 2, 3 | 3 workouts per activity at phase boundaries. |

Not automated: LLM output quality. The validator catches violations; the prompt shape prevents them.

---

## Risks recap (from the spec)

- Authoring 16 × 3 = 48 hand-authored example workouts is real work; Phase 2 provides the evidence that the shape works before that investment scales.
- Losing organic community signal from `fetch_top_liked_examples`. Treat `EXAMPLES` as a living list updated from the DB periodically.
- XML-tag change could surprise the model. Phase 2's dual-path (env flag) lets us compare.
- Contract schema drift. Add new keys deliberately with a pass across every activity.
