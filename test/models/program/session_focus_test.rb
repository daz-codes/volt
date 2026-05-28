require "test_helper"

class Program::SessionFocusTest < ActiveSupport::TestCase
  test "blank text → no overrides, no notes; default activity returned" do
    result = Program.parse_session_focus("", default_activity_name: "Hyrox")
    assert_equal "Hyrox", result[:activity_name]
    assert_nil result[:intensity_style]
    assert_nil result[:notes]
  end

  test "cardio keyword overrides activity to Engine Room" do
    result = Program.parse_session_focus("low cardio", default_activity_name: "Hyrox")
    assert_equal "Engine Room", result[:activity_name]
    assert_equal "low",         result[:intensity_style]
  end

  test "'engine room' phrase overrides activity to Engine Room" do
    result = Program.parse_session_focus("Low cardio (Engine Room)", default_activity_name: "Hyrox")
    assert_equal "Engine Room", result[:activity_name]
    assert_equal "low",         result[:intensity_style]
  end

  test "strength keyword overrides activity to Transformer" do
    result = Program.parse_session_focus("high strength", default_activity_name: "Hyrox")
    assert_equal "Transformer", result[:activity_name]
    assert_equal "high",        result[:intensity_style]
  end

  test "'transformer' phrase overrides activity to Transformer" do
    result = Program.parse_session_focus("Medium strength (Transformer)", default_activity_name: "Hyrox")
    assert_equal "Transformer", result[:activity_name]
    assert_equal "medium",      result[:intensity_style]
  end

  test "no activity keyword falls back to default" do
    result = Program.parse_session_focus("Low Hyrox", default_activity_name: "Hyrox")
    assert_equal "Hyrox", result[:activity_name]
    assert_equal "low",   result[:intensity_style]
  end

  test "intensity-only text returns just the intensity, default activity" do
    result = Program.parse_session_focus("easy day", default_activity_name: "Hyrox")
    assert_equal "Hyrox", result[:activity_name]
    assert_equal "low",   result[:intensity_style]
  end

  test "high-intensity synonyms map to high" do
    %w[max all-out race-day all\ out near-max].each do |word|
      result = Program.parse_session_focus("#{word} session", default_activity_name: "Hyrox")
      assert_equal "high", result[:intensity_style], "expected '#{word}' to map to high"
    end
  end

  test "low-intensity synonyms map to low" do
    %w[easy conversational recovery zone\ 2].each do |word|
      result = Program.parse_session_focus("#{word} day", default_activity_name: "Hyrox")
      assert_equal "low", result[:intensity_style], "expected '#{word}' to map to low"
    end
  end

  test "unknown intensity returns nil intensity but keeps the notes" do
    result = Program.parse_session_focus("upper body", default_activity_name: "Hyrox")
    assert_equal "Hyrox", result[:activity_name]
    assert_nil result[:intensity_style]
    assert_equal "upper body", result[:notes]
  end

  test "notes preserve the user's original wording" do
    text = "long ski day with focus on breathing"
    result = Program.parse_session_focus(text, default_activity_name: "Hyrox")
    assert_equal text, result[:notes]
  end
end
