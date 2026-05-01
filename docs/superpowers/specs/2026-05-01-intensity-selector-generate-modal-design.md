# Intensity Selector in Generate Modal

## Goal

Promote the existing `intensity_style` dial out of free-text Training Notes into an explicit pill selector on the workout generate modal. Today the LLM picks an intensity style (`zone_2` / `conditioning` / `max_effort`) per section based on keywords it spots in the user's session notes (`zone 2`, `tempo`, `max effort`, etc.). Users who want a session-wide intensity have to know which keywords trigger the behaviour. This change makes that dial first-class: a 4-option selector that, when set, becomes a session-wide directive applied to every main and finisher section.

## Background

Commit `e3df242` (28 Apr 2026) landed the schema, prompt rules, and validator carve-outs for `intensity_style` (phases 1-3). Each section in the LLM tool schema accepts an optional `intensity_style` enum. The validator already gives `max_effort` its own rest grid (`90/120/150/180`) and exempts it from the rest-≤-work rule. The commit body explicitly flags phase 4 (UI selector) as remaining work — this spec covers phase 4 only.

## Scope

**In scope:**
- New pill-row selector on `app/views/workouts/_generate_modal.html.erb`.
- Plumbing the selected value through `WorkoutsController` → `WorkoutLLMGenerator` → `ContractPromptBuilder` → prompt XML.
- One new line in `app/llm_context/shared/global_rules.md` describing how the LLM should treat the new tag.
- Tests covering the param flow and prompt rendering.

**Out of scope:**
- Section badge / display of intensity in workout cards (deferred phase — separate decision: surface in description copy, not as a badge).
- Programs creation form (`app/views/programs/new.html.erb`). A multi-week program needs per-day or per-week intensity targeting, which is a larger design.
- Validator changes — already correct for all three styles.
- Workout edit/builder form selector (could come later; not requested).
- Example workout updates (phase 6 from the original commit).

## UI

### Placement
The new pill row sits inside `_generate_modal.html.erb` directly above the **Training Notes** textarea. Reading order becomes: Workout Type → **Intensity** → Training Notes → Equipment → Injuries → Duration → Submit. This places the explicit dial before the freeform notes so the user sets the high-level shape first and uses notes only for nuance.

### Options
Four options, displayed as horizontal rounded-full pills (matches the existing "Recent" pill pattern further up the form, not the larger "Workout Type" tile pattern):

| Pill label    | Submitted value | Behaviour                                         |
| ------------- | --------------- | ------------------------------------------------- |
| Mixed         | `""` (empty)    | Default selected. No-op — LLM behaves as today.   |
| Zone 2        | `zone_2`        | Session-wide directive: every main/finisher section uses zone_2. |
| Conditioning  | `conditioning`  | Session-wide directive: every main/finisher section uses conditioning. |
| Max Effort    | `max_effort`    | Session-wide directive: every main/finisher section uses max_effort. |

`Mixed` is the default and ships submitted as an empty string. The controller treats it as `nil` and nothing about the prompt changes versus today. The existing keyword-detection in session notes continues to function as a fallback.

### Markup pattern
Use `radio_button_tag "intensity_style", value, default_check, ...` with `peer sr-only` plus a styled label, mirroring the existing pattern used by the "Workout Type" radios. A short heading row above the pills reads `INTENSITY` (uppercase, tracking-wide, gray-300, matching the other section headers). No subheading text — the labels are self-explanatory.

The Stimulus controller `generate-form` does not need to change. Standard browser radio behaviour handles the selection state; CSS handles the lime-400 selected ring via `peer-checked:` utilities.

## Plumbing

### 1. Form submission
The form already posts to `workouts_path`. The new radio adds `intensity_style` to the post body. Empty string when Mixed is selected.

### 2. `WorkoutsController#create`
Read `params[:intensity_style]`, sanitise to one of `%w[zone_2 conditioning max_effort]` or `nil`. Pass through alongside `session_notes` when constructing `WorkoutLLMGenerator`.

```ruby
intensity_style = params[:intensity_style].presence_in(%w[zone_2 conditioning max_effort])
```

### 3. `WorkoutLLMGenerator#initialize`
Add `intensity_style:` keyword argument (default `nil`). Store on `@intensity_style`. Pass into `ContractPromptBuilder.new(...)`. Existing callers that don't supply this kwarg (program code paths) keep working without change.

### 4. `ContractPromptBuilder`
Accept `intensity_style:` kwarg in `initialize`. In the prompt-rendering method that already emits `<session_notes>`, also emit:

```xml
<intensity_style>zone_2</intensity_style>
```

immediately above `<session_notes>` when present. Omit the tag entirely when `nil` or blank — never render an empty `<intensity_style></intensity_style>` tag.

### 5. `app/llm_context/shared/global_rules.md`
Add one rule under or beside the existing **Intensity style** bullet:

> If `<intensity_style>` is provided in the user input, treat it as a session-wide directive: apply that style to every `main` and `finisher` section, overriding any keyword detection in `<session_notes>`. Warm-up and cool-down sections are unaffected.

The existing per-section style behaviour remains intact for the no-tag case.

## Data flow

```
generate modal radio
  └─> POST /workouts (intensity_style param)
        └─> WorkoutsController#create
              └─> WorkoutLLMGenerator.new(... intensity_style: ...)
                    └─> ContractPromptBuilder.new(... intensity_style: ...)
                          └─> <intensity_style>...</intensity_style> tag in prompt
                                └─> LLM applies style to every main/finisher section
                                      └─> sections persist with intensity_style field
                                            └─> validator already handles per-style rest grids
```

## Testing

Three tests cover the change:

1. **Controller test** (`test/controllers/workouts_controller_test.rb`)
   Submit the create form with `intensity_style=zone_2` and assert the value is propagated to `WorkoutLLMGenerator` (mock or stub the generator and assert kwargs). Submit with `intensity_style=""` and assert `nil` is passed (or kwarg omitted).

2. **Generator/prompt test** (`test/services/workout_llm_generator/contract_prompt_builder_test.rb` or equivalent)
   - Build prompt with `intensity_style: "zone_2"` → assert prompt string contains `<intensity_style>zone_2</intensity_style>`.
   - Build prompt with `intensity_style: nil` → assert prompt string does NOT contain `<intensity_style>`.
   - Build prompt with `intensity_style: "garbage"` (defensive) → controller should have rejected it, but if a stray value reaches the builder it should still render only valid values; alternatively assert builder raises or coerces. Decision deferred to implementation: simplest is to trust the controller and pass through verbatim.

3. **No-regression check**
   Existing `WorkoutValidator` tests must remain green; they already cover the three styles.

## Risks and non-obvious bits

- **Multiple call sites for `WorkoutLLMGenerator`.** The generator is invoked from `WorkoutsController` and from program-related code paths (`Program::WorkoutBuilder`, `ProgramBuilder`, `RetryProgramSlotJob`). Adding a kwarg with a default of `nil` keeps every existing caller working. The implementation must not make the kwarg required.
- **Param name collision check.** `intensity_style` is not currently a top-level param on the workout create endpoint. Confirm during implementation by grepping the controller's permitted-params and existing form fields.
- **Prompt ordering matters.** The new XML tag should appear above `<session_notes>` so the LLM reads the directive before the freeform context. The global rule explicitly says the directive overrides keyword detection in notes, so order reinforces priority.
- **Mobile layout.** Four pills on a phone width: keep them in a single row using `flex flex-wrap gap-2` so they wrap if narrow. Each pill compact (`px-3 py-1.5 text-xs`).
- **Accessibility.** Each radio gets a unique `id` for label association. The visually hidden input still receives keyboard focus and the `peer-checked:` styles surface the selection state visibly.

## Future phases (not part of this spec)

- **Phase 5 — surfacing.** When showing intensity to the user (workout description, share image, etc.), weave it into the description text rather than rendering a coloured badge or chip on the workout card. Example phrasing: *"a zone 2 workout to build stamina."*
- **Phase 6 — example updates.** Update bundled example workouts in `app/llm_context/` to use explicit `intensity_style` values where appropriate.
- **Programs.** A program-level intensity dial likely needs to be per-week or per-day rather than per-program; defer until single-workout flow has been observed in use.
