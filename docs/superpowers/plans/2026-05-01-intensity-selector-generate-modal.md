# Intensity Selector in Generate Modal — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 4-option pill selector (Mixed / Zone 2 / Conditioning / Max Effort) to the workout generate modal and plumb the chosen value into the LLM prompt as a session-wide intensity directive.

**Architecture:** The selected pill posts an `intensity_style` param. The controller sanitises it to a known enum value or `nil`. `WorkoutLLMGenerator` threads it through to `ContractPromptBuilder`, which renders an optional `<intensity_style>` XML tag in the prompt. A new line in `global_rules.md` tells the LLM to apply that style to every main and finisher section, overriding the existing keyword-detection-in-notes behaviour. `Mixed` is the no-op default (empty string → `nil` → no tag → identical prompt to today).

**Tech Stack:** Rails 8, ERB, Tailwind, Minitest. No new gems, no JS controller changes.

**Spec:** `docs/superpowers/specs/2026-05-01-intensity-selector-generate-modal-design.md`

---

## File map

| File | Change |
| --- | --- |
| `test/services/workout_llm_generator/contract_prompt_builder_test.rb` | Add tests for the new tag |
| `app/services/workout_llm_generator/contract_prompt_builder.rb` | Accept `intensity_style:` kwarg, render `<intensity_style>` tag |
| `app/services/workout_llm_generator.rb` | Add `intensity_style:` kwarg, thread to builder |
| `app/llm_context/shared/global_rules.md` | Add directive-precedence rule |
| `app/controllers/workouts_controller.rb` | Read + sanitise param in `create_with_llm`, pass to generator |
| `app/views/workouts/_generate_modal.html.erb` | Add pill-row above Training Notes |

No new files. No JS controller changes.

---

## Task 1: ContractPromptBuilder renders `<intensity_style>` tag

**Files:**
- Test: `test/services/workout_llm_generator/contract_prompt_builder_test.rb`
- Modify: `app/services/workout_llm_generator/contract_prompt_builder.rb`

The existing builder already accepts a `session_notes:` kwarg and renders a `<session_notes>` tag only when present (lines 21-41). Mirror that pattern for `intensity_style:`.

- [ ] **Step 1: Update the test helper to accept `intensity_style:`**

In `test/services/workout_llm_generator/contract_prompt_builder_test.rb`, extend the `build` helper at line 4:

```ruby
def build(activity_slug: "kettlebell", duration_mins: 45, athlete: "test athlete", session_notes: nil, banned_override: [], intensity_style: nil)
  WorkoutLLMGenerator::ContractPromptBuilder.new(
    activity: LLMContext::Activities.for!(activity_slug),
    duration_mins: duration_mins,
    athlete_block: athlete,
    session_notes: session_notes,
    banned_equipment_override: banned_override,
    intensity_style: intensity_style
  ).build
end
```

- [ ] **Step 2: Write three failing tests**

Add these three tests near the existing `session_notes` tests (around line 22-28):

```ruby
test "omits intensity_style tag when not given" do
  refute_includes build, "<intensity_style>"
end

test "includes intensity_style tag when set" do
  prompt = build(intensity_style: "zone_2")
  assert_includes prompt, "<intensity_style>\nzone_2\n</intensity_style>"
end

test "intensity_style tag appears before session_notes tag" do
  prompt = build(intensity_style: "max_effort", session_notes: "no running")
  intensity_pos = prompt.index("<intensity_style>")
  notes_pos = prompt.index("<session_notes>")
  assert intensity_pos && notes_pos, "both tags must be present"
  assert intensity_pos < notes_pos, "intensity_style must come before session_notes"
end
```

- [ ] **Step 3: Run the tests and confirm they fail**

```
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb -n /intensity_style/
```

Expected: 3 failures (`unknown keyword: :intensity_style`).

- [ ] **Step 4: Implement the kwarg + tag rendering**

In `app/services/workout_llm_generator/contract_prompt_builder.rb`:

- Update `initialize` (line 21) to accept `intensity_style: nil` (place it at the end of the kwarg list, after `contract_override:`). Inside the method body, assign `@intensity_style = intensity_style`.
- In `build` (line 30-41), insert the new tag emission **before** the `session_notes` line:

```ruby
tags << xml(:intensity_style, @intensity_style) if @intensity_style.present?
tags << xml(:session_notes, @session_notes) if @session_notes.present?
```

- [ ] **Step 5: Re-run the tests**

```
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb -n /intensity_style/
```

Expected: 3 passing. Then run the full file:

```
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb
```

Expected: all green (the existing `session_notes` tests must still pass).

- [ ] **Step 6: Commit**

```
git add test/services/workout_llm_generator/contract_prompt_builder_test.rb \
        app/services/workout_llm_generator/contract_prompt_builder.rb
git commit -m "feat(intensity): contract prompt renders <intensity_style> tag"
```

---

## Task 2: WorkoutLLMGenerator threads `intensity_style` to the builder

**Files:**
- Modify: `app/services/workout_llm_generator.rb`

The generator's `initialize` (line 81) and `self.call` (line 77) both take `**_legacy` to safely swallow unknown kwargs, so adding a new optional kwarg is backwards-compatible. The private `build_contract_prompt` (line 578) is the single call site that constructs the builder.

- [ ] **Step 1: Add the kwarg to `self.call` and `initialize`**

In `app/services/workout_llm_generator.rb`:

- Line 77 (`self.call`): add `intensity_style: nil` to the signature and pass `intensity_style: intensity_style` to `new(...)`.
- Line 81 (`initialize`): add `intensity_style: nil` to the signature.
- Inside `initialize` (after line 89 where `@session_notes` is assigned), add:

```ruby
@intensity_style = intensity_style.to_s.presence_in(%w[zone_2 conditioning max_effort])
```

This double-checks values defensively even if the controller already validated — `WorkoutLLMGenerator` is also called from program-related code paths and remix flows, and we never want a stray value to reach the prompt.

- [ ] **Step 2: Pass `intensity_style` into the builder**

In `build_contract_prompt` (around line 583), extend the `ContractPromptBuilder.new(...)` call to include:

```ruby
intensity_style:           @intensity_style,
```

Place it right after `session_notes:` to mirror the spec ordering.

- [ ] **Step 3: Verify nothing broke**

Run the generator and prompt-builder test files to confirm existing callers still work:

```
bin/rails test test/services/workout_llm_generator/
```

Expected: all green.

- [ ] **Step 4: Commit**

```
git add app/services/workout_llm_generator.rb
git commit -m "feat(intensity): thread intensity_style kwarg through generator"
```

---

## Task 3: Add the directive-precedence rule to global_rules.md

**Files:**
- Modify: `app/llm_context/shared/global_rules.md`

The existing **Intensity style** bullet at line 4 (the one added in commit e3df242) describes the three styles. We need to add a sentence telling the LLM that an explicit `<intensity_style>` tag in the user input acts as a session-wide directive overriding session-note keyword detection.

- [ ] **Step 1: Edit the Intensity style bullet**

In `app/llm_context/shared/global_rules.md`, find the line beginning:

```
- **Intensity style** — every main/finisher section may set an optional `intensity_style`: ...
```

After the existing sentence ending `(typical: 1-2 conditioning blocks plus 1 max_effort or zone_2 anchor).`, append this new sentence inside the same bullet:

```
If `<intensity_style>` is provided in the user input, treat it as a session-wide directive: apply that style to every `main` and `finisher` section, overriding any keyword detection in `<session_notes>`. Warm-up and cool-down sections are unaffected.
```

The four sub-bullets (zone_2 / conditioning / max_effort definitions) stay untouched.

- [ ] **Step 2: Sanity-check the file still loads**

The builder reads this file via `File.read` (line 44). Confirm the file is valid markdown and there's no parse error:

```
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb
```

Expected: all green (the rules file is loaded into the prompt; broken file would crash these tests).

- [ ] **Step 3: Commit**

```
git add app/llm_context/shared/global_rules.md
git commit -m "feat(intensity): add directive-precedence rule for intensity_style tag"
```

---

## Task 4: Controller reads + sanitises `intensity_style` param

**Files:**
- Test: `test/controllers/workouts_controller_test.rb`
- Modify: `app/controllers/workouts_controller.rb`

The existing controller test file currently has no `create_with_llm` coverage (verified — `grep create_with_llm` and `grep session_notes` return nothing in that file). We'll add a focused test that stubs the generator and asserts the kwarg is forwarded.

- [ ] **Step 1: Read the existing test file structure**

```
bin/rails test test/controllers/workouts_controller_test.rb -n test_truth 2>/dev/null || head -40 test/controllers/workouts_controller_test.rb
```

Look at how other controller tests sign in users (likely `sign_in_as users(:some_user)` or equivalent fixture pattern). You'll need a signed-in user with at least one generation remaining (i.e. not at limit).

- [ ] **Step 2: Write three failing tests**

Add to `test/controllers/workouts_controller_test.rb`. Adapt the sign-in helper to whatever pattern the file already uses:

```ruby
test "create_with_llm forwards intensity_style to generator when valid" do
  sign_in_as(users(:one))  # replace with whatever fixture/helper pattern this file already uses
  captured = nil
  WorkoutLLMGenerator.stub :new, ->(**kwargs) { captured = kwargs; OpenStruct.new(generate: { attrs: {}, debug_info: [], group_tag_name: nil }) } do
    post workouts_path, params: { activity: "Functional Muscle", duration_mins: 45, intensity_style: "zone_2" }
  end
  assert_equal "zone_2", captured[:intensity_style]
end

test "create_with_llm passes nil when intensity_style is blank" do
  sign_in_as(users(:one))
  captured = nil
  WorkoutLLMGenerator.stub :new, ->(**kwargs) { captured = kwargs; OpenStruct.new(generate: { attrs: {}, debug_info: [], group_tag_name: nil }) } do
    post workouts_path, params: { activity: "Functional Muscle", duration_mins: 45, intensity_style: "" }
  end
  assert_nil captured[:intensity_style]
end

test "create_with_llm rejects unknown intensity_style values" do
  sign_in_as(users(:one))
  captured = nil
  WorkoutLLMGenerator.stub :new, ->(**kwargs) { captured = kwargs; OpenStruct.new(generate: { attrs: {}, debug_info: [], group_tag_name: nil }) } do
    post workouts_path, params: { activity: "Functional Muscle", duration_mins: 45, intensity_style: "garbage" }
  end
  assert_nil captured[:intensity_style]
end
```

If the file already requires `ostruct`, skip; otherwise add `require "ostruct"` at the top.

**Note for executor:** if the existing controller tests use a different mocking style (Mocha, etc.), adapt — the assertion is what matters: `intensity_style` arrives at `WorkoutLLMGenerator.new` as `"zone_2"`, `nil`, and `nil` respectively.

- [ ] **Step 3: Run the tests and confirm they fail**

```
bin/rails test test/controllers/workouts_controller_test.rb -n /intensity_style/
```

Expected: 3 failures — `captured[:intensity_style]` is missing because the controller doesn't read or pass the param yet.

- [ ] **Step 4: Update `create_with_llm` to read and pass the param**

In `app/controllers/workouts_controller.rb`, inside `create_with_llm` (lines 439-478):

After line 449 (`injury_notes = params[:injury_notes].presence`), add:

```ruby
intensity_style = params[:intensity_style].to_s.presence_in(%w[zone_2 conditioning max_effort])
```

In the `WorkoutLLMGenerator.new(...)` call (lines 451-459), add a kwarg right after `injury_notes:`:

```ruby
intensity_style: intensity_style,
```

- [ ] **Step 5: Re-run the tests**

```
bin/rails test test/controllers/workouts_controller_test.rb -n /intensity_style/
```

Expected: 3 passing.

- [ ] **Step 6: Run the full controller test file as a regression check**

```
bin/rails test test/controllers/workouts_controller_test.rb
```

Expected: all green.

- [ ] **Step 7: Commit**

```
git add test/controllers/workouts_controller_test.rb app/controllers/workouts_controller.rb
git commit -m "feat(intensity): controller forwards intensity_style param to generator"
```

---

## Task 5: Add the pill selector to the generate modal

**Files:**
- Modify: `app/views/workouts/_generate_modal.html.erb`

This is a view-only change. The form already submits to `workouts_path` (line 22) and standard browser radio behaviour handles selection — the existing `generate-form` Stimulus controller does not need to change.

- [ ] **Step 1: Insert the pill block above Training Notes**

In `app/views/workouts/_generate_modal.html.erb`, locate the **Training Notes** block at lines 91-99 (the comment line `<%# Session Notes — free text %>` and its `<div class="mb-6">` wrapper).

Insert the following block **immediately above** that block (i.e. between line 89's closing `</div>` of the Workout Type section and line 91's `<%# Session Notes — free text %>` comment):

```erb
<%# Intensity — session-wide directive (Mixed = no-op default) %>
<div class="mb-6">
  <p class="text-sm font-semibold text-gray-300 uppercase tracking-wide mb-3">Intensity</p>
  <% intensity_options = [
    { value: "",             label: "Mixed",        default: true  },
    { value: "zone_2",       label: "Zone 2",       default: false },
    { value: "conditioning", label: "Conditioning", default: false },
    { value: "max_effort",   label: "Max Effort",   default: false }
  ] %>
  <div class="flex flex-wrap gap-2">
    <% intensity_options.each do |opt| %>
      <label class="cursor-pointer">
        <%= radio_button_tag "intensity_style", opt[:value], opt[:default],
            id: "intensity_#{opt[:value].presence || 'mixed'}",
            class: "peer sr-only" %>
        <div class="px-3 py-1.5 rounded-full border border-zinc-600 text-xs font-semibold text-gray-400 peer-checked:border-lime-400 peer-checked:bg-lime-400/10 peer-checked:text-lime-400 transition-all">
          <%= opt[:label] %>
        </div>
      </label>
    <% end %>
  </div>
</div>
```

The pill styling matches the existing **Recent** activity pills in the same file (lines 67-78) — same `rounded-full`, same `border-zinc-600 → peer-checked:border-lime-400` pattern.

- [ ] **Step 2: Boot the dev server and visually verify**

Start the server (or reuse the running one) and open the workout generate modal:

```
bin/dev
```

Then in the browser, open the generate-workout modal (typically a "+" or "Generate" button on the home/feed page). Verify:

- A new **INTENSITY** heading appears above **TRAINING NOTES**.
- Four pills are visible: Mixed, Zone 2, Conditioning, Max Effort.
- Mixed is selected by default (lime ring + lime text).
- Clicking another pill moves the selection (browser handles this — no JS).
- The pill row wraps cleanly at narrow widths (resize the browser to phone width and confirm).
- No console errors.

If anything is off, fix the markup before continuing.

- [ ] **Step 3: Commit**

```
git add app/views/workouts/_generate_modal.html.erb
git commit -m "feat(intensity): add intensity selector pills to generate modal"
```

---

## Task 6: End-to-end verification

**Files:** none (manual sanity check + final commit message review)

- [ ] **Step 1: Generate a real workout with each intensity setting**

With `bin/dev` running:

1. Open the generate modal, pick **Zone 2**, set duration to 30 min, leave notes empty, submit.
2. Confirm the generated workout's main sections feel zone_2-shaped (high reps, light load, minimal rest, conversational pace cues). The session JSON should have `intensity_style: "zone_2"` on each main/finisher section — check by opening the workout in the rails console or inspecting the structure on the show page if visible.
3. Repeat with **Conditioning** and **Max Effort** to confirm each style takes effect.
4. Repeat once with **Mixed** to confirm the no-op behaviour: no session-wide directive, sections vary as before.

- [ ] **Step 2: Run the full test suite**

```
bin/rails test
```

Expected: all green. If any unrelated failures surface, investigate but do not lump fixes into this branch unless trivially related.

- [ ] **Step 3: Final commit / PR prep**

If the suite is clean, the branch is ready. Confirm the commit log reads as a clean sequence:

```
git log --oneline main..HEAD
```

Expected (5 commits, in this order):
1. `feat(intensity): contract prompt renders <intensity_style> tag`
2. `feat(intensity): thread intensity_style kwarg through generator`
3. `feat(intensity): add directive-precedence rule for intensity_style tag`
4. `feat(intensity): controller forwards intensity_style param to generator`
5. `feat(intensity): add intensity selector pills to generate modal`

No further commit needed — each task already committed its slice.

---

## Notes for the executor

- **Backwards compatibility:** every change is additive. No existing kwarg is removed or renamed. Program-related call sites (`Program::WorkoutBuilder`, `ProgramBuilder`, `RetryProgramSlotJob`) pass `intensity_style: nil` implicitly — verified safe by the `nil` default.
- **The `presence_in` Rails helper** (Active Support) returns the value if it's in the given array, otherwise `nil`. Used in both the controller and the generator for defence-in-depth.
- **Why two layers of validation:** controller validates user input (untrusted); generator validates again because it has internal callers (program code, remix flows) that may evolve independently. The cost is one extra `to_s.presence_in` call — cheap insurance.
- **Stimulus is untouched.** The existing `generate-form` controller handles spinner/submit logic only and doesn't read individual field values. Pure HTML radio buttons inside the form work fine.
- **DRY/YAGNI check:** no new helper modules, no new partials, no new constants beyond the inline `intensity_options` array. The pill markup is local to this single view — extracting it would be premature.
