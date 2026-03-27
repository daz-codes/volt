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
