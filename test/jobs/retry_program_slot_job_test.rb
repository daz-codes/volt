require "test_helper"

class RetryProgramSlotJobTest < ActiveJob::TestCase
  test "generates workout for a pending slot" do
    user = users(:one)
    activity = activities(:hyrox)
    program = Program.create!(
      user: user, activity: activity, name: "Test",
      weeks_count: 2, sessions_per_week: 2,
      duration_mins: 45,
      status: "complete"
    )
    pw = program.program_workouts.create!(
      week_number: 1, session_number: 1, status: "pending"
    )

    workout = Workout.create!(
      user: user, name: "Generated", duration_mins: 45,
      status: "active",
      structure: { "sections" => [] }
    )

    original_call = WorkoutLLMGenerator.method(:call)
    WorkoutLLMGenerator.define_singleton_method(:call) { |**_args| workout }
    begin
      RetryProgramSlotJob.perform_now(pw.id)
    ensure
      WorkoutLLMGenerator.define_singleton_method(:call, original_call)
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
      duration_mins: 45,
      status: "complete"
    )
    pw = program.program_workouts.create!(
      week_number: 1, session_number: 1, status: "pending"
    )

    original_call = WorkoutLLMGenerator.method(:call)
    WorkoutLLMGenerator.define_singleton_method(:call) { |**_args| raise "API error" }
    begin
      RetryProgramSlotJob.perform_now(pw.id)
    ensure
      WorkoutLLMGenerator.define_singleton_method(:call, original_call)
    end

    assert_equal "failed", pw.reload.status
  end
end
