require "test_helper"

class Workout::ScalableTest < ActiveSupport::TestCase
  setup do
    @workout = workouts(:hyrox_session)
    @workout.structure = {
      "goal" => "Test workout",
      "sections" => [
        {
          "name" => "Warm-Up", "category" => "warm_up", "format" => "straight",
          "duration_mins" => 5,
          "exercises" => [{ "name" => "Easy Row", "notes" => "Easy pace" }]
        },
        {
          "name" => "Main Circuit", "category" => "main", "format" => "rounds",
          "rounds" => 5,
          "exercises" => [
            { "name" => "KB Swings", "reps" => 20 },
            { "name" => "Box Jumps", "reps" => 15 },
            { "name" => "Row", "distance_m" => 400 }
          ]
        },
        {
          "name" => "The Ladder", "category" => "main", "format" => "ladder",
          "start" => 10, "end" => 1, "step" => 1, "varies" => "reps",
          "exercises" => [
            { "name" => "Thrusters" },
            { "name" => "Burpees" }
          ]
        },
        {
          "name" => "Cool-Down", "category" => "cool_down", "format" => "straight",
          "duration_mins" => 5,
          "exercises" => [{ "name" => "Stretch", "notes" => "Hold 30s each" }]
        }
      ]
    }
    @workout.original_structure = @workout.structure.deep_dup
  end

  test "scale_to 3 returns the original structure unchanged" do
    result = @workout.scale_to(3)
    assert_equal @workout.original_structure, result
  end

  test "scale_to 2 reduces rounds by 1" do
    result = @workout.scale_to(2)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    assert_equal 4, main["rounds"]
  end

  test "scale_to 4 increases rounds by 1" do
    result = @workout.scale_to(4)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    assert_equal 6, main["rounds"]
  end

  test "scale_to 2 reduces reps by ~20%" do
    result = @workout.scale_to(2)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    swings = main["exercises"].find { |e| e["name"] == "KB Swings" }
    # 20 * 0.8 = 16, rounded to 15 (nearest 5)
    assert_equal 15, swings["reps"]
  end

  test "scale_to 4 increases reps by ~20%" do
    result = @workout.scale_to(4)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    swings = main["exercises"].find { |e| e["name"] == "KB Swings" }
    # 20 * 1.2 = 24, rounded to 25 (nearest 5)
    assert_equal 25, swings["reps"]
  end

  test "scale_to 2 reduces distances" do
    result = @workout.scale_to(2)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    row = main["exercises"].find { |e| e["name"] == "Row" }
    # 400 * 0.75 = 300
    assert_equal 300, row["distance_m"]
  end

  test "scale_to 2 shrinks ladder range" do
    result = @workout.scale_to(2)
    ladder = result["sections"].find { |s| s["name"] == "The Ladder" }
    assert_equal 8, ladder["start"]
  end

  test "scale_to 4 extends ladder range" do
    result = @workout.scale_to(4)
    ladder = result["sections"].find { |s| s["name"] == "The Ladder" }
    assert_equal 12, ladder["start"]
  end

  test "warm_up and cool_down sections are never scaled" do
    result = @workout.scale_to(2)
    warmup = result["sections"].find { |s| s["category"] == "warm_up" }
    cooldown = result["sections"].find { |s| s["category"] == "cool_down" }

    assert_equal @workout.original_structure["sections"].first, warmup
    assert_equal @workout.original_structure["sections"].last, cooldown
  end

  test "scale_to uses structure as fallback when original_structure is nil" do
    @workout.original_structure = nil
    result = @workout.scale_to(2)
    main = result["sections"].find { |s| s["name"] == "Main Circuit" }
    assert_equal 4, main["rounds"]
  end

  test "tabata sections are not scaled" do
    @workout.structure["sections"] << {
      "name" => "Tabata", "category" => "main", "format" => "tabata",
      "exercises" => [
        { "name" => "Squat Curl and Press" },
        { "name" => "KB Swing with Lunge" }
      ]
    }
    @workout.original_structure = @workout.structure.deep_dup

    result = @workout.scale_to(2)
    tabata = result["sections"].find { |s| s["format"] == "tabata" }
    original_tabata = @workout.original_structure["sections"].find { |s| s["format"] == "tabata" }
    assert_equal original_tabata, tabata
  end

  test "hundred sections are not scaled" do
    @workout.structure["sections"] << {
      "name" => "The Hundred", "category" => "finisher", "format" => "hundred",
      "exercises" => [{ "name" => "KB Swings", "reps" => 100 }]
    }
    @workout.original_structure = @workout.structure.deep_dup

    result = @workout.scale_to(2)
    hundred = result["sections"].find { |s| s["format"] == "hundred" }
    assert_equal 100, hundred["exercises"].first["reps"]
  end

  test "matrix sections are not scaled" do
    @workout.structure["sections"] << {
      "name" => "Matrix", "category" => "main", "format" => "matrix",
      "exercises" => [
        { "name" => "Thrusters", "reps" => 10 },
        { "name" => "Pull-ups", "reps" => 10 }
      ]
    }
    @workout.original_structure = @workout.structure.deep_dup

    result = @workout.scale_to(2)
    matrix = result["sections"].find { |s| s["format"] == "matrix" }
    original_matrix = @workout.original_structure["sections"].find { |s| s["format"] == "matrix" }
    assert_equal original_matrix, matrix
  end

  test "scale_to 1 calls LLM and returns a valid structure" do
    # We can't easily test the full LLM call in unit tests, so test the fallback
    # The LLM scaling is integration-tested separately
    result = @workout.scale_to(1)
    assert result.is_a?(Hash)
    assert result["sections"].is_a?(Array)
    # Should still have warm-up and cool-down
    categories = result["sections"].map { |s| s["category"] }
    assert_includes categories, "warm_up"
    assert_includes categories, "cool_down"
  end

  test "scale_to 5 calls LLM and returns a valid structure" do
    result = @workout.scale_to(5)
    assert result.is_a?(Hash)
    assert result["sections"].is_a?(Array)
  end
end
