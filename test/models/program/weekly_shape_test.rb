require "test_helper"

class Program::WeeklyShapeTest < ActiveSupport::TestCase
  # -- per-session-count plans (Hyrox is the canonical shape) --

  test "1 session per week → medium Hyrox" do
    shape = Program.weekly_shape("Hyrox", 1)
    assert_equal 1, shape.size
    assert_equal "Hyrox", shape[0][:activity]
    assert_equal "medium", shape[0][:intensity_style]
  end

  test "2 sessions → low Engine Room + medium Hyrox" do
    shape = Program.weekly_shape("Hyrox", 2)
    assert_equal [ "Engine Room", "Hyrox" ], shape.map { |s| s[:activity] }
    assert_equal [ "low", "medium" ],        shape.map { |s| s[:intensity_style] }
  end

  test "3 sessions → low Hyrox + high Hyrox + low cardio" do
    shape = Program.weekly_shape("Hyrox", 3)
    assert_equal [ "Hyrox", "Hyrox", "Engine Room" ], shape.map { |s| s[:activity] }
    assert_equal [ "low",   "high",  "low" ],         shape.map { |s| s[:intensity_style] }
  end

  test "4 sessions → low Hyrox + high strength + low cardio + medium Hyrox" do
    shape = Program.weekly_shape("Hyrox", 4)
    assert_equal [ "Hyrox", "Volt Strong", "Engine Room", "Hyrox" ], shape.map { |s| s[:activity] }
    assert_equal [ "low",   "high",        "low",         "medium" ], shape.map { |s| s[:intensity_style] }
  end

  test "5 sessions composition: 2 low Hyrox + 1 low cardio + 1 high strength + 1 high Hyrox" do
    shape = Program.weekly_shape("Hyrox", 5)
    breakdown = shape.map { |s| [ s[:activity], s[:intensity_style] ] }.tally
    assert_equal({
      [ "Hyrox",       "low"  ] => 2,
      [ "Engine Room", "low"  ] => 1,
      [ "Volt Strong", "high" ] => 1,
      [ "Hyrox",       "high" ] => 1
    }, breakdown)
  end

  test "6 sessions = 5-session composition + 1 extra low cardio" do
    five = Program.weekly_shape("Hyrox", 5).map { |s| [ s[:activity], s[:intensity_style] ] }.tally
    six  = Program.weekly_shape("Hyrox", 6).map { |s| [ s[:activity], s[:intensity_style] ] }.tally
    diff = six.merge(five) { |_, b, a| b - a }
    assert_equal({ [ "Engine Room", "low" ] => 1 }, diff.reject { |_, v| v.zero? })
  end

  test "7 sessions = 6-session composition + 1 medium strength" do
    six   = Program.weekly_shape("Hyrox", 6).map { |s| [ s[:activity], s[:intensity_style] ] }.tally
    seven = Program.weekly_shape("Hyrox", 7).map { |s| [ s[:activity], s[:intensity_style] ] }.tally
    diff = seven.merge(six) { |_, b, a| b - a }
    assert_equal({ [ "Volt Strong", "medium" ] => 1 }, diff.reject { |_, v| v.zero? })
  end

  test "8+ sessions → 7-session plan + extra low primary sessions for each additional" do
    [ "Hyrox", "Deka Fit", "Deka Strong", "Deka Mile" ].each do |activity|
      shape8 = Program.weekly_shape(activity, 8)
      seven  = Program.weekly_shape(activity, 7)
      assert_equal seven, shape8.first(7), "#{activity} 8-session prefix should match the 7-session plan"
      assert_equal activity, shape8[7][:activity]
      assert_equal "low",    shape8[7][:intensity_style]
    end
  end

  # -- recovery rule: every high session is followed by ≥1 low later in the week --

  test "every high-intensity session is followed by at least one low-intensity session — all activities" do
    [ "Hyrox", "Deka Fit", "Deka Strong", "Deka Mile", "Deka Atlas" ].each do |activity|
      (1..9).each do |n|
        shape = Program.weekly_shape(activity, n)
        shape.each_with_index do |slot, i|
          next unless slot[:intensity_style] == "high"
          rest = shape[(i + 1)..]
          assert rest.any? { |s| s[:intensity_style] == "low" },
                 "#{activity}, n=#{n}: high session at slot #{i + 1} has no low session after it (#{shape.map { |s| s[:intensity_style] }.inspect})"
        end
      end
    end
  end

  # -- Deka Fit / Strong / Mile share Hyrox's shape, only the activity name swaps --

  test "Deka Fit / Strong / Mile follow the same base plan as Hyrox" do
    [ "Deka Fit", "Deka Strong", "Deka Mile" ].each do |activity|
      hyrox = Program.weekly_shape("Hyrox",  5)
      deka  = Program.weekly_shape(activity, 5)
      hyrox_pattern = hyrox.map { |s| [ s[:activity] == "Hyrox" ? :primary : s[:activity], s[:intensity_style] ] }
      deka_pattern  = deka.map  { |s| [ s[:activity] == activity   ? :primary : s[:activity], s[:intensity_style] ] }
      assert_equal hyrox_pattern, deka_pattern, "#{activity} 5-session plan should mirror Hyrox's"
    end
  end

  # -- Deka Atlas overlay --

  test "Deka Atlas: every cardio_low slot is swapped for a medium strength session" do
    shape = Program.weekly_shape("Deka Atlas", 6)
    assert shape.none? { |s| s[:activity] == "Engine Room" }, "Atlas has no Engine Room sessions"
    medium_strengths = shape.count { |s| s[:activity] == "Volt Strong" && s[:intensity_style] == "medium" }
    assert medium_strengths >= 2, "Atlas 6-session plan should replace both cardio_low slots with medium strength"
  end

  test "Deka Atlas: 2+ high sessions get one downgraded to medium" do
    # 5-session Hyrox has 1 strength_high (Volt Strong) + 1 primary_high.
    # For Atlas the downgrade rule kicks in. Volt Strong high is downgraded
    # (primary_high stays as the peak).
    shape = Program.weekly_shape("Deka Atlas", 5)
    high_count = shape.count { |s| s[:intensity_style] == "high" }
    assert_equal 1, high_count, "Atlas should never have more than 1 high session"
    high_slot = shape.find { |s| s[:intensity_style] == "high" }
    assert_equal "Deka Atlas", high_slot[:activity], "the surviving high should be the activity-specific one"
  end

  test "Deka Atlas: 3-session plan only has 1 high — no downgrade fires" do
    shape = Program.weekly_shape("Deka Atlas", 3)
    high_count = shape.count { |s| s[:intensity_style] == "high" }
    assert_equal 1, high_count
  end

  test "Deka Atlas: 2-session plan converts the cardio session into medium strength" do
    shape = Program.weekly_shape("Deka Atlas", 2)
    assert_equal [ "Volt Strong", "Deka Atlas" ], shape.map { |s| s[:activity] }
    assert_equal [ "medium",      "medium" ],     shape.map { |s| s[:intensity_style] }
  end

  # -- labels are prefill-friendly --

  test "weekly_labels for each activity matches the shape size" do
    [ "Hyrox", "Deka Fit", "Deka Strong", "Deka Mile", "Deka Atlas" ].each do |activity|
      labels = Program.weekly_labels(activity, 5)
      assert_equal 5, labels.size, "#{activity} should have 5 labels"
      assert labels.all? { |l| l.is_a?(String) && !l.empty? }, "#{activity} labels must be non-empty strings"
    end
  end

  test "primary-slot labels use the program's activity name in the text" do
    [ "Hyrox", "Deka Fit", "Deka Mile" ].each do |activity|
      labels = Program.weekly_labels(activity, 3)  # has a primary_low at slot 1
      assert_match(/#{Regexp.escape(activity)}/, labels[0], "first label should mention #{activity}")
    end
  end

  # -- guards --

  test "non-race-family activities return [] (no prescribed shape)" do
    assert_equal [], Program.weekly_shape("Kettlebell Hell", 5)
    assert_equal [], Program.weekly_shape("Pump & Grind", 3)
  end

  test "0 / negative / nil sessions return []" do
    assert_equal [], Program.weekly_shape("Hyrox", 0)
    assert_equal [], Program.weekly_shape("Hyrox", -1)
    assert_equal [], Program.weekly_shape("Hyrox", nil)
  end

  # -- legacy Hyrox-only API still works (backward compat) --

  test "Program.hyrox_weekly_shape delegates to Hyrox" do
    assert_equal Program.weekly_shape("Hyrox", 4), Program.hyrox_weekly_shape(4)
  end

  test "Program.hyrox_weekly_labels delegates to Hyrox" do
    assert_equal Program.weekly_labels("Hyrox", 4), Program.hyrox_weekly_labels(4)
  end

  # -- integration with Program#create_workout_placeholders --

  test "Hyrox program: form-prefilled labels parse into per-session activity + intensity" do
    user = users(:one)
    hyrox = Activity.find_or_create_by!(name: "Hyrox")
    Activity.find_or_create_by!(name: "Engine Room")
    Activity.find_or_create_by!(name: "Volt Strong")

    program = Program.create!(
      user: user, name: "4-Week Hyrox Program", activity: hyrox,
      weeks_count: 2, sessions_per_week: 4, duration_mins: 45, status: "pending"
    )
    program.create_workout_placeholders(Program.weekly_labels("Hyrox", 4))

    pws = program.program_workouts.where(week_number: 1).order(:session_number).to_a
    assert_equal 4, pws.size
    assert_equal [ nil,   "Volt Strong", "Engine Room", nil ],     pws.map { |pw| pw.activity&.name }
    assert_equal [ "low", "high",        "low",         "medium" ], pws.map(&:intensity_style)
  end

  test "Deka Atlas program routes through Atlas-overlay shape" do
    user = users(:one)
    atlas = Activity.find_or_create_by!(name: "Deka Atlas")
    Activity.find_or_create_by!(name: "Volt Strong")

    program = Program.create!(
      user: user, name: "5-Week Atlas Program", activity: atlas,
      weeks_count: 2, sessions_per_week: 5, duration_mins: 60, status: "pending"
    )
    program.create_workout_placeholders(Program.weekly_labels("Deka Atlas", 5))

    pws = program.program_workouts.where(week_number: 1).order(:session_number).to_a
    assert_equal 5, pws.size
    refute pws.any? { |pw| pw.activity&.name == "Engine Room" }, "Atlas should never produce an Engine Room slot"
    high_count = pws.count { |pw| pw.intensity_style == "high" }
    assert_equal 1, high_count, "Atlas should land on exactly 1 high session"
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
    assert pws.all? { |pw| pw.activity.nil? }
    assert pws.all? { |pw| pw.intensity_style.nil? }
    assert pws.all? { |pw| pw.session_notes.nil? }
  end

  test "free-text 'cardio only' on a Hyrox program parses to Engine Room override" do
    user = users(:one)
    Activity.find_or_create_by!(name: "Engine Room")
    hyrox = Activity.find_or_create_by!(name: "Hyrox")
    program = Program.create!(
      user: user, name: "Custom Hyrox", activity: hyrox,
      weeks_count: 2, sessions_per_week: 2, duration_mins: 60, status: "pending"
    )
    program.create_workout_placeholders([ "low cardio only", "" ])

    pws = program.program_workouts.where(week_number: 1).order(:session_number).to_a
    assert_equal "Engine Room", pws[0].activity&.name
    assert_equal "low",         pws[0].intensity_style
    assert_nil pws[1].activity
    assert_nil pws[1].intensity_style
  end
end
