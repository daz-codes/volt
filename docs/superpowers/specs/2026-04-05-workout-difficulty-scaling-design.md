# Workout Difficulty Scaling

**Date:** 2026-04-05
**Status:** Draft

## Overview

A 5-level difficulty scaling system that lets users adjust any workout to their fitness level. Workouts default to a personalised difficulty based on the user's posting history, and can be scaled up or down from the workout show page. Scaling is server-side with Turbo frame replacement, using deterministic rules for moderate adjustments and targeted LLM calls for extreme levels.

## Difficulty Levels

| Level | Label | Method |
|-------|-------|--------|
| 1 | Beginner | LLM call — intelligent exercise substitutions, gentler structure |
| 2 | Easy | Deterministic — ~20% reduction in volume |
| 3 | Intermediate | Original workout as generated/created (source of truth) |
| 4 | Hard | Deterministic — ~20% increase in volume |
| 5 | Elite | LLM call — harder substitutions, more demanding structure |

## Data Model

### workouts table

Add `original_structure` (jsonb, nullable).

- Set when the workout is first created, generated, or scanned — identical to `structure` at creation time.
- Never modified after initial set.
- When a user scales and saves/edits a workout, `structure` updates to the scaled version; `original_structure` stays untouched.
- For existing workouts predating this feature, `original_structure` is null — `structure` is treated as the level 3 source.
- All scaling operations derive from `original_structure || structure`.

### workout_logs table

Add `difficulty_level` (integer, default 3).

- Written when a user posts a workout, reflecting the difficulty level they were viewing at.
- Used to calculate the user's personalised default difficulty.
- Existing workout logs default to 3.

## Scaling Logic — Scalable Concern

`app/models/concerns/scalable.rb`, included in the `Workout` model.

### Public API

```ruby
workout.scale_to(level)
# => Hash — a new structure scaled to the given level
# Source: workout.original_structure || workout.structure
```

### Deterministic Rules (Levels 2 and 4)

Applied per section format. Warm-up and cool-down sections are **never scaled**.

| Format | Scale Down (level 2) | Scale Up (level 4) |
|--------|---------------------|-------------------|
| rounds | Reduce rounds by 1 (min 2) | Add 1 round |
| ladder | Shrink range (e.g. 10-1 → 8-1) | Extend range (e.g. 10-1 → 12-1) |
| mountain | Lower peak by 1-2 | Raise peak by 1-2 |
| emom | Reduce duration by 2 min, reps by ~20% | Increase duration by 2 min, reps by ~20% |
| tabata | No change (format is fixed 8 rounds) | No change |
| hundred | 80 reps | 120 reps |
| for_time | Reduce rounds by 1 or reps by ~20% | Add 1 round or increase reps by ~20% |
| amrap | Reduce reps by ~20% | Increase reps by ~20% |
| straight | Reduce reps by ~20% | Increase reps by ~20% |

Exercise-level adjustments:
- **Reps:** multiply by 0.8 (down) or 1.2 (up), round to clean numbers (multiples of 5 preferred).
- **Distances:** ±25%, snapped to round numbers (running: 100m multiples, other: 25m multiples).
- **Calories:** ±20%, snapped to multiples of 5.
- **Weight cues in notes:** shift language — "heavy" → "moderate" → "light-moderate" → "light" for scaling down; reverse for scaling up.
- **duration_s:** unchanged (time-based exercises stay the same).

### LLM Scaling (Levels 1 and 5)

Sends the original level 3 structure to Claude Haiku with a scaling prompt. Uses the same `create_workout` tool definition as generation to guarantee schema compliance.

The prompt instructs the LLM to:
- Substitute exercises for easier (level 1) or harder (level 5) alternatives.
- Adjust rep schemes, rounds, and distances.
- Modify weight cues appropriately.
- Keep the same overall session shape, section names, and section count.
- Leave warm-up and cool-down untouched.

The LLM returns a complete replacement structure.

## Personalised Default — HasDefaultDifficulty Concern

`app/models/concerns/has_default_difficulty.rb`, included in the `User` model.

### Public API

```ruby
user.default_difficulty_level
# => Integer 1-5
```

### Calculation

- Takes the last 20 posted workout logs' `difficulty_level` values.
- Applies exponential decay weighting — most recent post has the highest weight, older posts decay.
- Rounds to nearest integer, clamped to 1-5.
- Returns 3 if no posting history.

No caching — the query is cheap (20 rows, single user scope, indexed by user_id + completed_at).

## Controller & Routing

### Route

```ruby
resources :workouts do
  member do
    post :scale
  end
end
```

### workouts#scale Action

- Receives `params[:direction]` ("up" or "down") and `params[:current_level]`.
- Calculates target level (clamp 1-5).
- Calls `@workout.scale_to(target_level)`.
- Responds with Turbo Stream or Turbo Frame replacement of `workout_preview`, passing the scaled structure and current level to the preview partial.

The scaled structure is **ephemeral** — not persisted to the workout. It only persists when:
- The user edits and saves the workout (updates `structure`).
- The user posts the workout (records `difficulty_level` on the workout log).

### State Management

The current difficulty level is tracked via **data attributes** on the difficulty control buttons — no session state. The Stimulus controller reads `data-difficulty-level` and sends it with each scale request. State resets naturally on navigation.

## UI Design

### Workout Show Page — Header

The difficulty control appears in the workout header, right-aligned next to the workout name:

```
[Workout Name]                    [−] ●●●○○ [+]
[Activity] · [Duration]              DIFFICULTY
```

- 5 equal-sized dots: green (filled) up to current level, grey for the rest.
- "DIFFICULTY" label underneath the dots in small uppercase text.
- `−` button disabled/faded at level 1; `+` button disabled/faded at level 5.
- Both buttons submit POST to `scale_workout_path` via Turbo Frame targeting `workout_preview`.

Appears in both mobile and desktop header areas.

### Stimulus Controller

`difficulty_controller.js`:
- Targets: dots, down button, up button.
- Values: `level` (integer, initialised from server).
- Actions: `scaleUp`, `scaleDown` — submit forms with direction and current level.
- Updates dot fill state and button disabled state on connect (from server-rendered state).

### Loading State

For levels 1 and 5 (LLM call), the scale button shows a loading indicator. The Turbo Frame response replaces the preview, resolving the loading state. Use `data-turbo-submits-with` pattern or disable buttons during submission.

### Feed Cards

Difficulty dots do **not** appear on feed cards. Scaling is only available on the workout show page.

### Post Dialog

The complete workout dialog includes a hidden field `difficulty_level` set by the Stimulus controller whenever the level changes. When posting, the current viewing level is recorded on the workout log.

## Preserving the Original Structure

- When a workout is first created (generated, scanned, or manual), `original_structure` is set to match `structure`.
- `original_structure` is never modified after creation.
- All scaling derives from `original_structure || structure` (fallback for pre-existing workouts).
- If a user scales a workout and saves it via the edit page, `structure` updates but `original_structure` remains the level 3 source.

## Migration Plan

Two migrations:
1. Add `original_structure` (jsonb) to `workouts` — nullable, no backfill needed.
2. Add `difficulty_level` (integer, default 3) to `workout_logs`.

Existing workouts: `original_structure` stays null; `structure` treated as level 3 source.
Existing workout logs: default to 3.

## Files to Create/Modify

### New files
- `app/models/concerns/scalable.rb` — scaling logic
- `app/models/concerns/has_default_difficulty.rb` — user default calculation
- `app/javascript/controllers/difficulty_controller.js` — Stimulus controller
- `db/migrate/TIMESTAMP_add_original_structure_to_workouts.rb`
- `db/migrate/TIMESTAMP_add_difficulty_level_to_workout_logs.rb`

### Modified files
- `app/models/workout.rb` — include Scalable
- `app/models/user.rb` — include HasDefaultDifficulty
- `app/controllers/workouts_controller.rb` — add `scale` action
- `config/routes.rb` — add scale route
- `app/views/workouts/_preview.html.erb` — add difficulty control to header
- `app/views/workouts/show.html.erb` — pass difficulty level, add to mobile header
- `app/views/shared/_complete_workout_dialog.html.erb` — add hidden difficulty_level field
- `app/controllers/workout_logs_controller.rb` — accept difficulty_level param in create
