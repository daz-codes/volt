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

  # -- Rest ≤ work ratio enforcement --

  test "fix_rest_ratio caps rest_secs at working duration for single-exercise timed rounds" do
    data = build_workout_with_sections([
      { "name" => "Sprint Block", "category" => "main", "format" => "rounds", "rounds" => 6,
        "rest_secs" => 45,
        "exercises" => [ { "name" => "Assault Bike", "duration_s" => 10 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 45, main_tag_slug: "turbine").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_operator section["rest_secs"], :<=, 10, "rest_secs must not exceed 10s work"
  end

  test "fix_rest_ratio caps rest_secs at summed duration for multi-exercise rounds" do
    data = build_workout_with_sections([
      { "name" => "Circuit", "category" => "main", "format" => "rounds", "rounds" => 4,
        "rest_secs" => 60,
        "exercises" => [
          { "name" => "Thruster Hold", "duration_s" => 30 },
          { "name" => "Row Hold", "duration_s" => 15 }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 45, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_operator section["rest_secs"], :<=, 45, "rest_secs must not exceed total work (30+15)"
  end

  test "fix_rest_ratio leaves rep-based rounds alone" do
    data = build_workout_with_sections([
      { "name" => "Strength", "category" => "main", "format" => "rounds", "rounds" => 4,
        "rest_secs" => 60,
        "exercises" => [ { "name" => "Back Squat", "reps" => 5 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 45, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal 60, section["rest_secs"], "no timed work — leave rest alone"
  end

  test "fix_rest_ratio leaves tabata alone" do
    # 45s rest > 20s work on either exercise — fix_rest_ratio would cap a non-tabata
    # section to 20s (single-exercise) or 40s (summed). Tabata must be exempt.
    data = build_workout_with_sections([
      { "name" => "Tabata Finisher", "category" => "finisher", "format" => "tabata",
        "duration_mins" => 4, "rest_secs" => 45,
        "exercises" => [ { "name" => "KB Swing", "duration_s" => 20 }, { "name" => "Goblet Squat", "duration_s" => 20 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 45, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal "tabata", section["format"], "tabata format preserved"
    assert_equal 45, section["rest_secs"], "tabata rest_secs must not be capped by fix_rest_ratio"
  end

  test "fix_rest_ratio leaves sections where rest already <= work" do
    data = build_workout_with_sections([
      { "name" => "Hard Bike", "category" => "main", "format" => "rounds", "rounds" => 8,
        "rest_secs" => 30,
        "exercises" => [ { "name" => "Assault Bike", "duration_s" => 45 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 45, main_tag_slug: "turbine").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal 30, section["rest_secs"], "valid rest ratio should be preserved"
  end

  # -- Cardio machine reps conversion --

  test "fix_cardio_machine_reps converts SkiErg reps to calories" do
    data = build_workout_with_sections([
      { "name" => "Station Grind", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [ { "name" => "SkiErg", "reps" => 15 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 45, main_tag_slug: "hyrox").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    assert_equal 15, ex["calories"]
    assert_nil ex["reps"]
  end

  test "fix_cardio_machine_reps converts Rowing Machine reps to calories" do
    data = build_workout_with_sections([
      { "name" => "Engine", "category" => "main", "format" => "rounds", "rounds" => 4,
        "exercises" => [ { "name" => "Rowing Machine", "reps" => 12 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 45, main_tag_slug: "").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    assert_equal 12, ex["calories"]
    assert_nil ex["reps"]
  end

  test "fix_cardio_machine_reps converts Assault Bike reps to calories" do
    data = build_workout_with_sections([
      { "name" => "Bike Block", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [ { "name" => "Assault Bike", "reps" => 10 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    assert_equal 10, ex["calories"]
    assert_nil ex["reps"]
  end

  test "fix_cardio_machine_reps converts Treadmill reps to duration_s" do
    data = build_workout_with_sections([
      { "name" => "Run Block", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [ { "name" => "Treadmill", "reps" => 30 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    assert_equal 30, ex["duration_s"]
    assert_nil ex["reps"]
  end

  test "fix_cardio_machine_reps leaves DB Row alone (strength row, not cardio)" do
    data = build_workout_with_sections([
      { "name" => "Pull Block", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [ { "name" => "DB Row", "reps" => 10 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    assert_equal 10, ex["reps"]
    assert_nil ex["calories"]
  end

  test "fix_cardio_machine_reps no-op when calories already set" do
    data = build_workout_with_sections([
      { "name" => "Engine", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [ { "name" => "SkiErg", "calories" => 12 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    assert_equal 12, ex["calories"]
    assert_nil ex["reps"]
  end

  # -- Speed-language stripping --

  test "fix_speed_language renames 'Speed Ladder' section to 'Distance Ladder'" do
    data = build_workout_with_sections([
      { "name" => "Treadmill Speed Ladder", "category" => "main", "format" => "ladder",
        "exercises" => [ { "name" => "Run", "distance_m" => 400 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "hyrox").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_match(/Distance Ladder/i, section["name"])
    refute_match(/Speed/i, section["name"])
  end

  test "fix_speed_language renames 'Speed Pyramid' section" do
    data = build_workout_with_sections([
      { "name" => "Speed Pyramid", "category" => "main", "format" => "mountain",
        "exercises" => [ { "name" => "Run", "distance_m" => 400 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_match(/Distance Pyramid/i, section["name"])
  end

  test "fix_speed_language strips section notes containing km/h" do
    data = build_workout_with_sections([
      { "name" => "Run Block", "category" => "main", "format" => "rounds", "rounds" => 3,
        "notes" => "400→100 km/h, 1 min at each speed",
        "exercises" => [ { "name" => "Run", "distance_m" => 400 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_nil section["notes"]
  end

  test "fix_speed_language strips exercise notes containing pace" do
    data = build_workout_with_sections([
      { "name" => "Run Block", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [ { "name" => "Run", "distance_m" => 400, "notes" => "hold 6:00/km pace" } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    assert_nil ex["notes"]
  end

  test "fix_speed_language leaves clean notes alone" do
    data = build_workout_with_sections([
      { "name" => "Run Block", "category" => "main", "format" => "rounds", "rounds" => 3,
        "notes" => "hard effort, sustainable",
        "exercises" => [ { "name" => "Run", "distance_m" => 400, "notes" => "all-out" } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal "hard effort, sustainable", section["notes"]
    assert_equal "all-out", section["exercises"].first["notes"]
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
