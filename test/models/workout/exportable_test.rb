require "test_helper"

class Workout::ExportableTest < ActiveSupport::TestCase
  setup do
    @workout = workouts(:hyrox_session)
  end

  test "export_sections filters out warm-up sections" do
    @workout.structure = {
      "sections" => [
        { "name" => "Warm-Up", "format" => "straight", "exercises" => [{ "name" => "Jog" }] },
        { "name" => "Main", "format" => "rounds", "rounds" => 3, "exercises" => [{ "name" => "Squat", "reps" => 10 }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal 1, sections.length
    assert_equal "3 Rounds", sections.first[:label]
  end

  test "export_sections filters out cool-down and stretch sections" do
    @workout.structure = {
      "sections" => [
        { "name" => "Circuit", "format" => "amrap", "duration_mins" => 12, "exercises" => [{ "name" => "Burpees", "reps" => 10 }] },
        { "name" => "Cool-Down", "format" => "straight", "exercises" => [{ "name" => "Walk" }] },
        { "name" => "Stretch", "format" => "straight", "exercises" => [{ "name" => "Hamstring Stretch" }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal 1, sections.length
    assert_equal "AMRAP 12min", sections.first[:label]
  end

  test "export_sections builds correct labels for each format" do
    formats = {
      "tabata" => { expected: "Tabata", extra: {} },
      "emom" => { expected: "EMOM 16min", extra: { "duration_mins" => 16 } },
      "amrap" => { expected: "AMRAP 20min", extra: { "duration_mins" => 20 } },
      "for_time" => { expected: "For Time", extra: {} },
      "ladder" => { expected: "Ladder", extra: { "start" => 2, "end" => 10, "step" => 2 } },
      "mountain" => { expected: "Mountain", extra: { "start" => 2, "end" => 2, "peak" => 10 } },
      "hundred" => { expected: "100 Reps", extra: {} },
      "matrix" => { expected: "Matrix", extra: {} }
    }

    formats.each do |fmt, config|
      @workout.structure = {
        "sections" => [
          { "name" => "Block", "format" => fmt, "exercises" => [{ "name" => "Push-Up" }] }.merge(config[:extra])
        ]
      }

      sections = @workout.export_sections
      assert_equal config[:expected], sections.first[:label], "Expected label '#{config[:expected]}' for format '#{fmt}'"
    end
  end

  test "export_sections returns nil label for single-round rounds format" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "rounds", "rounds" => 1, "exercises" => [{ "name" => "Push-Up" }] }
      ]
    }

    sections = @workout.export_sections
    assert_nil sections.first[:label]
  end

  test "export_sections builds exercise line with reps" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "straight", "exercises" => [{ "name" => "Squat", "reps" => 15 }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "15 Squat", sections.first[:exercises].first
  end

  test "export_sections appends meter unit for carry exercises" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "straight", "exercises" => [{ "name" => "Farmer Carry", "reps" => 50 }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "50m Farmer Carry", sections.first[:exercises].first
  end

  test "export_sections builds exercise line with distance" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "straight", "exercises" => [{ "name" => "Run", "distance_m" => 1000 }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "1000m Run", sections.first[:exercises].first
  end

  test "export_sections builds exercise line with calories" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "straight", "exercises" => [{ "name" => "Row", "calories" => 20 }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "20 cal Row", sections.first[:exercises].first
  end

  test "export_sections builds exercise line with duration" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "straight", "exercises" => [{ "name" => "Plank", "duration_s" => 90 }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "1min 30s Plank", sections.first[:exercises].first
  end

  test "export_sections builds exercise line with duration under 60s" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "straight", "exercises" => [{ "name" => "Plank", "duration_s" => 45 }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "45s Plank", sections.first[:exercises].first
  end

  test "export_sections joins multiple metrics with middle dot" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "straight", "exercises" => [{ "name" => "Assault Bike", "reps" => 15, "calories" => 20 }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "15 \u00B7 20 cal Assault Bike", sections.first[:exercises].first
  end

  test "export_sections strips weight annotations from exercise names" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "straight", "exercises" => [{ "name" => "Deadlift (60kg)", "reps" => 5 }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "5 Deadlift", sections.first[:exercises].first
  end

  test "export_sections formats ladder exercises" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "ladder", "start" => 2, "end" => 10, "step" => 2,
          "exercises" => [{ "name" => "Burpee" }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "Burpee 2\u201310 (steps of 2)", sections.first[:exercises].first
  end

  test "export_sections formats mountain exercises" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "mountain", "start" => 2, "end" => 2, "peak" => 10,
          "exercises" => [{ "name" => "Kettlebell Swing" }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "Kettlebell Swing 2\u201310\u20132", sections.first[:exercises].first
  end

  test "export_sections returns exercise name only when no metrics" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "format" => "straight", "exercises" => [{ "name" => "Pull-Up" }] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "Pull-Up", sections.first[:exercises].first
  end

  test "export_sections returns empty array for nil structure" do
    @workout.structure = nil
    assert_equal [], @workout.export_sections
  end

  test "export_sections returns empty array for non-hash structure" do
    @workout.structure = "invalid"
    assert_equal [], @workout.export_sections
  end
end
