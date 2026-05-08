# Sortable Workout Sections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users reorder workout sections by drag-and-drop while editing or creating a workout, replacing the current "insert section above" button.

**Architecture:** Add Sortable.js as an importmap dependency. Wire it up via a new dedicated Stimulus controller (`sortable-sections`) attached to the existing sections list container. A grip handle on each section header is the only drag-initiator. On form submit, the controller re-indexes section field names to sequential `0,1,2,…` in DOM order so the existing server-side sort (`Workout::StructureBuilder#structure_from_params`) yields the user's chosen order.

**Tech Stack:** Rails 8, importmap-rails, Stimulus, Sortable.js, Tailwind, Minitest + Capybara/Selenium for system tests.

**Spec:** `docs/superpowers/specs/2026-05-08-sortable-sections-design.md`

---

## File Map

- **Modify** `config/importmap.rb` — pin `sortablejs`
- **Create** `app/javascript/controllers/sortable_sections_controller.js` — new Stimulus controller (~30 lines)
- **Modify** `app/javascript/controllers/builder_controller.js` — remove `insertSectionAbove()`; remove up-arrow markup from `sectionTemplate(id)`; add grip handle to `sectionTemplate(id)`
- **Modify** `app/views/workouts/_builder_form.html.erb` — add `data-controller="sortable-sections"` to sections list; add grip handle to each pre-rendered section header; remove pre-rendered up-arrow button
- **Modify** `test/models/workout/structure_builder_test.rb` — add regression test locking the integer-key-order invariant
- **Create** `test/system/workouts/sortable_sections_test.rb` — system test for end-to-end drag reorder

---

## Task 1: Pin sortablejs via importmap

**Files:**
- Modify: `config/importmap.rb`

- [ ] **Step 1: Pin the package**

Run from repo root:

```bash
bin/importmap pin sortablejs
```

This downloads sortable to `vendor/javascript/` (or pins it to a CDN URL) and adds a line like `pin "sortablejs"` to `config/importmap.rb`.

- [ ] **Step 2: Verify the pin**

Run:

```bash
grep sortablejs config/importmap.rb
```

Expected: one line containing `pin "sortablejs"` (with optional `# @x.y.z` version comment).

- [ ] **Step 3: Sanity-check the app boots**

Run:

```bash
bin/rails runner 'puts "ok"'
```

Expected: `ok`. (No JS executes in `runner`, but this confirms importmap config still parses.)

- [ ] **Step 4: Commit**

```bash
git add config/importmap.rb vendor/javascript/sortablejs* 2>/dev/null
git status
git commit -m "chore: pin sortablejs via importmap"
```

(If `vendor/javascript/` did not get a new file because the pin uses a CDN URL, just commit `config/importmap.rb`.)

---

## Task 2: Lock the integer-key-order invariant with a model test

This is a regression guard, not a behaviour change — the test should pass on first run. It documents and protects the contract that the client-side re-index relies on.

**Files:**
- Modify: `test/models/workout/structure_builder_test.rb`

- [ ] **Step 1: Add the test**

Append the following test to `test/models/workout/structure_builder_test.rb` (inside the `class Workout::StructureBuilderTest < ActiveSupport::TestCase` block, before the closing `end`):

```ruby
test "sections are returned in integer-key order regardless of hash insertion order" do
  params = ActionController::Parameters.new(
    "2" => { name: "B", category: "main", format: "straight" },
    "0" => { name: "C", category: "main", format: "straight" },
    "1" => { name: "A", category: "main", format: "straight" }
  )

  structure = Workout.structure_from_params(params)

  assert_equal %w[C A B], structure["sections"].map { |s| s["name"] }
end
```

- [ ] **Step 2: Run the test, expect PASS**

Run:

```bash
bin/rails test test/models/workout/structure_builder_test.rb -n /integer-key-order/
```

Expected: 1 run, 1 assertion, 0 failures, 0 errors. (The existing `sort_by { |k, _| k.to_i }` in `Workout::StructureBuilder` already produces this behaviour; this test pins it.)

- [ ] **Step 3: Commit**

```bash
git add test/models/workout/structure_builder_test.rb
git commit -m "test: lock integer-key sort invariant on structure_from_params"
```

---

## Task 3: Create the `sortable-sections` Stimulus controller

**Files:**
- Create: `app/javascript/controllers/sortable_sections_controller.js`

- [ ] **Step 1: Create the controller**

Create the file with this exact contents:

```javascript
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Makes the workout builder section list drag-reorderable.
// Re-indexes section field names to sequential 0..N on form submit so that
// Workout::StructureBuilder#structure_from_params (which sorts by integer key)
// returns sections in the user's drag order.
export default class extends Controller {
  connect() {
    this.sortable = Sortable.create(this.element, {
      handle: "[data-sortable-handle]",
      animation: 150,
      ghostClass: "opacity-40",
      chosenClass: "ring-2"
    })

    this.form = this.element.closest("form")
    this.reindexBound = this.reindex.bind(this)
    this.form?.addEventListener("submit", this.reindexBound)
  }

  disconnect() {
    this.sortable?.destroy()
    this.sortable = null
    this.form?.removeEventListener("submit", this.reindexBound)
    this.form = null
  }

  reindex() {
    const sections = this.element.querySelectorAll("[data-section-id]")
    sections.forEach((section, i) => {
      const oldId = section.dataset.sectionId
      if (String(oldId) === String(i)) return
      section.dataset.sectionId = i
      section.querySelectorAll("[name]").forEach(el => {
        el.name = el.name.replace(`sections[${oldId}]`, `sections[${i}]`)
      })
    })
  }
}
```

Notes for the implementer:
- The early-return `if (String(oldId) === String(i)) return` avoids no-op DOM writes for sections that already sit at their target index.
- The selector `[name]` on `querySelectorAll` correctly catches inputs, selects, and textareas; nested exercise field names like `sections[<oldId>][exercises][<exId>][name]` get their leading `sections[<oldId>]` replaced and their inner `[exercises][<exId>]` left untouched.
- No `Sortable.create` callbacks are needed for the drag itself; only the submit-time re-index touches DOM data.

- [ ] **Step 2: Verify Stimulus auto-loads it**

The repo uses `pin_all_from "app/javascript/controllers"` and stimulus-loading auto-registers any `*_controller.js` in that directory. No manual registration is needed.

Run a precompile to confirm there are no JS syntax errors:

```bash
bin/rails assets:precompile 2>&1 | tail -20
```

Expected: completes without errors. (If precompile is slow or unavailable in this environment, instead boot `bin/dev` briefly and check for errors — see Manual QA at the end.)

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/sortable_sections_controller.js
git commit -m "feat(builder): add sortable-sections stimulus controller"
```

---

## Task 4: Wire the controller into the builder form view

**Files:**
- Modify: `app/views/workouts/_builder_form.html.erb`

- [ ] **Step 1: Add the controller attribute to the sections list container**

Find this line (currently around line 60):

```erb
<div data-builder-target="sectionsList" class="space-y-4 mb-4">
```

Replace with:

```erb
<div data-builder-target="sectionsList" data-controller="sortable-sections" class="space-y-4 mb-4">
```

- [ ] **Step 2: Add a grip handle to each pre-rendered section header**

Find this block inside the `existing_sections.each_with_index` loop (currently around lines 64–67):

```erb
<div data-section-id="<%= si %>" class="border border-zinc-600 rounded-2xl p-4">
  <div class="flex items-center gap-2 mb-3">
    <input name="sections[<%= si %>][name]" type="text"
      value="<%= section["name"] %>" placeholder="Section name" required
```

Insert the grip span as the first child of the `flex items-center gap-2 mb-3` div, immediately before the `<input name="sections[<%= si %>][name]" ...>`:

```erb
<span data-sortable-handle aria-label="Drag to reorder" title="Drag to reorder"
  class="text-gray-600 hover:text-lime-400 transition-colors flex-shrink-0 p-1 cursor-grab active:cursor-grabbing">
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24"
       fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <circle cx="9" cy="5" r="1"/><circle cx="9" cy="12" r="1"/><circle cx="9" cy="19" r="1"/>
    <circle cx="15" cy="5" r="1"/><circle cx="15" cy="12" r="1"/><circle cx="15" cy="19" r="1"/>
  </svg>
</span>
```

- [ ] **Step 3: Remove the pre-rendered "insert section above" button**

In the same `existing_sections.each_with_index` loop, find and **delete** the entire button block (currently around lines 94–99):

```erb
<button type="button" data-action="builder#insertSectionAbove"
  class="text-gray-600 hover:text-lime-400 transition-colors flex-shrink-0 p-1" aria-label="Insert section above" title="Insert section above">
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <line x1="12" y1="19" x2="12" y2="5"/><polyline points="5 12 12 5 19 12"/>
  </svg>
</button>
```

The "remove section" trash button (the next sibling) stays.

- [ ] **Step 4: Visual sanity check**

Run the dev server:

```bash
bin/dev
```

In a browser, visit `/workouts/<id>/edit` for a workout that has sections (e.g. log in as the seeded `users(:one)` and pick any saved workout). Confirm:

- A grip dots icon appears at the far left of each section header
- The up-arrow no longer appears
- Hovering the grip shows the grab cursor
- Inputs and selects still work normally; clicking them does not start a drag

(If you don't have a seeded workout with `structure: { "sections" => [...] }` available, skip the visual check here — it'll be exercised by the system test in Task 6.)

Stop the dev server with Ctrl-C.

- [ ] **Step 5: Commit**

```bash
git add app/views/workouts/_builder_form.html.erb
git commit -m "feat(builder): mount sortable-sections controller and add grip handles to pre-rendered sections"
```

---

## Task 5: Update `builder_controller.js` — template + remove insertSectionAbove

**Files:**
- Modify: `app/javascript/controllers/builder_controller.js`

- [ ] **Step 1: Add the grip handle to `sectionTemplate(id)`**

Inside the `sectionTemplate(id)` method, find the opening of the header row (currently around lines 92–95):

```javascript
return `
  <div data-section-id="${id}" class="border border-zinc-600 rounded-2xl p-4">
    <div class="flex items-center gap-2 mb-3">
      <input name="sections[${id}][name]" type="text" placeholder="Section name (e.g. Warm Up, Main Set)" required
```

Insert the grip span as the first child of the `flex items-center gap-2 mb-3` div, before the `<input name="sections[${id}][name]" ...>`:

```javascript
      <span data-sortable-handle aria-label="Drag to reorder" title="Drag to reorder"
        class="text-gray-600 hover:text-lime-400 transition-colors flex-shrink-0 p-1 cursor-grab active:cursor-grabbing">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24"
             fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="9" cy="5" r="1"/><circle cx="9" cy="12" r="1"/><circle cx="9" cy="19" r="1"/>
          <circle cx="15" cy="5" r="1"/><circle cx="15" cy="12" r="1"/><circle cx="15" cy="19" r="1"/>
        </svg>
      </span>
```

The grip markup must be byte-identical to the ERB version in Task 4 (modulo whitespace) so the controller behaves identically on pre-rendered and JS-added sections.

- [ ] **Step 2: Remove the up-arrow button from `sectionTemplate(id)`**

In the same `sectionTemplate(id)` method, find and **delete** this block (currently around lines 118–123):

```javascript
<button type="button" data-action="builder#insertSectionAbove"
  class="text-gray-600 hover:text-lime-400 transition-colors flex-shrink-0 p-1" aria-label="Insert section above" title="Insert section above">
  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <line x1="12" y1="19" x2="12" y2="5"/><polyline points="5 12 12 5 19 12"/>
  </svg>
</button>
```

The trash (`builder#removeSection`) button immediately after stays.

- [ ] **Step 3: Remove the `insertSectionAbove()` method**

Delete this method from the controller (currently around lines 14–18):

```javascript
insertSectionAbove(event) {
  const id = Date.now()
  const section = event.currentTarget.closest("[data-section-id]")
  section.insertAdjacentHTML("beforebegin", this.sectionTemplate(id))
}
```

- [ ] **Step 4: Verify no references remain**

Run:

```bash
grep -rn "insertSectionAbove" /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/app /Users/daz/Library/CloudStorage/ProtonDrive-daz.codes@pm.me-folder/volt/test
```

Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/controllers/builder_controller.js
git commit -m "feat(builder): drop insertSectionAbove and add grip handle to section template"
```

---

## Task 6: System test for end-to-end drag reorder

**Files:**
- Create: `test/system/workouts/sortable_sections_test.rb`

- [ ] **Step 1: Write the system test**

Create the file with these contents:

```ruby
require "application_system_test_case"

class Workouts::SortableSectionsTest < ApplicationSystemTestCase
  setup do
    visit new_session_path
    fill_in "Enter your email address", with: users(:one).email_address
    fill_in "Enter your password", with: "password"
    click_on "Sign in"
  end

  test "drag-reordering sections persists the new order" do
    visit new_workout_path

    fill_in "Workout Name", with: "Drag Test"

    # Add three sections named A, B, C in DOM order, each with one named exercise
    # (the exercise name input is required by HTML5 validation).
    %w[A B C].each do |section_name|
      click_on "+ Add Section"
      section = all("[data-builder-target='sectionsList'] [data-section-id]").last

      # Fill the section's name input. The first input[name$='[name]'] inside the
      # section is the section name (the exercises haven't been added yet).
      section.find("input[name$='[name]']", match: :first).set(section_name)

      # Add one exercise and fill its name. Once the exercise row exists, scope
      # to its [data-exercise-id] wrapper to disambiguate from the section name.
      within(section) { click_on "+ Add Exercise" }
      exercise = section.find("[data-exercise-id]", match: :first)
      exercise.find("input[name$='[name]']").set("#{section_name}-Exercise")
    end

    # Sanity: section name inputs are currently in DOM order A, B, C.
    section_name_values = all(
      "[data-builder-target='sectionsList'] > [data-section-id] > div > input[name$='[name]']"
    ).map(&:value)
    assert_equal %w[A B C], section_name_values

    # Drag section C above section A.
    sections = all("[data-builder-target='sectionsList'] > [data-section-id]")
    sections[2].find("[data-sortable-handle]").drag_to(sections[0])

    # DOM order should now read C, A, B.
    section_name_values = all(
      "[data-builder-target='sectionsList'] > [data-section-id] > div > input[name$='[name]']"
    ).map(&:value)
    assert_equal %w[C A B], section_name_values

    # Submit. Label is set in app/views/workouts/new.html.erb.
    click_on "Save & Log Workout"

    # Persisted order must reflect the drag.
    workout = Workout.where(name: "Drag Test").last
    assert workout, "expected a workout named 'Drag Test' to be created"
    assert_equal %w[C A B], workout.structure["sections"].map { |s| s["name"] }
  end
end
```

Notes for the implementer:
- `users(:one)` (`email_address: one@example.com`, password `"password"`) is provided by `test/fixtures/users.yml`.
- The selector `[data-builder-target='sectionsList'] > [data-section-id] > div > input[name$='[name]']` targets only the first immediate-`<input name=…[name]>` inside each section's header `<div>`, avoiding accidental matches against exercise name inputs deeper in the section.
- `.set(value)` is the correct Capybara node-level write API. `fill_in` requires a locator argument and is used at the page level (or inside a `within` block) — calling it directly on a found node will not behave as expected.
- `drag_to` is provided by Capybara and works with Sortable.js because `forceFallback` is `false` (the default). If CI flakes, see Risks in the spec.

- [ ] **Step 2: Run the test and verify PASS**

Run:

```bash
bin/rails test test/system/workouts/sortable_sections_test.rb
```

Expected: 1 run, multiple assertions, 0 failures, 0 errors.

If the test fails on the `assert_equal %w[C A B]` check after submit, the most likely cause is that submit-time re-indexing didn't run; verify the form has `data-controller="sortable-sections"` on its sections list (Task 4 step 1).

- [ ] **Step 3: Commit**

```bash
git add test/system/workouts/sortable_sections_test.rb
git commit -m "test(system): assert drag-reordering persists section order"
```

---

## Task 7: Manual QA pass

- [ ] **Step 1: Boot the dev server**

```bash
bin/dev
```

- [ ] **Step 2: Walk through the manual QA checklist from the spec**

Sign in as a real user (or a seeded one) and verify each of these in turn:

- [ ] Drag sections up and down on desktop; save; reload edit page; order is persisted.
- [ ] On a touch device or with browser devtools touch emulation, drag using the grip; vertical scroll still works when starting from a non-handle area.
- [ ] Drag a section while a different section's name input is focused; release; nothing is broken.
- [ ] Add a new section via "+ Add Section"; drag it to the top; save; order is correct.
- [ ] Edit an existing workout; drag a pre-rendered section; save; order is correct (this exercises both pre-rendered ERB and the JS-templated path on the same page).

- [ ] **Step 3: Stop the dev server**

Ctrl-C.

- [ ] **Step 4: Final test run**

Run the full test suite to ensure no regressions:

```bash
bin/rails test
```

Expected: all green.

(If green, no commit needed for QA — already covered by the Task 6 system test.)

---

## Done criteria

- All tasks above completed and committed
- `bin/rails test` is green
- Manual QA checklist passes on desktop and mobile/touch
- The "insert section above" up-arrow no longer appears in the builder
- A grip handle appears at the far left of every section header (pre-rendered and JS-added)
- Saving a workout after drag-reordering persists sections in the dragged order
