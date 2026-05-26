require "test_helper"

class SharedWorkoutSectionTest < ActionView::TestCase
  include ApplicationHelper
  include LadderSequenceHelper

  test "ladder with per-exercise override renders each exercise's own rung sequence" do
    section = {
      "name" => "Parallel Descender", "format" => "ladder",
      "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
      "exercises" => [
        { "name" => "Box Jump" },
        { "name" => "Row", "varies" => "calories", "start" => 50, "end" => 10, "step" => 10 }
      ]
    }
    render partial: "shared/workout_section", locals: { section: section }
    assert_match(/50.*40.*30.*20.*10.*reps/, rendered, "Box Jump row should show its own rep sequence")
    assert_match(/50.*40.*30.*20.*10.*cal/,  rendered, "Row should show its own calorie sequence")
  end

  test "ladder without overrides keeps the shared header sequence" do
    section = {
      "name" => "Reps Ladder", "format" => "ladder",
      "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
      "exercises" => [{ "name" => "Burpee" }, { "name" => "Sit-up" }]
    }
    render partial: "shared/workout_section", locals: { section: section }
    assert_match(/10.*9.*8.*reps/, rendered, "header should carry the shared sequence")
  end
end
