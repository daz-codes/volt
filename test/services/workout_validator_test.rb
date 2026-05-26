require "test_helper"

class WorkoutValidatorTest < ActiveSupport::TestCase
  # -- Long cardio in rounds → straight (the production bug) --

  test "fix_deka_mile_compromised_run_cap clamps 500m compromised runs to 300m for Deka Mile" do
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5, "category" => "warm_up",
        "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
      { "name" => "Race Repeats", "format" => "rounds", "rounds" => 5, "rest_secs" => 60,
        "exercises" => [
          { "name" => "Compromised Run", "distance_m" => 500, "equipment" => "treadmill" },
          { "name" => "Med Ball Sit-up Throw", "reps" => 15, "equipment" => "wall_ball" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "deka-mile").validate_and_fix
    run = result.dig("structure", "sections")[1]["exercises"][0]
    assert_equal 300, run["distance_m"], "compromised run should clamp to 300m for Deka Mile"
  end

  test "fix_deka_mile_compromised_run_cap leaves 200m compromised runs alone" do
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5, "category" => "warm_up",
        "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
      { "name" => "Race Repeats", "format" => "rounds", "rounds" => 10, "rest_secs" => 60,
        "exercises" => [
          { "name" => "Compromised Run", "distance_m" => 200, "equipment" => "treadmill" },
          { "name" => "Box Jump", "reps" => 10, "equipment" => "bodyweight" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "deka-mile").validate_and_fix
    run = result.dig("structure", "sections")[1]["exercises"][0]
    assert_equal 200, run["distance_m"]
  end

  test "fix_deka_mile_compromised_run_cap is scoped to deka-mile only" do
    # Other activities (e.g. Hyrox) can have compromised runs longer than 300m
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5, "category" => "warm_up",
        "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
      { "name" => "Last Mile", "format" => "rounds", "rounds" => 4, "rest_secs" => 90,
        "exercises" => [
          { "name" => "Compromised Run", "distance_m" => 800, "equipment" => "treadmill" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "hyrox").validate_and_fix
    run = result.dig("structure", "sections")[1]["exercises"][0]
    assert_equal 800, run["distance_m"], "Hyrox compromised runs are NOT capped at 300m"
  end

  # -- User has no treadmill: swap running exercises for cardio machine --

  test "fix_swap_run_no_treadmill swaps Compromised Run for Row when user has no treadmill but has rowing_machine" do
    data = build_workout_with_sections([
      { "name" => "Race Repeats", "format" => "rounds", "rounds" => 5, "rest_secs" => 60,
        "exercises" => [
          { "name" => "Compromised Run", "distance_m" => 200, "equipment" => "treadmill" },
          { "name" => "Box Jump", "reps" => 10 }
        ] }
    ])
    result = WorkoutValidator.new(
      data, duration_mins: 60, main_tag_slug: "deka-mile",
      available_equipment: %w[rowing_machine ski_erg wall_ball]
    ).validate_and_fix
    ex = result.dig("structure", "sections")[0]["exercises"][0]
    assert_equal "Row", ex["name"]
    assert_equal "rowing_machine", ex["equipment"]
    assert_equal 200, ex["distance_m"], "distance is preserved"
  end

  test "fix_swap_run_no_treadmill falls back to SkiErg when no rowing_machine available" do
    data = build_workout_with_sections([
      { "name" => "Intervals", "format" => "rounds", "rounds" => 4, "rest_secs" => 60,
        "exercises" => [{ "name" => "Compromised Run", "distance_m" => 300, "equipment" => "treadmill" }] }
    ])
    result = WorkoutValidator.new(
      data, duration_mins: 45, main_tag_slug: "deka-mile",
      available_equipment: %w[ski_erg assault_bike wall_ball]
    ).validate_and_fix
    ex = result.dig("structure", "sections")[0]["exercises"][0]
    assert_equal "SkiErg", ex["name"]
    assert_equal "ski_erg", ex["equipment"]
  end

  test "fix_swap_run_no_treadmill falls back to Air Bike when only assault_bike available" do
    data = build_workout_with_sections([
      { "name" => "Intervals", "format" => "rounds", "rounds" => 4, "rest_secs" => 60,
        "exercises" => [{ "name" => "Sprint", "distance_m" => 100, "equipment" => "treadmill" }] }
    ])
    result = WorkoutValidator.new(
      data, duration_mins: 30, main_tag_slug: "deka-mile",
      available_equipment: %w[assault_bike wall_ball]
    ).validate_and_fix
    ex = result.dig("structure", "sections")[0]["exercises"][0]
    assert_equal "Air Bike", ex["name"]
    assert_equal "assault_bike", ex["equipment"]
  end

  test "fix_swap_run_no_treadmill also swaps Treadmill-named exercises" do
    data = build_workout_with_sections([
      { "name" => "Engine", "format" => "rounds", "rounds" => 3, "rest_secs" => 60,
        "exercises" => [{ "name" => "Treadmill Incline Intervals", "duration_s" => 480 }] }
    ])
    result = WorkoutValidator.new(
      data, duration_mins: 45, main_tag_slug: "deka-mile",
      available_equipment: %w[rowing_machine]
    ).validate_and_fix
    ex = result.dig("structure", "sections")[0]["exercises"][0]
    assert_equal "Row", ex["name"]
    assert_equal "rowing_machine", ex["equipment"]
  end

  test "fix_swap_run_no_treadmill leaves Compromised Run alone when user has treadmill" do
    data = build_workout_with_sections([
      { "name" => "Race Repeats", "format" => "rounds", "rounds" => 5, "rest_secs" => 60,
        "exercises" => [{ "name" => "Compromised Run", "distance_m" => 200, "equipment" => "treadmill" }] }
    ])
    result = WorkoutValidator.new(
      data, duration_mins: 60, main_tag_slug: "deka-mile",
      available_equipment: %w[treadmill rowing_machine]
    ).validate_and_fix
    ex = result.dig("structure", "sections")[0]["exercises"][0]
    assert_equal "Compromised Run", ex["name"]
  end

  test "fix_swap_run_no_treadmill is inert when available_equipment is nil (no constraint)" do
    data = build_workout_with_sections([
      { "name" => "Race Repeats", "format" => "rounds", "rounds" => 5, "rest_secs" => 60,
        "exercises" => [{ "name" => "Compromised Run", "distance_m" => 200, "equipment" => "treadmill" }] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "deka-mile").validate_and_fix
    ex = result.dig("structure", "sections")[0]["exercises"][0]
    assert_equal "Compromised Run", ex["name"]
  end

  test "fix_swap_run_no_treadmill leaves run exercises alone when no cardio machine available" do
    # User has no treadmill AND no row/ski/bike — nothing to swap to. Leave it; user must reconfigure.
    data = build_workout_with_sections([
      { "name" => "Race Repeats", "format" => "rounds", "rounds" => 5, "rest_secs" => 60,
        "exercises" => [{ "name" => "Compromised Run", "distance_m" => 200, "equipment" => "treadmill" }] }
    ])
    result = WorkoutValidator.new(
      data, duration_mins: 60, main_tag_slug: "deka-mile",
      available_equipment: %w[wall_ball kettlebells]
    ).validate_and_fix
    ex = result.dig("structure", "sections")[0]["exercises"][0]
    assert_equal "Compromised Run", ex["name"]
  end

  test "fix_swap_run_no_treadmill does not swap non-running exercises that contain 'run' as substring" do
    # 'Burpee Box Jump-overs' should not match. Sanity check the regex word-boundary scoping.
    data = build_workout_with_sections([
      { "name" => "Strength", "format" => "rounds", "rounds" => 3, "rest_secs" => 60,
        "exercises" => [
          { "name" => "RAM Reverse Lunges", "reps" => 10 },
          { "name" => "Box Jump", "reps" => 10 }
        ] }
    ])
    result = WorkoutValidator.new(
      data, duration_mins: 45, main_tag_slug: "deka-mile",
      available_equipment: %w[rowing_machine]
    ).validate_and_fix
    exs = result.dig("structure", "sections")[0]["exercises"]
    assert_equal "RAM Reverse Lunges", exs[0]["name"]
    assert_equal "Box Jump", exs[1]["name"]
  end

  test "fix_long_cardio_rounds_to_straight converts 3 rounds × 24 min run to one straight 24 min block" do
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5,
        "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
      { "name" => "The Long Run", "format" => "rounds", "rounds" => 3, "rest_secs" => 60,
        "exercises" => [{ "name" => "Run", "duration_s" => 1440, "equipment" => "treadmill" }] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "").validate_and_fix
    long = result.dig("structure", "sections")[1]
    assert_equal "straight", long["format"]
    assert_equal 24, long["duration_mins"]
    assert_nil long["rounds"]
    assert_nil long["rest_secs"]
  end

  test "fix_long_cardio_rounds_to_straight leaves short interval rounds alone" do
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5,
        "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
      { "name" => "Row Intervals", "format" => "rounds", "rounds" => 4, "rest_secs" => 60,
        "exercises" => [{ "name" => "Row", "duration_s" => 300, "equipment" => "rowing_machine" }] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "").validate_and_fix
    intervals = result.dig("structure", "sections")[1]
    assert_equal "rounds", intervals["format"]
    assert_equal 4, intervals["rounds"]
  end

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

  test "legacy emom + emom_style=rotating shape is normalized to continuous_circuit" do
    workout_data = build_workout_with_sections([
      { "name" => "Old Shape", "category" => "main", "format" => "emom", "emom_style" => "rotating",
        "duration_mins" => 12,
        "exercises" => [ { "name" => "A", "reps" => 10 }, { "name" => "B", "reps" => 10 }, { "name" => "C", "reps" => 10 } ] }
    ])

    validator = WorkoutValidator.new(workout_data, duration_mins: 60, main_tag_slug: "")
    result = validator.validate_and_fix

    section = result.dig("structure", "sections").first
    assert_equal "continuous_circuit", section["format"]
    assert_nil section["emom_style"]
  end

  test "continuous_circuit cardio exercises do not get a default metric back-filled" do
    workout_data = build_workout_with_sections([
      { "name" => "Engine Ignition", "category" => "main", "format" => "continuous_circuit",
        "duration_mins" => 12,
        "exercises" => [
          { "name" => "Ski Erg",    "calories" => 25, "notes" => "hard sustainable effort" },
          { "name" => "Wall Balls", "reps" => 15, "notes" => "explosive catch" },
          { "name" => "Dips",       "reps" => 10, "notes" => "controlled tempo" }
        ] }
    ])

    result = WorkoutValidator.new(workout_data, duration_mins: 60, main_tag_slug: "").validate_and_fix

    exercises = result.dig("structure", "sections").first["exercises"]
    exercises.each do |ex|
      %w[reps calories distance_m duration_s].each do |field|
        assert_nil ex[field], "#{ex["name"]} should not carry a per-exercise #{field} target in a continuous_circuit"
      end
    end
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

  test "fix_rest_ratio leaves high-intensity sections alone (long rest is the point)" do
    data = build_workout_with_sections([
      { "name" => "Heavy Bench", "category" => "main", "format" => "rounds", "rounds" => 5,
        "intensity_style" => "high", "rest_secs" => 180,
        "exercises" => [ { "name" => "Bench Press", "duration_s" => 30 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 45, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal 180, section["rest_secs"], "high-intensity rest must not be capped at work duration"
  end

  test "fix_rest_secs snaps high-intensity rest to wider grid (90/120/150/180)" do
    data = build_workout_with_sections([
      { "name" => "Heavy Squats", "category" => "main", "format" => "rounds", "rounds" => 5,
        "intensity_style" => "high", "rest_secs" => 100,
        "exercises" => [ { "name" => "Back Squat", "reps" => 5 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 45, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_includes [ 90, 120 ], section["rest_secs"], "100s should snap to 90 or 120, not 60"
  end

  test "fix_rest_secs still snaps non-max-effort rest to 30/45/60" do
    data = build_workout_with_sections([
      { "name" => "Conditioning", "category" => "main", "format" => "rounds", "rounds" => 5,
        "rest_secs" => 75,
        "exercises" => [ { "name" => "KB Swings", "reps" => 20 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 45, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal 60, section["rest_secs"]
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

  test "validators together strip 'Speed Ladder' from exercise names" do
    # fix_exercise_name_programming strips trailing 'Ladder'; fix_speed_language
    # cleans up any remaining "Speed Ladder" pattern. End state: no Speed Ladder.
    data = build_workout_with_sections([
      { "name" => "Run Block", "category" => "main", "format" => "straight", "duration_mins" => 8,
        "exercises" => [ { "name" => "Treadmill Speed Ladder", "duration_s" => 480 } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    refute_match(/Speed Ladder/i, ex["name"])
  end

  # -- Treadmill speed-ladder → distance-ladder rescue --

  test "fix_treadmill_ladder converts speed-shaped ladder to distance ladder" do
    data = build_workout_with_sections([
      { "name" => "Run Cardio Ladder", "category" => "main", "format" => "ladder",
        "varies" => "reps", "start" => 800, "end" => 400, "step" => 100,
        "exercises" => [ { "name" => "Treadmill" } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "hyrox").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal "ladder", section["format"]
    assert_equal "distance_m", section["varies"]
    assert_equal 800, section["start"]
    assert_equal 400, section["end"]
    assert_equal 100, section["step"]
    ex = section["exercises"].first
    assert_equal "Run", ex["name"]
    refute_match(/Speed Ladder/i, ex["name"])
    assert_nil ex["notes"]
  end

  test "fix_treadmill_ladder defaults to 400→100m when range too small" do
    data = build_workout_with_sections([
      { "name" => "Run Block", "category" => "main", "format" => "ladder",
        "varies" => "reps", "start" => 50, "end" => 50, "step" => 1,
        "exercises" => [ { "name" => "Treadmill" } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "hyrox").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal 400, section["start"]
    assert_equal 100, section["end"]
  end

  test "fix_treadmill_ladder leaves a proper distance ladder alone" do
    data = build_workout_with_sections([
      { "name" => "Distance Ladder", "category" => "main", "format" => "ladder",
        "varies" => "distance_m", "start" => 400, "end" => 100, "step" => 100,
        "rest_between_rungs" => 60,
        "exercises" => [ { "name" => "Run", "equipment" => "treadmill" } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "hyrox").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal "ladder", section["format"]
    assert_equal "distance_m", section["varies"]
    assert_equal 400, section["start"]
    assert_equal 100, section["end"]
  end

  test "fix_treadmill_ladder still converts incline ladders to straight" do
    data = build_workout_with_sections([
      { "name" => "Treadmill Incline Ladder", "category" => "main", "format" => "ladder",
        "varies" => "reps", "start" => 1, "end" => 10, "step" => 1,
        "exercises" => [ { "name" => "Treadmill" } ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal "straight", section["format"]
    ex = section["exercises"].first
    assert_match(/Incline/i, ex["name"])
    refute_match(/km\/h/i, ex["notes"].to_s)
  end

  # -- Switchback inference --

  test "fix_switchback_inference converts 'Up and Back' rounds into switchback format" do
    data = build_workout_with_sections([
      { "name" => "Up and Back", "category" => "main", "format" => "rounds", "rounds" => 5,
        "exercises" => [
          { "name" => "Assault Bike", "calories" => 25 },
          { "name" => "Thrusters",    "reps" => 5 }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal "switchback", section["format"]
    assert_equal 25, section["start"]
    assert_equal 5,  section["end"]
    assert_equal 5,  section["step"]
    # Switchback derives per-rung values from start/end/step — exercise rows should not carry them.
    cardio = section["exercises"].find { |ex| ex["name"].match?(/bike/i) }
    floor  = section["exercises"].find { |ex| ex["name"].match?(/thruster/i) }
    assert_nil cardio["calories"]
    assert_nil floor["reps"]
  end

  test "fix_ladder_switchback_strip_metrics removes per-exercise values when section is switchback" do
    data = build_workout_with_sections([
      { "name" => "Up and Back", "category" => "main", "format" => "switchback",
        "varies" => "calories", "start" => 30, "end" => 10, "step" => 5, "rest_between_rungs" => 45,
        "exercises" => [
          { "name" => "Assault Bike", "calories" => 25, "notes" => "hard effort" },
          { "name" => "Thrusters",    "reps" => 5,      "notes" => "moderate load" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal 30, section["start"]
    assert_equal 10, section["end"]
    cardio = section["exercises"].find { |ex| ex["name"].match?(/bike/i) }
    floor  = section["exercises"].find { |ex| ex["name"].match?(/thruster/i) }
    assert_nil cardio["calories"]
    assert_nil floor["reps"]
    assert_equal "hard effort", cardio["notes"]
    assert_equal "moderate load", floor["notes"]
  end

  test "fix_ladder_switchback_strip_metrics removes per-exercise values when section is a ladder" do
    data = build_workout_with_sections([
      { "name" => "Run Ladder", "category" => "main", "format" => "ladder",
        "varies" => "distance_m", "start" => 400, "end" => 100, "step" => 100,
        "exercises" => [
          { "name" => "Run", "distance_m" => 250, "equipment" => "treadmill" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    assert_nil ex["distance_m"]
  end

  test "fix_switchback_inference leaves non-switchback-named sections alone" do
    data = build_workout_with_sections([
      { "name" => "Cardio + Strength", "category" => "main", "format" => "rounds", "rounds" => 3,
        "exercises" => [
          { "name" => "Assault Bike", "calories" => 15 },
          { "name" => "Thrusters",    "reps" => 10 }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal "rounds", section["format"]
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

  # -- fix_emom_alternating_inference --

  test "fix_emom_alternating_inference promotes a 2-ex EMOM with the 1-min max cue to alternating" do
    data = build_workout_with_sections([
      { "name" => "Station Sweep", "category" => "main", "format" => "emom", "duration_mins" => 12, "rest_secs" => 0,
        "exercises" => [
          { "name" => "SkiErg", "notes" => "~50% of your 1-min max (leaves ~20s rest)", "equipment" => "ski_erg" },
          { "name" => "Sled Push", "notes" => "~50% of your 1-min max (leaves ~20s rest) — race weight", "equipment" => "sled" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "hyrox").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal true, section["alternating"]
  end

  test "fix_emom_alternating_inference strips fixed metrics that conflict with the cue" do
    data = build_workout_with_sections([
      { "name" => "Conflict EMOM", "category" => "main", "format" => "emom", "duration_mins" => 16, "rest_secs" => 0,
        "exercises" => [
          { "name" => "Sled Push", "distance_m" => 10, "notes" => "~50% of your 1-min max (leaves ~20s rest)", "equipment" => "sled" },
          { "name" => "Wall Balls", "reps" => 12, "notes" => "~50% of your 1-min max (leaves ~20s rest)", "equipment" => "wall_ball" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "hyrox").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal true, section["alternating"]
    section["exercises"].each do |ex|
      refute ex.key?("distance_m"), "#{ex["name"]} should have no distance_m once cue is in play"
      refute ex.key?("reps"),       "#{ex["name"]} should have no reps once cue is in play"
    end
  end

  test "fix_emom_alternating_inference leaves a 2-ex EMOM with fixed reps and no cue alone (legit 'both each minute')" do
    data = build_workout_with_sections([
      { "name" => "Triple Trouble", "category" => "main", "format" => "emom", "duration_mins" => 16, "rest_secs" => 0,
        "exercises" => [
          { "name" => "Burpees",   "reps" => 5, "equipment" => "bodyweight" },
          { "name" => "KB Swings", "reps" => 5, "equipment" => "kettlebells" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "hyrox").validate_and_fix
    section = result.dig("structure", "sections").first
    refute section["alternating"], "no cue means this is a real 'both each minute' EMOM — don't promote"
    assert_equal [ 5, 5 ], section["exercises"].map { |ex| ex["reps"] }
  end

  test "fix_emom_alternating_inference leaves a single-exercise EMOM with the cue alone" do
    data = build_workout_with_sections([
      { "name" => "Wall Window", "category" => "main", "format" => "emom", "duration_mins" => 12, "rest_secs" => 0,
        "exercises" => [
          { "name" => "Wall Balls", "notes" => "~50% of your 1-min max (leaves ~20s rest)", "equipment" => "wall_ball" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "hyrox").validate_and_fix
    section = result.dig("structure", "sections").first
    refute section["alternating"], "single-ex EMOMs render as the headline shape — alternating doesn't apply"
  end

  # -- fix_race_weight_on_non_stations --

  test "fix_race_weight_on_non_stations rewrites race-relative wording on a Deadlift (not a Hyrox station)" do
    data = build_workout_with_sections([
      { "name" => "Heavy Anchor", "category" => "main", "format" => "rounds", "rounds" => 5, "rest_secs" => 180,
        "exercises" => [
          { "name" => "Deadlift", "reps" => 5,
            "notes" => "heavier than race weight — near-max load, last rep should be a grin" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "hyrox").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    refute_match(/race weight/i, ex["notes"])
    assert_match(/heavy strength load/i, ex["notes"])
  end

  test "fix_race_weight_on_non_stations leaves race-weight wording on actual race stations (Sled Push in Hyrox)" do
    data = build_workout_with_sections([
      { "name" => "Sled Block", "category" => "main", "format" => "rounds", "rounds" => 4, "rest_secs" => 90,
        "exercises" => [
          { "name" => "Sled Push", "distance_m" => 40,
            "notes" => "race weight — full Hyrox competition sled", "equipment" => "sled" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "hyrox").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    assert_equal "race weight — full Hyrox competition sled", ex["notes"]
  end

  test "fix_race_weight_on_non_stations is a no-op for activities without RACE_STATIONS (transformer)" do
    data = build_workout_with_sections([
      { "name" => "Heavy Pull", "category" => "main", "format" => "rounds", "rounds" => 5, "rest_secs" => 180,
        "exercises" => [
          { "name" => "Deadlift", "reps" => 3,
            "notes" => "heavier than race weight — last rep should be a fight" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "transformer").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    assert_match(/race weight/i, ex["notes"], "transformer has no RACE_STATIONS so the phrase is left alone")
  end

  test "fix_race_weight_on_non_stations rewrites Bench Press wording in a Deka session" do
    data = build_workout_with_sections([
      { "name" => "Iron Press", "category" => "main", "format" => "rounds", "rounds" => 4, "rest_secs" => 120,
        "exercises" => [
          { "name" => "Bench Press", "reps" => 5,
            "notes" => "above competition load — well above race-day fatigue weight" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "deka").validate_and_fix
    ex = result.dig("structure", "sections").first["exercises"].first
    refute_match(/competition load/i, ex["notes"])
    refute_match(/race weight/i, ex["notes"])
    assert_match(/near-max load/i, ex["notes"])
  end

  # -- fix_ladder_rung_count_parity --

  test "fix_ladder_rung_count_parity leaves matching rung counts alone" do
    data = build_workout_with_sections([
      { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
        "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
        "exercises" => [
          { "name" => "Box Jump" },
          { "name" => "Row", "varies" => "calories", "start" => 50, "end" => 10, "step" => 10 }
        ] }
    ])
    result  = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    row     = section["exercises"].find { |e| e["name"] == "Row" }
    assert_equal "calories", row["varies"]
    assert_equal 50, row["start"]
  end

  test "fix_ladder_rung_count_parity strips all overrides on mismatch" do
    # Box Jump: 50→10 step 10 = 5 rungs. Row: 80→10 step 10 = 8 rungs. Mismatch.
    data = build_workout_with_sections([
      { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
        "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
        "exercises" => [
          { "name" => "Box Jump" },
          { "name" => "Row", "varies" => "calories", "start" => 80, "end" => 10, "step" => 10 }
        ] }
    ])
    validator = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "")
    result    = validator.validate_and_fix
    row       = result.dig("structure", "sections").first["exercises"].find { |e| e["name"] == "Row" }
    refute row.key?("varies"),    "override varies should be stripped on mismatch"
    refute row.key?("start"),     "override start should be stripped on mismatch"
    refute row.key?("end"),       "override end should be stripped on mismatch"
    refute row.key?("step"),      "override step should be stripped on mismatch"
    assert validator.warnings.any? { |w| w.match?(/rung count/i) }, "expected a parity warning"
  end

  test "fix_ladder_rung_count_parity also strips mountain peak override" do
    # Two mountain exercises with mismatched peaks → mismatched rung counts.
    data = build_workout_with_sections([
      { "name" => "Twin Peaks", "category" => "main", "format" => "mountain",
        "varies" => "reps", "start" => 5, "peak" => 15, "end" => 5, "step" => 5,
        "exercises" => [
          { "name" => "Wall Ball" },
          { "name" => "KB Swing", "varies" => "reps", "start" => 5, "peak" => 25, "end" => 5, "step" => 5 }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    kb = result.dig("structure", "sections").first["exercises"].find { |e| e["name"] == "KB Swing" }
    refute kb.key?("peak"), "override peak should be stripped on mismatch"
  end

  # -- fix_ladder_step on per-exercise overrides --

  test "fix_ladder_step corrects an out-of-range step on a per-exercise override" do
    data = build_workout_with_sections([
      { "name" => "Calorie Descender", "category" => "main", "format" => "ladder",
        "varies" => "reps", "start" => 25, "end" => 5, "step" => 5,
        "exercises" => [
          { "name" => "Row", "varies" => "calories", "start" => 25, "end" => 5, "step" => 2 }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    row = result.dig("structure", "sections").first["exercises"].first
    assert_equal 5, row["step"], "calories step 2 should be raised to minimum 5"
  end

  test "fix_ladder_step leaves valid per-exercise steps alone" do
    data = build_workout_with_sections([
      { "name" => "Calorie Descender", "category" => "main", "format" => "ladder",
        "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
        "exercises" => [
          { "name" => "Row", "varies" => "calories", "start" => 50, "end" => 10, "step" => 10 }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 30, main_tag_slug: "").validate_and_fix
    row = result.dig("structure", "sections").first["exercises"].first
    assert_equal 10, row["step"]
  end

  # -- fix_deka_mile_compromised_run_cap on ladders --

  test "fix_deka_mile_compromised_run_cap clamps section-level ladder rungs over 300m" do
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5, "category" => "warm_up",
        "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
      { "name" => "Run Stairs", "category" => "main", "format" => "ladder",
        "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100,
        "exercises" => [
          { "name" => "Compromised Run", "equipment" => "treadmill" }
        ] }
    ])
    result  = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "deka-mile").validate_and_fix
    section = result.dig("structure", "sections")[1]
    assert section["start"].to_i <= 300, "section start should be clamped to 300 or below (was #{section["start"]})"
    assert_equal 100, section["end"]
  end

  test "fix_deka_mile_compromised_run_cap leaves a 300m ladder alone" do
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5, "category" => "warm_up",
        "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
      { "name" => "Run Stairs", "category" => "main", "format" => "ladder",
        "varies" => "distance_m", "start" => 300, "end" => 100, "step" => 100,
        "exercises" => [
          { "name" => "Compromised Run", "equipment" => "treadmill" }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "deka-mile").validate_and_fix
    section = result.dig("structure", "sections")[1]
    assert_equal 300, section["start"]
  end

  test "fix_deka_mile_compromised_run_cap clamps per-exercise override rungs over 300m" do
    # Section is reps-based but Compromised Run override is distance_m 500->100.
    data = build_workout_with_sections([
      { "name" => "Warm-Up", "format" => "straight", "duration_mins" => 5, "category" => "warm_up",
        "exercises" => [{ "name" => "Easy ski", "duration_s" => 300 }] },
      { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
        "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
        "exercises" => [
          { "name" => "Box Jump" },
          { "name" => "Compromised Run", "equipment" => "treadmill",
            "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
        ] }
    ])
    result = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "deka-mile").validate_and_fix
    run    = result.dig("structure", "sections")[1]["exercises"].find { |e| e["name"] == "Compromised Run" }
    assert run["start"].to_i <= 300, "override start should be clamped to 300 or below"
  end

  # -- fix_treadmill_ladder respects per-exercise overrides --

  test "fix_treadmill_ladder leaves a parallel-rung ladder with a Run override alone" do
    data = build_workout_with_sections([
      { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
        "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
        "exercises" => [
          { "name" => "Box Jump" },
          { "name" => "Run", "equipment" => "treadmill",
            "varies" => "distance_m", "start" => 500, "end" => 100, "step" => 100 }
        ] }
    ])
    result  = WorkoutValidator.new(data, duration_mins: 60, main_tag_slug: "").validate_and_fix
    section = result.dig("structure", "sections").first
    assert_equal "reps", section["varies"], "section varies must not flip to distance_m"
    run = section["exercises"].find { |e| e["name"] == "Run" }
    assert_equal "distance_m", run["varies"]
    assert_equal 500, run["start"]
    assert_equal 2, section["exercises"].size, "Box Jump must not be deleted"
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
      "format" => "continuous_circuit",
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
