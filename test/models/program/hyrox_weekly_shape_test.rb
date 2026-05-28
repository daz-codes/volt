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

  test "5 sessions composition: 2 low Hyrox + 1 low cardio + 1 high strength + 1 high Hyrox" do
    shape = Program.hyrox_weekly_shape(5)
    breakdown = shape.map { |s| [ s[:activity], s[:intensity_style] ] }.tally
    assert_equal({
      [ "Hyrox",       "low"  ] => 2,
      [ "Engine Room", "low"  ] => 1,
      [ "Transformer", "high" ] => 1,
      [ "Hyrox",       "high" ] => 1
    }, breakdown)
  end

  test "6 sessions = 5-session composition + 1 extra low cardio" do
    five = Program.hyrox_weekly_shape(5).map { |s| [ s[:activity], s[:intensity_style] ] }.tally
    six  = Program.hyrox_weekly_shape(6).map { |s| [ s[:activity], s[:intensity_style] ] }.tally
    diff = six.merge(five) { |_, b, a| b - a }
    assert_equal({ [ "Engine Room", "low" ] => 1 }, diff.reject { |_, v| v.zero? })
  end

  test "7 sessions = 6-session composition + 1 medium strength" do
    six   = Program.hyrox_weekly_shape(6).map { |s| [ s[:activity], s[:intensity_style] ] }.tally
    seven = Program.hyrox_weekly_shape(7).map { |s| [ s[:activity], s[:intensity_style] ] }.tally
    diff = seven.merge(six) { |_, b, a| b - a }
    assert_equal({ [ "Transformer", "medium" ] => 1 }, diff.reject { |_, v| v.zero? })
  end

  # -- recovery rule: every high session is followed by ≥1 low later in the week --

  test "every high-intensity session is followed by at least one low-intensity session" do
    (1..9).each do |n|
      shape = Program.hyrox_weekly_shape(n)
      shape.each_with_index do |slot, i|
        next unless slot[:intensity_style] == "high"
        rest = shape[(i + 1)..]
        assert rest.any? { |s| s[:intensity_style] == "low" },
               "n=#{n}: high-intensity session at slot #{i + 1} has no low session after it (rest: #{rest.map { |s| s[:intensity_style] }.inspect})"
      end
    end
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

  test "Hyrox program: form-prefilled labels parse into per-session activity + intensity" do
    user = users(:one)
    hyrox = Activity.find_or_create_by!(name: "Hyrox")
    Activity.find_or_create_by!(name: "Engine Room")
    Activity.find_or_create_by!(name: "Transformer")

    program = Program.create!(
      user: user, name: "4-Week Hyrox Program", activity: hyrox,
      weeks_count: 2, sessions_per_week: 4, duration_mins: 45, status: "pending"
    )
    # Simulate the form's Stimulus prefill: pass the canonical Hyrox labels
    # back in as session_notes. The parser maps them to per-session overrides.
    program.create_workout_placeholders(Program.hyrox_weekly_labels(4))

    pws = program.program_workouts.where(week_number: 1).order(:session_number).to_a
    assert_equal 4, pws.size
    # "Low Hyrox" → Hyrox + low (parser keyword "low"; no activity override since no cardio/strength keyword)
    # "High strength (Transformer)" → Transformer + high
    # "Low cardio (Engine Room)" → Engine Room + low
    # "Medium Hyrox" → Hyrox + medium
    assert_equal [ nil,           "Transformer", "Engine Room", nil ],     pws.map { |pw| pw.activity&.name }
    assert_equal [ "low",         "high",        "low",         "medium" ], pws.map(&:intensity_style)
    # Same notes repeat every week
    week2 = program.program_workouts.where(week_number: 2).order(:session_number).to_a
    assert_equal pws.map(&:session_notes), week2.map(&:session_notes)
  end

  test "non-Hyrox program with blank session_notes: no overrides, no intensity, no notes" do
    user = users(:one)
    kettlebell = Activity.find_or_create_by!(name: "Kettlebell")
    program = Program.create!(
      user: user, name: "2-Week KB Program", activity: kettlebell,
      weeks_count: 2, sessions_per_week: 3, duration_mins: 30, status: "pending"
    )
    program.create_workout_placeholders  # no session_notes passed

    pws = program.program_workouts.where(week_number: 1).order(:session_number).to_a
    assert pws.all? { |pw| pw.activity.nil? },        "blank focus → no per-session activity override (program activity is used)"
    assert pws.all? { |pw| pw.intensity_style.nil? }, "blank focus → no intensity directive"
    assert pws.all? { |pw| pw.session_notes.nil? },   "blank focus → no notes"
  end

  test "free-text 'cardio only' on a Hyrox program parses to Engine Room override" do
    user = users(:one)
    Activity.find_or_create_by!(name: "Engine Room")
    hyrox = Activity.find_or_create_by!(name: "Hyrox")
    program = Program.create!(
      user: user, name: "Custom Hyrox", activity: hyrox,
      weeks_count: 2, sessions_per_week: 2, duration_mins: 60, status: "pending"
    )
    # User overrides slot 1 with "cardio only" and leaves slot 2 blank
    program.create_workout_placeholders([ "low cardio only", "" ])

    pws = program.program_workouts.where(week_number: 1).order(:session_number).to_a
    assert_equal "Engine Room", pws[0].activity&.name, "cardio keyword → Engine Room override"
    assert_equal "low",         pws[0].intensity_style
    assert_nil pws[1].activity,                        "blank slot → no override (program's Hyrox primary used)"
    assert_nil pws[1].intensity_style
  end
end
