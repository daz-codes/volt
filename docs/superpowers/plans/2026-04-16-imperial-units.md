# Imperial Units Preference Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a user preference that allows entering and viewing height/weight in imperial units (feet/inches, pounds) instead of metric (cm, kg).

**Architecture:** Store a `unit_system` string on users ("metric" or "imperial"). The database continues to hold metric values (`height_cm`, `weight_kg`) as the single source of truth. A Ruby helper module converts for display on the show page. A Stimulus controller handles the edit form — swapping visible inputs and converting imperial values to metric before submit. No changes to the LLM generator, validator, share images, or workout views.

**Tech Stack:** Rails 8.2, Stimulus.js, Minitest, Tailwind CSS.

**Spec:** `docs/superpowers/specs/2026-04-15-imperial-units-design.md`

---

## File Structure

**New files:**
- `db/migrate/<timestamp>_add_unit_system_to_users.rb` — migration
- `app/helpers/unit_conversion_helper.rb` — conversion methods (`cm_to_ft_in`, `ft_in_to_cm`, `kg_to_lbs`, `lbs_to_kg`, `format_height`, `format_weight`)
- `app/javascript/controllers/unit_toggle_controller.js` — swap visible fields, convert on submit
- `test/helpers/unit_conversion_helper_test.rb` — unit tests for the helper

**Modified files:**
- `app/controllers/profiles_controller.rb` — permit `unit_system` param
- `app/views/profiles/edit.html.erb` — add toggle + imperial inputs, wire Stimulus controller
- `app/views/profiles/show.html.erb` — use helper for height/weight display

---

## Task 1: Add `unit_system` column to users

**Files:**
- Create: `db/migrate/<timestamp>_add_unit_system_to_users.rb`
- Verify: `db/schema.rb` (auto-updated by migration)

- [ ] **Step 1: Generate the migration**

Run:
```bash
bin/rails generate migration AddUnitSystemToUsers unit_system:string
```

- [ ] **Step 2: Edit the migration to set the default**

Open the newly created migration file and set it to:

```ruby
class AddUnitSystemToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :unit_system, :string, default: "metric"
  end
end
```

- [ ] **Step 3: Run the migration**

Run:
```bash
bin/rails db:migrate
```

Expected: migration runs successfully, `db/schema.rb` updated with `t.string "unit_system", default: "metric"` in the users table.

- [ ] **Step 4: Verify in console**

Run:
```bash
bin/rails runner 'puts User.new.unit_system'
```

Expected: outputs `metric`.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "add unit_system column to users"
```

---

## Task 2: Build `UnitConversionHelper` with conversion methods (TDD)

**Files:**
- Create: `app/helpers/unit_conversion_helper.rb`
- Create: `test/helpers/unit_conversion_helper_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/helpers/unit_conversion_helper_test.rb` with:

```ruby
require "test_helper"

class UnitConversionHelperTest < ActionView::TestCase
  include UnitConversionHelper

  # cm_to_ft_in
  test "cm_to_ft_in converts 180cm to 5ft 11in" do
    assert_equal [5, 11], cm_to_ft_in(180)
  end

  test "cm_to_ft_in converts 183cm to 6ft 0in" do
    assert_equal [6, 0], cm_to_ft_in(183)
  end

  test "cm_to_ft_in converts 152cm to 4ft 12in rounded to 5ft 0in" do
    # 152cm = 59.842in — rounds to 60in = 5ft 0in
    assert_equal [5, 0], cm_to_ft_in(152)
  end

  test "cm_to_ft_in handles nil" do
    assert_nil cm_to_ft_in(nil)
  end

  # ft_in_to_cm
  test "ft_in_to_cm converts 5ft 11in to 180cm" do
    assert_equal 180, ft_in_to_cm(5, 11)
  end

  test "ft_in_to_cm converts 6ft 0in to 183cm" do
    assert_equal 183, ft_in_to_cm(6, 0)
  end

  test "ft_in_to_cm handles nil inches as zero" do
    assert_equal 183, ft_in_to_cm(6, nil)
  end

  test "ft_in_to_cm returns nil if feet is nil" do
    assert_nil ft_in_to_cm(nil, 5)
  end

  # kg_to_lbs
  test "kg_to_lbs converts 80kg to 176.5lbs rounded to nearest 0.5" do
    # 80 * 2.20462 = 176.3696 → rounds to 176.5
    assert_equal 176.5, kg_to_lbs(80)
  end

  test "kg_to_lbs converts 75kg to nearest 0.5" do
    # 75 * 2.20462 = 165.3465 → rounds to 165.5
    assert_equal 165.5, kg_to_lbs(75)
  end

  test "kg_to_lbs handles nil" do
    assert_nil kg_to_lbs(nil)
  end

  # lbs_to_kg
  test "lbs_to_kg converts 176lbs to 79.8kg" do
    # 176 * 0.453592 = 79.832 → rounded to 1 decimal = 79.8
    assert_equal 79.8, lbs_to_kg(176)
  end

  test "lbs_to_kg handles nil" do
    assert_nil lbs_to_kg(nil)
  end

  # format_height
  test "format_height metric shows cm" do
    user = User.new(height_cm: 180, unit_system: "metric")
    assert_equal "180cm", format_height(user)
  end

  test "format_height imperial shows ft and in" do
    user = User.new(height_cm: 180, unit_system: "imperial")
    assert_equal %{5'11"}, format_height(user)
  end

  test "format_height imperial shows zero inches" do
    user = User.new(height_cm: 183, unit_system: "imperial")
    assert_equal %{6'0"}, format_height(user)
  end

  test "format_height returns nil if no height" do
    user = User.new(height_cm: nil, unit_system: "metric")
    assert_nil format_height(user)
  end

  # format_weight
  test "format_weight metric shows kg" do
    user = User.new(weight_kg: 80, unit_system: "metric")
    assert_equal "80kg", format_weight(user)
  end

  test "format_weight metric with decimal shows one decimal place" do
    user = User.new(weight_kg: 80.5, unit_system: "metric")
    assert_equal "80.5kg", format_weight(user)
  end

  test "format_weight metric handles BigDecimal from DB" do
    user = User.new(weight_kg: BigDecimal("80.5"), unit_system: "metric")
    assert_equal "80.5kg", format_weight(user)
  end

  test "format_weight imperial shows lbs" do
    user = User.new(weight_kg: 80, unit_system: "imperial")
    assert_equal "176.5lbs", format_weight(user)
  end

  test "format_weight imperial whole number drops decimal" do
    user = User.new(weight_kg: 81.647, unit_system: "imperial")
    # 81.647kg = 180.0lbs → whole number
    assert_equal "180lbs", format_weight(user)
  end

  test "format_weight returns nil if no weight" do
    user = User.new(weight_kg: nil, unit_system: "metric")
    assert_nil format_weight(user)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
bin/rails test test/helpers/unit_conversion_helper_test.rb
```

Expected: FAIL with `NameError: uninitialized constant UnitConversionHelperTest::UnitConversionHelper` (or similar — module doesn't exist yet).

- [ ] **Step 3: Create the helper**

Create `app/helpers/unit_conversion_helper.rb`:

```ruby
module UnitConversionHelper
  CM_PER_INCH = 2.54
  KG_PER_LB   = 0.453592

  # Converts cm (numeric) to [feet, inches] with inches rounded to nearest integer.
  # Handles inch rollover (e.g. 60in becomes 5 ft, 0 in).
  def cm_to_ft_in(cm)
    return nil if cm.nil?
    total_inches = (cm.to_f / CM_PER_INCH).round
    [ total_inches / 12, total_inches % 12 ]
  end

  # Converts feet + inches to integer cm. Nil inches treated as 0.
  def ft_in_to_cm(feet, inches)
    return nil if feet.nil?
    ((feet.to_i * 12 + inches.to_i) * CM_PER_INCH).round
  end

  # Converts kg to lbs, rounded to nearest 0.5.
  def kg_to_lbs(kg)
    return nil if kg.nil?
    lbs = kg.to_f / KG_PER_LB
    (lbs * 2).round / 2.0
  end

  # Converts lbs to kg, rounded to 1 decimal place.
  def lbs_to_kg(lbs)
    return nil if lbs.nil?
    (lbs.to_f * KG_PER_LB).round(1)
  end

  # Formats a user's height for display based on their unit_system.
  # Returns nil if no height.
  def format_height(user)
    return nil if user.height_cm.blank?
    if user.unit_system == "imperial"
      ft, inches = cm_to_ft_in(user.height_cm)
      %(#{ft}'#{inches}")
    else
      "#{user.height_cm}cm"
    end
  end

  # Formats a user's weight for display based on their unit_system.
  # Returns nil if no weight.
  def format_weight(user)
    return nil if user.weight_kg.blank?
    if user.unit_system == "imperial"
      lbs = kg_to_lbs(user.weight_kg)
      lbs == lbs.to_i ? "#{lbs.to_i}lbs" : "#{lbs}lbs"
    else
      kg = user.weight_kg.to_f
      kg == kg.to_i ? "#{kg.to_i}kg" : "#{kg.round(1)}kg"
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
bin/rails test test/helpers/unit_conversion_helper_test.rb
```

Expected: PASS, all 23 tests.

- [ ] **Step 5: Commit**

```bash
git add app/helpers/unit_conversion_helper.rb test/helpers/unit_conversion_helper_test.rb
git commit -m "add UnitConversionHelper with metric/imperial conversions"
```

---

## Task 3: Permit `unit_system` in ProfilesController

**Files:**
- Modify: `app/controllers/profiles_controller.rb:36-40` (profile_params method)

- [ ] **Step 1: Edit `profile_params`**

In `app/controllers/profiles_controller.rb`, update `profile_params` to include `:unit_system`:

```ruby
def profile_params
  params.expect(user: [ :username, :display_name, :avatar,
    :age, :height_cm, :weight_kg, :gender,
    :pool_length, :speed_unit, :unit_system, :injury_notes ])
end
```

- [ ] **Step 2: Verify the app boots**

Run:
```bash
bin/rails runner 'puts "ok"'
```

Expected: outputs `ok` (no syntax errors).

- [ ] **Step 3: Commit**

```bash
git add app/controllers/profiles_controller.rb
git commit -m "permit unit_system in profile params"
```

---

## Task 4: Update profile show page to use display helpers

**Files:**
- Modify: `app/views/profiles/show.html.erb:146-157`

- [ ] **Step 1: Replace hardcoded height/weight display**

In `app/views/profiles/show.html.erb`, find the Physical section (currently around lines 146–157). Replace the two `if @user.height_cm.present?` / `if @user.weight_kg.present?` blocks with:

```erb
<% if @user.height_cm.present? %>
  <div class="bg-zinc-800 rounded-xl p-4 text-center">
    <% if @user.unit_system == "imperial" %>
      <% ft, inches = cm_to_ft_in(@user.height_cm) %>
      <p class="text-2xl font-bold text-white"><%= ft %><span class="text-sm text-gray-500 font-normal">'</span><%= inches %><span class="text-sm text-gray-500 font-normal">"</span></p>
    <% else %>
      <p class="text-2xl font-bold text-white"><%= @user.height_cm %><span class="text-sm text-gray-500 font-normal">cm</span></p>
    <% end %>
    <p class="text-gray-500 text-xs mt-1 uppercase tracking-wide">Height</p>
  </div>
<% end %>
<% if @user.weight_kg.present? %>
  <div class="bg-zinc-800 rounded-xl p-4 text-center">
    <% if @user.unit_system == "imperial" %>
      <% lbs = kg_to_lbs(@user.weight_kg) %>
      <p class="text-2xl font-bold text-white"><%= lbs == lbs.to_i ? lbs.to_i : lbs %><span class="text-sm text-gray-500 font-normal">lbs</span></p>
    <% else %>
      <p class="text-2xl font-bold text-white"><%= @user.weight_kg.to_f.round(1) %><span class="text-sm text-gray-500 font-normal">kg</span></p>
    <% end %>
    <p class="text-gray-500 text-xs mt-1 uppercase tracking-wide">Weight</p>
  </div>
<% end %>
```

**Why not use `format_height` / `format_weight`?** The show page displays the unit (cm/kg/ft/in/lbs) in a smaller, dimmer span for visual polish. Using the helpers directly would produce flat strings; keeping the markup inline preserves the existing styling treatment.

- [ ] **Step 2: Start the server and view the profile**

Run:
```bash
bin/rails server
```

Open the profile page in a browser. Expected: height/weight display exactly as before (since all users currently have `unit_system = "metric"`).

Stop the server (`Ctrl+C`).

- [ ] **Step 3: Manually test imperial rendering**

Run:
```bash
bin/rails runner 'u = User.first; u.update!(unit_system: "imperial"); puts "done"'
```

Reload the profile page — expected: height shows as e.g. `5'11"` and weight as e.g. `176.5lbs`.

Revert:
```bash
bin/rails runner 'u = User.first; u.update!(unit_system: "metric"); puts "done"'
```

- [ ] **Step 4: Commit**

```bash
git add app/views/profiles/show.html.erb
git commit -m "display height/weight in user's preferred unit system"
```

---

## Task 5: Add unit toggle + imperial inputs to profile edit form

**Files:**
- Modify: `app/views/profiles/edit.html.erb:84-108` (height/weight block)
- Modify: `app/views/profiles/edit.html.erb:142-161` (Preferences section — add toggle)

- [ ] **Step 1: Add the Metric/Imperial toggle in the Preferences section**

In `app/views/profiles/edit.html.erb`, inside the Preferences `<div>` (currently around lines 142–161), add the new toggle **above** the Speed Unit block so the Preferences section looks like this:

```erb
<%# ── Preferences ── %>
<div class="mb-10">
  <h2 class="text-xs font-black uppercase tracking-widest text-gray-500 mb-4">Preferences</h2>
  <div class="space-y-5">
    <div>
      <%= f.label :unit_system, "Units", class: "block text-sm font-semibold text-gray-300 uppercase tracking-wide mb-2" %>
      <div class="grid grid-cols-2 gap-2">
        <% [["metric", "Metric (cm, kg)"], ["imperial", "Imperial (ft, lbs)"]].each do |value, label| %>
          <label class="cursor-pointer">
            <%= f.radio_button :unit_system, value,
                class: "peer sr-only",
                checked: (@user.unit_system || "metric") == value,
                data: { action: "change->unit-toggle#switch", unit_toggle_target: "radio" } %>
            <div class="border-2 border-zinc-600 rounded-xl p-2.5 peer-checked:border-lime-400 peer-checked:bg-lime-400/10 transition-all text-center">
              <p class="font-semibold text-sm"><%= label %></p>
            </div>
          </label>
        <% end %>
      </div>
      <p class="text-gray-600 text-xs mt-1.5">Used for your height and weight.</p>
    </div>

    <div>
      <%= f.label :speed_unit, "Speed Unit", class: "block text-sm font-semibold text-gray-300 uppercase tracking-wide mb-2" %>
      <div class="grid grid-cols-2 gap-2">
        <% [["kmh", "km/h"], ["mph", "mph"]].each do |value, label| %>
          <label class="cursor-pointer">
            <%= f.radio_button :speed_unit, value, class: "peer sr-only", checked: (@user.speed_unit || "kmh") == value %>
            <div class="border-2 border-zinc-600 rounded-xl p-2.5 peer-checked:border-lime-400 peer-checked:bg-lime-400/10 transition-all text-center">
              <p class="font-semibold text-sm"><%= label %></p>
            </div>
          </label>
        <% end %>
      </div>
      <p class="text-gray-600 text-xs mt-1.5">Used for treadmill speeds in generated workouts.</p>
    </div>
  </div>
</div>
```

- [ ] **Step 2: Wire the Stimulus controller on the `form_with` tag**

In `app/views/profiles/edit.html.erb` at line 16, change:

```erb
<%= form_with model: @user, url: profile_path, method: :patch do |f| %>
```

to:

```erb
<%= form_with model: @user, url: profile_path, method: :patch,
      data: { controller: "unit-toggle",
              action: "submit->unit-toggle#beforeSubmit" } do |f| %>
```

- [ ] **Step 3: Replace the Physical grid height/weight cells**

In `app/views/profiles/edit.html.erb`, find the `grid grid-cols-3 gap-3` block (currently around lines 84–108). Replace the two height/weight divs (keep Age unchanged) so the whole grid looks like:

```erb
<div class="grid grid-cols-3 gap-3">
  <div>
    <%= f.label :age, "Age", class: "block text-sm font-semibold text-gray-300 uppercase tracking-wide mb-2" %>
    <%= f.number_field :age, min: 10, max: 100, placeholder: "e.g. 34",
        class: "w-full bg-zinc-800 border border-zinc-600 rounded-xl px-4 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-lime-400" %>
  </div>

  <div>
    <%= f.label :height_cm, "Height", class: "block text-sm font-semibold text-gray-300 uppercase tracking-wide mb-2" %>

    <%# Metric height (cm) %>
    <div data-unit-toggle-target="metricHeight" <%= "hidden" if @user.unit_system == "imperial" %>>
      <div class="relative">
        <%= f.number_field :height_cm, min: 100, max: 250, placeholder: "e.g. 178",
            data: { unit_toggle_target: "heightCm" },
            class: "w-full bg-zinc-800 border border-zinc-600 rounded-xl px-4 py-2.5 pr-10 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-lime-400" %>
        <span class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-600 text-xs">cm</span>
      </div>
    </div>

    <%# Imperial height (ft + in). These inputs have NO `name` — the Stimulus controller
        converts their values into the hidden height_cm field before submit. %>
    <% ft, inches = @user.height_cm.present? ? cm_to_ft_in(@user.height_cm) : [ nil, nil ] %>
    <div data-unit-toggle-target="imperialHeight" <%= "hidden" unless @user.unit_system == "imperial" %> class="flex gap-1.5">
      <div class="relative flex-1">
        <input type="number" min="3" max="8" placeholder="ft"
               value="<%= ft %>"
               data-unit-toggle-target="heightFt"
               class="w-full bg-zinc-800 border border-zinc-600 rounded-xl px-3 py-2.5 pr-6 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-lime-400">
        <span class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-600 text-xs">ft</span>
      </div>
      <div class="relative flex-1">
        <input type="number" min="0" max="11" placeholder="in"
               value="<%= inches %>"
               data-unit-toggle-target="heightIn"
               class="w-full bg-zinc-800 border border-zinc-600 rounded-xl px-3 py-2.5 pr-6 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-lime-400">
        <span class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-600 text-xs">in</span>
      </div>
    </div>
  </div>

  <div>
    <%= f.label :weight_kg, "Weight", class: "block text-sm font-semibold text-gray-300 uppercase tracking-wide mb-2" %>

    <%# Metric weight (kg) %>
    <div data-unit-toggle-target="metricWeight" <%= "hidden" if @user.unit_system == "imperial" %>>
      <div class="relative">
        <%= f.number_field :weight_kg, min: 30, max: 300, step: 0.5, placeholder: "e.g. 75",
            data: { unit_toggle_target: "weightKg" },
            class: "w-full bg-zinc-800 border border-zinc-600 rounded-xl px-4 py-2.5 pr-10 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-lime-400" %>
        <span class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-600 text-xs">kg</span>
      </div>
    </div>

    <%# Imperial weight (lbs). This input has NO `name` — the Stimulus controller
        converts its value into the hidden weight_kg field before submit. %>
    <% lbs = @user.weight_kg.present? ? kg_to_lbs(@user.weight_kg) : nil %>
    <div data-unit-toggle-target="imperialWeight" <%= "hidden" unless @user.unit_system == "imperial" %>>
      <div class="relative">
        <input type="number" min="66" max="660" step="0.5" placeholder="e.g. 165"
               value="<%= lbs %>"
               data-unit-toggle-target="weightLbs"
               class="w-full bg-zinc-800 border border-zinc-600 rounded-xl px-4 py-2.5 pr-10 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-lime-400">
        <span class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-600 text-xs">lbs</span>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 4: Commit (WIP — Stimulus controller comes next)**

```bash
git add app/views/profiles/edit.html.erb
git commit -m "add imperial inputs and toggle to profile edit form (needs controller)"
```

---

## Task 6: Build the `unit-toggle` Stimulus controller

**Files:**
- Create: `app/javascript/controllers/unit_toggle_controller.js`

- [ ] **Step 1: Create the controller**

Create `app/javascript/controllers/unit_toggle_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

const CM_PER_INCH = 2.54
const KG_PER_LB = 0.453592

export default class extends Controller {
  static targets = [
    "radio",
    "metricHeight", "imperialHeight",
    "metricWeight", "imperialWeight",
    "heightCm", "heightFt", "heightIn",
    "weightKg", "weightLbs"
  ]

  // Switch visible fields when the radio changes
  switch(event) {
    const system = event.target.value
    const imperial = system === "imperial"

    this.metricHeightTarget.hidden = imperial
    this.imperialHeightTarget.hidden = !imperial
    this.metricWeightTarget.hidden = imperial
    this.imperialWeightTarget.hidden = !imperial
  }

  // Before the form submits, if imperial is active, convert values
  // into the hidden metric inputs so the server receives cm/kg.
  // NOTE: This handler MUST stay synchronous — Turbo collects form data
  // immediately after the submit event, so any async work here would miss the window.
  beforeSubmit(_event) {
    const selected = this.radioTargets.find(r => r.checked)
    if (!selected || selected.value !== "imperial") return

    const ft = parseInt(this.heightFtTarget.value, 10)
    const inches = parseInt(this.heightInTarget.value, 10) || 0
    if (!isNaN(ft)) {
      const cm = Math.round((ft * 12 + inches) * CM_PER_INCH)
      this.heightCmTarget.value = cm
    } else {
      this.heightCmTarget.value = ""
    }

    const lbs = parseFloat(this.weightLbsTarget.value)
    if (!isNaN(lbs)) {
      const kg = Math.round(lbs * KG_PER_LB * 10) / 10
      this.weightKgTarget.value = kg
    } else {
      this.weightKgTarget.value = ""
    }
  }
}
```

- [ ] **Step 2: Manually verify in the browser**

Run:
```bash
bin/rails server
```

Open `/profile/edit` in a browser. Steps:
1. Verify it defaults to Metric with cm/kg inputs visible.
2. Click "Imperial" — cm/kg inputs should hide, ft/in/lbs inputs should appear populated from current values.
3. Enter `5` ft, `11` in, `165` lbs. Click Save.
4. Verify on the show page: height/weight are displayed correctly in imperial.
5. Edit again, verify the imperial values round-trip correctly (should show `5'11"` and `~165lbs`).
6. Switch back to Metric — cm/kg inputs reappear with original server values (180cm / 74.8kg from the conversion).
7. Save — verify the stored values are still correct.

Stop the server.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/unit_toggle_controller.js
git commit -m "add unit-toggle Stimulus controller for profile form"
```

---

## Task 7: Run full test suite to confirm no regressions

**Files:**
- None (verification only)

- [ ] **Step 1: Run the full test suite**

Run:
```bash
bin/rails test
```

Expected: all tests pass, no new failures.

- [ ] **Step 2: If anything fails, investigate and fix**

If a test fails that wasn't failing before, read the error, locate the cause, fix, re-run. Do not skip tests.

- [ ] **Step 3: Final commit (if any fixes were made)**

```bash
git add <whatever>
git commit -m "fix regressions from imperial units feature"
```

---

## Done

At this point the feature is complete:
- Users can toggle between Metric and Imperial on their profile.
- When imperial is selected, height and weight are entered as ft/in + lbs.
- The database always stores metric values.
- The profile show page displays in the user's preferred units.
- The workout system (LLM, validator, share images) is unaffected.
