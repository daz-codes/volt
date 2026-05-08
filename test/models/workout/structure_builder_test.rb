require "test_helper"

class Workout::StructureBuilderTest < ActiveSupport::TestCase
  test "ladder section persists exercise metric override when whitelisted" do
    params = ActionController::Parameters.new(
      "0" => {
        name: "Mixed Ladder", category: "main", format: "ladder",
        varies: "reps", start: 10, end: 1, step: 1,
        exercises: {
          "0" => { name: "Row", metric: "calories" },
          "1" => { name: "Bicep Curl" }
        }
      }
    )

    structure = Workout.structure_from_params(params)
    section = structure["sections"].first

    assert_equal "calories", section["exercises"][0]["metric"]
    assert_nil section["exercises"][1]["metric"]
  end

  test "exercise metric override rejects values outside the whitelist" do
    params = ActionController::Parameters.new(
      "0" => {
        name: "Bad Ladder", category: "main", format: "ladder",
        varies: "reps", start: 10, end: 1, step: 1,
        exercises: {
          "0" => { name: "Row", metric: "kg" },
          "1" => { name: "Curl", metric: "bogus" }
        }
      }
    )

    structure = Workout.structure_from_params(params)
    section = structure["sections"].first

    assert_nil section["exercises"][0]["metric"]
    assert_nil section["exercises"][1]["metric"]
  end

  test "exercise metric override is omitted when blank" do
    params = ActionController::Parameters.new(
      "0" => {
        name: "Plain Ladder", category: "main", format: "ladder",
        varies: "reps", start: 10, end: 1, step: 1,
        exercises: { "0" => { name: "Row", metric: "" } }
      }
    )

    structure = Workout.structure_from_params(params)

    refute structure["sections"].first["exercises"].first.key?("metric")
  end

  test "sections are returned in integer-key order regardless of hash insertion order" do
    params = ActionController::Parameters.new(
      "2" => { name: "B", category: "main", format: "straight" },
      "0" => { name: "C", category: "main", format: "straight" },
      "1" => { name: "A", category: "main", format: "straight" }
    )

    structure = Workout.structure_from_params(params)

    assert_equal %w[C A B], structure["sections"].map { |s| s["name"] }
  end
end
