# Hybrid race-family shared style — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the 7 race-family activity contracts (Hyrox, Hybrid Race, Deka, Deka Fit, Deka Strong, Deka Mile, Deka Atlas) around a shared `hybrid_style.md` and push EMOM / 30-30 cardio / compromised-running modalities to the forefront of every race-family workout.

**Architecture:** New `app/llm_context/shared/hybrid_style.md` is read once and injected as `<hybrid_style>` by `ContractPromptBuilder` whenever the activity contract sets `hybrid_family: true`. Mirrors the existing `<global_rules>` pattern. Each race contract gets the flag, has its duplicated `notes:` paragraphs stripped, and has its 3 EXAMPLES rewritten to showcase the hybrid modalities.

**Tech Stack:** Rails 8, Minitest, Anthropic SDK (tool-use). Spec at `docs/superpowers/specs/2026-05-13-hybrid-race-family-style-design.md`.

**Reference skills:** @superpowers-ruby:test-driven-development, @superpowers-ruby:verification-before-completion, @superpowers-ruby:ruby-commit-message.

---

## File map

**New:**
- `app/llm_context/shared/hybrid_style.md` — the shared style guide.

**Modified:**
- `app/services/workout_llm_generator/contract_prompt_builder.rb` — load + inject the shared file when `hybrid_family: true`.
- `app/services/workout_llm_generator.rb` — tweak tool-schema `notes` and `emom` descriptions.
- `app/llm_context/shared/global_rules.md` — soften the EMOM cardio + floor pairing rule for the multi-exercise (E2MOM) case.
- `lib/llm_context/activities/hyrox.rb`
- `lib/llm_context/activities/hybrid_race.rb`
- `lib/llm_context/activities/deka.rb`
- `lib/llm_context/activities/deka_fit.rb`
- `lib/llm_context/activities/deka_strong.rb`
- `lib/llm_context/activities/deka_mile.rb`
- `lib/llm_context/activities/deka_atlas.rb`
- `test/llm_context/contract_integrity_test.rb` — add positive assertion for the flag.
- `test/services/workout_llm_generator/contract_prompt_builder_test.rb` — add `<hybrid_style>` injection tests.

---

### Chipper distribution decision

The spec mandates "exactly 2 long for_time chippers across the 21 examples (≈1 in 10)". The chippers naturally belong on the race-simulation examples:

- **Deka Fit example 3 (Full Race)** — stays a `for_time` chipper covering all 10 zones.
- **Deka example 3 (Full Race)** — stays a `for_time` chipper covering all 10 zones.

All other 19 examples — including **Deka Atlas's current `Ten-Station Simulation`** — must be rewritten to lead with EMOM, 30/30 cardio, or compromised-running shapes. Atlas's current Race Simulation is replaced because Atlas is the third example and Atlas already breaks more aggressively from the run-station mould.

---

## Task 1: Add `<hybrid_style>` injection to ContractPromptBuilder (red → green)

**Files:**
- Create: `app/llm_context/shared/hybrid_style.md` (one-line placeholder for this task — full content lands in Task 2)
- Modify: `app/services/workout_llm_generator/contract_prompt_builder.rb`
- Test: `test/services/workout_llm_generator/contract_prompt_builder_test.rb`

- [ ] **Step 1: Write the failing tests**

Append to `test/services/workout_llm_generator/contract_prompt_builder_test.rb` (before the final `end`):

```ruby
test "omits hybrid_style tag for non-race activities" do
  refute_includes build(activity_slug: "kettlebell"), "<hybrid_style>"
end

test "injects hybrid_style tag for race-family activities" do
  prompt = build(activity_slug: "hyrox")
  assert_includes prompt, "<hybrid_style>"
  assert_includes prompt, "</hybrid_style>"
end

test "hybrid_style tag appears immediately after global_rules" do
  prompt = build(activity_slug: "hyrox")
  global_pos = prompt.index("</global_rules>")
  hybrid_pos = prompt.index("<hybrid_style>")
  assert global_pos && hybrid_pos, "both tags must be present"
  assert global_pos < hybrid_pos, "hybrid_style must come after global_rules"
end
```

- [ ] **Step 2: Run the tests and confirm they fail**

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb -n /hybrid_style/
```

Expected: 3 failures — `<hybrid_style>` not present in the Hyrox prompt because the builder doesn't inject it yet (and Hyrox doesn't have `hybrid_family: true` yet — that comes in Task 3).

> **Note:** The "non-race activities" test will pass even before the implementation lands, because the tag isn't in the prompt at all. That's expected — only the two "injects for race-family" assertions need to drive the implementation.

- [ ] **Step 3: Create placeholder shared file**

Create `app/llm_context/shared/hybrid_style.md` with a single-line placeholder (real content lands in Task 2):

```markdown
# Hybrid race-family style (placeholder — see Task 2 for full content)
```

- [ ] **Step 4: Implement the builder change**

In `app/services/workout_llm_generator/contract_prompt_builder.rb`:

Add a new constant beside `GLOBAL_RULES_PATH` (around line 19):

```ruby
HYBRID_STYLE_PATH = Rails.root.join("app/llm_context/shared/hybrid_style.md").freeze
```

Add a memoized class reader beside `self.global_rules` (around line 45):

```ruby
def self.hybrid_style
  @hybrid_style ||= File.read(HYBRID_STYLE_PATH).sub(/\A# .*\n+/, "").strip
end
```

In `build`, after the `<global_rules>` line (currently line 37: `tags << xml(:global_rules, self.class.global_rules)`), add:

```ruby
tags << xml(:hybrid_style, self.class.hybrid_style) if contract[:hybrid_family]
```

- [ ] **Step 5: Temporarily enable the flag on Hyrox to make tests pass**

Open `lib/llm_context/activities/hyrox.rb` and add `hybrid_family: true,` as a one-line addition near the top of the CONTRACT hash (just after `purity:`). This is a stopgap so Task 1's tests pass — Task 3 adds the same flag to all 7 contracts properly.

- [ ] **Step 6: Run the tests and confirm they pass**

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb -n /hybrid_style/
```

Expected: 3 passes. Also run the full file to confirm no regressions:

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb
```

Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add app/llm_context/shared/hybrid_style.md \
        app/services/workout_llm_generator/contract_prompt_builder.rb \
        test/services/workout_llm_generator/contract_prompt_builder_test.rb \
        lib/llm_context/activities/hyrox.rb
git commit -m "feat(generator): inject <hybrid_style> when contract opts in"
```

---

## Task 2: Populate `hybrid_style.md` with the full spec content

**Files:**
- Modify: `app/llm_context/shared/hybrid_style.md`

- [ ] **Step 1: Replace the placeholder with the full content**

Open the file and replace its single placeholder line with the content below verbatim. The content matches §"Content of `hybrid_style.md`" in the spec (`docs/superpowers/specs/2026-05-13-hybrid-race-family-style-design.md`):

````markdown
# Hybrid race-family style

## 1. Headline modalities — push these to the front

Hybrid sessions must lean heavily on these four shapes. Most sessions use 2-3 of them. A long for_time chipper is allowed occasionally (roughly 1 in 8-10 sessions) — never the default.

- **EMOM family** (`format: emom`) — 8-15 min blocks.
  - 1 or 2 exercises render as **EMOM** (every 1 min). Both exercises share each minute when 2 are listed. Alternatively more exercises can be given on a rotating basis, so each exercise is completed every round. The LLM may program these as "all exercises each minute" OR "exercises rotate across rounds" — both are valid.
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

## 2. Your-call reps cueing

For canonical EMOM movements (the list in section 1) when they appear inside an EMOM / E2MOM:

- Leave `reps` blank on the exercise.
- Write the per-exercise `notes` cue as: **`~50% of your 1-min max (leaves ~20s rest)`**.

The athlete supplies the actual rep number. Distance-based movements (Farmer's Carry, Sled, Bear Crawl) keep `distance_m`. Duration-holds keep `duration_s`.

The same cue is NOT used outside the EMOM family — a `rounds` or `for_time` section with wall balls still prescribes a concrete rep count.

## 3. Volume targets

- Most sessions include 1 EMOM block (10 min typical) AND a cardio block (30/30 or compromised running).
- A session with only an EMOM and no cardio block — or only cardio and no EMOM — is fine occasionally but should not be the default.
- One long for_time chipper is allowed roughly 1 in 8-10 sessions.
- Other modalities such as ladders, up-and-down ladders, mountains, etc. can be used, but the bread and butter should be EMOMs.
- It's also fine to use other cardio rounds (such as 4 rounds of 250m row), but the 30/30 pattern should be used often, especially if intensity is set to `high`.
- Do NOT use 30/30 sets if intensity is set to `low`.

## 4. Race stations remain race stations

Race-day stations (Hyrox's 8, Deka's 10, Atlas's strongman stations) stay the **headline movements** for their respective contracts. The shared file *adds* prominence to EMOMs and 30/30 cardio; it doesn't replace stations.

## 5. What to avoid

- Defaulting to a long for_time chipper every session — fine occasionally, not the norm.
- Prescribing a numeric `reps` value on canonical EMOM movements *inside* an EMOM (let the cue do it).
- Pairing a cardio machine with a floor or carry station inside a single-minute EMOM. For an E2MOM (3+ exercises, 2-min cycle) this is fine — the 2-min frame leaves room.

## 6. Shared movement vocabulary

- **Supplementary movements** (most sessions weave 1-2): KB Swings, KB Thrusters, KB High Pull, Walking Lunges, Jump Squats, Push-ups, Med Ball Slams, KB Shoulder Press.
- **Strength accessory** (most non-race-simulation sessions — max 1 strength block, never the centrepiece): Bench Press, Deadlift, Romanian Deadlift, Sumo Deadlift, Single-Leg Deadlift, Split Squat, Bulgarian Split Squat, B-stance Squat, B-stance Deadlift, Landmine Press, Landmine Row, Push Press, Bent-Over Row, Pull-ups, Chin-ups, Dips, Toes-to-bar.
- **Burpee variations**: Box Jump Burpees, Plate Burpees, Wall Ball Burpees, KB Burpees.
- **Abs finisher** (optional close-out): Sit-ups, Leg Raises, Plank, V-ups, Russian Twists, Hollow Holds.

Activities with their own variant-specific vocabulary additions keep those in their own contract.

## 7. Strength accessory rules

- Most non-race-simulation sessions include one strength accessory block.
- `format: rounds`, 3-6 reps heavy at 120s rest with `intensity_style: high`, OR 8-10 reps moderate at 90s rest.
- Never more than one strength block per session, never the centrepiece, never replaces a run or a station.

## 8. Duration-interval pattern

- A 3-4 round work-rest block on a single conditioning movement (Wall Balls, Burpees, Walking Lunges, KB Swings, Med Ball Slams) is a valid alternative to rep-based rounds.
- Use `format: rounds` with `duration_s: 120` and `rest_secs: 120` for the canonical 2-min work / 2-min rest shape.
- The clean-minute rule (work + rest = 60s) applies only to cardio machines, not to these functional movements.
````

- [ ] **Step 2: Verify file contents render in the prompt**

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb -n /hybrid_style/
```

Expected: still passes — the memoization happens at class load, so this assumes a fresh process. If a previously-loaded value is cached, `bin/rails test` starts a new process and reloads — no manual cache bust needed.

- [ ] **Step 3: Commit**

```bash
git add app/llm_context/shared/hybrid_style.md
git commit -m "feat(generator): populate hybrid race-family shared style"
```

---

## Task 3: Flip `hybrid_family: true` on all 7 race contracts + integrity test assertion

**Files:**
- Modify all 7: `lib/llm_context/activities/{hyrox,hybrid_race,deka,deka_fit,deka_strong,deka_mile,deka_atlas}.rb`
- Modify: `test/llm_context/contract_integrity_test.rb`

> Hyrox was given the flag in Task 1 already. Re-confirm it's still there; if so, no change in this task for Hyrox.

- [ ] **Step 1: Write the failing assertion**

In `test/llm_context/contract_integrity_test.rb`, add a new constant near the top and a new method below `assert_activity_valid`:

```ruby
RACE_FAMILY_MODULES = [
  LLMContext::Activities::Hyrox,
  LLMContext::Activities::HybridRace,
  LLMContext::Activities::Deka,
  LLMContext::Activities::DekaFit,
  LLMContext::Activities::DekaStrong,
  LLMContext::Activities::DekaMile,
  LLMContext::Activities::DekaAtlas
].freeze

test "all race-family contracts have hybrid_family: true" do
  RACE_FAMILY_MODULES.each do |mod|
    assert_equal true, mod::CONTRACT[:hybrid_family],
      "#{mod} must set hybrid_family: true to opt into the shared style"
  end
end
```

- [ ] **Step 2: Run the test and confirm it fails for 6 modules**

```bash
bin/rails test test/llm_context/contract_integrity_test.rb -n /hybrid_family/
```

Expected: 1 failure. The assertion fails on the first non-Hyrox module (likely HybridRace) because `:hybrid_family` is missing.

- [ ] **Step 3: Add the flag to the remaining 6 contracts**

In each of `lib/llm_context/activities/{hybrid_race,deka,deka_fit,deka_strong,deka_mile,deka_atlas}.rb`, add as the first line inside the CONTRACT hash (right after the opening `{`, before `purity:`):

```ruby
hybrid_family: true,
```

- [ ] **Step 4: Run all integrity tests**

```bash
bin/rails test test/llm_context/contract_integrity_test.rb
```

Expected: all green, including the new `hybrid_family` test.

- [ ] **Step 5: Commit**

```bash
git add test/llm_context/contract_integrity_test.rb lib/llm_context/activities/
git commit -m "feat(contracts): opt all race-family activities into shared hybrid_style"
```

---

## Task 4: Tweak tool-schema `notes` description

**Files:**
- Modify: `app/services/workout_llm_generator.rb` (around line 63)

- [ ] **Step 1: Edit the notes description**

Find line 63 in `app/services/workout_llm_generator.rb`. The current value of `description:` on the `notes` property ends:

```
"...use the structure fields instead."
```

Append:

```
 Athlete-relative effort cues that reference rep targets are allowed (e.g. '~50% of your 1-min max'). The 'never put reps in notes' rule applies to numeric rep counts that duplicate the reps field — not to athlete-calibrated cues.
```

The final string should be the existing text + a single space + the appended sentence. Keep on one line; this is a JSON Schema string.

- [ ] **Step 2: Run the full prompt builder test suite to confirm no regression**

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb
```

Expected: all green.

- [ ] **Step 3: Commit**

```bash
git add app/services/workout_llm_generator.rb
git commit -m "feat(generator): permit athlete-relative effort cues in exercise notes"
```

---

## Task 5: Tweak tool-schema `emom` description

**Files:**
- Modify: `app/services/workout_llm_generator.rb` (line 39, inside the `format` enum description)

- [ ] **Step 1: Edit the emom description**

The current `format` enum description contains the substring:

```
emom=every minute on the minute (all listed exercises share each minute, max 2 — usually 1)
```

Replace it with:

```
emom=every minute on the minute. 1-2 exercises render as EMOM (every 1 min). 3+ exercises render as E2MOM (every 2 min, all exercises in the cycle). Multi-exercise EMOMs may do all exercises each minute OR rotate exercises across rounds — programming choice
```

- [ ] **Step 2: Verify the build still parses**

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb
```

Expected: all green.

- [ ] **Step 3: Commit**

```bash
git add app/services/workout_llm_generator.rb
git commit -m "feat(generator): correct emom schema description to match renderer"
```

---

## Task 6: Soften the EMOM cardio + floor rule in global_rules.md

**Files:**
- Modify: `app/llm_context/shared/global_rules.md` (line 43)

- [ ] **Step 1: Edit the rule**

Find the existing sentence in line 43 that begins:

```
**EMOM (`format: emom`, all listed exercises every minute) must NOT pair a cardio machine with a floor or carry station**
```

Replace the parenthetical and the next clause so the rule applies only to 1-2 exercise EMOMs (single-minute cycle), and notes that E2MOM (3+ exercises, 2-min cycle) is exempt because the 2-min frame leaves room. Keep the rest of the bullet (`isn't room for a meaningful cardio effort plus a floor round inside 30-45s.`).

Concretely, change the opening of the relevant sentence from:

```
**EMOM (`format: emom`, all listed exercises every minute) must NOT pair a cardio machine with a floor or carry station** — there isn't room for a meaningful cardio effort plus a floor round inside 30-45s.
```

to:

```
**Single-minute EMOM (`format: emom` with 1-2 exercises that share each minute) must NOT pair a cardio machine with a floor or carry station** — there isn't room for a meaningful cardio effort plus a floor round inside 30-45s. **E2MOM is exempt** (3+ exercises, 2-min cycle) — the 2-min frame leaves room for cardio + floor.
```

The remaining EMOM rules (single-exercise EMOM minimums; the cardio-paired BAD examples) stay as written.

- [ ] **Step 2: Re-run the prompt builder tests**

```bash
bin/rails test test/services/workout_llm_generator/contract_prompt_builder_test.rb
```

Expected: all green (these tests assert presence of substrings that we didn't change).

- [ ] **Step 3: Commit**

```bash
git add app/llm_context/shared/global_rules.md
git commit -m "docs(global_rules): exempt E2MOM from EMOM cardio+floor pairing ban"
```

---

## Tasks 7-13: Per-contract rewrites

Each per-contract task follows the same three-part shape: **strip duplicated `notes:`**, **strip duplicated `MOVEMENT_VOCABULARY`**, **rewrite all 3 EXAMPLES**.

The general rules are identical across all 7 contracts:

**A. Strip from `notes:`** (remove these paragraphs verbatim — they live in `hybrid_style.md` now):

- The "SUPPLEMENTARY MOVEMENTS (most sessions): weave KB Swings…" paragraph.
- The "STRENGTH ACCESSORY (most non-race-simulation sessions): include one strength accessory block…" paragraph (where present).
- The "DURATION INTERVALS: a 3-4 round work-rest block on a single conditioning movement…" paragraph (where present).
- The "An abs finisher (sit-ups, leg raises, planks, V-ups, Russian twists) is a good optional close-out." sentence.

**B. Strip from `MOVEMENT_VOCABULARY`** (remove these lines):

- `Supplementary: …`
- `Strength accessory: …`
- `Burpee variations: …`
- `Abs finisher: …`

Lines that are activity-specific (e.g. `Stations:`, `Run zones:`, `Burpee variations: Box Jump Burpees, …` if customised) stay.

**C. EXAMPLES rewrite rules** (per the spec):

- At minimum 2 of 3 examples per contract MUST feature an EMOM block, a 30/30 cardio block, OR a compromised-running block.
- Across all 21 examples, only Deka and Deka Fit have a `for_time` chipper example (one each, on the 60-min `Race Simulation`). No other example may be a long chipper.
- Canonical EMOM movements (wall balls, lunges, burpees, dead ball yoke over, sit-ups, box step-overs, KB swings, med ball slams, KB thrusters, shoulder press, floor-to-ceilings) when used **inside an EMOM** must omit `reps` and carry `notes: "~50% of your 1-min max (leaves ~20s rest)"`. Use plain rep numbers elsewhere.
- Honour the existing integrity test invariants: 3 examples, first section warm-up, last section cool-down, equipment in `allowed_equipment`, no banned-pattern exercise names.
- Honour contract-specific constraints (covered per-task below).

**D. After every rewrite, run:**

```bash
bin/rails test test/llm_context/contract_integrity_test.rb
```

It MUST stay green.

---

### Task 7: Hyrox

**Files:**
- Modify: `lib/llm_context/activities/hyrox.rb`

**Hyrox uniqueness to KEEP:**
- `banned_equipment` and `banned_exercise_patterns` for Assault/Air/Echo Bike.
- The "MANDATORY: every session must include at least 2 treadmill running intervals (500m–1km each)…" run-mandate.
- "Stations mirror the race: SkiErg, Sled Push/Pull, Burpee Broad Jumps, Rowing, Farmer's Carry, Sandbag Lunges, Wall Balls."
- "Every section must be meaningfully different — do not create two sections with the same exercises and structure but different names."
- The `Running:` and `Stations:` lines in `MOVEMENT_VOCABULARY`.

**Example shapes (3 total, none is a chipper):**

- `duration_mins: 30` — Mostly EMOM + compromised-running:
  - Warm-up (3 min, easy cardio).
  - EMOM 10 min on canonical movements (e.g. Wall Balls + KB Swings, both each minute, `~50% of 1-min max` cue, blank reps).
  - 3 rounds × `Compromised Run 500m` + 1-2 station movements with concrete reps.
  - Cool-down (2 min).
- `duration_mins: 45` — 30/30 cardio + station rounds + 1 strength accessory:
  - Warm-up (5 min).
  - 30/30 block: 10-12 min on treadmill (`duration_s: 30, rest_secs: 30` rounds). `intensity_style: high`.
  - Strength accessory rounds (3-6 reps heavy, 120s rest, `intensity_style: high`).
  - 4-round compromised-running circuit using race stations.
  - Cool-down (5 min).
- `duration_mins: 60` — Compromised running + EMOM family (race-prep mix, NO chipper):
  - Warm-up (5 min).
  - 4 rounds × `Compromised Run 800m + 30 Wall Balls + 20 Burpee Broad Jumps + 40m Farmer's Carry` (the canonical Hyrox shape from the spec).
  - E2MOM 10 min on 3 canonical movements (cue, blank reps).
  - Abs finisher (rounds × Sit-ups + V-ups + Plank).
  - Cool-down (5 min).

- [ ] **Step 1:** Strip the duplicated `notes:` paragraphs (per the general rules above).
- [ ] **Step 2:** Strip the duplicated `MOVEMENT_VOCABULARY` lines.
- [ ] **Step 3:** Replace the 3 EXAMPLES with workouts matching the shapes above.
- [ ] **Step 4:** Run `bin/rails test test/llm_context/contract_integrity_test.rb` — expect green.
- [ ] **Step 5:** Commit: `feat(hyrox): rewrite examples and adopt shared hybrid style`

---

### Task 8: Hybrid Race

**Files:**
- Modify: `lib/llm_context/activities/hybrid_race.rb`

**Hybrid Race uniqueness to KEEP:**
- "Stations draw from a wide library: Sled Push/Pull, SkiErg, Rowing, Air Bike, Farmer's Carry, Wall Balls, Sandbag Lunges, RAM Reverse Lunges, Box Jump, Med Ball Sit-up Throw, Dead Ball Yoke Over, Burpee Broad Jumps, Weighted Burpees."
- "Mix freely — most sessions use 4-6 stations, not all of them."
- Two-treadmill run-interval mandate.
- The `Running:` and `Stations:` lines in MOVEMENT_VOCABULARY.

**Example shapes (3 total, none is a chipper):**

- 30-min — EMOM + 30/30 cardio.
- 45-min — Compromised running + EMOM + strength accessory.
- 60-min — 30/30 multi-machine (5 min row → 5 min ski → 5 min bike) + compromised-running circuit + abs finisher.

- [ ] **Step 1:** Strip duplicated `notes:`.
- [ ] **Step 2:** Strip duplicated `MOVEMENT_VOCABULARY` lines.
- [ ] **Step 3:** Rewrite 3 EXAMPLES.
- [ ] **Step 4:** Run integrity test.
- [ ] **Step 5:** Commit: `feat(hybrid-race): rewrite examples and adopt shared hybrid style`

---

### Task 9: Deka

**Files:**
- Modify: `lib/llm_context/activities/deka.rb`

**Deka uniqueness to KEEP:**
- "10-zone event covering all Deka variants generically. Five run zones alternate with five functional zones."
- The race-simulation behaviour ("When race_simulation? is true the builder sets finisher: :required.")
- 10-zone station list: RAM Reverse Lunges, Row, Box Jump, Med Ball Sit-up Throw, SkiErg, Farmer's Carry, Air Bike, Dead Ball Yoke Over, Sled Push/Pull, RAM Weighted Burpees.
- The `Run zones:` and `Functional:` lines in MOVEMENT_VOCABULARY.

**Example shapes (3 total, including 1 chipper):**

- 30-min — EMOM (canonical movements) + 30/30 cardio.
- 45-min — Compromised running + EMOM + strength accessory.
- 60-min — **Full Race chipper** (current 10-zone `for_time` simulation). Keep the existing shape; this is one of the two allowed chippers.

- [ ] **Step 1:** Strip duplicated `notes:`.
- [ ] **Step 2:** Strip duplicated `MOVEMENT_VOCABULARY` lines.
- [ ] **Step 3:** Rewrite examples 1 and 2 (EMOM-heavy / 30-30 / compromised). Leave example 3 (Full Race) structurally as-is, but make sure it still passes integrity test after notes/vocab stripping.
- [ ] **Step 4:** Run integrity test.
- [ ] **Step 5:** Commit: `feat(deka): rewrite examples 1-2 and adopt shared hybrid style`

---

### Task 10: Deka Fit

**Files:**
- Modify: `lib/llm_context/activities/deka_fit.rb`

**Deka Fit uniqueness to KEEP:**
- "Deka Fit race training — 10-zone event, 5 run zones alternating with 5 functional zones. Running is half the race (10 × 500m)."
- "Stations mirror the race: RAM Reverse Lunges, Row, …, Weighted Burpees."
- `race_simulation` finisher behaviour.
- `Run zones:` and `Functional:` lines in MOVEMENT_VOCABULARY.

**Example shapes (3 total, including 1 chipper):**

- 30-min — EMOM + 30/30 cardio (high intensity).
- 45-min — Compromised running (500m runs, mixing in functional zones) + EMOM.
- 60-min — **Full Race chipper** (current 10-zone `for_time` simulation, all 10 zones). Keep structurally as the 2nd of 2 allowed chippers.

- [ ] **Step 1:** Strip duplicated `notes:`.
- [ ] **Step 2:** Strip duplicated `MOVEMENT_VOCABULARY` lines.
- [ ] **Step 3:** Rewrite examples 1 and 2 (EMOM-heavy / 30-30 / compromised). Leave example 3 (Full Race) structurally as-is.
- [ ] **Step 4:** Run integrity test.
- [ ] **Step 5:** Commit: `feat(deka-fit): rewrite examples 1-2 and adopt shared hybrid style`

---

### Task 11: Deka Strong

**Files:**
- Modify: `lib/llm_context/activities/deka_strong.rb`

**Deka Strong uniqueness to KEEP:**
- "No running. Build anaerobic capacity on ski erg, assault bike, or rower instead — 30s hard/30s easy or 400m repeats."
- `banned_exercise_patterns` for treadmill / run.
- 10-zone station list.
- `Stations:` and `Engine:` lines in MOVEMENT_VOCABULARY.

**Example shapes (3 total, none is a chipper, NO running):**

- 30-min — EMOM (canonical movements, no running) + station rounds.
- 45-min — 30/30 machine block (15 min: row 5 → ski 5 → bike 5) + EMOM + strength accessory.
- 60-min — 4 rounds × (250m row / 250m ski / 15 cal bike) as "compromised cardio rounds" (the compromised-running analogue) + EMOM + abs finisher.

> The `compromised running` shape doesn't apply (no running). Replace it with compromised-cardio circuit rounds that combine machine + functional work.

- [ ] **Step 1:** Strip duplicated `notes:`.
- [ ] **Step 2:** Strip duplicated `MOVEMENT_VOCABULARY` lines.
- [ ] **Step 3:** Rewrite 3 EXAMPLES.
- [ ] **Step 4:** Run integrity test.
- [ ] **Step 5:** Commit: `feat(deka-strong): rewrite examples and adopt shared hybrid style`

---

### Task 12: Deka Mile

**Files:**
- Modify: `lib/llm_context/activities/deka_mile.rb`

**Deka Mile uniqueness to KEEP:**
- "Running-heavy Deka variant. Treadmill mileage is the backbone of every session."
- "runs are usually longer than the 500m Deka Fit zone (800m–mile repeats are common)."
- "Engine-building blocks on treadmill should appear regularly (400m repeats, mile repeats, 4min hard efforts)."
- `Run blocks:` and `Stations:` lines in MOVEMENT_VOCABULARY.

**Example shapes (3 total, none is a chipper):**

- 30-min — 6 × 400m run repeats + EMOM (canonical movements).
- 45-min — Mile repeats × 3 (compromised between each mile with a station round) + EMOM.
- 60-min — 30/30 treadmill block + EMOM + compromised running with 800m runs.

- [ ] **Step 1:** Strip duplicated `notes:`.
- [ ] **Step 2:** Strip duplicated `MOVEMENT_VOCABULARY` lines.
- [ ] **Step 3:** Rewrite 3 EXAMPLES.
- [ ] **Step 4:** Run integrity test.
- [ ] **Step 5:** Commit: `feat(deka-mile): rewrite examples and adopt shared hybrid style`

---

### Task 13: Deka Atlas

**Files:**
- Modify: `lib/llm_context/activities/deka_atlas.rb`

**Deka Atlas uniqueness to KEEP:**
- "No running. Strongman-style barbell + DB stations."
- "Jump rope (Single/Double Unders) is the race-relevant cardio modality."
- "Machines exist for warm-up and engine work but the race-station cardio is jump rope."
- Wall ball and pull-up bar are banned.
- Atlas-specific stations: Barbell Thrusters, Bar-Facing Burpees Over Bar, Surrender Lunges, Single Arm DB Ground to Overhead, DB Bear Crawl, Weighted Sit-ups, DB Shoulder to Overhead Press, Jump Rope Single Unders, Atlas Shoulder to Carry.
- `Barbell:`, `Dumbbell:`, `Carries:`, `Bodyweight:` lines in MOVEMENT_VOCABULARY (these are Atlas-specific).

**Example shapes (3 total, none is a chipper — the current `Ten-Station Simulation` chipper is being REPLACED):**

- 30-min — EMOM (DB Bear Crawl + DB Shoulder Press + Weighted Sit-ups) + Jump Rope 30/30 (5 min).
- 45-min — Barbell EMOM (Thrusters + Bar-Facing Burpees) + Jump Rope 30/30 (10 min) + Atlas Carry rounds.
- 60-min — Compromised-cardio rounds (Jump Rope 60s / Atlas Carry 50m / DB Devil Press × N), 4 rounds + Barbell EMOM + abs finisher.

> Cardio blocks in Atlas examples MUST use jump rope (`equipment: "jump_rope"`), not row/ski/bike interval blocks. Machines can still appear in warm-ups.

- [ ] **Step 1:** Strip duplicated `notes:`.
- [ ] **Step 2:** Strip duplicated `MOVEMENT_VOCABULARY` lines (Supplementary, Burpee variations, Abs finisher).
- [ ] **Step 3:** Rewrite 3 EXAMPLES, including replacing the current `Ten-Station Simulation` chipper.
- [ ] **Step 4:** Run integrity test.
- [ ] **Step 5:** Commit: `feat(deka-atlas): rewrite examples and adopt shared hybrid style`

---

## Task 14: Full-suite verification + manual smoke

**Files:** none (verification only).

- [ ] **Step 1: Run the full test suite**

```bash
bin/rails test
```

Expected: all green. If anything in `test/llm_context/`, `test/services/workout_llm_generator/`, or any other suite fails, return to the relevant per-contract task and fix.

- [ ] **Step 2: Manual smoke test — generate one workout per race activity**

For each of the 7 race activities, generate one workout (any duration) via the Rails console or the existing generate UI. Eyeball the result for:

- At least one EMOM block OR a 30/30 cardio block OR a compromised-running block.
- Canonical EMOM movements inside EMOMs have empty `reps` and a "~50% of your 1-min max" notes cue.
- For Atlas: any cardio block uses jump rope, not row/ski/bike.
- For Deka Strong / Atlas: no running anywhere in the session.
- For Deka Mile: at least one 800m+ run interval.

If a generated workout doesn't reflect the spec, the issue is either in `hybrid_style.md` wording, the per-contract notes, or the example workouts (because the LLM mirrors examples heavily). Update the offending source file and re-generate.

- [ ] **Step 3: Final commit (if smoke surfaces wording tweaks)**

```bash
git add app/llm_context/shared/hybrid_style.md lib/llm_context/activities/
git commit -m "chore(hybrid_style): smoke-test refinements"
```

---

## Done criteria

- All 7 race-family contracts set `hybrid_family: true`.
- `app/llm_context/shared/hybrid_style.md` exists and is injected as `<hybrid_style>` for the 7 race contracts (and only them).
- The 7 contracts' `notes:` and `MOVEMENT_VOCABULARY` no longer contain the shared paragraphs.
- All 21 examples are rewritten; exactly 2 (Deka, Deka Fit) are long `for_time` chippers; the other 19 lead with EMOM / 30-30 / compromised-running.
- `bin/rails test` is green.
- Smoke test confirms the modalities show up in generated workouts.
