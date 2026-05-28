require "test_helper"

class Program::HyroxWeeklyShapeTest < ActiveSupport::TestCase
  # -- per-session-count plans (the user's rules) --

  test "1 session per week → medium Hyrox" do
    shape = Program.hyrox_weekly_shape(1)
    assert_equal 1, shape.size
    assert_equal "Hyrox", shape[0][:activity]
    assert_equal "medium", shape[0][:intensity_style]
  end

  test "2 sessions → low Engine Room + medium Hyrox" do
    shape = Program.hyrox_weekly_shape(2)
    assert_equal [ "Engine Room", "Hyrox" ], shape.map { |s| s[:activity] }
    assert_equal [ "low", "medium" ],        shape.map { |s| s[:intensity_style] }
  end

  test "3 sessions → low Hyrox + high Hyrox + low cardio" do
    shape = Program.hyrox_weekly_shape(3)
    assert_equal [ "Hyrox", "Hyrox", "Engine Room" ], shape.map { |s| s[:activity] }
    assert_equal [ "low",   "high",  "low" ],         shape.map { |s| s[:intensity_style] }
  end

  test "4 sessions → low Hyrox + high strength + low cardio + medium Hyrox" do
    shape = Program.hyrox_weekly_shape(4)
    assert_equal [ "Hyrox", "Transformer", "Engine Room", "Hyrox" ], shape.map { |s| s[:activity] }
    assert_equal [ "low",   "high",        "low",         "medium" ], shape.map { |s| s[:intensity_style] }
  end

  test "5 sessions → low cardio + low Hyrox × 2 + high strength + high Hyrox" do
    shape = Program.hyrox_weekly_shape(5)
    assert_equal [ "Engine Room", "Hyrox", "Hyrox", "Transformer", "Hyrox" ], shape.map { |s| s[:activity] }
    assert_equal [ "low",         "low",   "low",   "high",        "high" ],  shape.map { |s| s[:intensity_style] }
  end

  test "6 sessions → 5-session plan + an extra low cardio" do
    shape = Program.hyrox_weekly_shape(6)
    five  = Program.hyrox_weekly_shape(5)
    assert_equal five, shape.first(5)
    assert_equal "Engine Room", shape.last[:activity]
    assert_equal "low",         shape.last[:intensity_style]
  end

  test "7 sessions → 6-session plan + a medium-intensity strength session" do
    shape = Program.hyrox_weekly_shape(7)
    six   = Program.hyrox_weekly_shape(6)
    assert_equal six, shape.first(6)
    assert_equal "Transformer", shape.last[:activity]
    assert_equal "medium",      shape.last[:intensity_style]
  end

  test "8+ sessions → 7-session plan + extra low Hyrox sessions for each additional" do
    shape8 = Program.hyrox_weekly_shape(8)
    shape9 = Program.hyrox_weekly_shape(9)
    seven  = Program.hyrox_weekly_shape(7)
    assert_equal seven, shape8.first(7)
    assert_equal "Hyrox", shape8[7][:activity]
    assert_equal "low",   shape8[7][:intensity_style]
    assert_equal 9,       shape9.size
    assert shape9.last(2).all? { |s| s[:activity] == "Hyrox" && s[:intensity_style] == "low" }
  end

  # -- guards --

  test "0 sessions returns an empty array" do
    assert_equal [], Program.hyrox_weekly_shape(0)
  end

  test "negative or nil sessions returns an empty array" do
    assert_equal [], Program.hyrox_weekly_shape(-1)
    assert_equal [], Program.hyrox_weekly_shape(nil)
  end

  # -- every slot carries notes the LLM can use --

  test "every shape entry includes activity, intensity_style and notes keys" do
    (1..8).each do |n|
      Program.hyrox_weekly_shape(n).each_with_index do |slot, i|
        assert_kind_of String, slot[:activity],        "n=#{n} slot #{i+1} activity"
        assert_kind_of String, slot[:intensity_style], "n=#{n} slot #{i+1} intensity_style"
        assert_kind_of String, slot[:notes],           "n=#{n} slot #{i+1} notes"
      end
    end
  end

  # -- integration with Program#create_workout_placeholders --

  test "Hyrox program routes through hyrox shape and stamps per-session activity + intensity" do
    user = users(:one)
    hyrox = Activity.find_or_create_by!(name: "Hyrox")
    Activity.find_or_create_by!(name: "Engine Room")
    Activity.find_or_create_by!(name: "Transformer")

    program = Program.create!(
      user: user, name: "4-Week Hyrox Program", activity: hyrox,
      weeks_count: 2, sessions_per_week: 4, duration_mins: 45, status: "pending"
    )
    program.create_workout_placeholders

    pws = program.program_workouts.where(week_number: 1).order(:session_number).to_a
    assert_equal 4, pws.size
    assert_equal [ "Hyrox", "Transformer", "Engine Room", "Hyrox" ], pws.map { |pw| pw.activity.name }
    assert_equal [ "low",   "high",        "low",         "medium" ], pws.map(&:intensity_style)
    # Same shape repeats every week
    week2 = program.program_workouts.where(week_number: 2).order(:session_number).to_a
    assert_equal pws.map { |pw| pw.activity.name }, week2.map { |pw| pw.activity.name }
  end

  test "non-Hyrox program falls back to legacy SESSION_FOCUSES (no per-session activity stamp)" do
    user = users(:one)
    kettlebell = Activity.find_or_create_by!(name: "Kettlebell")
    program = Program.create!(
      user: user, name: "2-Week KB Program", activity: kettlebell,
      weeks_count: 2, sessions_per_week: 3, duration_mins: 30, status: "pending"
    )
    program.create_workout_placeholders

    pws = program.program_workouts.where(week_number: 1).order(:session_number).to_a
    assert pws.all? { |pw| pw.activity.nil? },         "no per-session activity overrides for non-Hyrox programs"
    assert pws.all? { |pw| pw.intensity_style.nil? },  "no per-session intensity overrides for non-Hyrox programs"
    assert pws.all? { |pw| pw.session_notes.present? }, "session_notes still come from SESSION_FOCUSES rotation"
  end
end
