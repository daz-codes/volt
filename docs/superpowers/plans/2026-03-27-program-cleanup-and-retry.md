# Program Cleanup & Retry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three issues with programs: hide program workouts from the library list, cascade-delete workouts when a program is deleted (preserving feed posts), and add a retry button for failed generation slots.

**Architecture:** Program workouts are excluded from the library via a query filter on `WorkoutsController#index`. Program deletion uses a `before_destroy` callback (with `prepend: true` to run before `dependent: :destroy` clears the join table) that destroys un-logged workouts and leaves logged ones intact. A new `RetryProgramSlotJob` handles single-slot regeneration triggered by a retry button on failed slots.

**Tech Stack:** Rails 8, Turbo Streams, SQLite3, Solid Queue

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `app/controllers/workouts_controller.rb` | Modify | Filter program workouts from library query |
| `app/models/program.rb` | Modify | Add `before_destroy` callback to clean up workouts |
| `config/routes.rb` | Modify | Add `retry_slot` member route on programs |
| `app/controllers/programs_controller.rb` | Modify | Add `retry_slot` action |
| `app/jobs/retry_program_slot_job.rb` | Create | Single-slot generation job |
| `app/views/programs/_program_workout_slot.html.erb` | Modify | Add retry button to failed state |
| `test/controllers/workouts_controller_test.rb` | Modify | Test library excludes program workouts |
| `test/models/program_test.rb` | Create | Test cascade delete behaviour |
| `test/controllers/programs_controller_test.rb` | Modify | Test retry_slot action |
| `test/jobs/retry_program_slot_job_test.rb` | Create | Test single-slot job |

**Note:** No migration needed. The `cleanup_workouts` callback only destroys workouts that have zero logs, so `WorkoutLog`'s `belongs_to :workout` (non-optional) and `Workout`'s `has_many :workout_logs, dependent: :destroy` remain unchanged. Logged workouts are never destroyed during program deletion.

---

### Task 1: Hide program workouts from library

**Files:**
- Modify: `app/controllers/workouts_controller.rb:14-17`
- Modify: `test/controllers/workouts_controller_test.rb`
- Fixtures: `test/fixtures/program_workouts.yml`

- [ ] **Step 1: Set up fixtures for a program with workouts**

Check existing fixtures. `test/fixtures/programs.yml` already has `hyrox_program` (with activity) and `no_activity_program`. We need a program_workout fixture linking a program to an existing workout.

In `test/fixtures/program_workouts.yml`, replace `# empty` with:

```yaml
hyrox_week1_session1:
  program: hyrox_program
  workout: hyrox_session
  week_number: 1
  session_number: 1
  status: complete
```

This links the existing `hyrox_session` workout fixture to the `hyrox_program` fixture.

- [ ] **Step 2: Write failing test — library excludes program workouts**

In `test/controllers/workouts_controller_test.rb`, add. Note: do NOT use `assigns` (requires extra gem). Use `assert_select` against the response body instead:

```ruby
test "library excludes workouts that belong to a program" do
  get library_path
  assert_response :success
  # hyrox_session is linked to hyrox_program via program_workouts fixture
  # It should NOT appear in the individual workouts list
  assert_no_match workouts(:hyrox_session).name, response.body
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/controllers/workouts_controller_test.rb -n "test_library_excludes_workouts_that_belong_to_a_program"`

Expected: FAIL — hyrox_session name currently appears in the library response body.

- [ ] **Step 4: Implement the filter**

In `app/controllers/workouts_controller.rb`, change lines 15-17 from:

```ruby
@workouts  = Current.user.workouts
                   .includes(:tags, :activity)
                   .order(created_at: :desc)
```

To:

```ruby
@workouts  = Current.user.workouts
                   .where.not(id: ProgramWorkout.where.not(workout_id: nil).select(:workout_id))
                   .includes(:tags, :activity)
                   .order(created_at: :desc)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/workouts_controller_test.rb`

Expected: All pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/workouts_controller.rb test/controllers/workouts_controller_test.rb test/fixtures/program_workouts.yml
git commit -m "feat: hide program workouts from library list

Workouts linked to a program via program_workouts are excluded
from the individual workouts list in the library to avoid duplication."
```

---

### Task 2: Cascade-delete workouts when program is deleted

**Files:**
- Modify: `app/models/program.rb`
- Create: `test/models/program_test.rb`

**Important:** The `cleanup_workouts` callback must use `prepend: true` so it runs BEFORE the `has_many :program_workouts, dependent: :destroy` callback. Without `prepend: true`, Rails destroys the join records first, making the `workouts` through-association return nothing. Additionally, we query workout IDs directly from `program_workouts` rather than using the through-association, for robustness.

- [ ] **Step 1: Write failing test — deleting program destroys un-logged workouts**

Create `test/models/program_test.rb`:

```ruby
require "test_helper"

class ProgramTest < ActiveSupport::TestCase
  test "destroying program destroys workouts that have no logs" do
    user = users(:one)
    program = Program.create!(
      user: user, name: "Test Program", weeks_count: 2,
      sessions_per_week: 2, duration_mins: 45,
      difficulty: "intermediate", status: "complete"
    )
    workout = Workout.create!(
      user: user, name: "Program Workout", duration_mins: 45,
      difficulty: "intermediate", status: "active",
      structure: { "sections" => [] }
    )
    program.program_workouts.create!(
      workout: workout, week_number: 1,
      session_number: 1, status: "complete"
    )

    assert_difference "Workout.count", -1 do
      program.destroy!
    end
  end

  test "destroying program preserves workouts that have logs" do
    user = users(:one)
    program = Program.create!(
      user: user, name: "Test Program", weeks_count: 2,
      sessions_per_week: 2, duration_mins: 45,
      difficulty: "intermediate", status: "complete"
    )
    workout = Workout.create!(
      user: user, name: "Logged Workout", duration_mins: 45,
      difficulty: "intermediate", status: "active",
      structure: { "sections" => [] }
    )
    program.program_workouts.create!(
      workout: workout, week_number: 1,
      session_number: 1, status: "complete"
    )
    WorkoutLog.create!(
      user: user, workout: workout, sweat_rating: 3,
      visibility: "public", completed_at: Time.current
    )

    assert_no_difference "Workout.count" do
      program.destroy!
    end
  end

  test "destroying program handles slots with no workout (failed generation)" do
    user = users(:one)
    program = Program.create!(
      user: user, name: "Test Program", weeks_count: 2,
      sessions_per_week: 2, duration_mins: 45,
      difficulty: "intermediate", status: "complete"
    )
    program.program_workouts.create!(
      week_number: 1, session_number: 1, status: "failed"
    )

    assert_nothing_raised do
      program.destroy!
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/program_test.rb`

Expected: First test FAILS (workout not destroyed). Second and third may pass vacuously.

- [ ] **Step 3: Implement cascade delete on Program model**

In `app/models/program.rb`, add the callback with `prepend: true` and query workout IDs directly:

```ruby
class Program < ApplicationRecord
  belongs_to :user
  belongs_to :activity, optional: true
  has_many :program_workouts, dependent: :destroy
  has_many :workouts, through: :program_workouts
  has_many :shares, as: :shareable, dependent: :destroy

  before_destroy :cleanup_workouts, prepend: true

  # ... existing validations, scopes, methods ...

  private

  def cleanup_workouts
    workout_ids = program_workouts.where.not(workout_id: nil).pluck(:workout_id)
    return if workout_ids.empty?

    Workout.where(id: workout_ids)
           .left_joins(:workout_logs)
           .where(workout_logs: { id: nil })
           .destroy_all
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/program_test.rb`

Expected: All three pass.

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`

Expected: All pass, no breakage.

- [ ] **Step 6: Commit**

```bash
git add app/models/program.rb test/models/program_test.rb
git commit -m "feat: cascade-delete program workouts on program destroy

Workouts with no logs are destroyed when their program is deleted.
Workouts that have been logged (posted to feed) are preserved.
Uses prepend: true to run before dependent: :destroy clears the
join table, and queries workout IDs directly for robustness."
```

---

### Task 3: Add retry button for failed program slots

**Files:**
- Create: `app/jobs/retry_program_slot_job.rb`
- Modify: `config/routes.rb`
- Modify: `app/controllers/programs_controller.rb`
- Modify: `app/views/programs/_program_workout_slot.html.erb`
- Create: `test/jobs/retry_program_slot_job_test.rb`
- Modify: `test/controllers/programs_controller_test.rb`

- [ ] **Step 1: Write failing test — retry_slot route and controller action**

In `test/controllers/programs_controller_test.rb`, add:

```ruby
test "retry_slot resets failed slot and enqueues job" do
  program = programs(:hyrox_program)
  pw = program.program_workouts.create!(
    week_number: 1, session_number: 2, status: "failed"
  )

  assert_enqueued_with(job: RetryProgramSlotJob, args: [pw.id]) do
    post retry_slot_program_path(program, program_workout_id: pw.id)
  end

  assert_redirected_to program_path(program)
  assert_equal "pending", pw.reload.status
end

test "retry_slot ignores non-failed slots" do
  program = programs(:hyrox_program)
  pw = program.program_workouts.create!(
    week_number: 1, session_number: 2, status: "complete",
    workout: workouts(:hyrox_session)
  )

  post retry_slot_program_path(program, program_workout_id: pw.id)
  assert_redirected_to program_path(program)
  assert_equal "complete", pw.reload.status
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/programs_controller_test.rb -n "/retry_slot/"`

Expected: FAIL — route doesn't exist.

- [ ] **Step 3: Add route**

In `config/routes.rb`, change line 39 from:

```ruby
resources :programs, only: [ :new, :create, :show, :destroy ]
```

To:

```ruby
resources :programs, only: [ :new, :create, :show, :destroy ] do
  member do
    post :retry_slot
  end
end
```

- [ ] **Step 4: Add controller action**

In `app/controllers/programs_controller.rb`:

1. Update the `set_program` before_action to include `:retry_slot`:

```ruby
before_action :set_program, only: [ :show, :destroy, :retry_slot ]
```

2. Add the action after `destroy`:

```ruby
def retry_slot
  pw = @program.program_workouts.find(params[:program_workout_id])

  unless pw.failed?
    redirect_to program_path(@program) and return
  end

  pw.update!(status: "pending", workout: nil)
  RetryProgramSlotJob.perform_later(pw.id)
  redirect_to program_path(@program), notice: "Retrying generation…"
end
```

- [ ] **Step 5: Run controller tests (will fail on missing job class)**

Run: `bin/rails test test/controllers/programs_controller_test.rb -n "/retry_slot/"`

Expected: Error — `RetryProgramSlotJob` not defined yet.

- [ ] **Step 6: Write failing test for RetryProgramSlotJob**

Create `test/jobs/retry_program_slot_job_test.rb`:

```ruby
require "test_helper"

class RetryProgramSlotJobTest < ActiveJob::TestCase
  test "generates workout for a pending slot" do
    user = users(:one)
    activity = activities(:hyrox)
    program = Program.create!(
      user: user, activity: activity, name: "Test",
      weeks_count: 2, sessions_per_week: 2,
      duration_mins: 45, difficulty: "intermediate",
      status: "complete"
    )
    pw = program.program_workouts.create!(
      week_number: 1, session_number: 1, status: "pending"
    )

    workout = Workout.create!(
      user: user, name: "Generated", duration_mins: 45,
      difficulty: "intermediate", status: "active",
      structure: { "sections" => [] }
    )

    WorkoutLLMGenerator.stub(:call, workout) do
      RetryProgramSlotJob.perform_now(pw.id)
    end

    pw.reload
    assert_equal "complete", pw.status
    assert_equal workout, pw.workout
  end

  test "marks slot as failed when generation errors" do
    user = users(:one)
    activity = activities(:hyrox)
    program = Program.create!(
      user: user, activity: activity, name: "Test",
      weeks_count: 2, sessions_per_week: 2,
      duration_mins: 45, difficulty: "intermediate",
      status: "complete"
    )
    pw = program.program_workouts.create!(
      week_number: 1, session_number: 1, status: "pending"
    )

    WorkoutLLMGenerator.stub(:call, ->(*) { raise "API error" }) do
      RetryProgramSlotJob.perform_now(pw.id)
    end

    assert_equal "failed", pw.reload.status
  end
end
```

- [ ] **Step 7: Create RetryProgramSlotJob**

Create `app/jobs/retry_program_slot_job.rb`:

```ruby
class RetryProgramSlotJob < ApplicationJob
  queue_as :default

  def perform(program_workout_id)
    pw = ProgramWorkout.find(program_workout_id)
    program = pw.program

    pw.update!(status: "generating")
    broadcast_slot(pw)

    workout = WorkoutLLMGenerator.call(
      user:          program.user,
      activity:      program.activity&.name,
      duration_mins: program.duration_mins,
      difficulty:    program.difficulty,
      session_notes: pw.session_notes
    )

    pw.update!(workout: workout, status: "complete")
    broadcast_slot(pw)
  rescue => e
    Rails.logger.error "RetryProgramSlotJob failed for pw #{program_workout_id}: #{e.message}"
    pw&.update!(status: "failed")
    broadcast_slot(pw) if pw
  end

  private

  def broadcast_slot(pw)
    pw_fresh = pw.reload
    Turbo::StreamsChannel.broadcast_replace_to(
      "program_#{pw_fresh.program_id}",
      target:  pw_fresh.turbo_dom_id,
      partial: "programs/program_workout_slot",
      locals:  { program_workout: pw_fresh }
    )
  end
end
```

- [ ] **Step 8: Run all job and controller tests**

Run: `bin/rails test test/jobs/retry_program_slot_job_test.rb test/controllers/programs_controller_test.rb`

Expected: All pass.

- [ ] **Step 9: Add retry button to failed slot view**

In `app/views/programs/_program_workout_slot.html.erb`, replace the failed state block (lines 20-24):

```erb
<% elsif pw.failed? %>
  <div class="bg-zinc-800 border border-red-900/40 rounded-2xl p-4 min-h-[100px] flex items-center justify-center gap-3">
    <p class="text-gray-600 text-[10px] font-black uppercase tracking-widest">Session <%= pw.session_number %></p>
    <p class="text-red-400 text-xs font-medium">Generation failed</p>
    <%= button_to "Retry", retry_slot_program_path(pw.program, program_workout_id: pw.id),
          method: :post,
          class: "text-xs font-bold text-amber-400 hover:text-amber-300 border border-amber-400/40 hover:border-amber-300/60 px-3 py-1.5 rounded-lg transition-colors cursor-pointer" %>
  </div>
```

- [ ] **Step 10: Run full test suite**

Run: `bin/rails test`

Expected: All pass.

- [ ] **Step 11: Commit**

```bash
git add app/jobs/retry_program_slot_job.rb app/controllers/programs_controller.rb config/routes.rb app/views/programs/_program_workout_slot.html.erb test/jobs/retry_program_slot_job_test.rb test/controllers/programs_controller_test.rb
git commit -m "feat: add retry button for failed program workout slots

Failed slots now show a Retry button that resets the slot to pending
and enqueues RetryProgramSlotJob to regenerate just that one workout.
Uses Turbo Streams for real-time status updates."
```

---

### Task 4: Final verification

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`

Expected: All green, zero failures.

- [ ] **Step 2: Manual smoke test**

1. Create a program → verify workouts don't appear in library list
2. Delete the program → verify workouts are cleaned up
3. Check feed → any previously logged workouts still display correctly
4. Create a program where a slot fails → verify retry button appears → tap retry → verify slot regenerates
