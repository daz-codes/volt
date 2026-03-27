require "test_helper"

class WorkoutValidatorTest < ActiveSupport::TestCase
  # -- Rotating EMOM duration snapping --

  test "rotating EMOM duration snaps to nearest valid multiple of exercise count" do
    workout_data = build_workout_with_rotating_emom(exercises: 4, duration_mins: 15)

    validator = WorkoutValidator.new(workout_data, difficulty: "intermediate", duration_mins: 60, main_tag_slug: "")
    result = validator.validate_and_fix

    section = result.dig("structure", "sections").first
    assert_equal 16, section["duration_mins"], "4 exercises × 15 min should snap to 16 (4×4 rounds)"
  end

  test "rotating EMOM duration unchanged when already valid" do
    workout_data = build_workout_with_rotating_emom(exercises: 3, duration_mins: 12)

    validator = WorkoutValidator.new(workout_data, difficulty: "intermediate", duration_mins: 60, main_tag_slug: "")
    result = validator.validate_and_fix

    section = result.dig("structure", "sections").first
    assert_equal 12, section["duration_mins"], "3 exercises × 12 min is already valid (4 rounds each)"
  end

  test "rotating EMOM section notes stripped when containing fractional rounds" do
    workout_data = build_workout_with_rotating_emom(
      exercises: 4, duration_mins: 15,
      notes: "Rotating EMOM: Exercise A, Exercise B, Exercise C, Exercise D. 4-minute cycle × 3.75 rounds."
    )

    validator = WorkoutValidator.new(workout_data, difficulty: "intermediate", duration_mins: 60, main_tag_slug: "")
    result = validator.validate_and_fix

    section = result.dig("structure", "sections").first
    assert_nil section["notes"], "Section notes with fractional rounds should be stripped after duration snap"
  end

  private

  def build_workout_with_rotating_emom(exercises:, duration_mins:, notes: nil)
    exercise_list = exercises.times.map do |i|
      { "name" => "Exercise #{i + 1}", "reps" => 10 }
    end

    section = {
      "name" => "Test Circuit",
      "format" => "emom",
      "emom_style" => "rotating",
      "duration_mins" => duration_mins,
      "exercises" => exercise_list
    }
    section["notes"] = notes if notes

    {
      "name" => "Test Workout",
      "structure" => {
        "warm_up" => "5 min jog",
        "sections" => [ section ],
        "cool_down" => "5 min stretch"
      }
    }
  end
end
