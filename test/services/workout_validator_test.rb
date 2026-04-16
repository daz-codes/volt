require "test_helper"

class WorkoutValidatorTest < ActiveSupport::TestCase
  # -- Section category inference --

  test "ensure_section_categories infers warm_up from name" do
    data = build_workout_with_sections([
      { "name" => "Gas Pedal", "format" => "straight", "exercises" => [{ "name" => "Jog" }] },
      { "name" => "Main Block", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "").validate_and_fix
    sections = result.dig("structure", "sections")
    assert_equal "main", sections[0]["category"]
    assert_equal "main", sections[1]["category"]
  end

  test "ensure_section_categories infers warm_up from warm-up name" do
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "format" => "straight", "exercises" => [{ "name" => "Jog" }] },
      { "name" => "Main Block", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "").validate_and_fix
    sections = result.dig("structure", "sections")
    assert_equal "warm_up", sections[0]["category"]
    assert_equal "main", sections[1]["category"]
  end

  test "ensure_section_categories infers cool_down from name" do
    data = build_workout_with_sections([
      { "name" => "Main Block", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] },
      { "name" => "Decompress", "format" => "straight", "exercises" => [{ "name" => "Stretch" }] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "").validate_and_fix
    sections = result.dig("structure", "sections")
    assert_equal "main", sections[0]["category"]
    assert_equal "cool_down", sections[1]["category"]
  end

  test "ensure_section_categories infers finisher for last tabata before cool-down" do
    data = build_workout_with_sections([
      { "name" => "Main Block", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] },
      { "name" => "Final Push", "format" => "tabata", "duration_mins" => 4, "exercises" => [{ "name" => "Row" }] },
      { "name" => "Cool-Down", "format" => "straight", "exercises" => [{ "name" => "Stretch" }] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "").validate_and_fix
    sections = result.dig("structure", "sections")
    assert_equal "main", sections[0]["category"]
    assert_equal "finisher", sections[1]["category"]
    assert_equal "cool_down", sections[2]["category"]
  end

  test "ensure_section_categories preserves valid existing category" do
    data = build_workout_with_sections([
      { "name" => "Gas Pedal", "category" => "warm_up", "format" => "straight", "exercises" => [{ "name" => "Jog" }] },
      { "name" => "Main Block", "category" => "main", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "").validate_and_fix
    sections = result.dig("structure", "sections")
    assert_equal "warm_up", sections[0]["category"]
    assert_equal "main", sections[1]["category"]
  end

  test "ensure_section_categories replaces invalid category" do
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "category" => "bogus", "format" => "straight", "exercises" => [{ "name" => "Jog" }] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "").validate_and_fix
    sections = result.dig("structure", "sections")
    assert_equal "warm_up", sections[0]["category"]
  end

  # -- Rotating EMOM duration snapping --

  test "rotating EMOM duration snaps to nearest valid multiple of exercise count" do
    workout_data = build_workout_with_rotating_emom(exercises: 4, duration_mins: 15)

    validator = WorkoutValidator.new(workout_data, duration_mins: 60, main_tag_slug: "")
    result = validator.validate_and_fix

    section = result.dig("structure", "sections").first
    assert_equal 16, section["duration_mins"], "4 exercises × 15 min should snap to 16 (4×4 rounds)"
  end

  test "rotating EMOM duration unchanged when already valid" do
    workout_data = build_workout_with_rotating_emom(exercises: 3, duration_mins: 12)

    validator = WorkoutValidator.new(workout_data, duration_mins: 60, main_tag_slug: "")
    result = validator.validate_and_fix

    section = result.dig("structure", "sections").first
    assert_equal 12, section["duration_mins"], "3 exercises × 12 min is already valid (4 rounds each)"
  end

  test "rotating EMOM section notes stripped when containing fractional rounds" do
    workout_data = build_workout_with_rotating_emom(
      exercises: 4, duration_mins: 15,
      notes: "Rotating EMOM: Exercise A, Exercise B, Exercise C, Exercise D. 4-minute cycle × 3.75 rounds."
    )

    validator = WorkoutValidator.new(workout_data, duration_mins: 60, main_tag_slug: "")
    result = validator.validate_and_fix

    section = result.dig("structure", "sections").first
    assert_nil section["notes"], "Section notes with fractional rounds should be stripped after duration snap"
  end

  # -- Iron Engine (kettlebell) KB-only enforcement --

  test "fix_kettlebell_non_kb_exercises strips non-KB exercises from main sections" do
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "category" => "warm_up", "format" => "straight",
        "exercises" => [ { "name" => "Arm Circles" }, { "name" => "Bodyweight Squat" } ] },
      { "name" => "Main Block", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [
          { "name" => "KB Swing", "reps" => 20 },
          { "name" => "Assault Bike", "calories" => 12 },
          { "name" => "KB Row", "reps" => 10 }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "kettlebell").validate_and_fix
    main = result.dig("structure", "sections").find { |s| s["category"] == "main" }
    names = main["exercises"].map { |e| e["name"] }
    assert_equal [ "KB Swing", "KB Row" ], names
  end

  test "fix_kettlebell_non_kb_exercises removes sections left empty" do
    data = build_workout_with_sections([
      { "name" => "Main Block", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [ { "name" => "KB Swing", "reps" => 20 } ] },
      { "name" => "Rope Work", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [ { "name" => "Jump Rope", "distance_m" => 800 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "kettlebell").validate_and_fix
    section_names = result.dig("structure", "sections").map { |s| s["name"] }
    assert_includes section_names, "Main Block"
    assert_not_includes section_names, "Rope Work"
  end

  test "fix_kettlebell_non_kb_exercises leaves warm-ups and cool-downs alone" do
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "category" => "warm_up", "format" => "straight",
        "exercises" => [ { "name" => "Jumping Jacks" }, { "name" => "Bodyweight Squat" } ] },
      { "name" => "Main Block", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [ { "name" => "KB Swing", "reps" => 20 } ] },
      { "name" => "Cool-Down", "category" => "cool_down", "format" => "straight",
        "exercises" => [ { "name" => "Hamstring Stretch" } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "kettlebell").validate_and_fix
    warm_up  = result.dig("structure", "sections").find { |s| s["category"] == "warm_up" }
    cooldown = result.dig("structure", "sections").find { |s| s["category"] == "cool_down" }
    assert_equal 2, warm_up["exercises"].size
    assert_equal 1, cooldown["exercises"].size
  end

  test "fix_kettlebell_non_kb_exercises is a no-op for non-kettlebell activities" do
    data = build_workout_with_sections([
      { "name" => "Main Block", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [ { "name" => "Assault Bike", "calories" => 12 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "crossfit").validate_and_fix
    main = result.dig("structure", "sections").find { |s| s["category"] == "main" }
    assert main["exercises"].any? { |e| e["name"].match?(/bike/i) }, "non-kettlebell activities should keep bike work"
  end

  private

  def build_workout_with_sections(sections)
    { "structure" => { "sections" => sections } }
  end

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
