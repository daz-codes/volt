require "test_helper"

class Workout::LadderSequenceTest < ActiveSupport::TestCase
  # -- section-default ladders (no overrides) --

  test "ladder uses section start/end/step when exercise has no override" do
    section  = { "format" => "ladder", "varies" => "reps",
                 "start" => 10, "end" => 1, "step" => 1, "exercises" => [{ "name" => "KB Swing" }] }
    exercise = section["exercises"].first
    assert_equal [10, 9, 8, 7, 6, 5, 4, 3, 2, 1], Workout::LadderSequence.values_for(section, exercise)
    assert_equal "reps", Workout::LadderSequence.varies_for(section, exercise)
  end

  test "mountain uses section start/peak/end/step" do
    section  = { "format" => "mountain", "varies" => "reps",
                 "start" => 1, "peak" => 5, "end" => 1, "step" => 1,
                 "exercises" => [{ "name" => "Bear" }] }
    exercise = section["exercises"].first
    assert_equal [1, 2, 3, 4, 5, 4, 3, 2, 1], Workout::LadderSequence.values_for(section, exercise)
  end

  test "ascending ladder (start < end)" do
    section  = { "format" => "ladder", "varies" => "reps",
                 "start" => 2, "end" => 10, "step" => 2, "exercises" => [{ "name" => "Burpees" }] }
    assert_equal [2, 4, 6, 8, 10], Workout::LadderSequence.values_for(section, section["exercises"].first)
  end

  # -- per-exercise full overrides --

  test "exercise override of varies/start/end/step takes precedence" do
    section = { "format" => "ladder", "varies" => "reps",
                "start" => 50, "end" => 10, "step" => 10,
                "exercises" => [
                  { "name" => "Box Jump" },
                  { "name" => "Run", "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
                ] }
    box, run = section["exercises"]

    assert_equal [50, 40, 30, 20, 10], Workout::LadderSequence.values_for(section, box)
    assert_equal "reps", Workout::LadderSequence.varies_for(section, box)

    assert_equal [500, 400, 300, 200, 100], Workout::LadderSequence.values_for(section, run)
    assert_equal "distance_m", Workout::LadderSequence.varies_for(section, run)
  end

  test "partial override (varies only) inherits section start/end/step" do
    section  = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 2, "step" => 2,
                 "exercises" => [{ "name" => "Row", "varies" => "calories" }] }
    exercise = section["exercises"].first
    assert_equal [10, 8, 6, 4, 2], Workout::LadderSequence.values_for(section, exercise)
    assert_equal "calories", Workout::LadderSequence.varies_for(section, exercise)
  end

  test "legacy 'metric' field changes unit label only, not values" do
    section  = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
                 "exercises" => [{ "name" => "Row", "metric" => "calories" }] }
    exercise = section["exercises"].first
    assert_equal (1..10).to_a.reverse, Workout::LadderSequence.values_for(section, exercise)
    assert_equal "calories", Workout::LadderSequence.varies_for(section, exercise)
  end

  test "full override beats legacy metric when both are present" do
    section = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
                "exercises" => [{ "name" => "Run", "metric" => "distance_m",
                                  "varies" => "distance_m", "start" => 400, "end" => 100, "step" => 100 }] }
    exercise = section["exercises"].first
    assert_equal [400, 300, 200, 100], Workout::LadderSequence.values_for(section, exercise)
  end

  # -- unit labels --

  test "unit_label_for maps each varies to its short label" do
    section = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
                "exercises" => [{ "name" => "X" }] }
    %w[reps cal m kg].zip(%w[reps calories distance_m kg]).each do |label, varies|
      section["varies"] = varies
      assert_equal label, Workout::LadderSequence.unit_label_for(section, section["exercises"].first)
    end
  end

  # -- per-exercise overrides? helper --

  test "has_per_exercise_overrides? false for plain section ladder" do
    section = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
                "exercises" => [{ "name" => "A" }, { "name" => "B" }] }
    refute Workout::LadderSequence.has_per_exercise_overrides?(section)
  end

  test "has_per_exercise_overrides? false for legacy metric-only override" do
    section = { "format" => "ladder", "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
                "exercises" => [{ "name" => "Row", "metric" => "calories" }] }
    refute Workout::LadderSequence.has_per_exercise_overrides?(section)
  end

  test "has_per_exercise_overrides? true when any exercise sets varies/start/end/step" do
    section = { "format" => "ladder", "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
                "exercises" => [
                  { "name" => "Box Jump" },
                  { "name" => "Run", "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
                ] }
    assert Workout::LadderSequence.has_per_exercise_overrides?(section)
  end
end
