require "test_helper"

class Workout::ExportableTest < ActiveSupport::TestCase
  setup do
    @workout = workouts(:hyrox_session)
  end

  test "export_sections filters out warm_up and cool_down categories" do
    @workout.structure = {
      "sections" => [
        { "name" => "Gas Pedal", "category" => "warm_up", "format" => "straight", "exercises" => [ { "name" => "Jog" } ] },
        { "name" => "Main", "category" => "main", "format" => "rounds", "rounds" => 3, "exercises" => [ { "name" => "Squat", "reps" => 10 } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal 1, sections.length
    assert_equal "3 Rounds", sections.first[:label]
  end

  test "export_sections filters out cool_down category" do
    @workout.structure = {
      "sections" => [
        { "name" => "Circuit", "category" => "main", "format" => "amrap", "duration_mins" => 12, "exercises" => [ { "name" => "Burpees", "reps" => 10 } ] },
        { "name" => "Cool-Down", "category" => "cool_down", "format" => "straight", "exercises" => [ { "name" => "Walk" } ] },
        { "name" => "Stretch", "category" => "cool_down", "format" => "straight", "exercises" => [ { "name" => "Hamstring Stretch" } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal 1, sections.length
    assert_equal "AMRAP 12min", sections.first[:label]
  end

  test "export_sections includes finisher sections" do
    @workout.structure = {
      "sections" => [
        { "name" => "Main Block", "category" => "main", "format" => "rounds", "rounds" => 3, "exercises" => [ { "name" => "Squat", "reps" => 10 } ] },
        { "name" => "Final Push", "category" => "finisher", "format" => "tabata", "exercises" => [ { "name" => "Row" } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal 2, sections.length
    assert_equal "Tabata", sections.last[:label]
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
          { "name" => "Block", "category" => "main", "format" => fmt, "exercises" => [ { "name" => "Push-Up" } ] }.merge(config[:extra])
        ]
      }

      sections = @workout.export_sections
      assert_equal config[:expected], sections.first[:label], "Expected label '#{config[:expected]}' for format '#{fmt}'"
    end
  end

  test "export_sections renders 2-exercise EMOM as EMOM, not Continuous Circuit, when emom_style is blank" do
    @workout.structure = {
      "sections" => [
        { "name" => "Heavy Station Block", "category" => "main", "format" => "emom", "duration_mins" => 18,
          "exercises" => [
            { "name" => "Reverse Lunges", "reps" => 6 },
            { "name" => "Yoke Over",     "reps" => 5 }
          ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "EMOM 18min", sections.first[:label]
  end

  test "export_sections renders 2-exercise EMOM with emom_style=circuit as EMOM" do
    @workout.structure = {
      "sections" => [
        { "name" => "Couplet", "category" => "main", "format" => "emom", "emom_style" => "circuit", "duration_mins" => 10,
          "exercises" => [
            { "name" => "Wall Balls", "reps" => 10 },
            { "name" => "Box Jumps",  "reps" => 8 }
          ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "EMOM 10min", sections.first[:label]
  end

  test "export_sections renders alternating 2-exercise EMOM with 'Alternating each minute' description" do
    @workout.structure = {
      "sections" => [
        { "name" => "Final Boss", "category" => "main", "format" => "emom", "duration_mins" => 20, "alternating" => true,
          "exercises" => [
            { "name" => "Burpee Broad Jumps", "notes" => "~50% of your 1-min max (leaves ~20s rest)" },
            { "name" => "Walking Lunges",     "notes" => "~50% of your 1-min max (leaves ~20s rest)" }
          ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "EMOM 20min", sections.first[:label]
    assert_equal "Alternating each minute", sections.first[:description]
  end

  test "export_sections renders 3-exercise rotating EMOM with rotation cycle description" do
    @workout.structure = {
      "sections" => [
        { "name" => "Race Day Energy", "category" => "main", "format" => "emom", "duration_mins" => 15, "alternating" => true,
          "exercises" => [
            { "name" => "Burpees",        "reps" => 8 },
            { "name" => "Reverse Lunges", "reps" => 12 },
            { "name" => "Sit Ups",        "reps" => 15 }
          ] }
      ]
    }
    sections = @workout.export_sections
    assert_equal "EMOM 15min", sections.first[:label]
    assert_equal "3-min rotation · one exercise per minute", sections.first[:description]
  end

  test "export_sections renders E2MOM with all-together description and E2MOM label" do
    @workout.structure = {
      "sections" => [
        { "name" => "Triple Threat", "category" => "main", "format" => "emom", "duration_mins" => 20, "period_mins" => 2,
          "exercises" => [
            { "name" => "Press Ups", "reps" => 5 },
            { "name" => "Slams",     "reps" => 10 },
            { "name" => "Sit Ups",   "reps" => 20 }
          ] }
      ]
    }
    sections = @workout.export_sections
    assert_equal "E2MOM 20min", sections.first[:label]
    assert_equal "All 3 exercises every 2 minutes", sections.first[:description]
  end

  test "export_sections renders E3MOM label for period_mins:3" do
    @workout.structure = {
      "sections" => [
        { "name" => "Heavy Lift", "category" => "main", "format" => "emom", "duration_mins" => 15, "period_mins" => 3,
          "exercises" => [ { "name" => "Back Squat", "reps" => 5 } ] }
      ]
    }
    sections = @workout.export_sections
    assert_equal "E3MOM 15min", sections.first[:label]
  end

  test "export_sections renders continuous_circuit format as Continuous Circuit" do
    @workout.structure = {
      "sections" => [
        { "name" => "Cycle", "category" => "main", "format" => "continuous_circuit", "duration_mins" => 12,
          "exercises" => [
            { "name" => "Burpees",    "reps" => 10 },
            { "name" => "Wall Balls", "reps" => 12 }
          ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "Continuous Circuit", sections.first[:label]
  end

  test "export_sections uses section name as label for single-round rounds format" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "rounds", "rounds" => 1, "exercises" => [ { "name" => "Push-Up" } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "Block", sections.first[:label]
  end

  test "export_sections builds exercise line with reps" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "straight", "exercises" => [ { "name" => "Squat", "reps" => 15 } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "15 Squat", sections.first[:exercises].first
  end

  test "export_sections appends meter unit for carry exercises" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "straight", "exercises" => [ { "name" => "Farmer Carry", "reps" => 50 } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "50m Farmer Carry", sections.first[:exercises].first
  end

  test "export_sections builds exercise line with distance" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "straight", "exercises" => [ { "name" => "Run", "distance_m" => 1000 } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "1000m Run", sections.first[:exercises].first
  end

  test "export_sections builds exercise line with calories" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "straight", "exercises" => [ { "name" => "Row", "calories" => 20 } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "20 cal Row", sections.first[:exercises].first
  end

  test "export_sections builds exercise line with duration" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "straight", "exercises" => [ { "name" => "Plank", "duration_s" => 90 } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "1min 30s Plank", sections.first[:exercises].first
  end

  test "export_sections builds exercise line with duration under 60s" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "straight", "exercises" => [ { "name" => "Plank", "duration_s" => 45 } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "45s Plank", sections.first[:exercises].first
  end

  test "export_sections joins multiple metrics with middle dot" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "straight", "exercises" => [ { "name" => "Assault Bike", "reps" => 15, "calories" => 20 } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "15 \u00B7 20 cal Assault Bike", sections.first[:exercises].first
  end

  test "export_sections strips weight annotations from exercise names" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "straight", "exercises" => [ { "name" => "Deadlift (60kg)", "reps" => 5 } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "5 Deadlift", sections.first[:exercises].first
  end

  test "export_sections formats ladder exercises as name only with sequence in description" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "ladder", "start" => 2, "end" => 10, "step" => 2,
          "exercises" => [ { "name" => "Burpee" } ] }
    ]
    }

    sections = @workout.export_sections
    assert_equal "Burpee", sections.first[:exercises].first
    assert_equal "Ladder", sections.first[:label]
    assert_match(/2.*10.*reps/, sections.first[:description])
  end

  test "export_sections formats mountain exercises as name only with sequence in description" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "mountain", "start" => 2, "end" => 2, "peak" => 10, "step" => 2,
          "exercises" => [ { "name" => "Kettlebell Swing" } ] }
      ]
    }

    sections = @workout.export_sections
    assert_equal "Kettlebell Swing", sections.first[:exercises].first
    assert_equal "Mountain", sections.first[:label]
    assert_match(/2.*10.*2.*reps/, sections.first[:description])
  end

  test "export_sections returns exercise name only when no metrics" do
    @workout.structure = {
      "sections" => [
        { "name" => "Block", "category" => "main", "format" => "straight", "exercises" => [ { "name" => "Pull-Up" } ] }
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

  test "export_sections shows shared sequence in description for section-default ladder" do
    @workout.structure = {
      "sections" => [
        { "name" => "Reps Ladder", "category" => "main", "format" => "ladder",
          "varies" => "reps", "start" => 10, "end" => 1, "step" => 1,
          "exercises" => [ { "name" => "Burpee" } ] }
      ]
    }
    section = @workout.export_sections.first
    assert_equal "Ladder", section[:label]
    assert_match(/reps of each exercise/, section[:description].to_s)
  end

  test "export_sections shows per-exercise sequences when overrides are present" do
    @workout.structure = {
      "sections" => [
        { "name" => "Parallel Descender", "category" => "main", "format" => "ladder",
          "varies" => "reps", "start" => 50, "end" => 10, "step" => 10,
          "exercises" => [
            { "name" => "Box Jump" },
            { "name" => "Row", "varies" => "calories", "start" => 50, "end" => 10, "step" => 10 }
          ] }
      ]
    }
    section = @workout.export_sections.first
    assert_equal "Mixed Ladder", section[:label]
    assert section[:description].to_s.empty? || !section[:description].to_s.match?(/50.*40.*30/),
           "no shared sequence in header"
    assert section[:exercises].any? { |line| line.match?(/50.*40.*30.*20.*10.*reps/) }, "box jump row"
    assert section[:exercises].any? { |line| line.match?(/50.*40.*30.*20.*10.*cal/) },  "row row"
  end
end
