# Workout Prompt Rewrite — Contract Block Architecture

**Status:** Draft — awaiting spec review
**Date:** 2026-04-19
**Scope:** Restructure the prompt sent to Claude by `WorkoutLLMGenerator` so per-activity rules live in one data-driven "contract block" per activity, replace DB-fetched examples with hand-authored seeded examples, simplify warm-ups, and remove Tread & Shred as a distinct activity.

## Problem

`WorkoutLLMGenerator` currently composes its prompt from ~15 concatenated sections spread across a 2820-line service and a separate `app/llm_context/*.md` directory. Per-activity rules leak across six methods (`build_warmup_cooldown`, `warmup_cooldown_rule`, `build_session_structure`, `select_section_formats`, `sport_purity_rule`, `load_sport_context`) plus several constants (`FORMAT_AFFINITY`, `WARMUP_OPTIONS`, `COOLDOWN_OPTIONS`, `BODYWEIGHT_ONLY_SLUGS`, `SKIP_FORMAT_SELECTION_SLUGS`, `NO_WARMUP_COOLDOWN_SLUGS`, `CONTEXT_TAG_MAP`). Session-note behaviour flags (`no_run?`, `no_core?`, `race_simulation?`) and profile-equipment handling (`equipment_limited?`, `build_profile_equipment_rule`) add further scattered branching that the current prompt surfaces inconsistently.

The resulting prompt contradicts itself. Observed bugs before this work started:

- Iron Engine (kettlebell-only) sessions returning assault-bike intervals. The `kettlebell.md` context forbids cardio machines, but `build_warmup_cooldown` suggests an "easy row or bike" warm-up and `select_section_formats` picks cardio-focused format descriptions.
- Turbine sessions always finishing with a treadmill tabata. Turbine's guidance explicitly warns against this, but `build_session_structure` unconditionally appends `" → Finisher (Tabata 4 min or short for_time sprint)"` to the mandated structure.
- Sprint intervals with rest longer than work (e.g. 10s work / 45s rest). The Turbine guidance itself prescribes rest > work; no global rule caps the ratio.

Immediate bugs were patched in a preceding commit (kettlebell added to `SKIP_FORMAT_SELECTION_SLUGS`, Iron Engine warm-up branch added, Turbine finisher branch added, sprint ratios corrected, validator gained a `fix_rest_ratio` check). This spec addresses the structural cause: scattered rules that inevitably drift apart.

## Goals

1. Per-activity knowledge lives in one data structure, read once, used consistently.
2. Prompt composition is deterministic: same inputs → identical prompt. No random pool sampling for warm-ups or example selection.
3. The LLM receives ~2–3k tokens of prompt instead of ~4–6k, with no duplicate coverage and no shouting tone compensating for bad structure.
4. Adding a new activity is one file (`app/llm_context/activities/<slug>.rb`), not seven edits across six locations.
5. The full `WorkoutLLMGenerator` refactor (splitting the service into focused classes) is explicitly out of scope — deferred to a separate spec.

## Non-goals

- Refactoring `WorkoutLLMGenerator` into multiple classes. The service will get smaller and cleaner as old code deletes, but splitting into `PromptBuilder` / `FormatPicker` / `ContractLoader` is a separate future spec.
- Changing the `Workout`, `Activity`, or `Tag` data model.
- Moving existing Tread & Shred workouts in the database.
- Automated LLM output-quality tests. Quality is verified by the validator rules and manual eyeball. (See also Out of scope.)

## Design

### 1. Directory layout

```
app/llm_context/
  activities/
    iron_engine.rb          # Kettlebell — Iron Engine
    turbine.rb              # Pure cardio
    alternator.rb           # Hybrid (absorbs T&S treadmill-only)
    circuit_breaker.rb      # Functional / F45
    dynamo.rb               # HIIT / bodyweight
    transformer.rb          # Strength
    ohm.rb                  # Yoga / mobility / pilates
    hyrox.rb
    deka.rb
    deka_fit.rb
    deka_strong.rb
    deka_mile.rb
    deka_atlas.rb
    volt_octathlon.rb
    functional_muscle.rb
    crossfit.rb
    general_fitness.rb
  shared/
    global_rules.md         # JSON shape, naming, rest ≤ work, variety
    warm_up_cool_down.md    # Shared warm-up and cool-down vocabulary
```

Filenames use underscores (not hyphens) so Zeitwerk autoloads them as `LLMContext::Activities::IronEngine`, `CircuitBreaker`, `DekaFit`, etc. The slug inside each file keeps the hyphenated form (`SLUG = "iron-engine"`) that matches the DB.

The existing `app/llm_context/*.md` files are absorbed into each activity's Ruby file as a `CONTEXT` / `MOVEMENT_VOCABULARY` string constant and then deleted.

### 2. Shape of each activity file

Each activity file defines one module with:

- `SLUG` — canonical activity slug.
- `NAME` — display name.
- `CONTRACT` — a frozen hash with a fixed set of keys (see below).
- `MOVEMENT_VOCABULARY` — optional short prose string of movement vocabulary, for activities that need one (Iron Engine, CrossFit, Deka variants, Hyrox, Functional Muscle, Volt Octathlon). Omitted where obvious.
- `EXAMPLES` — a frozen array of exactly 3 workout hashes, hand-authored. Each has `name`, `goal`, `duration_mins`, `sections`. These replace `fetch_top_liked_examples` entirely.

**Required `CONTRACT` keys:**

| Key | Type | Purpose |
|---|---|---|
| `purity` | String | One-paragraph statement of what the activity fundamentally is and is not. |
| `allowed_equipment` | Array<String> | Equipment canonically allowed (main sections). |
| `banned_equipment` | Array<String> | Equipment explicitly banned in main sections. |
| `allowed_formats` | Array<String> | Full set of section formats this activity can use. |
| `primary_formats` | Array<String> | Subset preferred for main blocks. Used by the prompt to guide format picking, replacing `FORMAT_AFFINITY`. |
| `warm_up` | Symbol | Key into `shared/warm_up_cool_down.md` vocabulary. |
| `cool_down` | Symbol | Key into shared vocabulary. |
| `finisher` | Symbol | `:optional` / `:required` / `:forbidden`. Replaces the hard-coded "Finisher (Tabata 4 min…)" in `build_session_structure`. |
| `core` | Symbol | `:optional` / `:required` / `:never`. Replaces `core_section_rule`'s random 2/3-of-the-time injection for activities where core has a definite answer. |
| `signature_formats` | Array<String> | Optional. Formats the prompt should highlight as "the essence of this activity" (e.g. Iron Engine: `%w[complex flow carry]`). |
| `notes` | String | Optional additional prose rolled into the contract block. Short. |

**Composition with athlete profile and session notes.** The contract is the activity's baseline. The prompt builder composes it with:

- **Athlete profile equipment.** If the profile reports no barbell, `banned_equipment` gains `"barbell"` for this request even when the activity's baseline allows it. `equipment_limited?` and `build_profile_equipment_rule` (today's methods) collapse into a single `compose_banned_equipment(contract, profile)` step.
- **Session-note flags.** `no_run?`, `no_core?`, and `race_simulation?` translate into contract overrides at request time — e.g. `no_run?` pushes `"treadmill"` onto `banned_equipment` and removes `run` from `allowed_exercises` if present; `no_core?` forces `core: :never`; `race_simulation?` flips `finisher: :required` for Deka/Hyrox. These overrides live in the prompt builder, not in per-activity files, so the activity contracts stay small.

**Example — `iron-engine.rb`:**

```ruby
module LLMContext::Activities::IronEngine
  SLUG = "kettlebell"
  NAME = "Iron Engine"

  CONTRACT = {
    purity: "KETTLEBELL ONLY. Every main/finisher exercise must use a kettlebell. " \
            "No cardio machines, barbells, dumbbells, bodyweight conditioning, or jump rope " \
            "in main sections. Warm-up is KB + activation only.",
    allowed_equipment: %w[kettlebell],
    banned_equipment:  %w[barbell dumbbell cardio_machines jump_rope med_ball sled rings],
    allowed_formats:   %w[rounds emom for_time amrap ladder tabata hundred mountain],
    primary_formats:   %w[rounds emom for_time amrap],
    warm_up:           :kb_activation,
    cool_down:         :full_body_stretch,
    finisher:          :optional,
    core:              :never,
    signature_formats: %w[complex flow carry],
    notes: "Complexes, flows, and carries are Iron Engine's signature formats — " \
           "at least one should appear in most sessions."
  }.freeze

  MOVEMENT_VOCABULARY = <<~VOCAB
    Ballistic: KB Swing, KB Snatch, KB Clean, KB Long Cycle, Double KB Swing, KB SDHP
    Grind:    KB Goblet Squat, KB Front Squat, KB Press, KB Push Press, KB Row, KB Deadlift, KB Windmill, KB TGU
    Complex:  Clean → Press → Front Squat → Row → Swing  (and similar flows)
    Carry:    KB Farmer's Carry, KB Rack Carry, KB Overhead Carry, KB Waiter Walk
  VOCAB

  EXAMPLES = [
    { name: "The Blacksmith",
      goal: "Heavy grinds bookended by ballistic bursts.",
      duration_mins: 45,
      sections: [...] },
    # two more
  ].freeze
end
```

A tiny registry in `app/lib/llm_context/activities.rb` maps slug (hyphenated) → module constant. Slug `"iron-engine"` resolves to `LLMContext::Activities::IronEngine`. The generator does:

```ruby
activity = LLMContext::Activities.for(@activity_slug)
contract = activity::CONTRACT
```

The registry also resolves `ACTIVITY_ALIASES` transparently (`iron-engine`, `hybrid-training`, etc. → their canonical module).

### 3. The rewritten prompt

Assembled in this fixed order, using XML tags (which Claude parses more reliably than markdown headers):

```
<role>
You are an expert personal trainer who writes creative, effective gym workouts.
</role>

<athlete>
…name, goals, equipment, recent PBs, pace limits, recent workout names…
</athlete>

<task>
Generate a 45-minute Iron Engine session.
</task>

<contract>
Activity: Iron Engine (kettlebell)

PURITY: KETTLEBELL ONLY. Every main/finisher exercise must use a kettlebell…
ALLOWED EQUIPMENT: kettlebell
BANNED EQUIPMENT: barbell, dumbbell, cardio machines, jump rope, med ball, sled, rings
ALLOWED FORMATS: rounds, emom, for_time, amrap, ladder, tabata, hundred, mountain
PRIMARY FORMATS: rounds, emom, for_time, amrap
SIGNATURE FORMATS (use at least one in most sessions): complex, flow, carry
WARM-UP STYLE: KB + bodyweight activation, no cardio machines
COOL-DOWN STYLE: full-body stretch
FINISHER: optional
CORE SECTION: never

Movement vocabulary:
  Ballistic: KB Swing, KB Snatch, …
  Grind:    KB Goblet Squat, KB Front Squat, …
  …

Complexes, flows, and carries are Iron Engine's signature formats — at least one
should appear in most sessions.
</contract>

<global_rules>
- rest_secs must never exceed the working duration of any set.
- At least 3 different formats across the session. No two adjacent sections share a format.
- Exercise names are the movement only — no embedded reps, durations, or descriptors.
- Rep counts are clean numbers (even, or multiples of 5).
- Give the workout a punchy, memorable, original name. Banned words: [session-type brands]
- Goal field: one short motivational sentence about energy and training effect.
</global_rules>

<session_shape>
Warm-up (5 min) → 2 main sections → Cool-down (5 min).
Working time: 35 min. Do NOT set duration_mins on main sets.
</session_shape>

<examples>
Three Iron Engine workouts that show the quality bar and style. Study
structure, exercise selection, format variety, and naming. Create something
fresh in the same spirit — do not copy.

[JSON serialisation of IronEngine::EXAMPLES]
</examples>

<session_notes>
[if the athlete provided notes — sanitised as today]
</session_notes>
```

Generator pseudocode:

```ruby
def build_contract_prompt
  activity = LLMContext::Activities.for(@activity_slug)
  tags = []
  tags << xml(:role, ROLE_TEXT)
  tags << xml(:athlete, build_athlete_block)
  tags << xml(:task, "Generate a #{@duration_mins}-minute #{activity::NAME} session.")
  tags << xml(:contract, build_contract_block(activity))
  tags << xml(:global_rules, GLOBAL_RULES)
  tags << xml(:session_shape, build_session_shape(activity::CONTRACT))
  tags << xml(:examples, serialise_examples(activity::EXAMPLES))
  tags << xml(:session_notes, sanitized_notes) if @session_notes.present?
  tags.join("\n\n")
end
```

### 4. Warm-up and cool-down simplification

Four warm-up styles and four cool-down styles, defined once in `app/llm_context/shared/warm_up_cool_down.md`. Each activity picks one via its contract — no random sampling, no `WARMUP_OPTIONS` constant.

Every warm-up style boils down to **easy cardio (3 min for ≤30-min sessions, 5 min otherwise) + dynamic stretches**. The exercise-name field just says "dynamic stretches" — no need to name individual movements. Activity-specific styles differ in what counts as the cardio piece and whether anything replaces it entirely (e.g. Iron Engine swaps cardio for KB activation).

**Warm-up styles:**

| Key | Description | Used by |
|---|---|---|
| `:easy_cardio` | Easy cardio (3 min / 5 min) at conversational pace + dynamic stretches. Machine varies from the main session's machine. | Turbine, Transformer, Alternator, Circuit Breaker, Deka variants, Hyrox, CrossFit, Volt Octathlon, Functional Muscle, General Fitness |
| `:kb_activation` | KB halos + light swings + goblet squats + dynamic stretches. No machines ever. | Iron Engine |
| `:bodyweight_activation` | Easy bodyweight cardio (3 min / 5 min) + dynamic stretches. No equipment, no machines. | Dynamo, bodyweight-only |
| `:flow` | Yoga/pilates-style activation flow — part of the session content. | Ohm |

**Cool-down styles:**

| Key | Description |
|---|---|
| `:full_body_stretch` | 4–6 stretches covering hips, hamstrings, chest, shoulders, spine. Default. |
| `:lower_focus` | Hip flexors, pigeon, quads, hamstrings, spinal twist. |
| `:upper_focus` | Chest opener, cross-body shoulder, thread the needle, lat stretch. |
| `:savasana` | Longer holds, quiet. For Ohm. |

**Rules that replace today's ~70 lines of warm-up/cool-down prose:**

- Warm-up is first, cool-down is last. One sentence.
- Warm-up length: 3 min for ≤30-min sessions, 5 min otherwise.
- Cool-down length: 2 min for ≤30-min sessions, 5 min otherwise.
- Warm-up content defaults to easy cardio + "dynamic stretches" as a single exercise name — the prompt does not list which stretches.
- Cool-down notes: 5 deep breaths for short sessions, 10 for long.
- Contract style key expands to a short prose block in the shared vocabulary; the prompt builder injects it into the `<session_shape>` tag.
- No random sampling. Variety (which 4 of 6 stretches to pick) happens inside the vocabulary prose, driven by the LLM.

**Deletions:**

- `WARMUP_OPTIONS` constant (11 entries).
- `COOLDOWN_OPTIONS` constant (4 entries).
- `build_warmup_cooldown` method (~40 lines).
- `warmup_cooldown_rule` method (~30 lines).
- `skip_warmup_cooldown?` and `NO_WARMUP_COOLDOWN_SLUGS` (Ohm's behaviour is now expressed by `warm_up: :flow, cool_down: :savasana` in its contract).

### 5. Tread & Shred removal

T&S is removed as a distinct activity. Alternator (Hybrid) with treadmill-focused session notes covers the same use case.

**Code changes:**

1. Delete `app/llm_context/barrys.md`.
2. Remove `tread-shred` from `CONTEXT_TAG_MAP`, `FORMAT_AFFINITY`, `SKIP_FORMAT_SELECTION_SLUGS`.
3. Update `ACTIVITY_ALIASES`:
   - Remove `"barry-s" => "tread-shred"`, `"barry-s-bootcamp" => "tread-shred"`.
   - Add `"tread-shred" => "alternator"`, `"barrys" => "alternator"`, `"barry-s" => "alternator"`, `"barry-s-bootcamp" => "alternator"`.
4. Alternator's contract gains a short note: *"When the athlete's session notes or equipment strongly imply treadmill-focused training, anchor the session around treadmill intervals and keep the floor work tight."*
5. **Grep audit before merging:** run `rg -i 'tread.?shred|barry'` across `app/`, `config/`, `db/seeds/`, and `test/` and confirm every remaining reference is either (a) an alias entry added in step 3 or (b) a seed row that should stay for existing users. Anything else — a leftover method branch, view copy, or test fixture — is removed or rerouted to Alternator.

**Data:** Existing `Activity` and `Workout` records are untouched. Users who already have T&S workouts keep them. New generation for T&S slugs routes to Alternator.

### 6. Migration sequencing

Five phases, each independently deployable.

**Phase 1 — Scaffolding (no behaviour change)**
- Add `app/lib/llm_context/activities.rb` registry.
- Add `app/llm_context/activities/iron_engine.rb` with full contract, vocabulary, 3 examples.
- Add `app/llm_context/shared/global_rules.md` and `shared/warm_up_cool_down.md`.
- Registry-resolution tests and contract-integrity tests for Iron Engine.
- Generator is untouched; existing behaviour is untouched.

**Phase 2 — Iron Engine cutover (dual-path)**
- Add `build_contract_prompt` method to `WorkoutLLMGenerator`.
- Gate routing on `ENV["WORKOUT_PROMPT_CONTRACT_ACTIVITIES"]` (comma-separated slugs). When `"iron-engine"` is present, Iron Engine generations call `build_contract_prompt`; everything else keeps `build_example_prompt`. The env var makes rollback a deploy-less config flip.
- Log at INFO level per generation: activity slug, prompt path used (`example` or `contract`), prompt token estimate, and validator fix count. This gives side-by-side evidence for the two paths during the shakeout window.
- The `:kb_activation` prose required for Iron Engine was already introduced in the preceding surgical-fixes commit (`build_warmup_cooldown`'s kettlebell branch). Phase 2 moves that prose into `shared/warm_up_cool_down.md` rather than re-inventing it; the old branch deletes in Phase 4.
- Add prompt-shape tests for Iron Engine.
- Manual staging check: generate 3 Iron Engine workouts at 30/45/60 min under each path; eyeball for bleed and compare.
- Adjust the contract shape if needed before scaling.

**Phase 3 — Fill out remaining activity files**
- Author contract + 3 examples + vocabulary for each remaining activity.
- Order: purity-sensitive first (Turbine, Dynamo, Ohm, Hyrox, Deka variants), then Alternator/Transformer/Circuit Breaker/CrossFit/Volt Octathlon/Functional Muscle/General Fitness.
- Each activity flips over individually once its file passes contract-integrity and prompt-shape tests.

**Phase 4 — Collapse the old path**
- Delete `build_example_prompt`, `build_prompt`, `fetch_top_liked_examples`, `fetch_context`, `load_sport_context`, `build_research_context`, `build_warmup_cooldown`, `warmup_cooldown_rule`.
- Delete constants: `FORMAT_AFFINITY`, `WARMUP_OPTIONS`, `COOLDOWN_OPTIONS`, `TRAINING_EMPHASES`, `NO_WARMUP_COOLDOWN_SLUGS`, `BODYWEIGHT_ONLY_SLUGS`, `SKIP_FORMAT_SELECTION_SLUGS`, `CONTEXT_TAG_MAP`.
- Delete `app/llm_context/*.md` files that have been absorbed.
- Execute the T&S removal (§5).
- Tighten `build_session_structure` into `build_session_shape` (uses `CONTRACT[:finisher]` and `CONTRACT[:core]`).

**Phase 5 — Service refactor**
- Out of scope. Separate spec.
- Split `WorkoutLLMGenerator` into `PromptBuilder`, `FormatPicker`, `ContractLoader`, etc.

The value of this sequencing: Phase 2 produces real evidence (actual Iron Engine outputs) that the contract approach works before we invest in 16 more activity files. If Iron Engine looks bad, the contract shape adjusts first.

## Testing strategy

1. **Contract integrity tests** (`test/lib/llm_context/activities_test.rb`) — one test per activity:
   - Module loads.
   - `CONTRACT` has every required key.
   - `warm_up` and `cool_down` values are keys in shared vocabulary.
   - `EXAMPLES` has exactly 3 entries, each with `name`, `goal`, `duration_mins`, `sections`.
   - Each example's `sections` has a warm-up first, cool-down last, valid formats throughout.
   - Banned-equipment coverage has two distinct checks:
     - **Category match:** every exercise's `equipment` field (where present) is in `allowed_equipment` and not in `banned_equipment`.
     - **Name-pattern match:** exercise names match no banned-vocabulary regex. Each activity contract carries an optional `banned_exercise_patterns` array (e.g. Iron Engine bans `/\bassault bike\b/i`, `/\btreadmill\b/i`, `/\brow(er)?\b/i`). This catches LLM-authored names that embed forbidden equipment even when the `equipment` field looks clean.

2. **Registry tests** — every slug and alias resolves; T&S routes to Alternator.

3. **Prompt shape tests** (`test/services/workout_llm_generator_prompt_test.rb`) — stub the LLM call, generate the prompt, assert on:
   - Presence and order of `<contract>`, `<global_rules>`, `<session_shape>`, `<examples>` tags.
   - Banned-equipment line matches the contract exactly.
   - `<examples>` contains 3 JSON workouts.
   - `<global_rules>` contains the `rest_secs ≤ work` rule.
   - Regression checks:
     - Iron Engine prompt never contains the strings "cardio_intervals", "death_race", "switchback".
     - Turbine prompt never contains "Finisher (Tabata 4 min or short for_time sprint)".
     - Turbine prompt sprint combos are only `20s/10s`, `20s/20s`, `30s/15s`, `30s/30s`.

4. **Validator tests** — existing `WorkoutValidator` tests, plus `fix_rest_ratio` (already added).

5. **Prompt snapshot tests** (optional) — record a prompt per activity at 30/45/60 min; fail on unintended drift.

6. **Manual eyeball at phase boundaries** — gate each phase cutover on generating a handful of workouts per activity and skimming for bleed.

**Not tested automatically:** LLM output quality. The validator catches violations; the prompt shape prevents them. No end-to-end LLM tests.

## Risks

- **Authoring burden.** Writing 3 good example workouts × ~16 activities is real work. Mitigated by the phased rollout — only Iron Engine is needed before Phase 3 begins, and each activity flips independently.
- **Loss of organic community signal.** `fetch_top_liked_examples` reflected what real users liked. Replacing it with curated examples trades freshness for determinism. Mitigated by treating the examples as a living set — they can be updated whenever the DB surfaces better ones.
- **XML-tag change could surprise the model.** Claude is well-calibrated for XML-delimited prompts, but the current prompt uses markdown headers. Phase 2's dual-path lets us compare outputs directly before committing.
- **Contract schema drift.** As activities are authored, new contract keys may feel needed. Mitigated by starting with the listed keys only and adding new ones deliberately (with a migration across all activities when added).

## Out of scope

- Full `WorkoutLLMGenerator` service refactor (separate future spec).
- Data migration for existing T&S workouts.
- Changes to the `Workout`, `Activity`, or `Tag` data model.
- Any UI changes.

(Automated LLM-output-quality testing is covered in Non-goals — the validator and prompt-shape tests are the two lines of defence.)
